use lollipop305_backend::cycle_pairing::{
    build_cycle_e_miller_core_fixture, build_cycle_e_distorted_article640_fixture,
    build_cycle_ehat_ate_residue_fixture, build_cycle_ehat_weil_fixture,
    check_cycle_ehat_weil_pairing, cycle_e_final_exponent,
};
use lollipop305_backend::field::Fp4;
use lollipop305_backend::params::modulus_q;

#[test]
fn cycle_e_miller_core_fixture_is_generated_for_full_q_loop() {
    let fixture = build_cycle_e_miller_core_fixture().expect("cycle E Miller core fixture");
    assert!(fixture.steps.len() > 300, "q-order loop must be longer than stick r-loop");
    assert_ne!(fixture.core, Fp4::zero());
    assert_eq!(fixture.scalar_dec, modulus_q().to_string());
}

#[test]
fn cycle_e_distorted_fixture_satisfies_direct_and_residue_relations() {
    let fixture = build_cycle_e_distorted_article640_fixture().expect("distorted cycle E fixture");
    assert!(fixture.steps.len() > 300);
    assert_eq!(cycle_e_final_exponent(&fixture.core), Fp4::one());
    assert_eq!(fixture.c.mul(&fixture.c_inv), Fp4::one());
    assert_eq!(fixture.c.pow(&modulus_q()), fixture.core);
}

#[test]
fn cycle_ehat_weil_pairing_relation_is_nontrivial_and_correct() {
    let check = check_cycle_ehat_weil_pairing().expect("Ehat Weil pairing check");
    assert!(check.q_on_curve, "distorted Q must lie on Ehat/Fq6");
    assert!(check.p_torsion, "P must be in the p-torsion subgroup");
    assert!(check.q_torsion, "distorted Q must be in the p-torsion subgroup");
    assert!(check.frobenius_eigen, "distorted Q must satisfy the q^2-Frobenius eigenspace relation");
    assert!(check.pairing_nontrivial, "Weil pairing must be non-trivial");
    assert!(check.pairing_order_p, "Weil pairing value must lie in mu_p");
    assert!(check.product_with_neg_is_one, "e(P,Q) * e(-P,Q) must be one");
}

#[test]
fn cycle_ehat_weil_fixture_satisfies_product_relation() {
    let fixture = build_cycle_ehat_weil_fixture().expect("Ehat Weil fixture");
    assert!(fixture.f_p_q_steps.len() > 300);
    assert_eq!(fixture.f_p_q.mul(&fixture.f_neg_p_q), fixture.lhs);
    assert_eq!(fixture.f_q_p.mul(&fixture.f_q_neg_p), fixture.rhs);
    assert_eq!(fixture.lhs, fixture.rhs);
}

#[test]
fn cycle_ehat_ate_residue_fixture_satisfies_num_den_relation() {
    let fixture = build_cycle_ehat_ate_residue_fixture().expect("Ehat Ate/residue fixture");
    assert!(fixture.lines.len() > 200, "x-1 Ate loop should generate many prepared records");
    assert!(fixture.lines.iter().any(|line| !line.is_double), "fixture must include addition records");
    assert!(fixture.c_to_p_equals_f);
    assert!(fixture.residue_check);
    assert_eq!(fixture.c.pow(&lollipop305_backend::params::modulus_p()).mul(&fixture.f_den), fixture.f_num);
}
