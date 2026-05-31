use anyhow::{Context, Result};
use mnt4_merkle_deep_fri_backend::{
    config::Profile, deep_fri, polynomial::DomainParameters, security, serialize, trace::Fixture,
};
use serde_json::json;
use std::{env, fs, path::PathBuf, time::Instant};

fn main() -> Result<()> {
    let mut args = env::args().skip(1);
    let output = PathBuf::from(args.next().unwrap_or_else(|| "artifacts/benchmark-32q".to_owned()));
    let profile = match args.next().as_deref() {
        None | Some("benchmark-32q") => Profile::Benchmark32,
        Some("conservative-128q") => Profile::Conservative128,
        Some(other) => anyhow::bail!("unknown profile: {other}"),
    };
    fs::create_dir_all(&output).with_context(|| format!("create {}", output.display()))?;
    let started = Instant::now();
    let fixture = Fixture::non_degenerate();
    let bundle = deep_fri::prove(&fixture, profile)?;
    let proving_ms = started.elapsed().as_millis();
    let proof = serialize::proof_bytes(&bundle.public, &bundle.proof);
    fs::write(output.join("proof.bin"), &proof)?;
    fs::write(output.join("proof.hex"), serialize::hex0x(&proof))?;
    fs::write(output.join("root_fixed.hex"), serialize::hex0x(&bundle.public.root_fixed))?;
    let fixed = deep_fri::fixed_artifacts(&fixture)?;
    anyhow::ensure!(fixed.root_fixed == bundle.public.root_fixed, "fixed root changed between reproducible builds");
    anyhow::ensure!(fixed.config_digest == bundle.public.config_digest, "config digest changed between reproducible builds");
    fs::write(output.join("fixed_table_h.bin"), serialize::column_table_bytes(&fixed.h_columns))?;
    fs::write(output.join("fixed_table_lde.bin"), serialize::column_table_bytes(&fixed.lde_columns))?;
    fs::write(
        output.join("fixture_public_inputs.json"),
        serde_json::to_vec_pretty(&json!({
            "profile": profile.name(),
            "profileId": profile as u8,
            "configDigest": serialize::hex0x(&bundle.public.config_digest),
            "rootFixed": serialize::hex0x(&bundle.public.root_fixed),
            "p": serialize::hex0x(&serialize::g1_bytes(bundle.public.p)),
            "r": serialize::hex0x(&serialize::g1_bytes(bundle.public.r)),
            "c": serialize::hex0x(&serialize::fq4_bytes(bundle.public.c)),
            "cInv": serialize::hex0x(&serialize::fq4_bytes(bundle.public.c_inv)),
        }))?,
    )?;
    fs::write(
        output.join("metrics.json"),
        serde_json::to_vec_pretty(&json!({
            "provingMs": proving_ms,
            "peakRssBytes": peak_rss_bytes(),
            "actualProofBytes": proof.len(),
            "model": bundle.metrics,
        }))?,
    )?;
    fs::write(
        output.join("security_report.json"),
        serde_json::to_vec_pretty(&security::report(profile))?,
    )?;
    let params = DomainParameters::new();
    fs::write(
        output.join("fixed_config.json"),
        serde_json::to_vec_pretty(&json!({
            "version": 1,
            "traceSize": mnt4_merkle_deep_fri_backend::config::TRACE_SIZE,
            "ldeSize": mnt4_merkle_deep_fri_backend::config::LDE_SIZE,
            "blowup": mnt4_merkle_deep_fri_backend::config::BLOWUP,
            "configDigest": serialize::hex0x(&fixed.config_digest),
            "rootFixed": serialize::hex0x(&fixed.root_fixed),
            "omega": serialize::hex0x(&serialize::fq_bytes(params.omega)),
            "eta": serialize::hex0x(&serialize::fq_bytes(params.eta)),
            "gamma": serialize::hex0x(&serialize::fq_bytes(params.gamma)),
            "q": serialize::hex0x(&serialize::g2_bytes(fixture.q)),
            "s": serialize::hex0x(&serialize::g2_bytes(fixture.s)),
        }))?,
    )?;
    fs::write(
        output.join("proof_debug.json"),
        serde_json::to_vec_pretty(&json!({
            "profile": profile.name(),
            "proofBytes": proof.len(),
            "rootTrace": serialize::hex0x(&bundle.proof.root_trace),
            "rootQuotient": serialize::hex0x(&bundle.proof.root_quotient),
            "rootDeep": serialize::hex0x(&bundle.proof.root_deep),
            "rootFri": bundle.proof.root_fri.map(|root| serialize::hex0x(&root)),
            "traceOpenings": bundle.proof.trace.positions.len(),
            "fixedOpenings": bundle.proof.fixed.positions.len(),
            "quotientOpenings": bundle.proof.quotient.positions.len(),
            "deepOpenings": bundle.proof.deep.positions.len(),
            "friOpenings": bundle.proof.fri.iter().map(|section| section.positions.len()).sum::<usize>(),
        }))?,
    )?;
    let mut solidity_fixture = Vec::new();
    solidity_fixture.extend_from_slice(&bundle.public.config_digest);
    solidity_fixture.extend_from_slice(&bundle.public.root_fixed);
    solidity_fixture.extend_from_slice(&serialize::fq_bytes(params.omega));
    solidity_fixture.extend_from_slice(&serialize::fq_bytes(params.eta));
    solidity_fixture.extend_from_slice(&serialize::fq_bytes(params.gamma));
    solidity_fixture.extend_from_slice(&serialize::g1_bytes(bundle.public.p));
    solidity_fixture.extend_from_slice(&serialize::g1_bytes(bundle.public.r));
    solidity_fixture.extend_from_slice(&serialize::fq4_bytes(bundle.public.c));
    solidity_fixture.extend_from_slice(&serialize::fq4_bytes(bundle.public.c_inv));
    fs::write(output.join("solidity_fixture.hex"), serialize::hex0x(&solidity_fixture))?;
    println!("{}", serde_json::to_string_pretty(&json!({
        "profile": profile.name(),
        "provingMs": proving_ms,
        "proofBytes": proof.len(),
        "worstCaseCalldataGas": 16 * (proof.len() + bundle.metrics.public_input_bytes),
        "artifacts": output,
    }))?);
    Ok(())
}

#[cfg(target_os = "macos")]
fn peak_rss_bytes() -> i64 {
    let mut usage = unsafe { std::mem::zeroed::<libc::rusage>() };
    let status = unsafe { libc::getrusage(libc::RUSAGE_SELF, &mut usage) };
    if status == 0 { usage.ru_maxrss } else { -1 }
}

#[cfg(all(unix, not(target_os = "macos")))]
fn peak_rss_bytes() -> i64 {
    let mut usage = unsafe { std::mem::zeroed::<libc::rusage>() };
    let status = unsafe { libc::getrusage(libc::RUSAGE_SELF, &mut usage) };
    if status == 0 { usage.ru_maxrss * 1024 } else { -1 }
}

#[cfg(not(unix))]
fn peak_rss_bytes() -> i64 {
    -1
}
