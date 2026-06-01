# F8. Финальный отрицательный и граничный результат

## 1. Назначение отчета

Этот документ сводит в одну картину все результаты, полученные в проекте: теоретические выводы, Solidity/Yul-реализации, Rust reference/backend, gas-измерения, оценки constraints и исследование альтернативных кривых. Главная цель F8 — сформулировать не отдельный частный результат, а общий защищаемый вывод работы:

```text
для MNT4-753/MNT6-753 в текущей EVM нельзя получить одновременно
малую on-chain стоимость и малую off-chain/proof стоимость простым
переносом вычислений между on-chain и off-chain слоями.
```

При этом отрицательный результат не означает, что работа не дала результата. Наоборот, он является главным научно-инженерным итогом: были реализованы несколько независимых подходов, измерены их реальные стоимости и показано, где именно возникает граница применимости.

## 2. Исходная практическая задача

В Ethereum есть предкомпилированный контракт для проверки BN254-сопряжения, но нет предкомпилированной арифметики для MNT4-753 и MNT6-753. Поэтому если требуется использовать MNT-кривые, возникают два естественных пути:

1. считать арифметику и сопряжение прямо в EVM;
2. вынести вычисление off-chain и проверять on-chain короткое доказательство или подготовленные данные.

Первый путь платит gas. Второй путь платит constraints, calldata, памятью и временем доказчика. Работа исследует, можно ли выбрать архитектуру, в которой оба вида стоимости остаются малыми.

## 3. Что было реализовано

### 3.1. Арифметика MNT4-753 в EVM

Для MNT4-753 реализована 753-битная арифметика в Solidity/Yul. Элемент базового поля хранится тремя 256-битными словами:

```text
x = x0 + 2^256 x1 + 2^512 x2.
```

Реализованы и сравнены:

| Подход | Статус | Вывод |
|---|---|---|
| Montgomery/CIOS | production path | лучший найденный вариант |
| Barrett reduction | реализовано для сравнения | значительно дороже |
| FIOS | реализовано для сравнения | дороже CIOS |
| Comba/SOS | реализовано для сравнения | не выигрывает в EVM из-за переносов и memory traffic |
| branchless reduction | реализовано для сравнения | дороже или не компилируется в агрессивной форме |
| skip-dead-`t0` | реализовано для сравнения | эффект около нуля |

Ключевые измерения:

| Операция | Gas/op |
|---|---:|
| `Fq.mul`, MNT4-753, 3-limb Montgomery/CIOS | `2,959` |
| `Fq.square`, MNT4-753 | `2,947` |
| `Fq2.mul` | `11,877` |
| `Fq4.mul` | `42,764` |
| `Fq4.square` | `36,606` |

Формальная причина, почему стоимость нельзя снизить до условных `1000-1500 gas/op`: одно общее 3-limb Montgomery-умножение требует не менее 18 полных 512-битных произведений. В EVM нет инструкции `mulhi`, поэтому каждое 512-битное произведение требует связки `MUL`, `MULMOD`, `LT`, `SUB` и логики переносов. Поэтому разрыв между opcode-мечтой и фактическими `~2959 gas/op` не является полностью доступным резервом оптимизации.

Документы:

- `docs/F1_3LIMB_ARITHMETIC_FINAL_AUDIT_RU.md`;
- `docs/ARITHMETIC_ALGORITHM_STUDY_RU.md`;
- `docs/ALGORITHM_COMPLEXITY_ESTIMATES_RU.md`.

### 3.2. Наивный baseline

Для защиты важно было показать не только финальную оптимизированную стоимость, но и стартовую точку. Поэтому добавлен отдельный модуль:

```text
naive_tate_baseline/
```

Он использует generic Solidity-арифметику без Yul hot path, без sparse lines, без prepared cache и без оптимизированной финальной экспоненты. Полный наивный запуск целиком нецелесообразен, поэтому измерены микроблоки и выполнена строгая экстраполяция:

