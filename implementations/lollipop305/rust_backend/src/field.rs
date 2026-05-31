use crate::params::modulus_p;
use num_bigint::BigUint;
use num_traits::{One, Zero};
use serde::{de, Deserialize, Deserializer, Serialize, Serializer};
use std::fmt;

#[derive(Clone, Eq, PartialEq)]
pub struct Fp(BigUint);

impl fmt::Debug for Fp {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", self.0)
    }
}

impl Serialize for Fp {
    fn serialize<S>(&self, serializer: S) -> Result<S::Ok, S::Error>
    where
        S: Serializer,
    {
        serializer.serialize_str(&self.0.to_string())
    }
}

impl<'de> Deserialize<'de> for Fp {
    fn deserialize<D>(deserializer: D) -> Result<Self, D::Error>
    where
        D: Deserializer<'de>,
    {
        let s = String::deserialize(deserializer)?;
        BigUint::parse_bytes(s.as_bytes(), 10)
            .map(Fp::new)
            .ok_or_else(|| de::Error::custom("invalid decimal Fp element"))
    }
}

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
    pub fn is_zero(&self) -> bool {
        self.0.is_zero()
    }
    pub fn dec(&self) -> String {
        self.0.to_string()
    }
    pub fn hex(&self) -> String {
        format!("0x{}", self.0.to_str_radix(16))
    }

    pub fn add(&self, rhs: &Self) -> Self {
        Self::new(&self.0 + &rhs.0)
    }

    pub fn sub(&self, rhs: &Self) -> Self {
        if self.0 >= rhs.0 {
            Self(&self.0 - &rhs.0)
        } else {
            Self(&self.0 + modulus_p() - &rhs.0)
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
    pub fn pow(&self, exp: &BigUint) -> Self {
        Self(self.0.modpow(exp, &modulus_p()))
    }

    pub fn inverse(&self) -> Option<Self> {
        if self.0.is_zero() {
            None
        } else {
            Some(self.pow(&(modulus_p() - BigUint::from(2u8))))
        }
    }

    pub fn sqrt(&self) -> Option<Self> {
        let p = modulus_p();
        if self.0.is_zero() {
            return Some(Self::zero());
        }
        // The lollipop-305 p satisfies p = 3 mod 4.
        let exp = (&p + BigUint::one()) >> 2usize;
        let y = self.pow(&exp);
        if y.square() == *self {
            Some(y)
        } else {
            None
        }
    }
}

impl From<u64> for Fp {
    fn from(value: u64) -> Self {
        Self::new(BigUint::from(value))
    }
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub struct Fp2 {
    pub c0: Fp,
    pub c1: Fp,
}

impl Fp2 {
    pub fn new(c0: Fp, c1: Fp) -> Self {
        Self { c0, c1 }
    }
    pub fn zero() -> Self {
        Self::new(Fp::zero(), Fp::zero())
    }
    pub fn one() -> Self {
        Self::new(Fp::one(), Fp::zero())
    }
    pub fn is_zero(&self) -> bool {
        self.c0.is_zero() && self.c1.is_zero()
    }
    pub fn add(&self, rhs: &Self) -> Self {
        Self::new(self.c0.add(&rhs.c0), self.c1.add(&rhs.c1))
    }
    pub fn sub(&self, rhs: &Self) -> Self {
        Self::new(self.c0.sub(&rhs.c0), self.c1.sub(&rhs.c1))
    }
    pub fn neg(&self) -> Self {
        Self::new(self.c0.neg(), self.c1.neg())
    }

    pub fn frobenius_p(&self) -> Self {
        // p = 3 mod 4 and u^2=-1, hence u^p=-u.
        Self::new(self.c0.clone(), self.c1.neg())
    }

    pub fn mul_by_u(&self) -> Self {
        // u^2 = -1.
        Self::new(self.c1.neg(), self.c0.clone())
    }

    pub fn mul_by_fp4_nonresidue(&self) -> Self {
        // For lollipop-305, u is a square in Fp2 because p = 3 mod 8.
        // Therefore Fp2[v]/(v^2-u) is not a field. We use xi = 1+u,
        // which is a deterministic non-square in Fp2 for these parameters.
        self.add(&self.mul_by_u())
    }

    pub fn mul(&self, rhs: &Self) -> Self {
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

    pub fn inverse(&self) -> Option<Self> {
        if self.is_zero() {
            return None;
        }
        // (a+b*u)^-1 = (a-b*u)/(a^2+b^2), because u^2=-1.
        let denom = self.c0.square().add(&self.c1.square()).inverse()?;
        Some(Self::new(self.c0.mul(&denom), self.c1.neg().mul(&denom)))
    }

    pub fn pow(&self, exp: &BigUint) -> Self {
        let mut base = self.clone();
        let mut e = exp.clone();
        let mut acc = Self::one();
        while e > BigUint::zero() {
            if (&e & BigUint::one()) == BigUint::one() {
                acc = acc.mul(&base);
            }
            base = base.square();
            e >>= 1usize;
        }
        acc
    }

    pub fn legendre_is_square(&self) -> bool {
        if self.is_zero() {
            return true;
        }
        let q = modulus_p().pow(2);
        self.pow(&((&q - BigUint::one()) >> 1usize)) == Self::one()
    }

    pub fn sqrt(&self) -> Option<Self> {
        if self.is_zero() {
            return Some(Self::zero());
        }

        if !self.legendre_is_square() {
            return None;
        }

        let q_field = modulus_p().pow(2);
        let mut q = &q_field - BigUint::one();
        let mut s = 0usize;
        while (&q & BigUint::one()) == BigUint::zero() {
            q >>= 1usize;
            s += 1;
        }

        let mut z = Self::new(Fp::from(2u64), Fp::one());
        let mut seed = 3u64;
        while z.legendre_is_square() {
            z = Self::new(Fp::from(seed), Fp::one());
            seed += 1;
        }

        let mut m = s;
        let mut c = z.pow(&q);
        let mut t = self.pow(&q);
        let mut r = self.pow(&((&q + BigUint::one()) >> 1usize));

        while t != Self::one() {
            let mut i = 1usize;
            let mut t2i = t.square();
            while t2i != Self::one() {
                t2i = t2i.square();
                i += 1;
                if i >= m {
                    return None;
                }
            }
            let b = c.pow(&(BigUint::one() << (m - i - 1)));
            let b2 = b.square();
            r = r.mul(&b);
            t = t.mul(&b2);
            c = b2;
            m = i;
        }

        if r.square() == *self {
            Some(r)
        } else {
            None
        }
    }
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub struct Fp4 {
    pub c0: Fp2,
    pub c1: Fp2,
}

impl Fp4 {
    pub fn new(c0: Fp2, c1: Fp2) -> Self {
        Self { c0, c1 }
    }
    pub fn zero() -> Self {
        Self::new(Fp2::zero(), Fp2::zero())
    }
    pub fn one() -> Self {
        Self::new(Fp2::one(), Fp2::zero())
    }
    pub fn is_zero(&self) -> bool {
        self.c0.is_zero() && self.c1.is_zero()
    }
    pub fn is_one(&self) -> bool {
        *self == Self::one()
    }

    pub fn from_fp(x: Fp) -> Self {
        Self::new(Fp2::new(x, Fp::zero()), Fp2::zero())
    }

    pub fn from_fp2(x: Fp2) -> Self {
        Self::new(x, Fp2::zero())
    }

    pub fn from_u64s(a0: u64, a1: u64, a2: u64, a3: u64) -> Self {
        Self::new(
            Fp2::new(Fp::from(a0), Fp::from(a1)),
            Fp2::new(Fp::from(a2), Fp::from(a3)),
        )
    }

    pub fn add(&self, rhs: &Self) -> Self {
        Self::new(self.c0.add(&rhs.c0), self.c1.add(&rhs.c1))
    }
    pub fn sub(&self, rhs: &Self) -> Self {
        Self::new(self.c0.sub(&rhs.c0), self.c1.sub(&rhs.c1))
    }
    pub fn neg(&self) -> Self {
        Self::new(self.c0.neg(), self.c1.neg())
    }

    pub fn mul(&self, rhs: &Self) -> Self {
        // Fp4 = Fp2[v]/(v^2-xi), xi = 1+u.
        let v0 = self.c0.mul(&rhs.c0);
        let v1 = self.c1.mul(&rhs.c1);
        let v2 = self.c0.add(&self.c1).mul(&rhs.c0.add(&rhs.c1));
        Self::new(v0.add(&v1.mul_by_fp4_nonresidue()), v2.sub(&v0).sub(&v1))
    }

    pub fn square(&self) -> Self {
        let v0 = self.c0.square();
        let v1 = self.c1.square();
        let cross = self.c0.mul(&self.c1);
        Self::new(v0.add(&v1.mul_by_fp4_nonresidue()), cross.add(&cross))
    }

    pub fn inverse(&self) -> Option<Self> {
        if self.is_zero() {
            return None;
        }
        // (c0+c1*v)^-1 = (c0-c1*v)/(c0^2-xi*c1^2), because v^2=xi.
        let denom = self
            .c0
            .square()
            .sub(&self.c1.square().mul_by_fp4_nonresidue());
        let denom_inv = denom.inverse()?;
        Some(Self::new(
            self.c0.mul(&denom_inv),
            self.c1.neg().mul(&denom_inv),
        ))
    }

    pub fn pow(&self, exp: &BigUint) -> Self {
        let mut base = self.clone();
        let mut e = exp.clone();
        let mut acc = Self::one();
        while e > BigUint::zero() {
            if (&e & BigUint::one()) == BigUint::one() {
                acc = acc.mul(&base);
            }
            base = base.square();
            e >>= 1usize;
        }
        acc
    }

    pub fn legendre_is_square(&self) -> bool {
        if self.is_zero() {
            return true;
        }
        let q = modulus_p().pow(4);
        self.pow(&((&q - BigUint::one()) >> 1usize)).is_one()
    }

    pub fn sqrt(&self) -> Option<Self> {
        if self.is_zero() {
            return Some(Self::zero());
        }

        // Fast path for Fp4=Fp2[v]/(v^2-xi). If z=a+bv and y=x0+x1v,
        // then y^2=z iff x0^2+xi*x1^2=a and 2*x0*x1=b.
        let two = Fp2::new(Fp::from(2u64), Fp::zero());
        let two_inv_fp = Fp::from(2u64).inverse()?;
        if self.c1.is_zero() {
            if let Some(root_c0) = self.c0.sqrt() {
                return Some(Self::new(root_c0, Fp2::zero()));
            }
            let xi_inv = Fp2::one().mul_by_fp4_nonresidue().inverse()?;
            if let Some(root_c1) = self.c0.mul(&xi_inv).sqrt() {
                return Some(Self::new(Fp2::zero(), root_c1));
            }
        } else {
            let norm = self
                .c0
                .square()
                .sub(&self.c1.square().mul_by_fp4_nonresidue());
            if let Some(s) = norm.sqrt() {
                for t in [self.c0.add(&s), self.c0.sub(&s)] {
                    let half_t = Fp2::new(t.c0.mul(&two_inv_fp), t.c1.mul(&two_inv_fp));
                    if let Some(x0) = half_t.sqrt() {
                        let denom = two.mul(&x0).inverse()?;
                        let x1 = self.c1.mul(&denom);
                        let candidate = Self::new(x0, x1);
                        if candidate.square() == *self {
                            return Some(candidate);
                        }
                    }
                }
            }
        }

        if !self.legendre_is_square() {
            return None;
        }

        let q_field = modulus_p().pow(4);
        let mut q = &q_field - BigUint::one();
        let mut s = 0usize;
        while (&q & BigUint::one()) == BigUint::zero() {
            q >>= 1usize;
            s += 1;
        }

        let mut z = Self::from_u64s(2, 1, 0, 0);
        let mut seed = 3u64;
        while z.legendre_is_square() {
            z = Self::from_u64s(seed, 1, 0, 0);
            seed += 1;
        }

        let mut m = s;
        let mut c = z.pow(&q);
        let mut t = self.pow(&q);
        let mut r = self.pow(&((&q + BigUint::one()) >> 1usize));

        while !t.is_one() {
            let mut i = 1usize;
            let mut t2i = t.square();
            while !t2i.is_one() {
                t2i = t2i.square();
                i += 1;
                if i >= m {
                    return None;
                }
            }
            let b = c.pow(&(BigUint::one() << (m - i - 1)));
            let b2 = b.square();
            r = r.mul(&b);
            t = t.mul(&b2);
            c = b2;
            m = i;
        }

        if r.square() == *self {
            Some(r)
        } else {
            None
        }
    }
}
