#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_lib.sh"
run_and_capture mnt_cycle_full cargo test --release
log="$REPORT_DIR/mnt_cycle_full.log"
print_pass_summary "$log"
