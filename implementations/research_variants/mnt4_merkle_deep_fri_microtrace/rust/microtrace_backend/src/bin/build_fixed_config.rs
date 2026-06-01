use anyhow::{Context, Result};
use mnt4_merkle_deep_fri_backend::{
    config,
    deep_fri,
    polynomial::DomainParameters,
    serialize,
    trace::Fixture,
};
use serde_json::json;
use std::{env, fs, path::PathBuf};

/// Builds the reusable fixed table for the selected Q,S fixture without
/// constructing a proof. The binary is intentionally separate from
/// `prove_fixture`: it lets reviewers reproduce ROOT_FIXED independently.
fn main() -> Result<()> {
    let output = PathBuf::from(env::args().nth(1).unwrap_or_else(|| "artifacts/fixed".to_owned()));
    fs::create_dir_all(&output).with_context(|| format!("create {}", output.display()))?;
    let fixture = Fixture::non_degenerate();
    let fixed = deep_fri::fixed_artifacts(&fixture)?;
    let params = DomainParameters::new();
    fs::write(output.join("fixed_table_h.bin"), serialize::column_table_bytes(&fixed.h_columns))?;
    fs::write(output.join("fixed_table_lde.bin"), serialize::column_table_bytes(&fixed.lde_columns))?;
    fs::write(output.join("root_fixed.hex"), serialize::hex0x(&fixed.root_fixed))?;
    fs::write(
        output.join("fixed_config.json"),
        serde_json::to_vec_pretty(&json!({
            "version": config::VERSION,
            "traceSize": config::TRACE_SIZE,
            "ldeSize": config::LDE_SIZE,
            "blowup": config::BLOWUP,
            "configDigest": serialize::hex0x(&fixed.config_digest),
            "rootFixed": serialize::hex0x(&fixed.root_fixed),
            "omega": serialize::hex0x(&serialize::fq_bytes(params.omega)),
            "eta": serialize::hex0x(&serialize::fq_bytes(params.eta)),
            "gamma": serialize::hex0x(&serialize::fq_bytes(params.gamma)),
            "q": serialize::hex0x(&serialize::g2_bytes(fixture.q)),
            "s": serialize::hex0x(&serialize::g2_bytes(fixture.s)),
        }))?,
    )?;
    println!("rootFixed={}", serialize::hex0x(&fixed.root_fixed));
    Ok(())
}
