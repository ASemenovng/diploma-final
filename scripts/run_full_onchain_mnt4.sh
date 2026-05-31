#!/usr/bin/env bash
set -euo pipefail
source "$(dirname "$0")/_lib.sh"
run_and_capture implementations/full_onchain_mnt4 forge test --match-path test/MNT4TatePairingV4.t.sol --match-test 'testCodeShards|testGasBench_pairing_fixedQ_onchain_digest_probe|testGasBench_pairing_fixedQ_prepared_sparse_code_shards_digest_probe' --gas-report -vv
log="$REPORT_DIR/implementations__full_onchain_mnt4.log"
print_gas_rows "$log" \
  "benchPairingFixedQOnchainDigest" \
  "benchPairingFixedQPreparedSparseCodeShardsDigest" \
  "tatePairingFixedQPreparedSparseCodeShardsMemDigestWithShards" \
  "tatePairingFixedQPreparedSparseMemDigestWithBlobs"
print_pass_summary "$log"
