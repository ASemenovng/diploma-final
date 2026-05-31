use crate::curve::{e_stick_a, e_stick_b, AffinePointFp};
use crate::field::{Fp, Fp2, Fp4};
use crate::params::{cofactor_e_fp4_r, order_r};
use num_bigint::BigUint;
use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub struct AffinePointFp4 {
    pub x: Fp4,
    pub y: Fp4,
    pub infinity: bool,
}

fn coeff_a() -> Fp4 {
    Fp4::from_fp(e_stick_a())
}
fn coeff_b() -> Fp4 {
    Fp4::from_fp(e_stick_b())
}

impl AffinePointFp4 {
    pub fn infinity() -> Self {
        Self {
            x: Fp4::zero(),
            y: Fp4::zero(),
            infinity: true,
        }
    }
    pub fn is_infinity(&self) -> bool {
        self.infinity
    }

    pub fn from_fp_point(p: &AffinePointFp) -> Self {
        if p.is_infinity() {
            Self::infinity()
        } else {
            Self {
                x: Fp4::from_fp(p.x.clone()),
                y: Fp4::from_fp(p.y.clone()),
                infinity: false,
            }
        }
    }

    pub fn from_fp_xy(x: Fp, y: Fp) -> Self {
        Self {
            x: Fp4::from_fp(x),
            y: Fp4::from_fp(y),
            infinity: false,
        }
    }

    pub fn is_on_stick_curve(&self) -> bool {
        if self.infinity {
            return true;
        }
        let lhs = self.y.square();
        let rhs = self
            .x
            .square()
            .mul(&self.x)
            .add(&coeff_a().mul(&self.x))
            .add(&coeff_b());
        lhs == rhs
    }

    pub fn neg(&self) -> Self {
        if self.infinity {
            Self::infinity()
        } else {
            Self {
                x: self.x.clone(),
                y: self.y.neg(),
                infinity: false,
            }
        }
    }

    pub fn double(&self) -> Option<Self> {
        if self.infinity {
            return Some(Self::infinity());
        }
        if self.y.is_zero() {
            return Some(Self::infinity());
        }
        let three = Fp4::from_fp(Fp::from(3u64));
        let two = Fp4::from_fp(Fp::from(2u64));
        let numerator = three.mul(&self.x.square()).add(&coeff_a());
        let denominator = two.mul(&self.y).inverse()?;
        let lambda = numerator.mul(&denominator);
        Some(Self::from_slope(self, self, &lambda))
    }

    pub fn add(&self, rhs: &Self) -> Option<Self> {
        if self.infinity {
            return Some(rhs.clone());
        }
        if rhs.infinity {
            return Some(self.clone());
        }
        if self.x == rhs.x {
            if self.y.add(&rhs.y).is_zero() {
                return Some(Self::infinity());
            }
            return self.double();
        }
        let lambda = rhs.y.sub(&self.y).mul(&rhs.x.sub(&self.x).inverse()?);
        Some(Self::from_slope(self, rhs, &lambda))
    }

    fn from_slope(a: &Self, b: &Self, lambda: &Fp4) -> Self {
        let x3 = lambda.square().sub(&a.x).sub(&b.x);
        let y3 = lambda.mul(&a.x.sub(&x3)).sub(&a.y);
        Self {
            x: x3,
            y: y3,
            infinity: false,
        }
    }

    pub fn scalar_mul(&self, scalar: &BigUint) -> Option<Self> {
        let mut acc = Self::infinity();
        let mut base = self.clone();
        let mut k = scalar.clone();
        while k > BigUint::from(0u8) {
            if (&k & BigUint::from(1u8)) == BigUint::from(1u8) {
                acc = acc.add(&base)?;
            }
            base = base.double()?;
            k >>= 1usize;
        }
        Some(acc)
    }

    pub fn find_point_from_fp4_seed(seed: u64) -> Option<Self> {
        for i in 0..2_000u64 {
            let x = Fp4::from_u64s(seed + i, 1, 0, 0);
            let rhs = x.square().mul(&x).add(&coeff_a().mul(&x)).add(&coeff_b());
            if let Some(y) = rhs.sqrt() {
                let p = Self {
                    x,
                    y,
                    infinity: false,
                };
                if p.is_on_stick_curve() {
                    return Some(p);
                }
            }
        }
        None
    }

    pub fn sample_r_subgroup_point_fp4_projective() -> Option<Self> {
        let cof = cofactor_e_fp4_r();
        for seed in 2..128u64 {
            let p = Self::find_point_from_fp4_seed(seed)?;
            let r = ProjectivePointFp4::from_affine(&p)
                .scalar_mul(&cof)
                .to_affine()?;
            if !r.is_infinity() && r.is_in_r_subgroup() {
                return Some(r);
            }
        }
        None
    }

