#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_lib.sh"
run_and_capture implementations/article640_mnt4 forge test --match-path test/MNT4Article640PairingModesGas.t.sol --gas-report -vv
log="$REPORT_DIR/implementations__article640_mnt4.log"
print_gas_rows "$log" \
  "verifyEquationFixedQParametricS" \
  "verifyEquationFixedQParametricSResidue" \
  "verifyEquationFixedQParametricSResidueCodeShards" \
  "verifyEquationResidueCommitted" \
  "verifyEquationResidueCommittedCodeShards" \
  "verifyEquationResidueFixedShards" \
  "pairingFixedQOnchainDigest" \
  "pairingFixedQPreparedSparseBlobDigest" \
  "pairingFixedQPreparedSparseCodeShardsDigest"
print_pass_summary "$log"
