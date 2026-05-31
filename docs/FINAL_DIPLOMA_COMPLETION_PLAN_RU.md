# Финальный план завершения дипломной работы

> Документ фиксирует, что уже сделано в проекте, что остается реализовать и в каком порядке нужно довести работу до защищаемого финального состояния. Основная цель: получить всестороннее исследование вычисления MNT-сопряжений в EVM и proof-архитектурах, показать границы применимости текущих подходов и аккуратно оформить результаты в дипломе и презентации.

## 1. Финальная цель работы

Работа должна показать не один отдельный контракт, а полную исследовательскую линию:

1. как реализуется длинная арифметика для pairing-friendly кривых в EVM;
2. насколько дорогим оказывается прямое on-chain вычисление сопряжения;
3. какие оптимизации реально снижают стоимость;
4. почему подходы из ePrint 2024/640 помогают, но не устраняют стоимость цикла Миллера для MNT4-753;
5. где возникает trade-off между gas, calldata и constraints;
6. можно ли улучшить ситуацию за счет альтернативных циклов кривых из ePrint 2024/1627;
7. какие варианты можно считать корректными production-кандидатами, а какие являются исследовательскими прототипами;
8. какие дальнейшие шаги нужны для дешевого folding на циклических кривых.

Финальный результат должен быть защищаемым перед руководителем: для каждого важного утверждения должны быть код, тест, измерение gas/constraints/time или строгая причина, почему реализация невозможна/нецелесообразна.

## 2. Текущее состояние по 10 пунктам пользователя

| Пункт | Статус сейчас | Что уже есть | Что нужно доделать |
|---|---|---|---|
| 1. Проверка оптимальности 3-limb и 2-limb арифметики | Закрыто | `docs/F1_3LIMB_ARITHMETIC_FINAL_AUDIT_RU.md`, `docs/F2_2LIMB_ARITHMETIC_FINAL_AUDIT_RU.md`, `docs/ARITHMETIC_ALGORITHM_STUDY_RU.md`, варианты CIOS/FIOS/Barrett/Comba/branchless/stack, gas-тесты | Для F8 только перенести итоговые числа и вывод о нижней границе в финальный отрицательный результат |
| 2. Наивное Tate pairing как ориентир | Закрыто | `naive_tate_baseline/`, `naive_tate_baseline/docs/F3_NAIVE_TATE_BASELINE_RU.md`, экстраполяция полного naive пути около `2.55B gas` | Перенести как начальную строку оптимизационной лестницы в текст диплома |
| 3. Поэтапное добавление оптимизаций полного on-chain вычисления | Закрыто | `docs/MNT4_ONCHAIN_OPTIMIZATION_LADDER_RU.md`, `onchain_full/test/MNT4OptimizationLadder.t.sol`, fixed-Q, prepared sparse, code-shards, Frobenius/w0, fused hot path | Использовать таблицу ladder в F8/F9 |
| 4. ePrint 2024/640: residue FE и polynomial check | Закрыто для MNT4 | `article640_mnt4_verifier`, direct residue verifier, code-shards, `ARTICLE640_POLYNOMIAL_CHECK_TRADEOFF_RU.md`, KZG/Merkle-FRI verifier/оценки | В F8 собрать общий вывод: residue снижает FE, но Miller loop остается дорогим; PCS переносит стоимость в constraints/calldata |
| 5. Два оптимальных направления сравнения: gas-heavy и PCS/constraints-heavy | Закрыто как исследовательское сравнение | MNT4 gas-heavy реализован; polynomial-check + KZG/Merkle-FRI trade-off оформлен; BN254 Groth16 full proof не включается в финальный обязательный контур | В F8 явно отделить реализованный gas-heavy путь от PCS-heavy анализа |
| 6. Идея lollipop из ePrint 2024/1627 | Закрыто как исследовательский прототип | `lollipop305_research`, L0--L11 docs, 2-limb arithmetic, `E/Fp2`, `Ehat/Fq2`, corrected `Ehat` prepared-Ate/residue, gas-тесты | В F8 зафиксировать отрицательно-положительный вывод: 2-limb арифметика дешевле, но полный lollipop-cycle в EVM не дешевле MNT4/MNT6 |
| 7. Полный lollipop прототип и финальные gas/constraints | Закрыто как full-cycle research prototype | Реализованы stick + `E_cycle` + `Ehat`; лучший полный lollipop-cycle около `133.5M gas`; `43/43` Foundry-теста проходят | Не выдавать как production-ready; указать, что line-cache proof layer остается отдельной задачей, если требуется arbitrary-cache soundness |
| 8. Доказать невозможность дешевого production решения сейчас и предложить обходы | Частично готово | Есть выводы по MNT4, KZG, Merkle/FRI, lollipop security | Нужно оформить отдельную финальную главу/раздел: почему без MNT-precompile или нового PCS нельзя получить одновременно мало gas и мало constraints; добавить chunked-onchain идею |
| 9. Исправить презентацию и текст выступления | Частично готово | Есть обновленная презентация и краткий отчет | Нужно обновить после финальных измерений по naive/ladder/lollipop и убрать противоречивые старые тезисы |
| 10. Доработать диплом | Частично готово | Есть основной текст и планы | Нужно внести финальные результаты, таблицы, выводы и синхронизировать с презентацией |

