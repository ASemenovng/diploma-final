// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

/// @notice Экспериментальная Montgomery-арифметика MNT4-753 по схеме FIOS.
/// @dev Отделена от чистовой CIOS-реализации и предназначена для прозрачного сравнения,
///      а не для замены проверенного наиболее затратного пути.
library BigIntMNTFIOS {
    /// @dev Константа `P_0` задает слово модуля поля или связанный параметр редукции.
    uint256 private constant P_0 = 0x685acce9767254a4638810719ac425f0e39d54522cdd119f5e9063de245e8001;
    /// @dev Константа `P_1` задает слово модуля поля или связанный параметр редукции.
    uint256 private constant P_1 = 0x7fdb925e8a0ed8d99d124d9a15af79db117e776f218059db80f0da5cb537e38;
    /// @dev Константа `P_2` задает слово модуля поля или связанный параметр редукции.
    uint256 private constant P_2 = 0x1c4c62d92c41110229022eee2cdadb7f997505b8fafed5eb7e8f96c97d873;
    /// @dev Константа `MAGIC` содержит коэффициент Montgomery-редукции: отрицательное обратное к младшему слову модуля по модулю 2^256.
    uint256 private constant MAGIC = 0x4adb7a6352a3a656d9e1947eee113b7a7fd403903e304c4cf2044cfbe45e7fff;

    /// @notice Возводит значение в квадрат: `montSqr3`.
    function montSqr3(uint256 a0, uint256 a1, uint256 a2)
        internal pure returns (uint256 r0, uint256 r1, uint256 r2)
    {
        return montMul3(a0, a1, a2, a0, a1, a2);
    }

    /// @notice Выполняет умножение `montMul3`; точный уровень поля и специальный множитель отражены в названии.
    function montMul3(
        uint256 a0, uint256 a1, uint256 a2,
        uint256 b0, uint256 b1, uint256 b2
    ) internal pure returns (uint256 r0, uint256 r1, uint256 r2) {
        uint256[4] memory t;
        uint256[3] memory a = [a0, a1, a2];
        uint256[3] memory b = [b0, b1, b2];
        uint256[3] memory p = [P_0, P_1, P_2];

        for (uint256 i; i < 3; ) {
            // Тесная интеграция: множитель редукции вычисляется сразу после первого произведения, задающего t0.
            (uint256 lo, uint256 hi) = _mul512(a[i], b[0]);
            _addAt4(t, 0, lo);
            _addAt4(t, 1, hi);
            uint256 m;
            unchecked {
                m = t[0] * MAGIC;
            }

            (lo, hi) = _mul512(m, p[0]);
            _addAt4(t, 0, lo);
            _addAt4(t, 1, hi);

            for (uint256 j = 1; j < 3; ) {
                (lo, hi) = _mul512(a[i], b[j]);
                _addAt4(t, j, lo);
                _addAt4(t, j + 1, hi);

                (lo, hi) = _mul512(m, p[j]);
                _addAt4(t, j, lo);
                _addAt4(t, j + 1, hi);
                unchecked { ++j; }
            }

            // Младшее слово равно нулю по модулю B; делим значение на B.
            t[0] = t[1];
            t[1] = t[2];
            t[2] = t[3];
            t[3] = 0;
            unchecked { ++i; }
        }

        if (_geP(t)) {
            _subP(t);
        }
        return (t[0], t[1], t[2]);
    }

    /// @notice Выполняет умножение `_mul512`; точный уровень поля и специальный множитель отражены в названии.
    function _mul512(uint256 u, uint256 v) private pure returns (uint256 lo, uint256 hi) {
        assembly ("memory-safe") {
            lo := mul(u, v)
            let mm := mulmod(u, v, not(0))
            hi := sub(sub(mm, lo), lt(mm, lo))
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
