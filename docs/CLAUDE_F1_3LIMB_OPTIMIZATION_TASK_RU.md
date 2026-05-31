# Задание для Claude: проверить возможность дальнейшей оптимизации 3-limb Montgomery/CIOS арифметики MNT4-753 в EVM

## 1. Контекст

Нужно проверить, можно ли еще заметно снизить стоимость базовой арифметики поля MNT4-753 в EVM.

Поле MNT4-753 имеет размер около 753 бит. Один элемент поля хранится тремя 256-битными словами EVM:

```text
x = x0 + x1 * 2^256 + x2 * 2^512.
```

Текущая лучшая реализация использует:

```text
Montgomery representation + CIOS Montgomery multiplication + manually unrolled Yul hot path.
```

Нужно исследовать именно операции:

```text
montMul3
montSqr3
```

Если возможно снизить стоимость больше чем на 10%, нужно предложить и реализовать экспериментальный вариант рядом с текущим подходом. Если невозможно, нужно строго объяснить, почему текущая реализация близка к практическому минимуму для EVM.

## 2. Текущие gas-метрики

Актуальные измерения production CIOS:

| Операция | Реализация | Gas/op |
|---|---|---:|
| `montMul3` | internal hot path, Montgomery/CIOS | 2,959 |
| `montSqr3` | internal hot path, Montgomery/CIOS | 2,947 |
| `montMul3` | external stack ABI | 3,316 |
| `montSqr3` | external stack ABI | 3,170 |
| `add3` | internal | 284 |
| `sub3` | external stack ABI | 588 |
| `inv3Modexp` | ModExp precompile | 42,647 |

Уже проверенные альтернативы:

| Вариант | Gas/op | Статус |
|---|---:|---|
| Montgomery/CIOS | 2,959 | лучший текущий вариант |
| Barrett | 46,998 | сильно хуже |
| FIOS | 18,509 | сильно хуже |
| Comba/SOS | около 18,772 | сильно хуже |
| Square-specialized Comba | около 18,420 | чуть лучше Comba, но сильно хуже CIOS |
| Branchless add | 767 external | хуже production add external 678 |

Не нужно заново предлагать Barrett/FIOS/обычный Comba как основной путь: они уже реализованы и оказались хуже.

## 3. Нижняя оценка на `montMul3`

Один элемент поля хранится как 3 limb-а:

```text
a = a0 + a1 * 2^256 + a2 * 2^512
b = b0 + b1 * 2^256 + b2 * 2^512
```

Обычное произведение требует все попарные limb-products:

```text
3 * 3 = 9
```

CIOS Montgomery-редукция для 3 limb-ов выполняет 3 шага. На каждом шаге добавляется:

```text
m_i * p
```

где `p` — трехсловный модуль поля. Значит на каждом шаге нужны 3 limb-products, всего:

```text
3 * 3 = 9
```

Итого для общего Montgomery-умножения:

```text
9 limb-products для a*b
+
9 limb-products для REDC
=
18 полных 256x256 -> 512 произведений.
```

В EVM нет `mulhi`. Поэтому одно 512-битное произведение считается так:

```yul
lo := mul(u, v)                         // 5 gas
mm := mulmod(u, v, not(0))              // 8 gas
hi := sub(sub(mm, lo), lt(mm, lo))      // 3 + 3 + 3 gas
```

Минимум:

```text
5 + 8 + 3 + 3 + 3 = 22 gas
```

Только 18 wide-products:

```text
18 * 22 = 396 gas
```

Но каждый продукт нужно добавить в аккумулятор. Минимальная модель добавления 512-битного продукта требует хотя бы:

```text
ADD + LT для low word
ADD + LT для high word
```

то есть примерно:

```text
2 * (3 + 3) = 12 gas
```

Тогда:

```text
18 * (22 + 12) = 612 gas
```

Плюс 3 low-word умножения для Montgomery-коэффициентов:

```text
3 * 5 = 15 gas
```

Плюс carry propagation, shifts, final compare and conditional subtract. Очень грубо:

```text
150..300 gas
```

Жесткая идеализированная нижняя оценка:

```text
~777..927 gas/op
```

