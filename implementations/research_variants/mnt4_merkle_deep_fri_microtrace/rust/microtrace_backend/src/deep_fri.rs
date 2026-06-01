use crate::{
    air::{self, AirPublic},
    config::{self, Profile},
    merkle::{verify_compact, CompactProof, MerkleTree, TreeTag},
    polynomial::{self, bit_reverse, DomainParameters},
    serialize,
    trace::{self, Fixture},
    transcript::Transcript,
};
use anyhow::{anyhow, ensure, Result};
use ark_ec::AffineRepr;
use ark_ff::{Field, One, Zero};
use ark_mnt4_753::{Fq, Fq4, G1Affine, G2Affine};
use ark_poly::{EvaluationDomain, Radix2EvaluationDomain};
use serde::Serialize;
use sha3::{Digest, Keccak256};
use std::{collections::{BTreeMap, BTreeSet}, time::Instant};

#[derive(Debug, Clone)]
pub struct PublicInputs {
    pub profile: Profile,
    pub config_digest: [u8; 32],
    pub root_fixed: [u8; 32],
    pub q: G2Affine,
    pub s: G2Affine,
    pub p: G1Affine,
    pub r: G1Affine,
    pub c: Fq4,
    pub c_inv: Fq4,
}

#[derive(Debug, Clone)]
pub struct OodValues {
    pub trace_z: [Fq; 4],
    pub trace_omega_z: [Fq; 4],
    pub fixed_z: [Fq; config::FIXED_COLUMNS],
    pub quotient_z: [Fq; config::QUOTIENT_SEGMENTS],
}

#[derive(Debug, Clone)]
pub struct QueryHelpers {
    pub x_inv: Fq,
    pub x_minus_z_inv: Fq,
    pub x_minus_omega_z_inv: Fq,
    pub neg_x_minus_z_inv: Fq,
    pub neg_x_minus_omega_z_inv: Fq,
}

#[derive(Debug, Clone)]
pub struct Proof {
    pub root_trace: [u8; 32],
    pub root_quotient: [u8; 32],
    pub root_deep: [u8; 32],
    pub root_fri: [[u8; 32]; 7],
    pub ood: OodValues,
    pub final_coefficients: [Fq; config::FINAL_FRI_DEGREE_BOUND],
    pub helpers: Vec<QueryHelpers>,
    pub trace: CompactProof,
    pub fixed: CompactProof,
    pub quotient: CompactProof,
    /// Payload-ы DEEP-листьев не передаются: verifier вычисляет их из раскрытий trace/fixed/quotient.
    pub deep: CompactProof,
    pub fri: Vec<CompactProof>,
}

#[derive(Debug, Clone)]
pub struct ProofBundle {
    pub public: PublicInputs,
    pub proof: Proof,
    pub metrics: Metrics,
}

#[derive(Debug, Clone, Serialize)]
pub struct Metrics {
    pub profile: &'static str,
    pub query_count: usize,
    pub proof_bytes_model: usize,
    pub public_input_bytes: usize,
    pub worst_case_calldata_gas: usize,
    pub trace_opened_leaves: usize,
    pub fixed_opened_leaves: usize,
    pub quotient_opened_leaves: usize,
    pub deep_opened_leaves: usize,
    pub fri_opened_leaves: usize,
    pub frontier_hashes: usize,
    pub fixed_table_ms: u128,
    pub trace_ms: u128,
    pub quotient_ms: u128,
    pub deep_fri_ms: u128,
}

#[derive(Debug, Clone)]
pub struct FixedArtifacts {
    pub config_digest: [u8; 32],
    pub root_fixed: [u8; 32],
    pub h_columns: Vec<Vec<Fq>>,
    pub lde_columns: Vec<Vec<Fq>>,
}

struct CommittedColumns {
    coefficients: Vec<Vec<Fq>>,
    lde: Vec<Vec<Fq>>,
    tree: MerkleTree,
}