## 3. План работ по этапам

### Этап F1. Финальный аудит 3-limb арифметики MNT4-753

**Цель:** понять, является ли текущая стоимость `Fp.mul` около 3000 gas близкой к нижней границе или в реализации есть устранимые потери.

**Файлы:**

- `onchain_full/src/BigIntMNT.sol`
- `onchain_full/src/BigIntMNTComba.sol`
- `onchain_full/src/BigIntMNTFIOS.sol`
- `onchain_full/src/BigIntMNTBarrett.sol`
- `onchain_full/src/BigIntMNTBranchless.sol`
- `onchain_full/test/BigIntMNTFinal.t.sol`
- `onchain_full/test/BigIntMNTReductionVariants.t.sol`
- `onchain_full/test/MNT4ArithmeticAlgorithmStudy.t.sol`
- `docs/ARITHMETIC_ALGORITHM_STUDY_RU.md`
- `docs/ALGORITHM_COMPLEXITY_ESTIMATES_RU.md`

**Что проверить:**

1. Сколько gas уходит на саму арифметику, а сколько на ABI, memory allocation, wrapper-функции и loop overhead benchmark-а.
2. Можно ли реализовать all-stack `montMul3` без промежуточных массивов и лишней memory-записи.
3. Можно ли сделать специализированный `montSqr3` для 3-limb вместо полного `montMul3(a,a)`.
4. Можно ли безопасно использовать lazy internal representation в hot path без полной редукции после каждого шага.
5. Может ли branchless conditional reduction быть дешевле при полностью ручной Yul-реализации, а не через дополнительный helper.
6. Можно ли использовать fixed modulus constants и unrolled carries агрессивнее, чем сейчас.

**Практические задачи:**

- Добавить `BigIntMNTUltra.sol` или аналогичный экспериментальный файл, где будет один максимально ручной all-stack вариант `montMul3Ultra` и `montSqr3Ultra`.
- Добавить gas-тест рядом с существующими вариантами.
- Если вариант не улучшает gas, оставить его как отрицательное сравнение.
- Если улучшает gas, перенести лучший вариант в production path или явно объяснить, почему переносить нельзя.

**Команды проверки:**

```bash
cd /Users/a.i.semenov/mnt4-pairing-final/onchain_full
forge test --match-path test/BigIntMNTFinal.t.sol -vv --gas-report
forge test --match-path test/BigIntMNTReductionVariants.t.sol -vv --gas-report
forge test --match-path test/MNT4ArithmeticAlgorithmStudy.t.sol -vv --gas-report
```

**Критерий готовности:**

- Есть таблица всех 3-limb вариантов: Montgomery/CIOS, Barrett, FIOS, Comba/SOS, branchless, ultra/all-stack.
- Для каждого варианта есть correctness tests и gas/op.
- Если `Fp.mul` нельзя снизить до 1000--1500 gas, в документе есть opcode/lower-bound объяснение, почему эта оценка недостижима в текущей EVM-модели.

### Этап F2. Финальный аудит 2-limb арифметики lollipop-305

**Цель:** применить тот же уровень оптимизации к 2-limb арифметике, чтобы сравнение MNT4-753 и lollipop-305 было честным.

**Файлы:**

- `lollipop305_research/src/BigIntLollipop305.sol`
- `lollipop305_research/src/BigIntLollipop305Variants.sol`
- `lollipop305_research/src/Lollipop305Extension.sol`
- `lollipop305_research/src/Lollipop305ExtensionStack.sol`
- `lollipop305_research/test/Lollipop305Arithmetic.t.sol`
- `lollipop305_research/docs/L0_ARITHMETIC_BENCHMARK_RU.md`

**Что проверить:**

1. All-stack 2-limb Montgomery multiplication.
2. Specialized square.
3. Stack-only `Fp2/Fp4` API без nested memory structs.
4. Cheap non-residue multiplication.
5. Возможность fused `Fp4.sqr * line` для будущего Miller path.

