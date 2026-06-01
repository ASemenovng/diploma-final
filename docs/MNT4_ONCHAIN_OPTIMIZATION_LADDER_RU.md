# F4 — оптимизационная лестница полного on-chain вычисления MNT4-сопряжения

## 1. Задача этапа

Задача F4 — показать, как из заведомо непрактичного наивного Tate pairing постепенно получается текущая оптимизированная on-chain реализация. Документ отвечает на вопрос научного руководителя: какие именно оптимизации были применены, что они означают технически и насколько каждая из них снижает стоимость.

Важное ограничение: не каждая оптимизация существует как отдельный полный контракт `pairing()`. Например, `Karatsuba` или `cheap non-residue multiplication` — это локальные оптимизации арифметики расширений, а `fixed-Q prepared sparse blob` — уже интегральный режим всего pairing. Поэтому ниже используются три связанные таблицы:

1. **Интегральная лестница** — стоимость полного pairing или его максимально близкого production-режима.
2. **Арифметическая лестница** — стоимость базовых операций `Fq/Fq2/Fq4`.
3. **Лестница Miller/FE/cache** — вклад отдельных стадий полного вычисления.

Такой формат не смешивает несравнимые числа, но при этом показывает общий путь оптимизации.

## 2. Команды воспроизведения

Наивная cost model:

```bash
cd baselines/naive_tate_mnt4
../../scripts/run_naive_tate.sh
```

Основная ladder-таблица:

```bash
cd /Users/a.i.semenov/mnt4-pairing-final/onchain_full
forge test --match-path test/MNT4OptimizationLadder.t.sol -vv --gas-report
```

Базовая 3-limb арифметика:

```bash
cd /Users/a.i.semenov/mnt4-pairing-final/onchain_full
forge test --match-path test/BigIntMNTFinal.t.sol \
  --match-test 'testGasBench_(montMul3_internal|montSqr3_internal)' -vv --gas-report
```

Альтернативы и специальные операции:

```bash
cd /Users/a.i.semenov/mnt4-pairing-final/onchain_full
forge test --match-path test/MNT4ArithmeticAlgorithmStudy.t.sol \
  --match-test testGasReport_algorithmStudy_allOps -vv --gas-report
```

Операции в расширениях:

```bash
cd /Users/a.i.semenov/mnt4-pairing-final/onchain_full
forge test --match-path test/MNT4ExtensionV3Final.t.sol \
  --match-test testGasReport_internalStyleBench_allOps -vv --gas-report
```

## 3. Интегральная лестница полного вычисления

Эта таблица показывает крупные переходы от наивной модели к текущему optimized on-chain пути. Процент считается относительно предыдущей сопоставимой строки.

| Шаг | Оптимизация | Описание | Результат по gas | Снижение |
|---:|---|---|---:|---:|
| 0 | Naive Tate cost model | Generic Solidity `Fq/Fq2/Fq4`, модель полного Tate loop, полный `Fq4` line, binary final exponentiation | 2,548,394,681 | — |
| 1 | Полный optimized fixed-Q on-chain | Применены Yul/CIOS arithmetic, Ate loop, Karatsuba, cheap non-residue multiplication, optimized FE; линии строятся on-chain | 258,753,182 | 89.85% |
| 2 | Fixed-Q prepared sparse blob | Коэффициенты линий подготовлены заранее, передаются как blob, Miller accumulator и FE остаются on-chain | 79,588,799 | 69.24% |
| 3 | Fixed-Q prepared sparse code-shards | Тот же prepared sparse путь, но кэш читается из data-контрактов через `EXTCODECOPY` | 79,586,596 | 0.003% |

Первая строка является строгой нижней экстраполяцией измеренных микроблоков,
а не полным исполняемым вызовом. Вывод по интегральной таблице: основной
переход происходит в два больших этапа. Сначала наивная арифметика и полный
Tate loop заменяются optimized on-chain схемой, что снижает стоимость примерно
в 9.85 раза. Затем перенос line generation из on-chain в prepared sparse cache
снижает стоимость еще примерно в 3.25 раза.

## 4. Арифметическая лестница: `Fq/Fq2/Fq4`

Эта таблица показывает, почему итоговая реализация вообще стала возможной. Все следующие оптимизации применяются к базовой арифметике, из которой затем собираются Miller loop и final exponentiation.

