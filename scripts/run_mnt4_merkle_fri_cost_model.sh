#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "============================================================"
echo "Модуль: implementations/mnt4_merkle_fri_cost_model"
echo "Назначение: актуальная ordinary-FRI модель стоимости."
echo "============================================================"
"$ROOT/implementations/mnt4_merkle_fri_cost_model/scripts/run_cost_model.sh"
