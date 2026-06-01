use crate::config;
use anyhow::{ensure, Result};
use ark_ff::{BigInteger, PrimeField};
use ark_mnt4_753::{Fq, Fq2, Fq4, G1Affine, G2Affine};
use sha3::{Digest, Keccak256};
use crate::{deep_fri, merkle::CompactProof};

pub const FQ_BYTES: usize = 96;

pub fn fq_bytes(value: Fq) -> [u8; FQ_BYTES] {
    let raw = value.into_bigint().to_bytes_be();
    let mut out = [0u8; FQ_BYTES];
    out[FQ_BYTES - raw.len()..].copy_from_slice(&raw);
    out
}

pub fn fq_from_bytes(bytes: &[u8]) -> Result<Fq> {
    ensure!(bytes.len() == FQ_BYTES, "Fq encoding must contain 96 bytes");
    let value = Fq::from_be_bytes_mod_order(bytes);
    ensure!(fq_bytes(value) == bytes, "non-canonical Fq encoding");
    Ok(value)
}

pub fn fq2_bytes(value: Fq2) -> Vec<u8> {
    [fq_bytes(value.c0).as_slice(), fq_bytes(value.c1).as_slice()].concat()
}

pub fn fq4_bytes(value: Fq4) -> Vec<u8> {
    [fq2_bytes(value.c0), fq2_bytes(value.c1)].concat()
}

pub fn g1_bytes(value: G1Affine) -> Vec<u8> {
    [fq_bytes(value.x).as_slice(), fq_bytes(value.y).as_slice()].concat()
}

pub fn g2_bytes(value: G2Affine) -> Vec<u8> {
    [fq2_bytes(value.x), fq2_bytes(value.y)].concat()
}

pub fn fq_row_bytes(values: &[Fq]) -> Vec<u8> {
    values.iter().flat_map(|value| fq_bytes(*value)).collect()
}

/// Serializes a column-major evaluation table row by row. This layout is easy
/// to inspect independently and matches the order committed by the Merkle tree.
pub fn column_table_bytes(columns: &[Vec<Fq>]) -> Vec<u8> {
    let rows = columns.first().map(Vec::len).unwrap_or_default();
    assert!(columns.iter().all(|column| column.len() == rows));
    let mut out = Vec::with_capacity(rows * columns.len() * FQ_BYTES);
    for row in 0..rows {
        out.extend_from_slice(&fq_row_bytes(&columns.iter().map(|column| column[row]).collect::<Vec<_>>()));
    }
    out
}

pub fn fq_row_from_bytes(bytes: &[u8], count: usize) -> Result<Vec<Fq>> {
    ensure!(bytes.len() == count * FQ_BYTES, "row length mismatch");
    bytes.chunks_exact(FQ_BYTES).map(fq_from_bytes).collect()
}

pub fn u16_be(value: usize) -> [u8; 2] {
    (value as u16).to_be_bytes()
}

pub fn u32_be(value: usize) -> [u8; 4] {
    (value as u32).to_be_bytes()
}

pub fn config_digest(root_fixed: [u8; 32], q: G2Affine, s: G2Affine, omega: Fq, eta: Fq, gamma: Fq) -> [u8; 32] {
    let mut bytes = Vec::new();
    bytes.push(0xE0);
    bytes.extend_from_slice(&config::VERSION.to_be_bytes());
    let modulus = config::fq_modulus_biguint().to_bytes_be();
    let mut modulus_be = [0u8; FQ_BYTES];
    modulus_be[FQ_BYTES - modulus.len()..].copy_from_slice(&modulus);
    bytes.extend_from_slice(&modulus_be);
    // Scalar modulus is serialized as an unsigned 768-bit integer without reducing it into Fq.
    let scalar = config::scalar_modulus_biguint().to_bytes_be();
    let mut scalar_be = [0u8; FQ_BYTES];
    scalar_be[FQ_BYTES - scalar.len()..].copy_from_slice(&scalar);
    bytes.extend_from_slice(&scalar_be);
    bytes.extend_from_slice(&u32_be(config::TRACE_SIZE));
    bytes.extend_from_slice(&u32_be(config::LDE_SIZE));
    bytes.push(config::BLOWUP as u8);
    bytes.extend_from_slice(&fq_bytes(omega));
    bytes.extend_from_slice(&fq_bytes(eta));
    bytes.extend_from_slice(&fq_bytes(gamma));
    bytes.extend_from_slice(&g2_bytes(q));
    bytes.extend_from_slice(&g2_bytes(s));
    bytes.extend_from_slice(&root_fixed);
    Keccak256::digest(bytes).into()
}

