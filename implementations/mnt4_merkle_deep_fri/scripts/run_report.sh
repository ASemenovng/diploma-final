#!/usr/bin/env bash
set -euo pipefail

MODULE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BASELINE_DIR="$MODULE_DIR/../article640_mnt4"
RUST_DIR="$MODULE_DIR/rust/microtrace_backend"

echo "== MNT4 Merkle/DEEP-FRI microtrace report =="
echo
echo "[1/5] Rust unit tests"
(cd "$RUST_DIR" && cargo test --release)

echo
echo "[2/5] Rebuild reproducible fixtures"
(cd "$RUST_DIR" && cargo run --release --bin build_fixed_config -- artifacts/fixed-reproducible)
(cd "$RUST_DIR" && cargo run --release --bin prove_fixture -- artifacts/benchmark-32q benchmark-32q)
(cd "$RUST_DIR" && cargo run --release --bin prove_fixture -- artifacts/conservative-128q conservative-128q)

echo
echo "[3/5] Solidity acceptance and rejection tests"
(cd "$MODULE_DIR" && forge test -vv)

echo
echo "[4/5] Isolated gas reports"
(cd "$MODULE_DIR" && forge test --match-test testGas_verifyEquationMicrotraceBenchmark32 --gas-report -vv)
(cd "$MODULE_DIR" && forge test --match-test testGas_verifyEquationMicrotraceConservative128 --gas-report -vv)
(cd "$BASELINE_DIR" && forge test --match-test testGas_article640HotFixedShardsResidueEquation --gas-report -vv)

echo
echo "[5/5] Compact artifact summary"
python3 - "$RUST_DIR" <<'PY'
import json
import pathlib
import sys

root = pathlib.Path(sys.argv[1]) / "artifacts"
baseline_execution = 93_705_233
print(f"{'Profile':<20} {'Proof bytes':>12} {'Calldata gas':>14} {'Proving ms':>12} {'Peak RSS MiB':>14}")
for profile in ("benchmark-32q", "conservative-128q"):
    metrics = json.loads((root / profile / "metrics.json").read_text())
    model = metrics["model"]
    print(
        f"{profile:<20} {metrics['actualProofBytes']:>12,} "
        f"{model['worst_case_calldata_gas']:>14,} {metrics['provingMs']:>12,} "
        f"{metrics['peakRssBytes'] / 1024 / 1024:>14.1f}"
    )
print()
print(f"Article640 fixed-shards execution baseline: {baseline_execution:,} gas")
print("Read the isolated Forge gas-report rows above for verifier execution gas.")
PY
