// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

/// @notice Экспериментальный вариант lollipop-305 без лишних записей t0 в p0-блоках Montgomery-редукции.
library BigIntLollipop305SkipT0 {
    /// @dev Константа `P_0` задает слово модуля поля или связанный параметр редукции.
    uint256 private constant P_0 = 0x24240b65671ab020b2f03c6035ed8fdcdd1ff464dbb7022f6583adbbb2fef163;
    /// @dev Константа `P_1` задает слово модуля поля или связанный параметр редукции.
    uint256 private constant P_1 = 0x1f733286263df;
    /// @dev Константа `R2_0` содержит R^2 mod p и используется для перевода в Montgomery-представление.
    uint256 private constant R2_0 = 0x2135917f9ae921659a3b506d5a57a2c6efc61fd298b48640dfa6e3133833b342;
    /// @dev Константа `R2_1` содержит R^2 mod p и используется для перевода в Montgomery-представление.
    uint256 private constant R2_1 = 0xe53a37530f93;
    /// @dev Константа `MAGIC` содержит коэффициент Montgomery-редукции: отрицательное обратное к младшему слову модуля по модулю 2^256.
    uint256 private constant MAGIC = 0x6e556cf83eca6b341f73774b5f2335446538fb72d518b484d4357e144505e7b5;

    /// @notice Выполняет внутреннюю операцию `P0`; параметры и результат используют представление текущей библиотеки.
    function P0() internal pure returns (uint256) { return P_0; }
    /// @notice Выполняет внутреннюю операцию `P1`; параметры и результат используют представление текущей библиотеки.
    function P1() internal pure returns (uint256) { return P_1; }

    /// @notice Возвращает нулевой элемент в используемом представлении: `isZero2`.
    function isZero2(uint256 a0, uint256 a1) internal pure returns (bool) {
        return (a0 | a1) == 0;
    }

    /// @notice Сравнивает два значения без изменения входных данных: `eq2`.
    function eq2(uint256 a0, uint256 a1, uint256 b0, uint256 b1) internal pure returns (bool) {
        return a0 == b0 && a1 == b1;
    }

    /// @notice Выполняет внутреннюю операцию `reduce2`; параметры и результат используют представление текущей библиотеки.
    function reduce2(uint256 x0, uint256 x1) internal pure returns (uint256 r0, uint256 r1) {
        assembly ("memory-safe") {
            /// @notice Выполняет внутреннюю операцию `sbb`; параметры и результат используют представление текущей библиотеки.
            function sbb(x, y, b) -> rr, bOut {
                let yy := add(y, b)
                rr := sub(x, yy)
                bOut := or(lt(x, yy), lt(yy, y))
            }
            let t0
            let t1
            let bor := 0
            t0, bor := sbb(x0, P_0, 0)
            t1, bor := sbb(x1, P_1, bor)
            if iszero(bor) {
                x0 := t0
                x1 := t1
            }
            r0 := x0
            r1 := x1
        }
    }

    /// @notice Выполняет сложение `add2` с учетом модуля или структуры текущего поля.
    function add2(uint256 a0, uint256 a1, uint256 b0, uint256 b1)
        internal
        pure
        returns (uint256 r0, uint256 r1)
    {
        assembly ("memory-safe") {
            /// @notice Выполняет внутреннюю операцию `adc`; параметры и результат используют представление текущей библиотеки.
            function adc(x, y, c) -> rr, cOut {
                let s := add(x, y)
                let c1 := lt(s, x)
                rr := add(s, c)
                let c2 := lt(rr, s)
                cOut := or(c1, c2)
            }
            /// @notice Выполняет внутреннюю операцию `sbb`; параметры и результат используют представление текущей библиотеки.
            function sbb(x, y, b) -> rr, bOut {
                let yy := add(y, b)
                rr := sub(x, yy)
                bOut := or(lt(x, yy), lt(yy, y))
            }
            let c := 0
            r0, c := adc(a0, b0, 0)
            r1, c := adc(a1, b1, c)
            let ge := c
            if iszero(ge) {
                if gt(r1, P_1) { ge := 1 }
                if eq(r1, P_1) {
                    if iszero(lt(r0, P_0)) { ge := 1 }
                }
            }
            if ge {
                let bor := 0
                r0, bor := sbb(r0, P_0, 0)
                r1, bor := sbb(r1, P_1, bor)
            }
        }
    }

    /// @notice Выполняет вычитание `sub2` с учетом модуля или структуры текущего поля.
    function sub2(uint256 a0, uint256 a1, uint256 b0, uint256 b1)
        internal
        pure
        returns (uint256 r0, uint256 r1)
    {
        assembly ("memory-safe") {
            /// @notice Выполняет внутреннюю операцию `sbb`; параметры и результат используют представление текущей библиотеки.
            function sbb(x, y, b) -> rr, bOut {
                let yy := add(y, b)
                rr := sub(x, yy)
                bOut := or(lt(x, yy), lt(yy, y))
            }
            /// @notice Выполняет внутреннюю операцию `adc`; параметры и результат используют представление текущей библиотеки.
            function adc(x, y, c) -> rr, cOut {
                let s := add(x, y)
                let c1 := lt(s, x)
                rr := add(s, c)
                let c2 := lt(rr, s)
                cOut := or(c1, c2)
            }
            let bor := 0
            r0, bor := sbb(a0, b0, 0)
            r1, bor := sbb(a1, b1, bor)
            if bor {
                let c := 0
                r0, c := adc(r0, P_0, 0)
                r1, c := adc(r1, P_1, c)
            }
        }
    }

    /// @notice Вычисляет аддитивно обратное значение: `neg2`.
    function neg2(uint256 a0, uint256 a1) internal pure returns (uint256 r0, uint256 r1) {
        if ((a0 | a1) == 0) return (0, 0);
        return sub2(0, 0, a0, a1);
    }

    /// @notice Выполняет умножение `montMul2`; точный уровень поля и специальный множитель отражены в названии.
    function montMul2(uint256 a0, uint256 a1, uint256 b0, uint256 b1)
        internal
        pure
        returns (uint256 r0, uint256 r1)
    {
        assembly ("memory-safe") {
            /// @notice Выполняет умножение `mul512`; точный уровень поля и специальный множитель отражены в названии.
            function mul512(u, v) -> lo, hi {
                lo := mul(u, v)
                let mm := mulmod(u, v, not(0))
                hi := sub(sub(mm, lo), lt(mm, lo))
            }
            /// @notice Выполняет внутреннюю операцию `sbb`; параметры и результат используют представление текущей библиотеки.
            function sbb(x, y, b) -> rr, bOut {
                let yy := add(y, b)
                rr := sub(x, yy)
                bOut := or(lt(x, yy), lt(yy, y))
            }
            let p0 := P_0
            let p1 := P_1
            let magic := MAGIC
            let t0 := 0
            let t1 := 0
            let t2 := 0

            {
                let u := a0
                {
                    let lo, hi := mul512(u, b0)
                    t0 := add(t0, lo)
                    let c := lt(t0, lo)
                    let old := t1
                    t1 := add(t1, hi)
                    t2 := add(t2, lt(t1, old))
                    old := t1
                    t1 := add(t1, c)
                    t2 := add(t2, lt(t1, old))
                }
                {
                    let lo, hi := mul512(u, b1)
                    t1 := add(t1, lo)
                    let c := lt(t1, lo)
                    t2 := add(t2, hi)
                    t2 := add(t2, c)
                }
                let m := mul(t0, magic)
                {
                    let lo, hi := mul512(m, p0)
                    let c := lt(add(t0, lo), lo)
                    let old := t1
                    t1 := add(t1, hi)
                    t2 := add(t2, lt(t1, old))
                    old := t1
                    t1 := add(t1, c)
                    t2 := add(t2, lt(t1, old))
                }
                {
                    let lo, hi := mul512(m, p1)
                    t1 := add(t1, lo)
                    let c := lt(t1, lo)
                    t2 := add(t2, hi)
                    t2 := add(t2, c)
                }
            }
            t0 := t1
            t1 := t2
            t2 := 0
            {
                let u := a1
                {
                    let lo, hi := mul512(u, b0)
                    t0 := add(t0, lo)
                    let c := lt(t0, lo)
                    let old := t1
                    t1 := add(t1, hi)
                    t2 := add(t2, lt(t1, old))
                    old := t1
                    t1 := add(t1, c)
                    t2 := add(t2, lt(t1, old))
                }
                {
                    let lo, hi := mul512(u, b1)
                    t1 := add(t1, lo)
                    let c := lt(t1, lo)
                    t2 := add(t2, hi)
                    t2 := add(t2, c)
                }
                let m := mul(t0, magic)
                {
                    let lo, hi := mul512(m, p0)
                    let c := lt(add(t0, lo), lo)
                    let old := t1
                    t1 := add(t1, hi)
                    t2 := add(t2, lt(t1, old))
                    old := t1
                    t1 := add(t1, c)
                    t2 := add(t2, lt(t1, old))
                }
                {
                    let lo, hi := mul512(m, p1)
                    t1 := add(t1, lo)
                    let c := lt(t1, lo)
                    t2 := add(t2, hi)
                    t2 := add(t2, c)
                }
            }
            t0 := t1
            t1 := t2
            let ge := 0
            if gt(t1, p1) { ge := 1 }
            if eq(t1, p1) {
                if iszero(lt(t0, p0)) { ge := 1 }
            }
            if ge {
                let bor := 0
                t0, bor := sbb(t0, p0, 0)
                t1, bor := sbb(t1, p1, bor)
            }
            r0 := t0
            r1 := t1
        }
    }

    /// @notice Возводит значение в квадрат: `montSqr2`.
    function montSqr2(uint256 a0, uint256 a1) internal pure returns (uint256 r0, uint256 r1) {
        assembly ("memory-safe") {
            /// @notice Выполняет умножение `mul512`; точный уровень поля и специальный множитель отражены в названии.
            function mul512(u, v) -> lo, hi {
                lo := mul(u, v)
                let mm := mulmod(u, v, not(0))
                hi := sub(sub(mm, lo), lt(mm, lo))
            }
            /// @notice Выполняет внутреннюю операцию `sbb`; параметры и результат используют представление текущей библиотеки.
            function sbb(x, y, b) -> rr, bOut {
                let yy := add(y, b)
                rr := sub(x, yy)
                bOut := or(lt(x, yy), lt(yy, y))
            }
            let p0 := P_0
            let p1 := P_1
            let magic := MAGIC
            let t0 := 0
            let t1 := 0
            let t2 := 0

            let cLo, cHi := mul512(a0, a1)

            {
                {
                    let lo, hi := mul512(a0, a0)
                    t0 := add(t0, lo)
                    let c := lt(t0, lo)
                    let old := t1
                    t1 := add(t1, hi)
                    t2 := add(t2, lt(t1, old))
                    old := t1
                    t1 := add(t1, c)
                    t2 := add(t2, lt(t1, old))
                }
                {
                    t1 := add(t1, cLo)
                    let c := lt(t1, cLo)
                    t2 := add(t2, cHi)
                    t2 := add(t2, c)
                }
                let m := mul(t0, magic)
                {
                    let lo, hi := mul512(m, p0)
                    let c := lt(add(t0, lo), lo)
                    let old := t1
                    t1 := add(t1, hi)
                    t2 := add(t2, lt(t1, old))
                    old := t1
                    t1 := add(t1, c)
                    t2 := add(t2, lt(t1, old))
                }
                {
                    let lo, hi := mul512(m, p1)
                    t1 := add(t1, lo)
                    let c := lt(t1, lo)
                    t2 := add(t2, hi)
                    t2 := add(t2, c)
                }
            }
            t0 := t1
            t1 := t2
            t2 := 0
            {
                {
                    t0 := add(t0, cLo)
                    let c := lt(t0, cLo)
                    let old := t1
                    t1 := add(t1, cHi)
                    t2 := add(t2, lt(t1, old))
                    old := t1
                    t1 := add(t1, c)
                    t2 := add(t2, lt(t1, old))
                }
                {
                    let lo, hi := mul512(a1, a1)
                    t1 := add(t1, lo)
                    let c := lt(t1, lo)
                    t2 := add(t2, hi)
                    t2 := add(t2, c)
                }
                let m := mul(t0, magic)
                {
                    let lo, hi := mul512(m, p0)
                    let c := lt(add(t0, lo), lo)
                    let old := t1
                    t1 := add(t1, hi)
                    t2 := add(t2, lt(t1, old))
                    old := t1
                    t1 := add(t1, c)
                    t2 := add(t2, lt(t1, old))
                }
                {
                    let lo, hi := mul512(m, p1)
                    t1 := add(t1, lo)
                    let c := lt(t1, lo)
                    t2 := add(t2, hi)
                    t2 := add(t2, c)
                }
            }
            t0 := t1
            t1 := t2
            let ge := 0
            if gt(t1, p1) { ge := 1 }
            if eq(t1, p1) {
                if iszero(lt(t0, p0)) { ge := 1 }
            }
            if ge {
                let bor := 0
                t0, bor := sbb(t0, p0, 0)
                t1, bor := sbb(t1, p1, bor)
            }
            r0 := t0
            r1 := t1
        }
    }

    /// @notice Переводит значение в Montgomery-представление: `toMontgomery2`.
    function toMontgomery2(uint256 x0, uint256 x1) internal pure returns (uint256 r0, uint256 r1) {
        return montMul2(x0, x1, R2_0, R2_1);
    }

    /// @notice Переводит значение из Montgomery-представления в обычное: `fromMontgomery2`.
    function fromMontgomery2(uint256 x0, uint256 x1) internal pure returns (uint256 r0, uint256 r1) {
        return montMul2(x0, x1, 1, 0);
    }

}
