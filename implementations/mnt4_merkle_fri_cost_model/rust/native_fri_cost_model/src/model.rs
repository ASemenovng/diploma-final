//! Полная stop/go gas-модель с явными инженерными допущениями.

use std::collections::BTreeSet;

use crate::{
    fri::{
        deterministic_queries, enumerate_schedules, estimate_layout, merkle_frontier_count,
        FriSchedule,
    },
    security::{ordinary_fri_security, OrdinaryFriSecurity, LDE_SIZE, PRODUCTION_QUERY_COUNT},
};

/// Измеренные или явно выбранные параметры модели.
///
/// Поля с суффиксом `_gas` берутся из существующих Foundry gas-report либо
/// задают консервативный технический бюджет до появления Solidity verifier-а.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ModelAssumptions {
    pub field_bytes: usize,
    pub hash_bytes: usize,
    pub calldata_gas_per_nonzero_byte: u64,
    pub fq_mul_gas: u64,
    pub fq_add_gas: u64,
    pub keccak_pair_expected_gas: u64,
    pub source_leaf_dynamic_columns: usize,
    pub source_neighbor_radius: usize,
    pub relation_muls_per_query: usize,
    pub fixed_shard_words_per_query: usize,
    pub fixed_shard_read_gas_per_word: u64,
    pub global_relation_muls: usize,
    pub control_flow_overhead_gas: u64,
    pub article640_fixed_shards_gas: u64,
    pub desired_target_gas: u64,
}

impl Default for ModelAssumptions {
    fn default() -> Self {
        Self {
            field_bytes: 96,
            hash_bytes: 32,
            calldata_gas_per_nonzero_byte: 16,
            fq_mul_gas: 2_959,
            fq_add_gas: 284,
            // KECCAK256 opcode стоит 30 + 6 gas/word. Здесь добавлен запас
            // на работу потокового parser-а и scratch memory.
            keccak_pair_expected_gas: 120,
            // Минимальный реестр: C, E_alpha, E_D(P), E_D(R), B_alpha,
            // Q_ext, composition и boundary state.
            source_leaf_dynamic_columns: 8,
            // Для локальных отношений раскрываются строка и два соседа.
            source_neighbor_radius: 1,
            // Предварительный бюджет. Отчет отдельно строит sensitivity
            // таблицу, поэтому эта величина не маскируется под измерение.
            relation_muls_per_query: 12,
            fixed_shard_words_per_query: 12,
            fixed_shard_read_gas_per_word: 6,
            global_relation_muls: 192,
            control_flow_overhead_gas: 1_500_000,
            article640_fixed_shards_gas: 93_879_746,
            desired_target_gas: 60_000_000,
        }
    }
}

/// Разложение gas по компонентам. Все числа целочисленны и
/// воспроизводимы, чтобы позднее заменить модельные бюджеты измерениями.
#[derive(Debug, Clone, Default, PartialEq, Eq)]
pub struct GasBreakdown {
    pub fri_calldata_gas: u64,
    pub source_calldata_gas: u64,
    pub fri_arithmetic_gas: u64,
    pub relation_arithmetic_gas: u64,
    pub fixed_shard_reads_gas: u64,
    pub merkle_execution_gas: u64,
    pub global_relation_gas: u64,
    pub control_flow_overhead_gas: u64,
    pub total_gas: u64,
}

impl GasBreakdown {
    fn recompute_total(&mut self) {
        self.total_gas = self.fri_calldata_gas
            + self.source_calldata_gas
            + self.fri_arithmetic_gas
            + self.relation_arithmetic_gas
            + self.fixed_shard_reads_gas
            + self.merkle_execution_gas
            + self.global_relation_gas
            + self.control_flow_overhead_gas;
    }
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct StopGoDecision {
    pub beats_article640_fixed_shards: bool,
    pub reaches_desired_target: bool,
}

/// Сравниваемые представления `Fq4`. В N1 basis влияет только на
/// аналитическую таблицу: точные коэффициенты появятся после индексатора.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum BasisChoice {
    Tower,
    Normal,
}

impl BasisChoice {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::Tower => "tower",
            Self::Normal => "normal",
        }
    }
}

/// Значение эвристики Article640 для равномерного блока.
#[derive(Debug, Clone, PartialEq)]
pub struct BlockPartitionCandidate {
    pub block_size: usize,
    pub heuristic_cost: f64,
}

/// Статус basis-кандидата. Tower basis уже соответствует существующей
/// MNT4-арифметике. Normal basis остается исследовательским кандидатом:
/// экономию Frobenius нужно сопоставить со стоимостью конверсий на N2.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct BasisCandidate {
    pub basis: BasisChoice,
    pub production_eligible: bool,
    pub note: &'static str,
}

