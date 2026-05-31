use crate::config;
use anyhow::{ensure, Result};
use ark_ff::{Field, One, Zero};
use ark_mnt4_753::Fq;
use ark_poly::{EvaluationDomain, Radix2EvaluationDomain};
use num_bigint::BigUint;

#[derive(Debug, Clone)]
pub struct DomainParameters {
    pub eta: Fq,
    pub omega: Fq,
    pub gamma: Fq,
}

impl DomainParameters {
    pub fn new() -> Self {
        let gamma = Fq::from(17u64);
        let exponent = (config::fq_modulus_biguint() - BigUint::from(1u8)) / BigUint::from(config::LDE_SIZE);
        let eta = gamma.pow(biguint_to_u64_words(&exponent));
        let omega = eta.pow([config::BLOWUP as u64]);
        Self { eta, omega, gamma }
    }

    pub fn validate(&self) -> Result<()> {
        ensure!(self.eta.pow([config::LDE_SIZE as u64]) == Fq::one(), "eta^M != 1");
        ensure!(self.eta.pow([(config::LDE_SIZE / 2) as u64]) != Fq::one(), "eta order is too small");
        ensure!(self.omega.pow([config::TRACE_SIZE as u64]) == Fq::one(), "omega^N != 1");
        ensure!(self.omega.pow([(config::TRACE_SIZE / 2) as u64]) != Fq::one(), "omega order is too small");
        ensure!(self.gamma.pow([config::LDE_SIZE as u64]) != Fq::one(), "gamma is inside subgroup");
        Ok(())
    }

    pub fn h_points(&self) -> Vec<Fq> {
        powers(self.omega, config::TRACE_SIZE, Fq::one())
    }

    pub fn d_points(&self) -> Vec<Fq> {
        powers(self.eta, config::LDE_SIZE, self.gamma)
    }
}

pub fn powers(step: Fq, count: usize, start: Fq) -> Vec<Fq> {
    let mut out = Vec::with_capacity(count);
    let mut current = start;
    for _ in 0..count {
        out.push(current);
        current *= step;
    }
    out
}

pub fn bit_reverse(mut value: usize, bits: usize) -> usize {
    let mut out = 0usize;
    for _ in 0..bits {
        out = (out << 1) | (value & 1);
        value >>= 1;
    }
    out
}

pub fn biguint_to_u64_words(value: &BigUint) -> Vec<u64> {
    let bytes = value.to_bytes_le();
    let mut words = Vec::with_capacity((bytes.len() + 7) / 8);
    for chunk in bytes.chunks(8) {
        let mut word = [0u8; 8];
        word[..chunk.len()].copy_from_slice(chunk);
        words.push(u64::from_le_bytes(word));
    }
    if words.is_empty() {
        words.push(0);
    }
    words
}

pub fn h_domain() -> Radix2EvaluationDomain<Fq> {
    let params = DomainParameters::new();
    let domain = Radix2EvaluationDomain::<Fq>::new(config::TRACE_SIZE).expect("trace domain exists");
    assert_eq!(domain.group_gen, params.omega, "arkworks trace root differs from fixed specification");
    domain
}

pub fn d_domain() -> Radix2EvaluationDomain<Fq> {
    let params = DomainParameters::new();
    let domain = Radix2EvaluationDomain::<Fq>::new(config::LDE_SIZE)
        .expect("LDE domain exists")
        .get_coset(params.gamma)
        .expect("gamma defines a coset");
    assert_eq!(domain.group_gen, params.eta, "arkworks LDE root differs from fixed specification");
    domain
}

pub fn interpolate_h(values: &[Fq]) -> Vec<Fq> {
    assert_eq!(values.len(), config::TRACE_SIZE);
    h_domain().ifft(values)
}

pub fn interpolate_d(values: &[Fq]) -> Vec<Fq> {
    assert_eq!(values.len(), config::LDE_SIZE);
    d_domain().ifft(values)
}

pub fn lde_from_coefficients(coefficients: &[Fq]) -> Vec<Fq> {
    assert!(coefficients.len() <= config::LDE_SIZE);
    let mut padded = coefficients.to_vec();
    padded.resize(config::LDE_SIZE, Fq::zero());
    d_domain().fft(&padded)
}

pub fn evaluate(coefficients: &[Fq], point: Fq) -> Fq {
    coefficients.iter().rev().fold(Fq::zero(), |acc, coefficient| acc * point + coefficient)
}

pub fn trim(mut coefficients: Vec<Fq>) -> Vec<Fq> {
    while coefficients.len() > 1 && coefficients.last() == Some(&Fq::zero()) {
        coefficients.pop();
    }
    coefficients
}

pub fn degree(coefficients: &[Fq]) -> usize {
    trim(coefficients.to_vec()).len().saturating_sub(1)
}
