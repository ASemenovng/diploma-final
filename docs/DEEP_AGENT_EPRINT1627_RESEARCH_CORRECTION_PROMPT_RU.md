# Доработка исследования ePrint 2024/1627: критика отчета и новое задание

## 1. Почему требуется доработка

Был подготовлен отчет по ePrint 2024/1627 и достижимости цели `<60M gas`. Отчет полезен как обзор направления, но в текущем виде **не может быть использован как основание для реализации production-кода**.

Главная причина: в отчете есть несколько неверных или недоказанных допущений, которые радикально занижают gas-оценки и делают выводы слишком оптимистичными.

Цель доработки — исправить эти ошибки и получить реалистичный go/no-go verdict:

- есть ли curve/protocol candidate, который реально может дать `<60M gas`;
- если да, какой именно и почему;
- если нет, почему именно это невозможно при текущих ограничениях EVM.

---

## 2. Исходная задача

Нужно найти более совершенную архитектуру для проверки pairing/equation в EVM.

Текущая MNT4-753 реализация имеет такие результаты:

| Сценарий | Gas |
|---|---:|
| Full on-chain MNT4 pairing digest | `~259.5M-259.7M` |
| Direct Miller core без финальной экспоненты | `87,747,219` |
| Miller + обычная финальная экспонента | `115,997,313` |
| Miller + residue-check вместо полной FE | `93,879,746` |

Измеренные стоимости базовой арифметики MNT4-753:

| Операция | Gas/op |
|---|---:|
| `Fp mul` | `2,959` |
| `Fp sqr` | `2,947` |
| `Fp2 mul` | `11,877` |
| `Fp2 sqr` | `10,592` |
| `Fp4 mul` | `42,764` |
| `Fp4 sqr` | `36,606` |

Известная нижняя оценка для двухпарного Miller core:

\[
376\cdot S_4
+
2\cdot376\cdot M_4
+
2\cdot123\cdot M_4
=
56\,421\,448\ \text{gas}.
\]

Реальный measured hot core:

\[
87\,747\,219\ \text{gas}.
\]

Цель исследования:

> понять, можно ли за счет ePrint 2024/1627, смены кривой, lollipop-структуры, polynomial Miller check, KZG/Merkle/FRI или других техник получить полностью рабочий production-ready вариант дешевле `60M gas`, не возвращаясь к взрыву constraints из-за BN254 non-native arithmetic.

---

## 3. Ошибки и слабые места текущего отчета

### Ошибка 1. `MUL gas = limbs^2 * 8` нельзя использовать как стоимость field multiplication

В отчете написано, что для 2-limb поля стоимость умножения примерно:

```text
2^2 * 8 = 32 gas
```

а для 3-limb поля:

```text
3^2 * 8 = 72 gas.
```

Это неверно как модель field multiplication.

`8 gas` — это стоимость одной EVM-инструкции `MUL`, но field multiplication требует:

- нескольких word multiplications;
- получения старших частей произведений;
- переносов;
- modular reduction;
- conditional subtraction;
- memory/stack operations;
- иногда `mulmod` tricks;
- упаковки/распаковки limb-ов.

Фактическое измерение проекта для 3-limb MNT4-753:

```text
Fp mul = 2,959 gas,
```

а не `72 gas`.

Следовательно, прогнозы вида:

```text
lollipop-305 Miller ~= 5.8K / 5.8M gas
```

нельзя считать надежными. Нужно построить новую модель, где стоимость 2-limb, 3-limb и 4-limb field arithmetic оценивается реалистично.

Требование к доработке:

- либо реализовать минимальные microbenchmarks для 2-limb/3-limb/4-limb Montgomery arithmetic в Solidity/Yul;
- либо вывести оценку из текущей реализации MNT4-753 с поправкой на число limb-ов, но явно учитывать reduction/memory/control overhead;
- нельзя использовать `limbs^2 * 8` как итоговую стоимость field multiplication.

