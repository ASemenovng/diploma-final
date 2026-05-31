// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import "./BigIntMNT.sol";

/// @notice Указательный API для эффективных вычислений в наиболее затратных циклах.
///         Размещение данных в памяти; все коэффициенты записаны в Montgomery-представлении:
///         - Fp   : 3 слова [x0,x1,x2]
///         - Fq2  : 6 слов [c0(3), c1(3)], где u^2 = 13
///         - Fq4  : 12 слов [c0(Fq2=6), c1(Fq2=6)], где v^2 = u
library MNT4Extension {
    /// @dev Константа `WORD` фиксирует параметр алгоритма; значение не изменяется во время выполнения.
    uint256 internal constant WORD = 0x20;

    // -------------------------
    // Вспомогательные функции для указателей
    // -------------------------

    /// @dev Возвращает указатель на данные динамического массива uint256[], пропуская слово длины.
    function ptr(uint256[] memory a) internal pure returns (uint256 p) {
        assembly ("memory-safe") { p := add(a, 0x20) }
    }

    /// @dev Возвращает указатель на первый элемент фиксированного массива uint256[N] в памяти.
    function ptr6(uint256[6] memory a) internal pure returns (uint256 p) {
        assembly ("memory-safe") { p := a }
    }

    /// @notice Выполняет внутреннюю операцию `ptr12`; параметры и результат используют представление текущей библиотеки.
    function ptr12(uint256[12] memory a) internal pure returns (uint256 p) {
        assembly ("memory-safe") { p := a }
    }

    // -------------------------
    // Примитивы Fp через указатели на три слова
    // out/a/b point to 3 consecutive uint256 words
    // -------------------------

    function _fpLoad3(uint256 a) private pure returns (uint256 a0, uint256 a1, uint256 a2) {
        assembly ("memory-safe") {
            a0 := mload(a)
            a1 := mload(add(a, WORD))
            a2 := mload(add(a, mul(2, WORD)))
        }
    }

    /// @notice Записывает подготовленное значение в целевой буфер: `_fpStore3`.
    function _fpStore3(uint256 out, uint256 r0, uint256 r1, uint256 r2) private pure {
        assembly ("memory-safe") {
            mstore(out, r0)
            mstore(add(out, WORD), r1)
            mstore(add(out, mul(2, WORD)), r2)
        }
    }

    /// @notice Выполняет сложение `_fpAddTo` с учетом модуля или структуры текущего поля.
    function _fpAddTo(uint256 out, uint256 a, uint256 b) private pure {
        (uint256 a0, uint256 a1, uint256 a2) = _fpLoad3(a);
        (uint256 b0, uint256 b1, uint256 b2) = _fpLoad3(b);
        (uint256 r0, uint256 r1, uint256 r2) = BigIntMNT.add3(a0,a1,a2, b0,b1,b2);
        _fpStore3(out, r0, r1, r2);
    }

    /// @notice Выполняет сложение `_fpAddNRTo` с учетом модуля или структуры текущего поля.
    function _fpAddNRTo(uint256 out, uint256 a, uint256 b) private pure {
        (uint256 a0, uint256 a1, uint256 a2) = _fpLoad3(a);
        (uint256 b0, uint256 b1, uint256 b2) = _fpLoad3(b);
        (uint256 r0, uint256 r1, uint256 r2) = BigIntMNT.add3NR(a0,a1,a2, b0,b1,b2);
        _fpStore3(out, r0, r1, r2);
    }

    /// @notice Выполняет внутреннюю операцию `_fpReduceTo`; параметры и результат используют представление текущей библиотеки.
    function _fpReduceTo(uint256 out, uint256 a) private pure {
        (uint256 a0, uint256 a1, uint256 a2) = _fpLoad3(a);
        (uint256 r0, uint256 r1, uint256 r2) = BigIntMNT.reduce3(a0, a1, a2);
        _fpStore3(out, r0, r1, r2);
    }

    /// @notice Выполняет вычитание `_fpSubTo` с учетом модуля или структуры текущего поля.
    function _fpSubTo(uint256 out, uint256 a, uint256 b) private pure {
        (uint256 a0, uint256 a1, uint256 a2) = _fpLoad3(a);
        (uint256 b0, uint256 b1, uint256 b2) = _fpLoad3(b);
        (uint256 r0, uint256 r1, uint256 r2) = BigIntMNT.sub3(a0,a1,a2, b0,b1,b2);
        _fpStore3(out, r0, r1, r2);
    }

    /// @notice Выполняет умножение `_fpMulTo`; точный уровень поля и специальный множитель отражены в названии.
    function _fpMulTo(uint256 out, uint256 a, uint256 b) private pure {
        (uint256 a0, uint256 a1, uint256 a2) = _fpLoad3(a);
        (uint256 b0, uint256 b1, uint256 b2) = _fpLoad3(b);
        (uint256 r0, uint256 r1, uint256 r2) = BigIntMNT.montMul3(a0,a1,a2, b0,b1,b2);
        _fpStore3(out, r0, r1, r2);
    }

    /// @notice Возводит значение в квадрат: `_fpSqrTo`.
    function _fpSqrTo(uint256 out, uint256 a) private pure {
        (uint256 a0, uint256 a1, uint256 a2) = _fpLoad3(a);
        (uint256 r0, uint256 r1, uint256 r2) = BigIntMNT.montSqr3(a0,a1,a2);
        _fpStore3(out, r0, r1, r2);
    }

    /// @dev Записывает out = -a mod p; операция корректна для Montgomery-представления.
    function _fpNegTo(uint256 out, uint256 a) private pure {
        (uint256 a0, uint256 a1, uint256 a2) = _fpLoad3(a);
        (uint256 r0, uint256 r1, uint256 r2) = BigIntMNT.sub3(0,0,0, a0,a1,a2);
        _fpStore3(out, r0, r1, r2);
    }

    /// @dev Записывает out = 13*a; операция корректна для Montgomery-представления. tmp не должен пересекаться с a.
    function _fpMulBy13To(uint256 out, uint256 a, uint256 tmp) private pure {
        // Накапливаем значение в [0,16p) и выполняем одну широкую редукцию внутри BigInt.mulBy13.
        tmp; // Аргумент оставлен для совместимости с существующими местами вызова.
        (uint256 a0, uint256 a1, uint256 a2) = _fpLoad3(a);
        (uint256 r0, uint256 r1, uint256 r2) = BigIntMNT.mulBy13(a0, a1, a2);
        _fpStore3(out, r0, r1, r2);
    }

    // -------------------------
    // Указательный API для Fq2
    // Layout: [c0(3 limbs), c1(3 limbs)], u^2 = 13
    // -------------------------

    function fq2AddTo(uint256 out, uint256 a, uint256 b) internal pure {
        _fpAddTo(out, a, b);
        _fpAddTo(out + 3*WORD, a + 3*WORD, b + 3*WORD);
    }

    /// @notice Выполняет сложение `fq2AddNRTo` с учетом модуля или структуры текущего поля.
    function fq2AddNRTo(uint256 out, uint256 a, uint256 b) internal pure {
        _fpAddNRTo(out, a, b);
        _fpAddNRTo(out + 3*WORD, a + 3*WORD, b + 3*WORD);
    }

    /// @notice Выполняет внутреннюю операцию `fq2ReduceTo`; параметры и результат используют представление текущей библиотеки.
    function fq2ReduceTo(uint256 out, uint256 a) internal pure {
        _fpReduceTo(out, a);
        _fpReduceTo(out + 3*WORD, a + 3*WORD);
    }

    /// @notice Выполняет вычитание `fq2SubTo` с учетом модуля или структуры текущего поля.
    function fq2SubTo(uint256 out, uint256 a, uint256 b) internal pure {
        _fpSubTo(out, a, b);
        _fpSubTo(out + 3*WORD, a + 3*WORD, b + 3*WORD);
    }

    /// @notice Вычисляет аддитивно обратное значение: `fq2NegTo`.
    function fq2NegTo(uint256 out, uint256 a) internal pure {
        _fpNegTo(out, a);
        _fpNegTo(out + 3*WORD, a + 3*WORD);
    }

    /// @dev Умножение Fq2: out=a*b. Требуется scratchFq2 размером 18 слов, то есть 6 блоков Fp.
    function fq2MulTo(uint256 out, uint256 a, uint256 b, uint256 scratchFq2) internal pure {
        // Временные блоки по три слова:
        // as:0..2, bs:3..5, v0:6..8, v1:9..11, v2:12..14, s:15..17
        uint256 pAs = scratchFq2;
        uint256 pBs = scratchFq2 + 3*WORD;
        uint256 pV0 = scratchFq2 + 6*WORD;
        uint256 pV1 = scratchFq2 + 9*WORD;
        uint256 pV2 = scratchFq2 + 12*WORD;
        uint256 pS  = scratchFq2 + 15*WORD;

        uint256 a0 = a;
        uint256 a1 = a + 3*WORD;
        uint256 b0 = b;
        uint256 b1 = b + 3*WORD;

        _fpAddTo(pAs, a0, a1); // as
        _fpAddTo(pBs, b0, b1); // bs

        _fpMulTo(pV0, a0, b0);    // v0
        _fpMulTo(pV1, a1, b1);    // v1
        _fpMulTo(pV2, pAs, pBs);  // v2

        _fpAddTo(pS, pV0, pV1);   // s = v0+v1

        // c1 = v2 - s
        _fpSubTo(out + 3*WORD, pV2, pS);

        // c0 = v0 + 13*v1
        _fpMulBy13To(pBs, pV1, pAs); // Повторно используем bs как выходной буфер, а as как временный.
        _fpAddTo(out, pV0, pBs);
    }

    /// @dev Возведение Fq2 в квадрат: out=a^2. Требуется scratchFq2 размером 18 слов.
    function fq2SqrTo(uint256 out, uint256 a, uint256 scratchFq2) internal pure {
        // c0 = a0^2 + 13*a1^2
        // c1 = 2*a0*a1
        uint256 a0 = a;
        uint256 a1 = a + 3*WORD;

        uint256 pT0  = scratchFq2;          // 3 limbs
        uint256 pT1  = scratchFq2 + 3*WORD; // 3 limbs
        uint256 pTmp = scratchFq2 + 6*WORD; // 3 limbs
        uint256 pW   = scratchFq2 + 9*WORD; // 3 limbs

        _fpMulTo(pT0, a0, a1);                 // t0 = a0*a1
        _fpAddTo(out + 3*WORD, pT0, pT0);      // c1 = 2*t0

        _fpSqrTo(pT0, a0);                     // t0 = a0^2
        _fpSqrTo(pT1, a1);                     // t1 = a1^2
        // _fpMulBy13To is not safe for out==a, so write into pTmp.
        _fpMulBy13To(pTmp, pT1, pW);           // tmp = 13*t1

        _fpAddTo(out, pT0, pTmp);              // c0 = t0 + 13*t1
    }

    /// @dev Умножение на u в Fq2: (x0+x1*u)*u=(13*x1)+x0*u.
    /// Требуется scratch6 размером 6 слов. Допускается совпадение out==a.
    function fq2MulByUTo(uint256 out, uint256 a, uint256 scratch6) internal pure {
        uint256 a0 = a;
        uint256 a1 = a + 3*WORD;

        uint256 pSaveA0 = scratch6;          // 3 limbs
        uint256 pTmp    = scratch6 + 3*WORD; // 3 limbs

        // Сохраняем a0 до перезаписи выходного буфера.
        (uint256 s0, uint256 s1, uint256 s2) = _fpLoad3(a0);
        _fpStore3(pSaveA0, s0, s1, s2);

        // out.c0 = 13*a1
        _fpMulBy13To(out, a1, pTmp);

        // out.c1 = saved a0
        (uint256 r0, uint256 r1, uint256 r2) = _fpLoad3(pSaveA0);
        _fpStore3(out + 3*WORD, r0, r1, r2);
    }

    /// @dev Fq2 mul by Fp scalar (3 limbs): out = a*s.
    function fq2MulByFp3To(uint256 out, uint256 a, uint256 sFp3) internal pure {
        _fpMulTo(out, a, sFp3);
        _fpMulTo(out + 3*WORD, a + 3*WORD, sFp3);
    }

    /// @dev Fq2 inverse. Needs scratchFq2 = 18 words.
    /// (a0 + a1*u)^-1 = (a0 - a1*u) / (a0^2 - 13*a1^2)
    function fq2InvTo(uint256 out, uint256 a, uint256 scratchFq2) internal pure {
        uint256 a0 = a;
        uint256 a1 = a + 3*WORD;

        // layout (each 3 limbs):
        // t0:0, t1:3, betaT1:6, d:9, dinv:12, na1:15
        uint256 pT0     = scratchFq2;
        uint256 pT1     = scratchFq2 + 3*WORD;
        uint256 pBetaT1 = scratchFq2 + 6*WORD;
        uint256 pD      = scratchFq2 + 9*WORD;
        uint256 pDInv   = scratchFq2 + 12*WORD;
        uint256 pNA1    = scratchFq2 + 15*WORD;

        _fpSqrTo(pT0, a0); // a0^2
        _fpSqrTo(pT1, a1); // a1^2

        _fpMulBy13To(pBetaT1, pT1, pDInv); // betaT1 = 13*t1, use pDInv as tmp
        _fpSubTo(pD, pT0, pBetaT1);        // d = t0 - betaT1

        // dinv = inv3(d)
        (uint256 d0, uint256 d1, uint256 d2) = _fpLoad3(pD);
        (uint256 i0, uint256 i1, uint256 i2) = BigIntMNT.inv3(d0, d1, d2);
        _fpStore3(pDInv, i0, i1, i2);

        // out.c0 = a0*dinv
        _fpMulTo(out, a0, pDInv);

        // na1 = -a1
        _fpNegTo(pNA1, a1);
        // out.c1 = na1*dinv
        _fpMulTo(out + 3*WORD, pNA1, pDInv);
    }

    /// @dev Fq2 inverse via modexp backend in BigInt layer.
    function fq2InvToModexp(uint256 out, uint256 a, uint256 scratchFq2) internal view {
        uint256 a0 = a;
        uint256 a1 = a + 3*WORD;

        // layout (each 3 limbs):
        // t0:0, t1:3, betaT1:6, d:9, dinv:12, na1:15
        uint256 pT0     = scratchFq2;
        uint256 pT1     = scratchFq2 + 3*WORD;
        uint256 pBetaT1 = scratchFq2 + 6*WORD;
        uint256 pD      = scratchFq2 + 9*WORD;
        uint256 pDInv   = scratchFq2 + 12*WORD;
        uint256 pNA1    = scratchFq2 + 15*WORD;

        _fpSqrTo(pT0, a0); // a0^2
        _fpSqrTo(pT1, a1); // a1^2

        _fpMulBy13To(pBetaT1, pT1, pDInv); // betaT1 = 13*t1, use pDInv as tmp
        _fpSubTo(pD, pT0, pBetaT1);        // d = t0 - betaT1

        // dinv = inv3Modexp(d)
        (uint256 d0, uint256 d1, uint256 d2) = _fpLoad3(pD);
        (uint256 i0, uint256 i1, uint256 i2) = BigIntMNT.inv3Modexp(d0, d1, d2);
        _fpStore3(pDInv, i0, i1, i2);

        // out.c0 = a0*dinv
        _fpMulTo(out, a0, pDInv);

        // na1 = -a1
        _fpNegTo(pNA1, a1);
        // out.c1 = na1*dinv
        _fpMulTo(out + 3*WORD, pNA1, pDInv);
    }

    /// @notice Вычисляет мультипликативно обратное значение: `fq2InvToByBackend`.
    function fq2InvToByBackend(uint256 out, uint256 a, uint256 scratchFq2, bool useModexp) internal view {
        if (useModexp) {
            fq2InvToModexp(out, a, scratchFq2);
        } else {
            fq2InvTo(out, a, scratchFq2);
        }
    }

    // -------------------------
    // Указательный API для Fq4
    // Layout: [c0(Fq2=6 words), c1(Fq2=6 words)], v^2 = u
    // -------------------------

    function fq4AddTo(uint256 out, uint256 a, uint256 b) internal pure {
        fq2AddTo(out, a, b);
        fq2AddTo(out + 6*WORD, a + 6*WORD, b + 6*WORD);
    }

    /// @notice Выполняет сложение `fq4AddNRTo` с учетом модуля или структуры текущего поля.
    function fq4AddNRTo(uint256 out, uint256 a, uint256 b) internal pure {
        fq2AddNRTo(out, a, b);
        fq2AddNRTo(out + 6*WORD, a + 6*WORD, b + 6*WORD);
    }

    /// @notice Выполняет внутреннюю операцию `fq4ReduceTo`; параметры и результат используют представление текущей библиотеки.
    function fq4ReduceTo(uint256 out, uint256 a) internal pure {
        fq2ReduceTo(out, a);
        fq2ReduceTo(out + 6*WORD, a + 6*WORD);
    }

    /// @notice Выполняет вычитание `fq4SubTo` с учетом модуля или структуры текущего поля.
    function fq4SubTo(uint256 out, uint256 a, uint256 b) internal pure {
        fq2SubTo(out, a, b);
        fq2SubTo(out + 6*WORD, a + 6*WORD, b + 6*WORD);
    }

    /// @dev Multiply by v in Fq4: (c0 + c1*v)*v = (u*c1) + c0*v
    /// Requires scratch6 = 6 words for fq2MulByU.
    /// @dev Совпадение out==a не гарантируется безопасным: вызывающая функция должна разделять буферы.
    function fq4MulByVTo(uint256 out, uint256 a, uint256 scratch6) internal pure {
        uint256 a0 = a;
        uint256 a1 = a + 6*WORD;

        // out.c0 = u*c1
        fq2MulByUTo(out, a1, scratch6);

        // out.c1 = c0 (copy 6 words)
        assembly ("memory-safe") {
            mstore(add(out, mul(6, WORD)), mload(a0))
            mstore(add(out, mul(7, WORD)), mload(add(a0, WORD)))
            mstore(add(out, mul(8, WORD)), mload(add(a0, mul(2, WORD))))
            mstore(add(out, mul(9, WORD)), mload(add(a0, mul(3, WORD))))
            mstore(add(out, mul(10, WORD)), mload(add(a0, mul(4, WORD))))
            mstore(add(out, mul(11, WORD)), mload(add(a0, mul(5, WORD))))
        }
    }

    /// @dev Fq4 mul. Needs scratchFq4 = 54 words:
    ///  - 36 words for Fq2 temps (aSum,bSum,v0,v1,v2,s)
    ///  - 18 words for fq2 scratch
    function fq4MulTo(uint256 out, uint256 a, uint256 b, uint256 scratchFq4) internal pure {
        // Размещение временных значений по словам:
        // aSum:0..5, bSum:6..11, v0:12..17, v1:18..23, v2:24..29, s:30..35, fq2scratch:36..53
        uint256 pAS = scratchFq4;
        uint256 pBS = scratchFq4 + 6*WORD;
        uint256 pV0 = scratchFq4 + 12*WORD;
        uint256 pV1 = scratchFq4 + 18*WORD;
        uint256 pV2 = scratchFq4 + 24*WORD;
        uint256 pS  = scratchFq4 + 30*WORD;
        uint256 pFq2Scratch = scratchFq4 + 36*WORD;

        uint256 a0 = a;
        uint256 a1 = a + 6*WORD;
        uint256 b0 = b;
        uint256 b1 = b + 6*WORD;

        fq2AddTo(pAS, a0, a1);
        fq2AddTo(pBS, b0, b1);

        fq2MulTo(pV0, a0, b0, pFq2Scratch);
        fq2MulTo(pV1, a1, b1, pFq2Scratch);
        fq2MulTo(pV2, pAS, pBS, pFq2Scratch);

        fq2AddTo(pS, pV0, pV1);

        // out.c1 = v2 - s
        fq2SubTo(out + 6*WORD, pV2, pS);

        // tmp = v1 * u  (reuse pBS region now that bSum is dead)
        fq2MulByUTo(pBS, pV1, pFq2Scratch);

        // out.c0 = v0 + tmp
        fq2AddTo(out, pV0, pBS);
    }

    /// @dev Fq4 sqr. Needs scratchFq4 = 54 words.
    function fq4SqrTo(uint256 out, uint256 a, uint256 scratchFq4) internal pure {
        // (c0 + c1*v)^2 = (c0^2 + u*c1^2) + (2*c0*c1)*v
        uint256 pV0 = scratchFq4;           // 6
        uint256 pV1 = scratchFq4 + 6*WORD;  // 6
        uint256 pT  = scratchFq4 + 12*WORD; // 6
        uint256 pFq2Scratch = scratchFq4 + 36*WORD;

        uint256 a0 = a;
        uint256 a1 = a + 6*WORD;

        fq2SqrTo(pV0, a0, pFq2Scratch);
        fq2SqrTo(pV1, a1, pFq2Scratch);

        fq2MulTo(pT, a0, a1, pFq2Scratch);
        fq2AddTo(out + 6*WORD, pT, pT); // c1 = 2*t

        fq2MulByUTo(pT, pV1, pFq2Scratch); // t = u*v1

        fq2AddTo(out, pV0, pT); // c0 = v0 + t
    }

    /// @dev Multiply by Fq2 scalar: (a0+a1*v)*s = (a0*s) + (a1*s)*v
    function fq4MulByFq2To(uint256 out, uint256 a, uint256 sFq2, uint256 scratchFq2) internal pure {
        fq2MulTo(out, a, sFq2, scratchFq2);
        fq2MulTo(out + 6*WORD, a + 6*WORD, sFq2, scratchFq2);
    }

    /// @dev Fq4 inverse. Needs scratchFq4 = 54 words.
    /// (c0 + c1*v)^-1 = (c0 - c1*v) / (c0^2 - u*c1^2)
    function fq4InvTo(uint256 out, uint256 a, uint256 scratchFq4) internal pure {
        uint256 pT0     = scratchFq4;          // 6
        uint256 pT1     = scratchFq4 + 6*WORD; // 6
        uint256 pUT1    = scratchFq4 + 12*WORD;// 6
        uint256 pDen    = scratchFq4 + 18*WORD;// 6
        uint256 pDenInv = scratchFq4 + 24*WORD;// 6
        uint256 pNegC1  = scratchFq4 + 30*WORD;// 6
        uint256 pFq2Scratch = scratchFq4 + 36*WORD; // 18

        uint256 a0 = a;
        uint256 a1 = a + 6*WORD;

        fq2SqrTo(pT0, a0, pFq2Scratch);
        fq2SqrTo(pT1, a1, pFq2Scratch);

        fq2MulByUTo(pUT1, pT1, pFq2Scratch); // uses first 6 words of pFq2Scratch

        fq2SubTo(pDen, pT0, pUT1);

        fq2InvTo(pDenInv, pDen, pFq2Scratch);

        fq2MulTo(out, a0, pDenInv, pFq2Scratch);

        fq2NegTo(pNegC1, a1);
        fq2MulTo(out + 6*WORD, pNegC1, pDenInv, pFq2Scratch);
    }

    /// @notice Вычисляет мультипликативно обратное значение: `fq4InvToModexp`.
    function fq4InvToModexp(uint256 out, uint256 a, uint256 scratchFq4) internal view {
        uint256 pT0     = scratchFq4;          // 6
        uint256 pT1     = scratchFq4 + 6*WORD; // 6
        uint256 pUT1    = scratchFq4 + 12*WORD;// 6
        uint256 pDen    = scratchFq4 + 18*WORD;// 6
        uint256 pDenInv = scratchFq4 + 24*WORD;// 6
        uint256 pNegC1  = scratchFq4 + 30*WORD;// 6
        uint256 pFq2Scratch = scratchFq4 + 36*WORD; // 18

        uint256 a0 = a;
        uint256 a1 = a + 6*WORD;

        fq2SqrTo(pT0, a0, pFq2Scratch);
        fq2SqrTo(pT1, a1, pFq2Scratch);

        fq2MulByUTo(pUT1, pT1, pFq2Scratch);
        fq2SubTo(pDen, pT0, pUT1);

        fq2InvToModexp(pDenInv, pDen, pFq2Scratch);

        fq2MulTo(out, a0, pDenInv, pFq2Scratch);
        fq2NegTo(pNegC1, a1);
        fq2MulTo(out + 6*WORD, pNegC1, pDenInv, pFq2Scratch);
    }

    /// @notice Вычисляет мультипликативно обратное значение: `fq4InvToByBackend`.
    function fq4InvToByBackend(uint256 out, uint256 a, uint256 scratchFq4, bool useModexp) internal view {
        if (useModexp) {
            fq4InvToModexp(out, a, scratchFq4);
        } else {
            fq4InvTo(out, a, scratchFq4);
        }
    }
}