pub fn prove(fixture: &Fixture, profile: Profile) -> Result<ProofBundle> {
    let fixed_started = Instant::now();
    let params = DomainParameters::new();
    params.validate()?;
    let table = trace::build_fixed_table(fixture.q, fixture.s);
    let h_columns = air::fixed_h_columns(&table);
    let fixed = commit_h_columns(TreeTag::Fixed, h_columns.clone());
    let fixed_table_ms = fixed_started.elapsed().as_millis();

    let trace_started = Instant::now();
    let witness = trace::build_trace(fixture, &table);
    let air_public = AirPublic { p: fixture.p, r: fixture.r, c: witness.c, c_inv: witness.c_inv };
    let root_fixed = fixed.tree.root();
    let config_digest = serialize::config_digest(root_fixed, fixture.q, fixture.s, params.omega, params.eta, params.gamma);
    let public = PublicInputs {
        profile,
        config_digest,
        root_fixed,
        q: fixture.q,
        s: fixture.s,
        p: fixture.p,
        r: fixture.r,
        c: witness.c,
        c_inv: witness.c_inv,
    };
    let trace = commit_h_columns(TreeTag::Trace, air::trace_h_columns(&witness));
    let root_trace = trace.tree.root();
    let trace_ms = trace_started.elapsed().as_millis();

    let mut transcript = Transcript::new();
    transcript.absorb("public", &public_transcript_bytes(&public));
    transcript.absorb("trace-root", &root_trace);
    let beta = transcript.challenge_fq("beta", 0);

    let quotient_started = Instant::now();
    let quotient_coefficients = build_quotient(&trace.lde, &fixed.lde, &air_public, beta)?;
    ensure!(polynomial::degree(&quotient_coefficients) < 2 * config::TRACE_SIZE, "quotient degree exceeds 2N");
    let quotient_segment_coefficients = split_quotient(&quotient_coefficients);
    let quotient = commit_coefficients(TreeTag::Quotient, quotient_segment_coefficients.to_vec());
    let root_quotient = quotient.tree.root();
    let quotient_ms = quotient_started.elapsed().as_millis();
    transcript.absorb("quotient-root", &root_quotient);

    let deep_fri_started = Instant::now();
    let z = challenge_outside_domains(&transcript, "z", &params);
    let ood = OodValues {
        trace_z: evaluate_columns4(&trace.coefficients, z),
        trace_omega_z: evaluate_columns4(&trace.coefficients, params.omega * z),
        fixed_z: evaluate_columns17(&fixed.coefficients, z),
        quotient_z: evaluate_columns2(&quotient.coefficients, z),
    };
    check_ood_identity(&ood, &air_public, beta, z)?;
    transcript.absorb("ood", &ood_bytes(&ood));
    let alpha = transcript.challenge_fq("alpha", 0);

    let deep_values = build_deep_values(
        &trace.lde,
        &fixed.lde,
        &quotient.lde,
        &ood,
        alpha,
        z,
        params.omega,
        &params.d_points(),
    );
    let deep_tree = tree_from_single_column(TreeTag::Deep, &deep_values);
    let root_deep = deep_tree.root();
    transcript.absorb("deep-root", &root_deep);

    let mut fri_layers = Vec::<Vec<Fq>>::with_capacity(config::FRI_ROUNDS + 1);
    fri_layers.push(deep_values);
    let mut fri_trees = Vec::<MerkleTree>::with_capacity(7);
    let mut root_fri = [[0u8; 32]; 7];
    let mut rhos = Vec::with_capacity(config::FRI_ROUNDS);
    for round in 0..config::FRI_ROUNDS {
        let rho = transcript.challenge_fq(&format!("rho-{round}"), 0);
        rhos.push(rho);
        let next = fri_fold(&fri_layers[round], params.gamma.pow([1u64 << round]), rho);
        fri_layers.push(next);
        if round < 7 {
            let tree = tree_from_single_column(TreeTag::fri(round + 1), &fri_layers[round + 1]);
            root_fri[round] = tree.root();
            transcript.absorb(&format!("fri-root-{}", round + 1), &root_fri[round]);
            fri_trees.push(tree);
        }
    }
    let final_coefficients = interpolate_final_fri(&fri_layers[8], params.gamma.pow([256]))?;
    transcript.absorb("fri-final", &serialize::fq_row_bytes(&final_coefficients));
    let query_seed = transcript.challenge_digest("query-seed", 0);
    let queries = derive_queries(query_seed, profile.query_count());

    let base_positions = base_opening_positions(&queries);
    let fri_positions = (1..=7).map(|level| fri_opening_positions(&queries, level)).collect::<Vec<_>>();
    let helpers = queries
        .iter()
        .map(|query| query_helpers(params.gamma * params.eta.pow([*query as u64]), z, params.omega))
        .collect::<Result<Vec<_>>>()?;

    let trace_open = trace.tree.open_compact(&base_positions);
    let fixed_open = fixed.tree.open_compact(&base_positions);
    let quotient_open = quotient.tree.open_compact(&base_positions);
    let mut deep_open = deep_tree.open_compact(&base_positions);
    deep_open.payloads.clear();
    let fri_open = fri_trees
        .iter()
        .zip(&fri_positions)
        .map(|(tree, positions)| tree.open_compact(positions))
        .collect::<Vec<_>>();
    let proof = Proof {
        root_trace,
        root_quotient,
        root_deep,
        root_fri,
        ood,
        final_coefficients,
        helpers,
        trace: trace_open,
        fixed: fixed_open,
        quotient: quotient_open,
        deep: deep_open,
        fri: fri_open,
    };
    verify(&public, &proof)?;
    let deep_fri_ms = deep_fri_started.elapsed().as_millis();
    let metrics = metrics(&public, &proof, fixed_table_ms, trace_ms, quotient_ms, deep_fri_ms);
    Ok(ProofBundle { public, proof, metrics })
}

