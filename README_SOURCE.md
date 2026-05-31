# MNT4 Pairing Project Export

This export contains only the code needed for the final dissertation implementation.

## Structure

- `onchain_full/` - full Solidity MNT4-753 arithmetic and on-chain pairing baseline with tests.
- `offchain_verify/` - final architecture: Rust off-chain backend, succinct proof fixture, one public on-chain verifier entrypoint, and tests.
- `lib/forge-std/` - Foundry test dependency.

## Verify full on-chain baseline

```bash
cd onchain_full
forge test --offline
```

## Verify off-chain compute / on-chain verify architecture

```bash
cd offchain_verify
forge test --offline
cargo test --offline --manifest-path crates/mnt4_trace_backend/Cargo.toml
```

For the reproducible release pipeline, install `snarkjs` once in `offchain_verify`:

```bash
cd offchain_verify
npm install
python3 script/final_mnt4_pairing_release.py
```

The main public contract for deployment is:

```text
offchain_verify/src/final_mnt4_pairing/MNT4PairingFinal.sol
```

## Current proof-status boundary

The final EVM-facing verifier is intentionally compact. It verifies a BN254 proof because Ethereum has efficient BN254 precompiles, but this does not mean that the current BN254 circuit replays the entire MNT4-753 pairing computation.

The current deployed contour should be read as:

```text
Rust MNT4 backend -> prepared public inputs/artifacts -> compact BN254 proof -> Solidity verifier
```

The BN254 proof binds the submitted statement, result digest and artifact commitments. The expensive MNT4 arithmetic is performed by the Rust backend and checked against arkworks/reference vectors. The next research layer is the MNT-cycle native relation layer, implemented under `offchain_verify/crates/mnt_cycle_constraints`, which measures the relation that should later be folded over the MNT4/MNT6 cycle.

Therefore, the small BN254 circuit size must not be quoted as the cost of a full non-native MNT4 pairing proof. It is the cost of the current EVM-compatible verification envelope.
