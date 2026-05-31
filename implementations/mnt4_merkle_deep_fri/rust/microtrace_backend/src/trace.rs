use crate::{config, polynomial::biguint_to_u64_words, schedule::MicroOp};
use ark_ec::{CurveGroup, PrimeGroup};
use ark_ff::{Field, One, Zero};
use ark_mnt4_753::{Fq, Fq2, Fq4, Fr, G1Affine, G1Projective, G2Affine, G2Projective};
use num_bigint::{BigInt, BigUint, Sign};

#[derive(Debug, Clone)]
pub struct Fixture {
    pub p: G1Affine,
    pub r: G1Affine,
    pub q: G2Affine,
    pub s: G2Affine,
}

impl Fixture {
    pub fn sanity() -> Self {
        let p = G1Projective::generator().into_affine();
        let q = G2Projective::generator().into_affine();
        Self { p, r: p, q, s: q }
    }

    pub fn non_degenerate() -> Self {
        let p = G1Projective::generator().into_affine();
        let r = (G1Projective::generator() * Fr::from(2u64)).into_affine();
        let q = G2Projective::generator().into_affine();
        let half = Fr::from(2u64).inverse().expect("2 is invertible in Fr");
        let s = (G2Projective::generator() * half).into_affine();
        Self { p, r, q, s }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct NormalizedLine {
    pub k0: Fq2,
    pub k1: Fq2,
    pub k2: Fq2,
    pub addition: bool,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct FixedRow {
    pub op: MicroOp,
    pub line: Option<NormalizedLine>,
}

impl FixedRow {
    pub fn columns(&self) -> [Fq; config::FIXED_COLUMNS] {
        let mut out = [Fq::zero(); config::FIXED_COLUMNS];
        if let Some(selector_index) = match self.op {
            MicroOp::Sqr => Some(0),
            MicroOp::DblP => Some(1),
            MicroOp::DblR => Some(2),
            MicroOp::AddP => Some(3),
            MicroOp::AddR => Some(4),
            MicroOp::MulC => Some(5),
            MicroOp::MulCInv => Some(6),
            MicroOp::MulFrobCInv => Some(7),
            MicroOp::Hold => Some(8),
            MicroOp::Stop => None,
        } {
            out[selector_index] = Fq::one();
        }
        if let Some(line) = self.line {
            out[11] = line.k0.c0;
            out[12] = line.k0.c1;
            out[13] = line.k1.c0;
            out[14] = line.k1.c1;
            out[15] = line.k2.c0;
            out[16] = line.k2.c1;
        }
        out
    }
}

#[derive(Debug, Clone)]
pub struct FixedTable {
    pub q: G2Affine,
    pub s: G2Affine,
    pub rows: Vec<FixedRow>,
}

#[derive(Debug, Clone)]
pub struct TraceWitness {
    pub c: Fq4,
    pub c_inv: Fq4,
    pub states: Vec<Fq4>,
}

#[derive(Debug, Clone)]
struct G2ProjectiveExt {
    x: Fq2,
    y: Fq2,
    z: Fq2,
    t: Fq2,
}

#[derive(Debug, Clone)]
struct DblCoeff {
    c_h: Fq2,
    c_4c: Fq2,
    c_j: Fq2,
    c_l: Fq2,
}

#[derive(Debug, Clone)]
struct AddCoeff {
    c_l1: Fq2,
    c_rz: Fq2,
}

pub fn build_fixed_table(q: G2Affine, s: G2Affine) -> FixedTable {
    let mut rows = Vec::with_capacity(config::TRACE_SIZE);
    let mut tq = projective_ext(q);
    let mut ts = projective_ext(s);
    let q_xot = q.x * twist_inv();
    let q_yot = q.y * twist_inv();
    let s_xot = s.x * twist_inv();
    let s_yot = s.y * twist_inv();
    for digit in crate::schedule::ate_loop_digits().into_iter().skip(1) {
        rows.push(row(MicroOp::Sqr, None));
        let (next_q, coeff_q) = hot_double(tq);
        tq = next_q;
        rows.push(row(MicroOp::DblP, Some(normalize_double(coeff_q))));
        let (next_s, coeff_s) = hot_double(ts);
        ts = next_s;
        rows.push(row(MicroOp::DblR, Some(normalize_double(coeff_s))));
        if digit != 0 {
            let qy = if digit == 1 { q.y } else { -q.y };
            let qyot = if digit == 1 { q_yot } else { -q_yot };
            let (next_q, coeff_q) = hot_add(q.x, qy, tq);
            tq = next_q;
            rows.push(row(MicroOp::AddP, Some(normalize_add(coeff_q, q_xot, qyot))));
            let sy = if digit == 1 { s.y } else { -s.y };
            let syot = if digit == 1 { s_yot } else { -s_yot };
            let (next_s, coeff_s) = hot_add(s.x, sy, ts);
            ts = next_s;
            rows.push(row(MicroOp::AddR, Some(normalize_add(coeff_s, s_xot, syot))));
            rows.push(row(if digit == 1 { MicroOp::MulCInv } else { MicroOp::MulC }, None));
        }
    }
    let (_, coeff_q) = hot_neg_tail(tq);
    rows.push(row(MicroOp::AddP, Some(normalize_add(coeff_q, q_xot, q_yot))));
    let (_, coeff_s) = hot_neg_tail(ts);
    rows.push(row(MicroOp::AddR, Some(normalize_add(coeff_s, s_xot, s_yot))));
    rows.push(row(MicroOp::MulFrobCInv, None));
    assert_eq!(rows.len(), config::REAL_OPERATIONS);
    rows.resize(config::TRACE_SIZE - 1, row(MicroOp::Hold, None));
    rows.push(row(MicroOp::Stop, None));
    FixedTable { q, s, rows }
}

pub fn build_trace(fixture: &Fixture, table: &FixedTable) -> TraceWitness {
    let miller = combined_miller_without_residue(fixture, table);
    let c = residue_witness(miller);
    let c_inv = c.inverse().expect("residue witness is non-zero");
    let mut current = c_inv;
    let mut states = Vec::with_capacity(config::TRACE_SIZE);
    states.push(current);
    for fixed in table.rows.iter().take(config::TRACE_SIZE - 1) {
        current = apply_operation(current, fixed, fixture, c, c_inv);
        states.push(current);
    }
    assert_eq!(states.len(), config::TRACE_SIZE);
    assert_eq!(states[config::REAL_OPERATIONS], Fq4::one(), "residue relation must close");
    assert_eq!(states.last().copied(), Some(Fq4::one()), "HOLD padding must preserve one");
    TraceWitness { c, c_inv, states }
}

pub fn apply_operation(current: Fq4, fixed: &FixedRow, fixture: &Fixture, c: Fq4, c_inv: Fq4) -> Fq4 {
    match fixed.op {
        MicroOp::Sqr => current.square(),
        MicroOp::DblP | MicroOp::AddP => current * evaluate_line(fixed.line.unwrap(), fixture.p.x, fixture.p.y),
        MicroOp::DblR | MicroOp::AddR => current * evaluate_line(fixed.line.unwrap(), fixture.r.x, -fixture.r.y),
        MicroOp::MulC => current * c,
        MicroOp::MulCInv => current * c_inv,
        MicroOp::MulFrobCInv => {
            let mut frob = c_inv;
            frob.frobenius_map_in_place(1);
            current * frob
        }
        MicroOp::Hold => current,
        MicroOp::Stop => current,
    }
}

pub fn evaluate_line(line: NormalizedLine, x: Fq, y: Fq) -> Fq4 {
    if line.addition {
        Fq4::new(mul_fq2_by_fp(line.k0, y), line.k1 + mul_fq2_by_fp(line.k2, x))
    } else {
        Fq4::new(line.k0 + mul_fq2_by_fp(line.k1, x), mul_fq2_by_fp(line.k2, y))
    }
}

pub fn flatten(value: Fq4) -> [Fq; 4] {
    [value.c0.c0, value.c0.c1, value.c1.c0, value.c1.c1]
}

pub fn unflatten(value: [Fq; 4]) -> Fq4 {
    Fq4::new(Fq2::new(value[0], value[1]), Fq2::new(value[2], value[3]))
}

fn combined_miller_without_residue(fixture: &Fixture, table: &FixedTable) -> Fq4 {
    let mut current = Fq4::one();
    for fixed in table.rows.iter().take(config::REAL_OPERATIONS) {
        current = match fixed.op {
            MicroOp::MulC | MicroOp::MulCInv | MicroOp::MulFrobCInv => current,
            _ => apply_operation(current, fixed, fixture, Fq4::one(), Fq4::one()),
        };
    }
    current
}

fn residue_witness(miller: Fq4) -> Fq4 {
    let q = crate::config::fq_modulus_biguint();
    let r = crate::config::scalar_modulus_biguint();
    let h = ((&q * &q * &q * &q) - BigUint::from(1u8)) / &r;
    let r_inv = mod_inverse(&r, &h);
    miller.pow(biguint_to_u64_words(&r_inv))
}

fn mod_inverse(value: &BigUint, modulus: &BigUint) -> BigUint {
    let mut old_r = BigInt::from_biguint(Sign::Plus, modulus.clone());
    let mut r = BigInt::from_biguint(Sign::Plus, value % modulus);
    let mut old_s = BigInt::zero();
    let mut s = BigInt::one();
    while !r.is_zero() {
        let quotient = &old_r / &r;
        (old_r, r) = (r.clone(), &old_r - &quotient * &r);
        (old_s, s) = (s.clone(), &old_s - quotient * s);
    }
    assert_eq!(old_r, BigInt::one());
    if old_s.sign() == Sign::Minus {
        old_s += BigInt::from_biguint(Sign::Plus, modulus.clone());
    }
    old_s.to_biguint().unwrap()
}

fn row(op: MicroOp, line: Option<NormalizedLine>) -> FixedRow {
    FixedRow { op, line }
}

fn projective_ext(point: G2Affine) -> G2ProjectiveExt {
    G2ProjectiveExt { x: point.x, y: point.y, z: Fq2::one(), t: Fq2::one() }
}

fn hot_double(r: G2ProjectiveExt) -> (G2ProjectiveExt, DblCoeff) {
    let a = r.t.square();
    let b = r.x.square();
    let c = r.y.square();
    let d = c.square();
    let e = (r.x + c).square() - b - d;
    let f = b + b + b + twist_a() * a;
    let g = f.square();
    let d2 = d + d;
    let d4 = d2 + d2;
    let d8 = d4 + d4;
    let e2 = e + e;
    let e4 = e2 + e2;
    let x = g - e4;
    let y = f * (e + e - x) - d8;
    let z = (r.y + r.z).square() - c - r.z.square();
    let t = z.square();
    let c_h = (z + r.t).square() - t - a;
    let c2 = c + c;
    let c_4c = c2 + c2;
    let c_j = (f + r.t).square() - g - a;
    let c_l = (f + r.x).square() - g - b;
    (G2ProjectiveExt { x, y, z, t }, DblCoeff { c_h, c_4c, c_j, c_l })
}

fn hot_add(x: Fq2, y: Fq2, r: G2ProjectiveExt) -> (G2ProjectiveExt, AddCoeff) {
    let a = y.square();
    let b = r.t * x;
    let d = ((r.z + y).square() - a - r.t) * r.t;
    let h = b - r.x;
    let i = h.square();
    let i2 = i + i;
    let e = i2 + i2;
    let j = h * e;
    let v = r.x * e;
    let y2 = r.y + r.y;
    let l1 = d - y2;
    let x3 = l1.square() - j - (v + v);
    let y3 = l1 * (v - x3) - j * y2;
    let z3 = (r.z + h).square() - r.t - i;
    let t3 = z3.square();
    (G2ProjectiveExt { x: x3, y: y3, z: z3, t: t3 }, AddCoeff { c_l1: l1, c_rz: z3 })
}

fn hot_neg_tail(r: G2ProjectiveExt) -> (G2ProjectiveExt, AddCoeff) {
    let rz_inv = r.z.inverse().expect("non-zero z");
    let rz2_inv = rz_inv.square();
    let rz3_inv = rz_inv * rz2_inv;
    hot_add(r.x * rz2_inv, -(r.y * rz3_inv), r)
}

fn normalize_double(coeff: DblCoeff) -> NormalizedLine {
    NormalizedLine {
        k0: coeff.c_l - coeff.c_4c,
        k1: -mul_fq2_by_u(coeff.c_j),
        k2: mul_fq2_by_u(coeff.c_h),
        addition: false,
    }
}

fn normalize_add(coeff: AddCoeff, x_over_twist: Fq2, y_over_twist: Fq2) -> NormalizedLine {
    NormalizedLine {
        k0: mul_fq2_by_u(coeff.c_rz),
        k1: -(y_over_twist * coeff.c_rz - x_over_twist * coeff.c_l1),
        k2: -coeff.c_l1,
        addition: true,
    }
}

fn mul_fq2_by_u(value: Fq2) -> Fq2 {
    Fq2::new(Fq::from(13u64) * value.c1, value.c0)
}

fn mul_fq2_by_fp(value: Fq2, scalar: Fq) -> Fq2 {
    Fq2::new(value.c0 * scalar, value.c1 * scalar)
}

fn twist_a() -> Fq2 {
    Fq2::new(Fq::from(26u64), Fq::zero())
}

fn twist_inv() -> Fq2 {
    Fq2::new(Fq::zero(), Fq::from(13u64).inverse().unwrap())
}