pub fn fixed_artifacts(fixture: &Fixture) -> Result<FixedArtifacts> {
    let params = DomainParameters::new();
    params.validate()?;
    let table = trace::build_fixed_table(fixture.q, fixture.s);
    let h_columns = air::fixed_h_columns(&table);
    let fixed = commit_h_columns(TreeTag::Fixed, h_columns.clone());
    let root_fixed = fixed.tree.root();
    let config_digest =
        serialize::config_digest(root_fixed, fixture.q, fixture.s, params.omega, params.eta, params.gamma);
    Ok(FixedArtifacts { config_digest, root_fixed, h_columns, lde_columns: fixed.lde })
}

pub fn verify(public: &PublicInputs, proof: &Proof) -> Result<()> {
    ensure!(!public.p.is_zero() && !public.r.is_zero(), "G1 infinity is not accepted");
    ensure!(public.p.is_on_curve() && public.r.is_on_curve(), "G1 point is not on curve");
    ensure!(public.c * public.c_inv == Fq4::one(), "cInv is not inverse of c");
    let params = DomainParameters::new();
    params.validate()?;
    let expected_config = serialize::config_digest(public.root_fixed, public.q, public.s, params.omega, params.eta, params.gamma);
    ensure!(public.config_digest == expected_config, "config digest mismatch");

    let mut transcript = Transcript::new();
    transcript.absorb("public", &public_transcript_bytes(public));
    transcript.absorb("trace-root", &proof.root_trace);
    let beta = transcript.challenge_fq("beta", 0);
    transcript.absorb("quotient-root", &proof.root_quotient);
    let z = challenge_outside_domains(&transcript, "z", &params);
    check_ood_identity(&proof.ood, &AirPublic { p: public.p, r: public.r, c: public.c, c_inv: public.c_inv }, beta, z)?;
    transcript.absorb("ood", &ood_bytes(&proof.ood));
    let alpha = transcript.challenge_fq("alpha", 0);
    transcript.absorb("deep-root", &proof.root_deep);
    let mut rhos = Vec::with_capacity(config::FRI_ROUNDS);
    for round in 0..config::FRI_ROUNDS {
        rhos.push(transcript.challenge_fq(&format!("rho-{round}"), 0));
        if round < 7 {
            transcript.absorb(&format!("fri-root-{}", round + 1), &proof.root_fri[round]);
        }
    }
    transcript.absorb("fri-final", &serialize::fq_row_bytes(&proof.final_coefficients));
    let queries = derive_queries(transcript.challenge_digest("query-seed", 0), public.profile.query_count());
    ensure!(proof.helpers.len() == queries.len(), "query helper count mismatch");
    ensure!(proof.fri.len() == 7, "FRI section count mismatch");

    let base_positions = base_opening_positions(&queries);
    let fri_positions = (1..=7).map(|level| fri_opening_positions(&queries, level)).collect::<Vec<_>>();
    ensure_positions(&proof.trace, &base_positions)?;
    ensure_positions(&proof.fixed, &base_positions)?;
    ensure_positions(&proof.quotient, &base_positions)?;
    ensure_positions(&proof.deep, &base_positions)?;
    verify_compact(TreeTag::Trace, proof.root_trace, config::LDE_SIZE, &proof.trace)?;
    verify_compact(TreeTag::Fixed, public.root_fixed, config::LDE_SIZE, &proof.fixed)?;
    verify_compact(TreeTag::Quotient, proof.root_quotient, config::LDE_SIZE, &proof.quotient)?;
    for (level, section) in proof.fri.iter().enumerate() {
        ensure_positions(section, &fri_positions[level])?;
        verify_compact(TreeTag::fri(level + 1), proof.root_fri[level], config::LDE_SIZE >> (level + 1), section)?;
    }

    let trace_payloads = payload_map(&proof.trace);
    let fixed_payloads = payload_map(&proof.fixed);
    let quotient_payloads = payload_map(&proof.quotient);
    let fri_payloads = proof.fri.iter().map(payload_map).collect::<Vec<_>>();
    let mut deep_payloads = BTreeMap::<usize, Vec<u8>>::new();
    for (query, helpers) in queries.iter().zip(&proof.helpers) {
        let x = params.gamma * params.eta.pow([*query as u64]);
        validate_helpers(helpers, x, z, params.omega)?;
        let plus = opened_deep_value(*query, x, helpers.x_minus_z_inv, helpers.x_minus_omega_z_inv, &trace_payloads, &fixed_payloads, &quotient_payloads, &proof.ood, alpha)?;
        let neg_index = *query + config::LDE_SIZE / 2;
        let minus = opened_deep_value(neg_index, -x, helpers.neg_x_minus_z_inv, helpers.neg_x_minus_omega_z_inv, &trace_payloads, &fixed_payloads, &quotient_payloads, &proof.ood, alpha)?;
        deep_payloads.insert(physical_position(*query, config::LDE_SIZE), serialize::encode_fri_value(plus));
        deep_payloads.insert(physical_position(neg_index, config::LDE_SIZE), serialize::encode_fri_value(minus));

        let mut folded = fri_fold_pair(plus, minus, x, helpers.x_inv, rhos[0]);
        for level in 1..=7 {
            let width = config::LDE_SIZE >> level;
            let exponent = *query % width;
            let sibling_exponent = (exponent + width / 2) % width;
            let first = decode_fri_payload(&fri_payloads[level - 1], exponent, width)?;
            let second = decode_fri_payload(&fri_payloads[level - 1], sibling_exponent, width)?;
            let x_level_raw = x.pow([1u64 << level]);
            let x_inv_raw = helpers.x_inv.pow([1u64 << level]);
            let (positive, negative) = if exponent < width / 2 { (first, second) } else { (second, first) };
            ensure!(folded == if exponent < width / 2 { positive } else { negative }, "FRI linkage mismatch at level {level}");
            let x_inv = if exponent < width / 2 { x_inv_raw } else { -x_inv_raw };
            folded = fri_fold_pair(positive, negative, x_level_raw, x_inv, rhos[level]);
        }
        let final_x = x.pow([256]);
        ensure!(folded == polynomial::evaluate(&proof.final_coefficients, final_x), "final FRI polynomial mismatch");
    }
    let calculated_deep = CompactProof {
        positions: proof.deep.positions.clone(),
        payloads: proof.deep.positions.iter().map(|position| deep_payloads[position].clone()).collect(),
        frontier: proof.deep.frontier.clone(),
    };
    verify_compact(TreeTag::Deep, proof.root_deep, config::LDE_SIZE, &calculated_deep)?;
    Ok(())
}

