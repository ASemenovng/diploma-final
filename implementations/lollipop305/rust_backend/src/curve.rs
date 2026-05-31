use crate::field::Fp;
use crate::params::{stick_curve_a, stick_curve_b};
use num_bigint::BigUint;
use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub struct AffinePointFp {
    pub x: Fp,
    pub y: Fp,
}

pub fn e_stick_a() -> Fp {
    Fp::new(stick_curve_a())
}
pub fn e_stick_b() -> Fp {
    Fp::new(stick_curve_b())
}

pub static E_STICK_A: LazyFp = LazyFp::A;
pub static E_STICK_B: LazyFp = LazyFp::B;

#[derive(Copy, Clone, Debug)]
pub enum LazyFp {
    A,
    B,
}

impl LazyFp {
    pub fn value(self) -> Fp {
        match self {
            LazyFp::A => e_stick_a(),
            LazyFp::B => e_stick_b(),
        }
    }
}

impl AffinePointFp {
    /// Point at infinity encoded as the non-curve sentinel (0,0). This is sufficient for
    /// the backend trace builder; production serialization should use an explicit flag.
    pub fn infinity() -> Self {
        Self {
            x: Fp::zero(),
            y: Fp::zero(),
        }
    }
    pub fn is_infinity(&self) -> bool {
        self.x.is_zero() && self.y.is_zero()
    }

    pub fn is_on_curve(&self, a: &LazyFp, b: &LazyFp) -> bool {
        if self.is_infinity() {
            return true;
        }
        let lhs = self.y.square();
        let x2 = self.x.square();
        let x3 = x2.mul(&self.x);
        let rhs = x3.add(&a.value().mul(&self.x)).add(&b.value());
        lhs == rhs
    }

    pub fn neg(&self) -> Self {
        if self.is_infinity() {
            Self::infinity()
        } else {
            Self {
                x: self.x.clone(),
                y: self.y.neg(),
            }
        }
    }

    pub fn double(&self) -> Option<Self> {
        if self.is_infinity() {
            return Some(Self::infinity());
        }
        if self.y.is_zero() {
            return Some(Self::infinity());
        }
        let three = Fp::from(3u64);
        let two = Fp::from(2u64);
        let numerator = three.mul(&self.x.square()).add(&e_stick_a());
        let denominator = two.mul(&self.y).inverse()?;
        let lambda = numerator.mul(&denominator);
        Some(Self::from_slope(self, self, &lambda))
    }

    pub fn add(&self, rhs: &Self) -> Option<Self> {
        if self.is_infinity() {
            return Some(rhs.clone());
        }
        if rhs.is_infinity() {
            return Some(self.clone());
        }
        if self.x == rhs.x {
            if self.y.add(&rhs.y).is_zero() {
                return Some(Self::infinity());
            }
            return self.double();
        }
        let numerator = rhs.y.sub(&self.y);
        let denominator = rhs.x.sub(&self.x).inverse()?;
        let lambda = numerator.mul(&denominator);
        Some(Self::from_slope(self, rhs, &lambda))
    }

    fn from_slope(a: &Self, b: &Self, lambda: &Fp) -> Self {
        let x3 = lambda.square().sub(&a.x).sub(&b.x);
        let y3 = lambda.mul(&a.x.sub(&x3)).sub(&a.y);
        Self { x: x3, y: y3 }
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

    pub fn find_stick_point_from(start_x: u64) -> Option<Self> {
        let mut x = BigUint::from(start_x);
        for _ in 0..10_000u64 {
            let fx = Fp::new(x.clone());
            let rhs = fx
                .square()
                .mul(&fx)
                .add(&e_stick_a().mul(&fx))
                .add(&e_stick_b());
            if let Some(y) = rhs.sqrt() {
                return Some(Self { x: fx, y });
            }
            x += BigUint::from(1u8);
        }
        None
    }

    pub fn sample_stick_point() -> Self {
        Self::find_stick_point_from(0).expect("x=0 has sqrt(b) on lollipop-305 stick curve")
    }
}
