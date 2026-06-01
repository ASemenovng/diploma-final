use mnt_cycle_full::{
    build_cycle_report, check_cycle_field_equalities, mnt4_reference_pairing_digest,
    mnt6_reference_pairing_digest, CurveSide,
};

#[test]
fn mnt4_mnt6_field_equalities_hold() {
    let eq = check_cycle_field_equalities();
    assert!(eq.fr_mnt4_equals_fq_mnt6);
    assert!(eq.fr_mnt6_equals_fq_mnt4);
    assert!(eq.mnt4_fq_bits > 700);
    assert!(eq.mnt6_fq_bits > 700);
}

#[test]
fn both_reference_pairings_are_nontrivial_and_deterministic() {
    let mnt4_a = mnt4_reference_pairing_digest();
    let mnt4_b = mnt4_reference_pairing_digest();
    let mnt6_a = mnt6_reference_pairing_digest();
    let mnt6_b = mnt6_reference_pairing_digest();
    assert_eq!(mnt4_a, mnt4_b);
    assert_eq!(mnt6_a, mnt6_b);
    assert_ne!(mnt4_a, "0x00");
    assert_ne!(mnt6_a, "0x00");
    assert_ne!(mnt4_a, mnt6_a);
}

#[test]
fn report_contains_both_cycle_sides_and_constraints() {
    let report = build_cycle_report();
    assert_eq!(report.mnt4.side, CurveSide::Mnt4);
    assert_eq!(report.mnt6.side, CurveSide::Mnt6);
    assert_eq!(report.mnt4.native_base_mul_constraints, 1);
    assert_eq!(report.mnt6.native_base_mul_constraints, 1);
    assert!(report.mnt4.prepared_relation_constraints > 0);
    assert!(report.mnt6.prepared_relation_constraints > 0);
    assert!(report.bn254_non_native_sparse_miller_constraints > report.mnt4.prepared_relation_constraints);
    assert!(report.bn254_non_native_sparse_miller_constraints > report.mnt6.prepared_relation_constraints);
}

#[test]
fn mnt6_relation_uses_cubic_and_sextic_tower_costs() {
    let report = build_cycle_report();
    assert_eq!(report.mnt6.fq3_mul_constraints, Some(6));
    assert_eq!(report.mnt6.fq6_mul_constraints, Some(18));
    assert!(report.mnt6.one_miller_transition_constraints > report.mnt4.one_miller_transition_constraints);
}

#[test]
fn relation_accounting_uses_executable_ate_loop_counts() {
    let report = build_cycle_report();
    assert_eq!(report.mnt4.miller_rounds, 376);
    assert_eq!(report.mnt4.addition_steps, 124);
    assert_eq!(report.mnt4.prepared_relation_constraints, 24_126);
    assert_eq!(report.mnt6.miller_rounds, 376);
    assert_eq!(report.mnt6.addition_steps, 123);
    assert_eq!(report.mnt6.prepared_relation_constraints, 48_942);
}
