use anyhow::Result;
use std::{env, fs};

fn main() -> Result<()> {
    let path = env::args().nth(1).unwrap_or_else(|| "artifacts/benchmark-32q/proof.bin".to_owned());
    let proof = fs::read(&path)?;
    anyhow::ensure!(proof.len() >= 3696, "proof is shorter than fixed header");
    anyhow::ensure!(&proof[..4] == b"M4DF", "bad proof magic");
    println!("proof={} bytes={} magic=M4DF", path, proof.len());
    Ok(())
}

