# Исследование алгоритмов арифметики MNT4-753 в Solidity/Yul

## 1. Цель документа

Этот документ фиксирует часть работы, связанную с замечаниями о полноте исследования арифметики: нужно не только реализовать вычисление сопряжения, но и показать, почему выбранная реализация базовой арифметики является наиболее разумной для EVM.

Исследование покрывает:

- представление элементов 753-битного поля;
- Montgomery- и Barrett-редукцию;
- CIOS-, FIOS- и Comba/SOS-организацию умножения;
- арифметику башни расширений `Fq2/Fq4`;
- Karatsuba-формулы;
- cheap non-residue multiplication;
- lazy reduction variants;
- branchless conditional reduction;
- sparse/prepared line arithmetic для цикла Миллера.

Основной код находится в:

- `onchain_full/src/BigIntMNT.sol`;
- `onchain_full/src/BigIntMNTBarrett.sol`;
- `onchain_full/src/BigIntMNTFIOS.sol`;
- `onchain_full/src/BigIntMNTComba.sol`;
- `onchain_full/src/BigIntMNTBranchless.sol`;
- `onchain_full/src/MNT4Extension.sol`;
- `onchain_full/src/MNT4ExtensionAlgorithmVariants.sol`;
- `onchain_full/src/MNT4TatePairing.sol`.

Тесты и gas-бенчмарки находятся в:

- `onchain_full/test/BigIntMNTFinal.t.sol`;
- `onchain_full/test/BigIntMNTReductionVariants.t.sol`;
- `onchain_full/test/MNT4ExtensionV3Final.t.sol`;
- `onchain_full/test/MNT4ArithmeticAlgorithmStudy.t.sol`;
- `onchain_full/test/MNT4TatePairingV4.t.sol`.

## 2. Базовое поле и представление данных

Базовое поле MNT4-753 имеет модуль примерно 753 бит. Один элемент такого поля не помещается в одно 256-битное слово EVM, поэтому элемент хранится как три слова:

```text
x = x0 + x1 * 2^256 + x2 * 2^512.
```

В коде это представление используется в `BigIntMNT.sol`. Все основные операции принимают три limb-а и возвращают три limb-а.

Основной инвариант:

```text
0 <= x < p
```

для входов и выходов публичных арифметических функций. Внутри отдельных оптимизированных участков допускаются временные значения в более широком диапазоне, но на выходе функция снова возвращает редуцированное значение.

## 3. Montgomery arithmetic

### 3.1. Формальное описание

Пусть `B = 2^256`, `n = 3`, `R = B^n = 2^768`. Montgomery-представление элемента `a` задается как

```text
a~ = a * R mod p.
```

Если два элемента уже находятся в Montgomery-домене, то произведение вычисляется так:

```text
MontMul(a~, b~) = a~ * b~ * R^{-1} mod p = a*b*R mod p.
```

То есть результат снова остается в Montgomery-домене. Это важно для сопряжения: Miller loop и финальная экспонента содержат длинные цепочки умножений, поэтому вход в Montgomery-домен выполняется один раз, а дальше все промежуточные значения остаются в этом представлении.

### 3.2. Реализация

В `BigIntMNT.sol` реализованы:

- `add3` — сложение по модулю `p`;
- `sub3` — вычитание по модулю `p`;
- `montMul3` — Montgomery-умножение для 3 limb;
- `montSqr3` — специализированное возведение в квадрат;
- `toMontgomery3` и `fromMontgomery3`;
- `inv3` и `inv3Modexp`;
- `mulBy13` — специализированное умножение на малую константу `13`.

`montMul3` реализован в Yul и использует `mulmod(x, y, not(0))` для получения старшей половины 512-битного произведения двух 256-битных слов. Это стандартный прием в EVM, потому что отдельной инструкции `MULH` нет.

## 4. Barrett reduction

Barrett-редукция не использует Montgomery-домен. Она предварительно вычисляет константу

```text
mu = floor(B^(2n) / p)
```

