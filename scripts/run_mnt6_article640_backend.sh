#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_lib.sh"
run_and_capture implementations/article640_mnt6/rust/mnt6_article640_backend cargo test --release
log="$REPORT_DIR/implementations__article640_mnt6__rust__mnt6_article640_backend.log"
print_pass_summary "$log"

tmp_file="$(mktemp)"
trap 'rm -f "$tmp_file"' EXIT
(cd "$ROOT/implementations/article640_mnt6/rust/mnt6_article640_backend" && cargo run --release --quiet --bin gen_fixture >"$tmp_file")
cmp "$tmp_file" "$ROOT/implementations/article640_mnt6/fixtures/mnt6_fixture.json"
echo "Fixture cross-check: mnt6_fixture.json совпадает с Rust backend."
