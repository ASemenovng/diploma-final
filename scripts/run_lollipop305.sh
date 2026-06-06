#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_lib.sh"
run_and_capture implementations/lollipop305 forge test --gas-report -vv
log="$REPORT_DIR/implementations__lollipop305.log"
print_gas_rows "$log" \
  "verifyMillerCore" \
  "verifyResidue" \
  "verifyDirectFinalExponent" \
  "verifyCycleEResidue" \
  "verifyEhatAteResidue" \
  "verifyEhatAteResidueProductFrobenius" \
  "verifyEhatWeilEquation" \
  "verifyStickResidueCommitted" \
  "verifyCycleEResidueCommitted" \
  "verifyEhatAteResidueCommitted" \
  "verifyStickResidueFixedShards" \
  "verifyCycleEResidueFixedShards" \
  "verifyEhatAteResidueFixedShards" \
  "verifyEhatAteResidueProductFrobeniusFixedShards"
print_pass_summary "$log"