| Оптимизация | Описание | Было | Стало | Снижение |
|---|---|---:|---:|---:|
| Montgomery/CIOS + Yul arithmetic | Наивная 3-limb операция на Solidity заменяется CIOS Montgomery multiplication с ручной Yul-логикой переносов | `Fq.mul = 18,770` | `Fq.mul = 2,959` | 84.24% |
| Montgomery/CIOS square | Аналогично для `Fq.square`; используется тот же production hot path | `Fq.square ≈ 18,770` как naive mul-by-self ориентир | `Fq.square = 2,947` | около 84.30% |
| Karatsuba extension arithmetic | В `Fq2` и `Fq4` уменьшается число вложенных умножений: 4 умножения заменяются на 3 | `Fq2.mul = 110,080` | `Fq2.mul = 11,877` | 89.21% |
| Karatsuba + optimized tower for `Fq4` | В `Fq4 = Fq2[v]/(v^2-u)` используется tower/Karatsuba-структура вместо generic full object multiplication | `Fq4.mul = 486,819` | `Fq4.mul = 42,764` | 91.22% |
| Cheap multiplication by `u` in `Fq2` | Умножение на `u` заменяется формулой `(x0+x1u)u = 13x1 + x0u` | `12,588` | `1,731` | 86.25% |
| Cheap multiplication by `v` in `Fq4` | Умножение на `v` заменяется перестановкой координат и cheap `mulByU` | `42,253` | `1,859` | 95.60% |
| Cheap multiplication by `13` | Умножение на малую константу заменяется сложениями и широкой редукцией | `2,961` | `1,481` | 49.98% |

### 4.1. Что именно означает Montgomery/CIOS

Элемент поля MNT4-753 не помещается в одно слово EVM, поэтому хранится в трех 256-битных limb. Прямое умножение двух таких чисел дает до шести limb, после чего нужна редукция по модулю `p`. Наивная Solidity-реализация делает это через generic multi-limb операции и memory arrays.

Production-вариант использует Montgomery-представление:

```text
x -> xR mod p, где R = 2^768.
```

Тогда после умножения можно выполнять Montgomery reduction без деления на `p`. CIOS означает `Coarsely Integrated Operand Scanning`: умножение и редукция идут в одном цикле по limb, а не как две отдельные большие процедуры. В EVM это критично, потому что нет дешевого 512-битного умножения и нет native 753-битной арифметики.

### 4.2. Что именно означает Karatsuba в расширениях

Для квадратичного расширения:

```text
(a0 + a1u)(b0 + b1u)
```

наивная формула требует четыре умножения:

```text
a0b0, a0b1, a1b0, a1b1.
```

Karatsuba использует три:

```text
v0 = a0b0,
v1 = a1b1,
v2 = (a0+a1)(b0+b1),
c1 = v2 - v0 - v1.
```

Это снижает число дорогих умножений в нижнем поле. Для `Fq4` та же идея применяется поверх `Fq2`.

## 5. Лестница Miller loop

Miller loop — главный источник стоимости после того, как финальная экспонента оптимизирована. Здесь удобно смотреть не только полный pairing, но и Miller accumulator отдельно.

| Оптимизация | Описание | Было | Стало | Снижение |
|---|---|---:|---:|---:|
| Ate loop вместо полного Tate loop | Полный loop по `r` заменяется коротким NAF loop `ATE_LOOP_ENC` | `912,988,940` | `427,284,953` | 53.20% |
| Sparse line multiplication | Линия не строится как полный `Fq4`, а применяется в разреженном виде | `973,261` gas/step | около `137,874` gas/digit | около 85.83% |
| Fixed-Q on-chain line generation | Точка `Q` фиксирована, но линии еще строятся on-chain | — | `258,753,182` | measured baseline |
| Fixed-Q prepared sparse blob | Линии уже подготовлены и переданы как blob | `258,753,182` | `79,588,799` | 69.24% |
| Aggressive fused Miller hot path | Дополнительное слияние `square + sparse line multiplication` в hot path | `51,978,344` | `51,949,399` | 0.056% |

### 5.1. Откуда берется оценка Ate loop

Для полного Tate loop по `r`:

```text
bitlength(r) = 753,
popcount(r) = 373.
```

Наивный accumulator:

```text
752 * cost(f^2 * line) + 372 * cost(f * line)
= 752 * 973,261 + 372 * 486,819
= 912,988,940 gas.
```

В optimized Ate path используется `ATE_LOOP_ENC`:

```text
loop length = 377,
non-zero NAF digits = 124.
```

Тогда аналогичная модель дает:

```text
377 * 973,261 + 124 * 486,819 = 427,284,953 gas.
```

Это не финальная стоимость production-кода, а изолированная оценка эффекта `Tate loop -> Ate loop` при прочих равных.

### 5.2. Почему sparse lines дают большой выигрыш

Наивный line value — это полный элемент `Fq4`. Тогда каждый шаг выглядит так:

```text
f <- f^2 * line_full.
```

В prepared sparse path линия хранится компактнее: как коэффициенты, которые позволяют выполнить специализированное умножение без полного generic `Fq4.mul`. Поэтому полный measured Miller accumulator в prepared sparse режиме стоит:

```text
millerPreparedSparseBlobDigest = 51,978,344 gas.
```

Если разделить на `377` digit в Ate loop, получаем ориентир:

```text
51,978,344 / 377 ≈ 137,874 gas/digit.
```

