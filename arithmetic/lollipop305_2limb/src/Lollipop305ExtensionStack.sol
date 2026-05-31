// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import "./BigIntLollipop305.sol";

/// @notice Ориентированная на стек арифметика расширений Fp2/Fp4 для измерений lollipop-305.
/// @dev В наиболее затратных формулах не используются структуры и вложенные объекты памяти:
///      коэффициенты передаются отдельными словами, чтобы сократить копирования.
library Lollipop305ExtensionStack {
    /// @notice Выполняет умножение `fp2Mul`; точный уровень поля и специальный множитель отражены в названии.
    function fp2Mul(
        uint256 a00, uint256 a01, uint256 a10, uint256 a11,
        uint256 b00, uint256 b01, uint256 b10, uint256 b11
    ) internal pure returns (uint256 c00, uint256 c01, uint256 c10, uint256 c11) {
        (uint256 sA0, uint256 sA1) = BigIntLollipop305.add2(a00, a01, a10, a11);
        (uint256 sB0, uint256 sB1) = BigIntLollipop305.add2(b00, b01, b10, b11);
        (uint256 v00, uint256 v01) = BigIntLollipop305.montMul2(a00, a01, b00, b01);
        (uint256 v10, uint256 v11) = BigIntLollipop305.montMul2(a10, a11, b10, b11);
        (uint256 v20, uint256 v21) = BigIntLollipop305.montMul2(sA0, sA1, sB0, sB1);
        (c00, c01) = BigIntLollipop305.sub2(v00, v01, v10, v11);
        (uint256 sum0, uint256 sum1) = BigIntLollipop305.add2(v00, v01, v10, v11);
        (c10, c11) = BigIntLollipop305.sub2(v20, v21, sum0, sum1);
    }

    /// @notice Возводит значение в квадрат: `fp2Sqr`.
    function fp2Sqr(
        uint256 a00, uint256 a01, uint256 a10, uint256 a11
    ) internal pure returns (uint256 c00, uint256 c01, uint256 c10, uint256 c11) {
        (uint256 v00, uint256 v01) = BigIntLollipop305.montSqr2(a00, a01);
        (uint256 v10, uint256 v11) = BigIntLollipop305.montSqr2(a10, a11);
        (uint256 v20, uint256 v21) = BigIntLollipop305.montMul2(a00, a01, a10, a11);
        (c00, c01) = BigIntLollipop305.sub2(v00, v01, v10, v11);
        (c10, c11) = BigIntLollipop305.add2(v20, v21, v20, v21);
    }

    /// @notice Выполняет умножение `fp2MulByU`; точный уровень поля и специальный множитель отражены в названии.
    function fp2MulByU(
        uint256 a00, uint256 a01, uint256 a10, uint256 a11
    ) internal pure returns (uint256 c00, uint256 c01, uint256 c10, uint256 c11) {
        (c00, c01) = BigIntLollipop305.neg2(a10, a11);
        c10 = a00;
        c11 = a01;
    }

    /// @notice Выполняет умножение `fp2MulByFp4NonResidue`; точный уровень поля и специальный множитель отражены в названии.
    function fp2MulByFp4NonResidue(
        uint256 a00, uint256 a01, uint256 a10, uint256 a11
    ) internal pure returns (uint256 c00, uint256 c01, uint256 c10, uint256 c11) {
        (uint256 u00, uint256 u01, uint256 u10, uint256 u11) = fp2MulByU(a00, a01, a10, a11);
        (c00, c01) = BigIntLollipop305.add2(a00, a01, u00, u01);
        (c10, c11) = BigIntLollipop305.add2(a10, a11, u10, u11);
    }

    /// @notice Выполняет умножение `fp4Mul`; точный уровень поля и специальный множитель отражены в названии.
    function fp4Mul(uint256[8] memory a, uint256[8] memory b) internal pure returns (uint256[8] memory c) {
        uint256[4] memory v0;
        uint256[4] memory v1;
        uint256[4] memory v2;
        uint256[4] memory sA;
        uint256[4] memory sB;
        (sA[0], sA[1]) = BigIntLollipop305.add2(a[0], a[1], a[4], a[5]);
        (sA[2], sA[3]) = BigIntLollipop305.add2(a[2], a[3], a[6], a[7]);
        (sB[0], sB[1]) = BigIntLollipop305.add2(b[0], b[1], b[4], b[5]);
        (sB[2], sB[3]) = BigIntLollipop305.add2(b[2], b[3], b[6], b[7]);

        (v0[0], v0[1], v0[2], v0[3]) = fp2Mul(a[0], a[1], a[2], a[3], b[0], b[1], b[2], b[3]);
        (v1[0], v1[1], v1[2], v1[3]) = fp2Mul(a[4], a[5], a[6], a[7], b[4], b[5], b[6], b[7]);
        (v2[0], v2[1], v2[2], v2[3]) = fp2Mul(sA[0], sA[1], sA[2], sA[3], sB[0], sB[1], sB[2], sB[3]);

        (uint256 xi0, uint256 xi1, uint256 xi2, uint256 xi3) =
            fp2MulByFp4NonResidue(v1[0], v1[1], v1[2], v1[3]);
        (c[0], c[1]) = BigIntLollipop305.add2(v0[0], v0[1], xi0, xi1);
        (c[2], c[3]) = BigIntLollipop305.add2(v0[2], v0[3], xi2, xi3);
        (c[4], c[5]) = BigIntLollipop305.sub2(v2[0], v2[1], v0[0], v0[1]);
        (c[6], c[7]) = BigIntLollipop305.sub2(v2[2], v2[3], v0[2], v0[3]);
        (c[4], c[5]) = BigIntLollipop305.sub2(c[4], c[5], v1[0], v1[1]);
        (c[6], c[7]) = BigIntLollipop305.sub2(c[6], c[7], v1[2], v1[3]);
    }

    /// @notice Возводит значение в квадрат: `fp4Sqr`.
    function fp4Sqr(uint256[8] memory a) internal pure returns (uint256[8] memory c) {
        uint256[4] memory v0;
        uint256[4] memory v1;
        uint256[4] memory cross;
        (v0[0], v0[1], v0[2], v0[3]) = fp2Sqr(a[0], a[1], a[2], a[3]);
        (v1[0], v1[1], v1[2], v1[3]) = fp2Sqr(a[4], a[5], a[6], a[7]);
        (cross[0], cross[1], cross[2], cross[3]) = fp2Mul(a[0], a[1], a[2], a[3], a[4], a[5], a[6], a[7]);
        (uint256 xi0, uint256 xi1, uint256 xi2, uint256 xi3) =
            fp2MulByFp4NonResidue(v1[0], v1[1], v1[2], v1[3]);
        (c[0], c[1]) = BigIntLollipop305.add2(v0[0], v0[1], xi0, xi1);
        (c[2], c[3]) = BigIntLollipop305.add2(v0[2], v0[3], xi2, xi3);
        (c[4], c[5]) = BigIntLollipop305.add2(cross[0], cross[1], cross[0], cross[1]);
        (c[6], c[7]) = BigIntLollipop305.add2(cross[2], cross[3], cross[2], cross[3]);
    }
}
