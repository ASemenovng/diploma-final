#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPORT_DIR="$ROOT/.reports"
mkdir -p "$REPORT_DIR"

run_and_capture() {
  local module="$1"; shift
  local logfile="$REPORT_DIR/${module//\//__}.log"
  echo "============================================================"
  echo "Модуль: $module"
  echo "Команда: $*"
  echo "Лог: $logfile"
  echo "============================================================"
  (cd "$ROOT/$module" && "$@") | tee "$logfile"
}

print_gas_rows() {
  local logfile="$1"; shift
  echo
  echo "Ключевые gas-строки:"
  echo "------------------------------------------------------------"
  for pattern in "$@"; do
    local rows
    rows="$(grep -E "\|[[:space:]]*$pattern[[:space:]]*\|" "$logfile" || true)"
    if [[ -n "$rows" ]]; then
      echo "$rows" | sed 's/^/  /'
    else
      echo "  [нет строки] $pattern"
    fi
  done
  echo "------------------------------------------------------------"
}

print_pass_summary() {
  local logfile="$1"
  echo
  echo "Итог тестов:"
  grep -E "Ran [0-9]+ test suite|[0-9]+ tests passed|Suite result: ok|FAILED|failed" "$logfile" | tail -20 | sed 's/^/  /' || true
}