/// Экспериментальный DEEP-FRI профиль. До инстанциации конкретной теоремы
/// он не может участвовать в production stop/go независимо от gas.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ExperimentalDeepProfile {
    pub query_count: usize,
    pub schedule: FriSchedule,
    pub expected_total_gas: u64,
    pub production_eligible: bool,
}

/// Строка sensitivity-таблицы для еще не измеренных Solidity параметров.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct SensitivityRow {
    pub source_leaf_dynamic_columns: usize,
    pub relation_muls_per_query: usize,
    pub expected_total_gas: u64,
    pub beats_article640_fixed_shards: bool,
    pub reaches_desired_target: bool,
}

/// Высокоуровневые счетчики, объясняющие gas-модель через базовые операции.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct OperationCounts {
    pub minimum_fq_muls: usize,
    pub expected_fq_muls: usize,
    pub expected_fq_adds: usize,
    pub fq_inversions: usize,
    pub merkle_hashes: usize,
    pub fixed_shard_words: usize,
}

#[derive(Debug, Clone, PartialEq)]
pub struct ProfileEstimate {
    pub profile_name: &'static str,
    pub query_count: usize,
    pub schedule: FriSchedule,
    pub security: OrdinaryFriSecurity,
    pub source_opened_rows: usize,
    pub source_frontier_hashes: usize,
    pub fri_opened_field_values: usize,
    pub fri_frontier_hashes: usize,
    pub proof_bytes: u64,
    pub segment_count: usize,
    pub operations: OperationCounts,
    pub lower_bound: GasBreakdown,
    pub expected: GasBreakdown,
    pub stop_go: StopGoDecision,
}

/// Считает строгий ordinary-FRI профиль. `lower_bound` включает обязательные
/// calldata и FRI-умножения, но не технические расходы. `expected` добавляет
/// инженерные бюджеты из `ModelAssumptions`.
pub fn estimate_profile(
    assumptions: &ModelAssumptions,
    schedule: FriSchedule,
    query_count: usize,
) -> ProfileEstimate {
    let seed = 7;
    let security = ordinary_fri_security(query_count);
    let fri = estimate_layout(&schedule, query_count, seed);
    let source_positions = source_opening_positions(
        &deterministic_queries(query_count, seed, LDE_SIZE),
        assumptions.source_neighbor_radius,
    );
    let source_frontier_hashes = merkle_frontier_count(LDE_SIZE, &source_positions);
    let fri_bytes = fri.opened_field_values * assumptions.field_bytes
        + fri.frontier_hashes * assumptions.hash_bytes
        + fri.final_polynomial_values * assumptions.field_bytes;
    let source_bytes =
        source_positions.len() * assumptions.source_leaf_dynamic_columns * assumptions.field_bytes
            + source_frontier_hashes * assumptions.hash_bytes;

    let mut lower_bound = GasBreakdown {
        fri_calldata_gas: gas_for_bytes(assumptions, fri_bytes),
        source_calldata_gas: gas_for_bytes(assumptions, source_bytes),
        fri_arithmetic_gas: fri.opened_field_values as u64 * assumptions.fq_mul_gas,
        ..GasBreakdown::default()
    };
    lower_bound.recompute_total();

    let merkle_hashes = fri.frontier_hashes + source_frontier_hashes;
    let mut expected = lower_bound.clone();
    let relation_operations = query_count * assumptions.relation_muls_per_query;
    expected.fri_arithmetic_gas += fri.opened_field_values as u64 * assumptions.fq_add_gas;
    expected.relation_arithmetic_gas =
        relation_operations as u64 * (assumptions.fq_mul_gas + assumptions.fq_add_gas);
    expected.fixed_shard_reads_gas = query_count as u64
        * assumptions.fixed_shard_words_per_query as u64
        * assumptions.fixed_shard_read_gas_per_word;
    expected.merkle_execution_gas = merkle_hashes as u64 * assumptions.keccak_pair_expected_gas;
    expected.global_relation_gas =
        assumptions.global_relation_muls as u64 * (assumptions.fq_mul_gas + assumptions.fq_add_gas);
    expected.control_flow_overhead_gas = assumptions.control_flow_overhead_gas;
    expected.recompute_total();

    ProfileEstimate {
        profile_name: "ordinary-fri-strict",
        query_count,
        schedule,
        security,
        source_opened_rows: source_positions.len(),
        source_frontier_hashes,
        fri_opened_field_values: fri.opened_field_values,
        fri_frontier_hashes: fri.frontier_hashes,
        proof_bytes: (fri_bytes + source_bytes) as u64,
        segment_count: 1,
        operations: OperationCounts {
            minimum_fq_muls: fri.opened_field_values,
            expected_fq_muls: fri.opened_field_values
                + relation_operations
                + assumptions.global_relation_muls,
            expected_fq_adds: fri.opened_field_values
                + relation_operations
                + assumptions.global_relation_muls,
            fq_inversions: 0,
            merkle_hashes,
            fixed_shard_words: query_count * assumptions.fixed_shard_words_per_query,
        },
        stop_go: StopGoDecision {
            beats_article640_fixed_shards: expected.total_gas
                < assumptions.article640_fixed_shards_gas,
            reaches_desired_target: expected.total_gas < assumptions.desired_target_gas,
        },
        lower_bound,
        expected,
    }
}

