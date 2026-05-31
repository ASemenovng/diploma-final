use ark_ec::{pairing::Pairing, CurveGroup, PrimeGroup};
use ark_ff::{BigInteger, Field, PrimeField, Zero};
use ark_mnt4_753::{Fq, Fq2, Fq4, Fr, G1Affine, G1Projective, G2Affine, G2Projective, MNT4_753};
use num_bigint::BigUint;
use num_traits::One;
use serde::{Deserialize, Serialize};
use sha3::{Digest, Keccak256};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FpJson { pub d2: String, pub d1: String, pub d0: String }
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Fq2Json { pub c0: FpJson, pub c1: FpJson }
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Fq4Json { pub c0: Fq2Json, pub c1: Fq2Json }
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct G1Json { pub x: FpJson, pub y: FpJson }
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct G2Json { pub x: Fq2Json, pub y: Fq2Json }
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PreparedLineJson { pub kind: u8, pub base: Fq2Json, pub lambda_num: Fq2Json, pub lambda_den: Fq2Json }
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct QuotientArtifact {
    pub p: G1Json,
    pub r: G1Json,
    pub q: G2Json,
    pub s: G2Json,
    pub commitment_q: String,
    pub commitment_s: String,
    pub trace_commitment: String,
    pub quotient_commitment: String,
    pub transcript_challenge: String,
    pub challenge: FpJson,
    pub vanishing_eval: FpJson,
    pub quotient_eval: FpJson,
    pub relation_eval: FpJson,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RelationArtifact {
    pub p: G1Json,
    pub r: G1Json,
    pub q: G2Json,
    pub s: G2Json,
    pub commitment_q: String,
    pub commitment_s: String,
    pub trace_commitment: String,
    pub quotient_commitment: String,
    pub residue_commitment: String,
    pub challenge: FpJson,
    pub miller_vanishing_eval: FpJson,
    pub miller_quotient_eval: FpJson,
    pub miller_relation_eval: FpJson,
    pub residue_vanishing_eval: FpJson,
    pub residue_quotient_eval: FpJson,
    pub residue_relation_eval: FpJson,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Article640DirectArtifact {
    pub p: G1Json,
    pub r: G1Json,
    pub q: G2Json,
    pub s: G2Json,
    pub commitment_q: String,
    pub commitment_s: String,
    pub residue_c: Fq4Json,
    pub residue_c_inv: Fq4Json,
    pub rust_residue_relation_holds: bool,
    pub line_count: usize,
    pub arkworks_equation_holds: bool,
    pub lines_q: Vec<PreparedLineJson>,
    pub lines_s: Vec<PreparedLineJson>,
}

const ATE_STEP_KINDS_HEX: &str = "00000100000100000100000001000000020000010000010000020000020000000100000000020000020000020000000100000000000100000200000100000001000000000000000000020000020000000001000000020000000200000002000001000002000000000200000100000000020000000200000100000200000000020000000200000100000002000002000001000001000000000000000000000200000001000001000000010000020000000000010000010000010000020000020000000100000001000002000001000002000000000002000000000100000100000002000000020000010000020000000000000000000001000000020000010000020000010000000002000000020000000200000000010000010000000100000100000100000100000001000000000100000000020000000001000002000000010000020000010000010000020000010000000200000200000200000000000001000002000001000000000100000100000200000000010000010000000200000001000002000002000000000100000000000100000100000001000002000002000000000001000000000200000100000100000000020000000200000000010000010000020000000000000100000000000100000002000000020000010000000001000002000000000000000000000000000000";
const ATE_LOOP_ENC_HEX: &str = "0201020102010201010201010001020102010001000101020101010001000100010102010101010201000102010102010101010101010100010001010102010100010100010100010201000101010001020101010001010001020100010101000101000102010100010001020102010101010101010101000101020102010102010001010101020102010201000100010102010102010001020100010101010001010102010201010001010001020100010101010101010101020101000102010001020101010001010001010001010102010201010201020102010201010201010102010101000101010201000101020100010201020100010201010001000100010101010102010001020101010201020100010101020102010100010102010001000101010201010101020102010102010001000101010102010101000102010201010100010100010101020102010001010101010201010101020101000101000102010101020100010101010101010101010101010101";

#[derive(Debug, Clone)]
struct G2ProjectiveExt { x: Fq2, y: Fq2, z: Fq2, t: Fq2 }
#[derive(Debug, Clone)]
struct DblCoeff { c_h: Fq2, c_4c: Fq2, c_j: Fq2, c_l: Fq2 }
#[derive(Debug, Clone)]
struct AddCoeff { c_l1: Fq2, c_rz: Fq2 }

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Article640HotArtifact {
    pub p: G1Json,
    pub r: G1Json,
    pub q: G2Json,
    pub s: G2Json,
    pub commitment_q: String,
    pub commitment_s: String,
    pub residue_c: Fq4Json,
    pub residue_c_inv: Fq4Json,
    pub hot_miller_digest: String,
    pub rust_residue_relation_holds: bool,
}

#[derive(Debug, Clone)]
struct PreparedLineInternal { kind: u8, base: Fq2, lambda_num: Fq2, lambda_den: Fq2 }

pub fn build_artifact() -> Article640DirectArtifact {
    let p = G1Projective::generator().into_affine();
    // Non-degenerate bilinear fixture: e(P, Q) = e(2P, Q/2).
    let r = (G1Projective::generator() * Fr::from(2u64)).into_affine();
    let q = G2Projective::generator().into_affine();
    let half = Fr::from(2u64).inverse().expect("2 is invertible in Fr");
    let s = (G2Projective::generator() * half).into_affine();
    let lines_q = prepare_lines(q);
    let lines_s = prepare_lines(s);
    let commitment_q = commitment(&g2_json(&q), &lines_q);
    let commitment_s = commitment(&g2_json(&s), &lines_s);
    let lhs = MNT4_753::pairing(p, q).0;
    let rhs = MNT4_753::pairing(r, s).0;
    let miller = combined_miller_from_prepared_lines(p, r, &lines_q, &lines_s);
    let c = residue_witness_for_miller_output(miller);
    let c_inv = c.inverse().expect("residue witness is non-zero");
    let rust_residue_relation_holds = c.pow(residue_scalar_r_le_words()) == miller;
    Article640DirectArtifact {
        p: g1_json(&p),
        r: g1_json(&r),
        q: g2_json(&q),
        s: g2_json(&s),
        commitment_q: format!("0x{}", hex::encode(commitment_q)),
        commitment_s: format!("0x{}", hex::encode(commitment_s)),
        residue_c: fq4_json(&c),
        residue_c_inv: fq4_json(&c_inv),
        rust_residue_relation_holds,
        line_count: lines_q.len(),
        arkworks_equation_holds: lhs == rhs,
        lines_q: lines_q.iter().map(line_json).collect(),
        lines_s: lines_s.iter().map(line_json).collect(),
    }
}

pub fn build_hot_artifact() -> Article640HotArtifact {
    let p = G1Projective::generator().into_affine();
    let r = (G1Projective::generator() * Fr::from(2u64)).into_affine();
    let q = G2Projective::generator().into_affine();
    let half = Fr::from(2u64).inverse().expect("2 is invertible in Fr");
    let s = (G2Projective::generator() * half).into_affine();
    let lines_q = prepare_lines(q);
    let lines_s = prepare_lines(s);
    let commitment_q = commitment(&g2_json(&q), &lines_q);
    let commitment_s = commitment(&g2_json(&s), &lines_s);
    let miller = hot_combined_miller(p, r, q, s);
    let c = hot_residue_witness_for_miller_output(miller);
    let c_inv = c.inverse().expect("residue witness is non-zero");
    let hot_e = hot_residue_exponent_mod_h();
    Article640HotArtifact {
        p: g1_json(&p),
        r: g1_json(&r),
        q: g2_json(&q),
        s: g2_json(&s),
        commitment_q: format!("0x{}", hex::encode(commitment_q)),
        commitment_s: format!("0x{}", hex::encode(commitment_s)),
        residue_c: fq4_json(&c),
        residue_c_inv: fq4_json(&c_inv),
        hot_miller_digest: digest_fq4(&miller),
        rust_residue_relation_holds: miller * c.pow(biguint_to_le_u64_words(&hot_e)) == Fq4::one(),
    }
}

pub fn build_quotient_artifact(base: &Article640DirectArtifact) -> QuotientArtifact {
    let trace_commitment: [u8; 32] = Keccak256::digest(b"article640-mnt4-demo-trace").into();
    let quotient_commitment: [u8; 32] = Keccak256::digest(b"article640-mnt4-demo-quotient").into();
    let challenge = fp_json(&Fq::from(5u64));
    let vanishing_eval = fp_json(&Fq::from(7u64));
    let quotient_eval = fp_json(&Fq::from(11u64));
    let relation_eval = fp_json(&Fq::from(77u64));
    let transcript_challenge = quotient_transcript_challenge(
        base,
        &trace_commitment,
        &quotient_commitment,
        &challenge,
    );
    QuotientArtifact {
        p: base.p.clone(),
        r: base.r.clone(),
        q: base.q.clone(),
        s: base.s.clone(),
        commitment_q: base.commitment_q.clone(),
        commitment_s: base.commitment_s.clone(),
        trace_commitment: format!("0x{}", hex::encode(trace_commitment)),
        quotient_commitment: format!("0x{}", hex::encode(quotient_commitment)),
        transcript_challenge: format!("0x{}", hex::encode(transcript_challenge)),
        challenge,
        vanishing_eval,
        quotient_eval,
        relation_eval,
    }
}

pub fn build_relation_artifact(base: &Article640DirectArtifact) -> RelationArtifact {
    let trace_commitment: [u8; 32] = Keccak256::digest(b"article640-mnt4-demo-trace").into();
    let quotient_commitment: [u8; 32] = Keccak256::digest(b"article640-mnt4-demo-quotient").into();
    let residue_commitment: [u8; 32] = Keccak256::digest(b"article640-mnt4-demo-residue").into();
    let challenge = relation_challenge(base, &trace_commitment, &quotient_commitment, &residue_commitment);
    let miller_vanishing_eval = fp_json(&Fq::from(7u64));
    let miller_quotient_eval = fp_json(&Fq::from(11u64));
    let miller_relation_eval = fp_json(&Fq::from(77u64));
    let residue_vanishing_eval = fp_json(&Fq::from(13u64));
    let residue_quotient_eval = fp_json(&Fq::from(17u64));
    let residue_relation_eval = fp_json(&Fq::from(221u64));
    RelationArtifact {
        p: base.p.clone(),
        r: base.r.clone(),
        q: base.q.clone(),
        s: base.s.clone(),
        commitment_q: base.commitment_q.clone(),
        commitment_s: base.commitment_s.clone(),
        trace_commitment: format!("0x{}", hex::encode(trace_commitment)),
        quotient_commitment: format!("0x{}", hex::encode(quotient_commitment)),
        residue_commitment: format!("0x{}", hex::encode(residue_commitment)),
        challenge,
        miller_vanishing_eval,
        miller_quotient_eval,
        miller_relation_eval,
        residue_vanishing_eval,
        residue_quotient_eval,
        residue_relation_eval,
    }
}

pub fn write_relation_words_fixture(artifact: &RelationArtifact) -> String {
    let mut words = Vec::<String>::new();
    push_g1(&mut words, &artifact.p);
    push_g1(&mut words, &artifact.r);
    push_g2(&mut words, &artifact.q);
    push_g2(&mut words, &artifact.s);
    words.push(artifact.commitment_q.clone());
    words.push(artifact.commitment_s.clone());
    words.push(artifact.trace_commitment.clone());
    words.push(artifact.quotient_commitment.clone());
    words.push(artifact.residue_commitment.clone());
    push_fp(&mut words, &artifact.challenge);
    push_fp(&mut words, &artifact.miller_vanishing_eval);
    push_fp(&mut words, &artifact.miller_quotient_eval);
    push_fp(&mut words, &artifact.miller_relation_eval);
    push_fp(&mut words, &artifact.residue_vanishing_eval);
    push_fp(&mut words, &artifact.residue_quotient_eval);
    push_fp(&mut words, &artifact.residue_relation_eval);
    format!("0x{}", words.iter().map(|w| w.trim_start_matches("0x").to_string()).map(|x| format!("{:0>64}", x)).collect::<String>())
}

pub fn write_quotient_words_fixture(artifact: &QuotientArtifact) -> String {
    let mut words = Vec::<String>::new();
    push_g1(&mut words, &artifact.p);
    push_g1(&mut words, &artifact.r);
    push_g2(&mut words, &artifact.q);
    push_g2(&mut words, &artifact.s);
    words.push(artifact.commitment_q.clone());
    words.push(artifact.commitment_s.clone());
    words.push(artifact.trace_commitment.clone());
    words.push(artifact.quotient_commitment.clone());
    words.push(artifact.transcript_challenge.clone());
    push_fp(&mut words, &artifact.challenge);
    push_fp(&mut words, &artifact.vanishing_eval);
    push_fp(&mut words, &artifact.quotient_eval);
    push_fp(&mut words, &artifact.relation_eval);
    format!("0x{}", words.iter().map(|w| w.trim_start_matches("0x").to_string()).map(|x| format!("{:0>64}", x)).collect::<String>())
}

pub fn write_words_fixture(artifact: &Article640DirectArtifact) -> String {
    let mut words = Vec::<String>::new();
    push_g1(&mut words, &artifact.p);
    push_g1(&mut words, &artifact.r);
    push_g2(&mut words, &artifact.q);
    push_g2(&mut words, &artifact.s);
    words.push(artifact.commitment_q.clone());
    words.push(artifact.commitment_s.clone());
    push_fq4(&mut words, &artifact.residue_c);
    push_fq4(&mut words, &artifact.residue_c_inv);
    words.push(format!("0x{:x}", artifact.line_count));
    for l in &artifact.lines_q { push_line(&mut words, l); }
    for l in &artifact.lines_s { push_line(&mut words, l); }
    format!("0x{}", words.iter().map(|w| w.trim_start_matches("0x").to_string()).map(|x| format!("{:0>64}", x)).collect::<String>())
}

pub fn write_hot_words_fixture(artifact: &Article640HotArtifact) -> String {
    let mut words = Vec::<String>::new();
    push_g1(&mut words, &artifact.p);
    push_g1(&mut words, &artifact.r);
    push_g2(&mut words, &artifact.q);
    push_g2(&mut words, &artifact.s);
    words.push(artifact.commitment_q.clone());
    words.push(artifact.commitment_s.clone());
    push_fq4(&mut words, &artifact.residue_c);
    push_fq4(&mut words, &artifact.residue_c_inv);
    format!("0x{}", words.iter().map(|w| w.trim_start_matches("0x").to_string()).map(|x| format!("{:0>64}", x)).collect::<String>())
}


fn quotient_transcript_challenge(
    artifact: &Article640DirectArtifact,
    trace_commitment: &[u8; 32],
    quotient_commitment: &[u8; 32],
    challenge: &FpJson,
) -> [u8; 32] {
    let mut bytes = quotient_transcript_prefix(artifact, trace_commitment, quotient_commitment);
    push_fp_json_bytes(&mut bytes, challenge);
    Keccak256::digest(&bytes).into()
}

fn relation_challenge(
    artifact: &Article640DirectArtifact,
    trace_commitment: &[u8; 32],
    quotient_commitment: &[u8; 32],
    residue_commitment: &[u8; 32],
) -> FpJson {
    let mut bytes = quotient_transcript_prefix(artifact, trace_commitment, quotient_commitment);
    bytes.extend_from_slice(residue_commitment);
    let seed: [u8; 32] = Keccak256::digest(&bytes).into();
    fp_json(&Fq::from_be_bytes_mod_order(&seed))
}

fn quotient_transcript_prefix(
    artifact: &Article640DirectArtifact,
    trace_commitment: &[u8; 32],
    quotient_commitment: &[u8; 32],
) -> Vec<u8> {
    let domain: [u8; 32] = Keccak256::digest(b"MNT4_ARTICLE640_QUOTIENT_V1").into();
    let mut bytes = Vec::with_capacity(32 * 12);
    bytes.extend_from_slice(&domain);
    bytes.extend_from_slice(&hex::decode(artifact.commitment_q.trim_start_matches("0x")).unwrap());
    bytes.extend_from_slice(&hex::decode(artifact.commitment_s.trim_start_matches("0x")).unwrap());
    bytes.extend_from_slice(&hash_g1_json(&artifact.p));
    bytes.extend_from_slice(&hash_g1_json(&artifact.r));
    bytes.extend_from_slice(trace_commitment);
    bytes.extend_from_slice(quotient_commitment);
    bytes
}

fn hash_g1_json(p: &G1Json) -> [u8; 32] {
    let mut bytes = Vec::with_capacity(32 * 6);
    push_fp_json_bytes(&mut bytes, &p.x);
    push_fp_json_bytes(&mut bytes, &p.y);
    Keccak256::digest(&bytes).into()
}

fn prepare_lines(q: G2Affine) -> Vec<PreparedLineInternal> {
    let mut out = Vec::with_capacity(ate_step_kinds().len());
    let mut t = q;
    let neg_q = G2Affine::new_unchecked(q.x, -q.y);
    for kind in ate_step_kinds() {
        let t_before = t;
        let (t_after, n, d, kind_s) = match kind {
            0 => { let (ta,n,d)=double_data(t_before); (ta,n,d,0u8) }
            1 => { let (ta,n,d)=add_data(t_before, q); (ta,n,d,1u8) }
            2 => { let (ta,n,d)=add_data(t_before, neg_q); (ta,n,d,2u8) }
            _ => unreachable!(),
        };
        let base = n * t_before.x - d * t_before.y;
        out.push(PreparedLineInternal { kind: kind_s, base, lambda_num: n, lambda_den: d });
        t = t_after;
    }
    out
}

fn commitment(q: &G2Json, lines: &[PreparedLineInternal]) -> [u8; 32] {
    let mut init = Vec::with_capacity(32 * 13);
    push_g2_bytes(&mut init, q);
    init.extend_from_slice(&word_u128(lines.len() as u128));
    let mut state: [u8; 32] = Keccak256::digest(&init).into();
    for l in lines {
        let mut bytes = Vec::with_capacity(32 * 20);
        bytes.extend_from_slice(&state);
        bytes.extend_from_slice(&word_u8(l.kind));
        push_fq2_bytes(&mut bytes, &l.base);
        push_fq2_bytes(&mut bytes, &l.lambda_num);
        push_fq2_bytes(&mut bytes, &l.lambda_den);
        state = Keccak256::digest(&bytes).into();
    }
    state
}

fn double_data(t: G2Affine) -> (G2Affine, Fq2, Fq2) { let a=Fq2::new(Fq::from(26u64),Fq::from(0u64)); let n=Fq2::from(3u64)*t.x.square()+a; let d=Fq2::from(2u64)*t.y; let lambda=n*d.inverse().unwrap(); let x3=lambda.square()-t.x-t.x; let y3=lambda*(t.x-x3)-t.y; (G2Affine::new_unchecked(x3,y3),n,d) }
fn add_data(t: G2Affine, q: G2Affine) -> (G2Affine, Fq2, Fq2) { let n=q.y-t.y; let d=q.x-t.x; let lambda=n*d.inverse().unwrap(); let x3=lambda.square()-t.x-q.x; let y3=lambda*(t.x-x3)-t.y; (G2Affine::new_unchecked(x3,y3),n,d) }

fn combined_miller_from_prepared_lines(
    p: G1Affine,
    r: G1Affine,
    lines_q: &[PreparedLineInternal],
    lines_s: &[PreparedLineInternal],
) -> Fq4 {
    let mut f = Fq4::one();
    let neg_r_y = -r.y;
    for (line_q, line_s) in lines_q.iter().zip(lines_s.iter()) {
        if line_q.kind == 0 {
            f.square_in_place();
        }
        let (q_l0, q_l1) = evaluate_prepared_line_at_g1(line_q, p.x, p.y);
        let (s_l0, s_l1) = evaluate_prepared_line_at_g1(line_s, r.x, neg_r_y);
        f *= Fq4::new(q_l0, q_l1);
        f *= Fq4::new(s_l0, s_l1);
    }
    f
}

fn hot_combined_miller(p: G1Affine, r: G1Affine, q: G2Affine, s: G2Affine) -> Fq4 {
    let mut f = Fq4::one();
    let neg_r_y = -r.y;
    let mut tq = G2ProjectiveExt { x: q.x, y: q.y, z: Fq2::one(), t: Fq2::one() };
    let mut ts = G2ProjectiveExt { x: s.x, y: s.y, z: Fq2::one(), t: Fq2::one() };
    let q_neg_y = -q.y;
    let s_neg_y = -s.y;
    let q_xot = q.x * twist_inv();
    let q_yot = q.y * twist_inv();
    let q_yot_neg = -q_yot;
    let s_xot = s.x * twist_inv();
    let s_yot = s.y * twist_inv();
    let s_yot_neg = -s_yot;
    let loop_enc = ate_loop_enc();
    for bit in loop_enc.iter().skip(1).copied() {
        f.square_in_place();
        let (next_q, dc_q) = hot_double(tq.clone());
        tq = next_q;
        let (l0q, l1q) = hot_eval_double(&dc_q, p.x, p.y);
        f *= Fq4::new(l0q, l1q);
        let (next_s, dc_s) = hot_double(ts.clone());
        ts = next_s;
        let (l0s, l1s) = hot_eval_double(&dc_s, r.x, neg_r_y);
        f *= Fq4::new(l0s, l1s);
        if bit == 0 { continue; }
        let (qy, qyot) = if bit == 1 { (q.y, q_yot) } else { (q_neg_y, q_yot_neg) };
        let (next_q, ac_q) = hot_add(q.x, qy, tq.clone());
        tq = next_q;
        let (l0q, l1q) = hot_eval_add(&ac_q, p.x, p.y, q_xot, qyot);
        f *= Fq4::new(l0q, l1q);
        let (sy, syot) = if bit == 1 { (s.y, s_yot) } else { (s_neg_y, s_yot_neg) };
        let (next_s, ac_s) = hot_add(s.x, sy, ts.clone());
        ts = next_s;
        let (l0s, l1s) = hot_eval_add(&ac_s, r.x, neg_r_y, s_xot, syot);
        f *= Fq4::new(l0s, l1s);
    }
    let (_, ac_q) = hot_neg_tail(tq.clone());
    let (l0q, l1q) = hot_eval_add(&ac_q, p.x, p.y, q_xot, q_yot);
    f *= Fq4::new(l0q, l1q);
    let (_, ac_s) = hot_neg_tail(ts.clone());
    let (l0s, l1s) = hot_eval_add(&ac_s, r.x, neg_r_y, s_xot, s_yot);
    f *= Fq4::new(l0s, l1s);
    f
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
    let minus_x = r.x * rz2_inv;
    let minus_y = -(r.y * rz3_inv);
    hot_add(minus_x, minus_y, r)
}

fn hot_eval_double(c: &DblCoeff, px: Fq, py: Fq) -> (Fq2, Fq2) {
    let ell0 = c.c_l - c.c_4c - mul_fq2_by_u(mul_fq2_by_fp(c.c_j, px));
    let ell1 = mul_fq2_by_u(mul_fq2_by_fp(c.c_h, py));
    (ell0, ell1)
}

fn hot_eval_add(c: &AddCoeff, px: Fq, py: Fq, x_over_twist: Fq2, y_over_twist: Fq2) -> (Fq2, Fq2) {
    let l1_coeff = Fq2::new(px, Fq::zero()) - x_over_twist;
    let ell0 = mul_fq2_by_u(mul_fq2_by_fp(c.c_rz, py));
    let ell1 = -(y_over_twist * c.c_rz + l1_coeff * c.c_l1);
    (ell0, ell1)
}

fn twist_a() -> Fq2 { Fq2::new(Fq::from(26u64), Fq::zero()) }
fn twist_inv() -> Fq2 { Fq2::new(Fq::zero(), Fq::from(13u64).inverse().expect("13 invertible")) }
fn ate_loop_enc() -> Vec<i8> {
    let b = ATE_LOOP_ENC_HEX.as_bytes();
    (0..b.len()).step_by(2).map(|i| {
        let hi = (b[i] as char).to_digit(16).unwrap() as u8;
        let lo = (b[i + 1] as char).to_digit(16).unwrap() as u8;
        match (hi << 4) | lo {
            2 => 1,
            1 => 0,
            0 => -1,
            _ => unreachable!(),
        }
    }).collect()
}

fn evaluate_prepared_line_at_g1(line: &PreparedLineInternal, x: Fq, y: Fq) -> (Fq2, Fq2) {
    let l0 = line.base - mul_fq2_by_fp(mul_fq2_by_u(line.lambda_num), x);
    let l1 = mul_fq2_by_fp(mul_fq2_by_u(line.lambda_den), y);
    (l0, l1)
}

fn mul_fq2_by_u(a: Fq2) -> Fq2 {
    Fq2::new(Fq::from(13u64) * a.c1, a.c0)
}

fn mul_fq2_by_fp(a: Fq2, x: Fq) -> Fq2 {
    Fq2::new(a.c0 * x, a.c1 * x)
}

fn line_json(x: &PreparedLineInternal) -> PreparedLineJson { PreparedLineJson { kind: x.kind, base: fq2_json(&x.base), lambda_num: fq2_json(&x.lambda_num), lambda_den: fq2_json(&x.lambda_den) } }
fn ate_step_kinds() -> Vec<u8> { let b=ATE_STEP_KINDS_HEX.as_bytes(); (0..b.len()).step_by(2).map(|i| ((b[i] as char).to_digit(16).unwrap() as u8)<<4 | (b[i+1] as char).to_digit(16).unwrap() as u8).collect() }
fn word_u8(x: u8) -> [u8;32] { word_u128(x as u128) }
fn word_u128(x: u128) -> [u8;32] { let mut w=[0u8;32]; w[16..].copy_from_slice(&x.to_be_bytes()); w }
fn push_g2_bytes(out: &mut Vec<u8>, q: &G2Json) { push_fq2_json_bytes(out, &q.x); push_fq2_json_bytes(out, &q.y); }
fn push_fq2_json_bytes(out: &mut Vec<u8>, x: &Fq2Json) { push_fp_json_bytes(out, &x.c0); push_fp_json_bytes(out, &x.c1); }
fn push_fp_json_bytes(out: &mut Vec<u8>, x: &FpJson) { for s in [&x.d2, &x.d1, &x.d0] { out.extend_from_slice(&hex::decode(s.trim_start_matches("0x")).unwrap()); } }
fn push_fq2_bytes(out: &mut Vec<u8>, x: &Fq2) { push_fp_bytes(out,&x.c0); push_fp_bytes(out,&x.c1); }
fn push_fp_bytes(out: &mut Vec<u8>, x: &Fq) { let [d0,d1,d2]=fq_limbs_hex(&montgomery_fq(x)); for s in [d2,d1,d0] { out.extend_from_slice(&hex::decode(s.trim_start_matches("0x")).unwrap()); } }

fn g1_json(p:&G1Affine)->G1Json{G1Json{x:fp_json(&p.x),y:fp_json(&p.y)}}
fn g2_json(q:&G2Affine)->G2Json{G2Json{x:fq2_json(&q.x),y:fq2_json(&q.y)}}
fn fq2_json(x:&Fq2)->Fq2Json{Fq2Json{c0:fp_json(&x.c0),c1:fp_json(&x.c1)}}
fn fq4_json(x:&Fq4)->Fq4Json{Fq4Json{c0:fq2_json(&x.c0),c1:fq2_json(&x.c1)}}
fn digest_fq4(x: &Fq4) -> String {
    let j = fq4_json(x);
    let mut bytes = Vec::with_capacity(12 * 32);
    push_fq2_json_bytes(&mut bytes, &j.c0);
    push_fq2_json_bytes(&mut bytes, &j.c1);
    format!("0x{}", hex::encode(Keccak256::digest(&bytes)))
}
fn fp_json(x:&Fq)->FpJson{ let [d0,d1,d2]=fq_limbs_hex(&montgomery_fq(x)); FpJson{d2,d1,d0} }
fn montgomery_fq(x:&Fq)->Fq{ *x * Fq::from(2u64).pow([768u64]) }
fn fq_limbs_hex(x:&Fq)->[String;3]{ let limbs=x.into_bigint().0; [word_hex(limbs[0],limbs[1],limbs[2],limbs[3]), word_hex(limbs[4],limbs[5],limbs[6],limbs[7]), word_hex(limbs[8],limbs[9],limbs[10],limbs[11])] }
fn word_hex(a:u64,b:u64,c:u64,d:u64)->String{ let high=((d as u128)<<64)|(c as u128); let low=((b as u128)<<64)|(a as u128); format!("0x{high:032x}{low:032x}") }
fn push_g1(w:&mut Vec<String>, p:&G1Json){ push_fp(w,&p.x); push_fp(w,&p.y); }
fn push_g2(w:&mut Vec<String>, q:&G2Json){ push_fq2(w,&q.x); push_fq2(w,&q.y); }
fn push_fq4(w:&mut Vec<String>, x:&Fq4Json){ push_fq2(w,&x.c0); push_fq2(w,&x.c1); }
fn push_fq2(w:&mut Vec<String>, x:&Fq2Json){ push_fp(w,&x.c0); push_fp(w,&x.c1); }
fn push_fp(w:&mut Vec<String>, x:&FpJson){ w.extend([x.d2.clone(),x.d1.clone(),x.d0.clone()]); }
fn push_line(w:&mut Vec<String>, l:&PreparedLineJson){ w.push(format!("0x{:x}", l.kind)); push_fq2(w,&l.base); push_fq2(w,&l.lambda_num); push_fq2(w,&l.lambda_den); }

fn residue_witness_for_miller_output(f: Fq4) -> Fq4 {
    let p = biguint_from_prime::<Fq>();
    let r = biguint_from_prime::<Fr>();
    let h = ((&p * &p * &p * &p) - BigUint::one()) / &r;
    let r_inv_mod_h = mod_inverse(&r, &h);
    f.pow(biguint_to_le_u64_words(&r_inv_mod_h))
}

fn hot_residue_witness_for_miller_output(miller: Fq4) -> Fq4 {
    let h = residue_cofactor_h();
    let e = hot_residue_exponent_mod_h();
    let e_inv = mod_inverse(&e, &h);
    let exp = if e_inv == BigUint::from(0u8) { BigUint::from(0u8) } else { &h - e_inv };
    miller.pow(biguint_to_le_u64_words(&exp))
}

fn residue_cofactor_h() -> BigUint {
    let p = biguint_from_prime::<Fq>();
    let r = biguint_from_prime::<Fr>();
    ((&p * &p * &p * &p) - BigUint::one()) / &r
}

fn hot_residue_exponent_mod_h() -> BigUint {
    use num_bigint::{BigInt, Sign};
    let p = BigInt::from_biguint(Sign::Plus, biguint_from_prime::<Fq>());
    let h = BigInt::from_biguint(Sign::Plus, residue_cofactor_h());
    let mut e = -BigInt::one(); // initial c^{-1}
    for bit in ate_loop_enc().iter().skip(1).copied() {
        e *= 2;
        if bit == 1 {
            e -= 1;
        } else if bit == -1 {
            e += 1;
        }
    }
    e -= p; // final Frobenius(c^{-1}) = c^{-q}
    let mut m = e % &h;
    if m.sign() == Sign::Minus {
        m += &h;
    }
    m.to_biguint().expect("non-negative residue exponent")
}

fn residue_scalar_r_le_words() -> Vec<u64> {
    biguint_to_le_u64_words(&biguint_from_prime::<Fr>())
}

fn biguint_from_prime<F: PrimeField>() -> BigUint {
    BigUint::from_bytes_le(&F::MODULUS.to_bytes_le())
}

fn biguint_to_le_u64_words(x: &BigUint) -> Vec<u64> {
    let bytes = x.to_bytes_le();
    let mut words = Vec::with_capacity((bytes.len() + 7) / 8);
    for chunk in bytes.chunks(8) {
        let mut word = [0u8; 8];
        word[..chunk.len()].copy_from_slice(chunk);
        words.push(u64::from_le_bytes(word));
    }
    if words.is_empty() { words.push(0); }
    words
}

fn mod_inverse(a: &BigUint, modulus: &BigUint) -> BigUint {
    // Extended Euclidean algorithm with signed state represented by num_bigint::BigInt.
    use num_bigint::{BigInt, Sign};
    use num_traits::{One as _, Zero};

    let mut t = BigInt::zero();
    let mut new_t = BigInt::one();
    let mut r = BigInt::from_biguint(Sign::Plus, modulus.clone());
    let mut new_r = BigInt::from_biguint(Sign::Plus, a % modulus);

    while !new_r.is_zero() {
        let q = &r / &new_r;
        let tmp_t = &t - &q * &new_t;
        t = new_t;
        new_t = tmp_t;
        let tmp_r = &r - &q * &new_r;
        r = new_r;
        new_r = tmp_r;
    }

    assert_eq!(r, BigInt::one(), "inverse does not exist");
    if t.sign() == Sign::Minus {
        t += BigInt::from_biguint(Sign::Plus, modulus.clone());
    }
    t.to_biguint().expect("inverse must be non-negative")
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn artifact_matches_arkworks_equation() {
        let a = build_artifact();
        assert_eq!(a.line_count, 499);
        assert_eq!(a.lines_q.len(), 499);
        assert_eq!(a.lines_s.len(), 499);
        assert!(a.arkworks_equation_holds);
        assert!(a.rust_residue_relation_holds);
    }

    #[test]
    fn quotient_artifact_has_consistent_transcript() {
        let a = build_artifact();
        let q = build_quotient_artifact(&a);
        assert_ne!(q.challenge.d0, "0x0000000000000000000000000000000000000000000000000000000000000000");
        assert!(q.transcript_challenge.starts_with("0x"));
    }

    #[test]
    fn relation_artifact_has_two_nonzero_relations() {
        let a = build_artifact();
        let r = build_relation_artifact(&a);
        assert_ne!(r.challenge.d0, "0x0000000000000000000000000000000000000000000000000000000000000000");
        assert_ne!(r.miller_relation_eval.d0, "0x0000000000000000000000000000000000000000000000000000000000000000");
        assert_ne!(r.residue_relation_eval.d0, "0x0000000000000000000000000000000000000000000000000000000000000000");
    }
}