```text
Miller accumulator:
752 * 973,261 + 372 * 486,819 = 912,988,940 gas.

Generic final exponentiation:
2259 * 486,899 + 1100 * 486,819 = 1,635,405,741 gas.

Итого:
2,548,394,681 gas.
```

Это нижняя оценка на наивный полный путь, потому что она не включает построение линий, операции с twist-точками и проверки входов.

### 3.3. Оптимизационная лестница полного on-chain вычисления

Поэтапно применены:

1. Montgomery/CIOS вместо generic Solidity arithmetic;
2. Ate loop вместо полного Tate loop;
3. Karatsuba в расширениях;
4. cheap multiplication by non-residue;
5. sparse line multiplication;
6. fixed-Q режим;
7. prepared sparse line cache;
8. code-shards через `EXTCODECOPY`;
9. Frobenius/w0 decomposition для финальной экспоненты;
10. fused Miller hot path.

Итоговая интегральная таблица:

| Режим | Gas | Смысл |
|---|---:|---|
| Naive Tate baseline | `2,548,394,681` | строгая экстраполяция без оптимизаций |
| Full optimized fixed-Q on-chain | `258,753,182` | линии строятся on-chain |
| Fixed-Q prepared sparse blob | `79,588,799` | линии подготовлены заранее |
| Fixed-Q prepared sparse code-shards | `79,586,596` | кэш читается через `EXTCODECOPY` |

Главный вывод: оптимизации уменьшают стоимость более чем на порядок, но даже лучший full-onchain/prepared путь остается на уровне десятков миллионов gas.

### 3.4. Реализация идеи ePrint 2024/640 для MNT4-753

Для статьи `On Proving Pairings` реализован direct residue verifier для уравнения сопряжений:

```text
e(P,Q) * e(-R,S) = 1.
```

В этом формате можно заменить полную финальную экспоненту relation-проверкой через witness `c, c^{-1}`. Измерения:

| Режим | Gas |
|---|---:|
| Miller core без финальной экспоненты | `87,747,219` |
| Miller + обычная финальная экспонента | `115,997,313` |
| Miller + residue-проверка | `93,879,746` |

Экономия:

```text
115,997,313 - 93,879,746 = 22,117,567 gas.
```

Но общий результат остается около `94M gas`, потому что Miller loop уже стоит `87.7M gas`. Следовательно, оптимизация финальной экспоненты работает, но не решает стоимость всего verifier-а.

### 3.5. Polynomial-check направление: KZG и Merkle/FRI

Следующая идея ePrint 2024/640 — не исполнять каждое умножение в расширенном поле on-chain, а проверять вычислительную трассу через полиномиальные отношения.

Пусть в трассе есть равенства:

```text
c_i = a_i * b_i.
```

Они кодируются многочленами:

```text
a(X), b(X), c(X).
```

На домене `H` проверяется:

```text
R(X) = a(X)b(X) - c(X).
```

Если `R` зануляется на `H`, то:

```text
R(X) = Q(X) Z_H(X),
```

где `Z_H(X)` — vanishing polynomial. Verifier проверяет равенство в случайной точке `alpha`:

```text
R(alpha) = Q(alpha) Z_H(alpha).
```

Чтобы prover не подменил значения в `alpha`, нужен polynomial commitment/opening layer.

В проекте реализованы два направления:

| Направление | Реализация | Измерение | Ограничение |
|---|---|---:|---|
| KZG over BN254 | `Article640KzgBn254OpeningVerifier.sol` | `133,039 gas` на opening | MNT4 arithmetic становится non-native внутри BN254 |
| Merkle/FRI opening layer | `Article640MerkleFriOpeningVerifier.sol` | `46,402 gas` на 8 Merkle openings depth 16 | растет calldata |

Для KZG путь on-chain короткий, но constraints становятся большими:

| Операция в BN254 R1CS | Constraints |
|---|---:|
| MNT4 `Fq.mul` как non-native | `3,692` |
| MNT4 `Fq2.mul` как non-native | `11,300` |
| модель MNT4 `Fq4.mul` как non-native | `63,436` |
| приближенная sparse Miller relation | `63,309,128` |