и затем приближает частное при делении на `p`. Для одиночной редукции это может быть удобно, но для длинной цепочки умножений Barrett каждый раз заново строит приближенное частное и выполняет коррекции.

В проекте Barrett реализован в `BigIntMNTBarrett.sol` только как экспериментальный вариант. Он не используется в production path.

Результат измерений показывает, что для MNT4-753 в EVM Barrett существенно проигрывает Montgomery/CIOS.

## 5. CIOS, FIOS и Comba/SOS

### 5.1. CIOS

CIOS означает `Coarsely Integrated Operand Scanning`. Идея: внешний цикл проходит по словам одного операнда, а внутри каждого шага одновременно выполняются:

- накопление частичных произведений;
- вычисление Montgomery-коэффициента редукции;
- добавление кратного модуля;
- сдвиг аккумулятора.

В проекте CIOS является основным вариантом. Он реализован вручную и развернут для фиксированного размера `3 x 3` limb-а в `BigIntMNT.sol`.

### 5.2. FIOS

FIOS означает `Finely Integrated Operand Scanning`. В нем редукция интегрируется более мелко, внутри внутреннего цикла. На обычных процессорах такой подход иногда уменьшает промежуточное хранение. В EVM это не гарантирует выигрыша: дополнительные переносы, проверки и работа с memory могут оказаться дороже.

В проекте FIOS реализован в `BigIntMNTFIOS.sol`. Измерения показывают, что он существенно дороже CIOS.

### 5.3. Comba/SOS

Comba/SOS-подход сначала материализует полное произведение `3 x 3` limb-ов как 6-словный результат, а затем отдельно применяет Montgomery-редукцию. Формально поток такой:

```text
T = a * b
r = REDC(T)
```

В проекте добавлена экспериментальная реализация `BigIntMNTComba.sol`. Она нужна для проверки гипотезы: может ли product-scanning/Comba-организация быть дешевле текущего CIOS на фиксированном размере поля.

Результат: текущая Comba/SOS-реализация корректна, но дороже CIOS. Причина — необходимость материализовать промежуточный массив, больше операций переноса и больше memory pressure. Поэтому основной путь остается CIOS.

## 6. Extension towers, Karatsuba и non-residue

Для MNT4-753 используется башня расширений:

```text
Fq2 = Fq[u] / (u^2 - 13),
Fq4 = Fq2[v] / (v^2 - u).
```

Элемент `Fq2` хранится как пара элементов `Fq`:

```text
a = a0 + a1*u.
```

Элемент `Fq4` хранится как пара элементов `Fq2`:

```text
A = A0 + A1*v.
```

### 6.1. Karatsuba для Fq2

Обычное умножение в `Fq2` требует 4 умножения в `Fq`:

```text
(a0 + a1*u)(b0 + b1*u).
```

Karatsuba-форма использует 3 умножения:

```text
v0 = a0*b0,
v1 = a1*b1,
v2 = (a0+a1)(b0+b1),

c0 = v0 + 13*v1,
c1 = v2 - v0 - v1.
```

Эта формула реализована в `MNT4Extension.sol`.

### 6.2. Karatsuba для Fq4

Аналогично, для

```text
(A0 + A1*v)(B0 + B1*v), v^2 = u
```

используется:

```text
V0 = A0*B0,
V1 = A1*B1,
V2 = (A0+A1)(B0+B1),

C0 = V0 + u*V1,
C1 = V2 - V0 - V1.
```

Это уменьшает число `Fq2`-умножений с 4 до 3.

### 6.3. Cheap non-residue multiplication

Так как non-residue элементы малы и имеют специальную форму, умножение на них не нужно выполнять как generic field multiplication.

В проекте реализованы:

- `mulBy13`: умножение на `13` через сложения и одну финальную редукцию;
- `fq2MulByU`: перестановка коэффициентов и `mulBy13`;
- `fq4MulByV`: перестановка коэффициентов и `fq2MulByU`.

Новые тесты явно сравнивают specialized path с generic path.

## 7. Lazy reduction variants