fn build_quotient(trace_lde: &[Vec<Fq>], fixed_lde: &[Vec<Fq>], public: &AirPublic, beta: Fq) -> Result<Vec<Fq>> {
    let params = DomainParameters::new();
    let d_points = params.d_points();
    let mut values = Vec::with_capacity(config::LDE_SIZE);
    for index in 0..config::LDE_SIZE {
        let current = column_values4(trace_lde, index);
        let next = column_values4(trace_lde, (index + config::BLOWUP) % config::LDE_SIZE);
        let fixed = column_values(fixed_lde, index);
        let numerator = air::combined_numerator(current, next, &fixed, public, beta);
        let zh = d_points[index].pow([config::TRACE_SIZE as u64]) - Fq::one();
        values.push(numerator * zh.inverse().ok_or_else(|| anyhow!("LDE intersects trace domain"))?);
    }
    Ok(polynomial::trim(polynomial::interpolate_d(&values)))
}

fn split_quotient(coefficients: &[Fq]) -> [Vec<Fq>; 2] {
    let mut padded = coefficients.to_vec();
    padded.resize(2 * config::TRACE_SIZE, Fq::zero());
    [padded[..config::TRACE_SIZE].to_vec(), padded[config::TRACE_SIZE..].to_vec()]
}

fn commit_h_columns(tag: TreeTag, h_columns: Vec<Vec<Fq>>) -> CommittedColumns {
    let coefficients = h_columns.iter().map(|column| polynomial::interpolate_h(column)).collect::<Vec<_>>();
    commit_coefficients(tag, coefficients)
}