**Команды проверки:**

```bash
cd /Users/a.i.semenov/mnt4-pairing-final/lollipop305_research/rust_reference
cargo test

cd /Users/a.i.semenov/mnt4-pairing-final/lollipop305_research
forge test --match-path test/Lollipop305Arithmetic.t.sol -vv --gas-report
```

**Критерий готовности:**

- Есть таблица 2-limb вариантов с gas/op.
- Для 2-limb и 3-limb используется одинаковая методология измерений.
- В выводе указано, является ли выигрыш lollipop-305 устойчивым после всех оптимизаций.

### Этап F3. Наивный baseline для Tate pairing

**Цель:** показать исходную стоимость без основных оптимизаций, чтобы дальнейшие улучшения выглядели не как набор отдельных цифр, а как последовательная оптимизационная лестница.

**Файлы:**

- Новый модуль: `onchain_full/src/MNT4TatePairingNaive.sol`
- Новый тест: `onchain_full/test/MNT4TatePairingNaive.t.sol`
- Обновление: `docs/ALGORITHM_COMPLEXITY_ESTIMATES_RU.md`

**Режимы для baseline:**

1. Naive Miller с generic line representation.
2. Naive final exponentiation через generic exponentiation chain.
3. Без fixed-Q prepared cache.
4. Без sparse line multiplication.
5. По возможности без ate-shortening: если полный Tate loop практически невозможен по времени теста, дать частичный benchmark и формальную экстраполяцию.

**Команды проверки:**

```bash
cd /Users/a.i.semenov/mnt4-pairing-final/onchain_full
forge test --match-path test/MNT4TatePairingNaive.t.sol -vv --gas-report
```

**Критерий готовности:**

- Есть измеренный или строго экстраполированный naive baseline.
- Пояснено, почему полный naive Tate может быть невозможно прогнать полностью в Foundry без огромного времени/газа.
- Есть сравнение с текущим optimized ate/fixed-Q path.

### Этап F4. Оптимизационная лестница полного on-chain вычисления

**Цель:** поэтапно показать вклад каждой оптимизации в снижение gas.

**Файлы:**

- `onchain_full/src/MNT4TatePairing.sol`
- `onchain_full/test/MNT4TatePairingV4.t.sol`
- Новый тест: `onchain_full/test/MNT4OptimizationLadder.t.sol`
- Новый документ: `docs/MNT4_ONCHAIN_OPTIMIZATION_LADDER_RU.md`

**Строки таблицы:**

1. Naive Tate baseline.
2. Montgomery/CIOS arithmetic.
3. Ate loop вместо полного Tate loop.
4. Karatsuba extension arithmetic.
5. Cheap non-residue multiplication.
6. Sparse line multiplication.
7. Fixed-Q on-chain line generation.
8. Fixed-Q prepared sparse blob.
9. Fixed-Q prepared sparse code-shards.
10. Frobenius/w0 final exponentiation.
11. Aggressive fused Miller hot path.

**Команды проверки:**

```bash
cd /Users/a.i.semenov/mnt4-pairing-final/onchain_full
forge test --match-path test/MNT4OptimizationLadder.t.sol -vv --gas-report
forge test --match-path test/MNT4TatePairingV4.t.sol -vv --gas-report
```

**Критерий готовности:**

- Есть единая таблица `режим -> что добавлено -> gas -> delta`.
- Все строки либо измерены, либо помечены как formal extrapolation с формулой.
- Финальный optimized full-onchain result согласован с текущими gas-report.

### Этап F5. Финализация ePrint 2024/640 для MNT4-753

**Цель:** завершить блок direct residue verifier и polynomial-check анализа как центральный исследовательский результат по статье.

**Файлы:**

- `article640_mnt4_verifier/src/MNT4Article640DirectHotVerifier.sol`
- `article640_mnt4_verifier/src/MNT4TatePairing.sol`
- `article640_mnt4_verifier/test/MNT4Article640PairingModesGas.t.sol`
- `article640_mnt4_verifier/docs/ARTICLE640_PAIRING_GAS_COMPARISON_RU.md`
- `article640_mnt4_verifier/docs/ARTICLE640_DIRECT_RESIDUE_REPORT_RU.tex`
- Новый документ: `article640_mnt4_verifier/docs/ARTICLE640_POLYNOMIAL_CHECK_TRADEOFF_RU.md`

**Что уже готово:**

- Direct full equation: около `115.99M gas`.
- Direct residue equation: около `93.88M gas`.
- Code-shards residue equation: около `93.69M gas`.
- Объяснен `c`-witness и отличие `phi(f)=Y` от `phi(F)=1`.

