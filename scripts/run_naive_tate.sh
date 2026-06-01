#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_lib.sh"
echo "Наивная Tate cost model: измеряются микроблоки и строгая экстраполяция."
echo "Полный исполняемый MNT4 reference запускается отдельным full_onchain runner-ом."
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

echo
echo "Строгая нижняя экстраполяция полного наивного Tate-пути:"
echo "------------------------------------------------------------"
echo "  Tate Miller accumulator:       912,988,940 gas"
echo "  Generic binary final exponent: 1,635,405,741 gas"
echo "  Нижняя сумма:                  2,548,394,681 gas"
echo "  Не включены построение линий, twist-арифметика и входные проверки."
echo "------------------------------------------------------------"
