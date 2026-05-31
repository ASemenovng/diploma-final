use crate::field::{Fp, Fp2};
use crate::field_q::{Fq, Fq2};
use crate::params::{
    modulus_p, modulus_q, supersingular_cycle_e_cofactor_q,
    supersingular_cycle_ehat_cofactor_p,
};
use num_bigint::BigUint;
use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub struct CycleEPointFp2 {
    pub x: Fp2,
    pub y: Fp2,
}

impl CycleEPointFp2 {
    pub fn infinity() -> Self { Self { x: Fp2::zero(), y: Fp2::zero() } }
    pub fn is_infinity(&self) -> bool { self.x.is_zero() && self.y.is_zero() }
    pub fn a() -> Fp2 { Fp2::new(Fp::one(), Fp::one()) } // mu + 1, mu^2=-1
    pub fn b() -> Fp2 { Fp2::zero() }
    pub fn is_on_curve(&self) -> bool {
        if self.is_infinity() { return true; }
        self.y.square() == self.x.square().mul(&self.x).add(&Self::a().mul(&self.x)).add(&Self::b())
    }
    pub fn neg(&self) -> Self {
        if self.is_infinity() { Self::infinity() } else { Self { x: self.x.clone(), y: self.y.neg() } }
    }
    pub fn double(&self) -> Option<Self> {
        if self.is_infinity() { return Some(Self::infinity()); }
        if self.y.is_zero() { return Some(Self::infinity()); }
        let three = Fp2::new(Fp::from(3u64), Fp::zero());
        let two = Fp2::new(Fp::from(2u64), Fp::zero());
        let lambda = three.mul(&self.x.square()).add(&Self::a()).mul(&two.mul(&self.y).inverse()?);
        Some(Self::from_slope(self, self, &lambda))
    }
    pub fn add(&self, rhs: &Self) -> Option<Self> {
        if self.is_infinity() { return Some(rhs.clone()); }
        if rhs.is_infinity() { return Some(self.clone()); }
        if self.x == rhs.x {
            if self.y.add(&rhs.y).is_zero() { return Some(Self::infinity()); }
            return self.double();
        }
        let lambda = rhs.y.sub(&self.y).mul(&rhs.x.sub(&self.x).inverse()?);
        Some(Self::from_slope(self, rhs, &lambda))
    }
    fn from_slope(a: &Self, b: &Self, lambda: &Fp2) -> Self {
        let x3 = lambda.square().sub(&a.x).sub(&b.x);
        let y3 = lambda.mul(&a.x.sub(&x3)).sub(&a.y);
        Self { x: x3, y: y3 }
    }
    pub fn scalar_mul(&self, scalar: &BigUint) -> Option<Self> {
        let mut acc = Self::infinity();
        let mut base = self.clone();
        let mut k = scalar.clone();
        while k > BigUint::from(0u8) {
            if (&k & BigUint::from(1u8)) == BigUint::from(1u8) { acc = acc.add(&base)?; }
            base = base.double()?;
            k >>= 1usize;
        }
        Some(acc)
    }
    pub fn find_point_from(seed: u64) -> Option<Self> {
        for i in seed..seed + 512 {
            for j in 0..8u64 {
                let x = Fp2::new(Fp::from(i), Fp::from(j));
                let rhs = x.square().mul(&x).add(&Self::a().mul(&x));
                if let Some(y) = rhs.sqrt() { return Some(Self { x, y }); }
            }
        }
        None
    }
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub struct CycleEhatPointFq2 {
    pub x: Fq2,
    pub y: Fq2,
}

impl CycleEhatPointFq2 {
    pub fn infinity() -> Self { Self { x: Fq2::zero(), y: Fq2::zero() } }
    pub fn is_infinity(&self) -> bool { self.x.is_zero() && self.y.is_zero() }
    pub fn a() -> Fq2 { Fq2::zero() }
    pub fn b() -> Fq2 { Fq2::new(Fq::from(2u64), Fq::one()) } // eta + 2, eta^2=-2
    pub fn is_on_curve(&self) -> bool {
        if self.is_infinity() { return true; }
        self.y.square() == self.x.square().mul(&self.x).add(&Self::b())
    }
    pub fn neg(&self) -> Self {
        if self.is_infinity() { Self::infinity() } else { Self { x: self.x.clone(), y: self.y.neg() } }
    }
    pub fn double(&self) -> Option<Self> {
        if self.is_infinity() { return Some(Self::infinity()); }
        if self.y.is_zero() { return Some(Self::infinity()); }
        let three = Fq2::new(Fq::from(3u64), Fq::zero());
        let two = Fq2::new(Fq::from(2u64), Fq::zero());
        let lambda = three.mul(&self.x.square()).mul(&two.mul(&self.y).inverse()?);
        Some(Self::from_slope(self, self, &lambda))
    }
    pub fn add(&self, rhs: &Self) -> Option<Self> {
        if self.is_infinity() { return Some(rhs.clone()); }
        if rhs.is_infinity() { return Some(self.clone()); }
        if self.x == rhs.x {
            if self.y.add(&rhs.y).is_zero() { return Some(Self::infinity()); }
            return self.double();
        }
        let lambda = rhs.y.sub(&self.y).mul(&rhs.x.sub(&self.x).inverse()?);
        Some(Self::from_slope(self, rhs, &lambda))
    }
    fn from_slope(a: &Self, b: &Self, lambda: &Fq2) -> Self {
        let x3 = lambda.square().sub(&a.x).sub(&b.x);
        let y3 = lambda.mul(&a.x.sub(&x3)).sub(&a.y);
        Self { x: x3, y: y3 }
    }
    pub fn scalar_mul(&self, scalar: &BigUint) -> Option<Self> {
        let mut acc = Self::infinity();
        let mut base = self.clone();
        let mut k = scalar.clone();
        while k > BigUint::from(0u8) {
            if (&k & BigUint::from(1u8)) == BigUint::from(1u8) { acc = acc.add(&base)?; }
            base = base.double()?;
            k >>= 1usize;
        }
        Some(acc)
    }
    pub fn find_point_from(seed: u64) -> Option<Self> {
        for i in seed..seed + 512 {
            for j in 0..8u64 {
                let x = Fq2::new(Fq::from(i), Fq::from(j));
                let rhs = x.square().mul(&x).add(&Self::b());
                if let Some(y) = rhs.sqrt() { return Some(Self { x, y }); }
            }
        }
        None
    }
}

pub fn sample_cycle_e_point() -> Option<CycleEPointFp2> {
    let p = CycleEPointFp2::find_point_from(1)?;
    let g = p.scalar_mul(&supersingular_cycle_e_cofactor_q())?;
    if g.is_infinity() || !g.scalar_mul(&modulus_q())?.is_infinity() { None } else { Some(g) }
}

pub fn sample_cycle_ehat_point() -> Option<CycleEhatPointFq2> {
    let p = CycleEhatPointFq2::find_point_from(1)?;
    let g = p.scalar_mul(&supersingular_cycle_ehat_cofactor_p())?;
    if g.is_infinity() || !g.scalar_mul(&modulus_p())?.is_infinity() { None } else { Some(g) }
}
