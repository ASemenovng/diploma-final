//! JSON и Markdown отчеты N1 без внешних serialization-зависимостей.

use crate::model::{
    basis_candidates, block_partition_candidates, ExperimentalDeepProfile, ModelAssumptions,
    ProfileEstimate, SensitivityRow,
};

pub fn render_json(
    assumptions: &ModelAssumptions,
    strict: &ProfileEstimate,
    deep: &[ExperimentalDeepProfile],
    sensitivity: &[SensitivityRow],
) -> String {
    let deep_rows = deep
        .iter()
        .map(|row| {
            format!(
                "    {{\"query_count\": {}, \"expected_total_gas\": {}, \"production_eligible\": false}}",
                row.query_count, row.expected_total_gas
            )
        })
        .collect::<Vec<_>>()
        .join(",\n");
    let sensitivity_rows = sensitivity
        .iter()
        .map(|row| {
            format!(
                "    {{\"source_columns\": {}, \"relation_muls_per_query\": {}, \"expected_total_gas\": {}, \"beats_article640\": {}, \"reaches_60m_target\": {}}}",
                row.source_leaf_dynamic_columns,
                row.relation_muls_per_query,
                row.expected_total_gas,
                row.beats_article640_fixed_shards,
                row.reaches_desired_target
            )
        })
        .collect::<Vec<_>>()
        .join(",\n");

    format!(
        concat!(
            "{{\n",
            "  \"model\": \"MNT4 native-field Merkle/FRI N1 cost model\",\n",
            "  \"strict_profile\": {{\n",
            "    \"name\": \"{}\",\n",
            "    \"query_count\": {},\n",
            "    \"minimum_queries_for_128_bits\": {},\n",
            "    \"fri_soundness_bits\": {:.6},\n",
            "    \"schedule\": {:?},\n",
            "    \"source_opened_rows\": {},\n",
            "    \"fri_opened_field_values\": {},\n",
            "    \"fri_frontier_hashes\": {},\n",
            "    \"proof_bytes\": {},\n",
            "    \"segment_count\": {},\n",
            "    \"operations\": {{\"minimum_fq_muls\": {}, \"expected_fq_muls\": {}, \"expected_fq_adds\": {}, \"fq_inversions\": {}, \"merkle_hashes\": {}, \"fixed_shard_words\": {}}},\n",
            "    \"lower_bound_total_gas\": {},\n",
            "    \"expected_total_gas\": {},\n",
            "    \"beats_article640_fixed_shards\": {},\n",
            "    \"reaches_60m_target\": {}\n",
            "  }},\n",
            "  \"article640_fixed_shards_gas\": {},\n",
            "  \"desired_target_gas\": {},\n",
            "  \"deep_fri_profiles_are_experimental\": true,\n",
            "  \"deep_fri_sensitivity\": [\n{}\n  ],\n",
            "  \"ordinary_fri_sensitivity\": [\n{}\n  ]\n",
            "}}\n"
        ),
        strict.profile_name,
        strict.query_count,
        strict.security.minimum_queries_for_128_bits,
        strict.security.fri_soundness_bits,
        strict.schedule.skip_bits,
        strict.source_opened_rows,
        strict.fri_opened_field_values,
        strict.fri_frontier_hashes,
        strict.proof_bytes,
        strict.segment_count,
        strict.operations.minimum_fq_muls,
        strict.operations.expected_fq_muls,
        strict.operations.expected_fq_adds,
        strict.operations.fq_inversions,
        strict.operations.merkle_hashes,
        strict.operations.fixed_shard_words,
        strict.lower_bound.total_gas,
        strict.expected.total_gas,
        strict.stop_go.beats_article640_fixed_shards,
        strict.stop_go.reaches_desired_target,
        assumptions.article640_fixed_shards_gas,
        assumptions.desired_target_gas,
        deep_rows,
        sensitivity_rows
    )
}

