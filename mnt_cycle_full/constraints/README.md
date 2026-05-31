# Cycle-native relation fragments

This directory documents the constraint/accounting side of `mnt_cycle_full`.
The implemented model is intentionally explicit and small:

- one native base-field multiplication is counted as one multiplication constraint;
- additions and equalities are linear constraints and are not counted as multiplication constraints;
- MNT4 uses the `Fq -> Fq2 -> Fq4` tower;
- MNT6 uses the `Fq -> Fq3 -> Fq6` tower;
- sparse line multiplication, one Miller transition, line-cache consistency, and final-exponentiation residue fragments are counted from these tower costs.

This is not a production folding circuit. It is the reproducible model that explains why an MNT4/MNT6-native layer is fundamentally different from moving MNT4 arithmetic into BN254 as non-native arithmetic.
