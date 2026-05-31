// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import "../src/BigIntMNT.sol";
import "../src/MNT4Extension.sol";

/// @notice Экспериментальные варианты арифметики расширений только для сравнения стоимости алгоритмов.
library MNT4ExtensionAlgorithmVariants {
    using MNT4ExtensionFinal for MNT4ExtensionFinal.Fq2;
    using MNT4ExtensionFinal for MNT4ExtensionFinal.Fq4;

    /// @notice Выполняет умножение `_mulBy13Generic`; точный уровень поля и специальный множитель отражены в названии.
    function _mulBy13Generic(uint256 x0, uint256 x1, uint256 x2)
        internal pure returns (uint256 r0, uint256 r1, uint256 r2)
    {
        (uint256 k0, uint256 k1, uint256 k2) = BigIntMNT.toMontgomery3(13, 0, 0);
        return BigIntMNT.montMul3(x0, x1, x2, k0, k1, k2);
    }

    /// @notice Выполняет умножение `mulBy13Generic`; точный уровень поля и специальный множитель отражены в названии.
    function mulBy13Generic(uint256[3] memory x) internal pure returns (uint256[3] memory r) {
        (r[0], r[1], r[2]) = _mulBy13Generic(x[0], x[1], x[2]);
    }

    /// @notice Выполняет умножение `fq2MulByUGeneric`; точный уровень поля и специальный множитель отражены в названии.
    function fq2MulByUGeneric(MNT4ExtensionFinal.Fq2 memory x)
        internal pure returns (MNT4ExtensionFinal.Fq2 memory r)
    {
        MNT4ExtensionFinal.Fq2 memory u;
        u.c1 = BigIntMNT.toMontgomery([uint256(1), uint256(0), uint256(0)]);
        return MNT4ExtensionFinal.fq2Mul(x, u);
    }

    /// @notice Выполняет умножение `fq4MulByVGeneric`; точный уровень поля и специальный множитель отражены в названии.
    function fq4MulByVGeneric(MNT4ExtensionFinal.Fq4 memory x)
        internal pure returns (MNT4ExtensionFinal.Fq4 memory r)
    {
        MNT4ExtensionFinal.Fq4 memory v;
        v.c1.c0 = BigIntMNT.toMontgomery([uint256(1), uint256(0), uint256(0)]);
        return MNT4ExtensionFinal.fq4Mul(x, v);
    }

    /// @dev Same formula as production Fq2 square, but uses non-reducing doubling plus one reduce.
    function fq2SqrLazyDouble(MNT4ExtensionFinal.Fq2 memory a)
        internal pure returns (MNT4ExtensionFinal.Fq2 memory out)
    {
        (uint256 v00, uint256 v01, uint256 v02) = BigIntMNT.montSqr3(a.c0[0], a.c0[1], a.c0[2]);
        (uint256 v10, uint256 v11, uint256 v12) = BigIntMNT.montSqr3(a.c1[0], a.c1[1], a.c1[2]);
        (uint256 bv0, uint256 bv1, uint256 bv2) = BigIntMNT.mulBy13(v10, v11, v12);
        (out.c0[0], out.c0[1], out.c0[2]) = BigIntMNT.add3(v00, v01, v02, bv0, bv1, bv2);

        (uint256 t0, uint256 t1, uint256 t2) = BigIntMNT.montMul3(
            a.c0[0], a.c0[1], a.c0[2], a.c1[0], a.c1[1], a.c1[2]
        );
        (uint256 d0, uint256 d1, uint256 d2) = BigIntMNT.add3NR(t0, t1, t2, t0, t1, t2);
        (out.c1[0], out.c1[1], out.c1[2]) = BigIntMNT.reduce3(d0, d1, d2);
    }

    /// @dev Variant that delays the final c0 reduction after v0 + 13*v1.
    function fq2MulLazyC0(MNT4ExtensionFinal.Fq2 memory a, MNT4ExtensionFinal.Fq2 memory b)
        internal pure returns (MNT4ExtensionFinal.Fq2 memory out)
    {
        (uint256 v00, uint256 v01, uint256 v02) = BigIntMNT.montMul3(
            a.c0[0], a.c0[1], a.c0[2], b.c0[0], b.c0[1], b.c0[2]
        );
        (uint256 v10, uint256 v11, uint256 v12) = BigIntMNT.montMul3(
            a.c1[0], a.c1[1], a.c1[2], b.c1[0], b.c1[1], b.c1[2]
        );
        (uint256 s0, uint256 s1, uint256 s2) = BigIntMNT.add3(v00, v01, v02, v10, v11, v12);

        (uint256 as0, uint256 as1, uint256 as2) = BigIntMNT.add3(a.c0[0], a.c0[1], a.c0[2], a.c1[0], a.c1[1], a.c1[2]);
        (uint256 bs0, uint256 bs1, uint256 bs2) = BigIntMNT.add3(b.c0[0], b.c0[1], b.c0[2], b.c1[0], b.c1[1], b.c1[2]);
        (uint256 v20, uint256 v21, uint256 v22) = BigIntMNT.montMul3(as0, as1, as2, bs0, bs1, bs2);
        (out.c1[0], out.c1[1], out.c1[2]) = BigIntMNT.sub3(v20, v21, v22, s0, s1, s2);

        (uint256 b130, uint256 b131, uint256 b132) = BigIntMNT.mulBy13(v10, v11, v12);
        (uint256 c00, uint256 c01, uint256 c02) = BigIntMNT.add3NR(v00, v01, v02, b130, b131, b132);
        (out.c0[0], out.c0[1], out.c0[2]) = BigIntMNT.reduce3(c00, c01, c02);
    }
}