pub fn public_bytes(
    profile: config::Profile,
    config_digest: [u8; 32],
    root_fixed: [u8; 32],
    p: G1Affine,
    r: G1Affine,
    c: Fq4,
    c_inv: Fq4,
) -> Vec<u8> {
    let mut bytes = Vec::new();
    bytes.extend_from_slice(&config::VERSION.to_be_bytes());
    bytes.push(profile as u8);
    bytes.extend_from_slice(&config_digest);
    bytes.extend_from_slice(&root_fixed);
    bytes.extend_from_slice(&g1_bytes(p));
    bytes.extend_from_slice(&g1_bytes(r));
    bytes.extend_from_slice(&fq4_bytes(c));
    bytes.extend_from_slice(&fq4_bytes(c_inv));
    bytes
}

pub fn encode_fixed_row(row: &[Fq]) -> Vec<u8> {
    fq_row_bytes(row)
}

pub fn encode_trace_row(row: &[Fq; config::TRACE_COLUMNS]) -> Vec<u8> {
    fq_row_bytes(row)
}

pub fn encode_quotient_row(row: &[Fq; config::QUOTIENT_SEGMENTS]) -> Vec<u8> {
    fq_row_bytes(row)
}

pub fn encode_fri_value(value: Fq) -> Vec<u8> {
    fq_bytes(value).to_vec()
}

pub fn proof_bytes(public: &deep_fri::PublicInputs, proof: &deep_fri::Proof) -> Vec<u8> {
    let mut bytes = Vec::new();
    bytes.extend_from_slice(&0x4d344446u32.to_be_bytes()); // ASCII M4DF
    bytes.extend_from_slice(&config::VERSION.to_be_bytes());
    bytes.push(public.profile as u8);
    bytes.push(public.profile.query_count() as u8);
    bytes.extend_from_slice(&u32_be(config::LDE_SIZE));
    bytes.extend_from_slice(&u32_be(config::TRACE_SIZE));
    bytes.extend_from_slice(&proof.root_trace);
    bytes.extend_from_slice(&proof.root_quotient);
    bytes.extend_from_slice(&proof.root_deep);
    for root in proof.root_fri {
        bytes.extend_from_slice(&root);
    }
    bytes.extend_from_slice(&fq_row_bytes(&[
        proof.ood.trace_z.as_slice(),
        proof.ood.trace_omega_z.as_slice(),
        proof.ood.fixed_z.as_slice(),
        proof.ood.quotient_z.as_slice(),
    ]
    .concat()));
    bytes.extend_from_slice(&fq_row_bytes(&proof.final_coefficients));
    for helper in &proof.helpers {
        bytes.extend_from_slice(&fq_row_bytes(&[
            helper.x_inv,
            helper.x_minus_z_inv,
            helper.x_minus_omega_z_inv,
            helper.neg_x_minus_z_inv,
            helper.neg_x_minus_omega_z_inv,
        ]));
    }
    append_section(&mut bytes, &proof.trace, true);
    append_section(&mut bytes, &proof.fixed, true);
    append_section(&mut bytes, &proof.quotient, true);
    append_section(&mut bytes, &proof.deep, false);
    for section in &proof.fri {
        append_section(&mut bytes, section, true);
    }
    bytes
}

fn append_section(out: &mut Vec<u8>, section: &CompactProof, include_payloads: bool) {
    out.extend_from_slice(&u16_be(section.positions.len()));
    if include_payloads {
        assert_eq!(section.positions.len(), section.payloads.len());
        for payload in &section.payloads {
            out.extend_from_slice(payload);
        }
    } else {
        assert!(section.payloads.is_empty());
    }
    out.extend_from_slice(&u16_be(section.frontier.len()));
    for hash in &section.frontier {
        out.extend_from_slice(hash);
    }
}

pub fn hex0x(bytes: &[u8]) -> String {
    format!("0x{}", hex::encode(bytes))
}