fn commit_coefficients(tag: TreeTag, coefficients: Vec<Vec<Fq>>) -> CommittedColumns {
    let lde = coefficients.iter().map(|column| polynomial::lde_from_coefficients(column)).collect::<Vec<_>>();
    let tree = tree_from_columns(tag, &lde);
    CommittedColumns { coefficients, lde, tree }
}

fn tree_from_columns(tag: TreeTag, columns: &[Vec<Fq>]) -> MerkleTree {
    let width = columns[0].len();
    let mut payloads = vec![Vec::new(); width];
    for exponent in 0..width {
        payloads[physical_position(exponent, width)] = serialize::fq_row_bytes(&column_values(columns, exponent));
    }
    MerkleTree::new(tag, payloads)
}

fn tree_from_single_column(tag: TreeTag, values: &[Fq]) -> MerkleTree {
    tree_from_columns(tag, &[values.to_vec()])
}

fn build_deep_values(
    trace_lde: &[Vec<Fq>],
    fixed_lde: &[Vec<Fq>],
    quotient_lde: &[Vec<Fq>],
    ood: &OodValues,
    alpha: Fq,
    z: Fq,
    omega: Fq,
    d_points: &[Fq],
) -> Vec<Fq> {
    d_points
        .iter()
        .enumerate()
        .map(|(index, x)| {
            deep_value(
                &column_values(trace_lde, index),
                &column_values(fixed_lde, index),
                &column_values(quotient_lde, index),
                ood,
                alpha,
                (*x - z).inverse().unwrap(),
                (*x - omega * z).inverse().unwrap(),
            )
        })
        .collect()
}

