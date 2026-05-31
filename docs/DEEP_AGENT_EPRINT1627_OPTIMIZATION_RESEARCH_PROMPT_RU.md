# Задание для deep agent: исследование ePrint 2024/1627 и путей к verifier < 60M gas

## 1. Контекст работы

Исследуется задача дешевой проверки сопряжения на кривых семейства MNT / pairing-friendly циклах в EVM.

Текущая практическая цель работы:

> построить реализацию, которая проверяет корректность вычисления pairing/equation с gas строго ниже `60M`, желательно кратно ниже, либо строго доказать, что при выбранных ограничениях этого добиться нельзя.

Ограничения:

- нельзя полагаться на новые EVM precompile для MNT;
- нельзя просто “вынести все в Groth16 над BN254”, если внутри circuit нужно доказывать полную MNT4-753 арифметику в ненативном поле;
- нужно избегать решения, которое повторяет проблему Sonobe/CycleFold: рост constraints из-за non-native арифметики;
- основная новая идея должна быть связана со статьей:
  - Craig Costello, Gaurish Korpal, *Lollipops of pairing-friendly elliptic curves for composition of proof systems*, ePrint 2024/1627;
- также нужно учитывать результаты статьи:
  - *On Proving Pairings*, ePrint 2024/640;
- итог исследования должен ответить, можно ли получить практически реализуемую архитектуру лучше текущей MNT4-753.

---

## 2. Что реализовано сейчас

В проекте уже есть три класса решений.

### 2.1. Оптимизированная Solidity/Yul арифметика MNT4-753

Реализованы:

- Montgomery/CIOS арифметика для 753-битного поля;
- Barrett/FIOS/Comba/SOS как экспериментальные альтернативы;
- башня расширений:

\[
\mathbb F_p \subset \mathbb F_{p^2} \subset \mathbb F_{p^4};
\]

- Karatsuba для `Fp2/Fp4`;
- cheap non-residue multiplication;
- sparse/prepared line arithmetic;
- aggressive fused Miller hot path.

Измерения базовых операций:

| Операция | Gas/op |
|---|---:|
| `Fp mul` | `2,959` |
| `Fp sqr` | `2,947` |
| `Fp2 mul` | `11,877` |
| `Fp2 sqr` | `10,592` |
| `Fp4 mul` | `42,764` |
| `Fp4 sqr` | `36,606` |

### 2.2. Полное on-chain MNT4-сопряжение

Полное вычисление MNT4 pairing digest внутри EVM:

```text
~259.5M - 259.7M gas
```

Это корректный baseline, но практически непригоден.

### 2.3. Prepared/direct residue verifier по ePrint 2024/640

Реализована архитектура pairing equation:

\[
e(P,Q)\cdot e(-R,S)=1.
\]

Измерения:

| Режим | Gas |
|---|---:|
| Miller core без финальной экспоненты | `87,747,219` |
| Miller + обычная финальная экспонента | `115,997,313` |
| Miller + residue-проверка FE | `93,879,746` |

Вывод: оптимизация финальной экспоненты работает и экономит примерно:

\[
115\,997\,313 - 93\,879\,746 = 22\,117\,567\ \text{gas}.
\]

Но итоговая стоимость все равно выше `60M`, потому что сам цикл Миллера стоит:

\[
87\,747\,219\ \text{gas}.
\]

---

## 3. Почему текущие направления недостаточны

### 3.1. Direct on-chain Miller loop

Даже с prepared sparse lines контракт все равно исполняет сотни операций в `Fp4`.

Грубая нижняя оценка для двухпарного Miller core:

\[
376\cdot S_4
+
2\cdot 376\cdot M_4
+
2\cdot 123\cdot M_4.
\]

Подстановка измерений:

\[
376\cdot 36\,606
+
2\cdot376\cdot42\,764
+
2\cdot123\cdot42\,764
=
56\,421\,448\ \text{gas}.
\]

Это только нижняя оценка. Реальный hot core:

\[
87\,747\,219\ \text{gas}.
\]

Значит для цели `<60M` недостаточно локально оптимизировать Yul. Нужно менять математический или протокольный уровень проверки цикла Миллера.

### 3.2. BN254 non-native proof

Если доказывать полную MNT4-753 арифметику в BN254 circuit, возникает взрыв constraints.

Причина:

\[
753 > 254,
\]

поэтому один элемент MNT4-поля нужно представлять несколькими limb-ами в BN254-поле. Для каждого умножения нужно проверять:

- частичные произведения;
- переносы;
- диапазоны limb-ов;
- редукцию по модулю `p`;
- корректность остатка.

Измеренные ориентиры проекта:

| Операция в BN254 circuit | Constraints |
|---|---:|
| MNT4 `Fp mul` | `7,032` |
| MNT4 `Fp2 mul` | `44,404` |