/// Перебирает schedules для последнего слоя 16 и выбирает минимальную
/// ожидаемую оценку строгого ordinary-FRI профиля.
pub fn optimize_strict_profile(assumptions: &ModelAssumptions) -> ProfileEstimate {
    [8, 16, 32, 64]
        .into_iter()
        .flat_map(enumerate_schedules)
        .map(|schedule| estimate_profile(assumptions, schedule, PRODUCTION_QUERY_COUNT))
        .min_by_key(|estimate| estimate.expected.total_gas)
        .expect("at least one FRI schedule")
}

pub fn basis_candidates() -> Vec<BasisCandidate> {
    vec![
        BasisCandidate {
            basis: BasisChoice::Tower,
            production_eligible: true,
            note: "baseline: уже согласован с production MNT4 arithmetic",
        },
        BasisCandidate {
            basis: BasisChoice::Normal,
            production_eligible: false,
            note: "candidate: нужны индексатор и измерение basis-conversion/Frobenius",
        },
    ]
}

/// Эвристика Article640:
///
/// C(d) = (k - 1)L/d + (2^d - 1)(k - 1) - k,
///
/// где `k=4`, `L=376`. Она выбирает исходный block-compression baseline,
/// а точный adaptive partition строится индексатором на следующем этапе.
pub fn block_partition_candidates() -> Vec<BlockPartitionCandidate> {
    const K: f64 = 4.0;
    const L: f64 = 376.0;
    (3..=7)
        .map(|block_size| BlockPartitionCandidate {
            block_size,
            heuristic_cost: (K - 1.0) * L / block_size as f64
                + (((1usize << block_size) - 1) as f64) * (K - 1.0)
                - K,
        })
        .collect()
}

/// Считает цену DEEP-FRI кандидатов, не присваивая им неподтвержденный
/// production-статус. Эти строки показывают, какой query count потребуется
/// обосновать отдельной теоремой, чтобы направление имело практический смысл.
pub fn experimental_deep_sensitivity(
    assumptions: &ModelAssumptions,
    schedule: &FriSchedule,
) -> Vec<ExperimentalDeepProfile> {
    [32, 64, 96, 128, 256]
        .into_iter()
        .map(|query_count| ExperimentalDeepProfile {
            query_count,
            schedule: schedule.clone(),
            expected_total_gas: estimate_profile(assumptions, schedule.clone(), query_count)
                .expected
                .total_gas,
            production_eligible: false,
        })
        .collect()
}

/// Показывает устойчивость вывода к двум главным модельным параметрам:
/// числу динамических столбцов source leaf и локальных `Fq`-умножений.
pub fn sensitivity_grid(
    assumptions: &ModelAssumptions,
    schedule: &FriSchedule,
) -> Vec<SensitivityRow> {
    let mut rows = Vec::new();
    for source_leaf_dynamic_columns in [6, 8, 10] {
        for relation_muls_per_query in [8, 12, 16] {
            let mut varied = assumptions.clone();
            varied.source_leaf_dynamic_columns = source_leaf_dynamic_columns;
            varied.relation_muls_per_query = relation_muls_per_query;
            let profile = estimate_profile(&varied, schedule.clone(), PRODUCTION_QUERY_COUNT);
            rows.push(SensitivityRow {
                source_leaf_dynamic_columns,
                relation_muls_per_query,
                expected_total_gas: profile.expected.total_gas,
                beats_article640_fixed_shards: profile.stop_go.beats_article640_fixed_shards,
                reaches_desired_target: profile.stop_go.reaches_desired_target,
            });
        }
    }
    rows
}

fn gas_for_bytes(assumptions: &ModelAssumptions, bytes: usize) -> u64 {
    bytes as u64 * assumptions.calldata_gas_per_nonzero_byte
}

fn source_opening_positions(queries: &[usize], radius: usize) -> Vec<usize> {
    let mut positions = BTreeSet::new();
    for query in queries {
        for offset in 0..=radius {
            positions.insert((query + offset) & (LDE_SIZE - 1));
            positions.insert((query + LDE_SIZE - offset) & (LDE_SIZE - 1));
        }
    }
    positions.into_iter().collect()
}
