use lollipop305_backend::extension_curve::AffinePointFp4;
use lollipop305_backend::miller::ate_loop_scalar;
use lollipop305_backend::pairing::{
    final_exponent, final_exponent_value, miller_trace_full_fp4, reduced_ate_pairing_twist_source,
};
use lollipop305_backend::params::{modulus_p, order_r};
use lollipop305_backend::twist::{sample_g1_generator, sample_g2_generator, untwist_to_fp4};
use serde::Serialize;

#[derive(Serialize)]
struct Fp2Dec {
    c0: String,
    c1: String,
}

#[derive(Serialize)]
struct Fp4Dec {
    c0: Fp2Dec,
    c1: Fp2Dec,
}

#[derive(Serialize)]
struct FpPointDec {
    x: String,
    y: String,
}

#[derive(Serialize)]
struct Fp2PointDec {
    x: Fp2Dec,
    y: Fp2Dec,
}

#[derive(Serialize)]
struct Fp4PointDec {
    x: Fp4Dec,
    y: Fp4Dec,
}

#[derive(Serialize)]
struct Lollipop305TwistPairingVector {
    family: &'static str,
    tower: &'static str,
    twist: &'static str,
    pairing: &'static str,
    loop_scalar_dec: String,
    final_exponent_dec: String,
    p: FpPointDec,
    q_twist: Fp2PointDec,
    q_untwisted: Fp4PointDec,
    step_count: usize,
    final_t_is_infinity: bool,
    frobenius_q_equals_p_times_q: bool,
    result: Fp4Dec,
    result_is_one: bool,
    result_pow_r_is_one: bool,
}

fn fp2(x: &lollipop305_backend::field::Fp2) -> Fp2Dec {
    Fp2Dec {
        c0: x.c0.dec(),
        c1: x.c1.dec(),
    }
}

fn fp4(x: &lollipop305_backend::field::Fp4) -> Fp4Dec {
    Fp4Dec {
        c0: fp2(&x.c0),
        c1: fp2(&x.c1),
    }
}

fn frobenius_p_point(p: &AffinePointFp4) -> AffinePointFp4 {
    if p.is_infinity() {
        return AffinePointFp4::infinity();
    }
    let q = modulus_p();
    AffinePointFp4 {
        x: p.x.pow(&q),
        y: p.y.pow(&q),
        infinity: false,
    }
}

fn main() {
    let p = sample_g1_generator().expect("deterministic G1 generator");
    let q_twist = sample_g2_generator().expect("deterministic G2 generator");
    let q_full = untwist_to_fp4(&q_twist);
    let p_full = AffinePointFp4::from_fp_point(&p);
    let trace = miller_trace_full_fp4(&p_full, &q_full, &ate_loop_scalar()).expect("Miller trace");
    let result = reduced_ate_pairing_twist_source(&p, &q_twist).expect("reduced ate pairing");
    let p_mod_r = modulus_p() % order_r();
    let frobenius_check = frobenius_p_point(&q_full) == q_full.scalar_mul(&p_mod_r).expect("[p]Q");

    let vector = Lollipop305TwistPairingVector {
        family: "lollipop-305-158",
        tower: "Fp2=Fp[u]/(u^2+1), Fp4=Fp2[v]/(v^2-(1+u))",
        twist: "E': Y^2 = X^3 + (a/(1+u)^2)X + b/(1+u)^3; psi(X,Y)=((1+u)X,(1+u)vY)",
        pairing: "reduced ate pairing a_T(P,Q)=f_{T,Q}(P)^((p^4-1)/r), T=x-1",
        loop_scalar_dec: ate_loop_scalar().to_string(),
        final_exponent_dec: final_exponent_value().to_string(),
        p: FpPointDec {
            x: p.x.dec(),
            y: p.y.dec(),
        },
        q_twist: Fp2PointDec {
            x: fp2(&q_twist.x),
            y: fp2(&q_twist.y),
        },
        q_untwisted: Fp4PointDec {
            x: fp4(&q_full.x),
            y: fp4(&q_full.y),
        },
        step_count: trace.steps.len(),
        final_t_is_infinity: trace.final_t.is_infinity(),
        frobenius_q_equals_p_times_q: frobenius_check,
        result: fp4(&result),
        result_is_one: result.is_one(),
        result_pow_r_is_one: result.pow(&order_r()).is_one(),
    };
    println!("{}", serde_json::to_string_pretty(&vector).expect("json"));

    // Keep the binary useful as a CI sanity-check: panic if the target pairing is degenerate.
    assert!(frobenius_check);
    assert!(!result.is_one());
    assert_eq!(
        result.pow(&order_r()),
        lollipop305_backend::field::Fp4::one()
    );
    assert_eq!(final_exponent(&trace.accumulator), result);
}