Lazy reduction означает, что промежуточные суммы не всегда сразу приводятся к диапазону `[0,p)`. Например если `a,b < p`, то

```text
a + b < 2p.
```

Значит можно сначала выполнить обычное сложение limb-ов, а затем один раз условно вычесть `p`.

В проекте уже были низкоуровневые primitives:

- `add3NR` — сложение без редукции;
- `reduce3` — редукция из `[0,2p)`;
- `reduce3Wide16` — редукция из `[0,16p)`;
- `mulBy13` — использует lazy accumulation.

В рамках этого этапа добавлены экспериментальные extension-варианты в `MNT4ExtensionAlgorithmVariants.sol`:

- `fq2SqrLazyDouble`;
- `fq2MulLazyC0`.

Они проверены на равенство production-формулам. Изолированно они дают близкие значения, но при попытке встроить такой подход в основной extension path gas стал хуже из-за дополнительных вызовов редукции. Поэтому production-код оставлен без изменения, а lazy variants сохранены как исследовательское сравнение.

## 8. Branchless conditional reduction

Branchless reduction заменяет условный переход на выбор через битовую маску. Например вместо

```text
if x >= p:
    x = x - p
```

используется логика вида:

```text
mask = all_ones если вычитание успешно, иначе 0
result = (x-p)&mask | x&~mask
```

В обычной криптографической библиотеке это может быть важно для защиты от timing side-channel. В EVM вычисления публичны, а gas-стоимость важнее. Поэтому branchless-вариант добавлен как контрольный benchmark в `BigIntMNTBranchless.sol`.

Результат: branchless reduction не улучшает gas относительно текущего branch-based варианта.

## 9. Sparse lines и подготовленные коэффициенты

В цикле Миллера line-функции имеют специальную структуру. Их не нужно хранить как полный плотный элемент `Fq4`. Вместо этого используются sparse coefficients — только те компоненты, которые реально участвуют в подстановке точки `P`.

В `MNT4TatePairing.sol` реализованы:

- prepared fixed-Q line cache;
- sparse blob format;
- calldata/memory loaders;
- code-shards streaming;
- specialized line evaluation;
- specialized multiplication by line;
- fused helpers `_lineDoubleSparseMulPtrTo` и `_lineAddSparseMulPtrTo`.

Именно эта часть объясняет, почему prepared/sparse путь является обязательной оптимизацией для Miller loop: generic `Fq4`-умножение на каждом шаге было бы еще дороже.

## 10. Gas-результаты

### 10.1. Базовое поле

| Вариант | Операция | Gas/op | Вывод |
|---|---:|---:|---|
| Montgomery/CIOS | `Fp mul` | 2,959 | основной путь |
| Montgomery/CIOS | `Fp sqr` | 2,947 | основной путь |
| Barrett | `Fp mul` | 46,998 | существенно хуже |
| Barrett | `Fp sqr` | 47,172 | существенно хуже |
| FIOS | `Fp mul` | 18,509 | хуже CIOS |
| FIOS | `Fp sqr` | 18,543 | хуже CIOS |
| Comba/SOS | `Fp mul` | 18,301 | хуже CIOS |
| Comba/SOS | `Fp sqr` | 18,334 | хуже CIOS |

Comba/SOS gas/op получен из `benchCombaMul3` и `benchCombaSqr3`, где каждая функция выполняет 256 операций.

### 10.2. Branchless reduction

| Вариант | Total gas | Число операций | Gas/op | Вывод |
|---|---:|---:|---:|---|
| Branchless add/reduce | 2,212,143 | 4,096 | 540 | не лучше production add path |

### 10.3. Cheap non-residue multiplication

| Операция | Generic gas/op | Specialized gas/op | Улучшение |
|---|---:|---:|---:|
| `mulBy13` в `Fq` | 2,961 | 1,481 | примерно 2.0x |
| `mulByU` в `Fq2` | 12,587 | 1,731 | примерно 7.3x |
| `mulByV` в `Fq4` | 42,253 | 1,859 | примерно 22.7x |

Здесь generic path означает обычное умножение на соответствующий элемент расширения, а specialized path использует структуру non-residue.

