//! Детерминированная модель FRI-layer skipping и бинарных Merkle multiproof.

use std::collections::BTreeSet;

use crate::security::LDE_SIZE;

/// Группировка FRI-слоев. Значение `s_i` означает свертку сразу в `2^s_i`
/// раз. Сумма `s_i` обязана приводить исходный LDE-домен к `last_layer_size`.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct FriSchedule {
    pub skip_bits: Vec<u8>,
    pub last_layer_size: usize,
}

impl FriSchedule {
    pub fn new(skip_bits: Vec<u8>, last_layer_size: usize) -> Result<Self, String> {
        if skip_bits.is_empty() {
            return Err("FRI schedule must contain at least one round".into());
        }
        if last_layer_size == 0 || !last_layer_size.is_power_of_two() {
            return Err("last layer size must be a non-zero power of two".into());
        }
        if skip_bits.iter().any(|bits| !(1..=4).contains(bits)) {
            return Err("each FRI step must skip between one and four binary layers".into());
        }
        let total_fold_bits: usize = skip_bits.iter().map(|bits| *bits as usize).sum();
        if LDE_SIZE >> total_fold_bits != last_layer_size {
            return Err("FRI schedule does not fold the complete LDE domain".into());
        }
        Ok(Self {
            skip_bits,
            last_layer_size,
        })
    }

    pub fn total_fold_bits(&self) -> usize {
        self.skip_bits.iter().map(|bits| *bits as usize).sum()
    }
}

/// Количество данных, раскрываемых FRI proof-ом после дедупликации.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct FriLayout {
    pub initial_domain_size: usize,
    pub final_domain_size: usize,
    pub query_count: usize,
    pub opened_field_values: usize,
    pub frontier_hashes: usize,
    pub fold_groups: usize,
    pub final_polynomial_values: usize,
}

/// Число frontier-хешей минимального бинарного Merkle multiproof.
pub fn merkle_frontier_count(tree_size: usize, opened_positions: &[usize]) -> usize {
    assert!(tree_size.is_power_of_two());
    let mut active: BTreeSet<usize> = opened_positions.iter().copied().collect();
    assert!(active.iter().all(|position| *position < tree_size));

    let mut frontier = 0;
    let mut width = tree_size;
    while width > 1 {
        for position in &active {
            let sibling = position ^ 1;
            if !active.contains(&sibling) {
                frontier += 1;
            }
        }
        active = active.into_iter().map(|position| position >> 1).collect();
        width >>= 1;
    }
    frontier
}

/// Детерминированно выводит уникальные позиции запросов. Это не Fiat-Shamir
/// реализация prover-а: для cost-model достаточно воспроизводимого набора,
/// позволяющего измерить дедупликацию multiproof.
pub fn deterministic_queries(query_count: usize, seed: u64, domain_size: usize) -> Vec<usize> {
    assert!(query_count <= domain_size);
    let mut state = seed;
    let mut positions = BTreeSet::new();
    while positions.len() < query_count {
        state = splitmix64(state);
        positions.insert((state as usize) & (domain_size - 1));
    }
    positions.into_iter().collect()
}

/// Считает FRI openings, multiproof frontier и число уникальных групп
/// свертки для конкретного schedule.
pub fn estimate_layout(schedule: &FriSchedule, query_count: usize, seed: u64) -> FriLayout {
    let mut current_positions: BTreeSet<usize> = deterministic_queries(query_count, seed, LDE_SIZE)
        .into_iter()
        .collect();
    let mut current_domain_size = LDE_SIZE;
    let mut opened_field_values = 0;
    let mut frontier_hashes = 0;
    let mut fold_groups = 0;

    for bits in &schedule.skip_bits {
        let arity = 1usize << bits;
        let mut opened = BTreeSet::new();
        let mut next_positions = BTreeSet::new();
        for position in &current_positions {
            let group_start = position & !(arity - 1);
            for offset in 0..arity {
                opened.insert(group_start + offset);
            }
            next_positions.insert(position >> bits);
        }
        let opened: Vec<_> = opened.into_iter().collect();
        opened_field_values += opened.len();
        frontier_hashes += merkle_frontier_count(current_domain_size, &opened);
        fold_groups += opened.len() / arity;
        current_positions = next_positions;
        current_domain_size >>= bits;
    }

    FriLayout {
        initial_domain_size: LDE_SIZE,
        final_domain_size: current_domain_size,
        query_count,
        opened_field_values,
        frontier_hashes,
        fold_groups,
        final_polynomial_values: schedule.last_layer_size,
    }
}

/// Перебирает все schedules из шагов `1..=4`, приводящие домен к
/// `last_layer_size`. Оптимизатор gas выбирает лучший вариант позднее.
pub fn enumerate_schedules(last_layer_size: usize) -> Vec<FriSchedule> {
    assert!(last_layer_size.is_power_of_two());
    let target_bits =
        LDE_SIZE.trailing_zeros() as usize - last_layer_size.trailing_zeros() as usize;
    let mut raw = Vec::new();
    enumerate_compositions(target_bits, &mut Vec::new(), &mut raw);
    raw.into_iter()
        .map(|skip_bits| FriSchedule::new(skip_bits, last_layer_size).unwrap())
        .collect()
}

fn enumerate_compositions(remaining: usize, prefix: &mut Vec<u8>, out: &mut Vec<Vec<u8>>) {
    if remaining == 0 {
        out.push(prefix.clone());
        return;
    }
    for bits in 1..=4.min(remaining) {
        prefix.push(bits as u8);
        enumerate_compositions(remaining - bits, prefix, out);
        prefix.pop();
    }
}

fn splitmix64(mut value: u64) -> u64 {
    value = value.wrapping_add(0x9e3779b97f4a7c15);
    value = (value ^ (value >> 30)).wrapping_mul(0xbf58476d1ce4e5b9);
    value = (value ^ (value >> 27)).wrapping_mul(0x94d049bb133111eb);
    value ^ (value >> 31)
}
