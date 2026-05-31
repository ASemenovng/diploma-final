#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_lib.sh"
run_and_capture arithmetic/mnt6_3limb forge test --match-path test/MNT6FieldGasBench.t.sol --gas-report -vv
log="$REPORT_DIR/arithmetic__mnt6_3limb.log"
print_gas_rows "$log" "fq3Mul" "fq3Sqr" "fq6Mul" "fq6Sqr"
print_pass_summary "$log"
