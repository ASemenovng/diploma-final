// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import "../src/BigIntLollipop305.sol";

/// @notice Арифметика башни расширений для сравнительных измерений lollipop-305.
/// @dev Башня: Fp2=Fp[u]/(u^2+1), Fp4=Fp2[v]/(v^2-(1+u)).
library Lollipop305Extension {
    struct Fp2 { uint256[2] c0; uint256[2] c1; }
    struct Fp4 { Fp2 c0; Fp2 c1; }

    /// @notice Выполняет внутреннюю операцию `fpFromRaw`; параметры и результат используют представление текущей библиотеки.
    function fpFromRaw(uint256 x0, uint256 x1) internal pure returns (uint256[2] memory r) {
        (r[0], r[1]) = BigIntLollipop305.toMontgomery2(x0, x1);
    }

    /// @notice Выполняет внутреннюю операцию `fp2FromRaw`; параметры и результат используют представление текущей библиотеки.
    function fp2FromRaw(uint256 a0, uint256 a1) internal pure returns (Fp2 memory r) {
        r.c0 = fpFromRaw(a0, 0);
        r.c1 = fpFromRaw(a1, 0);
    }

    /// @notice Выполняет внутреннюю операцию `fp4FromRaw`; параметры и результат используют представление текущей библиотеки.
    function fp4FromRaw(uint256 a0, uint256 a1, uint256 b0, uint256 b1) internal pure returns (Fp4 memory r) {
        r.c0 = fp2FromRaw(a0, a1);
        r.c1 = fp2FromRaw(b0, b1);
    }

    /// @notice Сравнивает два значения без изменения входных данных: `eqFp`.
    function eqFp(uint256[2] memory a, uint256[2] memory b) internal pure returns (bool) {
        return a[0] == b[0] && a[1] == b[1];
    }

    /// @notice Сравнивает два значения без изменения входных данных: `eqFp2`.
    function eqFp2(Fp2 memory a, Fp2 memory b) internal pure returns (bool) {
        return eqFp(a.c0, b.c0) && eqFp(a.c1, b.c1);
    }

    /// @notice Сравнивает два значения без изменения входных данных: `eqFp4`.
    function eqFp4(Fp4 memory a, Fp4 memory b) internal pure returns (bool) {
        return eqFp2(a.c0, b.c0) && eqFp2(a.c1, b.c1);
    }

    /// @notice Выполняет сложение `fpAdd` с учетом модуля или структуры текущего поля.
    function fpAdd(uint256[2] memory a, uint256[2] memory b) internal pure returns (uint256[2] memory r) {
        (r[0], r[1]) = BigIntLollipop305.add2(a[0], a[1], b[0], b[1]);
    }

    /// @notice Выполняет вычитание `fpSub` с учетом модуля или структуры текущего поля.
    function fpSub(uint256[2] memory a, uint256[2] memory b) internal pure returns (uint256[2] memory r) {
        (r[0], r[1]) = BigIntLollipop305.sub2(a[0], a[1], b[0], b[1]);
    }

    /// @notice Вычисляет аддитивно обратное значение: `fpNeg`.
    function fpNeg(uint256[2] memory a) internal pure returns (uint256[2] memory r) {
        (r[0], r[1]) = BigIntLollipop305.neg2(a[0], a[1]);
    }

    /// @notice Выполняет умножение `fpMul`; точный уровень поля и специальный множитель отражены в названии.
    function fpMul(uint256[2] memory a, uint256[2] memory b) internal pure returns (uint256[2] memory r) {
        (r[0], r[1]) = BigIntLollipop305.montMul2(a[0], a[1], b[0], b[1]);
    }

    /// @notice Возводит значение в квадрат: `fpSqr`.
    function fpSqr(uint256[2] memory a) internal pure returns (uint256[2] memory r) {
        (r[0], r[1]) = BigIntLollipop305.montSqr2(a[0], a[1]);
    }

    /// @notice Выполняет сложение `fp2AddTo` с учетом модуля или структуры текущего поля.
    function fp2AddTo(Fp2 memory out, Fp2 memory a, Fp2 memory b) internal pure {
        out.c0 = fpAdd(a.c0, b.c0);
        out.c1 = fpAdd(a.c1, b.c1);
    }

    /// @notice Выполняет вычитание `fp2SubTo` с учетом модуля или структуры текущего поля.
    function fp2SubTo(Fp2 memory out, Fp2 memory a, Fp2 memory b) internal pure {
        out.c0 = fpSub(a.c0, b.c0);
        out.c1 = fpSub(a.c1, b.c1);
    }

    /// @notice Вычисляет аддитивно обратное значение: `fp2NegTo`.
    function fp2NegTo(Fp2 memory out, Fp2 memory a) internal pure {
        out.c0 = fpNeg(a.c0);
        out.c1 = fpNeg(a.c1);
    }

    /// @dev Fp2 multiplication with u^2 = -1: 3 Fp multiplications.
    function fp2MulTo(Fp2 memory out, Fp2 memory a, Fp2 memory b) internal pure {
        uint256[2] memory sA = fpAdd(a.c0, a.c1);
        uint256[2] memory sB = fpAdd(b.c0, b.c1);
        uint256[2] memory v0 = fpMul(a.c0, b.c0);
        uint256[2] memory v1 = fpMul(a.c1, b.c1);
        uint256[2] memory v2 = fpMul(sA, sB);
        out.c0 = fpSub(v0, v1);
        out.c1 = fpSub(v2, fpAdd(v0, v1));
    }

    /// @notice Возводит значение в квадрат: `fp2SqrTo`.
    function fp2SqrTo(Fp2 memory out, Fp2 memory a) internal pure {
        uint256[2] memory v0 = fpSqr(a.c0);
        uint256[2] memory v1 = fpSqr(a.c1);
        uint256[2] memory v01 = fpMul(a.c0, a.c1);
        out.c0 = fpSub(v0, v1);
        out.c1 = fpAdd(v01, v01);
    }

    /// @dev Multiply by u in Fp2, where u^2=-1: u*(a0+a1*u) = -a1 + a0*u.
    function fp2MulByUTo(Fp2 memory out, Fp2 memory a) internal pure {
        out.c0 = fpNeg(a.c1);
        out.c1 = a.c0;
    }

    /// @dev Multiply by xi = 1+u in Fp2.
    function fp2MulByFp4NonResidueTo(Fp2 memory out, Fp2 memory a) internal pure {
        Fp2 memory ua;
        fp2MulByUTo(ua, a);
        fp2AddTo(out, a, ua);
    }

    /// @notice Выполняет сложение `fp4AddTo` с учетом модуля или структуры текущего поля.
    function fp4AddTo(Fp4 memory out, Fp4 memory a, Fp4 memory b) internal pure {
        fp2AddTo(out.c0, a.c0, b.c0);
        fp2AddTo(out.c1, a.c1, b.c1);
    }

    /// @notice Выполняет вычитание `fp4SubTo` с учетом модуля или структуры текущего поля.
    function fp4SubTo(Fp4 memory out, Fp4 memory a, Fp4 memory b) internal pure {
        fp2SubTo(out.c0, a.c0, b.c0);
        fp2SubTo(out.c1, a.c1, b.c1);
    }

    /// @dev Fp4 multiplication with v^2 = xi = 1+u: 3 Fp2 multiplications.
    function fp4MulTo(Fp4 memory out, Fp4 memory a, Fp4 memory b) internal pure {
        Fp2 memory sA;
        Fp2 memory sB;
        Fp2 memory v0;
        Fp2 memory v1;
        Fp2 memory v2;
        Fp2 memory xiV1;
        fp2AddTo(sA, a.c0, a.c1);
        fp2AddTo(sB, b.c0, b.c1);
        fp2MulTo(v0, a.c0, b.c0);
        fp2MulTo(v1, a.c1, b.c1);
        fp2MulTo(v2, sA, sB);
        fp2MulByFp4NonResidueTo(xiV1, v1);
        fp2AddTo(out.c0, v0, xiV1);
        fp2SubTo(out.c1, v2, v0);
        fp2SubTo(out.c1, out.c1, v1);
    }

    /// @notice Возводит значение в квадрат: `fp4SqrTo`.
    function fp4SqrTo(Fp4 memory out, Fp4 memory a) internal pure {
        Fp2 memory v0;
        Fp2 memory v1;
        Fp2 memory two;
        Fp2 memory xiV1;
        fp2SqrTo(v0, a.c0);
        fp2SqrTo(v1, a.c1);
        fp2MulTo(two, a.c0, a.c1);
        fp2AddTo(two, two, two);
        fp2MulByFp4NonResidueTo(xiV1, v1);
        fp2AddTo(out.c0, v0, xiV1);
        out.c1 = two;
    }
}