**Что доделать / что реализуется в F5:**

1. Финально перепроверить gas для blob, calldata и code-shards вариантов.
2. Уточнить, где line-cache передается calldata, где читается через `EXTCODECOPY`, где готовится off-chain.
3. Формализовать polynomial relation check из статьи: witness polynomials, separation challenge `beta`, quotient polynomial `Q(X)`, evaluation challenge `alpha`.
4. Реализовать две PCS/opening ветки в коде, а не только как текстовую оценку:
   - KZG over BN254: реальный on-chain opening verifier через BN254 precompiles и constraints-замер non-native MNT4 arithmetic in BN254 R1CS;
   - Merkle/FRI opening layer: реальная проверка Merkle authentication paths и calldata-модель для MNT4-753 openings.
5. Зафиксировать, почему для MNT4-753 оба пути не дают одновременно мало gas и мало constraints без дополнительной системной поддержки.

**Команды проверки:**

```bash
cd /Users/a.i.semenov/mnt4-pairing-final/article640_mnt4_verifier
forge test -vv --gas-report | tee article640_full_test_gas_report.log
```

**Критерий готовности:**

- Direct residue path покрыт тестами.
- Polynomial-check path покрыт формальной моделью, реальными PCS/opening verifier-ами и измерениями.
- KZG ветка имеет Solidity verifier и Rust constraints measurement для BN254 non-native MNT4 arithmetic.
- Merkle/FRI ветка имеет Solidity Merkle-opening verifier и calldata measurement/model.
- В дипломе можно честно сказать: статья дает верное направление, но для MNT4-753 узкое место переносится в PCS/opening layer.

### Этап F6. MNT4/MNT6 cycle-native roadmap и PCS/constraints-heavy аргумент

**Цель:** не доводить BN254 Groth16 proof до финального production-контура, а показать рост constraints через тот механизм, который прямо связан с ePrint 2024/640: замена проверки цикла Миллера на polynomial relation check и проверка opening через KZG.

**Файлы:**

- `article640_mnt4_verifier/docs/ARTICLE640_POLYNOMIAL_CHECK_TRADEOFF_RU.md`
- `offchain_verify/docs/MNT_CYCLE_NATIVE_RELATION_EXPLAINED_RU.md`
- Новый документ: `docs/MNT_CYCLE_NATIVE_FOLDING_ROADMAP_RU.md`

**Что нужно сделать:**

1. Зафиксировать polynomial-check постановку из ePrint 2024/640:
   - witness-многочлены для операций в расширенном поле;
   - separation challenge `beta`;
   - единый quotient polynomial `Q(X)`;
   - evaluation challenge `alpha`;
   - openings в точке `alpha`.
2. Показать KZG over BN254 путь:
   - on-chain verifier короткий;
   - но MNT4-753 field elements становятся non-native внутри BN254-circuit;
   - поэтому constraints растут аналогично проблеме Sonobe/CycleFold.
3. Показать Merkle/FRI путь:
   - можно ближе остаться к нативному полю;
   - но proof/openings дают большой calldata из-за 753-битных элементов и Merkle paths.
4. Зафиксировать математическую идею MNT4/MNT6 цикла:
   - поле скаляров одной кривой совпадает с базовым полем другой;
   - это потенциально снижает non-native overhead внутри recursive/folding схемы.
5. Отделить текущую работу от будущего folding:
   - текущая работа реализует арифметику, on-chain baselines, article640 verifier и анализ PCS trade-off;
   - полный CycleFold-like слой не реализуется в этом дипломе.

**Критерий готовности:**

- Есть численная оценка constraints для KZG/opening path.
- Есть оценка calldata/gas для Merkle/FRI path.
- Руководитель видит, что рост constraints показан через релевантную статье ePrint 2024/640 конструкцию, а не через отдельный Groth16-проект.
- Четко сказано, что MNT4/MNT6 cycle-native folding остается дальнейшим направлением, а не готовым production-контрактом.


### Этап F6B. Предварительный MNT4/MNT6 cycle-native слой

**Цель:** не ограничиваться roadmap-описанием MNT4/MNT6 цикла, а получить отдельный воспроизводимый research/prototype-контур, который показывает, как именно MNT4 и MNT6 используются как цикл кривых для будущего folding. Этот этап не означает готовый EVM production-verifier и не реализует полный CycleFold; он должен дать предварительный кодовый и тестовый слой для cycle-native арифметики, reference pairing и relation/constraints accounting.

**Почему этап нужен:** исходная цель работы связана не только с MNT4-753 как одиночной кривой, а с идеей дешевого folding на циклических кривых. Поэтому в финальном плане должна быть явно зафиксирована реализация обоих направлений цикла:

```text
Fr(MNT4-753) = Fq(MNT6-753),
Fr(MNT6-753) = Fq(MNT4-753).
```

Именно это свойство позволяет в будущем выражать часть арифметики одной кривой в поле другой без того же non-native overhead, который возникает при переносе MNT4-арифметики в BN254.

**Файлы/директории:**

- Новый модуль: `mnt_cycle_full/`
- Rust reference: `mnt_cycle_full/rust/*`
- Constraint/relation prototype: `mnt_cycle_full/constraints/*`
- Документ: `docs/MNT4_MNT6_CYCLE_FULL_IMPLEMENTATION_RU.md`
- Тесты/бенчмарки: `mnt_cycle_full/tests/*`

**Что нужно реализовать:**

1. **Параметры цикла:**
   - зафиксировать параметры MNT4-753 и MNT6-753 из `arkworks`;
   - программно проверить равенства полей `Fr(MNT4)=Fq(MNT6)` и `Fr(MNT6)=Fq(MNT4)`;
   - зафиксировать группы, генераторы, embedding degree и pairing-friendly параметры.
2. **Rust reference для обеих сторон:**
   - MNT4 pairing reference через `ark-mnt4-753`;
   - MNT6 pairing reference через `ark-mnt6-753`;
   - cross-check test vectors для полей, точек, Miller output и final exponentiation.
3. **Cycle-native relation layer:**
   - показать, как MNT4-арифметика выражается в поле MNT6;
   - показать, как MNT6-арифметика выражается в поле MNT4;
   - реализовать минимальные relation fragments: `Fp`, `Fp2/Fp3/Fp6` по необходимости, sparse line multiplication, один Miller transition, FE/residue fragment.
4. **Сравнение с BN254 non-native переносом:**
   - посчитать constraints/operations для MNT-cycle-native fragments;
   - сравнить с BN254-style non-native representation;
   - явно показать, где именно возникает потенциальный выигрыш для будущего folding.
5. **Граница применимости:**
   - честно указать, что без полного folding layer и без EVM-precompile для MNT этот этап не дает дешевый production on-chain verifier сам по себе;
   - объяснить, что это именно предварительный слой для следующей работы: folding/recursive proof поверх MNT4/MNT6 cycle.

**Команды проверки:**

```bash
cd /Users/a.i.semenov/mnt4-pairing-final/mnt_cycle_full
cargo test --release
# если будет отдельный constraints-бенчмарк:
cargo run --release --bin mnt_cycle_constraints_bench
```

**Критерий готовности:**

- Есть код, а не только текстовый roadmap, для обеих сторон MNT4/MNT6 цикла.
- Проверены равенства полей, параметры групп и reference pairing outputs через `arkworks`.
- Есть измерение constraints/operation counts для cycle-native relation fragments.
- Есть сравнение с BN254 non-native переносом и пояснение, почему MNT4/MNT6 цикл является осмысленным направлением для дешевого folding.
- В дипломе можно честно сказать: полный folding еще не реализован, но предварительный MNT4/MNT6 cycle-native слой реализован и измерен.


### Этап F6C. Полная MNT6 on-chain/article640 verifier реализация

**Цель:** выполнить для MNT6-753 такую же практическую работу, какая уже выполнена для MNT4-753: on-chain арифметика, prepared sparse line cache, Miller loop, final exponentiation baseline, article640-style residue verifier, Rust fixtures, cross-check against arkworks и gas report.

**Файлы/директории:**

- Новый модуль: `mnt6_article640_verifier/`
- Design/DoD: `docs/F6C_MNT6_FULL_VERIFIER_DESIGN_RU.md`
- Итоговый статус: `mnt6_article640_verifier/docs/F6C_MNT6_IMPLEMENTATION_STATUS_RU.md`
- Аудит оптимизаций: `mnt6_article640_verifier/docs/MNT6_OPTIMIZATION_AUDIT_RU.md`

**Актуальный статус:** выполнено.

**Что дополнительно добавлено после исходного плана:**

1. Зафиксирована теоретическая часть MNT6-ветки: поле `Fq(MNT6-753)=Fr(MNT4-753)`, башня `Fq -> Fq3 -> Fq6`, отличие от MNT4-башни `Fq -> Fq2 -> Fq4`.
2. Реализован и измерен packed/pointer слой для `Fq3/Fq6`, чтобы MNT6 сравнивался с MNT4 не в заведомо проигрышной struct-архитектуре.
3. Реализованы prepared line cache, полный Miller loop, packed Frobenius/w0 final exponentiation и article640-style residue path.
4. Проведен перенос и проверка ключевых оптимизаций MNT4 -> MNT6: scratch arena, fused hot path `f <- f^2 * line(P)`, pointer-swap, packed NAF-возведение в `w0`-части.
5. Получен отрицательно-положительный вывод: MNT6 корректно реализован, но из-за `Fq3/Fq6` и плотных line coefficients остается дороже MNT4.