Более реалистичная практическая нижняя граница с учетом stack pressure, `DUP/SWAP`, Yul/Solidity codegen и отсутствия `mulhi`:

```text
~1500..2200 gas/op
```

Текущая реализация:

```text
2959 gas/op
```

Между идеализированной/практической нижней оценкой и текущей реализацией есть заметный разрыв. Нужно проверить, является ли он неизбежным для EVM/Yul, или его можно сократить.

## 4. Текущая production-реализация, которую нужно анализировать

Ниже приведен самодостаточный фрагмент текущей лучшей реализации. Это именно тот код, который сейчас дает около `2959 gas/op` для `montMul3`.

```solidity
// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

/// @notice Minimal current best 3-limb arithmetic for MNT4-753 base field.
library CurrentBigIntMNT3 {
    uint256 private constant P_0  = 0x685acce9767254a4638810719ac425f0e39d54522cdd119f5e9063de245e8001;
    uint256 private constant P_1  = 0x7fdb925e8a0ed8d99d124d9a15af79db117e776f218059db80f0da5cb537e38;
    uint256 private constant P_2  = 0x1c4c62d92c41110229022eee2cdadb7f997505b8fafed5eb7e8f96c97d873;

    uint256 private constant R2_0 = 0xa896a656a0714c7da24bea56242b3507c7d9ff8e7df03c0a84717088cfd190c8;
    uint256 private constant R2_1 = 0xe03c79cac4f7ef07a8c86d4604a3b5972f47839ef88d7ce880a46659ff6f3ddf;
    uint256 private constant R2_2 = 0x2a33e89cb485b081f15bcbfdacaf8e4605754c3817232505daf1f4a81245;

    // MAGIC = -p^{-1} mod 2^256.
    uint256 private constant MAGIC = 0x4adb7a6352a3a656d9e1947eee113b7a7fd403903e304c4cf2044cfbe45e7fff;

    function montMul3(
        uint256 a0, uint256 a1, uint256 a2,
        uint256 b0, uint256 b1, uint256 b2
    ) internal pure returns (uint256 r0, uint256 r1, uint256 r2) {
        assembly ("memory-safe") {
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

            // CIOS step 0: multiply by a0 and reduce one limb.
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

            // CIOS step 1: multiply by a1 and reduce one limb.
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

            // CIOS step 2: multiply by a2 and reduce one limb.
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

            // Final conditional subtraction: if t >= p, then t -= p.
            let ge := 0
            if gt(t2, p2) { ge := 1 }
            if eq(t2, p2) {
                if gt(t1, p1) { ge := 1 }
                if eq(t1, p1) {
                    if iszero(lt(t0, p0)) { ge := 1 }
                }
            }

            if ge {
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

    /// @notice Current best squaring path: square is implemented as multiplication by itself.
    function montSqr3(
        uint256 a0, uint256 a1, uint256 a2
    ) internal pure returns (uint256 r0, uint256 r1, uint256 r2) {
        return montMul3(a0, a1, a2, a0, a1, a2);
    }

    function toMontgomery3(
        uint256 x0, uint256 x1, uint256 x2
    ) internal pure returns (uint256 r0, uint256 r1, uint256 r2) {
        return montMul3(x0, x1, x2, R2_0, R2_1, R2_2);
    }

    function fromMontgomery3(
        uint256 x0, uint256 x1, uint256 x2
    ) internal pure returns (uint256 r0, uint256 r1, uint256 r2) {
        return montMul3(x0, x1, x2, 1, 0, 0);
    }
}
```

## 5. Минимальный harness для проверки нового варианта

Если предлагается новый вариант, он должен иметь тот же интерфейс:

```solidity
function montMul3(
    uint256 a0, uint256 a1, uint256 a2,
    uint256 b0, uint256 b1, uint256 b2
) internal pure returns (uint256 r0, uint256 r1, uint256 r2)
```

и/или:

```solidity
function montSqr3(
    uint256 a0, uint256 a1, uint256 a2
) internal pure returns (uint256 r0, uint256 r1, uint256 r2)
```

Корректность нужно проверять сравнением с текущей production-реализацией `CurrentBigIntMNT3`.

Пример минимального Foundry-style теста:

```solidity
pragma solidity 0.8.33;

import "forge-std/Test.sol";

contract CandidateHarness {
    function currentMul3(
        uint256 a0, uint256 a1, uint256 a2,
        uint256 b0, uint256 b1, uint256 b2
    ) external pure returns (uint256 r0, uint256 r1, uint256 r2) {
        return CurrentBigIntMNT3.montMul3(a0, a1, a2, b0, b1, b2);
    }

    function currentSqr3(
        uint256 a0, uint256 a1, uint256 a2
    ) external pure returns (uint256 r0, uint256 r1, uint256 r2) {
        return CurrentBigIntMNT3.montSqr3(a0, a1, a2);
    }

    // Replace CandidateBigIntMNT3 with proposed implementation.
    function candidateMul3(
        uint256 a0, uint256 a1, uint256 a2,
        uint256 b0, uint256 b1, uint256 b2
    ) external pure returns (uint256 r0, uint256 r1, uint256 r2) {
        return CandidateBigIntMNT3.montMul3(a0, a1, a2, b0, b1, b2);
    }

    function candidateSqr3(
        uint256 a0, uint256 a1, uint256 a2
    ) external pure returns (uint256 r0, uint256 r1, uint256 r2) {
        return CandidateBigIntMNT3.montSqr3(a0, a1, a2);
    }
}

contract CandidateBench {
    uint256 internal constant N = 512;

    uint256 private constant P_0 = 0x685acce9767254a4638810719ac425f0e39d54522cdd119f5e9063de245e8001;
    uint256 private constant P_1 = 0x7fdb925e8a0ed8d99d124d9a15af79db117e776f218059db80f0da5cb537e38;
    uint256 private constant P_2 = 0x1c4c62d92c41110229022eee2cdadb7f997505b8fafed5eb7e8f96c97d873;

    function benchCurrentMul3() external pure returns (uint256 r0, uint256 r1, uint256 r2) {
        (uint256 a0, uint256 a1, uint256 a2) = CurrentBigIntMNT3.toMontgomery3(
            P_0 - 0x123456789abcdef0123456789abcdef0,
            P_1 - 0x11111111111111111111111111111111,
            P_2 - 0x12345
        );
        (uint256 b0, uint256 b1, uint256 b2) = CurrentBigIntMNT3.toMontgomery3(
            P_0 - 0x0fedcba9876543210fedcba987654321,
            P_1 - 0x22222222222222222222222222222222,
            P_2 - 0x23456
        );
        for (uint256 i; i < N; ) {
            (a0, a1, a2) = CurrentBigIntMNT3.montMul3(a0, a1, a2, b0, b1, b2);
            unchecked { ++i; }
        }
        return (a0, a1, a2);
    }

    function benchCandidateMul3() external pure returns (uint256 r0, uint256 r1, uint256 r2) {
        (uint256 a0, uint256 a1, uint256 a2) = CurrentBigIntMNT3.toMontgomery3(
            P_0 - 0x123456789abcdef0123456789abcdef0,
            P_1 - 0x11111111111111111111111111111111,
            P_2 - 0x12345
        );
        (uint256 b0, uint256 b1, uint256 b2) = CurrentBigIntMNT3.toMontgomery3(
            P_0 - 0x0fedcba9876543210fedcba987654321,
            P_1 - 0x22222222222222222222222222222222,
            P_2 - 0x23456
        );
        for (uint256 i; i < N; ) {
            (a0, a1, a2) = CandidateBigIntMNT3.montMul3(a0, a1, a2, b0, b1, b2);
            unchecked { ++i; }
        }
        return (a0, a1, a2);
    }
}
```

## 6. Основные направления для проверки

### 6.1. Opcode-level разбор текущего hot path

Нужно оценить, сколько примерно в текущем `montMul3` реально исполняется:

- `MUL`;
- `MULMOD`;
- `ADD`;
- `SUB`;
- `LT`;
- `GT/EQ/ISZERO`;
- `DUP/SWAP`, насколько возможно оценить по IR/asm;
- memory operations, если они появляются после компиляции.

Цель — понять, куда уходит разрыв между нижней оценкой и `2959 gas/op`.

### 6.2. All-stack/manual-Yul вариант

Проверить возможность еще более ручного варианта `montMul3`:

- полностью внутри одного `assembly` block;
- минимум helper-функций;
- минимум memory access;
- предсказуемый порядок аккумулятора;
- оптимизированный carry propagation;
- минимизация `DUP/SWAP` через порядок вычислений;
- явное использование констант модуля и `MAGIC`;
- без generic loops.

Текущий код уже близок к этому, но нужно проверить, можно ли улучшить порядок вычислений и переносов.

### 6.3. Square-specialized CIOS, не Comba

Уже проверялся square-specialized Comba/SOS, но он материализует широкое произведение и оказался дорогим.

Нужно проверить другую идею: square-specialized CIOS, где симметрия square используется внутри CIOS-порядка, без materialized product в памяти.

Если это невозможно или не дает выигрыша, объяснить почему.

### 6.4. Modulus-specific reduction

Проверить форму модуля:

```text
P_0 = 0x685acce9767254a4638810719ac425f0e39d54522cdd119f5e9063de245e8001
P_1 = 0x7fdb925e8a0ed8d99d124d9a15af79db117e776f218059db80f0da5cb537e38
P_2 = 0x1c4c62d92c41110229022eee2cdadb7f997505b8fafed5eb7e8f96c97d873
```

Проверить, есть ли полезная специальная структура:

- sparse limb;
- small high limb;
- pseudo-Mersenne-like relation;
- возможность заменить часть умножений на shift/add/sub;
- возможность улучшить reduction по модулю именно этого поля.

Если структуры нет, явно зафиксировать.

### 6.5. Final subtraction optimization

Проверить, можно ли дешевле реализовать:

```text
if r >= p: r -= p
```

Варианты:

- compare + conditional subtract;
- subtract then conditional select;
- branchless select;
- carry-based select;
- сохранение результата в `[0, 2p)` для внутренних операций, если это безопасно.

Если предлагается relaxed representation `[0, 2p)`, нужно доказать, что последующие Montgomery-операции корректны и что экономия не теряется при нормализации.

### 6.6. Проверка возможности убрать часть `mulmod`

`mulmod(u, v, not(0))` нужен для high word 512-битного произведения. Но нужно проверить, есть ли места, где high word:

- не нужен;
- может быть ограничен bounds-анализом;
- может быть восстановлен дешевле;
- может быть отложен.

Важно: нельзя ломать корректность для full-width входов около модуля.

## 7. Критерии успеха

### Сильный успех

Новый вариант корректен и дает:

```text
montMul3 или montSqr3 gas/op <= 2660
```

Это больше 10% улучшения относительно `2959 gas/op`.

Тогда нужно:

1. показать код;
2. объяснить, почему он быстрее;
3. показать gas до/после;
4. указать, можно ли переносить в production.

### Умеренный успех

Новый вариант дает `3-10%` улучшения. Нужно объяснить, стоит ли усложнять код ради такого выигрыша.

### Отрицательный результат

Если улучшение меньше 3% или вариант хуже, нужно честно зафиксировать:

1. что проверено;
2. почему не сработало;
3. где теряется gas;
4. почему текущий CIOS остается лучшим production-вариантом.

## 8. Что не нужно делать

Не нужно заново предлагать как новый результат:

- Barrett reduction;
- FIOS в текущем стиле;
- обычный Comba/SOS;
- memory-heavy square Comba;
- branchless add как основной путь;
- перенос вычислений в off-chain proof;
- изменение архитектуры pairing verifier.

Эти направления уже проверены или относятся к другим этапам.

## 9. Ожидаемый итоговый ответ

Нужен итоговый отчет в формате:

1. какие участки текущего `montMul3` создают основной overhead;
2. какие оптимизации проверены;
3. какой код предложен, если предложен;
4. какие тесты нужны для проверки;
5. таблица gas до/после;
6. можно ли снизить gas больше чем на 10%;
7. если да — как именно переносить в production;
8. если нет — почему текущая реализация практически оптимальна для EVM.

Особенно важно объяснить разрыв:

```text
нижняя оценка ~777..927 gas/op
реалистичная нижняя оценка ~1500..2200 gas/op
текущая реализация 2959 gas/op
```

и ответить, можно ли этот разрыв сократить.