Для Merkle/FRI путь constraints может быть ближе к нативному полю, но появляется большой calldata. Один MNT4-753 field element занимает:

```text
3 * 32 = 96 bytes.
```

Модель на `4096` открытых MNT4 field elements и Merkle paths:

```text
4096 * 96 + 128 * 16 * 32 + 16 * 32 = 459,264 bytes.
```

Даже без учета всей FRI-логики это уже большой входной объем для EVM.

### 3.6. MNT4/MNT6 cycle-native слой

Исходная мотивация работы связана не только с одной кривой MNT4-753, но и с циклом:

```text
Fr(MNT4-753) = Fq(MNT6-753),
Fr(MNT6-753) = Fq(MNT4-753).
```

Добавлен модуль:

```text
mnt_cycle_full/
```

Он проверяет параметры цикла через `arkworks`, строит reference pairings и считает operation/constraints accounting для будущего cycle-native relation layer.

| Сторона | Башня | Prepared relation |
|---|---|---:|
| MNT4 | `Fq2/Fq4` | `24,178` |
| MNT6 | `Fq3/Fq6` | `49,120` |
| BN254 non-native sparse Miller estimate | MNT4 arithmetic inside BN254 | `63,309,128` |

Этот результат важен не как готовый EVM verifier, а как объяснение будущего направления: если folding-слой строится cycle-native, то можно избежать грубой non-native эмуляции MNT4 внутри BN254.

### 3.7. Полная MNT6 on-chain/article640 реализация

Для MNT6-753 выполнена отдельная on-chain/article640 реализация:

```text
mnt6_article640_verifier/
```

Реализованы:

- `Fq/Fq3/Fq6` arithmetic;
- packed/pointer API;
- prepared Miller loop;
- packed Frobenius/w0 final exponentiation;
- article640-style residue path;
- Rust backend и cross-check against `ark-mnt6-753`.

Ключевые результаты:

| Режим | Gas |
|---|---:|
| Miller loop, packed pointer blob | `93,254,054` |
| Final exponentiation, packed Frobenius/w0 + NAF | `38,428,108` |
| Полное MNT6-сопряжение | `131,685,843` |
| Article640-style residue digest одного сопряжения | `103,277,505` |
| Fixed-shards bool residue equation с общим аккумулятором | `172,004,717` |

MNT6 корректно реализован, но не стал дешевле MNT4. Причина: башня `Fq -> Fq3 -> Fq6` дороже, а prepared line coefficients плотнее.

### 3.8. Lollipop-305 из ePrint 2024/1627

Для проверки альтернативного направления реализован исследовательский lollipop-305 прототип:

```text
lollipop305_research/
```

Главная гипотеза: меньшее поле и 2-limb арифметика могут дать выигрыш в EVM.

Арифметика действительно стала дешевле:

| Операция | lollipop-305 | MNT4-753 | Выигрыш |
|---|---:|---:|---:|
| `Fp.mul` | `1,018` | `2,959` | `2.91x` |
| `Fp.square` | `940` | `2,947` | `3.14x` |
| `Fp2.mul` | `4,171` | `11,877` | `2.85x` |
| `Fp4.mul` | `14,942` | `42,764` | `2.86x` |

Но полный lollipop-cycle оказался дорогим:

| Часть | Режим | Function gas |
|---|---|---:|
| stick | residue FE | `8,710,110` |
| `E/Fp2 -> Fp4` | residue FE | `18,359,648` |
| `Ehat/Fq2 -> Fq6` | prepared-Ate + residue | `106,441,661` |
| full lollipop-cycle | сумма лучших частей | около `133,511,419` |

Причина: для `Ehat/Fq2` embedding degree равен `k=3`. При `k=3` стандартное удаление знаменателей линий не работает, поэтому verifier должен вести два аккумулятора:

```text
F = F_num / F_den,
c^p * F_den = F_num.
```

Итог: lollipop-305 подтверждает пользу меньшей арифметики, но не дает дешевой прямой EVM-замены MNT4/MNT6.

## 4. Общая таблица результатов

