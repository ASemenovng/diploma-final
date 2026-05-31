#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
for s in \
  run_arith_3limb.sh \
  run_arith_mnt6.sh \
  run_arith_2limb.sh \
  run_full_onchain_mnt4.sh \
  run_article640_mnt4.sh \
  run_article640_mnt4_backend.sh \
  run_naive_tate.sh \
  run_lollipop305.sh \
  run_lollipop305_backend.sh \
  run_mnt6_article640.sh \
  run_mnt6_article640_backend.sh \
  run_mnt_cycle.sh; do
  echo
  echo "############################################################"
  echo "Запуск $s"
  echo "############################################################"
  "$ROOT/scripts/$s"
done
