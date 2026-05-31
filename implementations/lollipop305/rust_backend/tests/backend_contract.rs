use lollipop305_backend::curve::{AffinePointFp, E_STICK_A, E_STICK_B};
use lollipop305_backend::field::{Fp, Fp2, Fp4};
use lollipop305_backend::fixture::build_smoke_fixture;
use lollipop305_backend::miller::{
    ate_loop_scalar, build_prepared_miller_trace, line_commitment_sha256_hex, naf_digits_lsb,
    PreparedLine,
};
use lollipop305_backend::params::{modulus_p, modulus_q, order_r, x_parameter};
use num_bigint::BigUint;
use num_traits::One;

#[test]
fn parameters_match_eprint1627_example_1_script() {
    let x = x_parameter();
    assert_eq!(modulus_p(), &x * &x - &x + BigUint::one());
    assert_eq!(modulus_q(), &x * &x + BigUint::one());
    assert_eq!(order_r().bits(), 158);
    assert_eq!(modulus_p().bits(), 305);
    assert_eq!(modulus_q().bits(), 305);
    assert_eq!(
        modulus_p().modpow(&BigUint::from(4u8), &order_r()),
        BigUint::one()
    );
    assert_ne!(
        modulus_p().modpow(&BigUint::from(1u8), &order_r()),
        BigUint::one()
    );
    assert_ne!(
        modulus_p().modpow(&BigUint::from(2u8), &order_r()),
        BigUint::one()
    );
}

#[test]
fn tower_arithmetic_matches_solidity_vectors() {
    let a = Fp2::new(Fp::from(3u64), Fp::from(5u64));
    let b = Fp2::new(Fp::from(7u64), Fp::from(11u64));
    let c = a.mul(&b);
    assert_eq!(c.c0, Fp::new(modulus_p() - BigUint::from(34u64)));
    assert_eq!(c.c1, Fp::from(68u64));

    let a4 = Fp4::from_u64s(3, 5, 7, 11);
    let b4 = Fp4::from_u64s(13, 17, 19, 23);
    let c4 = a4.mul(&b4);
    assert_eq!(c4.c0.c0, Fp::new(modulus_p() - BigUint::from(536u64)));
    assert_eq!(c4.c0.c1, Fp::from(366u64));
    assert_eq!(c4.c1.c0, Fp::new(modulus_p() - BigUint::from(154u64)));
    assert_eq!(c4.c1.c1, Fp::from(426u64));
}

#[test]
fn stick_curve_base_points_are_checked_against_equation() {
    let g = AffinePointFp::sample_stick_point();
    assert!(g.is_on_curve(&E_STICK_A, &E_STICK_B));
    let bad = AffinePointFp {
        x: g.x.clone(),
        y: g.y.add(&Fp::one()),
    };
    assert!(!bad.is_on_curve(&E_STICK_A, &E_STICK_B));
}

#[test]
fn backend_fixture_is_json_serializable_and_deterministic() {
    let fixture = build_smoke_fixture();
    let encoded = serde_json::to_string_pretty(&fixture).unwrap();
    assert!(encoded.contains("lollipop-305-158"));
    assert_eq!(fixture.params.p_dec, modulus_p().to_string());
    assert_eq!(fixture.params.r_dec, order_r().to_string());
    assert_eq!(fixture.stick_curve.generator_on_curve, true);
}

#[test]
fn curve_layer_addition_and_doubling_stay_on_curve() {
    let q = AffinePointFp::find_stick_point_from(0).unwrap();
    let p = AffinePointFp::find_stick_point_from(1).unwrap();
    let q2 = q.double().unwrap();
    let qp = q.add(&p).unwrap();
    assert!(q2.is_on_curve(&E_STICK_A, &E_STICK_B));
    assert!(qp.is_on_curve(&E_STICK_A, &E_STICK_B));
    assert_eq!(q.add(&q.neg()).unwrap(), AffinePointFp::infinity());
}

#[test]
fn prepared_lines_vanish_on_source_points() {
    let q = AffinePointFp::find_stick_point_from(0).unwrap();
    let q2 = q.double().unwrap();
    let dbl = PreparedLine::for_double(&q).unwrap();
    assert_eq!(dbl.evaluate_fp(&q), Fp::zero());
    assert_eq!(dbl.evaluate_fp(&q2.neg()), Fp::zero());

    let add = PreparedLine::for_add(&q2, &q).unwrap();
    assert_eq!(add.evaluate_fp(&q2), Fp::zero());
    assert_eq!(add.evaluate_fp(&q), Fp::zero());
    assert_eq!(add.evaluate_fp(&q2.add(&q).unwrap().neg()), Fp::zero());
}

#[test]
fn ate_loop_scalar_is_x_minus_one_and_has_non_adjacent_naf() {
    let scalar = ate_loop_scalar();
    assert_eq!(scalar, x_parameter() - BigUint::one());
    let naf = naf_digits_lsb(&scalar);
    assert!(naf.len() > 100);
    for pair in naf.windows(2) {
        assert!(
            pair[0] == 0 || pair[1] == 0,
            "NAF has adjacent non-zero digits"
        );
    }
}

#[test]
fn miller_core_matches_manual_prepared_trace_for_small_scalar() {
    let p = AffinePointFp::find_stick_point_from(1).unwrap();
    let q = AffinePointFp::find_stick_point_from(0).unwrap();
    let trace = build_prepared_miller_trace(&p, &q, &BigUint::from(13u64)).unwrap();
    assert!(trace.final_t.is_on_curve(&E_STICK_A, &E_STICK_B));
    assert_eq!(trace.steps.len(), 6); // NAF(13)=1,0,-1,0,1 -> 4 doubles + 2 signed additions.

    let mut manual = Fp4::one();
    for step in &trace.steps {
        if step.is_double {
            manual = manual.square();
        }
        manual = manual.mul(&step.line_value);
    }
    assert_eq!(manual, trace.accumulator);
}