pub fn render_markdown(
    assumptions: &ModelAssumptions,
    strict: &ProfileEstimate,
    deep: &[ExperimentalDeepProfile],
    sensitivity: &[SensitivityRow],
) -> String {
    let mut out = String::new();
    out.push_str("# N1: Rust cost-model нативной MNT4 Merkle/FRI-схемы\n\n");
    out.push_str("## Статус\n\n");
    out.push_str("Модель реализована до написания Solidity verifier-а. Она не подменяет реальный gas-report: нижняя оценка содержит обязательные данные и FRI-арифметику, ожидаемая оценка дополнительно использует явно перечисленные инженерные бюджеты.\n\n");
    out.push_str("DEEP-FRI строки ниже являются экспериментальными. Без отдельной инстанциации конкретной DEEP-FRI теоремы ни один такой профиль не является production-профилем.\n\n");
    out.push_str("## Строгий ordinary-FRI профиль\n\n");
    out.push_str(&format!(
        "- `rho = 1/8`, `delta0 = {:.7}`;\n- минимум запросов для `128 bit`: `{}`;\n- выбранный production-профиль: `{}` запросов, FRI-вклад `{:.3} bit`;\n- schedule: `{:?}`, последний слой `{}`;\n- раскрыто source rows: `{}`;\n- раскрыто FRI field values: `{}`;\n- Merkle frontier FRI: `{}` хешей;\n- обязательная calldata: `{}` байт;\n- сегментов LDE-домена: `{}`.\n\n",
        strict.security.delta0,
        strict.security.minimum_queries_for_128_bits,
        strict.query_count,
        strict.security.fri_soundness_bits,
        strict.schedule.skip_bits,
        strict.schedule.last_layer_size,
        strict.source_opened_rows,
        strict.fri_opened_field_values,
        strict.fri_frontier_hashes,
        strict.proof_bytes,
        strict.segment_count
    ));
    out.push_str("## Разложение стоимости strict-профиля\n\n");
    out.push_str("| Компонент | Нижняя оценка, gas | Ожидаемая оценка, gas |\n|---|---:|---:|\n");
    push_component(
        &mut out,
        "FRI calldata",
        strict.lower_bound.fri_calldata_gas,
        strict.expected.fri_calldata_gas,
    );
    push_component(
        &mut out,
        "Source calldata",
        strict.lower_bound.source_calldata_gas,
        strict.expected.source_calldata_gas,
    );
    push_component(
        &mut out,
        "FRI arithmetic",
        strict.lower_bound.fri_arithmetic_gas,
        strict.expected.fri_arithmetic_gas,
    );
    push_component(
        &mut out,
        "Локальные relations",
        strict.lower_bound.relation_arithmetic_gas,
        strict.expected.relation_arithmetic_gas,
    );
    push_component(
        &mut out,
        "Чтение fixed shards",
        strict.lower_bound.fixed_shard_reads_gas,
        strict.expected.fixed_shard_reads_gas,
    );
    push_component(
        &mut out,
        "Merkle execution",
        strict.lower_bound.merkle_execution_gas,
        strict.expected.merkle_execution_gas,
    );
    push_component(
        &mut out,
        "Глобальные relations",
        strict.lower_bound.global_relation_gas,
        strict.expected.global_relation_gas,
    );
    push_component(
        &mut out,
        "Control-flow budget",
        strict.lower_bound.control_flow_overhead_gas,
        strict.expected.control_flow_overhead_gas,
    );
    push_component(
        &mut out,
        "**Итого**",
        strict.lower_bound.total_gas,
        strict.expected.total_gas,
    );
    out.push('\n');
    out.push_str(&format!(
        "Article640 fixed-shards baseline: `{}` gas. Желаемая цель: `{}` gas.\n\n",
        assumptions.article640_fixed_shards_gas, assumptions.desired_target_gas
    ));
    out.push_str(&format!(
        "Stop/go относительно Article640: **{}**. Цель `< 60M`: **{}**.\n\n",
        yes_no(strict.stop_go.beats_article640_fixed_shards),
        yes_no(strict.stop_go.reaches_desired_target)
    ));
    out.push_str(
        "## Базовые операции ожидаемого профиля\n\n| Операция | Количество |\n|---|---:|\n",
    );
    out.push_str(&format!(
        "| Минимально необходимые `Fq mul` для FRI | {} |\n| Ожидаемые `Fq mul` | {} |\n| Ожидаемые `Fq add` | {} |\n| `Fq inv` | {} |\n| Merkle hashes | {} |\n| Слова fixed shards | {} |\n\n",
        strict.operations.minimum_fq_muls,
        strict.operations.expected_fq_muls,
        strict.operations.expected_fq_adds,
        strict.operations.fq_inversions,
        strict.operations.merkle_hashes,
        strict.operations.fixed_shard_words
    ));
    out.push_str(
        "## Блочное сжатие\n\n| Размер блока `d` | Эвристика Article640 `C(d)` |\n|---:|---:|\n",
    );
    for row in block_partition_candidates() {
        out.push_str(&format!(
            "| {} | {:.3} |\n",
            row.block_size, row.heuristic_cost
        ));
    }
    out.push_str("\nМинимум равномерной эвристики достигается при `d=5`. Adaptive partition должен быть уточнен индексатором на этапе N2.\n\n");
    out.push_str(
        "## Basis-кандидаты\n\n| Basis | Production-статус | Пояснение |\n|---|---|---|\n",
    );
    for row in basis_candidates() {
        out.push_str(&format!(
            "| `{}` | {} | {} |\n",
            row.basis.as_str(),
            yes_no(row.production_eligible),
            row.note
        ));
    }
    out.push('\n');
    out.push_str("## Экспериментальный диапазон DEEP-FRI\n\n| Запросы | Ожидаемая стоимость, gas | Production-статус |\n|---:|---:|---|\n");
    for row in deep {
        out.push_str(&format!(
            "| {} | {} | нет: требуется отдельная теорема |\n",
            row.query_count, row.expected_total_gas
        ));
    }
    out.push_str("\n## Sensitivity strict ordinary FRI\n\n| Source columns | Relation mul/query | Expected gas | Ниже Article640 | Ниже 60M |\n|---:|---:|---:|---|---|\n");
    for row in sensitivity {
        out.push_str(&format!(
            "| {} | {} | {} | {} | {} |\n",
            row.source_leaf_dynamic_columns,
            row.relation_muls_per_query,
            row.expected_total_gas,
            yes_no(row.beats_article640_fixed_shards),
            yes_no(row.reaches_desired_target)
        ));
    }
    out.push_str("\n## Ограничения N1\n\n- Это Rust cost-model, а не измерение Solidity.\n- `relation_muls_per_query`, технический Keccak budget и control-flow budget являются явными допущениями.\n- Normal basis пока не выбран: его преимущество должно подтверждаться индексатором и измерением конверсий.\n- DEEP-FRI нельзя использовать для production stop/go до численной инстанциации его теоремы.\n");
    out
}

fn push_component(out: &mut String, name: &str, lower: u64, expected: u64) {
    out.push_str(&format!("| {} | {} | {} |\n", name, lower, expected));
}

fn yes_no(value: bool) -> &'static str {
    if value {
        "да"
    } else {
        "нет"
    }
}