Это намного меньше generic `973,261 gas/step` из наивного baseline.

## 6. Лестница final exponentiation

Финальная экспонента переводит результат Miller loop в целевую подгруппу. Наивно она выглядит как:

```text
f^((q^4-1)/r).
```

Binary square-and-multiply для MNT4-753 требует:

```text
2259 squares + 1100 multiplications.
```

| Оптимизация | Описание | Было | Стало | Снижение |
|---|---|---:|---:|---:|
| Generic binary final exponentiation | Прямое возведение в степень `(q^4-1)/r` | `1,635,405,741` | — | — |
| Frobenius/w0 decomposition | Показатель разбивается на easy part, Frobenius part и `w0`-часть | `1,635,405,741` | около `28,134,825` | 98.28% |

Фактический overhead optimized FE берется из measured prepared path:

```text
pairingPreparedSparseBlobDigest - millerPreparedSparseBlobDigest
= 80,113,169 - 51,978,344
= 28,134,825 gas.
```

Именно поэтому в итоговой реализации не используется generic binary exponentiation. Даже после оптимизации FE остается дорогой, но уже не является главным источником сотен миллионов gas.

## 7. Хранение prepared cache: blob и code-shards

Prepared sparse coefficients можно передавать двумя способами.

| Способ | Описание | Gas | Разница |
|---|---|---:|---:|
| Blob/memory | Prepared cache приходит как blob и используется из памяти | `79,588,799` | baseline |
| Code-shards | Prepared cache хранится в runtime bytecode data-контрактов и читается через `EXTCODECOPY` | `79,586,596` | -0.003% |

С точки зрения runtime gas разница почти нулевая. Но архитектурно это разные режимы:

- blob удобен для простого вызова, но несет большой calldata/input payload;
- code-shards требуют предварительного деплоя data-контрактов, но позволяют переиспользовать большой cache без повторной передачи calldata.

## 8. Итоговая таблица в формате “оптимизация -> результат”

| Оптимизация | Описание | Результат по gas | Снижение |
|---|---|---:|---:|
| Naive Tate cost model | Строгая нижняя экстраполяция измеренных наивных микроблоков | `2,548,394,681` | — |
| Montgomery/CIOS arithmetic | Базовое `Fq.mul` вместо pure Solidity multi-limb | `18,770 -> 2,959` | 84.24% |
| Ate loop вместо полного Tate loop | Сокращение длины Miller loop | `912,988,940 -> 427,284,953` | 53.20% |
| Karatsuba extension arithmetic | Меньше вложенных умножений в `Fq2/Fq4` | `Fq4.mul: 486,819 -> 42,764` | 91.22% |
| Cheap non-residue multiplication | Специальные формулы для `u`, `v`, `13` | `Fq4*V: 42,253 -> 1,859` | 95.60% |
| Sparse line multiplication | Линия применяется как sparse object | `973,261 -> ~137,874 per digit` | ~85.83% |
| Fixed-Q on-chain line generation | Первый полный optimized on-chain baseline | `258,753,182` | 89.85% vs naive total |
| Fixed-Q prepared sparse blob | Убираем on-chain generation линий | `258,753,182 -> 79,588,799` | 69.24% |
| Fixed-Q prepared sparse code-shards | Prepared cache читается через `EXTCODECOPY` | `79,588,799 -> 79,586,596` | 0.003% |
| Frobenius/w0 final exponentiation | Не используем generic binary exponentiation | `1,635,405,741 -> ~28,134,825` | 98.28% |
| Aggressive fused Miller hot path | Дополнительное слияние в уже оптимизированном hot path | `51,978,344 -> 51,949,399` | 0.056% |

## 9. Главный вывод

F4 показывает, что итоговая стоимость около `80M gas` для fixed-Q prepared sparse pairing не является результатом одной оптимизации. Это сумма нескольких независимых уровней:

```text
naive Solidity arithmetic
  -> Montgomery/CIOS/Yul arithmetic
  -> Ate loop
  -> Karatsuba extension tower
  -> cheap non-residue multiplication
  -> sparse line multiplication
  -> fixed-Q prepared cache
  -> Frobenius/w0 final exponentiation
  -> fused Miller hot path
```

Самые сильные эффекты дают:

1. переход от наивной Solidity arithmetic к optimized Yul/CIOS;
2. переход от полного Tate loop к Ate loop;
3. переход от on-chain line generation к prepared sparse cache;
4. замена generic final exponentiation на Frobenius/w0 decomposition.

После этих шагов оставшаяся стоимость определяется тем, что контракт все еще выполняет Miller accumulator в `Fq4` над 753-битным полем. Поэтому дальнейшее кратное снижение требует уже не только низкоуровневой оптимизации Solidity, а изменения самой модели проверки Miller loop: polynomial relation check, proof/opening layer или другое семейство кривых.
