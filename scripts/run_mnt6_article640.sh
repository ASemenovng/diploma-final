#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_lib.sh"
run_and_capture implementations/article640_mnt6 forge test --gas-report -vv
log="$REPORT_DIR/implementations__article640_mnt6.log"
print_gas_rows "$log" \
  "pairingPreparedPackedFullDigest" \
  "pairingPreparedPackedFullDigestWithPackedFE" \
  "pairingPreparedPackedResidueDigest" \
  "finalExponentiationPackedDigest" \
  "verifyEquationFullFixedShards"
print_pass_summary "$log"
