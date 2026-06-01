use native_fri_cost_model::{
    fri::{estimate_layout, merkle_frontier_count, FriSchedule},
    model::{
        basis_candidates, block_partition_candidates, estimate_profile,
        experimental_deep_sensitivity, optimize_strict_profile, sensitivity_grid, BasisChoice,
        ModelAssumptions,
    },
    report::{render_json, render_markdown},
    security::ordinary_fri_security,
};

#[test]
fn ordinary_fri_security_matches_formal_specification() {
    let report = ordinary_fri_security(576);
    assert_eq!(report.lde_size, 32_768);
    assert_eq!(report.degree_envelope, 4_096);
    assert!((report.rate - 0.125).abs() < 1e-12);
    assert!((report.delta0 - 0.150_725_7).abs() < 1e-6);
    assert_eq!(report.minimum_queries_for_128_bits, 544);
    assert!(report.fri_soundness_bits > 135.0);
    assert!(report.production_eligible);
}

#[test]
fn merkle_frontier_counts_minimal_binary_multiproof() {
    assert_eq!(merkle_frontier_count(8, &[0]), 3);
    assert_eq!(merkle_frontier_count(8, &[0, 1]), 2);
    assert_eq!(merkle_frontier_count(8, &[0, 1, 2, 3]), 1);
    assert_eq!(merkle_frontier_count(8, &[0, 1, 2, 3, 4, 5, 6, 7]), 0);
}

#[test]
fn layer_skipping_schedule_folds_full_domain_to_last_layer() {
    let schedule = FriSchedule::new(vec![1, 2, 2, 4, 2], 16).unwrap();
    assert_eq!(schedule.total_fold_bits(), 11);
    let layout = estimate_layout(&schedule, 576, 7);
    assert_eq!(layout.initial_domain_size, 32_768);
    assert_eq!(layout.final_domain_size, 16);
    assert!(layout.opened_field_values > 0);
    assert!(layout.frontier_hashes > 0);
}

#[test]
fn strict_optimizer_produces_a_reproducible_stop_go_decision() {
    let assumptions = ModelAssumptions::default();
    let schedule = FriSchedule::new(vec![1, 2, 2, 4, 2], 16).unwrap();
    let estimate = estimate_profile(&assumptions, schedule.clone(), 576);
    let repeated = estimate_profile(&assumptions, schedule, 576);
    assert_eq!(estimate, repeated);
    assert!(estimate.security.production_eligible);
    assert_eq!(estimate.query_count, 576);
    assert_eq!(
        estimate.stop_go.beats_article640_fixed_shards,
        estimate.expected.total_gas < assumptions.article640_fixed_shards_gas
    );
}

#[test]
fn profile_estimate_exposes_major_cost_components() {
    let assumptions = ModelAssumptions::default();
    let schedule = FriSchedule::new(vec![1, 2, 2, 4, 2], 16).unwrap();
    let estimate = estimate_profile(&assumptions, schedule, 576);
    assert!(estimate.expected.fri_calldata_gas > 0);
    assert!(estimate.expected.source_calldata_gas > 0);
    assert!(estimate.expected.fri_arithmetic_gas > 0);
    assert!(estimate.expected.relation_arithmetic_gas > 0);
    assert!(estimate.expected.merkle_execution_gas > 0);
    assert!(estimate.lower_bound.total_gas < estimate.expected.total_gas);
    assert_eq!(
        estimate.proof_bytes * assumptions.calldata_gas_per_nonzero_byte,
        estimate.lower_bound.fri_calldata_gas + estimate.lower_bound.source_calldata_gas
    );
    assert!(estimate.operations.expected_fq_muls > estimate.operations.minimum_fq_muls);
    assert!(estimate.operations.expected_fq_adds > 0);
    assert_eq!(estimate.operations.fq_inversions, 0);
    assert_eq!(estimate.segment_count, 1);
}

#[test]
fn block_partition_model_selects_article640_d5_baseline() {
    let candidates = block_partition_candidates();
    let best = candidates
        .iter()
        .min_by(|left, right| left.heuristic_cost.total_cmp(&right.heuristic_cost))
        .unwrap();
    assert_eq!(best.block_size, 5);
}

#[test]
fn report_marks_deep_fri_profiles_as_experimental() {
    let assumptions = ModelAssumptions::default();
    let schedule = FriSchedule::new(vec![1, 2, 2, 4, 2], 16).unwrap();
    let strict = estimate_profile(&assumptions, schedule, 576);
    let deep = experimental_deep_sensitivity(&assumptions, &strict.schedule);
    assert!(deep.iter().all(|profile| !profile.production_eligible));
    let sensitivity = sensitivity_grid(&assumptions, &strict.schedule);
    let json = render_json(&assumptions, &strict, &deep, &sensitivity);
    let markdown = render_markdown(&assumptions, &strict, &deep, &sensitivity);
    assert!(json.contains("\"strict_profile\""));
    assert!(json.contains("\"deep_fri_profiles_are_experimental\": true"));
    assert!(markdown.contains("не является production-профилем"));
    assert!(markdown.contains("Article640 fixed-shards"));
    assert_eq!(BasisChoice::Tower.as_str(), "tower");
}

#[test]
fn strict_optimizer_compares_last_layer_sizes_and_basis_candidates() {
    let assumptions = ModelAssumptions::default();
    let best = optimize_strict_profile(&assumptions);
    assert!([8, 16, 32, 64].contains(&best.schedule.last_layer_size));
    let basis = basis_candidates();
    assert_eq!(basis.len(), 2);
    assert!(basis.iter().any(|candidate| {
        candidate.basis == BasisChoice::Tower && candidate.production_eligible
    }));
    assert!(basis.iter().any(|candidate| {
        candidate.basis == BasisChoice::Normal && !candidate.production_eligible
    }));
}
