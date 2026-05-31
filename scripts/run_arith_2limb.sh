#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_lib.sh"
log="$REPORT_DIR/arithmetic__lollipop305_2limb.log"
: > "$log"
echo "============================================================" | tee -a "$log"
echo "Модуль: arithmetic/lollipop305_2limb" | tee -a "$log"
echo "Команды: базовая 2-limb арифметика + Fp2/Fp4 оптимизации" | tee -a "$log"
echo "Лог: $log" | tee -a "$log"
echo "============================================================" | tee -a "$log"
(
  cd "$ROOT/arithmetic/lollipop305_2limb"
  forge test --match-path test/Lollipop305Arithmetic.t.sol --gas-report -vv
  forge test --match-path test/Lollipop305F2Optimization.t.sol --gas-report -vv
) | tee -a "$log"
print_gas_rows "$log" \
  "benchFpMul" \
  "benchFpSqr" \
  "benchFp2Mul" \
  "benchFp2Sqr" \
  "benchFp4Mul" \
  "benchFp4Sqr" \
  "benchFp2MulStack" \
  "benchFp4MulFullStack"
print_pass_summary "$log"