| Подход | Что реализовано | Основная метрика | Вывод |
|---|---|---:|---|
| Naive Tate baseline | generic Solidity + экстраполяция | `2.55B gas` | заведомо непрактично |
| MNT4 full optimized on-chain | fixed-Q, линии строятся on-chain | `258.8M gas` | корректно, но дороже блока |
| MNT4 prepared sparse | line cache заранее | `79.6M gas` | лучше, но все еще очень дорого |
| MNT4 article640 residue | Miller + `c`-witness | `93.9M gas` | FE дешевле, Miller доминирует |
| KZG opening over BN254 | короткая on-chain opening проверка | `133k gas` | дешево on-chain, дорого по non-native constraints |
| BN254 non-native sparse Miller | R1CS модель | `63.3M constraints` | повторяет проблему Sonobe/CycleFold |
| Merkle/FRI opening layer | Merkle openings | `459KB+ calldata` в умеренной модели | перенос стоимости в calldata |
| MNT-cycle-native relation | Rust/accounting | `24k-49k relation ops` | перспективно для будущего folding |
| MNT6 article640 | fixed-shards bool residue equation | `172.0M gas` | общий аккумулятор дешевле полной FE, но `Fq3/Fq6` дороже MNT4 |
| lollipop-305 | полный research-cycle | `133.5M gas` | арифметика дешевле, pairing-структура дороже |

## 5. Экономическая интерпретация gas

Стоимость on-chain вычисления можно выразить формулой:

```text
cost_usd = gas * gas_price_gwei * 10^(-9) * ETH_price_usd.
```

Для иллюстрации ниже используется условная цена:

```text
ETH_price_usd = 3000.
```

Это не прогноз курса, а нормировка, чтобы видеть порядок величин.

| Режим | Gas | 1 gwei | 5 gwei | 20 gwei |
|---|---:|---:|---:|---:|
| Naive Tate baseline | `2,548,394,681` | `$7,645` | `$38,226` | `$152,904` |
| MNT4 full optimized on-chain | `258,753,182` | `$776` | `$3,881` | `$15,525` |
| MNT4 prepared sparse | `79,588,799` | `$239` | `$1,194` | `$4,775` |
| MNT4 article640 residue | `93,879,746` | `$282` | `$1,408` | `$5,633` |
| MNT6 article640 fixed-shards residue equation | `172,004,717` | `$516` | `$2,580` | `$10,320` |
| lollipop full research-cycle | `133,511,419` | `$401` | `$2,003` | `$8,011` |
| KZG opening verifier | `133,039` | `$0.40` | `$2.00` | `$7.98` |

Вывод по деньгам: прямое EVM-исполнение MNT-сопряжений приводит к стоимости от сотен до тысяч долларов за один вызов при умеренных gas price. Короткая KZG/opening-проверка on-chain стоит дешево, но эта дешевизна достигается только потому, что тяжелая арифметика перенесена в proving layer.

## 6. Экономическая интерпретация constraints

Constraints не являются прямой денежной единицей. Их стоимость зависит от proof system, реализации prover-а, памяти, CPU/GPU, степени параллелизма и размера witness. Тем не менее полезно задать модель:

```text
prove_cost_usd = constraints / throughput_constraints_per_second
                 * hardware_usd_per_hour / 3600.
```

Для ориентировочной оценки возьмем два сценария:

| Сценарий | Throughput | Стоимость железа |
|---|---:|---:|
| CPU-like prover | `50,000 constraints/s` | `$1/hour` |
| GPU-like prover | `1,000,000 constraints/s` | `$3/hour` |

Тогда получаются такие порядки:

| Сценарий | Constraints | CPU time/cost | GPU time/cost |
|---|---:|---:|---:|
| MNT4 cycle-native relation | `24,178` | `0.48s / <$0.001` | `0.02s / <$0.001` |
| MNT6 cycle-native relation | `49,120` | `0.98s / <$0.001` | `0.05s / <$0.001` |
| Sonobe/CycleFold-like anchor | `9,000,000` | `180s / ~$0.05` | `9s / ~$0.008` |
| BN254 non-native sparse Miller | `63,309,128` | `1266s / ~$0.35` | `63s / ~$0.05` |