### 10.4. Extension arithmetic

| Операция | Gas/op |
|---|---:|
| `Fq2 mul` | 11,877 |
| `Fq2 sqr` | 10,592 |
| `Fq4 mul` | 42,764 |
| `Fq4 sqr` | 36,606 |

Эти значения получены internal-style benchmark-ами из `MNT4ExtensionV3Final.t.sol`.

### 10.5. Lazy variants

| Вариант | Total gas | Число операций | Gas/op | Вывод |
|---|---:|---:|---:|---|
| Production `Fq2 mul` в новом isolated bench | 1,667,554 | 128 | 13,028 | baseline для сравнения |
| Lazy `Fq2 mul` | 1,628,056 | 128 | 12,719 | близко, но не переносится в production без ухудшения общего path |
| Production `Fq2 sqr` в новом isolated bench | 1,497,260 | 128 | 11,697 | baseline для сравнения |
| Lazy `Fq2 sqr` | 1,488,147 | 128 | 11,626 | микровыигрыш в изоляции |

При интеграционной проверке production `MNT4Extension.sol` lazy-подстановка ухудшила общую стоимость `Fq2/Fq4`, поэтому она не включена в основной путь.

## 11. Проверенные команды

Корректность новых вариантов:

```bash
cd /Users/a.i.semenov/mnt4-pairing-final/onchain_full
forge test --match-path test/MNT4ArithmeticAlgorithmStudy.t.sol -vv
```

Результат:

```text
7 passed; 0 failed; 0 skipped
```

Полный набор тестов `onchain_full`:

```bash
cd /Users/a.i.semenov/mnt4-pairing-final/onchain_full
forge test
```

Результат:

```text
167 passed; 0 failed; 0 skipped
```

Gas-report для новых сравнений:

```bash
cd /Users/a.i.semenov/mnt4-pairing-final/onchain_full
forge test --match-path test/MNT4ArithmeticAlgorithmStudy.t.sol \
  --match-test testGasReport_algorithmStudy_allOps --gas-report -vv
```

## 12. Итоговый выбор

На текущем наборе реализаций наиболее оптимальным вариантом для production остается:

```text
Montgomery representation
+ CIOS Montgomery multiplication
+ specialized Montgomery squaring
+ Karatsuba in Fq2/Fq4
+ cheap non-residue multiplication
+ sparse/prepared line arithmetic
+ pointer/packed memory API in hot paths.
```

Barrett, FIOS, Comba/SOS и branchless reduction были реализованы и измерены как альтернативы. Они не улучшают gas. Lazy reduction полезна локально для некоторых выражений, но в текущем Solidity/Yul layout не дает устойчивого выигрыша при переносе в общий extension path.

Дополнительно был реализован aggressive fused-вариант для шага `f <- f^2 * line(P)` в цикле Миллера. Он корректен и немного снижает gas, но выигрыш составляет только около 20k gas на полном single pairing path. Поэтому основной production path не был заменен: эксперимент показывает, что локальное слияние memory-операций не меняет порядок стоимости, так как доминируют умножения в `Fq2/Fq4`.

Таким образом, выбранный production path обоснован не только теоретически, но и экспериментально: конкурирующие варианты реализованы рядом, проходят correctness-проверки и либо проигрывают по gas, либо дают слишком малый выигрыш относительно сложности.

## 13. Оставшиеся идеи низкоуровневой оптимизации

Реалистичные идеи, которые еще можно исследовать отдельно, но которые уже выходят за рамки базового сравнения алгоритмов:

1. Полностью stack-only Comba без memory arrays. Текущая экспериментальная Comba/SOS версия материализует массив, поэтому проигрывает CIOS. Теоретически можно написать полностью развернутую Yul-версию без массивов, но она будет очень большой и сложной в аудите.
2. Полностью сгенерированный Yul-код для фиксированной башни `Fq/Fq2/Fq4`. Это может уменьшить ручные ошибки и дать более агрессивное unrolling, но усложнит build pipeline.
3. Альтернативная раскладка scratch memory для Miller loop. Сейчас pointer API уже снижает аллокации, но можно профилировать memory expansion и aliasing более тонко.

