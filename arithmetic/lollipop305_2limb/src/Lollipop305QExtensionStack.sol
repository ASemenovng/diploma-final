// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import "./BigIntLollipop305Q.sol";

/// @notice Ориентированная на стек арифметика Fq2/Fq6 для q-части суперсингулярного цикла.
/// @dev Расширение задается как Fq2=Fq[eta]/(eta^2+2), поэтому eta^2=-2.
library Lollipop305QExtensionStack {
    /// @dev Константа `RHO_00` фиксирует параметр алгоритма; значение не изменяется во время выполнения.
    uint256 private constant RHO_00 = 0xbca4aad3edb267660749f41c7aed6a6a0716477ec23c131ca61e91ec49395e14;
    /// @dev Константа `RHO_01` фиксирует параметр алгоритма; значение не изменяется во время выполнения.
    uint256 private constant RHO_01 = 0x12e32fd6de0da;
    /// @dev Константа `RHO_10` фиксирует параметр алгоритма; значение не изменяется во время выполнения.
    uint256 private constant RHO_10 = 0x5e525569f6d933b303a4fa0e3d76b535038b23bf611e098e530f48f6249caf0a;
    /// @dev Константа `RHO_11` фиксирует параметр алгоритма; значение не изменяется во время выполнения.
    uint256 private constant RHO_11 = 0x97197eb6f06d;

    /// @notice Выполняет умножение `fq2Mul`; точный уровень поля и специальный множитель отражены в названии.
    function fq2Mul(
        uint256 a00,
        uint256 a01,
        uint256 a10,
        uint256 a11,
        uint256 b00,
        uint256 b01,
        uint256 b10,
        uint256 b11
    ) internal pure returns (uint256 c00, uint256 c01, uint256 c10, uint256 c11) {
        (uint256 sA0, uint256 sA1) = BigIntLollipop305Q.add2(a00, a01, a10, a11);
        (uint256 sB0, uint256 sB1) = BigIntLollipop305Q.add2(b00, b01, b10, b11);
        (uint256 v00, uint256 v01) = BigIntLollipop305Q.montMul2(a00, a01, b00, b01);
        (uint256 v10, uint256 v11) = BigIntLollipop305Q.montMul2(a10, a11, b10, b11);
        (uint256 v20, uint256 v21) = BigIntLollipop305Q.montMul2(sA0, sA1, sB0, sB1);
        (uint256 twoV10, uint256 twoV11) = BigIntLollipop305Q.add2(v10, v11, v10, v11);
        (c00, c01) = BigIntLollipop305Q.sub2(v00, v01, twoV10, twoV11);
        (uint256 sum0, uint256 sum1) = BigIntLollipop305Q.add2(v00, v01, v10, v11);
        (c10, c11) = BigIntLollipop305Q.sub2(v20, v21, sum0, sum1);
    }

    /// @notice Возводит значение в квадрат: `fq2Sqr`.
    function fq2Sqr(uint256 a00, uint256 a01, uint256 a10, uint256 a11)
        internal
        pure
        returns (uint256 c00, uint256 c01, uint256 c10, uint256 c11)
    {
        (uint256 v00, uint256 v01) = BigIntLollipop305Q.montSqr2(a00, a01);
        (uint256 v10, uint256 v11) = BigIntLollipop305Q.montSqr2(a10, a11);
        (uint256 twoV10, uint256 twoV11) = BigIntLollipop305Q.add2(v10, v11, v10, v11);
        (uint256 v20, uint256 v21) = BigIntLollipop305Q.montMul2(a00, a01, a10, a11);
        (c00, c01) = BigIntLollipop305Q.sub2(v00, v01, twoV10, twoV11);
        (c10, c11) = BigIntLollipop305Q.add2(v20, v21, v20, v21);
    }

    /// @notice Выполняет сложение `fq2Add` с учетом модуля или структуры текущего поля.
    function fq2Add(
        uint256 a00,
        uint256 a01,
        uint256 a10,
        uint256 a11,
        uint256 b00,
        uint256 b01,
        uint256 b10,
        uint256 b11
    ) internal pure returns (uint256 c00, uint256 c01, uint256 c10, uint256 c11) {
        (c00, c01) = BigIntLollipop305Q.add2(a00, a01, b00, b01);
        (c10, c11) = BigIntLollipop305Q.add2(a10, a11, b10, b11);
    }

    /// @notice Выполняет вычитание `fq2Sub` с учетом модуля или структуры текущего поля.
    function fq2Sub(
        uint256 a00,
        uint256 a01,
        uint256 a10,
        uint256 a11,
        uint256 b00,
        uint256 b01,
        uint256 b10,
        uint256 b11
    ) internal pure returns (uint256 c00, uint256 c01, uint256 c10, uint256 c11) {
        (c00, c01) = BigIntLollipop305Q.sub2(a00, a01, b00, b01);
        (c10, c11) = BigIntLollipop305Q.sub2(a10, a11, b10, b11);
    }

    /// @notice Выполняет умножение `fq2MulByRho`; точный уровень поля и специальный множитель отражены в названии.
    function fq2MulByRho(uint256 a00, uint256 a01, uint256 a10, uint256 a11)
        internal
        pure
        returns (uint256 c00, uint256 c01, uint256 c10, uint256 c11)
    {
        return fq2Mul(a00, a01, a10, a11, RHO_00, RHO_01, RHO_10, RHO_11);
    }

    /// @dev Fq6 = Fq2[w]/(w^3-rho), encoded as c0 + c1*w + c2*w^2.
    function fq6Mul(uint256[12] memory a, uint256[12] memory b) internal pure returns (uint256[12] memory c) {
        uint256[4] memory v0;
        uint256[4] memory v1;
        uint256[4] memory v2;
        uint256[4] memory t0;
        uint256[4] memory t1;
        uint256[4] memory t2;
        uint256[4] memory rhoT;

        // Умножение Карацубы for c0+c1*w+c2*w^2, w^3=rho:
        // 6 Fq2 умножений и двух умножений на фиксированное rho,
        // вместо 9 Fq2 products of the schoolbook formula.
        (v0[0], v0[1], v0[2], v0[3]) = fq2Mul(a[0], a[1], a[2], a[3], b[0], b[1], b[2], b[3]);
        (v1[0], v1[1], v1[2], v1[3]) = fq2Mul(a[4], a[5], a[6], a[7], b[4], b[5], b[6], b[7]);
        (v2[0], v2[1], v2[2], v2[3]) = fq2Mul(a[8], a[9], a[10], a[11], b[8], b[9], b[10], b[11]);

        uint256[4] memory sA;
        uint256[4] memory sB;
        (sA[0], sA[1], sA[2], sA[3]) = fq2Add(a[4], a[5], a[6], a[7], a[8], a[9], a[10], a[11]);
        (sB[0], sB[1], sB[2], sB[3]) = fq2Add(b[4], b[5], b[6], b[7], b[8], b[9], b[10], b[11]);
        (t0[0], t0[1], t0[2], t0[3]) = fq2Mul(sA[0], sA[1], sA[2], sA[3], sB[0], sB[1], sB[2], sB[3]);
        (t0[0], t0[1], t0[2], t0[3]) = fq2Sub(t0[0], t0[1], t0[2], t0[3], v1[0], v1[1], v1[2], v1[3]);
        (t0[0], t0[1], t0[2], t0[3]) = fq2Sub(t0[0], t0[1], t0[2], t0[3], v2[0], v2[1], v2[2], v2[3]);
        (rhoT[0], rhoT[1], rhoT[2], rhoT[3]) = fq2MulByRho(t0[0], t0[1], t0[2], t0[3]);
        (c[0], c[1], c[2], c[3]) = fq2Add(v0[0], v0[1], v0[2], v0[3], rhoT[0], rhoT[1], rhoT[2], rhoT[3]);

        (sA[0], sA[1], sA[2], sA[3]) = fq2Add(a[0], a[1], a[2], a[3], a[4], a[5], a[6], a[7]);
        (sB[0], sB[1], sB[2], sB[3]) = fq2Add(b[0], b[1], b[2], b[3], b[4], b[5], b[6], b[7]);
        (t1[0], t1[1], t1[2], t1[3]) = fq2Mul(sA[0], sA[1], sA[2], sA[3], sB[0], sB[1], sB[2], sB[3]);
        (t1[0], t1[1], t1[2], t1[3]) = fq2Sub(t1[0], t1[1], t1[2], t1[3], v0[0], v0[1], v0[2], v0[3]);
        (t1[0], t1[1], t1[2], t1[3]) = fq2Sub(t1[0], t1[1], t1[2], t1[3], v1[0], v1[1], v1[2], v1[3]);
        (rhoT[0], rhoT[1], rhoT[2], rhoT[3]) = fq2MulByRho(v2[0], v2[1], v2[2], v2[3]);
        (c[4], c[5], c[6], c[7]) = fq2Add(t1[0], t1[1], t1[2], t1[3], rhoT[0], rhoT[1], rhoT[2], rhoT[3]);

        (sA[0], sA[1], sA[2], sA[3]) = fq2Add(a[0], a[1], a[2], a[3], a[8], a[9], a[10], a[11]);
        (sB[0], sB[1], sB[2], sB[3]) = fq2Add(b[0], b[1], b[2], b[3], b[8], b[9], b[10], b[11]);
        (t2[0], t2[1], t2[2], t2[3]) = fq2Mul(sA[0], sA[1], sA[2], sA[3], sB[0], sB[1], sB[2], sB[3]);
        (t2[0], t2[1], t2[2], t2[3]) = fq2Sub(t2[0], t2[1], t2[2], t2[3], v0[0], v0[1], v0[2], v0[3]);
        (t2[0], t2[1], t2[2], t2[3]) = fq2Add(t2[0], t2[1], t2[2], t2[3], v1[0], v1[1], v1[2], v1[3]);
        (c[8], c[9], c[10], c[11]) = fq2Sub(t2[0], t2[1], t2[2], t2[3], v2[0], v2[1], v2[2], v2[3]);
    }

    /// @notice Возводит значение в квадрат: `fq6Sqr`.
    function fq6Sqr(uint256[12] memory a) internal pure returns (uint256[12] memory c) {
        return fq6SqrSpecialized(a);
    }

    /// @notice Возводит элемент Fq6 в квадрат по отдельной формуле вместо общего умножения.
    /// @dev Для a=a0+a1*w+a2*w^2 и w^3=rho:
    ///      c0=a0^2+2*rho*a1*a2;
    ///      c1=2*a0*a1+rho*a2^2;
    ///      c2=a1^2+2*a0*a2.
    ///      Формула уменьшает число дорогих умножений Fq2 и используется как кандидат
    ///      для горячего Ehat Miller loop после отдельной gas-проверки.
    function fq6SqrSpecialized(uint256[12] memory a) internal pure returns (uint256[12] memory c) {
        uint256[4] memory t0;
        uint256[4] memory t1;
        uint256[4] memory t2;
        uint256[4] memory rhoT;

        // c0 = a0^2 + 2*rho*a1*a2.
        (t0[0], t0[1], t0[2], t0[3]) = fq2Sqr(a[0], a[1], a[2], a[3]);
        (t1[0], t1[1], t1[2], t1[3]) = fq2Mul(a[4], a[5], a[6], a[7], a[8], a[9], a[10], a[11]);
        (t1[0], t1[1], t1[2], t1[3]) = fq2Add(t1[0], t1[1], t1[2], t1[3], t1[0], t1[1], t1[2], t1[3]);
        (rhoT[0], rhoT[1], rhoT[2], rhoT[3]) = fq2MulByRho(t1[0], t1[1], t1[2], t1[3]);
        (c[0], c[1], c[2], c[3]) = fq2Add(t0[0], t0[1], t0[2], t0[3], rhoT[0], rhoT[1], rhoT[2], rhoT[3]);

        // c1 = 2*a0*a1 + rho*a2^2.
        (t0[0], t0[1], t0[2], t0[3]) = fq2Mul(a[0], a[1], a[2], a[3], a[4], a[5], a[6], a[7]);
        (t0[0], t0[1], t0[2], t0[3]) = fq2Add(t0[0], t0[1], t0[2], t0[3], t0[0], t0[1], t0[2], t0[3]);
        (t2[0], t2[1], t2[2], t2[3]) = fq2Sqr(a[8], a[9], a[10], a[11]);
        (rhoT[0], rhoT[1], rhoT[2], rhoT[3]) = fq2MulByRho(t2[0], t2[1], t2[2], t2[3]);
        (c[4], c[5], c[6], c[7]) = fq2Add(t0[0], t0[1], t0[2], t0[3], rhoT[0], rhoT[1], rhoT[2], rhoT[3]);

        // c2 = a1^2 + 2*a0*a2.
        (t0[0], t0[1], t0[2], t0[3]) = fq2Sqr(a[4], a[5], a[6], a[7]);
        (t1[0], t1[1], t1[2], t1[3]) = fq2Mul(a[0], a[1], a[2], a[3], a[8], a[9], a[10], a[11]);
        (t1[0], t1[1], t1[2], t1[3]) = fq2Add(t1[0], t1[1], t1[2], t1[3], t1[0], t1[1], t1[2], t1[3]);
        (c[8], c[9], c[10], c[11]) = fq2Add(t0[0], t0[1], t0[2], t0[3], t1[0], t1[1], t1[2], t1[3]);
    }

    /// @notice Выполняет умножение `fq6MulBy01`; точный уровень поля и специальный множитель отражены в названии.
    function fq6MulBy01(uint256[12] memory a, uint256[4] memory b0, uint256[4] memory b1)
        internal
        pure
        returns (uint256[12] memory c)
    {
        uint256[4] memory t0;
        uint256[4] memory t1;
        uint256[4] memory rhoT;

        // (a0 + a1*w + a2*w^2) * (b0 + b1*w), w^3=rho.
        (t0[0], t0[1], t0[2], t0[3]) = fq2Mul(a[0], a[1], a[2], a[3], b0[0], b0[1], b0[2], b0[3]);
        (t1[0], t1[1], t1[2], t1[3]) = fq2Mul(a[8], a[9], a[10], a[11], b1[0], b1[1], b1[2], b1[3]);
        (rhoT[0], rhoT[1], rhoT[2], rhoT[3]) = fq2MulByRho(t1[0], t1[1], t1[2], t1[3]);
        (c[0], c[1], c[2], c[3]) = fq2Add(t0[0], t0[1], t0[2], t0[3], rhoT[0], rhoT[1], rhoT[2], rhoT[3]);

        (t0[0], t0[1], t0[2], t0[3]) = fq2Mul(a[0], a[1], a[2], a[3], b1[0], b1[1], b1[2], b1[3]);
        (t1[0], t1[1], t1[2], t1[3]) = fq2Mul(a[4], a[5], a[6], a[7], b0[0], b0[1], b0[2], b0[3]);
        (c[4], c[5], c[6], c[7]) = fq2Add(t0[0], t0[1], t0[2], t0[3], t1[0], t1[1], t1[2], t1[3]);

        (t0[0], t0[1], t0[2], t0[3]) = fq2Mul(a[4], a[5], a[6], a[7], b1[0], b1[1], b1[2], b1[3]);
        (t1[0], t1[1], t1[2], t1[3]) = fq2Mul(a[8], a[9], a[10], a[11], b0[0], b0[1], b0[2], b0[3]);
        (c[8], c[9], c[10], c[11]) = fq2Add(t0[0], t0[1], t0[2], t0[3], t1[0], t1[1], t1[2], t1[3]);
    }

    /// @notice Выполняет умножение `fq6MulBy02`; точный уровень поля и специальный множитель отражены в названии.
    function fq6MulBy02(uint256[12] memory a, uint256[4] memory b0, uint256[4] memory b2)
        internal
        pure
        returns (uint256[12] memory c)
    {
        uint256[4] memory t0;
        uint256[4] memory t1;
        uint256[4] memory rhoT;

        // (a0 + a1*w + a2*w^2) * (b0 + b2*w^2), w^3=rho.
        (t0[0], t0[1], t0[2], t0[3]) = fq2Mul(a[0], a[1], a[2], a[3], b0[0], b0[1], b0[2], b0[3]);
        (t1[0], t1[1], t1[2], t1[3]) = fq2Mul(a[4], a[5], a[6], a[7], b2[0], b2[1], b2[2], b2[3]);
        (rhoT[0], rhoT[1], rhoT[2], rhoT[3]) = fq2MulByRho(t1[0], t1[1], t1[2], t1[3]);
        (c[0], c[1], c[2], c[3]) = fq2Add(t0[0], t0[1], t0[2], t0[3], rhoT[0], rhoT[1], rhoT[2], rhoT[3]);

        (t0[0], t0[1], t0[2], t0[3]) = fq2Mul(a[4], a[5], a[6], a[7], b0[0], b0[1], b0[2], b0[3]);
        (t1[0], t1[1], t1[2], t1[3]) = fq2Mul(a[8], a[9], a[10], a[11], b2[0], b2[1], b2[2], b2[3]);
        (rhoT[0], rhoT[1], rhoT[2], rhoT[3]) = fq2MulByRho(t1[0], t1[1], t1[2], t1[3]);
        (c[4], c[5], c[6], c[7]) = fq2Add(t0[0], t0[1], t0[2], t0[3], rhoT[0], rhoT[1], rhoT[2], rhoT[3]);

        (t0[0], t0[1], t0[2], t0[3]) = fq2Mul(a[0], a[1], a[2], a[3], b2[0], b2[1], b2[2], b2[3]);
        (t1[0], t1[1], t1[2], t1[3]) = fq2Mul(a[8], a[9], a[10], a[11], b0[0], b0[1], b0[2], b0[3]);
        (c[8], c[9], c[10], c[11]) = fq2Add(t0[0], t0[1], t0[2], t0[3], t1[0], t1[1], t1[2], t1[3]);
    }
}
