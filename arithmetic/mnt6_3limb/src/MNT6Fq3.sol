// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {MNT6PairingTypes} from "./MNT6PairingTypes.sol";
import {MNT6Fp} from "./MNT6Fp.sol";

/// @notice Арифметика расширения Fq3=Fq[v]/(v^3-11) для MNT6-753.
library MNT6Fq3 {
    /// @notice Возвращает нулевой элемент в используемом представлении: `zero`.
    function zero() internal pure returns (MNT6PairingTypes.Fq3 memory r) {}

    /// @notice Возвращает единичный элемент в используемом представлении: `one`.
    function one() internal pure returns (MNT6PairingTypes.Fq3 memory r) {
        r.c0 = MNT6Fp.one();
    }

    /// @notice Сравнивает два значения без изменения входных данных: `eq`.
    function eq(MNT6PairingTypes.Fq3 memory a, MNT6PairingTypes.Fq3 memory b) internal pure returns (bool) {
        return MNT6Fp.eq(a.c0, b.c0) && MNT6Fp.eq(a.c1, b.c1) && MNT6Fp.eq(a.c2, b.c2);
    }

    /// @notice Выполняет сложение `add` с учетом модуля или структуры текущего поля.
    function add(MNT6PairingTypes.Fq3 memory a, MNT6PairingTypes.Fq3 memory b)
        internal pure returns (MNT6PairingTypes.Fq3 memory r)
    {
        r.c0 = MNT6Fp.add(a.c0, b.c0);
        r.c1 = MNT6Fp.add(a.c1, b.c1);
        r.c2 = MNT6Fp.add(a.c2, b.c2);
    }

    /// @notice Выполняет вычитание `sub` с учетом модуля или структуры текущего поля.
    function sub(MNT6PairingTypes.Fq3 memory a, MNT6PairingTypes.Fq3 memory b)
        internal pure returns (MNT6PairingTypes.Fq3 memory r)
    {
        r.c0 = MNT6Fp.sub(a.c0, b.c0);
        r.c1 = MNT6Fp.sub(a.c1, b.c1);
        r.c2 = MNT6Fp.sub(a.c2, b.c2);
    }

    /// @notice Вычисляет аддитивно обратное значение: `neg`.
    function neg(MNT6PairingTypes.Fq3 memory a) internal pure returns (MNT6PairingTypes.Fq3 memory r) {
        r.c0 = MNT6Fp.neg(a.c0);
        r.c1 = MNT6Fp.neg(a.c1);
        r.c2 = MNT6Fp.neg(a.c2);
    }

    /// @notice Выполняет умножение `mulByNonresidue`; точный уровень поля и специальный множитель отражены в названии.
    function mulByNonresidue(MNT6PairingTypes.Fq3 memory a) internal pure returns (MNT6PairingTypes.Fq3 memory r) {
        // v * (a0 + a1*v + a2*v^2) = 11*a2 + a0*v + a1*v^2.
        r.c0 = MNT6Fp.mulBy11(a.c2);
        r.c1 = a.c0;
        r.c2 = a.c1;
    }

    /// @notice Выполняет умножение `mulByFp`; точный уровень поля и специальный множитель отражены в названии.
    function mulByFp(MNT6PairingTypes.Fq3 memory a, MNT6PairingTypes.Fp memory s)
        internal pure returns (MNT6PairingTypes.Fq3 memory r)
    {
        r.c0 = MNT6Fp.mul(a.c0, s);
        r.c1 = MNT6Fp.mul(a.c1, s);
        r.c2 = MNT6Fp.mul(a.c2, s);
    }

    /// @notice Применяет отображение Фробениуса: `frobeniusMap`.
    function frobeniusMap(MNT6PairingTypes.Fq3 memory a, uint256 power)
        internal pure returns (MNT6PairingTypes.Fq3 memory r)
    {
        uint256 p = power % 3;
        r.c0 = a.c0;
        r.c1 = MNT6Fp.mul(a.c1, _frobeniusC1(p));
        r.c2 = MNT6Fp.mul(a.c2, _frobeniusC2(p));
    }

    /// @notice Выполняет умножение `mul`; точный уровень поля и специальный множитель отражены в названии.
    function mul(MNT6PairingTypes.Fq3 memory a, MNT6PairingTypes.Fq3 memory b)
        internal pure returns (MNT6PairingTypes.Fq3 memory r)
    {
        // Умножение Карацубы for Fq[v]/(v^3-11), 6 Fq multiplications instead of 9.
        MNT6PairingTypes.Fp memory v0 = MNT6Fp.mul(a.c0, b.c0);
        MNT6PairingTypes.Fp memory v1 = MNT6Fp.mul(a.c1, b.c1);
        MNT6PairingTypes.Fp memory v2 = MNT6Fp.mul(a.c2, b.c2);
        MNT6PairingTypes.Fp memory t0 = MNT6Fp.sub(MNT6Fp.sub(MNT6Fp.mul(MNT6Fp.add(a.c1, a.c2), MNT6Fp.add(b.c1, b.c2)), v1), v2);
        MNT6PairingTypes.Fp memory t1 = MNT6Fp.sub(MNT6Fp.sub(MNT6Fp.mul(MNT6Fp.add(a.c0, a.c1), MNT6Fp.add(b.c0, b.c1)), v0), v1);
        MNT6PairingTypes.Fp memory t2 = MNT6Fp.sub(MNT6Fp.sub(MNT6Fp.mul(MNT6Fp.add(a.c0, a.c2), MNT6Fp.add(b.c0, b.c2)), v0), v2);
        r.c0 = MNT6Fp.add(v0, MNT6Fp.mulBy11(t0));
        r.c1 = MNT6Fp.add(t1, MNT6Fp.mulBy11(v2));
        r.c2 = MNT6Fp.add(t2, v1);
    }

    /// @notice Возводит значение в квадрат: `sqr`.
    function sqr(MNT6PairingTypes.Fq3 memory a) internal pure returns (MNT6PairingTypes.Fq3 memory r) {
        // Squaring in Fq[v]/(v^3-11): 6 base multiplications with cheaper doubled cross terms.
        MNT6PairingTypes.Fp memory a0a0 = MNT6Fp.sqr(a.c0);
        MNT6PairingTypes.Fp memory a1a1 = MNT6Fp.sqr(a.c1);
        MNT6PairingTypes.Fp memory a2a2 = MNT6Fp.sqr(a.c2);
        MNT6PairingTypes.Fp memory a0a1 = MNT6Fp.mul(a.c0, a.c1);
        MNT6PairingTypes.Fp memory a0a2 = MNT6Fp.mul(a.c0, a.c2);
        MNT6PairingTypes.Fp memory a1a2 = MNT6Fp.mul(a.c1, a.c2);
        r.c0 = MNT6Fp.add(a0a0, MNT6Fp.mulBy11(MNT6Fp.add(a1a2, a1a2)));
        r.c1 = MNT6Fp.add(MNT6Fp.add(a0a1, a0a1), MNT6Fp.mulBy11(a2a2));
        r.c2 = MNT6Fp.add(MNT6Fp.add(a0a2, a0a2), a1a1);
    }

    /// @notice Вычисляет мультипликативно обратное значение: `inv`.
    function inv(MNT6PairingTypes.Fq3 memory a) internal pure returns (MNT6PairingTypes.Fq3 memory r) {
        // For a = a0 + a1*v + a2*v^2 and v^3=11:
        // a^{-1} = (a0^2 - 11*a1*a2, 11*a2^2 - a0*a1, a1^2 - a0*a2) / norm(a).
        MNT6PairingTypes.Fp memory t0 = MNT6Fp.sub(MNT6Fp.sqr(a.c0), MNT6Fp.mulBy11(MNT6Fp.mul(a.c1, a.c2)));
        MNT6PairingTypes.Fp memory t1 = MNT6Fp.sub(MNT6Fp.mulBy11(MNT6Fp.sqr(a.c2)), MNT6Fp.mul(a.c0, a.c1));
        MNT6PairingTypes.Fp memory t2 = MNT6Fp.sub(MNT6Fp.sqr(a.c1), MNT6Fp.mul(a.c0, a.c2));
        MNT6PairingTypes.Fp memory norm = MNT6Fp.add(
            MNT6Fp.mul(a.c0, t0),
            MNT6Fp.mulBy11(MNT6Fp.add(MNT6Fp.mul(a.c2, t1), MNT6Fp.mul(a.c1, t2)))
        );
        MNT6PairingTypes.Fp memory invNorm = MNT6Fp.inv(norm);
        r.c0 = MNT6Fp.mul(t0, invNorm);
        r.c1 = MNT6Fp.mul(t1, invNorm);
        r.c2 = MNT6Fp.mul(t2, invNorm);
    }

    /// @notice Применяет отображение Фробениуса: `_frobeniusC1`.
    function _frobeniusC1(uint256 power) private pure returns (MNT6PairingTypes.Fp memory) {
        if (power == 0) {
            return MNT6Fp.one();
        } else if (power == 1) {
            return MNT6PairingTypes.Fp(
                0x00011d5033223a5db8b087523d7db902b4b96c948f0e9992a75658e33e25f9f0,
                0xe5b38512c92d9f5be660b05c89764d7df480725d1dc6e2f1524a1cc56c78e977,
                0x3f64a98166c46a979bb6f43b5282969c1379b1ebf803e51e6b66f7b83f968680
            );
        } else {
            return MNT6PairingTypes.Fp(
                0x00002c2e5ba7a770c22ca91d916b7315f39babe0941b2dce76ecc64a30e53860,
                0xc8bef1104c8343cf816438c604b125871e2f40c2cc85fb4741955ee7e8c161eb,
                0x6b08f346088b0f329920baa7e003df81ec757f1362138688b409ff15806a0a3f
            );
        }
    }

    /// @notice Применяет отображение Фробениуса: `_frobeniusC2`.
    function _frobeniusC2(uint256 power) private pure returns (MNT6PairingTypes.Fp memory) {
        if (power == 0) return MNT6Fp.one();
        if (power == 1) return _frobeniusC1(2);
        return _frobeniusC1(1);
    }
}