fn deep_value(trace_values: &[Fq], fixed_values: &[Fq], quotient_values: &[Fq], ood: &OodValues, alpha: Fq, inv_z: Fq, inv_omega_z: Fq) -> Fq {
    let mut power = Fq::one();
    let mut out = Fq::zero();
    for (value, at_z) in trace_values.iter().zip(ood.trace_z) {
        out += power * (*value - at_z) * inv_z;
        power *= alpha;
    }
    for (value, at_z) in fixed_values.iter().zip(ood.fixed_z) {
        out += power * (*value - at_z) * inv_z;
        power *= alpha;
    }
    for (value, at_z) in quotient_values.iter().zip(ood.quotient_z) {
        out += power * (*value - at_z) * inv_z;
        power *= alpha;
    }
    for (value, at_omega_z) in trace_values.iter().zip(ood.trace_omega_z) {
        out += power * (*value - at_omega_z) * inv_omega_z;
        power *= alpha;
    }
    out
}

fn opened_deep_value(
    exponent: usize,
    _x: Fq,
    inv_z: Fq,
    inv_omega_z: Fq,
    trace_payloads: &BTreeMap<usize, Vec<u8>>,
    fixed_payloads: &BTreeMap<usize, Vec<u8>>,
    quotient_payloads: &BTreeMap<usize, Vec<u8>>,
    ood: &OodValues,
    alpha: Fq,
) -> Result<Fq> {
    let position = physical_position(exponent, config::LDE_SIZE);
    let trace_values = serialize::fq_row_from_bytes(&trace_payloads[&position], config::TRACE_COLUMNS)?;
    let fixed_values = serialize::fq_row_from_bytes(&fixed_payloads[&position], config::FIXED_COLUMNS)?;
    let quotient_values = serialize::fq_row_from_bytes(&quotient_payloads[&position], config::QUOTIENT_SEGMENTS)?;
    Ok(deep_value(&trace_values, &fixed_values, &quotient_values, ood, alpha, inv_z, inv_omega_z))
}

fn check_ood_identity(ood: &OodValues, public: &AirPublic, beta: Fq, z: Fq) -> Result<()> {
    let numerator = air::combined_numerator(ood.trace_z, ood.trace_omega_z, &ood.fixed_z, public, beta);
    let quotient = ood.quotient_z[0] + z.pow([config::TRACE_SIZE as u64]) * ood.quotient_z[1];
    ensure!(quotient * (z.pow([config::TRACE_SIZE as u64]) - Fq::one()) == numerator, "OOD quotient identity mismatch");
    Ok(())
}

fn fri_fold(values: &[Fq], offset: Fq, rho: Fq) -> Vec<Fq> {
    let half = values.len() / 2;
    let two_inv = Fq::from(2u64).inverse().unwrap();
    let mut x = offset;
    let step = DomainParameters::new().eta.pow([(config::LDE_SIZE / values.len()) as u64]);
    let mut out = Vec::with_capacity(half);
    for index in 0..half {
        let positive = values[index];
        let negative = values[index + half];
        let x_inv = x.inverse().unwrap();
        out.push((positive + negative) * two_inv + rho * (positive - negative) * two_inv * x_inv);
        x *= step;
    }
    out
}

fn fri_fold_pair(positive: Fq, negative: Fq, _x: Fq, x_inv: Fq, rho: Fq) -> Fq {
    let two_inv = Fq::from(2u64).inverse().unwrap();
    (positive + negative) * two_inv + rho * (positive - negative) * two_inv * x_inv
}

fn interpolate_final_fri(values: &[Fq], offset: Fq) -> Result<[Fq; config::FINAL_FRI_DEGREE_BOUND]> {
    ensure!(values.len() == 128, "final FRI layer must contain 128 evaluations");
    let domain = Radix2EvaluationDomain::<Fq>::new(values.len()).unwrap().get_coset(offset).unwrap();
    let coefficients = polynomial::trim(domain.ifft(values));
    ensure!(coefficients.len() <= config::FINAL_FRI_DEGREE_BOUND, "final FRI polynomial has degree >= 8");
    let mut out = [Fq::zero(); config::FINAL_FRI_DEGREE_BOUND];
    out[..coefficients.len()].copy_from_slice(&coefficients);
    let params = DomainParameters::new();
    let step = params.eta.pow([256]);
    let mut x = offset;
    for (index, expected) in values.iter().enumerate() {
        ensure!(polynomial::evaluate(&out, x) == *expected, "final FRI interpolation mismatch at index {index}");
        x *= step;
    }
    Ok(out)
}