Эти числа нельзя читать как точную цену генерации proof. Реальные proving systems имеют overhead на FFT/MSM, память, witness generation, serialization и setup. Но таблица показывает важный порядок: off-chain стоимость в долларах может быть ниже gas-стоимости, однако она превращается в другую проблему:

1. latency: десятки секунд или минуты на доказательство;
2. memory pressure: большие witness и proving keys;
3. infrastructure cost: prover должен быть отдельным сервисом;
4. centralization risk: не каждый пользователь сможет генерировать такие proofs локально;
5. engineering complexity: нужны надежные circuits, trusted setup или transparent PCS.

Иными словами, перенос в off-chain не уничтожает стоимость, а меняет ее природу.

## 7. Calldata как третья форма стоимости

Merkle/FRI путь показывает, что есть не только gas и constraints. Если не использовать BN254 KZG, а коммититься к таблицам через Merkle/FRI, то verifier может избежать части non-native constraints, но должен получить openings.

Для MNT4-753:

```text
1 field element = 96 bytes.
```

Даже умеренная модель:

```text
459,264 bytes
```

дает calldata gas примерно:

```text
lower bound: 459,264 * 4  = 1,837,056 gas,
upper bound: 459,264 * 16 = 7,348,224 gas.
```

Для тяжелой модели с `30,000` открытых MNT4 elements:

```text
30,000 * 96 = 2,880,000 bytes.
```

Только сами значения дают:

```text
lower bound: 11,520,000 gas,
upper bound: 46,080,000 gas.
```

Это уже сравнимо с частью on-chain arithmetic. Поэтому Merkle/FRI не является бесплатной заменой KZG: он меняет constraints на calldata.

## 8. Главный trade-off

Полученная картина:

```text
Если считаем MNT arithmetic on-chain:
    платим gas.

Если доказываем MNT arithmetic в BN254 circuit:
    платим constraints из-за non-native arithmetic.

Если используем Merkle/FRI вместо BN254 KZG:
    платим calldata и proof size.

Если уменьшаем поле через lollipop:
    дешевеет базовая арифметика, но pairing-структура может стать дороже.

Если используем MNT4/MNT6 cycle-native слой:
    появляется перспективный путь для folding, но это уже следующий proof-system layer,
    а не готовый дешевый EVM verifier.
```

Это и есть финальный граничный результат.

## 9. Фундаментальные ограничения, которые сохраняются

### 9.1. Нет native MNT arithmetic в EVM

EVM работает с 256-битными словами. MNT4-753/MNT6-753 требуют 753-битной арифметики. Поэтому каждое полевая операция распадается на limb arithmetic.

Без precompile для MNT нельзя получить стоимость уровня BN254 precompile.

### 9.2. Prepared cache не убирает Miller accumulator

Prepared line cache убирает построение линий, но не убирает обновление аккумулятора:

```text
f <- f^2 * line(P).
```

Именно этот шаг повторяется сотни раз и остается дорогим.

### 9.3. Residue-проверка оптимизирует финальную экспоненту, но не Miller loop

Для MNT4:

```text
FE contribution:       ~28.25M gas
residue contribution:  ~6.13M gas
Miller core:           ~87.75M gas
```

Поэтому после оптимизации FE главным узким местом становится Miller loop.

### 9.4. KZG over BN254 переносит проблему в non-native constraints

KZG verifier дешев on-chain, потому что Ethereum имеет BN254 precompile. Но MNT4-арифметика внутри BN254-circuit остается non-native. Это и дает десятки миллионов constraints для строгого переноса Miller relation.

### 9.5. Merkle/FRI переносит проблему в calldata

FRI/Merkle может быть привлекательнее по algebraic-native структуре, но MNT4 field elements крупные. Opening большого числа значений быстро дает сотни килобайт или мегабайты calldata.

### 9.6. Lollipop уменьшает limb count, но не гарантирует дешевый pairing