---

### Ошибка 2. Проценты из ePrint 2024/640 нельзя применять универсально и мультипликативно

В отчете используются сокращения вроде:

```text
prepared lines: -30%
residue FE: -40%
polynomial check: -20%
```

и затем они перемножаются как `0.7 * 0.6 * 0.8 * 0.9`.

Это недоказанная модель.

Для MNT4-753 уже есть фактический результат:

```text
full equation = 115,997,313 gas
residue equation = 93,879,746 gas
saving = 22,117,567 gas
```

Оптимизация FE работает, но Miller core остается доминирующим:

```text
Miller core = 87,747,219 gas.
```

Требование к доработке:

- для каждого candidate curve отдельно оценить Miller loop и FE;
- не применять проценты из статьи как универсальные константы;
- если используется percentage-based estimate, явно доказать, почему он применим к данной curve/tower/API.

---

### Ошибка 3. Кандидаты lollipop-305/351 не выглядят production-secure

Отчет рекомендует lollipop-305/351, но сам же приводит security:

```text
lollipop-305: 77–88 bits
lollipop-351: 83–95 bits
```

Это не production-security для современной криптографии.

Даже lollipop-442 и lollipop-574 по таблице дают примерно:

```text
lollipop-442: 94–106 bits
lollipop-574: 108–119 bits
```

Это тоже ниже привычного 128-bit target, если такой target требуется.

Требование к доработке:

- явно разделить research prototype и production security;
- для каждого кандидата указать security level;
- если кандидат ниже 128-bit, нельзя называть его production-ready;
- если нужен 128-bit target, проверить, остается ли gas < 60M для кандидатов вроде lollipop-956 или других вариантов из статьи.

---

### Ошибка 4. Утверждение “KZG + lollipop устраняет non-native overhead” не доказано

В отчете сказано, что если KZG строится над тем же полем, что и lollipop-кривая, то non-native overhead исчезает, и что scalar field можно согласовать с существующей KZG-инфраструктурой.

Это слишком сильное и недоказанное утверждение.

KZG verifier в EVM обычно опирается на BN254 или BLS12-381 precompile. Чтобы проверка была дешевой, polynomial commitment должен жить в scalar field соответствующей pairing curve. Если witness arithmetic живет в другом поле, то снова возникает field mismatch.

Нужно строго определить:

- над каким полем строятся witness polynomials;
- над каким полем работает KZG commitment;
- в какой группе лежит commitment;
- какой precompile проверяет opening;
- как значения MNT/lollipop field elements кодируются в KZG scalar field;
- появляется ли limb decomposition/range/reduction check.

Требование к доработке:

- нельзя писать “non-native overhead исчезает”, пока не построена точная field-alignment схема;
- нужно явно проверить, существует ли у выбранной lollipop-кривой scalar/base field, совместимое с BN254/BLS12-381 KZG без non-native arithmetic;
- если совместимости нет, нужно оценить constraints overhead.

---

### Ошибка 5. Polynomial Miller check описан концептуально, но без полной проверяемой схемы

Для polynomial check недостаточно сказать, что verifier проверяет равенство в случайной точке.

Нужно определить:

- какие witness polynomials коммитятся;
- какие значения открываются;
- сколько openings требуется;
- какая degree bound;
- как строится quotient polynomial;
- как получается Fiat-Shamir challenge;
- как verifier проверяет opening;
- сколько calldata требуется;
- сколько gas стоит verifier;
- как обеспечивается soundness.

Требование к доработке:

- дать конкретную схему для KZG;
- дать конкретную схему для Merkle/FRI или честно доказать, что она не подходит;
- указать полный public input / witness / proof format.

---

### Ошибка 6. Нет точной модели loop length и line formulas для lollipop-кандидатов

Отчет использует грубые числа `k=4`, `k=6` и фиксированные множители, но не выводит:

- ate loop parameter;
- число doubling rounds;
- число add rounds;
- signed/NAF representation;
- tower representation;
- line evaluation formulas;
- sparse structure;
- FE decomposition.

Без этого невозможно оценить реальный gas.

Требование к доработке:

Для каждого серьезного кандидата нужно дать:

```text
L = number of doubling rounds
H = number of addition rounds
Target field tower
Cost(M4), Cost(S4), Cost(line_dbl), Cost(line_add)
FE decomposition
Expected direct/residue gas
```

---

## 4. Новое задание агенту

### Task 1. Перепроверить ePrint 2024/1627

Нужно заново извлечь из статьи:

- список реально предложенных lollipop-кривых;
- параметры `p`, `r`, `q`, embedding degree;
- security levels;
- cycle/lollipop structure;
- какие кривые являются supersingular;
- какие кривые pairing-friendly;
- какие поля используются для arithmetization.

Нельзя использовать только пересказ. Нужна таблица с параметрами и ссылкой на место в статье.

---

### Task 2. Отделить research candidates от production candidates

Кандидаты нужно разделить минимум на три группы:

1. Research/demo candidates: можно использовать для эксперимента, но не для production.
2. Borderline candidates: возможно приемлемы для дипломной демонстрации, но не production-safe.
3. Production candidates: соответствуют современному security target.

Для каждой группы указать:

- security bits;
- expected EVM limb count;
- expected target field cost;
- compatibility with folding / lollipop composition.

---

### Task 3. Построить реалистичную field arithmetic gas model

Нужно заменить модель:

```text
Cost(MUL) = limbs^2 * 8 gas
```

на реалистичную модель.

Варианты:

1. Предложить microbenchmark implementation plan для 2-limb/3-limb/4-limb Montgomery arithmetic.
2. Или построить оценку на основе текущей 3-limb реализации:

```text
Fp3_mul_measured = 2,959 gas
```

и вывести conservative estimates для:

```text
Fp2limb_mul
Fp3limb_mul
Fp4limb_mul
```

с учетом:

- word multiplication;
- high-word extraction;
- reduction;
- conditional subtraction;
- memory/stack overhead.

Результат должен быть таблицей:

| limb count | lower-bound gas | realistic estimate gas | optimistic estimate gas | notes |
|---:|---:|---:|---:|---|

---

### Task 4. Построить operation-level gas model для каждого кандидата

Для каждого серьезного кандидата нужно оценить:

```text
Fp mul/sqr
Fp2 mul/sqr
Fp4 or Fp6 mul/sqr
line evaluation
line multiplication
Miller core
FE direct
FE residue
full direct verifier
```

Модель должна иметь форму:

\[
G_{\mathrm{Miller}}
=
L\cdot S_T
+ N_{\mathrm{dbl}}\cdot L_{\mathrm{dbl}}
+ N_{\mathrm{add}}\cdot L_{\mathrm{add}}
+ G_{\mathrm{overhead}}.
\]

Нужно отдельно указать:

- optimistic estimate;
- realistic estimate;
- pessimistic estimate.

---

### Task 5. Перепроверить возможность `<60M gas`

Для каждого кандидата ответить:

```text
Can direct residue verifier be <60M gas?
Can polynomial Miller check verifier be <60M gas?
What is the cost moved off-chain?
What is the constraints cost?
```

Нельзя писать “достижимо” без формальной модели.

---

### Task 6. Проверить KZG, Merkle/FRI и другие PCS строго

Для KZG:

- над каким полем полиномы;
- какая группа commitment;
- какой precompile используется;
- сколько pairings/openings;
- сколько calldata;
- есть ли non-native field mismatch;
- сколько constraints требуется, если mismatch есть.

Для Merkle/FRI:

- размер trace table;
- число opened rows;
- размер одного field element;
- число hash paths;
- calldata;
- gas на hashing;
- soundness error.

