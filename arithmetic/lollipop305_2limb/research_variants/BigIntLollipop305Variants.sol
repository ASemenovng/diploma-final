// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

/// @notice Экспериментальные варианты базовой арифметики lollipop-305 для сравнительных измерений,
/// а не выбранный чистовой путь.
library BigIntLollipop305Comba {
    /// @dev Константа `P_0` задает слово модуля поля или связанный параметр редукции.
    uint256 private constant P_0 = 0x24240b65671ab020b2f03c6035ed8fdcdd1ff464dbb7022f6583adbbb2fef163;
    /// @dev Константа `P_1` задает слово модуля поля или связанный параметр редукции.
    uint256 private constant P_1 = 0x1f733286263df;
    /// @dev Константа `MAGIC` содержит коэффициент Montgomery-редукции: отрицательное обратное к младшему слову модуля по модулю 2^256.
    uint256 private constant MAGIC = 0x6e556cf83eca6b341f73774b5f2335446538fb72d518b484d4357e144505e7b5;

    /// @notice Возводит значение в квадрат: `montSqr2`.
    function montSqr2(uint256 a0, uint256 a1) internal pure returns (uint256 r0, uint256 r1) {
        return montMul2(a0, a1, a0, a1);
    }

    /// @notice Выполняет умножение `montMul2`; точный уровень поля и специальный множитель отражены в названии.
    function montMul2(uint256 a0, uint256 a1, uint256 b0, uint256 b1)
        internal pure returns (uint256 r0, uint256 r1)
    {
        uint256[6] memory t;
        _addMulAt(t, 0, a0, b0);
        _addMulAt(t, 1, a0, b1);
        _addMulAt(t, 1, a1, b0);
        _addMulAt(t, 2, a1, b1);
        for (uint256 i; i < 2; ) {
            unchecked {
                uint256 m = t[i] * MAGIC;
                _addMulAt(t, i, m, P_0);
                _addMulAt(t, i + 1, m, P_1);
                ++i;
            }
        }
        r0 = t[2];
        r1 = t[3];
        if (t[4] != 0 || r1 > P_1 || (r1 == P_1 && r0 >= P_0)) {
            (r0, r1) = _subP(r0, r1);
        }
    }

    /// @notice Выполняет умножение `_mul512`; точный уровень поля и специальный множитель отражены в названии.
    function _mul512(uint256 u, uint256 v) private pure returns (uint256 lo, uint256 hi) {
        assembly ("memory-safe") {
            lo := mul(u, v)
            let mm := mulmod(u, v, not(0))
            hi := sub(sub(mm, lo), lt(mm, lo))
        }
    }

    /// @notice Выполняет умножение `_addMulAt`; точный уровень поля и специальный множитель отражены в названии.
    function _addMulAt(uint256[6] memory acc, uint256 idx, uint256 u, uint256 v) private pure {
        (uint256 lo, uint256 hi) = _mul512(u, v);
        _addAt(acc, idx, lo);
        _addAt(acc, idx + 1, hi);
    }

    /// @notice Выполняет сложение `_addAt` с учетом модуля или структуры текущего поля.
    function _addAt(uint256[6] memory acc, uint256 idx, uint256 value) private pure {
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

    /// @notice Выполняет вычитание `_subP` с учетом модуля или структуры текущего поля.
    function _subP(uint256 a0, uint256 a1) private pure returns (uint256 r0, uint256 r1) {
        assembly ("memory-safe") {
            /// @notice Выполняет внутреннюю операцию `sbb`; параметры и результат используют представление текущей библиотеки.
            function sbb(x, y, b) -> rr, bOut {
                let yy := add(y, b)
                rr := sub(x, yy)
                bOut := or(lt(x, yy), lt(yy, y))
            }
            let bor := 0
            r0, bor := sbb(a0, P_0, 0)
            r1, bor := sbb(a1, P_1, bor)
        }
    }
}

/// @notice Компонент `BigIntLollipop305FIOS` входит в набор исследовательских сравнений проекта.
library BigIntLollipop305FIOS {
    /// @dev Константа `P_0` задает слово модуля поля или связанный параметр редукции.
    uint256 private constant P_0 = 0x24240b65671ab020b2f03c6035ed8fdcdd1ff464dbb7022f6583adbbb2fef163;
    /// @dev Константа `P_1` задает слово модуля поля или связанный параметр редукции.
    uint256 private constant P_1 = 0x1f733286263df;
    /// @dev Константа `MAGIC` содержит коэффициент Montgomery-редукции: отрицательное обратное к младшему слову модуля по модулю 2^256.
    uint256 private constant MAGIC = 0x6e556cf83eca6b341f73774b5f2335446538fb72d518b484d4357e144505e7b5;

    /// @notice Возводит значение в квадрат: `montSqr2`.
    function montSqr2(uint256 a0, uint256 a1) internal pure returns (uint256 r0, uint256 r1) {
        return montMul2(a0, a1, a0, a1);
    }

    /// @notice Выполняет умножение `montMul2`; точный уровень поля и специальный множитель отражены в названии.
    function montMul2(uint256 a0, uint256 a1, uint256 b0, uint256 b1)
        internal pure returns (uint256 r0, uint256 r1)
    {
        uint256[3] memory t;
        uint256[2] memory a = [a0, a1];
        uint256[2] memory b = [b0, b1];
        uint256[2] memory p = [P_0, P_1];
        for (uint256 i; i < 2; ) {
            (uint256 lo, uint256 hi) = _mul512(a[i], b[0]);
            _addAt3(t, 0, lo);
            _addAt3(t, 1, hi);
            uint256 m;
            unchecked { m = t[0] * MAGIC; }
            (lo, hi) = _mul512(m, p[0]);
            _addAt3(t, 0, lo);
            _addAt3(t, 1, hi);
            (lo, hi) = _mul512(a[i], b[1]);
            _addAt3(t, 1, lo);
            _addAt3(t, 2, hi);
            (lo, hi) = _mul512(m, p[1]);
            _addAt3(t, 1, lo);
            _addAt3(t, 2, hi);
            t[0] = t[1];
            t[1] = t[2];
            t[2] = 0;
            unchecked { ++i; }
        }
        r0 = t[0]; r1 = t[1];
        if (r1 > P_1 || (r1 == P_1 && r0 >= P_0)) {
            (r0, r1) = _subP(r0, r1);
        }
    }

    /// @notice Выполняет умножение `_mul512`; точный уровень поля и специальный множитель отражены в названии.
    function _mul512(uint256 u, uint256 v) private pure returns (uint256 lo, uint256 hi) {
        assembly ("memory-safe") {
            lo := mul(u, v)
            let mm := mulmod(u, v, not(0))
            hi := sub(sub(mm, lo), lt(mm, lo))
        }
    }

    /// @notice Выполняет сложение `_addAt3` с учетом модуля или структуры текущего поля.
    function _addAt3(uint256[3] memory acc, uint256 idx, uint256 value) private pure {
        if (value == 0 || idx >= 3) return;
        unchecked {
            uint256 old = acc[idx];
            uint256 sum = old + value;
            acc[idx] = sum;
            uint256 carry = sum < old ? 1 : 0;
            while (carry != 0 && ++idx < 3) {
                old = acc[idx];
                sum = old + carry;
                acc[idx] = sum;
                carry = sum < old ? 1 : 0;
            }
        }
    }

    /// @notice Выполняет вычитание `_subP` с учетом модуля или структуры текущего поля.
    function _subP(uint256 a0, uint256 a1) private pure returns (uint256 r0, uint256 r1) {
        assembly ("memory-safe") {
            /// @notice Выполняет внутреннюю операцию `sbb`; параметры и результат используют представление текущей библиотеки.
            function sbb(x, y, b) -> rr, bOut {
                let yy := add(y, b)
                rr := sub(x, yy)
                bOut := or(lt(x, yy), lt(yy, y))
            }
            let bor := 0
            r0, bor := sbb(a0, P_0, 0)
            r1, bor := sbb(a1, P_1, bor)
        }
    }
}

/// @notice Компонент `BigIntLollipop305Barrett` входит в набор исследовательских сравнений проекта.
library BigIntLollipop305Barrett {
    /// @dev Константа `P_0` задает слово модуля поля или связанный параметр редукции.
    uint256 private constant P_0 = 0x24240b65671ab020b2f03c6035ed8fdcdd1ff464dbb7022f6583adbbb2fef163;
    /// @dev Константа `P_1` задает слово модуля поля или связанный параметр редукции.
    uint256 private constant P_1 = 0x1f733286263df;
    /// @dev Константа `MU_0` фиксирует параметр алгоритма; значение не изменяется во время выполнения.
    uint256 private constant MU_0 = 0x22840e74b1baa7af826fc9de54678722e66283f58f894b7cf05969c8ad984baa;
    /// @dev Константа `MU_1` фиксирует параметр алгоритма; значение не изменяется во время выполнения.
    uint256 private constant MU_1 = 0x456663b20064d73e460553481f7c911d530bd9d05d1e4251291b82fa3abb33a3;
    /// @dev Константа `MU_2` фиксирует параметр алгоритма; значение не изменяется во время выполнения.
    uint256 private constant MU_2 = 0x823d0f6a8a047d4fe07962d605841f3a02d10d891c27982a4a9d;

    /// @notice Возводит значение в квадрат: `sqr2`.
    function sqr2(uint256 a0, uint256 a1) internal pure returns (uint256 r0, uint256 r1) {
        return mul2(a0, a1, a0, a1);
    }

    /// @notice Выполняет умножение `mul2`; точный уровень поля и специальный множитель отражены в названии.
    function mul2(uint256 a0, uint256 a1, uint256 b0, uint256 b1)
        internal pure returns (uint256 r0, uint256 r1)
    {
        uint256[4] memory x;
        _addMulAt4(x, 0, a0, b0);
        _addMulAt4(x, 1, a0, b1);
        _addMulAt4(x, 1, a1, b0);
        _addMulAt4(x, 2, a1, b1);
        return _reduce4(x);
    }

    /// @notice Выполняет внутреннюю операцию `_reduce4`; параметры и результат используют представление текущей библиотеки.
    function _reduce4(uint256[4] memory x) private pure returns (uint256 r0, uint256 r1) {
        // Barrett k=2: q1=floor(x/B), q3=floor(q1*mu/B^3).
        uint256[3] memory q1 = [x[1], x[2], x[3]];
        uint256[3] memory mu = [MU_0, MU_1, MU_2];
        uint256[6] memory q2;
        for (uint256 i; i < 3; ) {
            for (uint256 j; j < 3; ) {
                _addMulAt6(q2, i + j, q1[i], mu[j]);
                unchecked { ++j; }
            }
            unchecked { ++i; }
        }
        uint256[3] memory q3 = [q2[3], q2[4], q2[5]];

        uint256[3] memory r = [x[0], x[1], x[2]];
        uint256[3] memory qp;
        _addMulAt3(qp, 0, q3[0], P_0);
        _addMulAt3(qp, 1, q3[0], P_1);
        _addMulAt3(qp, 1, q3[1], P_0);
        _addMulAt3(qp, 2, q3[1], P_1);
        _addMulAt3(qp, 2, q3[2], P_0);
        _sub3ModB3(r, qp);
        for (uint256 i; i < 4 && _geP(r); ) {
            _subP(r);
            unchecked { ++i; }
        }
        return (r[0], r[1]);
    }

    /// @notice Выполняет умножение `_mul512`; точный уровень поля и специальный множитель отражены в названии.
    function _mul512(uint256 u, uint256 v) private pure returns (uint256 lo, uint256 hi) {
        assembly ("memory-safe") {
            lo := mul(u, v)
            let mm := mulmod(u, v, not(0))
            hi := sub(sub(mm, lo), lt(mm, lo))
        }
    }

    /// @notice Выполняет умножение `_addMulAt3`; точный уровень поля и специальный множитель отражены в названии.
    function _addMulAt3(uint256[3] memory acc, uint256 idx, uint256 u, uint256 v) private pure {
        if (idx >= 3) return;
        (uint256 lo, uint256 hi) = _mul512(u, v);
        _addAt3(acc, idx, lo);
        _addAt3(acc, idx + 1, hi);
    }

    /// @notice Выполняет умножение `_addMulAt4`; точный уровень поля и специальный множитель отражены в названии.
    function _addMulAt4(uint256[4] memory acc, uint256 idx, uint256 u, uint256 v) private pure {
        if (idx >= 4) return;
        (uint256 lo, uint256 hi) = _mul512(u, v);
        _addAt4(acc, idx, lo);
        _addAt4(acc, idx + 1, hi);
    }

    /// @notice Выполняет умножение `_addMulAt6`; точный уровень поля и специальный множитель отражены в названии.
    function _addMulAt6(uint256[6] memory acc, uint256 idx, uint256 u, uint256 v) private pure {
        if (idx >= 6) return;
        (uint256 lo, uint256 hi) = _mul512(u, v);
        _addAt6(acc, idx, lo);
        _addAt6(acc, idx + 1, hi);
    }

    /// @notice Выполняет сложение `_addAt3` с учетом модуля или структуры текущего поля.
    function _addAt3(uint256[3] memory acc, uint256 idx, uint256 value) private pure {
        if (value == 0 || idx >= 3) return;
        unchecked {
            uint256 old = acc[idx];
            uint256 sum = old + value;
            acc[idx] = sum;
            uint256 carry = sum < old ? 1 : 0;
            while (carry != 0 && ++idx < 3) {
                old = acc[idx]; sum = old + carry; acc[idx] = sum; carry = sum < old ? 1 : 0;
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
                old = acc[idx]; sum = old + carry; acc[idx] = sum; carry = sum < old ? 1 : 0;
            }
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
                old = acc[idx]; sum = old + carry; acc[idx] = sum; carry = sum < old ? 1 : 0;
            }
        }
    }

    /// @notice Выполняет вычитание `_sub3ModB3` с учетом модуля или структуры текущего поля.
    function _sub3ModB3(uint256[3] memory a, uint256[3] memory b) private pure {
        unchecked {
            uint256 borrow;
            for (uint256 i; i < 3; ++i) {
                uint256 bi = b[i] + borrow;
                uint256 nextBorrow = (bi < b[i] || a[i] < bi) ? 1 : 0;
                a[i] = a[i] - bi;
                borrow = nextBorrow;
            }
        }
    }

    /// @notice Выполняет внутреннюю операцию `_geP`; параметры и результат используют представление текущей библиотеки.
    function _geP(uint256[3] memory a) private pure returns (bool) {
        if (a[2] != 0) return true;
        if (a[1] != P_1) return a[1] > P_1;
        return a[0] >= P_0;
    }

    /// @notice Выполняет вычитание `_subP` с учетом модуля или структуры текущего поля.
    function _subP(uint256[3] memory a) private pure {
        unchecked {
            uint256 b = P_0;
            uint256 borrow = a[0] < b ? 1 : 0;
            a[0] = a[0] - b;
            b = P_1 + borrow;
            borrow = (b < P_1 || a[1] < b) ? 1 : 0;
            a[1] = a[1] - b;
            a[2] = a[2] - borrow;
        }
    }
}
