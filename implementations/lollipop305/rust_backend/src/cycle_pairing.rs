use crate::cycle::{sample_cycle_e_point, CycleEPointFp2};
use crate::field::{Fp, Fp2, Fp4};
use crate::miller::naf_digits_lsb;
use crate::params::{modulus_p, modulus_q, x_parameter};
use num_bigint::{BigInt, BigUint, Sign};
use num_traits::{One, Zero};

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct CycleEPointFp4 {
    pub x: Fp4,
    pub y: Fp4,
    pub infinity: bool,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct CycleELineFp4 {
    pub x_coeff: Fp4,
    pub const_coeff: Fp4,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct CycleELineStep {
    pub is_double: bool,
    pub line_value: Fp4,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct CycleEArticle640Fixture {
    pub scalar_dec: String,
    pub final_exponent_dec: String,
    pub steps: Vec<CycleELineStep>,
    pub core: Fp4,
    pub c: Fp4,
    pub c_inv: Fp4,
}

fn coeff_a() -> Fp4 {
    Fp4::new(Fp2::new(Fp::one(), Fp::one()), Fp2::zero())
}

fn mu_fp2() -> Fp2 {
    Fp2::new(Fp::zero(), Fp::one())
}

fn cycle_e_theta() -> Option<Fp4> {
    // For E: y^2=x^3+(1+mu)x, the p-Frobenius conjugates a to 1-mu.
    // A distortion/Frobenius map back to E needs theta^4=(1+mu)/(1-mu)=mu.
    Fp4::from_fp2(mu_fp2()).sqrt()?.sqrt()
}

fn cycle_e_distortion(p: &CycleEPointFp2) -> Option<CycleEPointFp4> {
    if p.is_infinity() {
        return Some(CycleEPointFp4::infinity());
    }
    let theta = cycle_e_theta()?;
    let theta2 = theta.square();
    let theta3 = theta2.mul(&theta);
    let x_p = Fp4::from_fp2(p.x.frobenius_p());
    let y_p = Fp4::from_fp2(p.y.frobenius_p());
    Some(CycleEPointFp4 { x: theta2.mul(&x_p), y: theta3.mul(&y_p), infinity: false })
}

impl CycleEPointFp4 {
    pub fn infinity() -> Self {
        Self { x: Fp4::zero(), y: Fp4::zero(), infinity: true }
    }
    pub fn from_fp2_point(p: &CycleEPointFp2) -> Self {
        if p.is_infinity() {
            Self::infinity()
        } else {
            Self {
                x: Fp4::new(p.x.clone(), Fp2::zero()),
                y: Fp4::new(p.y.clone(), Fp2::zero()),
                infinity: false,
            }
        }
    }
    pub fn is_infinity(&self) -> bool { self.infinity }
    pub fn is_on_curve(&self) -> bool {
        if self.infinity { return true; }
        self.y.square() == self.x.square().mul(&self.x).add(&coeff_a().mul(&self.x))
    }
    pub fn neg(&self) -> Self {
        if self.infinity { Self::infinity() } else { Self { x: self.x.clone(), y: self.y.neg(), infinity: false } }
    }
    pub fn double(&self) -> Option<Self> {
        if self.infinity { return Some(Self::infinity()); }
        if self.y.is_zero() { return Some(Self::infinity()); }
        let three = Fp4::from_fp(Fp::from(3u64));
        let two = Fp4::from_fp(Fp::from(2u64));
        let lambda = three.mul(&self.x.square()).add(&coeff_a()).mul(&two.mul(&self.y).inverse()?);
        Some(Self::from_slope(self, self, &lambda))
    }
    pub fn add(&self, rhs: &Self) -> Option<Self> {
        if self.infinity { return Some(rhs.clone()); }
        if rhs.infinity { return Some(self.clone()); }
        if self.x == rhs.x {
            if self.y.add(&rhs.y).is_zero() { return Some(Self::infinity()); }
            return self.double();
        }
        let lambda = rhs.y.sub(&self.y).mul(&rhs.x.sub(&self.x).inverse()?);
        Some(Self::from_slope(self, rhs, &lambda))
    }
    fn from_slope(a: &Self, b: &Self, lambda: &Fp4) -> Self {
        let x3 = lambda.square().sub(&a.x).sub(&b.x);
        let y3 = lambda.mul(&a.x.sub(&x3)).sub(&a.y);
        Self { x: x3, y: y3, infinity: false }
    }
}

impl CycleELineFp4 {
    pub fn for_double(p: &CycleEPointFp4) -> Option<Self> {
        if p.infinity || p.y.is_zero() { return None; }
        let three = Fp4::from_fp(Fp::from(3u64));
        let two = Fp4::from_fp(Fp::from(2u64));
        let lambda = three.mul(&p.x.square()).add(&coeff_a()).mul(&two.mul(&p.y).inverse()?);
        Some(Self::from_slope(p, &lambda))
    }
    pub fn for_add(a: &CycleEPointFp4, b: &CycleEPointFp4) -> Option<Self> {
        if a.infinity || b.infinity { return None; }
        if a.x == b.x {
            if a.y == b.y { return Self::for_double(a); }
            return None;
        }
        let lambda = b.y.sub(&a.y).mul(&b.x.sub(&a.x).inverse()?);
        Some(Self::from_slope(a, &lambda))
    }
    pub fn for_sub(a: &CycleEPointFp4, b: &CycleEPointFp4) -> Option<Self> {
        Self::for_add(a, &b.neg())
    }
    fn from_slope(p: &CycleEPointFp4, lambda: &Fp4) -> Self {
        let nu = p.y.sub(&lambda.mul(&p.x));
        Self { x_coeff: lambda.neg(), const_coeff: nu.neg() }
    }
    pub fn evaluate(&self, p: &CycleEPointFp4) -> Fp4 {
        if p.infinity { return Fp4::zero(); }
        p.y.add(&self.x_coeff.mul(&p.x)).add(&self.const_coeff)
    }
}

pub fn cycle_e_final_exponent_value() -> BigUint {
    let p = modulus_p();
    (p.pow(4) - BigUint::one()) / modulus_q()
}

pub fn cycle_e_final_exponent(f: &Fp4) -> Fp4 {
    f.pow(&cycle_e_final_exponent_value())
}

fn modinv(a: &BigUint, m: &BigUint) -> Option<BigUint> {
    let mut t = BigInt::zero();
    let mut new_t = BigInt::one();
    let mut r = BigInt::from_biguint(Sign::Plus, m.clone());
    let mut new_r = BigInt::from_biguint(Sign::Plus, a % m);
    while new_r != BigInt::zero() {
        let q = &r / &new_r;
        let tmp_t = t - &q * &new_t;
        t = new_t;
        new_t = tmp_t;
        let tmp_r = r - q * &new_r;
        r = new_r;
        new_r = tmp_r;
    }
    if r != BigInt::one() { return None; }
    if t.sign() == Sign::Minus { t += BigInt::from_biguint(Sign::Plus, m.clone()); }
    t.to_biguint()
}


#[derive(Clone, Debug, Eq, PartialEq)]
pub struct CycleEMillerCoreFixture {
    pub scalar_dec: String,
    pub steps: Vec<CycleELineStep>,
    pub core: Fp4,
}

pub fn build_cycle_e_miller_core_fixture() -> Option<CycleEMillerCoreFixture> {
    let p_source = sample_cycle_e_point()?;
    let q_source = p_source.double()?;
    let eval_source = CycleEPointFp2::find_point_from(11)?;
    let eval = CycleEPointFp4::from_fp2_point(&eval_source);
    let neg_eval = eval.neg();
    let q = CycleEPointFp4::from_fp2_point(&q_source);
    if !eval.is_on_curve() || !q.is_on_curve() { return None; }

    let scalar = modulus_q();
    let naf = naf_digits_lsb(&scalar);
    let mut t = q.clone();
    let mut f = Fp4::one();
    let mut steps = Vec::new();

    for idx in (0..naf.len() - 1).rev() {
        let dbl = CycleELineFp4::for_double(&t)?;
        let line = dbl.evaluate(&eval).mul(&dbl.evaluate(&neg_eval));
        f = f.square().mul(&line);
        t = t.double()?;
        steps.push(CycleELineStep { is_double: true, line_value: line });

        match naf[idx] {
            1 => {
                let line = if let Some(add) = CycleELineFp4::for_add(&t, &q) {
                    add.evaluate(&eval).mul(&add.evaluate(&neg_eval))
                } else if t.x == q.x && t.y.add(&q.y).is_zero() {
                    eval.x.sub(&t.x).mul(&neg_eval.x.sub(&t.x))
                } else { return None; };
                f = f.mul(&line);
                t = t.add(&q)?;
                steps.push(CycleELineStep { is_double: false, line_value: line });
            }
            -1 => {
                let neg_q = q.neg();
                let line = if let Some(sub) = CycleELineFp4::for_sub(&t, &q) {
                    sub.evaluate(&eval).mul(&sub.evaluate(&neg_eval))
                } else if t.x == neg_q.x && t.y.add(&neg_q.y).is_zero() {
                    eval.x.sub(&t.x).mul(&neg_eval.x.sub(&t.x))
                } else { return None; };
                f = f.mul(&line);
                t = t.add(&neg_q)?;
                steps.push(CycleELineStep { is_double: false, line_value: line });
            }
            0 => {}
            _ => return None,
        }
    }

    Some(CycleEMillerCoreFixture { scalar_dec: scalar.to_string(), steps, core: f })
}

pub fn build_cycle_e_article640_fixture() -> Option<CycleEArticle640Fixture> {
    let p_source = sample_cycle_e_point().or_else(|| { eprintln!("no sample_cycle_e_point"); None })?;
    let q_source = p_source.double().or_else(|| { eprintln!("p_source.double failed"); None })?;
    let eval_source = CycleEPointFp2::find_point_from(11)?;
    let eval = CycleEPointFp4::from_fp2_point(&eval_source);
    let neg_eval = eval.neg();
    let q = CycleEPointFp4::from_fp2_point(&q_source);
    if !eval.is_on_curve() || !q.is_on_curve() { eprintln!("eval/q not on curve"); return None; }

    let scalar = modulus_q();
    let naf = naf_digits_lsb(&scalar);
    let mut t = q.clone();
    let mut f = Fp4::one();
    let mut steps = Vec::new();

    for idx in (0..naf.len() - 1).rev() {
        let dbl = CycleELineFp4::for_double(&t).or_else(|| { eprintln!("double line failed at idx {idx}"); None })?;
        let line = dbl.evaluate(&eval).mul(&dbl.evaluate(&neg_eval));
        f = f.square().mul(&line);
        t = t.double().or_else(|| { eprintln!("double point failed at idx {idx}"); None })?;
        steps.push(CycleELineStep { is_double: true, line_value: line });

        match naf[idx] {
            1 => {
                let line = if let Some(add) = CycleELineFp4::for_add(&t, &q) {
                    add.evaluate(&eval).mul(&add.evaluate(&neg_eval))
                } else if t.x == q.x && t.y.add(&q.y).is_zero() {
                    // Last-step vertical line: x - x_T = 0.
                    eval.x.sub(&t.x).mul(&neg_eval.x.sub(&t.x))
                } else {
                    eprintln!("add line failed at idx {idx}");
                    return None;
                };
                f = f.mul(&line);
                t = t.add(&q).or_else(|| { eprintln!("add point failed at idx {idx}"); None })?;
                steps.push(CycleELineStep { is_double: false, line_value: line });
            }
            -1 => {
                let neg_q = q.neg();
                let line = if let Some(sub) = CycleELineFp4::for_sub(&t, &q) {
                    sub.evaluate(&eval).mul(&sub.evaluate(&neg_eval))
                } else if t.x == neg_q.x && t.y.add(&neg_q.y).is_zero() {
                    // Last-step vertical line: x - x_T = 0.
                    eval.x.sub(&t.x).mul(&neg_eval.x.sub(&t.x))
                } else {
                    eprintln!("sub line failed at idx {idx}");
                    return None;
                };
                f = f.mul(&line);
                t = t.add(&neg_q).or_else(|| { eprintln!("sub point failed at idx {idx}"); None })?;
                steps.push(CycleELineStep { is_double: false, line_value: line });
            }
            0 => {}
            _ => return None,
        }
    }

    let e = cycle_e_final_exponent_value();
    if cycle_e_final_exponent(&f) != Fp4::one() { eprintln!("direct FE not one; steps={}", steps.len()); return None; }
    let q_inv_mod_e = modinv(&modulus_q(), &e).or_else(|| { eprintln!("modinv q mod e failed"); None })?;
    let c = f.pow(&q_inv_mod_e);
    if c.pow(&modulus_q()) != f { eprintln!("c^q != f"); return None; }
    let c_inv = c.inverse()?;
    if c.mul(&c_inv) != Fp4::one() { return None; }

    Some(CycleEArticle640Fixture {
        scalar_dec: scalar.to_string(),
        final_exponent_dec: e.to_string(),
        steps,
        core: f,
        c,
        c_inv,
    })
}

pub fn build_cycle_e_distorted_article640_fixture() -> Option<CycleEArticle640Fixture> {
    let p_source = sample_cycle_e_point()?;
    let q_raw = p_source.double()?;
    let p_eval = CycleEPointFp4::from_fp2_point(&p_source);
    let neg_p_eval = p_eval.neg();
    let q = cycle_e_distortion(&q_raw)?;
    if !p_eval.is_on_curve() || !q.is_on_curve() {
        return None;
    }

    let scalar = modulus_q();
    let naf = naf_digits_lsb(&scalar);
    let mut t = q.clone();
    let mut f = Fp4::one();
    let mut steps = Vec::new();

    for idx in (0..naf.len() - 1).rev() {
        let dbl = CycleELineFp4::for_double(&t)?;
        let line = dbl.evaluate(&p_eval).mul(&dbl.evaluate(&neg_p_eval));
        f = f.square().mul(&line);
        t = t.double()?;
        steps.push(CycleELineStep { is_double: true, line_value: line });

        match naf[idx] {
            1 => {
                let line = if let Some(add) = CycleELineFp4::for_add(&t, &q) {
                    add.evaluate(&p_eval).mul(&add.evaluate(&neg_p_eval))
                } else if t.x == q.x && t.y.add(&q.y).is_zero() {
                    p_eval.x.sub(&t.x).mul(&neg_p_eval.x.sub(&t.x))
                } else {
                    return None;
                };
                f = f.mul(&line);
                t = t.add(&q)?;
                steps.push(CycleELineStep { is_double: false, line_value: line });
            }
            -1 => {
                let neg_q = q.neg();
                let line = if let Some(sub) = CycleELineFp4::for_sub(&t, &q) {
                    sub.evaluate(&p_eval).mul(&sub.evaluate(&neg_p_eval))
                } else if t.x == neg_q.x && t.y.add(&neg_q.y).is_zero() {
                    p_eval.x.sub(&t.x).mul(&neg_p_eval.x.sub(&t.x))
                } else {
                    return None;
                };
                f = f.mul(&line);
                t = t.add(&neg_q)?;
                steps.push(CycleELineStep { is_double: false, line_value: line });
            }
            0 => {}
            _ => return None,
        }
    }

    let h = cycle_e_final_exponent_value();
    if f.pow(&h) != Fp4::one() {
        return None;
    }
    let exp = modinv(&modulus_q(), &h)?;
    let c = f.pow(&exp);
    let c_inv = c.inverse()?;
    if c.pow(&modulus_q()) != f {
        return None;
    }

    Some(CycleEArticle640Fixture {
        scalar_dec: scalar.to_string(),
        final_exponent_dec: cycle_e_final_exponent_value().to_string(),
        steps,
        core: f,
        c,
        c_inv,
    })
}

use crate::cycle::{sample_cycle_ehat_point, CycleEhatPointFq2};
use crate::field_q::{Fq, Fq2, Fq6};

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct CycleEhatPointFq6 {
    pub x: Fq6,
    pub y: Fq6,
    pub infinity: bool,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct CycleEhatLineFq6 {
    pub x_coeff: Fq6,
    pub const_coeff: Fq6,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct CycleEhatLineStep {
    pub is_double: bool,
    pub line_value: Fq6,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct CycleEhatPreparedLine {
    pub is_double: bool,
    pub x_coeff_w: Fq2,
    pub const_coeff: Fq2,
    pub c_vert: Fq2,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct CycleEhatArticle640Fixture {
    pub steps: Vec<CycleEhatLineStep>,
    pub core: Fq6,
    pub c: Fq6,
    pub c_inv: Fq6,
    pub direct_is_one: bool,
    pub c_times_c_inv_is_one: bool,
    pub c_to_p_equals_core: bool,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct CycleEhatAteResidueFixture {
    pub lines: Vec<CycleEhatPreparedLine>,
    pub px: Fq2,
    pub py: Fq2,
    pub f_num: Fq6,
    pub f_den: Fq6,
    pub f: Fq6,
    pub c: Fq6,
    pub c_to_p_equals_f: bool,
    pub residue_check: bool,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct CycleEhatWeilCheck {
    pub pairing: Fq6,
    pub q_on_curve: bool,
    pub p_torsion: bool,
    pub q_torsion: bool,
    pub frobenius_eigen: bool,
    pub pairing_nontrivial: bool,
    pub pairing_order_p: bool,
    pub product_with_neg_is_one: bool,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct CycleEhatWeilFixture {
    pub f_p_q_steps: Vec<CycleEhatLineStep>,
    pub f_neg_p_q_steps: Vec<CycleEhatLineStep>,
    pub f_q_p_steps: Vec<CycleEhatLineStep>,
    pub f_q_neg_p_steps: Vec<CycleEhatLineStep>,
    pub f_p_q: Fq6,
    pub f_neg_p_q: Fq6,
    pub f_q_p: Fq6,
    pub f_q_neg_p: Fq6,
    pub lhs: Fq6,
    pub rhs: Fq6,
}

fn ehat_b_fq6() -> Fq6 {
    Fq6::from_fq2(Fq2::new(Fq::from(2u64), Fq::one()))
}

impl CycleEhatPointFq6 {
    pub fn infinity() -> Self {
        Self { x: Fq6::zero(), y: Fq6::zero(), infinity: true }
    }
    pub fn from_fq2_point(p: &CycleEhatPointFq2) -> Self {
        if p.is_infinity() {
            Self::infinity()
        } else {
            Self { x: Fq6::from_fq2(p.x.clone()), y: Fq6::from_fq2(p.y.clone()), infinity: false }
        }
    }
    pub fn is_on_curve(&self) -> bool {
        if self.infinity { return true; }
        self.y.square() == self.x.square().mul(&self.x).add(&ehat_b_fq6())
    }
    pub fn neg(&self) -> Self {
        if self.infinity { Self::infinity() } else { Self { x: self.x.clone(), y: self.y.neg(), infinity: false } }
    }
    pub fn double(&self) -> Option<Self> {
        if self.infinity { return Some(Self::infinity()); }
        if self.y.is_zero() { return Some(Self::infinity()); }
        let three = Fq6::from_fq2(Fq2::new(Fq::from(3u64), Fq::zero()));
        let two = Fq6::from_fq2(Fq2::new(Fq::from(2u64), Fq::zero()));
        let lambda = three.mul(&self.x.square()).mul(&two.mul(&self.y).inverse()?);
        Some(Self::from_slope(self, self, &lambda))
    }
    pub fn add(&self, rhs: &Self) -> Option<Self> {
        if self.infinity { return Some(rhs.clone()); }
        if rhs.infinity { return Some(self.clone()); }
        if self.x == rhs.x {
            if self.y.add(&rhs.y).is_zero() { return Some(Self::infinity()); }
            return self.double();
        }
        let lambda = rhs.y.sub(&self.y).mul(&rhs.x.sub(&self.x).inverse()?);
        Some(Self::from_slope(self, rhs, &lambda))
    }
    fn from_slope(a: &Self, b: &Self, lambda: &Fq6) -> Self {
        let x3 = lambda.square().sub(&a.x).sub(&b.x);
        let y3 = lambda.mul(&a.x.sub(&x3)).sub(&a.y);
        Self { x: x3, y: y3, infinity: false }
    }
}

impl CycleEhatLineFq6 {
    pub fn for_double(p: &CycleEhatPointFq6) -> Option<Self> {
        if p.infinity || p.y.is_zero() { return None; }
        let three = Fq6::from_fq2(Fq2::new(Fq::from(3u64), Fq::zero()));
        let two = Fq6::from_fq2(Fq2::new(Fq::from(2u64), Fq::zero()));
        let lambda = three.mul(&p.x.square()).mul(&two.mul(&p.y).inverse()?);
        Some(Self::from_slope(p, &lambda))
    }
    pub fn for_add(a: &CycleEhatPointFq6, b: &CycleEhatPointFq6) -> Option<Self> {
        if a.infinity || b.infinity { return None; }
        if a.x == b.x {
            if a.y == b.y { return Self::for_double(a); }
            return None;
        }
        let lambda = b.y.sub(&a.y).mul(&b.x.sub(&a.x).inverse()?);
        Some(Self::from_slope(a, &lambda))
    }
    pub fn for_sub(a: &CycleEhatPointFq6, b: &CycleEhatPointFq6) -> Option<Self> {
        Self::for_add(a, &b.neg())
    }
    fn from_slope(p: &CycleEhatPointFq6, lambda: &Fq6) -> Self {
        let nu = p.y.sub(&lambda.mul(&p.x));
        Self { x_coeff: lambda.neg(), const_coeff: nu.neg() }
    }
    pub fn evaluate(&self, p: &CycleEhatPointFq6) -> Fq6 {
        if p.infinity { return Fq6::zero(); }
        p.y.add(&self.x_coeff.mul(&p.x)).add(&self.const_coeff)
    }
}

fn cycle_ehat_distortion(p: &CycleEhatPointFq2) -> CycleEhatPointFq6 {
    if p.is_infinity() {
        return CycleEhatPointFq6::infinity();
    }
    let x_q = Fq6::from_fq2(p.x.frobenius_q());
    let y_q = Fq6::from_fq2(p.y.frobenius_q());
    let theta2 = Fq6::w2();
    let theta3 = Fq6::from_fq2(Fq6::rho());
    CycleEhatPointFq6 { x: theta2.mul(&x_q), y: theta3.mul(&y_q), infinity: false }
}

fn cycle_ehat_scalar_mul_fq6(point: &CycleEhatPointFq6, scalar: &BigUint) -> Option<CycleEhatPointFq6> {
    let mut acc = CycleEhatPointFq6::infinity();
    let mut base = point.clone();
    let mut k = scalar.clone();
    while k > BigUint::zero() {
        if (&k & BigUint::one()) == BigUint::one() {
            acc = acc.add(&base)?;
        }
        base = base.double()?;
        k >>= 1usize;
    }
    Some(acc)
}

fn cycle_ehat_frobenius_q2_point(point: &CycleEhatPointFq6) -> CycleEhatPointFq6 {
    if point.infinity {
        return CycleEhatPointFq6::infinity();
    }
    let q2 = modulus_q().pow(2);
    CycleEhatPointFq6 {
        x: point.x.pow(&q2),
        y: point.y.pow(&q2),
        infinity: false,
    }
}

fn cycle_ehat_vertical_denominator(eval: &CycleEhatPointFq6, new_t: &CycleEhatPointFq6) -> Fq6 {
    if new_t.infinity {
        Fq6::one()
    } else {
        eval.x.sub(&new_t.x)
    }
}

fn cycle_ehat_miller_full(source: &CycleEhatPointFq6, eval: &CycleEhatPointFq6) -> Option<Fq6> {
    Some(cycle_ehat_miller_full_trace(source, eval)?.0)
}

fn cycle_ehat_miller_full_trace(
    source: &CycleEhatPointFq6,
    eval: &CycleEhatPointFq6,
) -> Option<(Fq6, Vec<CycleEhatLineStep>)> {
    if source.infinity || eval.infinity {
        return None;
    }

    let scalar = modulus_p();
    let naf = naf_digits_lsb(&scalar);
    let mut t = source.clone();
    let mut f = Fq6::one();
    let mut steps = Vec::new();

    for idx in (0..naf.len() - 1).rev() {
        let dbl = CycleEhatLineFq6::for_double(&t)?;
        let doubled = t.double()?;
        let numerator = dbl.evaluate(eval);
        let denominator = cycle_ehat_vertical_denominator(eval, &doubled).inverse()?;
        let line_value = numerator.mul(&denominator);
        f = f.square().mul(&line_value);
        steps.push(CycleEhatLineStep { is_double: true, line_value });
        t = doubled;

        match naf[idx] {
            1 => {
                let added = t.add(source)?;
                let numerator = if let Some(add) = CycleEhatLineFq6::for_add(&t, source) {
                    add.evaluate(eval)
                } else if t.x == source.x && t.y.add(&source.y).is_zero() {
                    eval.x.sub(&t.x)
                } else {
                    return None;
                };
                let denominator = cycle_ehat_vertical_denominator(eval, &added).inverse()?;
                let line_value = numerator.mul(&denominator);
                f = f.mul(&line_value);
                steps.push(CycleEhatLineStep { is_double: false, line_value });
                t = added;
            }
            -1 => {
                let neg_source = source.neg();
                let subbed = t.add(&neg_source)?;
                let numerator = if let Some(sub) = CycleEhatLineFq6::for_sub(&t, source) {
                    sub.evaluate(eval)
                } else if t.x == neg_source.x && t.y.add(&neg_source.y).is_zero() {
                    eval.x.sub(&t.x)
                } else {
                    return None;
                };
                let denominator = cycle_ehat_vertical_denominator(eval, &subbed).inverse()?;
                let line_value = numerator.mul(&denominator);
                f = f.mul(&line_value);
                steps.push(CycleEhatLineStep { is_double: false, line_value });
                t = subbed;
            }
            0 => {}
            _ => return None,
        }
    }

    Some((f, steps))
}

pub fn cycle_ehat_weil_pairing(source: &CycleEhatPointFq6, eval: &CycleEhatPointFq6) -> Option<Fq6> {
    // Weil pairing in Miller-function form. The fixed sign convention is irrelevant
    // for the product test e(P,Q)e(-P,Q)=1 used by the verifier model.
    let f_source_eval = cycle_ehat_miller_full(source, eval)?;
    let f_eval_source = cycle_ehat_miller_full(eval, source)?;
    Some(f_source_eval.mul(&f_eval_source.inverse()?))
}

pub fn check_cycle_ehat_weil_pairing() -> Option<CycleEhatWeilCheck> {
    let p_raw = sample_cycle_ehat_point()?;
    let q_raw = p_raw.double()?;
    let p = CycleEhatPointFq6::from_fq2_point(&p_raw);
    let q = cycle_ehat_distortion(&q_raw);

    let p_order = modulus_p();
    let q2_mod_p = modulus_q().pow(2) % &p_order;
    let frob_q2 = cycle_ehat_frobenius_q2_point(&q);
    let scalar_q2 = cycle_ehat_scalar_mul_fq6(&q, &q2_mod_p)?;

    let pairing = cycle_ehat_weil_pairing(&p, &q)?;
    let pairing_neg = cycle_ehat_weil_pairing(&p.neg(), &q)?;

    Some(CycleEhatWeilCheck {
        pairing: pairing.clone(),
        q_on_curve: q.is_on_curve(),
        p_torsion: cycle_ehat_scalar_mul_fq6(&p, &p_order)?.infinity,
        q_torsion: cycle_ehat_scalar_mul_fq6(&q, &p_order)?.infinity,
        frobenius_eigen: frob_q2 == scalar_q2,
        pairing_nontrivial: !pairing.is_one(),
        pairing_order_p: pairing.pow(&p_order).is_one(),
        product_with_neg_is_one: pairing.mul(&pairing_neg).is_one(),
    })
}

pub fn build_cycle_ehat_weil_fixture() -> Option<CycleEhatWeilFixture> {
    let p_raw = sample_cycle_ehat_point()?;
    let q_raw = p_raw.double()?;
    let p = CycleEhatPointFq6::from_fq2_point(&p_raw);
    let neg_p = p.neg();
    let q = cycle_ehat_distortion(&q_raw);

    let (f_p_q, f_p_q_steps) = cycle_ehat_miller_full_trace(&p, &q)?;
    let (f_neg_p_q, f_neg_p_q_steps) = cycle_ehat_miller_full_trace(&neg_p, &q)?;
    let (f_q_p, f_q_p_steps) = cycle_ehat_miller_full_trace(&q, &p)?;
    let (f_q_neg_p, f_q_neg_p_steps) = cycle_ehat_miller_full_trace(&q, &neg_p)?;
    let lhs = f_p_q.mul(&f_neg_p_q);
    let rhs = f_q_p.mul(&f_q_neg_p);
    if lhs != rhs {
        return None;
    }
    Some(CycleEhatWeilFixture {
        f_p_q_steps,
        f_neg_p_q_steps,
        f_q_p_steps,
        f_q_neg_p_steps,
        f_p_q,
        f_neg_p_q,
        f_q_p,
        f_q_neg_p,
        lhs,
        rhs,
    })
}

pub fn cycle_ehat_final_exponent_value() -> BigUint {
    let q = modulus_q();
    (q.pow(6) - BigUint::one()) / modulus_p()
}

fn cycle_ehat_ate_scalar() -> BigUint {
    x_parameter() - BigUint::one()
}

fn cycle_ehat_line_coeffs_generic(line: &CycleEhatLineFq6) -> Option<(Fq2, Fq2)> {
    if !line.x_coeff.c0.is_zero()
        || !line.x_coeff.c2.is_zero()
        || !line.const_coeff.c1.is_zero()
        || !line.const_coeff.c2.is_zero()
    {
        return None;
    }
    Some((line.x_coeff.c1.clone(), line.const_coeff.c0.clone()))
}

fn cycle_ehat_extract_c_vert(point: &CycleEhatPointFq6) -> Option<Fq2> {
    if point.infinity || !point.x.c0.is_zero() || !point.x.c1.is_zero() {
        return None;
    }
    Some(point.x.c2.clone())
}

fn cycle_ehat_miller_prepared_num_den(
    eval: &CycleEhatPointFq2,
    lines: &[CycleEhatPreparedLine],
) -> (Fq6, Fq6) {
    let mut f_num = Fq6::one();
    let mut f_den = Fq6::one();
    for line in lines {
        let a_l = eval.y.add(&line.const_coeff);
        let b_l = line.x_coeff_w.mul(&eval.x);
        let a_v = eval.x.clone();
        let c_v = line.c_vert.neg();
        if line.is_double {
            f_num = f_num.square();
            f_den = f_den.square();
        }
        f_num = f_num.mul_by_01(&a_l, &b_l);
        f_den = f_den.mul_by_02(&a_v, &c_v);
    }
    (f_num, f_den)
}

fn build_cycle_ehat_ate_prepared_lines(q0: &CycleEhatPointFq2) -> Option<Vec<CycleEhatPreparedLine>> {
    let q_prime = cycle_ehat_distortion(q0);
    let scalar = cycle_ehat_ate_scalar();
    let bits = scalar.to_str_radix(2).into_bytes();
    let mut t = q_prime.clone();
    let mut lines = Vec::new();
    for bit in bits.iter().skip(1) {
        let dbl = CycleEhatLineFq6::for_double(&t)?;
        let doubled = t.double()?;
        let (x_coeff_w, const_coeff) = cycle_ehat_line_coeffs_generic(&dbl)?;
        let c_vert = cycle_ehat_extract_c_vert(&doubled)?;
        lines.push(CycleEhatPreparedLine { is_double: true, x_coeff_w, const_coeff, c_vert });
        t = doubled;

        if *bit == b'1' {
            let add = CycleEhatLineFq6::for_add(&t, &q_prime)?;
            let added = t.add(&q_prime)?;
            let (x_coeff_w, const_coeff) = cycle_ehat_line_coeffs_generic(&add)?;
            let c_vert = cycle_ehat_extract_c_vert(&added)?;
            lines.push(CycleEhatPreparedLine { is_double: false, x_coeff_w, const_coeff, c_vert });
            t = added;
        }
    }
    Some(lines)
}

pub fn build_cycle_ehat_ate_residue_fixture() -> Option<CycleEhatAteResidueFixture> {
    let p_eval = sample_cycle_ehat_point()?;
    let q_raw = p_eval.double()?;
    let lines = build_cycle_ehat_ate_prepared_lines(&q_raw)?;

    let (n1, d1) = cycle_ehat_miller_prepared_num_den(&p_eval, &lines);
    let neg_eval = p_eval.neg();
    let (n2, d2) = cycle_ehat_miller_prepared_num_den(&neg_eval, &lines);
    let f_num = n1.mul(&n2);
    let f_den = d1.mul(&d2);
    let f = f_num.mul(&f_den.inverse()?);

    let m = cycle_ehat_final_exponent_value();
    if !f.pow(&m).is_one() {
        return None;
    }
    let u = modinv(&modulus_p(), &m)?;
    let c = f.pow(&u);
    let c_to_p_equals_f = c.pow(&modulus_p()) == f;
    let residue_check = c.pow(&modulus_p()).mul(&f_den) == f_num;
    if !c_to_p_equals_f || !residue_check {
        return None;
    }

    Some(CycleEhatAteResidueFixture {
        lines,
        px: p_eval.x,
        py: p_eval.y,
        f_num,
        f_den,
        f,
        c,
        c_to_p_equals_f,
        residue_check,
    })
}

pub fn build_cycle_ehat_distorted_article640_fixture() -> Option<CycleEhatArticle640Fixture> {
    let p_source = sample_cycle_ehat_point()?;
    let q_raw = p_source.double()?;
    let p_eval = CycleEhatPointFq6::from_fq2_point(&p_source);
    let neg_p_eval = p_eval.neg();
    let q = cycle_ehat_distortion(&q_raw);
    if !p_eval.is_on_curve() || !q.is_on_curve() { return None; }

    let scalar = modulus_p();
    let naf = naf_digits_lsb(&scalar);
    let mut t = q.clone();
    let mut f = Fq6::one();
    let mut steps = Vec::new();

    for idx in (0..naf.len() - 1).rev() {
        let dbl = CycleEhatLineFq6::for_double(&t)?;
        let line = dbl.evaluate(&p_eval).mul(&dbl.evaluate(&neg_p_eval));
        f = f.square().mul(&line);
        t = t.double()?;
        steps.push(CycleEhatLineStep { is_double: true, line_value: line });
        match naf[idx] {
            1 => {
                let line = if let Some(add) = CycleEhatLineFq6::for_add(&t, &q) {
                    add.evaluate(&p_eval).mul(&add.evaluate(&neg_p_eval))
                } else if t.x == q.x && t.y.add(&q.y).is_zero() {
                    p_eval.x.sub(&t.x).mul(&neg_p_eval.x.sub(&t.x))
                } else { return None; };
                f = f.mul(&line);
                t = t.add(&q)?;
                steps.push(CycleEhatLineStep { is_double: false, line_value: line });
            }
            -1 => {
                let neg_q = q.neg();
                let line = if let Some(sub) = CycleEhatLineFq6::for_sub(&t, &q) {
                    sub.evaluate(&p_eval).mul(&sub.evaluate(&neg_p_eval))
                } else if t.x == neg_q.x && t.y.add(&neg_q.y).is_zero() {
                    p_eval.x.sub(&t.x).mul(&neg_p_eval.x.sub(&t.x))
                } else { return None; };
                f = f.mul(&line);
                t = t.add(&neg_q)?;
                steps.push(CycleEhatLineStep { is_double: false, line_value: line });
            }
            0 => {}
            _ => return None,
        }
    }

    let h = cycle_ehat_final_exponent_value();
    let direct_is_one = f.pow(&h).is_one();
    if !direct_is_one { return None; }
    let exp = modinv(&modulus_p(), &h)?;
    let c = f.pow(&exp);
    let c_inv = c.inverse()?;
    let c_times_c_inv_is_one = c.mul(&c_inv).is_one();
    let c_to_p_equals_core = c.pow(&modulus_p()) == f;
    Some(CycleEhatArticle640Fixture { steps, core: f, c, c_inv, direct_is_one, c_times_c_inv_is_one, c_to_p_equals_core })
}
