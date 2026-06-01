use ark_ec::{models::short_weierstrass::SWCurveConfig, pairing::Pairing, CurveGroup, PrimeGroup};
use ark_ff::{AdditiveGroup, BigInteger, Field, PrimeField};
use ark_mnt6_753::{g1, g2, Fq, Fq3, Fq6, G1Prepared, G1Projective, G2Prepared, G2Projective, MNT6_753};
use ark_serialize::CanonicalSerialize;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FpJson { pub d2: String, pub d1: String, pub d0: String }
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Fq3Json { pub c0: FpJson, pub c1: FpJson, pub c2: FpJson }
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Fq6Json { pub c0: Fq3Json, pub c1: Fq3Json }
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct G1Json { pub x: FpJson, pub y: FpJson }
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct G2Json { pub x: Fq3Json, pub y: Fq3Json }

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ConstantsJson {
    pub modulus: FpJson,
    pub one_mont: FpJson,
    pub r2: FpJson,
    pub magic: String,
    pub p2: FpJson,
    pub p4: FpJson,
    pub p8: FpJson,
    pub exp_pm2: FpJson,
    pub exp_pm2_top_bits: u32,
    pub g1: G1Json,
    pub g2: G2Json,
    pub g1_coeff_a: FpJson,
    pub g1_coeff_b: FpJson,
    pub g2_coeff_a: Fq3Json,
    pub g2_coeff_b: Fq3Json,
    pub fq_nonresidue: FpJson,
    pub fq3_nonresidue_c1: Fq3Json,
    pub pairing_digest: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ArithmeticVectorJson {
    pub a: FpJson,
    pub b: FpJson,
    pub a_plus_b: FpJson,
    pub a_minus_b: FpJson,
    pub a_mul_b: FpJson,
    pub a_sqr: FpJson,
    pub a_inv: FpJson,
    pub a_mul_11: FpJson,
    pub x3: Fq3Json,
    pub y3: Fq3Json,
    pub x3_mul_y3: Fq3Json,
    pub x3_sqr: Fq3Json,
    pub z6: Fq6Json,
    pub w6: Fq6Json,
    pub z6_mul_w6: Fq6Json,
    pub z6_sqr: Fq6Json,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DoubleCoeffJson { pub c_h: Fq3Json, pub c_4c: Fq3Json, pub c_j: Fq3Json, pub c_l: Fq3Json }
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MillerStepJson { pub q_x_over_twist: Fq3Json, pub q_y_over_twist: Fq3Json, pub double0: DoubleCoeffJson, pub after_double0: Fq6Json }
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ResidueJson { pub c: Fq6Json, pub c_inv: Fq6Json, pub c_pow_r: Fq6Json }
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PreparedJson {
    pub double_count: usize,
    pub add_count: usize,
    pub dbl_blob: String,
    pub add_blob: String,
    pub full_miller: Fq6Json,
    pub full_miller_blob: String,
    pub final_exp: Fq6Json,
    pub final_exp_blob: String,
}
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EquationJson {
    pub p: G1Json,
    pub r: G1Json,
    pub q: G2Json,
    pub s: G2Json,
    pub q_x_over_twist: Fq3Json,
    pub q_y_over_twist: Fq3Json,
    pub s_x_over_twist: Fq3Json,
    pub s_y_over_twist: Fq3Json,
    pub q_dbl_blob: String,
    pub q_add_blob: String,
    pub s_dbl_blob: String,
    pub s_add_blob: String,
    pub miller_product: Fq6Json,
    pub final_exp_is_one: bool,
}
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FixtureJson {
    pub constants: ConstantsJson,
    pub arithmetic: ArithmeticVectorJson,
    pub miller_step: MillerStepJson,
    pub residue: ResidueJson,
    pub prepared: PreparedJson,
    pub equation: EquationJson,
}

pub fn build_fixture() -> FixtureJson {
    let a = Fq::from(123456789u64);
    let b = Fq::from(987654321u64);
    let x3 = Fq3::new(Fq::from(3u64), Fq::from(5u64), Fq::from(7u64));
    let y3 = Fq3::new(Fq::from(11u64), Fq::from(13u64), Fq::from(17u64));
    let z6 = Fq6::new(x3, y3);
    let w6 = Fq6::new(
        Fq3::new(Fq::from(19u64), Fq::from(23u64), Fq::from(29u64)),
        Fq3::new(Fq::from(31u64), Fq::from(37u64), Fq::from(41u64)),
    );
    let g1 = G1Projective::generator().into_affine();
    let g2 = G2Projective::generator().into_affine();
    let pairing = MNT6_753::pairing(g1, g2);
    let mut pairing_bytes = Vec::new();
    pairing.serialize_compressed(&mut pairing_bytes).unwrap();

    let p_prep = G1Prepared::from(g1);
    let q_prep = G2Prepared::from(g2);
    let dc0 = &q_prep.double_coefficients[0];
    let g0 = dc0.c_l - dc0.c_4c - (dc0.c_j * p_prep.x_twist);
    let g1_line = dc0.c_h * p_prep.y_twist;

    let residue_c = z6;
    let residue_c_inv = residue_c.inverse().unwrap();
    let residue_c_pow_r = residue_c.pow(ark_mnt6_753::Fr::MODULUS);
    let full_miller = MNT6_753::multi_miller_loop([g1], [g2]).0;
    let final_exp = MNT6_753::final_exponentiation(ark_ec::pairing::MillerLoopOutput::<MNT6_753>(full_miller)).unwrap().0;
    let dbl_blob = pack_doubles(&q_prep.double_coefficients);
    let add_blob = pack_adds(&q_prep.addition_coefficients);
    let full_miller_blob = pack_fq6(&full_miller);
    let final_exp_blob = pack_fq6(&final_exp);
    let equation_p = (G1Projective::generator() + G1Projective::generator()).into_affine();
    let equation_r = G1Projective::generator().into_affine();
    let equation_q = G2Projective::generator().into_affine();
    let equation_s = (G2Projective::generator() + G2Projective::generator()).into_affine();
    let equation_q_prep = G2Prepared::from(equation_q);
    let equation_s_prep = G2Prepared::from(equation_s);
    let equation_miller = MNT6_753::multi_miller_loop([equation_p, -equation_r], [equation_q, equation_s]).0;
    let equation_final =
        MNT6_753::final_exponentiation(ark_ec::pairing::MillerLoopOutput::<MNT6_753>(equation_miller)).unwrap().0;

    FixtureJson {
        constants: ConstantsJson {
            modulus: fp_from_biguint(&modulus_biguint::<Fq>()),
            one_mont: fp_from_biguint(&((one() << 768usize) % modulus_biguint::<Fq>())),
            r2: fp_from_biguint(&((one() << 1536usize) % modulus_biguint::<Fq>())),
            magic: format!("0x{:064x}", mont_magic()),
            p2: fp_from_biguint(&(modulus_biguint::<Fq>() * 2u32)),
            p4: fp_from_biguint(&(modulus_biguint::<Fq>() * 4u32)),
            p8: fp_from_biguint(&(modulus_biguint::<Fq>() * 8u32)),
            exp_pm2: fp_from_biguint(&(modulus_biguint::<Fq>() - 2u32)),
            exp_pm2_top_bits: (modulus_biguint::<Fq>() - 2u32).bits() as u32 - 512,
            g1: G1Json { x: fp_json(&g1.x), y: fp_json(&g1.y) },
            g2: G2Json { x: fq3_json(&g2.x), y: fq3_json(&g2.y) },
            g1_coeff_a: fp_json(&<g1::Config as SWCurveConfig>::COEFF_A),
            g1_coeff_b: fp_json(&<g1::Config as SWCurveConfig>::COEFF_B),
            g2_coeff_a: fq3_json(&<g2::Config as SWCurveConfig>::COEFF_A),
            g2_coeff_b: fq3_json(&<g2::Config as SWCurveConfig>::COEFF_B),
            fq_nonresidue: fp_json(&Fq::from(11u64)),
            fq3_nonresidue_c1: fq3_json(&Fq3::new(Fq::ZERO, Fq::ONE, Fq::ZERO)),
            pairing_digest: format!("0x{}", hex::encode(pairing_bytes)),
        },
        arithmetic: ArithmeticVectorJson {
            a: fp_json(&a),
            b: fp_json(&b),
            a_plus_b: fp_json(&(a + b)),
            a_minus_b: fp_json(&(a - b)),
            a_mul_b: fp_json(&(a * b)),
            a_sqr: fp_json(&(a.square())),
            a_inv: fp_json(&a.inverse().unwrap()),
            a_mul_11: fp_json(&(a * Fq::from(11u64))),
            x3: fq3_json(&x3),
            y3: fq3_json(&y3),
            x3_mul_y3: fq3_json(&(x3 * y3)),
            x3_sqr: fq3_json(&(x3.square())),
            z6: fq6_json(&z6),
            w6: fq6_json(&w6),
            z6_mul_w6: fq6_json(&(z6 * w6)),
            z6_sqr: fq6_json(&(z6.square())),
        },
        miller_step: MillerStepJson {
            q_x_over_twist: fq3_json(&q_prep.x_over_twist),
            q_y_over_twist: fq3_json(&q_prep.y_over_twist),
            double0: DoubleCoeffJson { c_h: fq3_json(&dc0.c_h), c_4c: fq3_json(&dc0.c_4c), c_j: fq3_json(&dc0.c_j), c_l: fq3_json(&dc0.c_l) },
            after_double0: fq6_json(&Fq6::new(g0, g1_line)),
        },
        residue: ResidueJson { c: fq6_json(&residue_c), c_inv: fq6_json(&residue_c_inv), c_pow_r: fq6_json(&residue_c_pow_r) },
        prepared: PreparedJson {
            double_count: q_prep.double_coefficients.len(),
            add_count: q_prep.addition_coefficients.len(),
            dbl_blob,
            add_blob,
            full_miller: fq6_json(&full_miller),
            full_miller_blob,
            final_exp: fq6_json(&final_exp),
            final_exp_blob,
        },
        equation: EquationJson {
            p: G1Json { x: fp_json(&equation_p.x), y: fp_json(&equation_p.y) },
            r: G1Json { x: fp_json(&equation_r.x), y: fp_json(&equation_r.y) },
            q: G2Json { x: fq3_json(&equation_q.x), y: fq3_json(&equation_q.y) },
            s: G2Json { x: fq3_json(&equation_s.x), y: fq3_json(&equation_s.y) },
            q_x_over_twist: fq3_json(&equation_q_prep.x_over_twist),
            q_y_over_twist: fq3_json(&equation_q_prep.y_over_twist),
            s_x_over_twist: fq3_json(&equation_s_prep.x_over_twist),
            s_y_over_twist: fq3_json(&equation_s_prep.y_over_twist),
            q_dbl_blob: pack_doubles(&equation_q_prep.double_coefficients),
            q_add_blob: pack_adds(&equation_q_prep.addition_coefficients),
            s_dbl_blob: pack_doubles(&equation_s_prep.double_coefficients),
            s_add_blob: pack_adds(&equation_s_prep.addition_coefficients),
            miller_product: fq6_json(&equation_miller),
            final_exp_is_one: equation_final == Fq6::ONE,
        },
    }
}

fn fp_json(x: &Fq) -> FpJson {
    let p = modulus_biguint::<Fq>();
    let r = one() << 768usize;
    fp_from_biguint(&((biguint_from_field(x) * r) % p))
}
fn fq3_json(x: &Fq3) -> Fq3Json { Fq3Json { c0: fp_json(&x.c0), c1: fp_json(&x.c1), c2: fp_json(&x.c2) } }
fn fq6_json(x: &Fq6) -> Fq6Json { Fq6Json { c0: fq3_json(&x.c0), c1: fq3_json(&x.c1) } }

fn fp_from_biguint(x: &num_bigint::BigUint) -> FpJson {
    let mask = (one() << 256usize) - 1u32;
    let d0 = x & &mask;
    let d1 = (x >> 256usize) & &mask;
    let d2 = (x >> 512usize) & &mask;
    FpJson { d2: hex_word(&d2), d1: hex_word(&d1), d0: hex_word(&d0) }
}
fn hex_word(x: &num_bigint::BigUint) -> String { format!("0x{:064x}", x) }
fn one() -> num_bigint::BigUint { num_bigint::BigUint::from(1u32) }
fn modulus_biguint<F: PrimeField>() -> num_bigint::BigUint { num_bigint::BigUint::from_bytes_le(&F::MODULUS.to_bytes_le()) }
fn biguint_from_field<F: PrimeField>(x: &F) -> num_bigint::BigUint { num_bigint::BigUint::from_bytes_le(&x.into_bigint().to_bytes_le()) }
fn mont_magic() -> num_bigint::BigUint {
    let p = modulus_biguint::<Fq>();
    let m = one() << 256usize;
    let inv = modinv(&p, &m);
    (&m - inv) % &m
}
fn modinv(a: &num_bigint::BigUint, m: &num_bigint::BigUint) -> num_bigint::BigUint {
    use num_bigint::{BigInt, ToBigInt};
    use num_traits::{One, Zero};
    let mut t = BigInt::zero();
    let mut new_t = BigInt::one();
    let mut r = m.to_bigint().unwrap();
    let mut new_r = a.to_bigint().unwrap();
    while !new_r.is_zero() {
        let q = &r / &new_r;
        let tmp_t = t - &q * &new_t;
        t = new_t;
        new_t = tmp_t;
        let tmp_r = r - q * &new_r;
        r = new_r;
        new_r = tmp_r;
    }
    if t < BigInt::zero() { t += m.to_bigint().unwrap(); }
    t.to_biguint().unwrap()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn article640_equation_fixture_is_nontrivial_and_satisfies_relation() {
        let fixture = build_fixture();
        assert!(fixture.equation.final_exp_is_one);
        assert_ne!(fixture.equation.p.x.d0, fixture.equation.r.x.d0);
        assert_ne!(fixture.equation.q.x.c0.d0, fixture.equation.s.x.c0.d0);
    }
}


fn pack_doubles(v: &[ark_ec::models::mnt6::g2::AteDoubleCoefficients<ark_mnt6_753::Config>]) -> String {
    let mut out = String::from("0x");
    for c in v {
        push_fq3_hex(&mut out, &c.c_h);
        push_fq3_hex(&mut out, &c.c_4c);
        push_fq3_hex(&mut out, &c.c_j);
        push_fq3_hex(&mut out, &c.c_l);
    }
    out
}

fn pack_adds(v: &[ark_ec::models::mnt6::g2::AteAdditionCoefficients<ark_mnt6_753::Config>]) -> String {
    let mut out = String::from("0x");
    for c in v {
        push_fq3_hex(&mut out, &c.c_l1);
        push_fq3_hex(&mut out, &c.c_rz);
    }
    out
}

fn pack_fq6(x: &Fq6) -> String {
    let mut out = String::from("0x");
    push_fq3_hex(&mut out, &x.c0);
    push_fq3_hex(&mut out, &x.c1);
    out
}

fn push_fq3_hex(out: &mut String, x: &Fq3) {
    push_fp_hex(out, &x.c0);
    push_fp_hex(out, &x.c1);
    push_fp_hex(out, &x.c2);
}

fn push_fp_hex(out: &mut String, x: &Fq) {
    let j = fp_json(x);
    out.push_str(j.d2.trim_start_matches("0x"));
    out.push_str(j.d1.trim_start_matches("0x"));
    out.push_str(j.d0.trim_start_matches("0x"));
}
