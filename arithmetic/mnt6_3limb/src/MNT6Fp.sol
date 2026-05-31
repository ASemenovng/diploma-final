// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {BigIntMNT6} from "./BigIntMNT6.sol";
import {MNT6PairingTypes} from "./MNT6PairingTypes.sol";

/// @notice Тонкая оболочка над базовой арифметикой MNT6-753. Она переводит операции над тремя словами в операции над типом Fp.
library MNT6Fp {
    /// @dev Константа `P0` задает слово модуля поля или связанный параметр редукции.
    uint256 internal constant P0 = 0xb9dff97634993aa4d6c381bc3f0057974ea099170fa13a4fd90776e240000001;
    /// @dev Константа `P1` задает слово модуля поля или связанный параметр редукции.
    uint256 internal constant P1 = 0x07fdb925e8a0ed8d99d124d9a15af79db26c5c28c859a99b3eebca9429212636;
    /// @dev Константа `P2` задает слово модуля поля или связанный параметр редукции.
    uint256 internal constant P2 = 0x0001c4c62d92c41110229022eee2cdadb7f997505b8fafed5eb7e8f96c97d873;

    /// @dev Константа `ONE0` содержит соответствующее слово единицы в Montgomery-представлении.
    uint256 internal constant ONE0 = 0x0f725caec549c0daa1ebd2d90c79e1794eb16817b589cea8b99680147fff6f42;
    /// @dev Константа `ONE1` содержит соответствующее слово единицы в Montgomery-представлении.
    uint256 internal constant ONE1 = 0x598b4302d2f00a62320c3bb7133384989fbca908de0ccb62ab0c4ee6d3e6dad4;
    /// @dev Константа `ONE2` содержит соответствующее слово единицы в Montgomery-представлении.
    uint256 internal constant ONE2 = 0x00007b479ec8e24295455fb31ff9a1950fa47edb3865e88c4074c9cbfd8ca621;

    /// @notice Возвращает нулевой элемент в используемом представлении: `zero`.
    function zero() internal pure returns (MNT6PairingTypes.Fp memory r) {}

    /// @notice Возвращает единичный элемент в используемом представлении: `one`.
    function one() internal pure returns (MNT6PairingTypes.Fp memory r) {
        r = _fromLe(ONE0, ONE1, ONE2);
    }

    /// @notice Выполняет внутреннюю операцию `fromUint`; параметры и результат используют представление текущей библиотеки.
    function fromUint(uint256 x) internal pure returns (MNT6PairingTypes.Fp memory r) {
        uint256[3] memory c = [x, uint256(0), uint256(0)];
        uint256[3] memory m = BigIntMNT6.toMontgomery(c);
        r = _fromLe(m[0], m[1], m[2]);
    }

    /// @notice Сравнивает два значения без изменения входных данных: `eq`.
    function eq(MNT6PairingTypes.Fp memory a, MNT6PairingTypes.Fp memory b) internal pure returns (bool) {
        return a.d0 == b.d0 && a.d1 == b.d1 && a.d2 == b.d2;
    }

    /// @notice Возвращает нулевой элемент в используемом представлении: `isZero`.
    function isZero(MNT6PairingTypes.Fp memory a) internal pure returns (bool) {
        return (a.d0 | a.d1 | a.d2) == 0;
    }

    /// @notice Проверяет корректность представления или принадлежность кривой: `isValid`.
    function isValid(MNT6PairingTypes.Fp memory a) internal pure returns (bool) {
        if (a.d2 > P2) return false;
        if (a.d2 < P2) return true;
        if (a.d1 > P1) return false;
        if (a.d1 < P1) return true;
        return a.d0 < P0;
    }

    /// @notice Выполняет сложение `add` с учетом модуля или структуры текущего поля.
    function add(MNT6PairingTypes.Fp memory a, MNT6PairingTypes.Fp memory b)
        internal pure returns (MNT6PairingTypes.Fp memory r)
    {
        (uint256 r0, uint256 r1, uint256 r2) = BigIntMNT6.add3(a.d0, a.d1, a.d2, b.d0, b.d1, b.d2);
        r = _fromLe(r0, r1, r2);
    }

    /// @notice Выполняет вычитание `sub` с учетом модуля или структуры текущего поля.
    function sub(MNT6PairingTypes.Fp memory a, MNT6PairingTypes.Fp memory b)
        internal pure returns (MNT6PairingTypes.Fp memory r)
    {
        (uint256 r0, uint256 r1, uint256 r2) = BigIntMNT6.sub3(a.d0, a.d1, a.d2, b.d0, b.d1, b.d2);
        r = _fromLe(r0, r1, r2);
    }

    /// @notice Вычисляет аддитивно обратное значение: `neg`.
    function neg(MNT6PairingTypes.Fp memory a) internal pure returns (MNT6PairingTypes.Fp memory r) {
        (uint256 r0, uint256 r1, uint256 r2) = BigIntMNT6.sub3(0, 0, 0, a.d0, a.d1, a.d2);
        r = _fromLe(r0, r1, r2);
    }

    /// @notice Выполняет умножение `mul`; точный уровень поля и специальный множитель отражены в названии.
    function mul(MNT6PairingTypes.Fp memory a, MNT6PairingTypes.Fp memory b)
        internal pure returns (MNT6PairingTypes.Fp memory r)
    {
        (uint256 r0, uint256 r1, uint256 r2) = BigIntMNT6.montMul3(a.d0, a.d1, a.d2, b.d0, b.d1, b.d2);
        r = _fromLe(r0, r1, r2);
    }

    /// @notice Возводит значение в квадрат: `sqr`.
    function sqr(MNT6PairingTypes.Fp memory a) internal pure returns (MNT6PairingTypes.Fp memory r) {
        (uint256 r0, uint256 r1, uint256 r2) = BigIntMNT6.montSqr3(a.d0, a.d1, a.d2);
        r = _fromLe(r0, r1, r2);
    }

    /// @notice Вычисляет мультипликативно обратное значение: `inv`.
    function inv(MNT6PairingTypes.Fp memory a) internal pure returns (MNT6PairingTypes.Fp memory r) {
        (uint256 r0, uint256 r1, uint256 r2) = BigIntMNT6.inv3(a.d0, a.d1, a.d2);
        r = _fromLe(r0, r1, r2);
    }

    /// @notice Выполняет умножение `mulBy11`; точный уровень поля и специальный множитель отражены в названии.
    function mulBy11(MNT6PairingTypes.Fp memory a) internal pure returns (MNT6PairingTypes.Fp memory r) {
        (uint256 r0, uint256 r1, uint256 r2) = BigIntMNT6.mulBy11(a.d0, a.d1, a.d2);
        r = _fromLe(r0, r1, r2);
    }

    /// @notice Выполняет внутреннюю операцию `_fromLe`; параметры и результат используют представление текущей библиотеки.
    function _fromLe(uint256 d0, uint256 d1, uint256 d2) private pure returns (MNT6PairingTypes.Fp memory r) {
        r.d0 = d0;
        r.d1 = d1;
        r.d2 = d2;
    }
}
