use lollipop305_backend::cycle::{sample_cycle_e_point, sample_cycle_ehat_point};
use lollipop305_backend::field_q::{Fq, Fq2};
use lollipop305_backend::params::{
    cycle_e_order, cycle_ehat_order, modulus_p, modulus_q, order_r, order_r_hat,
    supersingular_cycle_e_cofactor_q, supersingular_cycle_ehat_cofactor_p, x_parameter,
};
use num_bigint::BigUint;
use num_traits::One;

#[test]
fn lollipop305_formal_curve_relations_match_eprint1627() {
    let x = x_parameter();
    let p = modulus_p();
    let q = modulus_q();
    let nq = &x * &x - BigUint::from(2u8) * &x + BigUint::from(2u8);
    let np = &x * &x + &x + BigUint::one();

    assert_eq!(p, &x * &x - &x + BigUint::one());
    assert_eq!(q, &x * &x + BigUint::one());
    assert_eq!(cycle_e_order(), &q * &nq); // #E305(Fp2)=p^2+1=q*Nq
    assert_eq!(cycle_ehat_order(), &p * &np); // #Ehat305(Fq2)=q^2-q+1=p*Np
    assert_eq!(supersingular_cycle_e_cofactor_q(), nq);
    assert_eq!(supersingular_cycle_ehat_cofactor_p(), np);
    assert_eq!(order_r().bits(), 158);
    assert_eq!(order_r_hat().bits(), 158);
}

#[test]
fn fq2_arithmetic_for_q_field_is_a_quadratic_extension() {
    let eta = Fq2::new(Fq::zero(), Fq::one());
    assert_eq!(eta.square(), Fq2::new(Fq::from(2u64).neg(), Fq::zero()));
    let a = Fq2::new(Fq::from(3u64), Fq::from(5u64));
    let inv = a.inverse().expect("non-zero element has inverse");
    assert_eq!(a.mul(&inv), Fq2::one());
}

#[test]
fn supersingular_cycle_points_are_in_expected_prime_order_subgroups() {
    let p_on_cycle = sample_cycle_e_point().expect("q-order point on E305/Fp2");
    assert!(p_on_cycle.is_on_curve());
    assert!(p_on_cycle.scalar_mul(&modulus_q()).unwrap().is_infinity());
    assert!(!p_on_cycle.is_infinity());

    let q_on_cycle = sample_cycle_ehat_point().expect("p-order point on Ehat305/Fq2");
    assert!(q_on_cycle.is_on_curve());
    assert!(q_on_cycle.scalar_mul(&modulus_p()).unwrap().is_infinity());
    assert!(!q_on_cycle.is_infinity());
}