fn query_helpers(x: Fq, z: Fq, omega: Fq) -> Result<QueryHelpers> {
    Ok(QueryHelpers {
        x_inv: x.inverse().ok_or_else(|| anyhow!("x is zero"))?,
        x_minus_z_inv: (x - z).inverse().ok_or_else(|| anyhow!("x=z"))?,
        x_minus_omega_z_inv: (x - omega * z).inverse().ok_or_else(|| anyhow!("x=omega*z"))?,
        neg_x_minus_z_inv: (-x - z).inverse().ok_or_else(|| anyhow!("-x=z"))?,
        neg_x_minus_omega_z_inv: (-x - omega * z).inverse().ok_or_else(|| anyhow!("-x=omega*z"))?,
    })
}

fn validate_helpers(helpers: &QueryHelpers, x: Fq, z: Fq, omega: Fq) -> Result<()> {
    ensure!(x * helpers.x_inv == Fq::one(), "invalid x inverse");
    ensure!((x - z) * helpers.x_minus_z_inv == Fq::one(), "invalid x-z inverse");
    ensure!((x - omega * z) * helpers.x_minus_omega_z_inv == Fq::one(), "invalid x-omega*z inverse");
    ensure!((-x - z) * helpers.neg_x_minus_z_inv == Fq::one(), "invalid -x-z inverse");
    ensure!((-x - omega * z) * helpers.neg_x_minus_omega_z_inv == Fq::one(), "invalid -x-omega*z inverse");
    Ok(())
}

fn challenge_outside_domains(transcript: &Transcript, label: &str, params: &DomainParameters) -> Fq {
    for counter in 0..u32::MAX {
        let candidate = transcript.challenge_fq(label, counter);
        if candidate.pow([config::TRACE_SIZE as u64]) != Fq::one()
            && candidate.pow([config::LDE_SIZE as u64]) != params.gamma.pow([config::LDE_SIZE as u64])
        {
            return candidate;
        }
    }
    unreachable!("challenge counter exhausted")
}

fn derive_queries(seed: [u8; 32], count: usize) -> Vec<usize> {
    let mut selected = BTreeSet::new();
    for counter in 0..u32::MAX {
        if selected.len() == count {
            break;
        }
        let mut bytes = Vec::with_capacity(37);
        bytes.push(0xD0);
        bytes.extend_from_slice(&seed);
        bytes.extend_from_slice(&counter.to_be_bytes());
        let digest: [u8; 32] = Keccak256::digest(bytes).into();
        let mut tail = [0u8; 8];
        tail.copy_from_slice(&digest[24..]);
        selected.insert((u64::from_be_bytes(tail) as usize) % (config::LDE_SIZE / 2));
    }
    selected.into_iter().collect()
}

fn base_opening_positions(queries: &[usize]) -> Vec<usize> {
    let mut out = BTreeSet::new();
    for query in queries {
        out.insert(physical_position(*query, config::LDE_SIZE));
        out.insert(physical_position(*query + config::LDE_SIZE / 2, config::LDE_SIZE));
    }
    out.into_iter().collect()
}

fn fri_opening_positions(queries: &[usize], level: usize) -> Vec<usize> {
    let width = config::LDE_SIZE >> level;
    let mut out = BTreeSet::new();
    for query in queries {
        let exponent = *query % width;
        out.insert(physical_position(exponent, width));
        out.insert(physical_position((exponent + width / 2) % width, width));
    }
    out.into_iter().collect()
}

fn physical_position(exponent: usize, width: usize) -> usize {
    bit_reverse(exponent, width.ilog2() as usize)
}

fn ensure_positions(section: &CompactProof, expected: &[usize]) -> Result<()> {
    ensure!(section.positions == expected, "opening position set mismatch");
    Ok(())
}

