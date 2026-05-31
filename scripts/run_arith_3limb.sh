#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_lib.sh"
run_and_capture arithmetic/mnt4_3limb forge test --match-path test/MNT4ArithmeticAlgorithmStudy.t.sol --gas-report -vv
log="$REPORT_DIR/arithmetic__mnt4_3limb.log"
print_gas_rows "$log" \
  "mul3" \
  "sqr3" \
  "squareCombaSqr3" \
  "benchCombaMul3" \
  "benchCombaSqr3" \
  "benchFq2MulProduction" \
  "benchFq2MulLazyC0" \
  "benchFq4MulByVSpecialized" \
  "benchMulBy13Specialized"
print_pass_summary "$log"
