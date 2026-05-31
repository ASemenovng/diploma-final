use crate::params::modulus_q;
use num_bigint::BigUint;
use num_traits::{One, Zero};
use serde::{Deserialize, Serialize};
use std::fmt;
use std::sync::OnceLock;

#[derive(Clone, Eq, PartialEq, Serialize, Deserialize)]
pub struct Fq(BigUint);

impl fmt::Debug for Fq {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", self.0)
    }
}

impl Fq {
    pub fn new<T: Into<BigUint>>(x: T) -> Self {
        Self(x.into() % modulus_q())
    }
    pub fn zero() -> Self { Self(BigUint::zero()) }
    pub fn one() -> Self { Self(BigUint::one()) }
    pub fn value(&self) -> &BigUint { &self.0 }
    pub fn is_zero(&self) -> bool { self.0.is_zero() }
    pub fn add(&self, rhs: &Self) -> Self { Self::new(&self.0 + &rhs.0) }
    pub fn sub(&self, rhs: &Self) -> Self {
        if self.0 >= rhs.0 { Self(&self.0 - &rhs.0) } else { Self(&self.0 + modulus_q() - &rhs.0) }
    }
    pub fn neg(&self) -> Self { if self.is_zero() { Self::zero() } else { Self(modulus_q() - &self.0) } }
    pub fn mul(&self, rhs: &Self) -> Self { Self::new(&self.0 * &rhs.0) }
    pub fn square(&self) -> Self { self.mul(self) }
    pub fn pow(&self, exp: &BigUint) -> Self { Self(self.0.modpow(exp, &modulus_q())) }
    pub fn inverse(&self) -> Option<Self> {
        if self.is_zero() { None } else { Some(self.pow(&(modulus_q() - BigUint::from(2u8)))) }
    }
}

impl From<u64> for Fq {
    fn from(value: u64) -> Self { Self::new(BigUint::from(value)) }
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub struct Fq2 {
    pub c0: Fq,
    pub c1: Fq,
}

impl Fq2 {
    pub fn new(c0: Fq, c1: Fq) -> Self { Self { c0, c1 } }
    pub fn zero() -> Self { Self::new(Fq::zero(), Fq::zero()) }
    pub fn one() -> Self { Self::new(Fq::one(), Fq::zero()) }
    pub fn is_zero(&self) -> bool { self.c0.is_zero() && self.c1.is_zero() }
    pub fn add(&self, rhs: &Self) -> Self { Self::new(self.c0.add(&rhs.c0), self.c1.add(&rhs.c1)) }
    pub fn sub(&self, rhs: &Self) -> Self { Self::new(self.c0.sub(&rhs.c0), self.c1.sub(&rhs.c1)) }
    pub fn neg(&self) -> Self { Self::new(self.c0.neg(), self.c1.neg()) }

    pub fn frobenius_q(&self) -> Self {
        // eta^2=-2 and eta is not in Fq, hence q-Frobenius is conjugation.
        Self::new(self.c0.clone(), self.c1.neg())
    }

    pub fn mul_by_eta(&self) -> Self {
        // Fq2 = Fq[eta]/(eta^2+2), so eta^2=-2.
        Self::new(Fq::from(2u64).neg().mul(&self.c1), self.c0.clone())
    }

    pub fn mul(&self, rhs: &Self) -> Self {
        let v0 = self.c0.mul(&rhs.c0);
        let v1 = self.c1.mul(&rhs.c1);
        let v2 = self.c0.add(&self.c1).mul(&rhs.c0.add(&rhs.c1));
        let minus_two_v1 = Fq::from(2u64).neg().mul(&v1);
        Self::new(v0.add(&minus_two_v1), v2.sub(&v0).sub(&v1))
    }

    pub fn square(&self) -> Self {
        let a2 = self.c0.square();
        let b2 = self.c1.square();
        let ab = self.c0.mul(&self.c1);
        Self::new(a2.sub(&Fq::from(2u64).mul(&b2)), ab.add(&ab))
    }

    pub fn inverse(&self) -> Option<Self> {
        if self.is_zero() { return None; }
        // (a+b*eta)^-1 = (a-b*eta)/(a^2+2b^2), eta^2=-2.
        let denom = self.c0.square().add(&Fq::from(2u64).mul(&self.c1.square())).inverse()?;
        Some(Self::new(self.c0.mul(&denom), self.c1.neg().mul(&denom)))
    }

    pub fn pow(&self, exp: &BigUint) -> Self {
        let mut base = self.clone();
        let mut e = exp.clone();
        let mut acc = Self::one();
        while e > BigUint::zero() {
            if (&e & BigUint::one()) == BigUint::one() { acc = acc.mul(&base); }
            base = base.square();
            e >>= 1usize;
        }
        acc
    }

    pub fn legendre_is_square(&self) -> bool {
        if self.is_zero() { return true; }
        let field_order = modulus_q().pow(2);
        self.pow(&((&field_order - BigUint::one()) >> 1usize)) == Self::one()
    }

