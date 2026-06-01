#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_lib.sh"
run_and_capture implementations/article640_mnt4/rust/article640_backend cargo test --release
log="$REPORT_DIR/implementations__article640_mnt4__rust__article640_backend.log"
print_pass_summary "$log"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT
(cd "$ROOT/implementations/article640_mnt4/rust/article640_backend" && cargo run --release --quiet --bin article640_backend -- "$tmp_dir" >/dev/null)
cmp "$tmp_dir/article640_hot.words.hex" "$ROOT/implementations/article640_mnt4/fixtures/article640_hot.words.hex"
echo "Fixture cross-check: article640_hot.words.hex совпадает с Rust backend."
