# L7: lollipop-305 Article640 verifier — Solidity/Yul hot-path и gas-результаты

## 1. Что реализовано

Для исследовательского кандидата `lollipop-305-158` реализован минимальный полный on-chain verifier-слой, аналогичный прямому режиму `article640_mnt4_verifier`.

Реализованный поток:

```text
Rust backend
  -> строит P in G1, Q' in G2 twist
  -> вычисляет combined prepared line values для equation e(P,Q)e(-P,Q)=1
  -> строит Miller accumulator f
  -> строит witness c, c^{-1}, где c^r = f
  -> пишет fixture

Solidity/Yul verifier
  -> читает prepared line-value blob
  -> проверяет Miller recurrence
  -> режим direct FE: проверяет f^((p^4-1)/r)=1
  -> режим residue FE: проверяет c*c^{-1}=1 и c^r=f
```

Код:

- `src/Lollipop305Article640Verifier.sol`
- `rust_backend/src/bin/lollipop305_article640_fixture.rs`
- `test/Lollipop305Article640Verifier.t.sol`
- `docs/lollipop305_article640_fixture.words.hex`

## 2. Формат prepared line-value blob

Каждый шаг Miller loop кодируется как:

```text
op || line
```

где:

- `op = 1` означает doubling step: on-chain выполняется `f <- f^2 * line`;
- `op = 0` означает addition/subtraction step: on-chain выполняется `f <- f * line`;
- `line` — один элемент `Fp4` в Montgomery-представлении;
- `Fp4` хранится как 8 слов EVM:

```text
c0.c0[0], c0.c0[1],
c0.c1[0], c0.c1[1],
c1.c0[0], c1.c0[1],
c1.c1[0], c1.c1[1].
```

Для текущего fixture:

```text
steps = 199
line blob size = 199 * 9 * 32 = 57,312 bytes
```

Это prepared line-value формат: контракт не строит точки `T` и не вычисляет line coefficients, а проверяет саму последовательность умножений в Miller accumulator. Поэтому этот режим измеряет стоимость hot-path `Fp4`-арифметики, но еще не является полным line-cache soundness verifier.

## 3. Проверяемые утверждения

### Miller core

Контракт получает prepared lines и проверяет:

```text
f_0 = 1,
f_{i+1} =
  f_i^2 * line_i, если op_i = 1,
  f_i   * line_i, если op_i = 0.
```

В конце сравнивается:

```text
f_n == f_expected,
```

где `f_expected` получен Rust backend.

### Direct final exponentiation

Контракт считает:

```text
f_n^((p^4-1)/r)
```

и проверяет, что результат равен `1`.

### Residue-style проверка

Контракт получает `c` и `c^{-1}` и проверяет:

```text
c * c^{-1} = 1,
c^r = f_n.
```

Если `c^r = f_n`, то:

```text
f_n^((p^4-1)/r) = (c^r)^((p^4-1)/r) = c^(p^4-1) = 1.
```

То есть длинная финальная экспонента заменяется более коротким возведением `c^r`, где `r` имеет около 158 бит.

## 4. Gas-результаты

Команда:

```bash
forge test --root lollipop305_research --match-path test/Lollipop305Article640Verifier.t.sol -vv --gas-report
```

Результат:

| Режим | Что проверяет | Gas |
|---|---|---:|
| Miller core | Только recurrence `f <- f^2 * line` / `f <- f * line` | `5,289,040` |
| Direct FE | Miller core + полная финальная экспонента | `30,292,044` |
| Residue FE | Miller core + проверка `c*c^{-1}=1`, `c^r=f` | `8,669,753` |

## 5. Сравнение с MNT4-753

Для MNT4-753 ранее были измерены:

| Режим | MNT4-753 gas | lollipop-305 gas | Улучшение |
|---|---:|---:|---:|
| Miller core | `87,747,219` | `5,289,040` | `16.6x` |
| Direct FE / full equation | `115,997,313` | `30,292,044` | `3.8x` |
| Residue FE | `93,879,746` | `8,669,753` | `10.8x` |

## 6. Интерпретация

Результат показывает, что lollipop-направление действительно снижает стоимость EVM-арифметики. Причины:

1. базовое поле имеет 305 бит и помещается в 2 EVM-лимба, а не в 3;
2. loop scalar имеет около 153 бит;
3. `Fp4.mul` и `Fp4.square` дешевле, чем для MNT4-753;
4. residue-проверка заменяет длинную финальную экспоненту на проверку `c^r=f`.

Ограничение: текущая версия проверяет prepared line values и Miller recurrence, но не доказывает on-chain, что сами line values были построены из `Q`. Для полного production-grade варианта нужно добавить line-cache soundness layer: либо пересчет line coefficients, либо polynomial/commitment proof. Поэтому текущий lollipop verifier является сильным исследовательским результатом по gas, но не финальной production-заменой pairing precompile.
