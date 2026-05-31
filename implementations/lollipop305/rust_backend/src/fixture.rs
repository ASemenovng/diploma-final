use crate::curve::{AffinePointFp, E_STICK_A, E_STICK_B};
use crate::params::{modulus_p, modulus_q, order_r, order_r_hat, p_hex, q_hex, r_hex, x_parameter};
use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct ParameterFixture {
    pub family: String,
    pub source: String,
    pub x_dec: String,
    pub p_dec: String,
    pub q_dec: String,
    pub r_dec: String,
    pub r_hat_dec: String,
    pub p_hex: String,
    pub q_hex: String,
    pub r_hex: String,
    pub fp_tower: String,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct StickCurveFixture {
    pub equation: String,
    pub generator_x_dec: String,
    pub generator_y_dec: String,
    pub generator_on_curve: bool,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct SmokeFixture {
    pub params: ParameterFixture,
    pub stick_curve: StickCurveFixture,
}

pub fn build_smoke_fixture() -> SmokeFixture {
    let g = AffinePointFp::sample_stick_point();
    SmokeFixture {
        params: ParameterFixture {
            family: "lollipop-305-158".to_string(),
            source: "ePrint 2024/1627, Appendix A, Example 1; lollipops-magma/lollipop-305-158.m"
                .to_string(),
            x_dec: x_parameter().to_string(),
            p_dec: modulus_p().to_string(),
            q_dec: modulus_q().to_string(),
            r_dec: order_r().to_string(),
            r_hat_dec: order_r_hat().to_string(),
            p_hex: p_hex(),
            q_hex: q_hex(),
            r_hex: r_hex(),
            fp_tower: "Fp2=Fp[u]/(u^2+1), Fp4=Fp2[v]/(v^2-(1+u))".to_string(),
        },
        stick_curve: StickCurveFixture {
            equation: "E/Fp: y^2 = x^3 + a*x + b".to_string(),
            generator_x_dec: g.x.dec(),
            generator_y_dec: g.y.dec(),
            generator_on_curve: g.is_on_curve(&E_STICK_A, &E_STICK_B),
        },
    }
}