Для IPA:

- есть ли MSM precompile;
- если нет, оценить impracticality.

---

### Task 7. Дать окончательный go/no-go verdict

Нужно дать один из трех вариантов:

#### Вариант A. Есть production-ready candidate

Тогда нужно указать:

- какую curve выбрать;
- какой protocol;
- API контракта;
- off-chain backend;
- proof format;
- expected gas;
- expected constraints;
- implementation plan.

#### Вариант B. Есть только research prototype candidate

Тогда нужно честно указать:

- почему не production;
- что именно можно реализовать для диплома;
- какие выводы можно защищать.

#### Вариант C. Нет подходящего candidate

Тогда нужно строго доказать:

- почему `<60M gas` недостижимо без precompile / different proof system / lower security;
- где именно bottleneck;
- какие future protocol/EVM changes нужны.

---

## 5. Минимальный формат итогового ответа

Итоговый отчет должен иметь структуру:

```text
1. Executive summary
2. Ошибки предыдущего отчета и исправления
3. Реальные параметры ePrint 2024/1627 candidates
4. Security classification
5. Corrected EVM field arithmetic gas model
6. Corrected Miller/FE gas model per candidate
7. Polynomial check + PCS analysis
8. Non-native constraints analysis
9. Recommendation: implement / do not implement
10. If implement: exact implementation plan
```

---

## 6. Важное требование

Не нужно оптимистичных “маркетинговых” оценок.

Нужен строгий технический результат:

```text
либо кандидат действительно реализуем и обоснован,
либо честно доказано, что текущая цель невозможна при заданных ограничениях.
```

В частности, нельзя использовать следующие утверждения без доказательства:

- `Fp mul for 2 limbs costs 32 gas`;
- `ePrint 2024/640 gives universal 30%/40%/20% savings`;
- `KZG automatically removes non-native overhead`;
- `lollipop-305/351 are production-ready`;
- `Miller verifier can be ~5M gas`.

Каждое такое утверждение должно быть либо строго доказано, либо удалено.

---

## 7. Дополнение: исследовательский прототип на lollipop-305/351

После исправления gas-модели и проверки параметров нужно отдельно ответить на вопрос:

> Имеет ли смысл реализовать lollipop-305 или lollipop-351 как research prototype, даже если они не являются production-secure?

Это важный отдельный сценарий. Его цель — не получить production-ready криптографическую стойкость, а проверить саму гипотезу:

```text
если перейти с MNT4-753 на меньшую lollipop-кривую,
то можно ли получить резко более дешевый verifier в EVM
и избежать главной проблемы MNT4-753: дорогой 753-битной арифметики.
```

Такой прототип имеет смысл, если он отвечает на вопрос:

```text
работает ли подход на самой простой малой кривой?
```

Если даже на lollipop-305/351 не получается получить адекватный gas, то более крупные и более безопасные lollipop-кривые почти наверняка будут еще дороже. Поэтому малый кандидат может быть полезен как sanity-check всей идеи.

### 7.1. Что нельзя утверждать про такой прототип

Если lollipop-305/351 имеют security level около 77--95 бит, то нельзя писать:

- production-ready;
- mainnet-ready;
- криптографически полноценная замена MNT4-753;
- финальное решение для промышленного verifier-а.

Правильная формулировка:

```text
research prototype / feasibility prototype / лабораторная проверка архитектуры.
```

### 7.2. Когда такой прототип имеет смысл реализовывать

Агент должен дать положительный ответ на реализацию research prototype только если выполняются условия:

1. В статье 2024/1627 действительно есть явные параметры выбранного кандидата, достаточные для реализации арифметики и pairing.
2. Можно построить башню расширений и формулы pairing/equation без недостающих математических данных.
3. Можно оценить loop length и количество line operations.
4. Можно реализовать 2-limb Montgomery/CIOS arithmetic в Solidity/Yul.
5. Можно построить Rust backend для генерации test vectors и сверки результата.
6. Можно получить корректный positive/negative test suite.
7. Ожидаемый gas хотя бы теоретически может быть ниже MNT4-753 direct residue path.

