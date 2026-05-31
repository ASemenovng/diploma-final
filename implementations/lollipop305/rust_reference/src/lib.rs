use num_bigint::BigUint;
use num_traits::{One, Zero};

pub fn x_parameter() -> BigUint {
    BigUint::parse_bytes(b"8004046504391788107635887004283725454478544674", 10).unwrap()
}

pub fn modulus_p() -> BigUint {
    BigUint::parse_bytes(
        b"64064760444466402482617092084437280876782408929523650941985296571943203113725143542535221603",
        10,
    )
    .unwrap()
}

pub fn modulus_q() -> BigUint {
    BigUint::parse_bytes(
        b"64064760444466402482617092084437280876782408937527697446377084679579090118008868997013766277",
        10,
    )
    .unwrap()
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct Fp(BigUint);

impl Fp {
    pub fn new<T: Into<BigUint>>(x: T) -> Self {
        Self(x.into() % modulus_p())
    }

    pub fn zero() -> Self {
        Self(BigUint::zero())
    }

    pub fn one() -> Self {
        Self(BigUint::one())
    }

    pub fn value(&self) -> &BigUint {
        &self.0
    }

    pub fn add(&self, rhs: &Self) -> Self {
        Self::new(&self.0 + &rhs.0)
    }

    pub fn sub(&self, rhs: &Self) -> Self {
        let p = modulus_p();
        if self.0 >= rhs.0 {
            Self(&self.0 - &rhs.0)
        } else {
            Self(&self.0 + p - &rhs.0)
        }
    }

    pub fn neg(&self) -> Self {
        if self.0.is_zero() {
            Self::zero()
        } else {
            Self(modulus_p() - &self.0)
        }
    }

    pub fn mul(&self, rhs: &Self) -> Self {
        Self::new(&self.0 * &rhs.0)
    }

    pub fn square(&self) -> Self {
        self.mul(self)
    }
}

impl From<u64> for Fp {
    fn from(value: u64) -> Self {
        Self::new(BigUint::from(value))
    }
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct Fp2 {
    pub c0: Fp,
    pub c1: Fp,
}

impl Fp2 {
    pub fn new(c0: Fp, c1: Fp) -> Self {
        Self { c0, c1 }
    }

    pub fn add(&self, rhs: &Self) -> Self {
        Self::new(self.c0.add(&rhs.c0), self.c1.add(&rhs.c1))
    }

    pub fn sub(&self, rhs: &Self) -> Self {
        Self::new(self.c0.sub(&rhs.c0), self.c1.sub(&rhs.c1))
    }

    pub fn mul_by_u(&self) -> Self {
        // u^2 = -1, so u*(a0+a1*u) = -a1 + a0*u.
        Self::new(self.c1.neg(), self.c0.clone())
    }

    pub fn mul_by_fp4_nonresidue(&self) -> Self {
        // xi = 1+u.
        self.add(&self.mul_by_u())
    }

    pub fn mul(&self, rhs: &Self) -> Self {
        // Karatsuba for u^2=-1.
        let v0 = self.c0.mul(&rhs.c0);
        let v1 = self.c1.mul(&rhs.c1);
        let v2 = self.c0.add(&self.c1).mul(&rhs.c0.add(&rhs.c1));
        Self::new(v0.sub(&v1), v2.sub(&v0).sub(&v1))
    }

    pub fn square(&self) -> Self {
        let v0 = self.c0.square();
        let v1 = self.c1.square();
        let v01 = self.c0.mul(&self.c1);
        Self::new(v0.sub(&v1), v01.add(&v01))
    }
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct Fp4 {
    pub c0: Fp2,
    pub c1: Fp2,
}

impl Fp4 {
    pub fn new(c0: Fp2, c1: Fp2) -> Self {
        Self { c0, c1 }
    }

    pub fn mul(&self, rhs: &Self) -> Self {
        // v^2 = xi = 1+u over Fp2.
        let v0 = self.c0.mul(&rhs.c0);
        let v1 = self.c1.mul(&rhs.c1);
        let v2 = self.c0.add(&self.c1).mul(&rhs.c0.add(&rhs.c1));
        Self::new(
            v0.add(&v1.mul_by_fp4_nonresidue()),
            v2.sub(&v0).sub(&v1),
        )
    }

    pub fn square(&self) -> Self {
        let v0 = self.c0.square();
        let v1 = self.c1.square();
        let cross = self.c0.mul(&self.c1);
        Self::new(v0.add(&v1.mul_by_fp4_nonresidue()), cross.add(&cross))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn modulus_matches_example_1_relations() {
        let x = x_parameter();
        let p = modulus_p();
        let q = modulus_q();
        assert_eq!(p, &x * &x - &x + BigUint::one());
        assert_eq!(q, &x * &x + BigUint::one());
        assert_eq!(p.bits(), 305);
        assert_eq!(q.bits(), 305);
    }

    #[test]
    fn fp2_small_vector() {
        let a = Fp2::new(Fp::from(3), Fp::from(5));
        let b = Fp2::new(Fp::from(7), Fp::from(11));
        let c = a.mul(&b);
        assert_eq!(c.c0, Fp::new(modulus_p() - BigUint::from(34u64)));
        assert_eq!(c.c1, Fp::from(68));
    }

    #[test]
    fn fp4_small_vector() {
        let a = Fp4::new(
            Fp2::new(Fp::from(3), Fp::from(5)),
            Fp2::new(Fp::from(7), Fp::from(11)),
        );
        let b = Fp4::new(
            Fp2::new(Fp::from(13), Fp::from(17)),
            Fp2::new(Fp::from(19), Fp::from(23)),
        );
        let c = a.mul(&b);
        assert_eq!(c.c0.c0, Fp::new(modulus_p() - BigUint::from(536u64)));
        assert_eq!(c.c0.c1, Fp::from(366));
        assert_eq!(c.c1.c0, Fp::new(modulus_p() - BigUint::from(154u64)));
        assert_eq!(c.c1.c1, Fp::from(426));
    }
}
