#!/usr/bin/env bash
set -euo pipefail

HARDFORK="${1:-prague}"
PORT="${2:-9555}"
RPC="http://127.0.0.1:${PORT}"
KEY="0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"

cleanup() {
  if [[ -n "${ANVIL_PID:-}" ]]; then
    kill "${ANVIL_PID}" >/dev/null 2>&1 || true
    wait "${ANVIL_PID}" >/dev/null 2>&1 || true
  fi
  rm -rf "${TMP}"
}
trap cleanup EXIT

cd "${ROOT}"
anvil --hardfork "${HARDFORK}" --port "${PORT}" --silent >"${TMP}/anvil.log" 2>&1 &
ANVIL_PID=$!

for _ in $(seq 1 50); do
  if cast chain-id --rpc-url "${RPC}" >/dev/null 2>&1; then
    break
  fi
  sleep 0.1
done
cast chain-id --rpc-url "${RPC}" >/dev/null

deploy() {
  local contract="$1"
  forge create --broadcast --rpc-url "${RPC}" --private-key "${KEY}" "${contract}" |
    awk '/Deployed to:/ {print $3}'
}

measure() {
  local address="$1"
  local signature="$2"
  local receipt data hex value
  receipt="$(cast send --rpc-url "${RPC}" --private-key "${KEY}" --gas-limit 20000000 \
    "${address}" "${signature}" --json)"
  data="$(printf '%s' "${receipt}" | jq -r '.logs[1].data')"
  hex="${data#0x}"
  value="$(cast --to-dec "0x${hex:64:64}")"
  printf '%s' "${value}"
}

small="$(deploy 'test/BenchModexpSmall.t.sol:BenchModexpSmall')"
full="$(deploy 'test/BenchModexpFullWidth.t.sol:BenchModexpFullWidth')"
square="$(deploy 'test/BenchModexpSquare.t.sol:BenchModexpSquare')"

printf 'MODEXP 3-limb benchmark, hardfork=%s\n' "${HARDFORK}"
printf '  multiply, small inputs:      %s gas/op\n' "$(measure "${small}" 'test_GasSmall()')"
printf '  multiply, full-width inputs: %s gas/op\n' "$(measure "${full}" 'test_GasFullWidth()')"
printf '  square, full-width input:    %s gas/op\n' "$(measure "${square}" 'test_GasSquareFullWidth()')"
