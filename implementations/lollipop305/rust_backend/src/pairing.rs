use crate::curve::AffinePointFp;
use crate::extension_curve::AffinePointFp4;
use crate::field::Fp4;
use crate::miller::{ate_loop_scalar, naf_digits_lsb, PreparedLine};
use crate::params::{modulus_p, order_r};
use num_bigint::BigUint;
use num_traits::One;
use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub struct MillerStepFp4 {
    pub is_double: bool,
    pub naf_digit: i8,
    pub line: PreparedLine,
    pub line_value: Fp4,
    pub accumulator_after: Fp4,
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub struct MillerTraceFp4 {
    pub loop_scalar_dec: String,
    pub naf_lsb: Vec<i8>,
    pub steps: Vec<MillerStepFp4>,
    pub final_t: AffinePointFp4,
    pub accumulator: Fp4,
}

pub fn final_exponent_value() -> BigUint {
    let p = modulus_p();
    (p.pow(4) - BigUint::one()) / order_r()
}

pub fn final_exponent(f: &Fp4) -> Fp4 {
    f.pow(&final_exponent_value())
}

pub fn miller_trace_fp4(
    eval_point: &AffinePointFp4,
    q: &AffinePointFp,
    scalar: &BigUint,
) -> Option<MillerTraceFp4> {
    if !eval_point.is_on_stick_curve() {
        return None;
    }
    let naf = naf_digits_lsb(scalar);
    if naf.is_empty() {
        return None;
    }
    let mut t = q.clone();
    let mut f = Fp4::one();
    let mut steps = Vec::new();

    for idx in (0..naf.len() - 1).rev() {
        let dbl = PreparedLine::for_double(&t)?;
        let dbl_value = dbl.evaluate_fp4_point(eval_point);
        f = f.square().mul(&dbl_value);
        t = t.double()?;
        steps.push(MillerStepFp4 {
            is_double: true,
            naf_digit: 0,
            line: dbl,
            line_value: dbl_value,
            accumulator_after: f.clone(),
        });

        match naf[idx] {
            1 => {
                let add = PreparedLine::for_add(&t, q)?;
                let value = add.evaluate_fp4_point(eval_point);
                f = f.mul(&value);
                t = t.add(q)?;
                steps.push(MillerStepFp4 {
                    is_double: false,
                    naf_digit: 1,
                    line: add,
                    line_value: value,
                    accumulator_after: f.clone(),
                });
            }
            -1 => {
                let sub = PreparedLine::for_sub(&t, q)?;
                let value = sub.evaluate_fp4_point(eval_point);
                f = f.mul(&value);
                t = t.add(&q.neg())?;
                steps.push(MillerStepFp4 {
                    is_double: false,
                    naf_digit: -1,
                    line: sub,
                    line_value: value,
                    accumulator_after: f.clone(),
                });
            }
            0 => {}
            _ => return None,
        }
    }

    Some(MillerTraceFp4 {
        loop_scalar_dec: scalar.to_string(),
        naf_lsb: naf,
        steps,
        final_t: AffinePointFp4::from_fp_point(&t),
        accumulator: f,
    })
}

pub fn reduced_ate_pairing_base_source(
    eval_point: &AffinePointFp4,
    q: &AffinePointFp,
) -> Option<Fp4> {
    let trace = miller_trace_fp4(eval_point, q, &ate_loop_scalar())?;
    Some(final_exponent(&trace.accumulator))
}

use crate::twist::{untwist_to_fp4, AffinePointFp2Twist};

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub struct PreparedLineFp4 {
    pub x_coeff: Fp4,
    pub const_coeff: Fp4,
}

impl PreparedLineFp4 {
    pub fn for_double(p: &AffinePointFp4) -> Option<Self> {
        if p.is_infinity() || p.y.is_zero() {
            return None;
        }
        let three = Fp4::from_fp(crate::field::Fp::from(3u64));
        let two = Fp4::from_fp(crate::field::Fp::from(2u64));
        let lambda = three
            .mul(&p.x.square())
            .add(&Fp4::from_fp(crate::curve::e_stick_a()))
            .mul(&two.mul(&p.y).inverse()?);
        Some(Self::from_slope(p, &lambda))
    }

    pub fn for_add(a: &AffinePointFp4, b: &AffinePointFp4) -> Option<Self> {
        if a.is_infinity() || b.is_infinity() {
            return None;
        }
        if a.x == b.x {
            if a.y == b.y {
                return Self::for_double(a);
            }
            return None;
        }
        let lambda = b.y.sub(&a.y).mul(&b.x.sub(&a.x).inverse()?);
        Some(Self::from_slope(a, &lambda))
    }

    pub fn for_sub(a: &AffinePointFp4, b: &AffinePointFp4) -> Option<Self> {
        Self::for_add(a, &b.neg())
    }

    fn from_slope(p: &AffinePointFp4, lambda: &Fp4) -> Self {
        let nu = p.y.sub(&lambda.mul(&p.x));
        Self {
            x_coeff: lambda.neg(),
            const_coeff: nu.neg(),
        }
    }

    pub fn evaluate(&self, p: &AffinePointFp4) -> Fp4 {
        if p.is_infinity() {
            return Fp4::zero();
        }
        p.y.add(&self.x_coeff.mul(&p.x)).add(&self.const_coeff)
    }
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub struct MillerStepFullFp4 {
    pub is_double: bool,
    pub naf_digit: i8,
    pub line: PreparedLineFp4,
    pub line_value: Fp4,
    pub accumulator_after: Fp4,
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub struct MillerTraceFullFp4 {
    pub loop_scalar_dec: String,
    pub naf_lsb: Vec<i8>,
    pub steps: Vec<MillerStepFullFp4>,
    pub final_t: AffinePointFp4,
    pub accumulator: Fp4,
}

pub fn miller_trace_full_fp4(
    eval_point: &AffinePointFp4,
    source_q: &AffinePointFp4,
    scalar: &BigUint,
) -> Option<MillerTraceFullFp4> {
    if !eval_point.is_on_stick_curve() || !source_q.is_on_stick_curve() {
        return None;
    }
    let naf = naf_digits_lsb(scalar);
    if naf.is_empty() {
        return None;
    }
    let mut t = source_q.clone();
    let mut f = Fp4::one();
    let mut steps = Vec::new();

    for idx in (0..naf.len() - 1).rev() {
        let dbl = PreparedLineFp4::for_double(&t)?;
        let dbl_value = dbl.evaluate(eval_point);
        f = f.square().mul(&dbl_value);
        t = t.double()?;
        steps.push(MillerStepFullFp4 {
            is_double: true,
            naf_digit: 0,
            line: dbl,
            line_value: dbl_value,
            accumulator_after: f.clone(),
        });

        match naf[idx] {
            1 => {
                let add = PreparedLineFp4::for_add(&t, source_q)?;
                let value = add.evaluate(eval_point);
                f = f.mul(&value);
                t = t.add(source_q)?;
                steps.push(MillerStepFullFp4 {
                    is_double: false,
                    naf_digit: 1,
                    line: add,
                    line_value: value,
                    accumulator_after: f.clone(),
                });
            }
            -1 => {
                let sub = PreparedLineFp4::for_sub(&t, source_q)?;
                let value = sub.evaluate(eval_point);
                f = f.mul(&value);
                t = t.add(&source_q.neg())?;
                steps.push(MillerStepFullFp4 {
                    is_double: false,
                    naf_digit: -1,
                    line: sub,
                    line_value: value,
                    accumulator_after: f.clone(),
                });
            }
            0 => {}
            _ => return None,
        }
    }

    Some(MillerTraceFullFp4 {
        loop_scalar_dec: scalar.to_string(),
        naf_lsb: naf,
        steps,
        final_t: t,
        accumulator: f,
    })
}

pub fn reduced_ate_pairing_twist_source(
    p: &AffinePointFp,
    q_twist: &AffinePointFp2Twist,
) -> Option<Fp4> {
    let eval = AffinePointFp4::from_fp_point(p);
    let q_full = untwist_to_fp4(q_twist);
    let trace = miller_trace_full_fp4(&eval, &q_full, &ate_loop_scalar())?;
    Some(final_exponent(&trace.accumulator))
}
