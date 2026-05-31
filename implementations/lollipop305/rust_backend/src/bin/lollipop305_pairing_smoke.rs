use lollipop305_backend::curve::AffinePointFp;
use lollipop305_backend::extension_curve::AffinePointFp4;
use lollipop305_backend::miller::ate_loop_scalar;
use lollipop305_backend::pairing::{
    final_exponent_value, miller_trace_fp4, reduced_ate_pairing_base_source,
};
use lollipop305_backend::params::order_r;
use serde::Serialize;

#[derive(Serialize)]
struct PairingSmokeSummary {
    family: &'static str,
    mode: &'static str,
    scalar_dec: String,
    final_exponent_bits: u64,
    source_q_on_curve: bool,
    eval_p_on_curve_fp4: bool,
    eval_p_in_r_subgroup: bool,
    step_count: usize,
    reduced_result: lollipop305_backend::field::Fp4,
    reduced_result_pow_r_is_one: bool,
}

fn main() {
    let source_q = AffinePointFp::find_stick_point_from(0).expect("source point");
    let eval_p = AffinePointFp4::from_fp_point(
        &AffinePointFp::find_stick_point_from(1).expect("eval point"),
    );
    let trace = miller_trace_fp4(&eval_p, &source_q, &ate_loop_scalar()).expect("miller trace");
    let y = reduced_ate_pairing_base_source(&eval_p, &source_q).expect("reduced pairing");
    let summary = PairingSmokeSummary {
        family: "lollipop-305-158",
        mode: "research smoke: ate Miller over E(Fp4) with base-field source Q",
        scalar_dec: ate_loop_scalar().to_string(),
        final_exponent_bits: final_exponent_value().bits(),
        source_q_on_curve: source_q.is_on_curve(
            &lollipop305_backend::curve::E_STICK_A,
            &lollipop305_backend::curve::E_STICK_B,
        ),
        eval_p_on_curve_fp4: eval_p.is_on_stick_curve(),
        eval_p_in_r_subgroup: eval_p.is_in_r_subgroup(),
        step_count: trace.steps.len(),
        reduced_result: y.clone(),
        reduced_result_pow_r_is_one: y.pow(&order_r()) == lollipop305_backend::field::Fp4::one(),
    };
    println!("{}", serde_json::to_string_pretty(&summary).expect("json"));
}