Идея дальнейшего слияния line evaluation и multiplication уже проверена отдельно в разделе 14. Она оказалась корректной, но не дала существенного выигрыша. Поэтому оставшиеся низкоуровневые направления имеют более исследовательский характер и не выглядят обязательными для текущей версии работы.

## 14. Дополнительный эксперимент: aggressive fusion для `f^2 * line(P)`

После базового сравнения был проверен еще один вариант низкоуровневой оптимизации Miller hot path: более плотное слияние шага

```text
f <- f^2 * line(P)
```

В production-path уже использовались prepared/sparse линии и helper-ы, которые не строят плотный `Fq4`-объект линии. Тем не менее старый путь все еще выполнял две последовательные операции:

```text
1. t <- f^2                      // полный промежуточный Fq4
2. f <- t * (ell0 + ell1 * v)    // sparse умножение на линию
```

Экспериментальный путь добавляет helper `_fq4SqrMulByLinePtrTo`, который раскрывает формулы над `Fq2` и сразу потребляет результат возведения в квадрат в sparse-умножении. Если `f = a + b v`, `v^2 = u`, а линия имеет вид `l0 + l1 v`, то используется:

```text
s0 = a^2 + u * b^2
s1 = 2ab
f^2 * line = (s0 + s1 v)(l0 + l1 v)
            = (s0 l0 + u s1 l1) + ((s0+s1)(l0+l1) - s0l0 - s1l1) v.
```

То есть промежуточный `Fq4` для `f^2` больше не материализуется как отдельный объект. Для multi-pairing семантика shared accumulator сохраняется: в каждом раунде accumulator возводится в квадрат только один раз, а затем последовательно умножается на линии всех точек.

### 14.1. Проверка корректности

Новый путь реализован как экспериментальный API с суффиксом `Aggressive`, не заменяя production-функции. Корректность проверяется сравнением digest полного Miller output:

```bash
cd /Users/a.i.semenov/mnt4-pairing-final/onchain_full
forge test --match-contract MNT4TatePairingV4Test \
  --match-test 'testPreparedSparseAggressive|testGasBench_(miller|pairing|multi_miller|multi_pairing)_fixedQ_prepared_sparse_digest' -vv
```

Результат:

```text
9 passed; 0 failed; 0 skipped
```

Проверенные сценарии:

| Сценарий | Что сравнивается |
|---|---|
| Single Miller | `millerLoopFixedQPreparedSparseBlobNoInvMemDigest` против `...Aggressive` |
| Single full pairing | `tatePairingFixedQPreparedSparseMemDigest` против `...Aggressive` |
| Multi Miller, 2 точки | `multiMillerLoopFixedQPreparedSparseBlobNoInvMemDigest` против `...Aggressive` |
| Full pairing digest | Старый путь с финальной экспонентой против aggressive Miller + та же финальная экспонента |

### 14.2. Gas-результаты

| Сценарий | Старый путь | Aggressive fusion | Изменение |
|---|---:|---:|---:|
| Single Miller digest | 238,581,004 | 238,560,411 | -20,593 |
| Single full pairing digest | 267,026,828 | 267,006,510 | -20,318 |
| Multi Miller digest, 2 точки | нет отдельного старого gas-теста в этом прогоне | 274,078,151 | - |

Вывод: вариант корректен, но выигрыш очень мал. Причина в том, что он уменьшает в основном memory traffic вокруг одного промежуточного `Fq4`, но не уменьшает число дорогих `Fq2/Fq4` умножений. Основная стоимость шага Миллера по-прежнему определяется длинной арифметикой 753-битного поля и количеством умножений в расширении.

Практический вывод для production: aggressive fusion можно оставить как исследовательский вариант, но он не меняет порядок стоимости. Для кратного снижения gas нужно менять математический протокол проверки цикла Миллера, а не только плотнее упаковывать локальные операции в Yul.