#[test]
fn full_ate_prepared_trace_is_generated_from_rust_backend() {
    let p = AffinePointFp::find_stick_point_from(1).unwrap();
    let q = AffinePointFp::find_stick_point_from(0).unwrap();
    let trace = build_prepared_miller_trace(&p, &q, &ate_loop_scalar()).unwrap();
    assert!(trace.steps.len() > 150);
    assert!(trace.final_t.is_on_curve(&E_STICK_A, &E_STICK_B));
    assert_eq!(trace.final_t, q.scalar_mul(&ate_loop_scalar()).unwrap());
    assert!(line_commitment_sha256_hex(&trace).starts_with("0x"));
}

use lollipop305_backend::extension_curve::AffinePointFp4;
use lollipop305_backend::pairing::{
    final_exponent, miller_trace_fp4, reduced_ate_pairing_base_source,
};

#[test]
fn fp4_inverse_and_final_exponent_are_consistent() {
    let a = Fp4::from_u64s(3, 5, 7, 11);
    let inv = a.inverse().unwrap();
    assert_eq!(a.mul(&inv), Fp4::one());

    let y = final_exponent(&a);
    assert_eq!(y.pow(&order_r()), Fp4::one());
}

#[test]
fn extension_curve_embeds_base_curve_and_checks_subgroup_api() {
    let q = AffinePointFp::find_stick_point_from(0).unwrap();
    let q_ext = AffinePointFp4::from_fp_point(&q);
    assert!(q_ext.is_on_stick_curve());
    assert_eq!(q_ext.add(&q_ext.neg()).unwrap(), AffinePointFp4::infinity());

    let g1 = q
        .scalar_mul(&lollipop305_backend::params::cofactor_h())
        .unwrap();
    assert!(g1.is_on_curve(&E_STICK_A, &E_STICK_B));
    assert!(g1.scalar_mul(&order_r()).unwrap().is_infinity());
    assert!(AffinePointFp4::from_fp_point(&g1).is_in_r_subgroup());
}

#[test]
fn fp4_line_evaluation_extends_base_line_evaluation() {
    let eval = AffinePointFp::find_stick_point_from(1).unwrap();
    let q = AffinePointFp::find_stick_point_from(0).unwrap();
    let line = PreparedLine::for_double(&q).unwrap();
    assert_eq!(
        line.evaluate_fp4_point(&AffinePointFp4::from_fp_point(&eval)),
        line.evaluate_fp4(&eval)
    );
}

#[test]
fn fp4_miller_core_matches_base_core_on_embedded_eval_point() {
    let eval = AffinePointFp::find_stick_point_from(1).unwrap();
    let q = AffinePointFp::find_stick_point_from(0).unwrap();
    let base_trace = build_prepared_miller_trace(&eval, &q, &BigUint::from(13u64)).unwrap();
    let ext_trace = miller_trace_fp4(
        &AffinePointFp4::from_fp_point(&eval),
        &q,
        &BigUint::from(13u64),
    )
    .unwrap();
    assert_eq!(base_trace.accumulator, ext_trace.accumulator);
    assert_eq!(
        AffinePointFp4::from_fp_point(&base_trace.final_t),
        ext_trace.final_t
    );
}

#[test]
fn reduced_ate_pairing_smoke_result_lives_in_r_torsion_of_fp4_star() {
    let eval = AffinePointFp::find_stick_point_from(1).unwrap();
    let q = AffinePointFp::find_stick_point_from(0).unwrap();
    let y = reduced_ate_pairing_base_source(&AffinePointFp4::from_fp_point(&eval), &q).unwrap();
    assert_eq!(y.pow(&order_r()), Fp4::one());
}

#[test]
fn projective_fp4_matches_affine_for_small_scalar() {
    let p = AffinePointFp4::from_fp_point(&AffinePointFp::find_stick_point_from(1).unwrap());
    let scalar = BigUint::from(37u64);
    let affine = p.scalar_mul(&scalar).unwrap();
    let projective = lollipop305_backend::extension_curve::ProjectivePointFp4::from_affine(&p)
        .scalar_mul(&scalar)
        .to_affine()
        .unwrap();
    assert_eq!(projective, affine);
}

use lollipop305_backend::pairing::reduced_ate_pairing_twist_source;
use lollipop305_backend::twist::{sample_g1_generator, sample_g2_generator, untwist_to_fp4};

#[test]
fn lollipop305_twist_g2_generates_nontrivial_ate_pairing() {
    let p = sample_g1_generator().expect("deterministic G1 generator");
    let q_twist = sample_g2_generator().expect("deterministic G2 generator on twist");
    let q_full = untwist_to_fp4(&q_twist);

    assert!(p.is_on_curve(&E_STICK_A, &E_STICK_B));
    assert!(p.scalar_mul(&order_r()).unwrap().is_infinity());
    assert!(q_twist.is_on_twist_curve());
    assert!(q_twist.scalar_mul(&order_r()).unwrap().is_infinity());
    assert!(q_full.is_on_stick_curve());
    assert!(q_full.scalar_mul(&order_r()).unwrap().is_infinity());

    let y = reduced_ate_pairing_twist_source(&p, &q_twist).expect("reduced ate pairing");
    assert_ne!(y, Fp4::one(), "target ate pairing must be non-trivial");
    assert_eq!(
        y.pow(&order_r()),
        Fp4::one(),
        "pairing result must be in mu_r"
    );
}