**Ключевые gas-результаты MNT6:**

| Режим | Gas |
|---|---:|
| Miller loop, packed pointer blob | `93,254,054` |
| Final exponentiation, packed Frobenius/w0 + NAF | `38,428,108` |
| Полное MNT6-сопряжение: Miller + packed FE | `131,685,843` |
| Article640-style residue path | `103,294,551` |

**Критерий готовности:**

- Реализована MNT6-753 арифметика `Fq/Fq3/Fq6` в Solidity/Yul.
- Реализован MNT6 prepared sparse Miller path.
- Реализован MNT6 article640 residue verifier.
- Есть Rust backend для генерации fixtures и cross-check против `ark-mnt6-753`.
- Есть gas report и итоговая таблица по режимам MNT6.

### Этап F7. Завершение lollipop-305 направления

**Цель:** проверить идею ePrint 2024/1627 как возможный способ получить меньше gas за счет меньших полей, но не выдать research-прототип за production-решение.

**Файлы:**

- `lollipop305_research/rust_backend/*`
- `lollipop305_research/src/*`
- `lollipop305_research/test/*`
- `lollipop305_research/docs/L0_ARITHMETIC_BENCHMARK_RU.md`
- `lollipop305_research/docs/L1_MILLER_RESIDUE_ESTIMATE_RU.md`
- `lollipop305_research/docs/L5_FULL_ARTICLE640_ANALOGUE_STATUS_RU.md`
- `lollipop305_research/docs/L8_FULL_LOLLIPOP_CYCLE_STATUS_RU.md`
- `lollipop305_research/docs/L9_SUPERSINGULAR_PAIRING_RESEARCH_RU.md`
- `lollipop305_research/docs/L10_EHAT_WEIL_PAIRING_FORMAL_RESULT_RU.md`
- `lollipop305_research/docs/L11_FULL_LOLLIPOP_IMPLEMENTATION_REPORT_RU.md`
- `lollipop305_research/docs/DEEP_AGENT_LOLLIPOP305_EHAT_TATE_ATE_RESEARCH_TASK_RU.md`
- `lollipop305_research/docs/DEEP_AGENT_LOLLIPOP305_EHAT_TATE_ATE_FOLLOWUP_RU.md`
- `docs/DEEP_AGENT_LOLLIPOP305_G2_TWIST_TASK_RU.md`

**Актуальный статус:** выполнено как full-cycle research prototype.

Изначально полный verifier был заблокирован выбором `G2/twist`. Этот блокер снят в исследовательском смысле: для lollipop-305 зафиксированы stick-часть, первая cycle-часть `E/Fp2 -> Fp4` и вторая cycle-часть `Ehat/Fq2 -> Fq6`. Дополнительно после исследования `Ehat` выяснено, что полная аналогия с MNT4/MNT6 невозможна: при embedding degree `k=3` стандартное удаление знаменателей линий не работает. Поэтому для `Ehat` реализован отдельный prepared-Ate/residue путь с двумя аккумуляторами:

```text
F = F_num / F_den,
c^p * F_den = F_num.
```

**Что реализовано сверх исходного плана:**

1. Доказательно зафиксирована причина, почему для `Ehat/Fq2` нельзя использовать тот же one-accumulator denominator-elimination path, что для MNT4/MNT6.
2. Реализован старый корректный, но дорогой Weil fallback для `Ehat`.
3. Реализован улучшенный `Ehat prepared-Ate/residue` путь: Rust backend генерирует prepared lines и witness `c`, Solidity verifier пересчитывает `F_num/F_den` и проверяет relation.
4. Проведены негативные тесты: подмена prepared line и witness отвергается.
5. Проведено итоговое сравнение lollipop с MNT4/MNT6.

**Ключевые gas-результаты lollipop-305:**

| Часть | Режим | Function gas |
|---|---|---:|
| stick | residue FE | `8,710,110` |
| `E/Fp2 -> Fp4` | residue FE | `18,359,648` |
| `Ehat/Fq2 -> Fq6` | Weil fallback | `200,977,272` |
| `Ehat/Fq2 -> Fq6` | prepared-Ate raw `F_num/F_den` | `76,422,749` |
| `Ehat/Fq2 -> Fq6` | prepared-Ate + residue | `106,441,661` |
| full lollipop-cycle | stick + `E` + `Ehat prepared-Ate/residue` | около `133,511,419` |

