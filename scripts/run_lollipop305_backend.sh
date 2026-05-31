#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_lib.sh"
run_and_capture implementations/lollipop305/rust_backend cargo test --release
log="$REPORT_DIR/implementations__lollipop305__rust_backend.log"
print_pass_summary "$log"
run_and_capture implementations/lollipop305/rust_reference cargo test --release
log_ref="$REPORT_DIR/implementations__lollipop305__rust_reference.log"
print_pass_summary "$log_ref"
