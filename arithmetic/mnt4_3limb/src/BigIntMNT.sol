// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

/// @notice Арифметика базового поля MNT4-753 по модулю p: три 256-битных слова от младшего к старшему.
///         Инвариант представления:
///         - Входы сложения, вычитания, умножения и возведения в квадрат считаются приведенными: 0 <= x < p.
///         - Результаты приведены по модулю.
/// @dev Основание Montgomery: B = 2^256, число слов n=3, поэтому R=2^768.
///      MAGIC = -p^{-1} mod 2^256.
library BigIntMNT {
    /// @dev Константа `P_0` задает слово модуля поля или связанный параметр редукции.
    uint256 private constant P_0  = 0x685acce9767254a4638810719ac425f0e39d54522cdd119f5e9063de245e8001;
    /// @dev Константа `P_1` задает слово модуля поля или связанный параметр редукции.
    uint256 private constant P_1  = 0x7fdb925e8a0ed8d99d124d9a15af79db117e776f218059db80f0da5cb537e38;
    /// @dev Константа `P_2` задает слово модуля поля или связанный параметр редукции.
    uint256 private constant P_2  = 0x1c4c62d92c41110229022eee2cdadb7f997505b8fafed5eb7e8f96c97d873;
    /// @dev Константа `P2_0` задает слово модуля поля или связанный параметр редукции.
    uint256 private constant P2_0 = 0xd0b599d2ece4a948c71020e335884be1c73aa8a459ba233ebd20c7bc48bd0002;
    /// @dev Константа `P2_1` задает слово модуля поля или связанный параметр редукции.
    uint256 private constant P2_1 = 0xffb724bd141db1b33a249b342b5ef3b622fceede4300b3b701e1b4b96a6fc70;
    /// @dev Константа `P2_2` задает слово модуля поля или связанный параметр редукции.
    uint256 private constant P2_2 = 0x3898c5b25882220452045ddc59b5b6ff32ea0b71f5fdabd6fd1f2d92fb0e6;
    /// @dev Константа `P4_0` задает слово модуля поля или связанный параметр редукции.
    uint256 private constant P4_0 = 0xa16b33a5d9c952918e2041c66b1097c38e755148b374467d7a418f78917a0004;
    /// @dev Константа `P4_1` задает слово модуля поля или связанный параметр редукции.
    uint256 private constant P4_1 = 0x1ff6e497a283b63667449366856bde76c45f9ddbc8601676e03c36972d4df8e1;
    /// @dev Константа `P4_2` задает слово модуля поля или связанный параметр редукции.
    uint256 private constant P4_2 = 0x71318b64b1044408a408bbb8b36b6dfe65d416e3ebfb57adfa3e5b25f61cc;
    /// @dev Константа `P8_0` задает слово модуля поля или связанный параметр редукции.
    uint256 private constant P8_0 = 0x42d6674bb392a5231c40838cd6212f871ceaa29166e88cfaf4831ef122f40008;
    /// @dev Константа `P8_1` задает слово модуля поля или связанный параметр редукции.
    uint256 private constant P8_1 = 0x3fedc92f45076c6cce8926cd0ad7bced88bf3bb790c02cedc0786d2e5a9bf1c3;
    /// @dev Константа `P8_2` задает слово модуля поля или связанный параметр редукции.
    uint256 private constant P8_2 = 0xe26316c9620888114811777166d6dbfccba82dc7d7f6af5bf47cb64bec398;

    /// @dev Константа `R2_0` содержит R^2 mod p и используется для перевода в Montgomery-представление.
    uint256 private constant R2_0 = 0xa896a656a0714c7da24bea56242b3507c7d9ff8e7df03c0a84717088cfd190c8;
    /// @dev Константа `R2_1` содержит R^2 mod p и используется для перевода в Montgomery-представление.
    uint256 private constant R2_1 = 0xe03c79cac4f7ef07a8c86d4604a3b5972f47839ef88d7ce880a46659ff6f3ddf;
    /// @dev Константа `R2_2` содержит R^2 mod p и используется для перевода в Montgomery-представление.
    uint256 private constant R2_2 = 0x2a33e89cb485b081f15bcbfdacaf8e4605754c3817232505daf1f4a81245;

    /// @dev Константа `MAGIC` содержит коэффициент Montgomery-редукции: отрицательное обратное к младшему слову модуля по модулю 2^256.
    uint256 private constant MAGIC = 0x4adb7a6352a3a656d9e1947eee113b7a7fd403903e304c4cf2044cfbe45e7fff;
    /// @dev Константа `ONE_MONT_0` содержит соответствующее слово единицы в Montgomery-представлении.
    uint256 private constant ONE_MONT_0 = 0x79589819c788b60197c3e4a0cd14572e91cd31c65a03468698a8ecabd9dc6f42;
    /// @dev Константа `ONE_MONT_1` содержит соответствующее слово единицы в Montgomery-представлении.
    uint256 private constant ONE_MONT_1 = 0x598b4302d2f00a62320c3bb7133385591e0f4d8acf031d68ed269c942108976f;
    /// @dev Константа `ONE_MONT_2` содержит соответствующее слово единицы в Montgomery-представлении.
    uint256 private constant ONE_MONT_2 = 0x7b479ec8e24295455fb31ff9a1950fa47edb3865e88c4074c9cbfd8ca621;
    /// @dev Константа `EXP_PM2_0` фиксирует параметр алгоритма; значение не изменяется во время выполнения.
    uint256 private constant EXP_PM2_0 = 0x685acce9767254a4638810719ac425f0e39d54522cdd119f5e9063de245e7fff;
    /// @dev Константа `EXP_PM2_1` фиксирует параметр алгоритма; значение не изменяется во время выполнения.
    uint256 private constant EXP_PM2_1 = 0x7fdb925e8a0ed8d99d124d9a15af79db117e776f218059db80f0da5cb537e38;
    /// @dev Константа `EXP_PM2_2` фиксирует параметр алгоритма; значение не изменяется во время выполнения.
    uint256 private constant EXP_PM2_2 = 0x1c4c62d92c41110229022eee2cdadb7f997505b8fafed5eb7e8f96c97d873;
    /// @dev Константа `EXP_PM2_TOP_BITS` фиксирует параметр алгоритма; значение не изменяется во время выполнения.
    uint256 private constant EXP_PM2_TOP_BITS = 241;

    /// @notice Сложение по словам без немедленной редукции: r = a + b (mod 2^768).
    /// @dev Используется в ветках отложенной редукции, где вызывающая функция контролирует границы значения.
    function add3NR(
        uint256 a0, uint256 a1, uint256 a2,
        uint256 b0, uint256 b1, uint256 b2
    ) internal pure returns (uint256 r0, uint256 r1, uint256 r2) {
        assembly ("memory-safe") {
            // Выполняет внутреннюю операцию `adc`; параметры и результат используют представление текущей библиотеки.
            function adc(x, y, c) -> r, cOut {
                let s := add(x, y)
                let c1 := lt(s, x)
                r := add(s, c)
                let c2 := lt(r, s)
                cOut := or(c1, c2)
            }
            let c := 0
            r0, c := adc(a0, b0, 0)
            r1, c := adc(a1, b1, c)
            r2, c := adc(a2, b2, c)
        }
    }

    /// @notice Приводит x из диапазона [0, 2p) к диапазону [0, p).
    function reduce3(
        uint256 x0, uint256 x1, uint256 x2
    ) internal pure returns (uint256 r0, uint256 r1, uint256 r2) {
        assembly ("memory-safe") {
            // Выполняет внутреннюю операцию `sbb`; параметры и результат используют представление текущей библиотеки.
            function sbb(x, y, b) -> rr, bOut {
                let yy := add(y, b)
                rr := sub(x, yy)
                bOut := or(lt(x, yy), lt(yy, y))
            }
            let t0
            let t1
            let t2
            let bor := 0
            t0, bor := sbb(x0, P_0, 0)
            t1, bor := sbb(x1, P_1, bor)
            t2, bor := sbb(x2, P_2, bor)

            if iszero(bor) {
                x0 := t0
                x1 := t1
                x2 := t2
            }
            r0 := x0
            r1 := x1
            r2 := x2
        }
    }

    /// @notice Приводит x из [0, 16p) к [0, p) условными вычитаниями 8p, 4p, 2p и p.
    function reduce3Wide16(
        uint256 x0, uint256 x1, uint256 x2
    ) internal pure returns (uint256 r0, uint256 r1, uint256 r2) {
        assembly ("memory-safe") {
            // Выполняет внутреннюю операцию `sbb`; параметры и результат используют представление текущей библиотеки.
            function sbb(x, y, b) -> rr, bOut {
                let yy := add(y, b)
                rr := sub(x, yy)
                bOut := or(lt(x, yy), lt(yy, y))
            }
            // Выполняет вычитание `condSub` с учетом модуля или структуры текущего поля.
            function condSub(x0v, x1v, x2v, c0, c1, c2) -> y0, y1, y2 {
                let t0
                let t1
                let t2
                let bor := 0
                t0, bor := sbb(x0v, c0, 0)
                t1, bor := sbb(x1v, c1, bor)
                t2, bor := sbb(x2v, c2, bor)
                if iszero(bor) {
                    y0 := t0
                    y1 := t1
                    y2 := t2
                }
                if bor {
                    y0 := x0v
                    y1 := x1v
                    y2 := x2v
                }
            }

            x0, x1, x2 := condSub(x0, x1, x2, P8_0, P8_1, P8_2)
            x0, x1, x2 := condSub(x0, x1, x2, P4_0, P4_1, P4_2)
            x0, x1, x2 := condSub(x0, x1, x2, P2_0, P2_1, P2_2)
            x0, x1, x2 := condSub(x0, x1, x2, P_0, P_1, P_2)

            r0 := x0
            r1 := x1
            r2 := x2
        }
    }

    /// @notice Вычисляет 13*a с отложенным накоплением и одной широкой редукцией.
    /// @dev Requires a in [0,p). Internal accumulator stays in [0,16p).
    function mulBy13(
        uint256 a0, uint256 a1, uint256 a2
    ) internal pure returns (uint256 r0, uint256 r1, uint256 r2) {
        (uint256 t0, uint256 t1, uint256 t2) = add3NR(a0, a1, a2, a0, a1, a2); // 2a
        (t0, t1, t2) = add3NR(t0, t1, t2, t0, t1, t2); // 4a
        (r0, r1, r2) = add3NR(t0, t1, t2, t0, t1, t2); // 8a
        (r0, r1, r2) = add3NR(r0, r1, r2, t0, t1, t2); // 12a
        (r0, r1, r2) = add3NR(r0, r1, r2, a0, a1, a2); // 13a
        return reduce3Wide16(r0, r1, r2);
    }

    /// @notice Выполняет сложение `add3` с учетом модуля или структуры текущего поля.
    function add3(
        uint256 a0, uint256 a1, uint256 a2,
        uint256 b0, uint256 b1, uint256 b2
    ) internal pure returns (uint256 r0, uint256 r1, uint256 r2) {
        assembly ("memory-safe") {
            // Выполняет внутреннюю операцию `adc`; параметры и результат используют представление текущей библиотеки.
            function adc(x, y, c) -> r, cOut {
                let s := add(x, y)
                let c1 := lt(s, x)
                r := add(s, c)
                let c2 := lt(r, s)
                cOut := or(c1, c2)
            }
            // Выполняет внутреннюю операцию `sbb`; параметры и результат используют представление текущей библиотеки.
            function sbb(x, y, b) -> rr, bOut {
                let yy := add(y, b)
                rr := sub(x, yy)
                bOut := or(lt(x, yy), lt(yy, y))
            }

            let c := 0
            r0, c := adc(a0, b0, 0)
            r1, c := adc(a1, b1, c)
            r2, c := adc(a2, b2, c)

            let ge := 0
            if gt(r2, P_2) { ge := 1 }
            if eq(r2, P_2) {
                if gt(r1, P_1) { ge := 1 }
                if eq(r1, P_1) {
                    if iszero(lt(r0, P_0)) { ge := 1 }
                }
            }

            if ge {
                let bor := 0
                r0, bor := sbb(r0, P_0, 0)
                r1, bor := sbb(r1, P_1, bor)
                r2, bor := sbb(r2, P_2, bor)
            }
        }
    }

    /// @notice Выполняет вычитание `sub3` с учетом модуля или структуры текущего поля.
    function sub3(
        uint256 a0, uint256 a1, uint256 a2,
        uint256 b0, uint256 b1, uint256 b2
    ) internal pure returns (uint256 r0, uint256 r1, uint256 r2) {
        assembly ("memory-safe") {
            // Выполняет внутреннюю операцию `sbb`; параметры и результат используют представление текущей библиотеки.
            function sbb(x, y, b) -> rr, bOut {
                let yy := add(y, b)
                rr := sub(x, yy)
                bOut := or(lt(x, yy), lt(yy, y))
            }
            // Выполняет внутреннюю операцию `adc`; параметры и результат используют представление текущей библиотеки.
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
            r2, bor := sbb(a2, b2, bor)

            if bor {
                let c := 0
                r0, c := adc(r0, P_0, 0)
                r1, c := adc(r1, P_1, c)
                r2, c := adc(r2, P_2, c)
            }
        }
    }

    /// @notice Выполняет умножение `montMul3`;
    function montMul3(
        uint256 a0, uint256 a1, uint256 a2,
        uint256 b0, uint256 b1, uint256 b2
    ) internal pure returns (uint256 r0, uint256 r1, uint256 r2) {
        assembly ("memory-safe") {
            // Выполняет умножение `mul512`;
            function mul512(u, v) -> lo, hi {
                lo := mul(u, v)
                let mm := mulmod(u, v, not(0))
                hi := sub(sub(mm, lo), lt(mm, lo))
            }

            let p0 := P_0
            let p1 := P_1
            let p2 := P_2
            let magic := MAGIC

            let t0 := 0
            let t1 := 0
            let t2 := 0
            let t3 := 0

            {
                let u := a0
                {
                    let lo, hi := mul512(u, b0)
                    t0 := add(t0, lo)
                    let c := lt(t0, lo)
                    t1 := add(t1, hi)
                    let c2 := lt(t1, hi)
                    t1 := add(t1, c)
                    if lt(t1, c) { c2 := add(c2, 1) }
                    t2 := add(t2, c2)
                }
                {
                    let lo, hi := mul512(u, b1)
                    t1 := add(t1, lo)
                    let c := lt(t1, lo)
                    t2 := add(t2, hi)
                    let c2 := lt(t2, hi)
                    t2 := add(t2, c)
                    if lt(t2, c) { c2 := add(c2, 1) }
                    t3 := add(t3, c2)
                }
                {
                    let lo, hi := mul512(u, b2)
                    t2 := add(t2, lo)
                    let c := lt(t2, lo)
                    t3 := add(t3, hi)
                    t3 := add(t3, c)
                }

                let m := mul(t0, magic)

                {
                    let lo, hi := mul512(m, p0)
                    t0 := add(t0, lo)
                    let c := lt(t0, lo)
                    t1 := add(t1, hi)
                    let c2 := lt(t1, hi)
                    t1 := add(t1, c)
                    if lt(t1, c) { c2 := add(c2, 1) }
                    t2 := add(t2, c2)
                    if lt(t2, c2) { t3 := add(t3, 1) }
                }
                {
                    let lo, hi := mul512(m, p1)
                    t1 := add(t1, lo)
                    let c := lt(t1, lo)
                    t2 := add(t2, hi)
                    let c2 := lt(t2, hi)
                    t2 := add(t2, c)
                    if lt(t2, c) { c2 := add(c2, 1) }
                    t3 := add(t3, c2)
                }
                {
                    let lo, hi := mul512(m, p2)
                    t2 := add(t2, lo)
                    let c := lt(t2, lo)
                    t3 := add(t3, hi)
                    t3 := add(t3, c)
                }
            }

            t0 := t1
            t1 := t2
            t2 := t3
            t3 := 0

            {
                let u := a1
                {
                    let lo, hi := mul512(u, b0)
                    t0 := add(t0, lo)
                    let c := lt(t0, lo)
                    t1 := add(t1, hi)
                    let c2 := lt(t1, hi)
                    t1 := add(t1, c)
                    if lt(t1, c) { c2 := add(c2, 1) }
                    t2 := add(t2, c2)
                    if lt(t2, c2) { t3 := add(t3, 1) }
                }
                {
                    let lo, hi := mul512(u, b1)
                    t1 := add(t1, lo)
                    let c := lt(t1, lo)
                    t2 := add(t2, hi)
                    let c2 := lt(t2, hi)
                    t2 := add(t2, c)
                    if lt(t2, c) { c2 := add(c2, 1) }
                    t3 := add(t3, c2)
                }
                {
                    let lo, hi := mul512(u, b2)
                    t2 := add(t2, lo)
                    let c := lt(t2, lo)
                    t3 := add(t3, hi)
                    t3 := add(t3, c)
                }

                let m := mul(t0, magic)

                {
                    let lo, hi := mul512(m, p0)
                    t0 := add(t0, lo)
                    let c := lt(t0, lo)
                    t1 := add(t1, hi)
                    let c2 := lt(t1, hi)
                    t1 := add(t1, c)
                    if lt(t1, c) { c2 := add(c2, 1) }
                    t2 := add(t2, c2)
                    if lt(t2, c2) { t3 := add(t3, 1) }
                }
                {
                    let lo, hi := mul512(m, p1)
                    t1 := add(t1, lo)
                    let c := lt(t1, lo)
                    t2 := add(t2, hi)
                    let c2 := lt(t2, hi)
                    t2 := add(t2, c)
                    if lt(t2, c) { c2 := add(c2, 1) }
                    t3 := add(t3, c2)
                }
                {
                    let lo, hi := mul512(m, p2)
                    t2 := add(t2, lo)
                    let c := lt(t2, lo)
                    t3 := add(t3, hi)
                    t3 := add(t3, c)
                }
            }

            t0 := t1
            t1 := t2
            t2 := t3
            t3 := 0

            {
                let u := a2
                {
                    let lo, hi := mul512(u, b0)
                    t0 := add(t0, lo)
                    let c := lt(t0, lo)
                    t1 := add(t1, hi)
                    let c2 := lt(t1, hi)
                    t1 := add(t1, c)
                    if lt(t1, c) { c2 := add(c2, 1) }
                    t2 := add(t2, c2)
                    if lt(t2, c2) { t3 := add(t3, 1) }
                }
                {
                    let lo, hi := mul512(u, b1)
                    t1 := add(t1, lo)
                    let c := lt(t1, lo)
                    t2 := add(t2, hi)
                    let c2 := lt(t2, hi)
                    t2 := add(t2, c)
                    if lt(t2, c) { c2 := add(c2, 1) }
                    t3 := add(t3, c2)
                }
                {
                    let lo, hi := mul512(u, b2)
                    t2 := add(t2, lo)
                    let c := lt(t2, lo)
                    t3 := add(t3, hi)
                    t3 := add(t3, c)
                }

                let m := mul(t0, magic)

                {
                    let lo, hi := mul512(m, p0)
                    t0 := add(t0, lo)
                    let c := lt(t0, lo)
                    t1 := add(t1, hi)
                    let c2 := lt(t1, hi)
                    t1 := add(t1, c)
                    if lt(t1, c) { c2 := add(c2, 1) }
                    t2 := add(t2, c2)
                    if lt(t2, c2) { t3 := add(t3, 1) }
                }
                {
                    let lo, hi := mul512(m, p1)
                    t1 := add(t1, lo)
                    let c := lt(t1, lo)
                    t2 := add(t2, hi)
                    let c2 := lt(t2, hi)
                    t2 := add(t2, c)
                    if lt(t2, c) { c2 := add(c2, 1) }
                    t3 := add(t3, c2)
                }
                {
                    let lo, hi := mul512(m, p2)
                    t2 := add(t2, lo)
                    let c := lt(t2, lo)
                    t3 := add(t3, hi)
                    t3 := add(t3, c)
                }
            }

            t0 := t1
            t1 := t2
            t2 := t3

            let ge := 0
            if gt(t2, p2) { ge := 1 }
            if eq(t2, p2) {
                if gt(t1, p1) { ge := 1 }
                if eq(t1, p1) {
                    if iszero(lt(t0, p0)) { ge := 1 }
                }
            }

            if ge {
                // Выполняет внутреннюю операцию `sbb`; параметры и результат используют представление текущей библиотеки.
                function sbb(x, y, b) -> rr, bOut {
                    let yy := add(y, b)
                    rr := sub(x, yy)
                    bOut := or(lt(x, yy), lt(yy, y))
                }
                let bor := 0
                t0, bor := sbb(t0, p0, 0)
                t1, bor := sbb(t1, p1, bor)
                t2, bor := sbb(t2, p2, bor)
            }

            r0 := t0
            r1 := t1
            r2 := t2
        }
    }

    /// @notice Montgomery squaring specialized for n=3 limbs.
    function montSqr3(
        uint256 a0, uint256 a1, uint256 a2
    ) internal pure returns (uint256 r0, uint256 r1, uint256 r2) {
        return montMul3(a0, a1, a2, a0, a1, a2);
    }

    /// @notice Stack-версии конвертаций (без memory аллокаций).
    function toMontgomery3(
        uint256 x0, uint256 x1, uint256 x2
    ) internal pure returns (uint256 r0, uint256 r1, uint256 r2) {
        return montMul3(x0, x1, x2, R2_0, R2_1, R2_2);
    }

    /// @notice Переводит значение из Montgomery-представления в обычное: `fromMontgomery3`.
    function fromMontgomery3(
        uint256 x0, uint256 x1, uint256 x2
    ) internal pure returns (uint256 r0, uint256 r1, uint256 r2) {
        return montMul3(x0, x1, x2, 1, 0, 0);
    }

    /// @notice Вычисляет мультипликативно обратное значение: `inv3NativeStack`.
    function inv3NativeStack(uint256 a0, uint256 a1, uint256 a2)
        internal
        pure
        returns (uint256 r0, uint256 r1, uint256 r2)
    {
        require((a0 | a1 | a2) != 0, "inv(0)");

        // Exponent e = p - 2 (p is odd => e is odd)
        uint256 e0 = P_0 - 2;
        uint256 e1 = P_1;
        uint256 e2 = P_2;

        // r = 1 in Montgomery domain
        r0 = ONE_MONT_0;
        r1 = ONE_MONT_1;
        r2 = ONE_MONT_2;

        // Ширина скользящего окна: w=5.
        // Заранее вычисляем 16 нечетных степеней x: x^1, x^3, ..., x^31.
        // Храним таблицу в свободном участке памяти из 48 слов, чтобы не обнулять фиксированный массив.
        uint256 pTbl;
        assembly ("memory-safe") {
            pTbl := mload(0x40)
            mstore(0x40, add(pTbl, 0x600)) // 48 words
        }

        // x2 = x^2
        (uint256 x20, uint256 x21, uint256 x22) = montSqr3(a0, a1, a2);

        // tbl[0] = x^1
        assembly ("memory-safe") {
            mstore(pTbl, a0)
            mstore(add(pTbl, 0x20), a1)
            mstore(add(pTbl, 0x40), a2)
        }

        // tbl[i] = tbl[i-1] * x^2  => x^(2i+1)
        unchecked {
            for (uint256 j = 1; j < 16; ++j) { // 16 = (1<<5)/2
                uint256 offPrev = (j - 1) * 0x60;
                uint256 off = j * 0x60;
                uint256 tPrev0;
                uint256 tPrev1;
                uint256 tPrev2;
                assembly ("memory-safe") {
                    tPrev0 := mload(add(pTbl, offPrev))
                    tPrev1 := mload(add(add(pTbl, offPrev), 0x20))
                    tPrev2 := mload(add(add(pTbl, offPrev), 0x40))
                }

                (uint256 t0, uint256 t1, uint256 t2) = montMul3(
                    tPrev0,
                    tPrev1,
                    tPrev2,
                    x20,
                    x21,
                    x22
                );

                assembly ("memory-safe") {
                    mstore(add(pTbl, off), t0)
                    mstore(add(add(pTbl, off), 0x20), t1)
                    mstore(add(add(pTbl, off), 0x40), t2)
                }
            }
        }

        // Bitlength(p) = 753 => MSB index = 752
        uint256 i = 752;

        while (true) {
            // bit = (e >> i) & 1
            uint256 bit;
            if (i < 256) bit = (e0 >> i) & 1;
            else if (i < 512) bit = (e1 >> (i - 256)) & 1;
            else bit = (e2 >> (i - 512)) & 1;

            if (bit == 0) {
                (r0, r1, r2) = montSqr3(r0, r1, r2);
                if (i == 0) break;
                unchecked { --i; }
                continue;
            }

            // w=5 => look back up to 4 bits from i
            uint256 j;
            unchecked {
                j = (i > 4) ? (i - 4) : 0;
            }

            while (true) {
                uint256 bj;
                if (j < 256) bj = (e0 >> j) & 1;
                else if (j < 512) bj = (e1 >> (j - 256)) & 1;
                else bj = (e2 >> (j - 512)) & 1;

                if (bj == 1) break;
                unchecked { ++j; }
            }

            // Длина окна k=i-j+1 не превышает 5; значение окна по битам [i..j] всегда нечетно.
            uint256 k;
            unchecked { k = i - j + 1; }

            uint256 wval = 0;
            uint256 t = i;
            while (true) {
                uint256 bt;
                if (t < 256) bt = (e0 >> t) & 1;
                else if (t < 512) bt = (e1 >> (t - 256)) & 1;
                else bt = (e2 >> (t - 512)) & 1;

                wval = (wval << 1) | bt;

                if (t == j) break;
                unchecked { --t; }
            }

            // k squarings
            unchecked {
                for (uint256 s = 0; s < k; ++s) {
                    (r0, r1, r2) = montSqr3(r0, r1, r2);
                }
            }

            // Умножаем на заранее вычисленную нечетную степень x^wval.
            // For odd wval in [1..31]: idx = wval >> 1 in [0..15]
            uint256 idx = wval >> 1;
            uint256 off = idx * 0x60;
            uint256 tMul0;
            uint256 tMul1;
            uint256 tMul2;
            assembly ("memory-safe") {
                tMul0 := mload(add(pTbl, off))
                tMul1 := mload(add(add(pTbl, off), 0x20))
                tMul2 := mload(add(add(pTbl, off), 0x40))
            }

            (r0, r1, r2) = montMul3(
                r0,
                r1,
                r2,
                tMul0,
                tMul1,
                tMul2
            );

            if (j == 0) break;
            unchecked { i = j - 1; }
        }

        return (r0, r1, r2);
    }

    /// @notice Вычисляет мультипликативно обратное значение: `inv3Native`.
    function inv3Native(uint256 a0, uint256 a1, uint256 a2)
        internal
        pure
        returns (uint256 r0, uint256 r1, uint256 r2)
    {
        return inv3NativeStack(a0, a1, a2);
    }

    /// @dev Raw modular exponentiation over 96-byte operands using precompile 0x05.
    ///      Operands are passed in 3 limbs little-endian and converted to big-endian byte order.
    function _modexp96(
        uint256 b0, uint256 b1, uint256 b2,
        uint256 e0, uint256 e1, uint256 e2,
        uint256 m0, uint256 m1, uint256 m2
    ) private view returns (uint256 r0, uint256 r1, uint256 r2) {
        assembly ("memory-safe") {
            let ptr := mload(0x40)

            // lengths: base=96, exp=96, mod=96
            mstore(ptr, 0x60)
            mstore(add(ptr, 0x20), 0x60)
            mstore(add(ptr, 0x40), 0x60)

            // base (big-endian)
            mstore(add(ptr, 0x60), b2)
            mstore(add(ptr, 0x80), b1)
            mstore(add(ptr, 0xA0), b0)

            // Экспонента в порядке от старшего байта к младшему.
            mstore(add(ptr, 0xC0), e2)
            mstore(add(ptr, 0xE0), e1)
            mstore(add(ptr, 0x100), e0)

            // Модуль в порядке от старшего байта к младшему.
            mstore(add(ptr, 0x120), m2)
            mstore(add(ptr, 0x140), m1)
            mstore(add(ptr, 0x160), m0)

            // output is 96 bytes big-endian
            if iszero(staticcall(not(0), 0x05, ptr, 0x180, ptr, 0x60)) {
                revert(0, 0)
            }

            // Возвращаем результат в формате трех слов от младшего к старшему.
            r2 := mload(ptr)
            r1 := mload(add(ptr, 0x20))
            r0 := mload(add(ptr, 0x40))

            mstore(0x40, add(ptr, 0x180))
        }
    }

    /// @notice Inversion via precompile 0x05 (modexp), returns Montgomery-domain inverse.
    /// @dev Input is Montgomery element aR. We convert to normal a, do a^(p-2), then back to Montgomery.
    function inv3Modexp(uint256 a0, uint256 a1, uint256 a2)
        internal
        view
        returns (uint256 r0, uint256 r1, uint256 r2)
    {
        require((a0 | a1 | a2) != 0, "inv(0)");

        (uint256 n0, uint256 n1, uint256 n2) = fromMontgomery3(a0, a1, a2);
        (uint256 i0, uint256 i1, uint256 i2) = _modexp96(
            n0, n1, n2,
            EXP_PM2_0, EXP_PM2_1, EXP_PM2_2,
            P_0, P_1, P_2
        );
        return toMontgomery3(i0, i1, i2);
    }

    /// @notice Вычисляет мультипликативно обратное значение: `inv3ByBackend`.
    function inv3ByBackend(
        uint256 a0, uint256 a1, uint256 a2, bool useModexp
    ) internal view returns (uint256 r0, uint256 r1, uint256 r2) {
        if (useModexp) {
            return inv3Modexp(a0, a1, a2);
        }
        return inv3Native(a0, a1, a2);
    }

    /// @notice Backward-compatible default inverse backend.
    function inv3(uint256 a0, uint256 a1, uint256 a2)
        internal
        pure
        returns (uint256 r0, uint256 r1, uint256 r2)
    {
        return inv3Native(a0, a1, a2);
    }

    // wrappers
    function add(uint256[3] memory a, uint256[3] memory b) internal pure returns (uint256[3] memory r) {
        (r[0], r[1], r[2]) = add3(a[0], a[1], a[2], b[0], b[1], b[2]);
    }

    /// @notice Выполняет вычитание `sub` с учетом модуля или структуры текущего поля.
    function sub(uint256[3] memory a, uint256[3] memory b) internal pure returns (uint256[3] memory r) {
        (r[0], r[1], r[2]) = sub3(a[0], a[1], a[2], b[0], b[1], b[2]);
    }

    /// @notice Выполняет умножение `montMul`;
    function montMul(uint256[3] memory a, uint256[3] memory b) internal pure returns (uint256[3] memory r) {
        (r[0], r[1], r[2]) = montMul3(a[0], a[1], a[2], b[0], b[1], b[2]);
    }

    /// @notice Возводит значение в квадрат: `montSqr`.
    function montSqr(uint256[3] memory a) internal pure returns (uint256[3] memory r) {
        (r[0], r[1], r[2]) = montSqr3(a[0], a[1], a[2]);
    }

    /// @notice Вычисляет мультипликативно обратное значение: `inv`.
    function inv(uint256[3] memory a) internal pure returns (uint256[3] memory r) {
        (r[0], r[1], r[2]) = inv3(a[0], a[1], a[2]);
    }

    /// @notice Вычисляет мультипликативно обратное значение: `invNative`.
    function invNative(uint256[3] memory a) internal pure returns (uint256[3] memory r) {
        (r[0], r[1], r[2]) = inv3Native(a[0], a[1], a[2]);
    }

    /// @notice Вычисляет мультипликативно обратное значение: `invModexp`.
    function invModexp(uint256[3] memory a) internal view returns (uint256[3] memory r) {
        (r[0], r[1], r[2]) = inv3Modexp(a[0], a[1], a[2]);
    }

    /// @notice Вычисляет мультипликативно обратное значение: `invByBackend`.
    function invByBackend(uint256[3] memory a, bool useModexp) internal view returns (uint256[3] memory r) {
        (r[0], r[1], r[2]) = inv3ByBackend(a[0], a[1], a[2], useModexp);
    }

    /// @notice Оптимизировано: больше нет выделения r2/one массивов.
    function toMontgomery(uint256[3] memory x) internal pure returns (uint256[3] memory r) {
        (r[0], r[1], r[2]) = toMontgomery3(x[0], x[1], x[2]);
    }

    /// @notice Переводит значение из Montgomery-представления в обычное: `fromMontgomery`.
    function fromMontgomery(uint256[3] memory x) internal pure returns (uint256[3] memory r) {
        (r[0], r[1], r[2]) = fromMontgomery3(x[0], x[1], x[2]);
    }
}
