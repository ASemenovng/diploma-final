use ark_ff::PrimeField;
use ark_mnt4_753::Fq;
use sha3::{Digest, Keccak256};

#[derive(Debug, Clone)]
pub struct Transcript {
    state: [u8; 32],
}

impl Transcript {
    pub fn new() -> Self {
        Self { state: Keccak256::digest(b"MNT4-MICROTRACE-DEEP-FRI-V1").into() }
    }

    pub fn absorb(&mut self, label: &str, payload: &[u8]) {
        let mut input = Vec::with_capacity(39 + label.len() + payload.len());
        input.push(0xA0);
        input.extend_from_slice(&self.state);
        input.extend_from_slice(&(label.len() as u16).to_be_bytes());
        input.extend_from_slice(label.as_bytes());
        input.extend_from_slice(&(payload.len() as u32).to_be_bytes());
        input.extend_from_slice(payload);
        self.state = Keccak256::digest(input).into();
    }

    pub fn challenge_digest(&self, label: &str, counter: u32) -> [u8; 32] {
        let mut input = Vec::with_capacity(39 + label.len());
        input.push(0xC0);
        input.extend_from_slice(&self.state);
        input.extend_from_slice(&(label.len() as u16).to_be_bytes());
        input.extend_from_slice(label.as_bytes());
        input.extend_from_slice(&counter.to_be_bytes());
        Keccak256::digest(input).into()
    }

    pub fn challenge_fq(&self, label: &str, counter: u32) -> Fq {
        Fq::from_be_bytes_mod_order(&self.challenge_digest(label, counter))
    }
}

