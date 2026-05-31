# Final Work Requirements and Definition of Done

This document is the source of truth for the final engineering and research target of the MNT4 pairing project.

## 1. Final research goal

The work is not merely a Solidity optimization of MNT4 arithmetic. The final research goal is to show that the bottleneck observed in generic folding systems such as Sonobe/CycleFold can be avoided for the MNT curve setting by preparing a native MNT-cycle relation layer.

The project must implement all preliminary layers needed before the actual folding layer:

1. A full on-chain MNT4 pairing baseline, used to demonstrate practical infeasibility on EVM without MNT precompiles.
2. A Rust off-chain backend that computes MNT4 pairing artifacts without relying on Solidity as an oracle.
3. A compact on-chain verifier contract that checks a proof/claim that an off-chain computed MNT4 pairing result is consistent with the submitted points and auxiliary cache.
4. A strict MNT-native relation layer, or at least a completed pre-folding relation implementation, showing that the future folding layer will not emulate all MNT4 arithmetic inside BN254.
5. A reproducible benchmark suite measuring gas, constraints, and off-chain time.

The actual CycleFold integration is explicitly out of scope for the current work, but the current work must make the next CycleFold step technically justified and measurable.

## 2. Supervisor-facing implementation shape

The final code should be understandable and minimal from the public-contract perspective:

1. One main public contract that can be deployed and called by anyone.
2. Optional helper contracts/libraries for field arithmetic and reference computations.
3. No unnecessary ownership, mutable registry, replay state, expiry policy, or admin-freeze logic in the final public contour unless it is strictly required by the mathematical claim being verified.
4. Parameters may be fixed in the constructor or in immutable code.
5. The contract receives:
   - point or points `P` in the first source group;
   - point `Q` in the second source group;
   - the claimed pairing result or its digest;
   - required cache commitments/artifacts;
   - a proof object.
6. The contract verifies that the proof binds these objects to the claimed MNT4 pairing computation.

The contract must not trust line cache, Miller trace, final exponentiation witness, or other auxiliary data merely because they are submitted by the caller.

## 3. What must be shown scientifically

The final text and code must support the following claims:

1. Direct full on-chain MNT4 pairing is infeasible on EVM without a dedicated MNT precompile.
2. A generic BN254 non-native circuit for MNT4 pairing would reproduce the same bottleneck as emulated-pairing/Sonobe-like approaches.
3. MNT4/MNT6 are relevant because they form a curve cycle:

   `Fr(MNT4) = Fp(MNT6)` and `Fr(MNT6) = Fp(MNT4)`.

   This allows a future folding construction to express the MNT relation in a native or near-native field setting rather than as large non-native BN254 arithmetic.
4. The project implements the pre-folding layer: off-chain MNT4 computation, cache/relation artifacts, compact EVM verification, and MNT-native relation measurements.
5. The project must not claim that a small BN254 verifier-envelope circuit is the full MNT4 pairing proof.

## 4. Required optimizations from the literature

The implementation and text must account for the following ideas:

1. Precomputed / witnessed line coefficients for the Miller loop.
2. Sparse line multiplication in the target extension field.
3. Shared Miller accumulator for multi-pairing.
4. Final exponentiation replacement by residue/relation checks where applicable.
5. Separation between forward computation and cheaper verification of algebraic relations.
6. MNT-cycle-native accounting as the intended route away from BN254 non-native emulation.

The implementation does not need to implement the final folding scheme itself, but it must make clear which parts are already implemented and which parts are measured as relation fragments for the future folding layer.

## 5. Current status after local stages 1-7

Implemented locally on branch `codex/stage3-line-cache-relation` in `/Users/a.i.semenov/mnt4-pairing-final`:

1. Full on-chain baseline and gas report.
2. Rust MNT4 backend producing pairing artifacts.
3. Compact BN254 verifier-envelope for EVM verification.
4. Honest proof-boundary documentation.
5. Line-cache relation artifact.
6. Miller relation artifact.
7. Final exponentiation residue relation artifact.
8. MNT-cycle constraint-accounting crate.
9. Reproducible release summary with gas, constraints, and timing metrics.

Important limitation: the current `mnt_cycle_constraints` crate is an accounting/model layer, not yet a real compiled MNT4/MNT6-native constraint system used by a folding backend.

## 6. Final Definition of Done

The work is complete only when the following are all true:

1. The public Solidity contour remains simple: one main verifier contract plus helper arithmetic/reference libraries.
2. The Rust backend is the only production off-chain computation path; Solidity workers are used only for tests/reference checks.
3. The proof statement is exact and honest:
   - if using BN254, it is described as an EVM-compatible compression/envelope layer;
   - the MNT-native relation layer is separately implemented/measured;
   - no document claims that the BN254 envelope alone proves full MNT4 pairing arithmetic unless it actually does.
4. The line cache is not trusted: there is a relation connecting `Q -> line coefficients -> line commitment`.
5. The Miller computation is not trusted: there is a relation connecting `P, line cache -> Miller accumulator/result`.
6. The final exponentiation is not blindly trusted: there is a residue/relation check or an explicitly measured direct chain alternative.
7. The project contains a reproducible benchmark suite with:
   - full on-chain gas;
   - compact verifier gas;
   - Rust backend time;
   - proof generation time;
   - BN254 envelope constraints;
   - MNT-native relation constraints;
   - comparison anchors against emulated-pairing/Sonobe-like approaches.
8. The dissertation text clearly separates:
   - implemented production-like code;
   - reference/test harnesses;
   - accounting models;
   - future CycleFold integration.

## 7. Remaining gap at the time of writing

The main remaining gap is that the MNT-native relation layer is currently measured as an explicit Rust accounting model, but it is not yet implemented as a real constraint system/gadget layer that can be compiled and used by a future folding backend.

Therefore the current state is a strong pre-folding prototype, but not yet the final defensible form of the claim that cheap MNT-cycle folding is achievable.

## 8. Article640 direct MNT4 verifier experiment

Added locally in `/Users/a.i.semenov/mnt4-pairing-final/article640_mnt4_verifier`:

1. Rust backend based on `ark-mnt4-753` that generates a fixed-Q/fixed-S pairing-equation fixture and checks it against arkworks.
2. Solidity direct verifier `MNT4Article640DirectVerifier` for the equation `e(P,Q)=e(R,S)` with precomputed line caches and a combined Miller loop.
3. Foundry tests for the positive arkworks fixture and negative cases: wrong `P`, wrong `R`, tampered `Q` line, tampered `S` line, wrong line count, and commitment mismatch.
4. Gas report showing that this direct adaptation is correct but not practical in the current EVM arithmetic model:
   - `verifyEquationCore`: about `724M gas`;
   - full `verifyEquation`: about `1.12B gas`;
   - prepared-line hash for one fixed point: about `1.56M gas`.

This experiment should be described as an illustrative implementation of the applicable fixed-line/combined-Miller part of ePrint 2024/640 for MNT4-753, not as a cheap production verifier. Its value is the negative result: without a proof/folding layer, native wide-field support, or radically more optimized 753-bit arithmetic, the direct on-chain verifier remains impractical.