Lollipop-305 показывает `2.8x-3.3x` выигрыш на базовой арифметике. Но полная pairing-структура требует дорогой `Ehat/Fq2 -> Fq6` части, а при `k=3` нельзя использовать стандартное удаление знаменателей. Поэтому полный EVM-cycle остается дорогим.

## 10. Что удалось достичь

1. Реализована и проверена оптимизированная 753-битная arithmetic library для MNT4-753.
2. Реализованы альтернативы arithmetic algorithms и доказано, что текущий Montgomery/CIOS/Yul путь является лучшим найденным.
3. Построен naive Tate baseline и оптимизационная лестница до production-like prepared MNT4 path.
4. Реализован direct residue verifier по ePrint 2024/640 для MNT4-753.
5. Показано, что residue-подход экономит финальную экспоненту, но не устраняет стоимость Miller loop.
6. Реализованы KZG и Merkle/FRI opening layers для анализа polynomial-check направления.
7. Построена constraints-модель, показывающая рост BN254 non-native MNT4 arithmetic.
8. Реализован preliminary MNT4/MNT6 cycle-native слой с operation/constraints accounting.
9. Реализована полная исследовательская MNT6 on-chain/article640 ветка.
10. Реализован lollipop-305 research pipeline и показано, почему меньшая арифметика не гарантирует дешевый полный verifier.

## 11. Финальный вывод

Работа показывает, что исходная цель в сильной форме:

```text
получить дешевое MNT-сопряжение в EVM без MNT-precompile
и без большого proof/PCS overhead
```

в текущей модели недостижима.

Но работа также показывает, где именно проходит граница:

- MNT4/MNT6 можно корректно считать on-chain, но это дорого по gas.
- Article640 residue-подход корректно снижает стоимость финальной экспоненты, но не стоимость цикла Миллера.
- Polynomial-check/KZG снижает on-chain verifier gas, но переносит MNT arithmetic в non-native constraints.
- Merkle/FRI снижает зависимость от BN254, но увеличивает calldata.
- Lollipop-кривые уменьшают стоимость базовой арифметики, но полная pairing-структура может вернуть стоимость к сотням миллионов gas.
- MNT4/MNT6 cycle-native relation layer выглядит наиболее перспективным направлением для будущего folding, но это уже следующая архитектура, а не простой контрактный verifier.

Поэтому финальный результат работы можно формулировать так:

```text
Построена и измерена полная линейка реализаций MNT-сопряжений:
от наивного on-chain baseline до article640 verifier, PCS trade-off,
MNT4/MNT6 cycle-native accounting и lollipop-альтернатив.
Показано, что без новой системной поддержки невозможно одновременно
получить малую on-chain стоимость и малую off-chain proof стоимость.
```

## 12. Практические варианты продолжения

### 12.1. Chunked on-chain verifier

Можно разбить Miller loop на несколько транзакций:

```text
step 1: проверить часть Miller loop, сохранить accumulator;
step 2: продолжить с сохраненного accumulator;
step k: завершить последний фрагмент Miller loop;
final step: residue или финальная экспонента.
```

Это не снижает суммарный gas, но позволяет уложить каждый отдельный шаг в block gas limit. Минусы:

- storage cost;
- несколько транзакций;
- latency;
- нужно защищать continuation state;
- усложняется API.

### 12.2. MNT-cycle-native folding

Более перспективный путь — не доказывать всю MNT4-арифметику в BN254, а строить relation layer в MNT4/MNT6 cycle-native постановке. Текущий accounting показывает:

```text
MNT4 prepared relation: ~24k relation ops,
MNT6 prepared relation: ~49k relation ops,
BN254 non-native sparse Miller: ~63M constraints.
```

Это направление сохраняет исходную идею работы: использовать особенности MNT-цикла, а не просто эмулировать MNT в BN254.

### 12.3. Новые PCS или precompile

Для production-уровня возможны два системных улучшения:

1. MNT precompile или специализированная VM-инструкция для больших полей;
2. polynomial commitment/proof system, который дешево открывает MNT-sized field traces без BN254 non-native overhead и без огромного calldata.

Без одного из этих улучшений текущий trade-off сохраняется.
