#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_lib.sh"
run_and_capture implementations/article640_mnt6/rust/mnt6_article640_backend cargo test --release
log="$REPORT_DIR/implementations__article640_mnt6__rust__mnt6_article640_backend.log"
print_pass_summary "$log"
