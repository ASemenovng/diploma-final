use crate::curve::{e_stick_a, e_stick_b, AffinePointFp, E_STICK_A, E_STICK_B};
use crate::extension_curve::AffinePointFp4;
use crate::field::{Fp, Fp2, Fp4};
use crate::params::{order_r, x_parameter};
use num_bigint::BigUint;
use num_traits::Zero;
use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, Eq, PartialEq, Serialize, Deserialize)]
pub struct AffinePointFp2Twist {
    pub x: Fp2,
    pub y: Fp2,
    pub infinity: bool,
}

pub fn twist_a() -> Fp2 {
    // Quadratic twist for xi = 1+u and untwist psi(X,Y)=(xi*X, xi*v*Y):
    // E': Y^2 = X^3 + (a/xi^2)X + b/xi^3.
    let xi_inv = fp4_nonresidue_xi().inverse().expect("xi non-zero");
    Fp2::new(e_stick_a(), Fp::zero()).mul(&xi_inv.square())
}

pub fn twist_b() -> Fp2 {
    let xi_inv = fp4_nonresidue_xi().inverse().expect("xi non-zero");
    Fp2::new(e_stick_b(), Fp::zero()).mul(&xi_inv.square().mul(&xi_inv))
}

pub fn fp4_nonresidue_xi() -> Fp2 {
    // xi = 1 + u is the first small deterministic non-square in Fp2.
    Fp2::new(Fp::one(), Fp::one())
}

pub fn twist_order() -> BigUint {
    let x = x_parameter();
    x.pow(4) - BigUint::from(2u8) * x.pow(3) + BigUint::from(2u8) * x.pow(2)
}

pub fn twist_cofactor() -> BigUint {
    twist_order() / order_r()
}

pub fn sample_g1_generator() -> Option<AffinePointFp> {
    let h1 = crate::params::cofactor_h();
    for seed in 0..10_000u64 {
        let p = AffinePointFp::find_stick_point_from(seed)?;
        let g = p.scalar_mul(&h1)?;
        if !g.is_infinity()
            && g.is_on_curve(&E_STICK_A, &E_STICK_B)
            && g.scalar_mul(&order_r())?.is_infinity()
        {
            return Some(g);
        }
    }
    None
}

impl AffinePointFp2Twist {
    pub fn infinity() -> Self {
        Self {
            x: Fp2::zero(),
            y: Fp2::zero(),
            infinity: true,
        }
    }

    pub fn is_infinity(&self) -> bool {
        self.infinity
    }

    pub fn is_on_twist_curve(&self) -> bool {
        if self.infinity {
            return true;
        }
        let lhs = self.y.square();
        let rhs = self
            .x
            .square()
            .mul(&self.x)
            .add(&twist_a().mul(&self.x))
            .add(&twist_b());
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
        let three = Fp2::new(Fp::from(3u64), Fp::zero());
        let two = Fp2::new(Fp::from(2u64), Fp::zero());
        let numerator = three.mul(&self.x.square()).add(&twist_a());
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

    fn from_slope(a: &Self, b: &Self, lambda: &Fp2) -> Self {
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
        while k > BigUint::zero() {
            if (&k & BigUint::from(1u8)) == BigUint::from(1u8) {
                acc = acc.add(&base)?;
            }
            base = base.double()?;
            k >>= 1usize;
        }
        Some(acc)
    }

    pub fn find_twist_point_from(seed: u64) -> Option<Self> {
        for i in 0..20_000u64 {
            // Deterministic Fp2 x-search. The non-zero u-coordinate avoids the embedded base-field component.
            let x = Fp2::new(Fp::from(seed + i), Fp::from(1u64 + (i % 17)));
            let rhs = x.square().mul(&x).add(&twist_a().mul(&x)).add(&twist_b());
            if let Some(y) = rhs.sqrt() {
                let p = Self {
                    x,
                    y,
                    infinity: false,
                };
                if p.is_on_twist_curve() {
                    return Some(p);
                }
            }
        }
        None
    }
}

pub fn sample_g2_generator() -> Option<AffinePointFp2Twist> {
    let h2 = twist_cofactor();
    for seed in 0..256u64 {
        let p = AffinePointFp2Twist::find_twist_point_from(seed)?;
        let g = p.scalar_mul(&h2)?;
        if !g.is_infinity() && g.is_on_twist_curve() && g.scalar_mul(&order_r())?.is_infinity() {
            return Some(g);
        }
    }
    None
}

pub fn fp4_from_fp2(c0: Fp2) -> Fp4 {
    Fp4::new(c0, Fp2::zero())
}

pub fn fp4_v_times(c1: Fp2) -> Fp4 {
    Fp4::new(Fp2::zero(), c1)
}

pub fn untwist_to_fp4(q: &AffinePointFp2Twist) -> AffinePointFp4 {
    if q.is_infinity() {
        return AffinePointFp4::infinity();
    }
    // psi(X,Y) = (xi*X, xi*v*Y), xi=1+u.
    let xi = fp4_nonresidue_xi();
    AffinePointFp4 {
        x: fp4_from_fp2(q.x.mul(&xi)),
        y: fp4_v_times(q.y.mul(&xi)),
        infinity: false,
    }
}