    pub fn sample_r_subgroup_point_fp4() -> Option<Self> {
        let cof = cofactor_e_fp4_r();
        for seed in 2..128u64 {
            let p = Self::find_point_from_fp4_seed(seed)?;
            let r = p.scalar_mul(&cof)?;
            if !r.is_infinity() && r.is_in_r_subgroup() {
                return Some(r);
            }
        }
        None
    }

    pub fn is_in_r_subgroup(&self) -> bool {
        if !self.is_on_stick_curve() {
            return false;
        }
        ProjectivePointFp4::from_affine(self)
            .scalar_mul(&order_r())
            .is_infinity()
    }
}

#[allow(dead_code)]
pub fn fp4_from_base_pair(c0: Fp, c1: Fp) -> Fp4 {
    Fp4::new(Fp2::new(c0, c1), Fp2::zero())
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub struct ProjectivePointFp4 {
    pub x: Fp4,
    pub y: Fp4,
    pub z: Fp4,
}

impl ProjectivePointFp4 {
    pub fn infinity() -> Self {
        Self {
            x: Fp4::zero(),
            y: Fp4::one(),
            z: Fp4::zero(),
        }
    }

    pub fn is_infinity(&self) -> bool {
        self.z.is_zero()
    }

    pub fn from_affine(p: &AffinePointFp4) -> Self {
        if p.is_infinity() {
            Self::infinity()
        } else {
            Self {
                x: p.x.clone(),
                y: p.y.clone(),
                z: Fp4::one(),
            }
        }
    }

    pub fn to_affine(&self) -> Option<AffinePointFp4> {
        if self.is_infinity() {
            return Some(AffinePointFp4::infinity());
        }
        let z_inv = self.z.inverse()?;
        let z2 = z_inv.square();
        let z3 = z2.mul(&z_inv);
        Some(AffinePointFp4 {
            x: self.x.mul(&z2),
            y: self.y.mul(&z3),
            infinity: false,
        })
    }

    pub fn double(&self) -> Self {
        if self.is_infinity() || self.y.is_zero() {
            return Self::infinity();
        }
        let two = Fp4::from_fp(Fp::from(2u64));
        let three = Fp4::from_fp(Fp::from(3u64));
        let four = Fp4::from_fp(Fp::from(4u64));
        let eight = Fp4::from_fp(Fp::from(8u64));
        let xx = self.x.square();
        let yy = self.y.square();
        let yyyy = yy.square();
        let zz = self.z.square();
        let s = self.x.add(&yy).square().sub(&xx).sub(&yyyy).mul(&two);
        let m = xx.mul(&three).add(&coeff_a().mul(&zz.square()));
        let t = m.square().sub(&s.mul(&two));
        let x3 = t.clone();
        let y3 = m.mul(&s.sub(&t)).sub(&yyyy.mul(&eight));
        let z3 = self.y.add(&self.z).square().sub(&yy).sub(&zz);
        // Keep formula variables used as expected; `four` documents S=4*X*Y^2 equivalent above.
        let _ = four;
        Self {
            x: x3,
            y: y3,
            z: z3,
        }
    }

    pub fn add(&self, rhs: &Self) -> Self {
        if self.is_infinity() {
            return rhs.clone();
        }
        if rhs.is_infinity() {
            return self.clone();
        }
        let two = Fp4::from_fp(Fp::from(2u64));
        let z1z1 = self.z.square();
        let z2z2 = rhs.z.square();
        let u1 = self.x.mul(&z2z2);
        let u2 = rhs.x.mul(&z1z1);
        let s1 = self.y.mul(&rhs.z).mul(&z2z2);
        let s2 = rhs.y.mul(&self.z).mul(&z1z1);
        if u1 == u2 {
            if s1 == s2 {
                return self.double();
            }
            return Self::infinity();
        }
        let h = u2.sub(&u1);
        let i = h.mul(&two).square();
        let j = h.mul(&i);
        let r = s2.sub(&s1).mul(&two);
        let v = u1.mul(&i);
        let x3 = r.square().sub(&j).sub(&v.mul(&two));
        let y3 = r.mul(&v.sub(&x3)).sub(&s1.mul(&j).mul(&two));
        let z3 = self.z.add(&rhs.z).square().sub(&z1z1).sub(&z2z2).mul(&h);
        Self {
            x: x3,
            y: y3,
            z: z3,
        }
    }

    pub fn scalar_mul(&self, scalar: &BigUint) -> Self {
        let mut acc = Self::infinity();
        let mut base = self.clone();
        let mut k = scalar.clone();
        while k > BigUint::from(0u8) {
            if (&k & BigUint::from(1u8)) == BigUint::from(1u8) {
                acc = acc.add(&base);
            }
            base = base.double();
            k >>= 1usize;
        }
        acc
    }
}
