// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {BigIntMNT6} from "./BigIntMNT6.sol";
import {MNT6PairingTypes} from "./MNT6PairingTypes.sol";

/// @notice Упакованная указательная арифметика для горячего пути MNT6-753.
/// @dev Слова каждого коэффициента расположены от младшего к старшему:
///      Fp  = [d0,d1,d2]
///      Fq3 = [c0(Fp), c1(Fp), c2(Fp)]
///      Fq6 = [c0(Fq3), c1(Fq3)].
library MNT6PackedArithmetic {
    /// @dev Константа `WORD` фиксирует параметр алгоритма; значение не изменяется во время выполнения.
    uint256 internal constant WORD = 0x20;
    /// @dev Константа `FP` фиксирует параметр алгоритма; значение не изменяется во время выполнения.
    uint256 internal constant FP = 0x60;
    /// @dev Константа `FQ3` фиксирует параметр алгоритма; значение не изменяется во время выполнения.
    uint256 internal constant FQ3 = 0x120;
    /// @dev Константа `FQ6` фиксирует параметр алгоритма; значение не изменяется во время выполнения.
    uint256 internal constant FQ6 = 0x240;

    /// @dev Константа `ONE0` содержит соответствующее слово единицы в Montgomery-представлении.
    uint256 internal constant ONE0 = 0x0f725caec549c0daa1ebd2d90c79e1794eb16817b589cea8b99680147fff6f42;
    /// @dev Константа `ONE1` содержит соответствующее слово единицы в Montgomery-представлении.
    uint256 internal constant ONE1 = 0x598b4302d2f00a62320c3bb7133384989fbca908de0ccb62ab0c4ee6d3e6dad4;
    /// @dev Константа `ONE2` содержит соответствующее слово единицы в Montgomery-представлении.
    uint256 internal constant ONE2 = 0x00007b479ec8e24295455fb31ff9a1950fa47edb3865e88c4074c9cbfd8ca621;

    /// @notice Выполняет внутреннюю операцию `arenaPtr`; параметры и результат используют представление текущей библиотеки.
    function arenaPtr(uint256 words) internal pure returns (uint256 p) {
        uint256[] memory arena = new uint256[](words);
        assembly ("memory-safe") {
            p := add(arena, 0x20)
        }
    }

    /// @notice Возвращает нулевой элемент в используемом представлении: `zeroTo`.
    function zeroTo(uint256 out, uint256 bytesLen) internal pure {
        for (uint256 o; o < bytesLen; o += WORD) {
            assembly ("memory-safe") {
                mstore(add(out, o), 0)
            }
        }
    }

    /// @notice Записывает подготовленное значение в целевой буфер: `fpStoreTo`.
    function fpStoreTo(uint256 out, MNT6PairingTypes.Fp memory x) internal pure {
        assembly ("memory-safe") {
            mstore(out, mload(add(x, 0x40)))
            mstore(add(out, 0x20), mload(add(x, 0x20)))
            mstore(add(out, 0x40), mload(x))
        }
    }

    /// @notice Записывает подготовленное значение в целевой буфер: `fq3StoreTo`.
    function fq3StoreTo(uint256 out, MNT6PairingTypes.Fq3 memory x) internal pure {
        fpStoreTo(out, x.c0);
        fpStoreTo(out + FP, x.c1);
        fpStoreTo(out + 2 * FP, x.c2);
    }

    /// @notice Записывает подготовленное значение в целевой буфер: `fq6StoreTo`.
    function fq6StoreTo(uint256 out, MNT6PairingTypes.Fq6 memory x) internal pure {
        fq3StoreTo(out, x.c0);
        fq3StoreTo(out + FQ3, x.c1);
    }

    /// @notice Читает подготовленные данные из указанного источника: `fq6Load`.
    function fq6Load(uint256 p) internal pure returns (MNT6PairingTypes.Fq6 memory r) {
        r.c0 = fq3Load(p);
        r.c1 = fq3Load(p + FQ3);
    }

    /// @notice Читает подготовленные данные из указанного источника: `fq3Load`.
    function fq3Load(uint256 p) internal pure returns (MNT6PairingTypes.Fq3 memory r) {
        r.c0 = fpLoad(p);
        r.c1 = fpLoad(p + FP);
        r.c2 = fpLoad(p + 2 * FP);
    }

    /// @notice Читает подготовленные данные из указанного источника: `fpLoad`.
    function fpLoad(uint256 p) internal pure returns (MNT6PairingTypes.Fp memory r) {
        assembly ("memory-safe") {
            mstore(r, mload(add(p, 0x40)))
            mstore(add(r, 0x20), mload(add(p, 0x20)))
            mstore(add(r, 0x40), mload(p))
        }
    }

    /// @notice Копирует представление значения между буферами памяти: `fpCopyTo`.
    function fpCopyTo(uint256 out, uint256 a) internal pure {
        assembly ("memory-safe") {
            mstore(out, mload(a))
            mstore(add(out, 0x20), mload(add(a, 0x20)))
            mstore(add(out, 0x40), mload(add(a, 0x40)))
        }
    }

    /// @notice Копирует представление значения между буферами памяти: `fq3CopyTo`.
    function fq3CopyTo(uint256 out, uint256 a) internal pure {
        fpCopyTo(out, a);
        fpCopyTo(out + FP, a + FP);
        fpCopyTo(out + 2 * FP, a + 2 * FP);
    }

    /// @notice Копирует представление значения между буферами памяти: `fq6CopyTo`.
    function fq6CopyTo(uint256 out, uint256 a) internal pure {
        fq3CopyTo(out, a);
        fq3CopyTo(out + FQ3, a + FQ3);
    }

    /// @notice Возвращает единичный элемент в используемом представлении: `fq6OneTo`.
    function fq6OneTo(uint256 out) internal pure {
        zeroTo(out, FQ6);
        assembly ("memory-safe") {
            mstore(out, ONE0)
            mstore(add(out, 0x20), ONE1)
            mstore(add(out, 0x40), ONE2)
        }
    }

    /// @notice Выполняет сложение `fpAddTo` с учетом модуля или структуры текущего поля.
    function fpAddTo(uint256 out, uint256 a, uint256 b) internal pure {
        (uint256 r0, uint256 r1, uint256 r2) = BigIntMNT6.add3(
            _w(a, 0), _w(a, 1), _w(a, 2), _w(b, 0), _w(b, 1), _w(b, 2)
        );
        _storeFp(out, r0, r1, r2);
    }

    /// @notice Выполняет вычитание `fpSubTo` с учетом модуля или структуры текущего поля.
    function fpSubTo(uint256 out, uint256 a, uint256 b) internal pure {
        (uint256 r0, uint256 r1, uint256 r2) = BigIntMNT6.sub3(
            _w(a, 0), _w(a, 1), _w(a, 2), _w(b, 0), _w(b, 1), _w(b, 2)
        );
        _storeFp(out, r0, r1, r2);
    }

    /// @notice Вычисляет аддитивно обратное значение: `fpNegTo`.
    function fpNegTo(uint256 out, uint256 a) internal pure {
        (uint256 r0, uint256 r1, uint256 r2) = BigIntMNT6.sub3(0, 0, 0, _w(a, 0), _w(a, 1), _w(a, 2));
        _storeFp(out, r0, r1, r2);
    }

    /// @notice Выполняет умножение `fpMulTo`; точный уровень поля и специальный множитель отражены в названии.
    function fpMulTo(uint256 out, uint256 a, uint256 b) internal pure {
        (uint256 r0, uint256 r1, uint256 r2) = BigIntMNT6.montMul3(
            _w(a, 0), _w(a, 1), _w(a, 2), _w(b, 0), _w(b, 1), _w(b, 2)
        );
        _storeFp(out, r0, r1, r2);
    }

    /// @notice Возводит значение в квадрат: `fpSqrTo`.
    function fpSqrTo(uint256 out, uint256 a) internal pure {
        (uint256 r0, uint256 r1, uint256 r2) = BigIntMNT6.montSqr3(_w(a, 0), _w(a, 1), _w(a, 2));
        _storeFp(out, r0, r1, r2);
    }

    /// @notice Выполняет умножение `fpMulBy11To`; точный уровень поля и специальный множитель отражены в названии.
    function fpMulBy11To(uint256 out, uint256 a) internal pure {
        (uint256 r0, uint256 r1, uint256 r2) = BigIntMNT6.mulBy11(_w(a, 0), _w(a, 1), _w(a, 2));
        _storeFp(out, r0, r1, r2);
    }

    /// @notice Выполняет сложение `fq3AddTo` с учетом модуля или структуры текущего поля.
    function fq3AddTo(uint256 out, uint256 a, uint256 b) internal pure {
        fpAddTo(out, a, b);
        fpAddTo(out + FP, a + FP, b + FP);
        fpAddTo(out + 2 * FP, a + 2 * FP, b + 2 * FP);
    }

    /// @notice Выполняет вычитание `fq3SubTo` с учетом модуля или структуры текущего поля.
    function fq3SubTo(uint256 out, uint256 a, uint256 b) internal pure {
        fpSubTo(out, a, b);
        fpSubTo(out + FP, a + FP, b + FP);
        fpSubTo(out + 2 * FP, a + 2 * FP, b + 2 * FP);
    }

    /// @notice Вычисляет аддитивно обратное значение: `fq3NegTo`.
    function fq3NegTo(uint256 out, uint256 a) internal pure {
        fpNegTo(out, a);
        fpNegTo(out + FP, a + FP);
        fpNegTo(out + 2 * FP, a + 2 * FP);
    }

    /// @notice Выполняет умножение `fq3MulByNonresidueTo`; точный уровень поля и специальный множитель отражены в названии.
    function fq3MulByNonresidueTo(uint256 out, uint256 a) internal pure {
        fpMulBy11To(out, a + 2 * FP);
        fpCopyTo(out + FP, a);
        fpCopyTo(out + 2 * FP, a + FP);
    }

    /// @notice Выполняет умножение `fq3MulTo`; точный уровень поля и специальный множитель отражены в названии.
    function fq3MulTo(uint256 out, uint256 a, uint256 b, uint256 scratch) internal pure {
        uint256 v0 = scratch;
        uint256 v1 = scratch + FP;
        uint256 v2 = scratch + 2 * FP;
        uint256 t0 = scratch + 3 * FP;
        uint256 t1 = scratch + 4 * FP;
        uint256 t2 = scratch + 5 * FP;
        uint256 as_ = scratch + 6 * FP;
        uint256 bs_ = scratch + 7 * FP;

        fpMulTo(v0, a, b);
        fpMulTo(v1, a + FP, b + FP);
        fpMulTo(v2, a + 2 * FP, b + 2 * FP);

        fpAddTo(as_, a + FP, a + 2 * FP);
        fpAddTo(bs_, b + FP, b + 2 * FP);
        fpMulTo(t0, as_, bs_);
        fpSubTo(t0, t0, v1);
        fpSubTo(t0, t0, v2);

        fpAddTo(as_, a, a + FP);
        fpAddTo(bs_, b, b + FP);
        fpMulTo(t1, as_, bs_);
        fpSubTo(t1, t1, v0);
        fpSubTo(t1, t1, v1);

        fpAddTo(as_, a, a + 2 * FP);
        fpAddTo(bs_, b, b + 2 * FP);
        fpMulTo(t2, as_, bs_);
        fpSubTo(t2, t2, v0);
        fpSubTo(t2, t2, v2);

        fpMulBy11To(as_, t0);
        fpAddTo(out, v0, as_);
        fpMulBy11To(as_, v2);
        fpAddTo(out + FP, t1, as_);
        fpAddTo(out + 2 * FP, t2, v1);
    }

    /// @notice Возводит значение в квадрат: `fq3SqrTo`.
    function fq3SqrTo(uint256 out, uint256 a, uint256 scratch) internal pure {
        uint256 a00 = scratch;
        uint256 a11 = scratch + FP;
        uint256 a22 = scratch + 2 * FP;
        uint256 a01 = scratch + 3 * FP;
        uint256 a02 = scratch + 4 * FP;
        uint256 a12 = scratch + 5 * FP;
        uint256 tmp = scratch + 6 * FP;

        fpSqrTo(a00, a);
        fpSqrTo(a11, a + FP);
        fpSqrTo(a22, a + 2 * FP);
        fpMulTo(a01, a, a + FP);
        fpMulTo(a02, a, a + 2 * FP);
        fpMulTo(a12, a + FP, a + 2 * FP);

        fpAddTo(tmp, a12, a12);
        fpMulBy11To(tmp, tmp);
        fpAddTo(out, a00, tmp);
        fpAddTo(tmp, a01, a01);
        fpMulBy11To(a12, a22);
        fpAddTo(out + FP, tmp, a12);
        fpAddTo(tmp, a02, a02);
        fpAddTo(out + 2 * FP, tmp, a11);
    }

    /// @notice Возводит значение в квадрат: `fq6SqrTo`.
    function fq6SqrTo(uint256 out, uint256 a, uint256 scratch) internal pure {
        uint256 a0a0 = scratch;
        uint256 a1a1 = scratch + FQ3;
        uint256 a0a1 = scratch + 2 * FQ3;
        uint256 tmp = scratch + 3 * FQ3;
        uint256 inner = scratch + 4 * FQ3;

        fq3SqrTo(a0a0, a, inner);
        fq3SqrTo(a1a1, a + FQ3, inner);
        fq3MulTo(a0a1, a, a + FQ3, inner);
        fq3MulByNonresidueTo(tmp, a1a1);
        fq3AddTo(out, a0a0, tmp);
        fq3AddTo(out + FQ3, a0a1, a0a1);
    }

    /// @notice Выполняет умножение `fq6MulByLineTo`; точный уровень поля и специальный множитель отражены в названии.
    function fq6MulByLineTo(uint256 out, uint256 a, uint256 b0, uint256 b1, uint256 scratch) internal pure {
        uint256 v0 = scratch;
        uint256 v1 = scratch + FQ3;
        uint256 v2 = scratch + 2 * FQ3;
        uint256 as_ = scratch + 3 * FQ3;
        uint256 bs_ = scratch + 4 * FQ3;
        uint256 tmp = scratch + 5 * FQ3;
        uint256 inner = scratch + 6 * FQ3;

        fq3MulTo(v0, a, b0, inner);
        fq3MulTo(v1, a + FQ3, b1, inner);
        fq3AddTo(as_, a, a + FQ3);
        fq3AddTo(bs_, b0, b1);
        fq3MulTo(v2, as_, bs_, inner);
        fq3MulByNonresidueTo(tmp, v1);
        fq3AddTo(out, v0, tmp);
        fq3SubTo(out + FQ3, v2, v0);
        fq3SubTo(out + FQ3, out + FQ3, v1);
    }

    /// @notice Выполняет умножение `fq6MulTo`; точный уровень поля и специальный множитель отражены в названии.
    function fq6MulTo(uint256 out, uint256 a, uint256 b, uint256 scratch) internal pure {
        fq6MulByLineTo(out, a, b, b + FQ3, scratch);
    }

    /// @notice Читает подготовленные данные из указанного источника: `loadFpFromCalldataBETo`.
    function loadFpFromCalldataBETo(uint256 out, bytes calldata blob, uint256 off) internal pure {
        assembly ("memory-safe") {
            let src := add(blob.offset, off)
            mstore(out, calldataload(add(src, 0x40)))
            mstore(add(out, 0x20), calldataload(add(src, 0x20)))
            mstore(add(out, 0x40), calldataload(src))
        }
    }

    /// @notice Читает подготовленные данные из указанного источника: `loadFq3FromCalldataBETo`.
    function loadFq3FromCalldataBETo(uint256 out, bytes calldata blob, uint256 off) internal pure {
        loadFpFromCalldataBETo(out, blob, off);
        loadFpFromCalldataBETo(out + FP, blob, off + 0x60);
        loadFpFromCalldataBETo(out + 2 * FP, blob, off + 0xc0);
    }

    /// @notice Выполняет внутреннюю операцию `_w`; параметры и результат используют представление текущей библиотеки.
    function _w(uint256 p, uint256 i) private pure returns (uint256 x) {
        assembly ("memory-safe") {
            x := mload(add(p, mul(i, 0x20)))
        }
    }

    /// @notice Записывает подготовленное значение в целевой буфер: `_storeFp`.
    function _storeFp(uint256 out, uint256 r0, uint256 r1, uint256 r2) private pure {
        assembly ("memory-safe") {
            mstore(out, r0)
            mstore(add(out, 0x20), r1)
            mstore(add(out, 0x40), r2)
        }
    }
}
