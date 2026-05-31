// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

/// @notice Экспериментальная специализация Comba/SOS Montgomery-редукции для возведения MNT4-753 в квадрат.
/// @dev Вариант не входит в чистовой путь. Он проверяет, компенсирует ли экономия трех симметричных
///      произведений 256x256 материализацию полного произведения перед REDC.
library BigIntMNTSquareComba {
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
        uint256[8] memory t;

        _addMulAt(t, 0, a0, a0);
        _addMulAtDouble(t, 1, a0, a1);
        _addMulAtDouble(t, 2, a0, a2);
        _addMulAt(t, 2, a1, a1);
        _addMulAtDouble(t, 3, a1, a2);
        _addMulAt(t, 4, a2, a2);

        _redc3(t);
        r0 = t[3];
        r1 = t[4];
        r2 = t[5];

        if (_gePWithHi(t[6], r0, r1, r2)) {
            (r0, r1, r2) = _subP(r0, r1, r2);
        }
    }

    /// @notice Выполняет внутреннюю операцию `_redc3`; параметры и результат используют представление текущей библиотеки.
    function _redc3(uint256[8] memory t) private pure {
        unchecked {
            for (uint256 i; i < 3; ++i) {
                uint256 m = t[i] * MAGIC;
                _addMulAt(t, i, m, P_0);
                _addMulAt(t, i + 1, m, P_1);
                _addMulAt(t, i + 2, m, P_2);
            }
        }
    }

    /// @notice Выполняет умножение `_addMulAtDouble`; точный уровень поля и специальный множитель отражены в названии.
    function _addMulAtDouble(uint256[8] memory acc, uint256 idx, uint256 u, uint256 v) private pure {
        (uint256 lo, uint256 hi) = _mul512(u, v);
        _addAt(acc, idx, lo);
        _addAt(acc, idx, lo);
        _addAt(acc, idx + 1, hi);
        _addAt(acc, idx + 1, hi);
    }

    /// @notice Выполняет умножение `_addMulAt`; точный уровень поля и специальный множитель отражены в названии.
    function _addMulAt(uint256[8] memory acc, uint256 idx, uint256 u, uint256 v) private pure {
        (uint256 lo, uint256 hi) = _mul512(u, v);
        _addAt(acc, idx, lo);
        _addAt(acc, idx + 1, hi);
    }

    /// @notice Выполняет умножение `_mul512`; точный уровень поля и специальный множитель отражены в названии.
    function _mul512(uint256 u, uint256 v) private pure returns (uint256 lo, uint256 hi) {
        assembly ("memory-safe") {
            lo := mul(u, v)
            let mm := mulmod(u, v, not(0))
            hi := sub(sub(mm, lo), lt(mm, lo))
        }
    }

    /// @notice Выполняет сложение `_addAt` с учетом модуля или структуры текущего поля.
    function _addAt(uint256[8] memory acc, uint256 idx, uint256 value) private pure {
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

    /// @notice Выполняет внутреннюю операцию `_gePWithHi`; параметры и результат используют представление текущей библиотеки.
    function _gePWithHi(uint256 hi, uint256 a0, uint256 a1, uint256 a2) private pure returns (bool) {
        if (hi != 0) return true;
        if (a2 != P_2) return a2 > P_2;
        if (a1 != P_1) return a1 > P_1;
        return a0 >= P_0;
    }

    /// @notice Выполняет вычитание `_subP` с учетом модуля или структуры текущего поля.
    function _subP(uint256 a0, uint256 a1, uint256 a2)
        private pure returns (uint256 r0, uint256 r1, uint256 r2)
    {
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
            r2, bor := sbb(a2, P_2, bor)
        }
    }
}