    pub fn sqrt(&self) -> Option<Self> {
        if self.is_zero() { return Some(Self::zero()); }
        if !self.legendre_is_square() { return None; }
        let field_order = modulus_q().pow(2);
        let mut q = &field_order - BigUint::one();
        let mut s = 0usize;
        while (&q & BigUint::one()) == BigUint::zero() { q >>= 1usize; s += 1; }
        let mut z = Self::new(Fq::from(1u64), Fq::from(1u64));
        let mut seed = 2u64;
        while z.legendre_is_square() {
            z = Self::new(Fq::from(seed), Fq::one());
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
                if i >= m { return None; }
            }
            let b = c.pow(&(BigUint::one() << (m - i - 1)));
            let b2 = b.square();
            r = r.mul(&b);
            t = t.mul(&b2);
            c = b2;
            m = i;
        }
        if r.square() == *self { Some(r) } else { None }
    }
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub struct Fq6 {
    pub c0: Fq2,
    pub c1: Fq2,
    pub c2: Fq2,
}

impl Fq6 {
    pub fn new(c0: Fq2, c1: Fq2, c2: Fq2) -> Self { Self { c0, c1, c2 } }
    pub fn zero() -> Self { Self::new(Fq2::zero(), Fq2::zero(), Fq2::zero()) }
    pub fn one() -> Self { Self::new(Fq2::one(), Fq2::zero(), Fq2::zero()) }
    pub fn from_fq2(x: Fq2) -> Self { Self::new(x, Fq2::zero(), Fq2::zero()) }
    pub fn is_zero(&self) -> bool { self.c0.is_zero() && self.c1.is_zero() && self.c2.is_zero() }
    pub fn is_one(&self) -> bool { *self == Self::one() }
    pub fn add(&self, rhs: &Self) -> Self {
        Self::new(self.c0.add(&rhs.c0), self.c1.add(&rhs.c1), self.c2.add(&rhs.c2))
    }
    pub fn sub(&self, rhs: &Self) -> Self {
        Self::new(self.c0.sub(&rhs.c0), self.c1.sub(&rhs.c1), self.c2.sub(&rhs.c2))
    }
    pub fn neg(&self) -> Self { Self::new(self.c0.neg(), self.c1.neg(), self.c2.neg()) }
    pub fn rho() -> Fq2 {
        static RHO: OnceLock<Fq2> = OnceLock::new();
        RHO.get_or_init(|| {
            let b = Fq2::new(Fq::from(2u64), Fq::one());
            let bq = b.frobenius_q();
            b.mul(&bq.inverse().expect("non-zero b^q"))
                .sqrt()
                .expect("sqrt((2+eta)/(2-eta)) exists for lollipop-305")
        }).clone()
    }
    pub fn w() -> Self { Self::new(Fq2::zero(), Fq2::one(), Fq2::zero()) }
    pub fn w2() -> Self { Self::new(Fq2::zero(), Fq2::zero(), Fq2::one()) }
    pub fn mul(&self, rhs: &Self) -> Self {
        let rho = Self::rho();
        let a0b0 = self.c0.mul(&rhs.c0);
        let a0b1 = self.c0.mul(&rhs.c1);
        let a0b2 = self.c0.mul(&rhs.c2);
        let a1b0 = self.c1.mul(&rhs.c0);
        let a1b1 = self.c1.mul(&rhs.c1);
        let a1b2 = self.c1.mul(&rhs.c2);
        let a2b0 = self.c2.mul(&rhs.c0);
        let a2b1 = self.c2.mul(&rhs.c1);
        let a2b2 = self.c2.mul(&rhs.c2);
        Self::new(
            a0b0.add(&rho.mul(&a1b2.add(&a2b1))),
            a0b1.add(&a1b0).add(&rho.mul(&a2b2)),
            a0b2.add(&a1b1).add(&a2b0),
        )
    }
    pub fn square(&self) -> Self { self.mul(self) }
    pub fn mul_by_01(&self, a: &Fq2, b: &Fq2) -> Self {
        // (c0 + c1*w + c2*w^2) * (a + b*w), w^3=rho.
        let rho = Self::rho();
        Self::new(
            self.c0.mul(a).add(&rho.mul(&self.c2.mul(b))),
            self.c0.mul(b).add(&self.c1.mul(a)),
            self.c1.mul(b).add(&self.c2.mul(a)),
        )
    }
    pub fn mul_by_02(&self, a: &Fq2, c: &Fq2) -> Self {
        // (c0 + c1*w + c2*w^2) * (a + c*w^2), w^3=rho.
        let rho = Self::rho();
        Self::new(
            self.c0.mul(a).add(&rho.mul(&self.c1.mul(c))),
            self.c1.mul(a).add(&rho.mul(&self.c2.mul(c))),
            self.c0.mul(c).add(&self.c2.mul(a)),
        )
    }
    pub fn pow(&self, exp: &BigUint) -> Self {
        let mut base = self.clone();
        let mut e = exp.clone();
        let mut acc = Self::one();
        while e > BigUint::zero() {
            if (&e & BigUint::one()) == BigUint::one() { acc = acc.mul(&base); }
            base = base.square();
            e >>= 1usize;
        }
        acc
    }
    pub fn inverse(&self) -> Option<Self> {
        if self.is_zero() { return None; }
        // Algorithm for cubic extension with w^3=rho.
        let rho = Self::rho();
        let c0 = self.c0.square().sub(&rho.mul(&self.c1.mul(&self.c2)));
        let c1 = rho.mul(&self.c2.square()).sub(&self.c0.mul(&self.c1));
        let c2 = self.c1.square().sub(&self.c0.mul(&self.c2));
        let denom = self
            .c0
            .mul(&c0)
            .add(&rho.mul(&self.c2.mul(&c1).add(&self.c1.mul(&c2))))
            .inverse()?;
        Some(Self::new(c0.mul(&denom), c1.mul(&denom), c2.mul(&denom)))
    }
}