Если хотя бы один из этих пунктов не выполняется, агент должен объяснить, что именно блокирует реализацию.

### 7.3. Что именно нужно реализовать в research prototype, если он имеет смысл

Если агент считает lollipop-305 или lollipop-351 реализуемым как research prototype, он должен подготовить подробный implementation plan.

Минимальный состав прототипа:

#### 1. Rust reference backend

Должен уметь:

- задавать параметры выбранной lollipop-кривой;
- проверять точки на кривой;
- выполнять field arithmetic;
- выполнять extension arithmetic;
- строить prepared line coefficients;
- выполнять Miller loop;
- выполнять final exponentiation или residue relation;
- генерировать JSON fixtures для Solidity;
- сверять pairing/equation на нескольких тестовых точках.

#### 2. Solidity/Yul arithmetic

Должно быть реализовано:

- 2-limb base field representation;
- Montgomery/CIOS multiplication;
- specialized squaring;
- modular add/sub;
- conditional reduction;
- tower extension arithmetic;
- cheap non-residue multiplication;
- sparse line multiplication.

Нужно отдельно измерить:

| Операция | Gas/op |
|---|---:|
| `Fp mul` 2-limb |
| `Fp sqr` 2-limb |
| `Fp2 mul` |
| `Fp2 sqr` |
| target field mul |
| target field sqr |

#### 3. Direct residue verifier

Нужно реализовать вариант, максимально близкий к уже написанному MNT4-753 verifier:

```text
verifyEquation(P, R, witness, preparedLines) -> bool
```

Для fixed `Q,S` проверяется:

\[
e(P,Q)\cdot e(-R,S)=1.
\]

Режимы:

1. Miller core без FE;
2. Miller + обычная FE;
3. Miller + residue FE по ePrint 2024/640.

Это позволит напрямую сравнить с MNT4-753:

| Режим | MNT4-753 gas | lollipop prototype gas |
|---|---:|---:|
| Miller core | `87,747,219` | TBD |
| Full equation | `115,997,313` | TBD |
| Residue equation | `93,879,746` | TBD |

#### 4. Optional polynomial Miller check

Если direct residue verifier все еще дорогой, агент должен описать вторую стадию:

```text
polynomial Miller relation + KZG/Merkle openings
```

Но важно: для первого прототипа можно начать с direct residue verifier, потому что он проще и дает честную базу.

### 7.4. Какие результаты должен дать прототип

Если prototype реализуется, он должен дать:

1. Реальные gas/op для 2-limb поля.
2. Реальный gas Miller core.
3. Реальный gas обычной FE.
4. Реальный gas residue FE.
5. Сравнение с MNT4-753.
6. Понимание, масштабируется ли результат на более безопасные lollipop-кривые.

Ключевой исследовательский вывод:

```text
если lollipop-305/351 дает кратное снижение gas,
то направление перспективно и можно переходить к более безопасной кривой;
если не дает, то сама идея смены кривой не решает EVM-проблему.
```

### 7.5. Что агент должен добавить в финальный ответ

В финальном отчете после correction analysis добавить раздел:

```text
Research prototype decision: lollipop-305/351
```

В нем ответить:

1. Стоит ли реализовывать малый lollipop-прототип?
2. Какой кандидат выбрать: 305 или 351, и почему?
3. Какие параметры кривой нужны?
4. Какие файлы/модули писать?
5. Какие тесты обязательны?
6. Какие gas-метрики снять?
7. Какие выводы можно будет защищать после реализации?
8. Какие выводы нельзя будет защищать из-за низкого security level?

Если реализация рекомендована, агент должен дать пошаговый план, достаточный для начала кодирования.
