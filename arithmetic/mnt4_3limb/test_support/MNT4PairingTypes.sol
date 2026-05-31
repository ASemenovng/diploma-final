// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

/// @notice ABI-level data types for the strict MNT4-753 pairing witness verifier.
/// @dev Fp limbs are exposed in big-endian order: value = d2*2^512 + d1*2^256 + d0.
library MNT4PairingTypes {
    struct Fp {
        uint256 d2;
        uint256 d1;
        uint256 d0;
    }

    struct Fq2 {
        Fp c0;
        Fp c1;
    }

    struct Fq4 {
        Fq2 c0;
        Fq2 c1;
    }

    struct G1Point {
        Fp x;
        Fp y;
    }

    struct G2Point {
        Fq2 x;
        Fq2 y;
    }

    enum StepKind {
        Double,
        Add,
        Sub
    }

    /// @notice Unnormalised slope data: lambda = lambda_num / lambda_den.
    /// @dev The verifier never trusts a pre-divided slope; all checks use cross-multiplication.
    struct LineCoeffs {
        Fq2 lambda_num;
        Fq2 lambda_den;
    }

    struct MillerStep {
        StepKind kind;
        G2Point tBefore;
        G2Point tAfter;
        LineCoeffs line;
        Fq4 lineEval;
        Fq4 fBefore;
        Fq4 fAfter;
    }

    struct FinalExpWitness {
        Fq4 fMiller;
        Fq4 g;
        Fq4 gAbsT;
    }

    struct PairingWitness {
        G1Point P;
        G2Point Q;
        Fq4 claimedY;
        MillerStep[] millerSteps;
        FinalExpWitness finalExp;
    }
}
