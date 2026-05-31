# MNT4 native-field optimized Merkle/FRI verifier

## Decision

Implement the transparent verifier without foreign-field arithmetic:

```text
fixed Q,S
-> block-compressed MNT4 multi-Miller relation
-> embedded residue witness
-> randomized Fq4 arithmetic
-> column-wise coefficient evaluation
-> native MNT4-field Merkle/FRI PCS
-> Solidity verifyEquation(P,R,proof)
```

The complete Russian-language specification is:

```text
implementations/mnt4_merkle_fri_block_compressed/docs/
MNT4_NATIVE_FIELD_OPTIMIZED_MERKLE_FRI_SPEC_RU.md
```

## Required properties

1. No BN254 limb/carry AIR and no Groth16.
2. Verify `e(P,Q)e(-R,S)=1` for fixed `Q,S`.
3. Use the exact MNT4 Article640 residue program as the source of truth.
4. Precompute fixed compressed divisors and store them in immutable code
   shards.
5. Keep fixed divisor tape and dynamic witness coefficient tape separate.
6. Use one randomized extension quotient.
7. Use column-wise efficient evaluation.
8. Use one composition oracle and one batched FRI query set.
9. Implement ordinary FRI as the correctness baseline.
10. Add OODS/DEEP-FRI, layer skipping and final polynomial transmission as
    measurable optimizations.
11. Generate a numeric `security_report.json`.
12. Run a Rust stop/go cost model before writing the Solidity verifier.

## Stop/go

Write the Solidity verifier only if the strict Rust profile predicts:

```text
expected_gas < 93,879,746
```

Target:

```text
expected_gas < 60,000,000
```

## Scope boundary

Not included:

- universal `Y = e(P,Q)` API;
- dynamic `Q,S`;
- BN254 proof compression;
- MNT4/MNT6 folding;
- recursive proof compression;
- production audit.