Даже минимальная оценка полного replay:

\[
13\,536\cdot 7\,032
=
95\,185\,152
\]

constraints.

Это неприемлемо для цели “дешевого folding”.

---

## 4. Основной вопрос исследования

Нужно изучить, может ли идея из ePrint 2024/1627 дать **другой выбор кривых или протокольной архитектуры**, при котором:

1. pairing-friendly структура сохраняется;
2. можно строить future folding / recursive composition;
3. начальная арифметика выполняется над полем меньшего или более удобного размера;
4. on-chain проверка не требует сотен миллионов gas;
5. proof/circuit не возвращается к BN254 non-native replay с десятками миллионов constraints.

---

## 5. Что конкретно нужно исследовать

### Task A. Изучить ePrint 2024/1627

Нужно подробно разобрать:

1. Что такое lollipop of pairing-friendly elliptic curves.
2. Чем lollipop отличается от обычного цикла MNT4/MNT6.
3. Как цепочка перед циклом позволяет арифметизировать начальную часть над полями оптимального размера.
4. Какие именно кривые/параметры предлагают авторы.
5. Какие embedding degrees, base field sizes, scalar field sizes и security levels получаются.
6. Можно ли из этих параметров выбрать кривую, более удобную для EVM, чем MNT4-753.

Особенно важно проверить:

\[
\text{base field size},\quad
\text{scalar field size},\quad
k,\quad
\rho,\quad
\text{security level}.
\]

---

### Task B. Сравнить MNT4-753 с альтернативами из 2024/1627

Нужно построить таблицу:

| Кривая/семейство | Base field bits | Target field | Embedding degree | Security | Ожидаемый gas для базовой арифметики | Применимость к folding |
|---|---:|---|---:|---:|---:|---|

Для каждой альтернативы ответить:

1. Сколько limb-ов нужно в EVM?
2. Сколько стоит базовое умножение относительно текущего `Fp mul = 2,959 gas`?
3. Какой target field нужен для pairing?
4. Будет ли target field дешевле, чем `Fp4` MNT4-753?
5. Есть ли known efficient final exponentiation?
6. Есть ли practical curve parameters, а не только существование по теореме?

---

### Task C. Проверить возможность `<60M gas`

Нужно построить прогноз gas для альтернативной кривой.

Модель должна быть не “на глаз”, а формальная:

\[
G_{\mathrm{Miller}}
\approx
L\cdot S_T
+
N_{\mathrm{dbl}}\cdot L_{\mathrm{dbl}}
+
N_{\mathrm{add}}\cdot L_{\mathrm{add}},
\]

где:

- `T` — целевое поле новой кривой;
- `S_T` — стоимость возведения accumulator в квадрат;
- `L_dbl`, `L_add` — стоимость применения line-функции;
- `L` — число раундов loop;
- `N_dbl`, `N_add` — число применений линий.

Нужно сравнить с текущими MNT4-753 числами:

```text
Fp mul = 2,959 gas
Fp4 mul = 42,764 gas
Fp4 sqr = 36,606 gas
Miller core = 87,747,219 gas
Residue verifier = 93,879,746 gas
Full on-chain = ~259.7M gas
```

Критерий:

```text
если прогнозный Miller/residue verifier < 60M gas,
то кандидат потенциально интересен;
если нет, нужно объяснить почему.
```

---

### Task D. Проверить constraints-риски

Для каждого предложенного варианта нужно ответить:

1. Где будет строиться circuit?
2. В каком поле?
3. Какие операции станут native?
4. Какие операции останутся non-native?
5. Не возникнет ли та же проблема, что в BN254 proof для MNT4-753?

Нужно явно показать:

\[
\text{field mismatch}
\Rightarrow
\text{limb decomposition}
\Rightarrow
\text{carry/range/reduction checks}
\Rightarrow
\text{constraints growth}.
\]

Если предлагается lollipop/cycle-архитектура, нужно объяснить:

- какая часть вычислений живет в “оптимальном” поле;
- где начинается cycle;
- где будет terminal proof для EVM;
- что именно проверяет EVM-контракт.

---

### Task E. Проверить идеи параллелизма

Руководитель отдельно упомянул “параллельные операции на эллиптических кривых”.

Нужно исследовать:

1. Можно ли в EVM получить gas-выигрыш от параллелизма?
2. Или параллелизм полезен только off-chain/prover-side?
3. Можно ли использовать shared accumulator/multi-Miller лучше текущего варианта?
4. Можно ли перестроить pairing equation так, чтобы уменьшить число expensive target-field operations?

