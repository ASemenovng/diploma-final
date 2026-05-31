#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_lib.sh"
run_and_capture baselines/naive_tate_mnt4 forge test --gas-report -vv
log="$REPORT_DIR/baselines__naive_tate_mnt4.log"
print_gas_rows "$log" \
  "fpMul" \
  "fq2Mul" \
  "fq4Mul" \
  "naiveMillerStep" \
  "benchNaiveMillerSteps" \
  "benchNaiveFinalExponentiationChunk16"
print_pass_summary "$log"
