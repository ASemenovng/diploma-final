// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

/// @notice Экспериментальная арифметика MNT4-753 с Barrett-редукцией в каноническом представлении.
/// @dev Библиотека намеренно отделена от чистового Montgomery-пути.
///      Она нужна только для сравнения корректности и стоимости gas в исследовании.
library BigIntMNTBarrett {
    /// @dev Константа `P_0` задает слово модуля поля или связанный параметр редукции.
    uint256 private constant P_0 = 0x685acce9767254a4638810719ac425f0e39d54522cdd119f5e9063de245e8001;
    /// @dev Константа `P_1` задает слово модуля поля или связанный параметр редукции.
    uint256 private constant P_1 = 0x7fdb925e8a0ed8d99d124d9a15af79db117e776f218059db80f0da5cb537e38;
    /// @dev Константа `P_2` задает слово модуля поля или связанный параметр редукции.
    uint256 private constant P_2 = 0x1c4c62d92c41110229022eee2cdadb7f997505b8fafed5eb7e8f96c97d873;

    // mu=floor(2^(2*3*256)/p), 256-битные слова от младшего к старшему.
    uint256 private constant MU_0 = 0xdcadd560309f1347c7d5ea5a84517732576a460d27d25968abba3f5d42026f38;
    /// @dev Константа `MU_1` фиксирует параметр алгоритма; значение не изменяется во время выполнения.
    uint256 private constant MU_1 = 0xe8c0383b7865972fdcbc2aa6fc0d1e7560c9b8f015490661278f1c5c76148a08;
    /// @dev Константа `MU_2` фиксирует параметр алгоритма; значение не изменяется во время выполнения.
    uint256 private constant MU_2 = 0x45b3ea09c9f1babbce015aaa82abb6c15d19fee4cb2b8aaea69745f07fdcd4e2;
    /// @dev Константа `MU_3` фиксирует параметр алгоритма; значение не изменяется во время выполнения.
    uint256 private constant MU_3 = 0x00000000000000000000000000000000000000000000000000000000000090be;

    /// @notice Возводит значение в квадрат: `sqr3`.
    function sqr3(uint256 a0, uint256 a1, uint256 a2)
        internal pure returns (uint256 r0, uint256 r1, uint256 r2)
    {
        return mul3(a0, a1, a2, a0, a1, a2);
    }

    /// @notice Выполняет умножение `mul3`; точный уровень поля и специальный множитель отражены в названии.
    function mul3(
        uint256 a0, uint256 a1, uint256 a2,
        uint256 b0, uint256 b1, uint256 b2
    ) internal pure returns (uint256 r0, uint256 r1, uint256 r2) {
        uint256[6] memory x;
        _mul3x3(x, a0, a1, a2, b0, b1, b2);
        return _barrettReduce6(x);
    }

    /// @notice Выполняет умножение `_mul512`; точный уровень поля и специальный множитель отражены в названии.
    function _mul512(uint256 u, uint256 v) private pure returns (uint256 lo, uint256 hi) {
        assembly ("memory-safe") {
            lo := mul(u, v)
            let mm := mulmod(u, v, not(0))
            hi := sub(sub(mm, lo), lt(mm, lo))
        }
    }

    /// @notice Выполняет сложение `_addAt6` с учетом модуля или структуры текущего поля.
    function _addAt6(uint256[6] memory acc, uint256 idx, uint256 value) private pure {
        if (value == 0 || idx >= 6) return;
        unchecked {
            uint256 old = acc[idx];
            uint256 sum = old + value;
            acc[idx] = sum;
            uint256 carry = sum < old ? 1 : 0;
            while (carry != 0 && ++idx < 6) {
                old = acc[idx];
                sum = old + carry;
                acc[idx] = sum;
                carry = sum < old ? 1 : 0;
            }
        }
    }

    /// @notice Выполняет сложение `_addAt8` с учетом модуля или структуры текущего поля.
    function _addAt8(uint256[8] memory acc, uint256 idx, uint256 value) private pure {
        if (value == 0 || idx >= 8) return;
        unchecked {
            uint256 old = acc[idx];
            uint256 sum = old + value;
            acc[idx] = sum;
            uint256 carry = sum < old ? 1 : 0;
            while (carry != 0 && ++idx < 8) {
                old = acc[idx];
                sum = old + carry;
                acc[idx] = sum;
                carry = sum < old ? 1 : 0;
            }
        }
    }

    /// @notice Выполняет сложение `_addAt4` с учетом модуля или структуры текущего поля.
    function _addAt4(uint256[4] memory acc, uint256 idx, uint256 value) private pure {
        if (value == 0 || idx >= 4) return;
        unchecked {
            uint256 old = acc[idx];
            uint256 sum = old + value;
            acc[idx] = sum;
            uint256 carry = sum < old ? 1 : 0;
            while (carry != 0 && ++idx < 4) {
                old = acc[idx];
                sum = old + carry;
                acc[idx] = sum;
                carry = sum < old ? 1 : 0;
            }
        }
    }

    /// @notice Выполняет умножение `_mul3x3`; точный уровень поля и специальный множитель отражены в названии.
    function _mul3x3(
        uint256[6] memory out,
        uint256 a0, uint256 a1, uint256 a2,
        uint256 b0, uint256 b1, uint256 b2
    ) private pure {
        uint256[3] memory a = [a0, a1, a2];
        uint256[3] memory b = [b0, b1, b2];
        for (uint256 i; i < 3; ) {
            for (uint256 j; j < 3; ) {
                (uint256 lo, uint256 hi) = _mul512(a[i], b[j]);
                _addAt6(out, i + j, lo);
                _addAt6(out, i + j + 1, hi);
                unchecked { ++j; }
            }
            unchecked { ++i; }
        }
    }

    /// @notice Выполняет внутреннюю операцию `_barrettReduce6`; параметры и результат используют представление текущей библиотеки.
    function _barrettReduce6(uint256[6] memory x) private pure returns (uint256 r0, uint256 r1, uint256 r2) {
        // q1 = floor(x / B^(k-1)) for k=3: limbs x2..x5.
        uint256[4] memory q1 = [x[2], x[3], x[4], x[5]];
        uint256[4] memory mu = [MU_0, MU_1, MU_2, MU_3];

        // q2 = q1 * mu; q3 = floor(q2 / B^(k+1)) = high limbs 4..7.
        uint256[8] memory q2;
        for (uint256 i; i < 4; ) {
            for (uint256 j; j < 4; ) {
                (uint256 lo, uint256 hi) = _mul512(q1[i], mu[j]);
                _addAt8(q2, i + j, lo);
                _addAt8(q2, i + j + 1, hi);
                unchecked { ++j; }
            }
            unchecked { ++i; }
        }
        uint256[4] memory q3 = [q2[4], q2[5], q2[6], q2[7]];

        // r1 = x mod B^(k+1); r2 = (q3 * p) mod B^(k+1).
        uint256[4] memory r = [x[0], x[1], x[2], x[3]];
        uint256[4] memory qpLow;
        uint256[3] memory p = [P_0, P_1, P_2];
        for (uint256 i; i < 4; ) {
            for (uint256 j; j < 3; ) {
                if (i + j < 4) {
                    (uint256 lo, uint256 hi) = _mul512(q3[i], p[j]);
                    _addAt4(qpLow, i + j, lo);
                    _addAt4(qpLow, i + j + 1, hi);
                }
                unchecked { ++j; }
            }
            unchecked { ++i; }
        }

        _sub4ModB4(r, qpLow);

        // Barrett's bound gives a small number of corrections; four is conservative for k=3.
        for (uint256 i; i < 4 && _geP(r); ) {
            _subP(r);
            unchecked { ++i; }
        }
        return (r[0], r[1], r[2]);
    }

    /// @notice Выполняет вычитание `_sub4ModB4` с учетом модуля или структуры текущего поля.
    function _sub4ModB4(uint256[4] memory a, uint256[4] memory b) private pure {
        unchecked {
            uint256 borrow;
            for (uint256 i; i < 4; ++i) {
                uint256 bi = b[i] + borrow;
                uint256 nextBorrow = (bi < b[i] || a[i] < bi) ? 1 : 0;
                a[i] = a[i] - bi;
                borrow = nextBorrow;
            }
        }
    }

    /// @notice Выполняет внутреннюю операцию `_geP`; параметры и результат используют представление текущей библиотеки.
    function _geP(uint256[4] memory a) private pure returns (bool) {
        if (a[3] != 0) return true;
        if (a[2] != P_2) return a[2] > P_2;
        if (a[1] != P_1) return a[1] > P_1;
        return a[0] >= P_0;
    }

    /// @notice Выполняет вычитание `_subP` с учетом модуля или структуры текущего поля.
    function _subP(uint256[4] memory a) private pure {
        unchecked {
            uint256 b = P_0;
            uint256 borrow = a[0] < b ? 1 : 0;
            a[0] = a[0] - b;
            b = P_1 + borrow;
            borrow = (b < P_1 || a[1] < b) ? 1 : 0;
            a[1] = a[1] - b;
            b = P_2 + borrow;
            borrow = (b < P_2 || a[2] < b) ? 1 : 0;
            a[2] = a[2] - b;
            a[3] = a[3] - borrow;
        }
    }
}
