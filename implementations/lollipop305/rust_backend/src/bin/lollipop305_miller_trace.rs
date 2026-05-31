use lollipop305_backend::curve::AffinePointFp;
use lollipop305_backend::miller::{
    ate_loop_scalar, build_prepared_miller_trace, line_commitment_sha256_hex,
};
use serde::Serialize;

#[derive(Serialize)]
struct TraceSummary {
    family: &'static str,
    pairing_loop: &'static str,
    scalar_dec: String,
    naf_len: usize,
    step_count: usize,
    line_commitment_sha256: String,
    final_t_x_dec: String,
    final_t_y_dec: String,
    accumulator: lollipop305_backend::field::Fp4,
}

fn main() {
    let p = AffinePointFp::find_stick_point_from(1).expect("eval point");
    let q = AffinePointFp::find_stick_point_from(0).expect("source point");
    let scalar = ate_loop_scalar();
    let trace = build_prepared_miller_trace(&p, &q, &scalar).expect("trace");
    let summary = TraceSummary {
        family: "lollipop-305-158",
        pairing_loop: "ate loop over t-1 = x-1",
        scalar_dec: scalar.to_string(),
        naf_len: trace.naf_lsb.len(),
        step_count: trace.steps.len(),
        line_commitment_sha256: line_commitment_sha256_hex(&trace),
        final_t_x_dec: trace.final_t.x.dec(),
        final_t_y_dec: trace.final_t.y.dec(),
        accumulator: trace.accumulator,
    };
    println!("{}", serde_json::to_string_pretty(&summary).expect("json"));
}
