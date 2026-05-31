#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_lib.sh"
run_and_capture implementations/article640_mnt4/rust/article640_backend cargo test --release
log="$REPORT_DIR/implementations__article640_mnt4__rust__article640_backend.log"
print_pass_summary "$log"
