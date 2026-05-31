// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

/// @notice Экспериментальный CIOS-вариант с безветвительным финальным вычитанием.
library BigIntMNTFinalSelect {
    /// @dev Константа `P_0` задает слово модуля поля или связанный параметр редукции.
    uint256 private constant P_0  = 0x685acce9767254a4638810719ac425f0e39d54522cdd119f5e9063de245e8001;
    /// @dev Константа `P_1` задает слово модуля поля или связанный параметр редукции.
    uint256 private constant P_1  = 0x7fdb925e8a0ed8d99d124d9a15af79db117e776f218059db80f0da5cb537e38;
    /// @dev Константа `P_2` задает слово модуля поля или связанный параметр редукции.
    uint256 private constant P_2  = 0x1c4c62d92c41110229022eee2cdadb7f997505b8fafed5eb7e8f96c97d873;
    /// @dev Константа `R2_0` содержит R^2 mod p и используется для перевода в Montgomery-представление.
    uint256 private constant R2_0 = 0xa896a656a0714c7da24bea56242b3507c7d9ff8e7df03c0a84717088cfd190c8;
    /// @dev Константа `R2_1` содержит R^2 mod p и используется для перевода в Montgomery-представление.
    uint256 private constant R2_1 = 0xe03c79cac4f7ef07a8c86d4604a3b5972f47839ef88d7ce880a46659ff6f3ddf;
    /// @dev Константа `R2_2` содержит R^2 mod p и используется для перевода в Montgomery-представление.
    uint256 private constant R2_2 = 0x2a33e89cb485b081f15bcbfdacaf8e4605754c3817232505daf1f4a81245;
    /// @dev Константа `MAGIC` содержит коэффициент Montgomery-редукции: отрицательное обратное к младшему слову модуля по модулю 2^256.
    uint256 private constant MAGIC = 0x4adb7a6352a3a656d9e1947eee113b7a7fd403903e304c4cf2044cfbe45e7fff;

    /// @notice Выполняет умножение `montMul3`; точный уровень поля и специальный множитель отражены в названии.
    function montMul3(
        uint256 a0, uint256 a1, uint256 a2,
        uint256 b0, uint256 b1, uint256 b2
    ) internal pure returns (uint256 r0, uint256 r1, uint256 r2) {
        assembly ("memory-safe") {
            // Выполняет умножение `mul512`; точный уровень поля и специальный множитель отражены в названии.
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

            // Экспериментальное безветвительное финальное условное вычитание.
            // Всегда вычисляем t-p и выбираем результат вычитания только при отсутствии займа.
            let n0 := sub(t0, p0)
            let b01 := lt(t0, p0)
            let y1 := add(p1, b01)
            let n1 := sub(t1, y1)
            let b12 := or(lt(t1, y1), lt(y1, p1))
            let y2 := add(p2, b12)
            let n2 := sub(t2, y2)
            let bor := or(lt(t2, y2), lt(y2, p2))
            let mask := sub(0, iszero(bor))
            r0 := xor(t0, and(mask, xor(t0, n0)))
            r1 := xor(t1, and(mask, xor(t1, n1)))
            r2 := xor(t2, and(mask, xor(t2, n2)))
        }
    }


    /// @notice Возводит значение в квадрат: `montSqr3`.
    function montSqr3(uint256 a0, uint256 a1, uint256 a2)
        internal pure returns (uint256 r0, uint256 r1, uint256 r2)
    {
        return montMul3(a0, a1, a2, a0, a1, a2);
    }

    /// @notice Переводит значение в Montgomery-представление: `toMontgomery3`.
    function toMontgomery3(uint256 x0, uint256 x1, uint256 x2)
        internal pure returns (uint256 r0, uint256 r1, uint256 r2)
    {
        return montMul3(x0, x1, x2, R2_0, R2_1, R2_2);
    }
}