**Проверка:**

```bash
cd /Users/a.i.semenov/mnt4-pairing-final/lollipop305_research
forge test -vv --gas-report --gas-limit 3000000000
```

Свежий результат:

```text
43 tests passed, 0 failed, 0 skipped.
```

**Критерий готовности:**

- Есть полный lollipop-cycle research verifier с gas-таблицей.
- Есть формальная причина, почему `Ehat/Fq2` отличается от MNT4/MNT6: при `k=3` нельзя удалить знаменатели линий, поэтому используются `F_num/F_den`.
- Есть итоговый вывод: 2-limb арифметика дешевле, но полный lollipop-cycle в прямой EVM-проверке не становится дешевле MNT4/MNT6 Article640-режимов.
- Для production soundness arbitrary-cache остается отдельная задача: нужен line-cache proof layer или фиксированная/зарегистрированная prepared cache модель.

### Этап F8. Финальный отрицательный/граничный результат

**Цель:** сформулировать главный вывод работы: почему сейчас нельзя получить одновременно дешево по gas и дешево по constraints для MNT4-753 без MNT-precompile или нового proof/PCS слоя.

**Нужно покрыть три режима:**

1. **On-chain arithmetic:** корректно, но дорого по gas.
2. **Off-chain proof over BN254:** дешево on-chain, но дорого по constraints из-за non-native MNT4 arithmetic.
3. **Polynomial/FRI/KZG checks:** перспективно, но KZG переносит стоимость в constraints, а Merkle/FRI переносит стоимость в calldata.

**Дополнительная идея обхода:**

Chunked on-chain verifier:

```text
step 1: verify part of Miller loop, store accumulator
step 2: continue from stored accumulator
...
final step: final exponentiation / residue check
```

Такой подход не уменьшает суммарный gas, но позволяет каждый отдельный шаг уложить в block gas limit. Нужно описать риски:

- storage cost;
- replay/continuation state;
- необходимость привязки входов и accumulator;
- больше транзакций и latency;
- подходит только как инженерный обход block limit, а не как удешевление.

**Файл:**

- Новый документ: `docs/FINAL_NEGATIVE_AND_BOUNDARY_RESULTS_RU.md`

**Критерий готовности:**

- Есть строгий финальный вывод: что именно реализовано, что невозможно дешево сейчас, какие есть пути продолжения.

### Этап F9. Синхронизация презентации, краткого отчета и диплома

**Цель:** привести текстовые материалы к одной финальной версии без противоречий.

**Файлы:**

- `/Users/a.i.semenov/Desktop/diploma/MAIN2_DEFENSE_PRESENTATION_ARTICLE640.tex`
- `/Users/a.i.semenov/Desktop/diploma/Семенов презентация.pdf`
- `docs/WORK_SUMMARY_SHORT_RU.tex`
- `docs/WORK_SUMMARY_SHORT_RU.pdf`
- основной текст диплома в актуальном `main-2.tex` или его текущей версии

**Что внести:**

1. Обновленные gas-таблицы по on-chain ladder.
2. Финальный результат Article640 direct residue/code-shards.
3. Финальный PCS/KZG/Merkle-FRI trade-off вместо Groth16 baseline.
4. Финальный статус lollipop-305.
5. Итоговый отрицательный результат и roadmap.
6. Ссылка на clean-директорию с финальным кодом.
7. Убрать устаревшие утверждения о “готовом дешевом folding”, если они еще есть.
8. Заменить англицизмы там, где есть корректные русские термины.
9. Оставить устоявшиеся термины: `gas`, `calldata`, `commitment`, `proof`, `constraints`, `Miller loop`, `KZG`, `FRI`.

**Команды проверки:**

```bash
cd /Users/a.i.semenov/Desktop/diploma
tectonic MAIN2_DEFENSE_PRESENTATION_ARTICLE640.tex

cd /Users/a.i.semenov/mnt4-pairing-final/docs
pdflatex WORK_SUMMARY_SHORT_RU.tex
```

Для основного текста диплома команда зависит от актуального имени файла. Ее нужно зафиксировать в финальном README.

**Критерий готовности:**

- Презентация, краткий отчет и диплом говорят одно и то же.
- Все числа в слайдах совпадают с gas-report/constraint-report.
- В тексте нет утверждения, которое не подтверждается кодом, тестом, формулой или отдельным исследовательским документом.

### Этап F10. Очистка и финальная директория с понятным кодом

