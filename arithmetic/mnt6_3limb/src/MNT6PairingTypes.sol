// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

/// @notice Типы данных MNT6-753: элементы базового поля, расширений Fq3/Fq6, точки групп и подготовленные коэффициенты линий Миллера.
library MNT6PairingTypes {
    struct Fp {
        uint256 d2;
        uint256 d1;
        uint256 d0;
    }

    struct Fq3 {
        Fp c0;
        Fp c1;
        Fp c2;
    }

    struct Fq6 {
        Fq3 c0;
        Fq3 c1;
    }

    struct G1Point {
        Fp x;
        Fp y;
    }

    struct G2Point {
        Fq3 x;
        Fq3 y;
    }

    enum StepKind {
        Double,
        Add,
        Sub
    }
}
