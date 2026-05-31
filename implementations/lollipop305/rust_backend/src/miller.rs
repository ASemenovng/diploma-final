use crate::curve::AffinePointFp;
use crate::extension_curve::AffinePointFp4;
use crate::field::{Fp, Fp2, Fp4};
use crate::params::x_parameter;
use num_bigint::{BigInt, BigUint, Sign};
use num_traits::{One, Zero};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub enum PreparedLineKind {
    Double,
    Add,
    Sub,
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub struct PreparedLine {
    pub kind: PreparedLineKind,
    /// Line equation: y + x_coeff*x + const_coeff = 0.
    /// For affine slope lambda and intercept nu, this is y - lambda*x - nu.
    pub x_coeff: Fp,
    pub const_coeff: Fp,
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub struct MillerStep {
    pub is_double: bool,
    pub naf_digit: i8,
    pub line: PreparedLine,
    pub line_value: Fp4,
    pub accumulator_after: Fp4,
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub struct MillerTrace {
    pub loop_scalar_dec: String,
    pub naf_lsb: Vec<i8>,
    pub steps: Vec<MillerStep>,
    pub final_t: AffinePointFp,
    pub accumulator: Fp4,
}

pub fn ate_loop_scalar() -> BigUint {
    x_parameter() - BigUint::one()
}

pub fn naf_digits_lsb(n: &BigUint) -> Vec<i8> {
    let mut k = BigInt::from_biguint(Sign::Plus, n.clone());
    let zero = BigInt::zero();
    let one = BigInt::one();
    let four = BigInt::from(4u8);
    let mut out = Vec::new();
    while k > zero {
        if (&k & &one) == one {
            let rem4 = ((&k % &four).to_biguint().unwrap()).to_u64_digits();
            let rem = rem4.first().copied().unwrap_or(0);
            let zi = if rem == 1 { 1i8 } else { -1i8 };
            out.push(zi);
            k -= BigInt::from(zi);
        } else {
            out.push(0);
        }
        k >>= 1usize;
    }
    out
}

impl PreparedLine {
    pub fn for_double(p: &AffinePointFp) -> Option<Self> {
        if p.is_infinity() || p.y.is_zero() {
            return None;
        }
        let three = Fp::from(3u64);
        let two = Fp::from(2u64);
        let lambda = three
            .mul(&p.x.square())
            .add(&crate::curve::e_stick_a())
            .mul(&two.mul(&p.y).inverse()?);
        Some(Self::from_slope(PreparedLineKind::Double, p, &lambda))
    }

    pub fn for_add(a: &AffinePointFp, b: &AffinePointFp) -> Option<Self> {
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
        Some(Self::from_slope(PreparedLineKind::Add, a, &lambda))
    }

    pub fn for_sub(a: &AffinePointFp, b: &AffinePointFp) -> Option<Self> {
        let neg_b = b.neg();
        let mut line = Self::for_add(a, &neg_b)?;
        line.kind = PreparedLineKind::Sub;
        Some(line)
    }

    fn from_slope(kind: PreparedLineKind, p: &AffinePointFp, lambda: &Fp) -> Self {
        let nu = p.y.sub(&lambda.mul(&p.x));
        Self {
            kind,
            x_coeff: lambda.neg(),
            const_coeff: nu.neg(),
        }
    }

    pub fn evaluate_fp(&self, p: &AffinePointFp) -> Fp {
        if p.is_infinity() {
            return Fp::zero();
        }
        p.y.add(&self.x_coeff.mul(&p.x)).add(&self.const_coeff)
    }

    pub fn evaluate_fp4(&self, p: &AffinePointFp) -> Fp4 {
        Fp4::new(Fp2::new(self.evaluate_fp(p), Fp::zero()), Fp2::zero())
    }

    pub fn evaluate_fp4_point(&self, p: &AffinePointFp4) -> Fp4 {
        if p.is_infinity() {
            return Fp4::zero();
        }
        p.y.add(&Fp4::from_fp(self.x_coeff.clone()).mul(&p.x))
            .add(&Fp4::from_fp(self.const_coeff.clone()))
    }
}

pub fn build_prepared_miller_trace(
    eval_point: &AffinePointFp,
    q: &AffinePointFp,
    scalar: &BigUint,
) -> Option<MillerTrace> {
    let naf = naf_digits_lsb(scalar);
    if naf.is_empty() {
        return None;
    }
    let mut t = q.clone();
    let mut f = Fp4::one();
    let mut steps = Vec::new();

    for idx in (0..naf.len() - 1).rev() {
        let dbl = PreparedLine::for_double(&t)?;
        let dbl_value = dbl.evaluate_fp4(eval_point);
        f = f.square().mul(&dbl_value);
        t = t.double()?;
        steps.push(MillerStep {
            is_double: true,
            naf_digit: 0,
            line: dbl,
            line_value: dbl_value,
            accumulator_after: f.clone(),
        });

        match naf[idx] {
            1 => {
                let add = PreparedLine::for_add(&t, q)?;
                let value = add.evaluate_fp4(eval_point);
                f = f.mul(&value);
                t = t.add(q)?;
                steps.push(MillerStep {
                    is_double: false,
                    naf_digit: 1,
                    line: add,
                    line_value: value,
                    accumulator_after: f.clone(),
                });
            }
            -1 => {
                let sub = PreparedLine::for_sub(&t, q)?;
                let value = sub.evaluate_fp4(eval_point);
                f = f.mul(&value);
                t = t.add(&q.neg())?;
                steps.push(MillerStep {
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

    Some(MillerTrace {
        loop_scalar_dec: scalar.to_string(),
        naf_lsb: naf,
        steps,
        final_t: t,
        accumulator: f,
    })
}

pub fn line_commitment_sha256_hex(trace: &MillerTrace) -> String {
    let bytes = serde_json::to_vec(&trace.steps.iter().map(|s| &s.line).collect::<Vec<_>>())
        .expect("line serialization is deterministic");
    let digest = Sha256::digest(bytes);
    let mut out = String::from("0x");
    for byte in digest {
        out.push_str(&format!("{:02x}", byte));
    }
    out
}