fn payload_map(section: &CompactProof) -> BTreeMap<usize, Vec<u8>> {
    section.positions.iter().copied().zip(section.payloads.iter().cloned()).collect()
}

fn decode_fri_payload(payloads: &BTreeMap<usize, Vec<u8>>, exponent: usize, width: usize) -> Result<Fq> {
    let position = physical_position(exponent, width);
    let row = serialize::fq_row_from_bytes(payloads.get(&position).ok_or_else(|| anyhow!("FRI payload missing"))?, 1)?;
    Ok(row[0])
}

fn evaluate_columns4(columns: &[Vec<Fq>], point: Fq) -> [Fq; 4] {
    columns.iter().map(|column| polynomial::evaluate(column, point)).collect::<Vec<_>>().try_into().unwrap()
}

fn evaluate_columns17(columns: &[Vec<Fq>], point: Fq) -> [Fq; config::FIXED_COLUMNS] {
    columns.iter().map(|column| polynomial::evaluate(column, point)).collect::<Vec<_>>().try_into().unwrap()
}

fn evaluate_columns2(columns: &[Vec<Fq>], point: Fq) -> [Fq; config::QUOTIENT_SEGMENTS] {
    columns.iter().map(|column| polynomial::evaluate(column, point)).collect::<Vec<_>>().try_into().unwrap()
}

fn column_values(columns: &[Vec<Fq>], index: usize) -> Vec<Fq> {
    columns.iter().map(|column| column[index]).collect()
}

fn column_values4(columns: &[Vec<Fq>], index: usize) -> [Fq; 4] {
    column_values(columns, index).try_into().unwrap()
}

fn public_transcript_bytes(public: &PublicInputs) -> Vec<u8> {
    serialize::public_bytes(public.profile, public.config_digest, public.root_fixed, public.p, public.r, public.c, public.c_inv)
}

fn ood_bytes(ood: &OodValues) -> Vec<u8> {
    serialize::fq_row_bytes(&[
        ood.trace_z.as_slice(),
        ood.trace_omega_z.as_slice(),
        ood.fixed_z.as_slice(),
        ood.quotient_z.as_slice(),
    ]
    .concat())
}

pub fn metrics(
    public: &PublicInputs,
    proof: &Proof,
    fixed_table_ms: u128,
    trace_ms: u128,
    quotient_ms: u128,
    deep_fri_ms: u128,
) -> Metrics {
    let public_input_bytes = public_transcript_bytes(public).len() - 3 - 64;
    let payload_bytes = proof.trace.payloads.iter().map(Vec::len).sum::<usize>()
        + proof.fixed.payloads.iter().map(Vec::len).sum::<usize>()
        + proof.quotient.payloads.iter().map(Vec::len).sum::<usize>()
        + proof.fri.iter().flat_map(|section| &section.payloads).map(Vec::len).sum::<usize>();
    let frontier_hashes = proof.trace.frontier.len()
        + proof.fixed.frontier.len()
        + proof.quotient.frontier.len()
        + proof.deep.frontier.len()
        + proof.fri.iter().map(|section| section.frontier.len()).sum::<usize>();
    let fixed_header = 3696usize;
    let helpers = proof.helpers.len() * 5 * serialize::FQ_BYTES;
    let counters = (4 + 7) * 4;
    let proof_bytes_model = fixed_header + helpers + counters + payload_bytes + frontier_hashes * 32;
    Metrics {
        profile: public.profile.name(),
        query_count: public.profile.query_count(),
        proof_bytes_model,
        public_input_bytes,
        worst_case_calldata_gas: 16 * (proof_bytes_model + public_input_bytes),
        trace_opened_leaves: proof.trace.positions.len(),
        fixed_opened_leaves: proof.fixed.positions.len(),
        quotient_opened_leaves: proof.quotient.positions.len(),
        deep_opened_leaves: proof.deep.positions.len(),
        fri_opened_leaves: proof.fri.iter().map(|section| section.positions.len()).sum(),
        frontier_hashes,
        fixed_table_ms,
        trace_ms,
        quotient_ms,
        deep_fri_ms,
    }
}
