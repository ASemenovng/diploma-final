// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {MNT6PairingTypes} from "./MNT6PairingTypes.sol";
import {MNT6Fq3} from "./MNT6Fq3.sol";
import {MNT6PackedArithmetic} from "./MNT6PackedArithmetic.sol";

/// @notice Арифметика расширения Fq6=Fq3[w]/(w^2-v) для MNT6-753.
library MNT6Fq6 {
    /// @notice Возвращает нулевой элемент в используемом представлении: `zero`.
    function zero() internal pure returns (MNT6PairingTypes.Fq6 memory r) {}

    /// @notice Возвращает единичный элемент в используемом представлении: `one`.
    function one() internal pure returns (MNT6PairingTypes.Fq6 memory r) {
        r.c0 = MNT6Fq3.one();
    }

    /// @notice Сравнивает два значения без изменения входных данных: `eq`.
    function eq(MNT6PairingTypes.Fq6 memory a, MNT6PairingTypes.Fq6 memory b) internal pure returns (bool) {
        return MNT6Fq3.eq(a.c0, b.c0) && MNT6Fq3.eq(a.c1, b.c1);
    }

    /// @notice Выполняет сложение `add` с учетом модуля или структуры текущего поля.
    function add(MNT6PairingTypes.Fq6 memory a, MNT6PairingTypes.Fq6 memory b)
        internal pure returns (MNT6PairingTypes.Fq6 memory r)
    {
        r.c0 = MNT6Fq3.add(a.c0, b.c0);
        r.c1 = MNT6Fq3.add(a.c1, b.c1);
    }

    /// @notice Выполняет вычитание `sub` с учетом модуля или структуры текущего поля.
    function sub(MNT6PairingTypes.Fq6 memory a, MNT6PairingTypes.Fq6 memory b)
        internal pure returns (MNT6PairingTypes.Fq6 memory r)
    {
        r.c0 = MNT6Fq3.sub(a.c0, b.c0);
        r.c1 = MNT6Fq3.sub(a.c1, b.c1);
    }

    /// @notice Выполняет умножение `mul`; точный уровень поля и специальный множитель отражены в названии.
    function mul(MNT6PairingTypes.Fq6 memory a, MNT6PairingTypes.Fq6 memory b)
        internal pure returns (MNT6PairingTypes.Fq6 memory r)
    {
        return mulByLine(a, b.c0, b.c1);
    }

    /// @notice Выполняет умножение `mulByLine`; точный уровень поля и специальный множитель отражены в названии.
    function mulByLine(
        MNT6PairingTypes.Fq6 memory a,
        MNT6PairingTypes.Fq3 memory b0,
        MNT6PairingTypes.Fq3 memory b1
    ) internal pure returns (MNT6PairingTypes.Fq6 memory r) {
        MNT6PairingTypes.Fq3 memory v0 = MNT6Fq3.mul(a.c0, b0);
        MNT6PairingTypes.Fq3 memory v1 = MNT6Fq3.mul(a.c1, b1);
        MNT6PairingTypes.Fq3 memory v2 = MNT6Fq3.mul(MNT6Fq3.add(a.c0, a.c1), MNT6Fq3.add(b0, b1));
        r.c0 = MNT6Fq3.add(v0, MNT6Fq3.mulByNonresidue(v1));
        r.c1 = MNT6Fq3.sub(MNT6Fq3.sub(v2, v0), v1);
    }

    /// @notice Возводит значение в квадрат: `sqr`.
    function sqr(MNT6PairingTypes.Fq6 memory a) internal pure returns (MNT6PairingTypes.Fq6 memory r) {
        // (a0 + a1*w)^2 = (a0^2 + v*a1^2) + 2*a0*a1*w, where w^2 = v.
        MNT6PairingTypes.Fq3 memory a0a0 = MNT6Fq3.sqr(a.c0);
        MNT6PairingTypes.Fq3 memory a1a1 = MNT6Fq3.sqr(a.c1);
        MNT6PairingTypes.Fq3 memory a0a1 = MNT6Fq3.mul(a.c0, a.c1);
        r.c0 = MNT6Fq3.add(a0a0, MNT6Fq3.mulByNonresidue(a1a1));
        r.c1 = MNT6Fq3.add(a0a1, a0a1);
    }

    /// @notice Вычисляет сопряженный элемент расширения: `conjugate`.
    function conjugate(MNT6PairingTypes.Fq6 memory a) internal pure returns (MNT6PairingTypes.Fq6 memory r) {
        r.c0 = a.c0;
        r.c1 = MNT6Fq3.neg(a.c1);
    }

    /// @notice Применяет отображение Фробениуса: `frobeniusMap`.
    function frobeniusMap(MNT6PairingTypes.Fq6 memory a, uint256 power)
        internal pure returns (MNT6PairingTypes.Fq6 memory r)
    {
        uint256 p = power % 6;
        r.c0 = MNT6Fq3.frobeniusMap(a.c0, p);
        r.c1 = MNT6Fq3.mulByFp(MNT6Fq3.frobeniusMap(a.c1, p), _frobeniusC1(p));
    }

    /// @notice Вычисляет мультипликативно обратное значение: `inv`.
    function inv(MNT6PairingTypes.Fq6 memory a) internal pure returns (MNT6PairingTypes.Fq6 memory r) {
        // (a0 + a1*w)^{-1}, w^2=v: denominator = a0^2 - v*a1^2.
        MNT6PairingTypes.Fq3 memory denom = MNT6Fq3.sub(MNT6Fq3.sqr(a.c0), MNT6Fq3.mulByNonresidue(MNT6Fq3.sqr(a.c1)));
        MNT6PairingTypes.Fq3 memory invDenom = MNT6Fq3.inv(denom);
        r.c0 = MNT6Fq3.mul(a.c0, invDenom);
        r.c1 = MNT6Fq3.neg(MNT6Fq3.mul(a.c1, invDenom));
    }

    /// @notice Выполняет внутреннюю операцию `powByMNT6ScalarModulus`; параметры и результат используют представление текущей библиотеки.
    function powByMNT6ScalarModulus(MNT6PairingTypes.Fq6 memory a) internal pure returns (MNT6PairingTypes.Fq6 memory r) {
        // Fr(MNT6-753) = Fq(MNT4-753). Bits are scanned from most significant to least significant.
        uint256[3] memory e = [
            uint256(0x685acce9767254a4638810719ac425f0e39d54522cdd119f5e9063de245e8001),
            uint256(0x7fdb925e8a0ed8d99d124d9a15af79db117e776f218059db80f0da5cb537e38),
            uint256(0x0001c4c62d92c41110229022eee2cdadb7f997505b8fafed5eb7e8f96c97d873)
        ];
        r = one();
        bool started = false;
        for (uint256 limb = 3; limb > 0; limb--) {
            uint256 word = e[limb - 1];
            for (uint256 bit = 256; bit > 0; bit--) {
                bool isSet = ((word >> (bit - 1)) & 1) == 1;
                if (started) r = sqr(r);
                if (isSet) {
                    r = started ? mul(r, a) : a;
                    started = true;
                }
            }
        }
    }

    /// @notice Выполняет или проверяет этап финальной экспоненты `finalExponentiation` после цикла Миллера.
    function finalExponentiation(MNT6PairingTypes.Fq6 memory value)
        internal pure returns (MNT6PairingTypes.Fq6 memory)
    {
        MNT6PairingTypes.Fq6 memory valueInv = inv(value);
        MNT6PairingTypes.Fq6 memory first = _finalExponentiationFirstChunk(value, valueInv);
        return mul(frobeniusMap(first, 1), _cyclotomicExpW0(first));
    }

    /// @notice Выполняет или проверяет этап финальной экспоненты `finalExponentiationPacked` после цикла Миллера.
    function finalExponentiationPacked(MNT6PairingTypes.Fq6 memory value)
        internal pure returns (MNT6PairingTypes.Fq6 memory)
    {
        MNT6PairingTypes.Fq6 memory valueInv = inv(value);
        MNT6PairingTypes.Fq6 memory first = _finalExponentiationFirstChunk(value, valueInv);
        return mul(frobeniusMap(first, 1), _cyclotomicExpW0Packed(first));
    }

    /// @notice Выполняет или проверяет этап финальной экспоненты `_finalExponentiationFirstChunk` после цикла Миллера.
    function _finalExponentiationFirstChunk(
        MNT6PairingTypes.Fq6 memory elt,
        MNT6PairingTypes.Fq6 memory eltInv
    ) private pure returns (MNT6PairingTypes.Fq6 memory) {
        // (q^3 - 1) * (q + 1): q^3 is conjugation in this quadratic tower.
        MNT6PairingTypes.Fq6 memory eltQ3OverElt = mul(conjugate(elt), eltInv);
        return mul(frobeniusMap(eltQ3OverElt, 1), eltQ3OverElt);
    }

    /// @notice Выполняет внутреннюю операцию `_cyclotomicExpW0`; параметры и результат используют представление текущей библиотеки.
    function _cyclotomicExpW0(MNT6PairingTypes.Fq6 memory a) private pure returns (MNT6PairingTypes.Fq6 memory r) {
        uint256[3] memory e = [
            uint256(0x51852c8cbe26e600733b714aa43c31a66b0344c4e2c428b07a7713041ba18000),
            uint256(0x00000000000000000000000000000000015474b1d641a3fd86dcbcee5dcda7fe),
            uint256(0)
        ];
        r = one();
        bool started = false;
        for (uint256 limb = 3; limb > 0; limb--) {
            uint256 word = e[limb - 1];
            for (uint256 bit = 256; bit > 0; bit--) {
                bool isSet = ((word >> (bit - 1)) & 1) == 1;
                if (started) r = sqr(r);
                if (isSet) {
                    r = started ? mul(r, a) : a;
                    started = true;
                }
            }
        }
    }

    /// @notice Выполняет внутреннюю операцию `_cyclotomicExpW0Packed`; параметры и результат используют представление текущей библиотеки.
    function _cyclotomicExpW0Packed(MNT6PairingTypes.Fq6 memory a) private pure returns (MNT6PairingTypes.Fq6 memory) {
        uint256 base = MNT6PackedArithmetic.arenaPtr(224);
        uint256 pA = base;
        uint256 pR = base + 0x240;
        uint256 pTmp = base + 0x480;
        uint256 pAInv = base + 0x6c0;
        uint256 scratch = base + 0x900;

        MNT6PackedArithmetic.fq6StoreTo(pA, a);
        MNT6PackedArithmetic.fq6StoreTo(pAInv, conjugate(a));
        MNT6PackedArithmetic.fq6OneTo(pR);

        bool started = false;
        for (uint256 i = 377; i > 0; i--) {
            int8 digit = _w0NafDigit(i - 1);
            if (started) {
                MNT6PackedArithmetic.fq6SqrTo(pTmp, pR, scratch);
                (pR, pTmp) = (pTmp, pR);
            }
            if (digit != 0) {
                uint256 pMul = digit == 1 ? pA : pAInv;
                if (started) {
                    MNT6PackedArithmetic.fq6MulTo(pTmp, pR, pMul, scratch);
                    (pR, pTmp) = (pTmp, pR);
                } else {
                    MNT6PackedArithmetic.fq6CopyTo(pR, pMul);
                }
                started = true;
            }
        }
        return MNT6PackedArithmetic.fq6Load(pR);
    }

    /// @notice Выполняет внутреннюю операцию `_w0NafDigit`; параметры и результат используют представление текущей библиотеки.
    function _w0NafDigit(uint256 i) private pure returns (int8) {
        uint256 j = i;
        uint256 plus;
        uint256 minus;
        if (i < 256) {
            plus = 0x52054091002808008440014aa440422880044505040429008280140420220000;
            minus = 0x80140442012200110490000004108215010040214000500809010004808000;
        } else {
            j = i - 256;
            plus = 0x1548502004224000801010080102800;
            minus = 0x10502a0080028124441222428002;
        }
        uint256 mask = 1 << j;
        if (plus & mask != 0) return 1;
        if (minus & mask != 0) return -1;
        return 0;
    }

    /// @notice Применяет отображение Фробениуса: `_frobeniusC1`.
    function _frobeniusC1(uint256 power) private pure returns (MNT6PairingTypes.Fp memory) {
        if (power == 0) {
            return MNT6PairingTypes.Fp(
                0x00007b479ec8e24295455fb31ff9a1950fa47edb3865e88c4074c9cbfd8ca621,
                0x598b4302d2f00a62320c3bb7133384989fbca908de0ccb62ab0c4ee6d3e6dad4,
                0x0f725caec549c0daa1ebd2d90c79e1794eb16817b589cea8b99680147fff6f42
            );
        } else if (power == 1) {
            return MNT6PairingTypes.Fp(
                0x00019897d1eb1ca04df5e7055d775a97c45deb6fc774821ee7cb22af3bb2a012,
                0x3f3ec8159c1da9be186cec139ca9d216943d1b65fbd3ae53fd566bac405fc44b,
                0x4ed706302c0e2b723da2c7145efc7815622b1a03ad8db3c724fd77ccbf95f5c2
            );
        } else if (power == 2) {
            return MNT6PairingTypes.Fp(
                0x00011d5033223a5db8b087523d7db902b4b96c948f0e9992a75658e33e25f9f0,
                0xe5b38512c92d9f5be660b05c89764d7df480725d1dc6e2f1524a1cc56c78e977,
                0x3f64a98166c46a979bb6f43b5282969c1379b1ebf803e51e6b66f7b83f968680
            );
        } else if (power == 3) {
            return MNT6PairingTypes.Fp(
                0x0001497e8ec9e1ce7add306fcee92c18a85518752329c7611e431f2d6f0b3251,
                0xae72762315b0e32b67c4e9228e27730512afb31fea4cde3893df7bad553a4b62,
                0xaa6d9cc76f4f79ca34d7aee33286761dffef30ff5a176ba71f70f6cdc00090bf
            );
        } else if (power == 4) {
            return MNT6PairingTypes.Fp(
                0x00002c2e5ba7a770c22ca91d916b7315f39babe0941b2dce76ecc64a30e53860,
                0xc8bef1104c8343cf816438c604b125871e2f40c2cc85fb4741955ee7e8c161eb,
                0x6b08f346088b0f329920baa7e003df81ec757f1362138688b409ff15806a0a3f
            );
        } else {
            return MNT6PairingTypes.Fp(
                0x0000a775fa7089b3577208d0b16514ab03402abbcc81165ab76190162e71de82,
                0x224a34131f734e31b370747d17e4aa1fbdebe9cbaa92c6a9eca1adcebca83cbf,
                0x7a7b4ff4cdd4d00d3b0c8d80ec7dc0fb3b26e72b179d55316da07f2a00697981
            );
        }
    }
}