/// @notice High-level (struct-based) API compatible with your old MNT4ExtensionV3,
///         plus you can use `MNT4Extension` for maximum-performance pointer loops.
library MNT4ExtensionFinal {
    struct Fq2 {
        uint256[3] c0;
        uint256[3] c1;
    }

    struct Fq4 {
        Fq2 c0;
        Fq2 c1;
    }

    // ========= small const 13*x over Fp (Montgomery) =========

    function fpMulBy13(
        uint256 x0, uint256 x1, uint256 x2
    ) internal pure returns (uint256 y0, uint256 y1, uint256 y2) {
        (uint256 x2_0, uint256 x2_1, uint256 x2_2) = BigIntMNT.add3(x0, x1, x2, x0, x1, x2);              // 2x
        (uint256 x4_0, uint256 x4_1, uint256 x4_2) = BigIntMNT.add3(x2_0, x2_1, x2_2, x2_0, x2_1, x2_2);  // 4x
        (uint256 x8_0, uint256 x8_1, uint256 x8_2) = BigIntMNT.add3(x4_0, x4_1, x4_2, x4_0, x4_1, x4_2);  // 8x
        (uint256 x12_0, uint256 x12_1, uint256 x12_2) = BigIntMNT.add3(x8_0, x8_1, x8_2, x4_0, x4_1, x4_2); // 12x
        (y0, y1, y2) = BigIntMNT.add3(x12_0, x12_1, x12_2, x0, x1, x2);                                    // 13x
    }

    // ========= helpers: memory pointers for packed API (no allocations) =========

    function _ptrFq2(Fq2 memory a) private pure returns (uint256 p) {
        assembly ("memory-safe") { p := a }
    }

    /// @notice Выполняет внутреннюю операцию `_ptrFq4`; параметры и результат используют представление текущей библиотеки.
    function _ptrFq4(Fq4 memory a) private pure returns (uint256 p) {
        assembly ("memory-safe") { p := a }
    }

    // ========= Fq2 basic =========

    function fq2AddTo(Fq2 memory out, Fq2 memory a, Fq2 memory b) internal pure {
        (out.c0[0], out.c0[1], out.c0[2]) = BigIntMNT.add3(a.c0[0], a.c0[1], a.c0[2], b.c0[0], b.c0[1], b.c0[2]);
        (out.c1[0], out.c1[1], out.c1[2]) = BigIntMNT.add3(a.c1[0], a.c1[1], a.c1[2], b.c1[0], b.c1[1], b.c1[2]);
    }

    /// @notice Выполняет вычитание `fq2SubTo` с учетом модуля или структуры текущего поля.
    function fq2SubTo(Fq2 memory out, Fq2 memory a, Fq2 memory b) internal pure {
        (out.c0[0], out.c0[1], out.c0[2]) = BigIntMNT.sub3(a.c0[0], a.c0[1], a.c0[2], b.c0[0], b.c0[1], b.c0[2]);
        (out.c1[0], out.c1[1], out.c1[2]) = BigIntMNT.sub3(a.c1[0], a.c1[1], a.c1[2], b.c1[0], b.c1[1], b.c1[2]);
    }

    /// @notice Выполняет сложение `fq2Add` с учетом модуля или структуры текущего поля.
    function fq2Add(Fq2 memory a, Fq2 memory b) internal pure returns (Fq2 memory r) {
        fq2AddTo(r, a, b);
    }

    /// @notice Выполняет вычитание `fq2Sub` с учетом модуля или структуры текущего поля.
    function fq2Sub(Fq2 memory a, Fq2 memory b) internal pure returns (Fq2 memory r) {
        fq2SubTo(r, a, b);
    }

    // ========= Fq2 mul/sqr (with To-variants) =========
    // Совпадение out с a или b не гарантируется безопасным: вызывающая функция должна разделять буферы.

    function fq2MulTo(Fq2 memory out, Fq2 memory a, Fq2 memory b) internal pure {
        // Не выделяем новые массивы памяти: это снижает стоимость в цикле и сохраняет сравнимость benchmark.
        // v0 into out.c0
        (out.c0[0], out.c0[1], out.c0[2]) = BigIntMNT.montMul3(
            a.c0[0], a.c0[1], a.c0[2],
            b.c0[0], b.c0[1], b.c0[2]
        );

        // v1 into out.c1
        (out.c1[0], out.c1[1], out.c1[2]) = BigIntMNT.montMul3(
            a.c1[0], a.c1[1], a.c1[2],
            b.c1[0], b.c1[1], b.c1[2]
        );

        // s = v0+v1
        (uint256 s0, uint256 s1, uint256 s2) = BigIntMNT.add3(
            out.c0[0], out.c0[1], out.c0[2],
            out.c1[0], out.c1[1], out.c1[2]
        );

        // c0 = v0 + 13*v1
        (uint256 bv0, uint256 bv1, uint256 bv2) = fpMulBy13(out.c1[0], out.c1[1], out.c1[2]);
        (out.c0[0], out.c0[1], out.c0[2]) = BigIntMNT.add3(out.c0[0], out.c0[1], out.c0[2], bv0, bv1, bv2);

        // v2 = (a0+a1)*(b0+b1)
        (uint256 as0, uint256 as1, uint256 as2) = BigIntMNT.add3(
            a.c0[0], a.c0[1], a.c0[2],
            a.c1[0], a.c1[1], a.c1[2]
        );
        (uint256 bs0, uint256 bs1, uint256 bs2) = BigIntMNT.add3(
            b.c0[0], b.c0[1], b.c0[2],
            b.c1[0], b.c1[1], b.c1[2]
        );
        (uint256 v20, uint256 v21, uint256 v22) = BigIntMNT.montMul3(as0, as1, as2, bs0, bs1, bs2);

        // c1 = v2 - (v0+v1)
        (out.c1[0], out.c1[1], out.c1[2]) = BigIntMNT.sub3(v20, v21, v22, s0, s1, s2);
    }

    /// @notice Выполняет умножение `fq2Mul`; точный уровень поля и специальный множитель отражены в названии.
    function fq2Mul(Fq2 memory a, Fq2 memory b) internal pure returns (Fq2 memory r) {
        fq2MulTo(r, a, b);
    }

    /// @notice (a0 + a1*u)^2 = (a0^2 + 13*a1^2) + (2*a0*a1)u
    function fq2SqrTo(Fq2 memory out, Fq2 memory a) internal pure {
        (uint256 v00, uint256 v01, uint256 v02) = BigIntMNT.montSqr3(a.c0[0], a.c0[1], a.c0[2]);
        (uint256 v10, uint256 v11, uint256 v12) = BigIntMNT.montSqr3(a.c1[0], a.c1[1], a.c1[2]);

        (uint256 bv0, uint256 bv1, uint256 bv2) = fpMulBy13(v10, v11, v12);
        (out.c0[0], out.c0[1], out.c0[2]) = BigIntMNT.add3(v00, v01, v02, bv0, bv1, bv2);

        (uint256 t0, uint256 t1, uint256 t2) = BigIntMNT.montMul3(
            a.c0[0], a.c0[1], a.c0[2],
            a.c1[0], a.c1[1], a.c1[2]
        );
        (out.c1[0], out.c1[1], out.c1[2]) = BigIntMNT.add3(t0, t1, t2, t0, t1, t2);
    }

    /// @notice Возводит значение в квадрат: `fq2Sqr`.
    function fq2Sqr(Fq2 memory a) internal pure returns (Fq2 memory r) {
        fq2SqrTo(r, a);
    }

    /// @notice Multiply by u in Fq2: (x0 + x1*u)*u = (13*x1) + x0*u
    function fq2MulByUTo(Fq2 memory out, Fq2 memory x) internal pure {
        (out.c0[0], out.c0[1], out.c0[2]) = fpMulBy13(x.c1[0], x.c1[1], x.c1[2]);
        out.c1 = x.c0;
    }

    /// @notice Выполняет умножение `fq2MulByU`; точный уровень поля и специальный множитель отражены в названии.
    function fq2MulByU(Fq2 memory x) internal pure returns (Fq2 memory r) {
        fq2MulByUTo(r, x);
    }

    /// @notice Multiply Fq2 by scalar in Fp (Montgomery): (a0+a1*u)*s
    function fq2MulByFp3To(Fq2 memory out, Fq2 memory a, uint256 s0, uint256 s1, uint256 s2) internal pure {
        (out.c0[0], out.c0[1], out.c0[2]) = BigIntMNT.montMul3(a.c0[0], a.c0[1], a.c0[2], s0, s1, s2);
        (out.c1[0], out.c1[1], out.c1[2]) = BigIntMNT.montMul3(a.c1[0], a.c1[1], a.c1[2], s0, s1, s2);
    }

    /// @notice Выполняет умножение `fq2MulByFpTo`; точный уровень поля и специальный множитель отражены в названии.
    function fq2MulByFpTo(Fq2 memory out, Fq2 memory a, uint256[3] memory s) internal pure {
        fq2MulByFp3To(out, a, s[0], s[1], s[2]);
    }

    /// @notice Выполняет умножение `fq2MulByFp`; точный уровень поля и специальный множитель отражены в названии.
    function fq2MulByFp(Fq2 memory a, uint256[3] memory s) internal pure returns (Fq2 memory r) {
        fq2MulByFpTo(r, a, s);
    }

    // ========= Fq4 add/sub (To-variants) =========

    function fq4AddTo(Fq4 memory out, Fq4 memory a, Fq4 memory b) internal pure {
        fq2AddTo(out.c0, a.c0, b.c0);
        fq2AddTo(out.c1, a.c1, b.c1);
    }

    /// @notice Выполняет вычитание `fq4SubTo` с учетом модуля или структуры текущего поля.
    function fq4SubTo(Fq4 memory out, Fq4 memory a, Fq4 memory b) internal pure {
        fq2SubTo(out.c0, a.c0, b.c0);
        fq2SubTo(out.c1, a.c1, b.c1);
    }

    /// @notice Выполняет сложение `fq4Add` с учетом модуля или структуры текущего поля.
    function fq4Add(Fq4 memory a, Fq4 memory b) internal pure returns (Fq4 memory r) {
        fq4AddTo(r, a, b);
    }

    /// @notice Выполняет вычитание `fq4Sub` с учетом модуля или структуры текущего поля.
    function fq4Sub(Fq4 memory a, Fq4 memory b) internal pure returns (Fq4 memory r) {
        fq4SubTo(r, a, b);
    }

    // ========= Fq4 mul/sqr + helpers =========

    function fq4MulTo(Fq4 memory out, Fq4 memory a, Fq4 memory b) internal pure {
        // Ядро не выделяет память и подходит для повторных вызовов в измерениях,
        // а отдельный packed API используется в наиболее затратных указательных циклах.
        fq2MulTo(out.c0, a.c0, b.c0); // v0
        fq2MulTo(out.c1, a.c1, b.c1); // v1

        // s = v0+v1
        (uint256 s00, uint256 s01, uint256 s02) = BigIntMNT.add3(
            out.c0.c0[0], out.c0.c0[1], out.c0.c0[2],
            out.c1.c0[0], out.c1.c0[1], out.c1.c0[2]
        );
        (uint256 s10, uint256 s11, uint256 s12) = BigIntMNT.add3(
            out.c0.c1[0], out.c0.c1[1], out.c0.c1[2],
            out.c1.c1[0], out.c1.c1[1], out.c1.c1[2]
        );

        // c0 = v0 + u*v1
        (uint256 uv0, uint256 uv1, uint256 uv2) = fpMulBy13(out.c1.c1[0], out.c1.c1[1], out.c1.c1[2]); // 13*v1.c1
        (out.c0.c0[0], out.c0.c0[1], out.c0.c0[2]) = BigIntMNT.add3(
            out.c0.c0[0], out.c0.c0[1], out.c0.c0[2],
            uv0, uv1, uv2
        );
        (out.c0.c1[0], out.c0.c1[1], out.c0.c1[2]) = BigIntMNT.add3(
            out.c0.c1[0], out.c0.c1[1], out.c0.c1[2],
            out.c1.c0[0], out.c1.c0[1], out.c1.c0[2]
        );

        // v2 = (a0+a1)*(b0+b1)
        Fq2 memory aSum;
        (aSum.c0[0], aSum.c0[1], aSum.c0[2]) = BigIntMNT.add3(
            a.c0.c0[0], a.c0.c0[1], a.c0.c0[2],
            a.c1.c0[0], a.c1.c0[1], a.c1.c0[2]
        );
        (aSum.c1[0], aSum.c1[1], aSum.c1[2]) = BigIntMNT.add3(
            a.c0.c1[0], a.c0.c1[1], a.c0.c1[2],
            a.c1.c1[0], a.c1.c1[1], a.c1.c1[2]
        );

        Fq2 memory bSum;
        (bSum.c0[0], bSum.c0[1], bSum.c0[2]) = BigIntMNT.add3(
            b.c0.c0[0], b.c0.c0[1], b.c0.c0[2],
            b.c1.c0[0], b.c1.c0[1], b.c1.c0[2]
        );
        (bSum.c1[0], bSum.c1[1], bSum.c1[2]) = BigIntMNT.add3(
            b.c0.c1[0], b.c0.c1[1], b.c0.c1[2],
            b.c1.c1[0], b.c1.c1[1], b.c1.c1[2]
        );

        fq2MulTo(out.c1, aSum, bSum);

        // c1 = v2 - s
        (out.c1.c0[0], out.c1.c0[1], out.c1.c0[2]) = BigIntMNT.sub3(
            out.c1.c0[0], out.c1.c0[1], out.c1.c0[2],
            s00, s01, s02
        );
        (out.c1.c1[0], out.c1.c1[1], out.c1.c1[2]) = BigIntMNT.sub3(
            out.c1.c1[0], out.c1.c1[1], out.c1.c1[2],
            s10, s11, s12
        );
    }

    /// @notice Выполняет умножение `fq4Mul`; точный уровень поля и специальный множитель отражены в названии.
    function fq4Mul(Fq4 memory a, Fq4 memory b) internal pure returns (Fq4 memory r) {
        fq4MulTo(r, a, b);
    }

    /// @notice (c0 + c1*v)^2 = (c0^2 + u*c1^2) + (2*c0*c1)*v, with v^2=u
    function fq4SqrTo(Fq4 memory out, Fq4 memory a) internal pure {
        fq2SqrTo(out.c0, a.c0);
        fq2SqrTo(out.c1, a.c1);

        (uint256 ux0, uint256 ux1, uint256 ux2) = fpMulBy13(out.c1.c1[0], out.c1.c1[1], out.c1.c1[2]);
        (out.c0.c0[0], out.c0.c0[1], out.c0.c0[2]) = BigIntMNT.add3(
            out.c0.c0[0], out.c0.c0[1], out.c0.c0[2],
            ux0, ux1, ux2
        );
        (out.c0.c1[0], out.c0.c1[1], out.c0.c1[2]) = BigIntMNT.add3(
            out.c0.c1[0], out.c0.c1[1], out.c0.c1[2],
            out.c1.c0[0], out.c1.c0[1], out.c1.c0[2]
        );

        fq2MulTo(out.c1, a.c0, a.c1);

        (out.c1.c0[0], out.c1.c0[1], out.c1.c0[2]) = BigIntMNT.add3(
            out.c1.c0[0], out.c1.c0[1], out.c1.c0[2],
            out.c1.c0[0], out.c1.c0[1], out.c1.c0[2]
        );
        (out.c1.c1[0], out.c1.c1[1], out.c1.c1[2]) = BigIntMNT.add3(
            out.c1.c1[0], out.c1.c1[1], out.c1.c1[2],
            out.c1.c1[0], out.c1.c1[1], out.c1.c1[2]
        );
    }

    /// @notice Возводит значение в квадрат: `fq4Sqr`.
    function fq4Sqr(Fq4 memory a) internal pure returns (Fq4 memory r) {
        fq4SqrTo(r, a);
    }

    /// @notice Multiply Fq4 by scalar in Fq2: (a0+a1*v)*s = (a0*s) + (a1*s)*v
    function fq4MulByFq2To(Fq4 memory out, Fq4 memory a, Fq2 memory s) internal pure {
        fq2MulTo(out.c0, a.c0, s);
        fq2MulTo(out.c1, a.c1, s);
    }

    /// @notice Выполняет умножение `fq4MulByFq2`; точный уровень поля и специальный множитель отражены в названии.
    function fq4MulByFq2(Fq4 memory a, Fq2 memory s) internal pure returns (Fq4 memory r) {
        fq4MulByFq2To(r, a, s);
    }

    /// @notice Multiply by v in Fq4: (c0 + c1*v)*v = (u*c1) + c0*v
    function fq4MulByVTo(Fq4 memory out, Fq4 memory a) internal pure {
        fq2MulByUTo(out.c0, a.c1);
        out.c1 = a.c0;
    }

    /// @notice Выполняет умножение `fq4MulByV`; точный уровень поля и специальный множитель отражены в названии.
    function fq4MulByV(Fq4 memory a) internal pure returns (Fq4 memory r) {
        fq4MulByVTo(r, a);
    }

    /// @notice Вычисляет аддитивно обратное значение: `fq2NegTo`.
    function fq2NegTo(Fq2 memory out, Fq2 memory a) internal pure {
        (out.c0[0], out.c0[1], out.c0[2]) = BigIntMNT.sub3(0, 0, 0, a.c0[0], a.c0[1], a.c0[2]);
        (out.c1[0], out.c1[1], out.c1[2]) = BigIntMNT.sub3(0, 0, 0, a.c1[0], a.c1[1], a.c1[2]);
    }

    /// @notice Inverse in Fq2:
    /// (a0 + a1*u)^-1 = (a0 - a1*u) / (a0^2 - 13*a1^2)
    function fq2InvTo(Fq2 memory out, Fq2 memory a) internal pure {
        (uint256 t00, uint256 t01, uint256 t02) = BigIntMNT.montSqr3(a.c0[0], a.c0[1], a.c0[2]);
        (uint256 t10, uint256 t11, uint256 t12) = BigIntMNT.montSqr3(a.c1[0], a.c1[1], a.c1[2]);
        (uint256 beta10, uint256 beta11, uint256 beta12) = fpMulBy13(t10, t11, t12);
        (uint256 d0, uint256 d1, uint256 d2) = BigIntMNT.sub3(t00, t01, t02, beta10, beta11, beta12);
        (uint256 dinv0, uint256 dinv1, uint256 dinv2) = BigIntMNT.inv3(d0, d1, d2);

        (out.c0[0], out.c0[1], out.c0[2]) = BigIntMNT.montMul3(a.c0[0], a.c0[1], a.c0[2], dinv0, dinv1, dinv2);
        (uint256 na10, uint256 na11, uint256 na12) = BigIntMNT.sub3(0, 0, 0, a.c1[0], a.c1[1], a.c1[2]);
        (out.c1[0], out.c1[1], out.c1[2]) = BigIntMNT.montMul3(na10, na11, na12, dinv0, dinv1, dinv2);
    }

    /// @notice Вычисляет мультипликативно обратное значение: `fq2Inv`.
    function fq2Inv(Fq2 memory a) internal pure returns (Fq2 memory r) {
        fq2InvTo(r, a);
    }

    /// @notice Вычисляет мультипликативно обратное значение: `fq2InvToNative`.
    function fq2InvToNative(Fq2 memory out, Fq2 memory a) internal pure {
        fq2InvTo(out, a);
    }

    /// @notice Вычисляет мультипликативно обратное значение: `fq2InvNative`.
    function fq2InvNative(Fq2 memory a) internal pure returns (Fq2 memory r) {
        fq2InvToNative(r, a);
    }

    /// @notice Вычисляет мультипликативно обратное значение: `fq2InvToModexp`.
    function fq2InvToModexp(Fq2 memory out, Fq2 memory a) internal view {
        (uint256 t00, uint256 t01, uint256 t02) = BigIntMNT.montSqr3(a.c0[0], a.c0[1], a.c0[2]);
        (uint256 t10, uint256 t11, uint256 t12) = BigIntMNT.montSqr3(a.c1[0], a.c1[1], a.c1[2]);
        (uint256 beta10, uint256 beta11, uint256 beta12) = fpMulBy13(t10, t11, t12);
        (uint256 d0, uint256 d1, uint256 d2) = BigIntMNT.sub3(t00, t01, t02, beta10, beta11, beta12);
        (uint256 dinv0, uint256 dinv1, uint256 dinv2) = BigIntMNT.inv3Modexp(d0, d1, d2);

        (out.c0[0], out.c0[1], out.c0[2]) = BigIntMNT.montMul3(a.c0[0], a.c0[1], a.c0[2], dinv0, dinv1, dinv2);
        (uint256 na10, uint256 na11, uint256 na12) = BigIntMNT.sub3(0, 0, 0, a.c1[0], a.c1[1], a.c1[2]);
        (out.c1[0], out.c1[1], out.c1[2]) = BigIntMNT.montMul3(na10, na11, na12, dinv0, dinv1, dinv2);
    }

    /// @notice Вычисляет мультипликативно обратное значение: `fq2InvModexp`.
    function fq2InvModexp(Fq2 memory a) internal view returns (Fq2 memory r) {
        fq2InvToModexp(r, a);
    }

    /// @notice Вычисляет мультипликативно обратное значение: `fq2InvToByBackend`.
    function fq2InvToByBackend(Fq2 memory out, Fq2 memory a, bool useModexp) internal view {
        if (useModexp) fq2InvToModexp(out, a);
        else fq2InvTo(out, a);
    }

    /// @notice Вычисляет мультипликативно обратное значение: `fq2InvByBackend`.
    function fq2InvByBackend(Fq2 memory a, bool useModexp) internal view returns (Fq2 memory r) {
        fq2InvToByBackend(r, a, useModexp);
    }

    /// @notice Inverse in Fq4:
    /// (c0 + c1*v)^-1 = (c0 - c1*v) / (c0^2 - u*c1^2), where v^2 = u.
    function fq4InvTo(Fq4 memory out, Fq4 memory a) internal pure {
        // Для наиболее затратного пути можно вызвать указательную версию MNT4Extension.fq4InvTo(...).
        Fq2 memory t0;
        fq2SqrTo(t0, a.c0);

        Fq2 memory t1;
        fq2SqrTo(t1, a.c1);

        Fq2 memory ut1;
        fq2MulByUTo(ut1, t1);

        Fq2 memory den;
        fq2SubTo(den, t0, ut1);

        Fq2 memory denInv;
        fq2InvTo(denInv, den);

        fq2MulTo(out.c0, a.c0, denInv);

        Fq2 memory negC1;
        fq2NegTo(negC1, a.c1);
        fq2MulTo(out.c1, negC1, denInv);
    }

    /// @notice Вычисляет мультипликативно обратное значение: `fq4Inv`.
    function fq4Inv(Fq4 memory a) internal pure returns (Fq4 memory r) {
        fq4InvTo(r, a);
    }

    /// @notice Вычисляет мультипликативно обратное значение: `fq4InvToNative`.
    function fq4InvToNative(Fq4 memory out, Fq4 memory a) internal pure {
        fq4InvTo(out, a);
    }

    /// @notice Вычисляет мультипликативно обратное значение: `fq4InvNative`.
    function fq4InvNative(Fq4 memory a) internal pure returns (Fq4 memory r) {
        fq4InvToNative(r, a);
    }

    /// @notice Вычисляет мультипликативно обратное значение: `fq4InvToModexp`.
    function fq4InvToModexp(Fq4 memory out, Fq4 memory a) internal view {
        Fq2 memory t0;
        fq2SqrTo(t0, a.c0);

        Fq2 memory t1;
        fq2SqrTo(t1, a.c1);

        Fq2 memory ut1;
        fq2MulByUTo(ut1, t1);

        Fq2 memory den;
        fq2SubTo(den, t0, ut1);

        Fq2 memory denInv;
        fq2InvToModexp(denInv, den);

        fq2MulTo(out.c0, a.c0, denInv);

        Fq2 memory negC1;
        fq2NegTo(negC1, a.c1);
        fq2MulTo(out.c1, negC1, denInv);
    }

    /// @notice Вычисляет мультипликативно обратное значение: `fq4InvModexp`.
    function fq4InvModexp(Fq4 memory a) internal view returns (Fq4 memory r) {
        fq4InvToModexp(r, a);
    }

    /// @notice Вычисляет мультипликативно обратное значение: `fq4InvToByBackend`.
    function fq4InvToByBackend(Fq4 memory out, Fq4 memory a, bool useModexp) internal view {
        if (useModexp) fq4InvToModexp(out, a);
        else fq4InvTo(out, a);
    }

    /// @notice Вычисляет мультипликативно обратное значение: `fq4InvByBackend`.
    function fq4InvByBackend(Fq4 memory a, bool useModexp) internal view returns (Fq4 memory r) {
        fq4InvToByBackend(r, a, useModexp);
    }
}
