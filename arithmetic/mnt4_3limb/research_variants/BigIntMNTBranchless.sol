// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

/// @notice Экспериментальные безветвительные условные редукции для сравнения стоимости gas.
/// @dev Выполнение on-chain публично, поэтому постоянное время не является основной целью безопасности.
///      Вариант показывает, конкурирует ли выбор по маске с ветвлением по стоимости gas.
library BigIntMNTBranchless {
    /// @dev Константа `P_0` задает слово модуля поля или связанный параметр редукции.
    uint256 private constant P_0 = 0x685acce9767254a4638810719ac425f0e39d54522cdd119f5e9063de245e8001;
    /// @dev Константа `P_1` задает слово модуля поля или связанный параметр редукции.
    uint256 private constant P_1 = 0x7fdb925e8a0ed8d99d124d9a15af79db117e776f218059db80f0da5cb537e38;
    /// @dev Константа `P_2` задает слово модуля поля или связанный параметр редукции.
    uint256 private constant P_2 = 0x1c4c62d92c41110229022eee2cdadb7f997505b8fafed5eb7e8f96c97d873;

    /// @notice Выполняет внутреннюю операцию `reduce3`; параметры и результат используют представление текущей библиотеки.
    function reduce3(uint256 x0, uint256 x1, uint256 x2)
        internal pure returns (uint256 r0, uint256 r1, uint256 r2)
    {
        assembly ("memory-safe") {
            /// @notice Выполняет внутреннюю операцию `sbb`; параметры и результат используют представление текущей библиотеки.
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

            let mask := sub(0, iszero(bor))
            r0 := or(and(t0, mask), and(x0, not(mask)))
            r1 := or(and(t1, mask), and(x1, not(mask)))
            r2 := or(and(t2, mask), and(x2, not(mask)))
        }
    }

    /// @notice Выполняет сложение `add3` с учетом модуля или структуры текущего поля.
    function add3(
        uint256 a0, uint256 a1, uint256 a2,
        uint256 b0, uint256 b1, uint256 b2
    ) internal pure returns (uint256 r0, uint256 r1, uint256 r2) {
        assembly ("memory-safe") {
            /// @notice Выполняет внутреннюю операцию `adc`; параметры и результат используют представление текущей библиотеки.
            function adc(x, y, c) -> rr, cOut {
                let s := add(x, y)
                let c1 := lt(s, x)
                rr := add(s, c)
                let c2 := lt(rr, s)
                cOut := or(c1, c2)
            }
            let c := 0
            r0, c := adc(a0, b0, 0)
            r1, c := adc(a1, b1, c)
            r2, c := adc(a2, b2, c)
        }
        return reduce3(r0, r1, r2);
    }
}