**Цель:** создать отдельную чистую директорию с финальным кодом, где нет исторических экспериментов, старых суррогатных путей и непонятных вспомогательных файлов. Это нужно, чтобы руководитель и комиссия могли открыть проект и увидеть ясную структуру: арифметика, on-chain baseline, Article640 verifier, lollipop research, тесты и документы.

**Новая директория:**

- `/Users/a.i.semenov/mnt4-pairing-final-clean` или другое согласованное имя.

**Предлагаемая структура:**

```text
mnt4-pairing-final-clean/
  README.md
  docs/
    ARITHMETIC_ALGORITHM_STUDY_RU.md
    ALGORITHM_COMPLEXITY_ESTIMATES_RU.md
    MNT4_ONCHAIN_OPTIMIZATION_LADDER_RU.md
    ARTICLE640_POLYNOMIAL_CHECK_TRADEOFF_RU.md
    FINAL_NEGATIVE_AND_BOUNDARY_RESULTS_RU.md
  onchain_full/
    src/
    test/
    foundry.toml
  article640_mnt4_verifier/
    src/
    test/
    fixtures/
    docs/
    foundry.toml
  lollipop305_research/
    src/
    test/
    rust_reference/
    rust_backend/
    docs/
    foundry.toml
  scripts/
    run_all_tests.sh
    collect_gas_reports.sh
```

**Что перенести:**

1. Только актуальные production/research файлы, которые нужны для защиты.
2. Все Foundry-тесты, которыми подтверждаются таблицы в дипломе.
3. Rust reference/backend для lollipop и/или off-chain генерации witness, если он используется в финальном тексте.
4. Документы, которые прямо закрывают замечания руководителя.

**Что не переносить:**

1. Старые surrogate/prototype пути, если они не используются в финальном выводе.
2. Логи, cache, `out`, временные fixtures, которые можно пересобрать.
3. Документы, противоречащие финальной версии работы.
4. Groth16 full proof директорию как финальный обязательный контур, если мы решили не доводить ее до защиты. Ее можно оставить в старом репозитории как исторический эксперимент, но не включать в clean-директорию по умолчанию.

**Критерий готовности:**

- В clean-директории есть README с командами запуска всех тестов.
- Все команды из README проходят.
- Код снабжен короткими поясняющими комментариями в местах, где используется нетривиальная арифметика/Yul.
- Структура директории совпадает с повествованием диплома.
- В презентации можно ссылаться именно на эту директорию как на финальную реализацию.

## 4. Рекомендуемый порядок выполнения

1. F1: 3-limb arithmetic final audit.
2. F2: 2-limb arithmetic final audit.
3. F3: naive Tate baseline.
4. F4: on-chain optimization ladder.
5. F5: Article640 finalization and polynomial-check trade-off.
6. F6: MNT-cycle-native roadmap and PCS/constraints-heavy argument.
7. F6B: preliminary MNT4/MNT6 cycle-native layer.
8. F6C: full MNT6 on-chain/article640 research verifier.
9. F7: lollipop final decision: full prototype or formal stop-result.
10. F8: final negative/boundary result.
11. F9: presentation and diploma synchronization.
12. F10: clean final code directory.

Этот порядок выбран так, чтобы сначала закрыть вопросы руководителя по арифметике и сложности, затем закрыть архитектуры вычисления, затем оформить научный вывод и только после этого собрать чистый код без исторического мусора.

## 5. Финальные критерии готовности всей работы

Работа считается полностью завершенной, когда выполнены все пункты:

1. Есть воспроизводимые gas-report для всех основных on-chain режимов.
2. Есть gas/op таблицы для 3-limb и 2-limb арифметики.
3. Есть naive baseline и оптимизационная лестница.
4. Есть direct residue verifier по ePrint 2024/640 и объяснение, почему он не решает стоимость Miller loop.
5. Есть formal trade-off KZG vs Merkle/FRI для polynomial-check идеи.
6. Есть PCS/KZG/Merkle-FRI анализ, показывающий constraints-heavy и calldata-heavy стороны замены цикла Миллера на polynomial check.
7. Есть предварительный MNT4/MNT6 cycle-native слой: параметры, Rust reference, relation fragments, constraints/operation counts и сравнение с BN254 non-native переносом.
8. Есть финальный статус lollipop-направления: полный прототип или строго обоснованный блокер.
9. Есть документ с отрицательным/граничным результатом: почему дешево одновременно по gas и constraints сейчас не получается.
10. Презентация и текст диплома обновлены и не противоречат коду.
11. Создана clean-директория с финальным кодом, README и воспроизводимыми командами тестирования.