Важно: в EVM нет настоящего параллельного исполнения внутри одного вызова. Поэтому если “параллелизм” не снижает число операций, а только распараллеливает их в обычном CPU-смысле, он не снижает gas. Нужно это явно проверить.

---

### Task F. Развить идеи ePrint 2024/640

Нужно проверить, можно ли объединить 2024/640 и 2024/1627:

1. Взять более подходящую curve/lollipop-структуру из 2024/1627.
2. Для pairing verification использовать:
   - prepared lines;
   - residue/relation final exponentiation;
   - polynomial check для Miller loop.
3. Оценить KZG/Merkle-FRI/opening overhead уже для новой кривой.

Вопрос:

> Если поле новой кривой меньше или лучше согласовано с proof system, исчезает ли проблема KZG non-native overhead?

Если да, нужно показать формально.

Если нет, нужно объяснить, почему.

---

## 6. Какие решения агент должен рассмотреть

### Вариант 1. Остаться на MNT4-753 и доказать невозможность `<60M`

Агент должен проверить, можно ли строго показать:

\[
G_{\mathrm{Miller}} > 60M
\]

для любого direct on-chain verifier, который исполняет Miller loop в EVM без precompile.

Если да, нужно сформулировать lower-bound argument.

---

### Вариант 2. MNT4-753 + polynomial check

Проверить:

- KZG over BN254;
- Merkle/FRI;
- другой polynomial commitment;
- возможность batched quotient check.

Нужно определить, можно ли получить:

```text
on-chain gas < 60M
```

без того, чтобы off-chain/circuit constraints стали неприемлемыми.

---

### Вариант 3. Кривые/lollipop из 2024/1627

Проверить, можно ли заменить MNT4-753 на другую pairing-friendly/lollipop структуру так, чтобы:

- базовое поле было меньше;
- целевое поле было дешевле;
- сохранялась применимость к будущей рекурсии/folding;
- on-chain verifier был реализуем без новых precompile;
- constraints не взрывались.

---

### Вариант 4. Гибрид

Например:

```text
smaller/lollipop pairing curve
+ residue final exponentiation
+ polynomial Miller check
+ EVM-friendly commitment/opening
```

Нужно оценить, является ли это реальным путем к `<60M gas`.

---

## 7. DoD исследования

Исследование считается готовым, если агент предоставит:

1. Краткий, но точный разбор ePrint 2024/1627.
2. Таблицу параметров всех релевантных кривых/семейств из статьи.
3. Сравнение с MNT4-753 по:
   - field size;
   - embedding degree;
   - target field size;
   - Miller loop length;
   - final exponentiation complexity;
   - ожидаемой EVM gas cost.
4. Строгий ответ: есть ли кандидат, который может дать `<60M gas`.
5. Если кандидат есть:
   - описать протокол;
   - описать API контракта;
   - описать off-chain backend;
   - дать формулы проверки;
   - дать ожидаемую gas-модель;
   - дать constraints-модель.
6. Если кандидата нет:
   - доказать, почему;
   - отдельно показать, что проблема не только в текущем коде, а в размере поля/target field/Miller loop;
   - указать, какие изменения модели потребовались бы: precompile, другая curve family, другой commitment scheme, native recursion и т.д.
7. Отдельно проверить, не возникает ли в предложенном решении тот же non-native constraints explosion, что в BN254 proof для MNT4-753.
8. Предложить конкретный следующий implementation plan:
   - какие контракты писать;
   - какие Rust-компоненты писать;
   - какие тесты;
   - какие gas/constraints/ms метрики снять.

---

## 8. Формат итогового ответа агента

Агент должен выдать отчет со структурой:

```text
1. Executive summary
2. Что дает статья 2024/1627
3. Почему текущая MNT4-753 реализация не проходит <60M
4. Candidate curve/lollipop options
5. Gas model for each option
6. Constraints model for each option
7. Does it avoid BN254 non-native explosion?
8. Recommended architecture
9. If impossible: formal impossibility/lower-bound argument
10. Implementation plan
```

---

## 9. Предварительный вывод

Не следует начинать реализацию до этого исследования.

Причина: текущие локальные оптимизации уже почти исчерпаны. Мы видим:

```text
direct residue verifier = 93.9M gas
Miller core alone = 87.7M gas
target = <60M gas
```

Значит нужно не “еще немного оптимизировать Yul”, а менять один из фундаментальных факторов:

1. размер поля;
2. форму проверяемого pairing statement;
3. способ проверки Miller loop;
4. семейство кривых;
5. proof/commitment architecture.

Статья 2024/1627 как раз потенциально относится к пунктам 1 и 4. Поэтому deep-agent должен сначала ответить: **есть ли там практический кандидат для EVM**, или статья важна только как перспектива для future folding/proof-system design, но не дает immediate Solidity verifier дешевле `60M gas`.
