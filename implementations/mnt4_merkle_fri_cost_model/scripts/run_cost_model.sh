#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODULE_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

cd "${MODULE_DIR}/rust/native_fri_cost_model"
cargo run --release

printf '\nОтчеты:\n'
printf '  JSON: %s\n' "${MODULE_DIR}/artifacts/native-field-cost-model/report.json"
printf '  Markdown: %s\n' "${MODULE_DIR}/docs/N1_NATIVE_FIELD_COST_MODEL_RESULTS_RU.md"
