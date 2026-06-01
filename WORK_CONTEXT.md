# WORK_CONTEXT

## Текущий фокус
Научный руководитель попросил усилить исследование реализации арифметики на Solidity/Yul: сравнить алгоритмы умножения/редукции в базовом поле и расширениях, обосновать оптимальность выбранного пути и предложить реальные низкоуровневые улучшения.

## Главная директория арифметики
Основная реализация длинной арифметики и полного on-chain baseline находится в `onchain_full/src`:
- `BigIntMNT.sol` — базовое поле MNT4-753, 3 limb по 256 бит, Montgomery/CIOS, Yul hot path.
- `BigIntMNTBarrett.sol` — экспериментальная Barrett-редукция для сравнения.
- `BigIntMNTFIOS.sol` — экспериментальная FIOS-форма Montgomery-умножения для сравнения.
- `MNT4Extension.sol` — башня расширений Fq2/Fq4, Karatsuba-формулы, cheap non-residue multiplication, pointer/packed API.
- `MNT4TatePairing.sol` — цикл Миллера, prepared/sparse line cache, code-shards, финальная экспонента, fixed-Q/full baseline.

## Уже измеренные выводы
- Montgomery/CIOS значительно дешевле Barrett и FIOS для MNT4-753 в EVM.
- Базовые gas/op: Fq mul ~2,959; Fq sqr ~2,947; Fq2 mul ~11,877; Fq2 sqr ~10,592; Fq4 mul ~42,764; Fq4 sqr ~36,606.
- Barrett: ~46,998 gas/op для Fp mul; FIOS: ~18,509 gas/op для Fp mul, то есть оба хуже production Montgomery/CIOS.

## Что еще стоит исследовать для закрытия замечаний 1-2
1. Специализированный 3x3 Comba/SOS Montgomery mul/sqr как отдельный вариант против текущего CIOS.
2. Lazy reduction в Fq2/Fq4 и fused Miller step с доказанными bound-инвариантами.
3. Специализированные проверки cheap non-residue и sparse-line умножений против generic Fq4 multiplication.
4. Branchless conditional reduction только как сравнительный вариант: on-chain side channel не релевантен, а gas может вырасти.
5. Единый отчет/таблица по всем вариантам: теория, операции EVM, gas, почему выбран основной путь.

## 2026-05-24 — закрытие замечаний 1-2 по арифметике
Добавлены экспериментальные реализации и сравнения:
- `onchain_full/src/BigIntMNTComba.sol` — Comba/SOS-style Montgomery multiplication.
- `onchain_full/src/BigIntMNTBranchless.sol` — branchless reduction helpers.
- `onchain_full/src/MNT4ExtensionAlgorithmVariants.sol` — lazy Fq2 variants и generic-vs-specialized non-residue comparisons.
- `onchain_full/test/MNT4ArithmeticAlgorithmStudy.t.sol` — correctness и gas-report для новых вариантов.
- `docs/ARITHMETIC_ALGORITHM_STUDY_RU.md` — отчет для руководителя.

Итог: production path остается Montgomery/CIOS + Karatsuba + cheap non-residue + sparse/prepared lines. Comba/SOS, FIOS, Barrett и branchless варианты корректны, но проигрывают по gas. Lazy Fq2 variants полезны как эксперимент, но не дают устойчивого выигрыша при интеграции в общий extension path.

## 2026-05-24 — Aggressive Miller hot-path fusion experiment

Implemented an experimental aggressive fusion path in `onchain_full/src/MNT4TatePairing.sol` for the operation `f <- f^2 * line(P)`. The new helper `_fq4SqrMulByLinePtrTo` expands the square and sparse line multiplication over `Fq2` and avoids materializing a separate full `Fq4` object for `f^2`. The production path is unchanged; the new API is suffixed with `Aggressive`.

Verification command:

```bash
cd /Users/a.i.semenov/mnt4-pairing-final/onchain_full
forge test --match-contract MNT4TatePairingV4Test \
  --match-test 'testPreparedSparseAggressive|testGasBench_(miller|pairing|multi_miller|multi_pairing)_fixedQ_prepared_sparse_digest' -vv
```

Result: `9 passed; 0 failed; 0 skipped`.

Gas comparison:

- Single Miller digest: old `238,581,004`, aggressive `238,560,411`, delta `-20,593` gas.
- Single full pairing digest: old `267,026,828`, aggressive `267,006,510`, delta `-20,318` gas.
- Multi Miller aggressive, 2 points: `274,078,151` gas.

Conclusion: the experiment is correct but only saves about 20k gas. It reduces memory movement, not the dominant number of expensive 753-bit extension-field multiplications. It is useful as evidence that the remaining bottleneck is mathematical/protocol-level, not merely local Yul packing.

## 2026-05-25: Complexity estimates document

Added `docs/ALGORITHM_COMPLEXITY_ESTIMATES_RU.md` to close the supervisor's third remark: algorithmic complexity estimates in terms of EVM/basic field operations and higher-level operations. The document links base `Fp` gas/op, extension tower formulas, Miller loop lower bounds, final exponentiation decomposition, direct residue verifier gas, and proof/constraints limitations into one coherent model.

## 2026-05-25 — Stage L0 lollipop-305 arithmetic benchmark
- Добавлена отдельная директория `lollipop305_research/` для проверки арифметики lollipop-305-158 из ePrint 2024/1627.
- Реализованы: Rust reference на `num-bigint`, Solidity/Yul 2-limb Montgomery `Fp`, `Fp2`, `Fp4`, Foundry correctness/fuzz tests и gas-report.
- Ключевой результат: 2-limb `Fp.mul` стоит около 2,023 gas/op против 3,287 gas/op у MNT4-753; в `Fp4.mul` выигрыш меньше, около 35,822 gas/op против 42,764 gas/op.
- Вывод: малое поле дает измеримый, но не радикальный выигрыш; полный Miller/residue verifier для lollipop имеет смысл делать только после отдельной оценки длины цикла, башни расширений и требований безопасности.

## 2026-05-25 — Stage L0 lollipop-305 optimization pass
- Для lollipop-305 добавлены дополнительные варианты: Comba/SOS, FIOS, Barrett, специализированное `Fp.square`, stack/packed `Fp2/Fp4`, full-stack `Fp4.mul` benchmark.
- Проверки: `cargo test` для Rust reference и `forge test --match-path test/Lollipop305Arithmetic.t.sol --gas-report -vv` проходят.
- Лучшие результаты: `Fp.mul` 2,081 gas/op, `Fp.square` 1,926 gas/op, `Fp2.mul` 7,361 gas/op, `Fp2.square` 6,289 gas/op, `Fp4.mul` 24,243 gas/op, `Fp4.square` 22,028 gas/op.
- CIOS остался лучшим для базового умножения; FIOS/Comba/Barrett проиграли и оставлены как отрицательные сравнения. Главный выигрыш пришел от stack/full-stack API в расширениях.

## 2026-05-25 — Stage L1 lollipop-305 Miller/residue gas estimate
- Добавлен документ `lollipop305_research/docs/L1_MILLER_RESIDUE_ESTIMATE_RU.md` с оценкой полного direct Miller/residue verifier для lollipop-305.
- Оценка использует MNT4 article640 measured baseline и L0 lollipop gas/op: expected Miller core около 20-25M gas, full direct FE около 38-48M gas, residue FE около 28-35M gas.
- В отличие от MNT4-753, residue FE для lollipop-305 должна быть полезнее: direct hard exponent примерно 452 bits, а residue exponent `r` около 158 bits.
- Вердикт: имеет смысл реализовать как research prototype; не production-secure, потому что lollipop-305-158 имеет только около 77-88 bits security по ePrint 2024/1627.
## 2026-05-25 — Stage L2 lollipop-305 params/backend/arithmetic
- Зафиксированы точные параметры `lollipop-305-158` по ePrint 2024/1627 Appendix A Example 1 и исходному `lollipop-305-158.m`: `p=x^2-x+1`, `q=x^2+1`, 158-битный `r`, ordinary stick-curve `E/Fp`.
- Добавлен Rust crate `lollipop305_research/rust_backend` с параметрами, reference `Fp/Fp2/Fp4`, проверкой точки на `E/Fp` и JSON smoke fixture.
- Сформирован документ `lollipop305_research/docs/L2_PARAMETERS_AND_BACKEND_RU.md`, который фиксирует выбранную Solidity/Yul арифметику и gas-результаты.
## 2026-05-25 — Stage L3 lollipop-305 curve/lines/Miller backend
- Подтверждено: MNT4 `article640_mnt4_verifier` и `onchain_full` фактически используют ate-loop (`ATE_LOOP_ENC`, `|t-1|`), несмотря на исторические имена `TatePairing`.
- В `lollipop305_research/rust_backend` добавлены `curve.rs` операции `double/add/scalar_mul`, `miller.rs` prepared sparse lines и Miller trace builder для ate scalar `x-1`.
- Добавлен документ `lollipop305_research/docs/L3_CURVE_LINES_MILLER_RU.md`; backend trace дает `naf_len=154`, `step_count=199`.
## 2026-05-25 — Stage L4 lollipop-305 Fp4 pairing layer
- Добавлен Rust слой `E(Fp4)`: `extension_curve.rs` с `add/double/scalar_mul/is_in_r_subgroup`, embedding `E(Fp)->E(Fp4)`.
- В `field.rs` добавлены `Fp2.inverse`, `Fp4.inverse`, `Fp4.pow`, `Fp4.sqrt` (для будущего поиска extension-точек).
- В `pairing.rs` добавлены `miller_trace_fp4`, `final_exponent`, `reduced_ate_pairing_base_source`; тесты подтверждают `Y^r=1` после final exponent.
- Важная граница: default smoke использует embedded base-field point и может быть вырожденным; production G2/twist selection для lollipop-305 остается отдельным следующим этапом.
## 2026-05-25 — lollipop-305 full analogue attempt status
- Проверено отличие координат: MNT4 `article640_mnt4_verifier` использует `G2ProjectiveExtended`/mixed formulas, lollipop Rust layer изначально был affine.
- Добавлен projective `E(Fp4)` backend и тест `projective_fp4_matches_affine_for_small_scalar`; это устраняет per-step inversions в Rust scalar multiplication.
- Попытка получить full analogue заблокирована на точном выборе невырожденного `G2`/twist для lollipop-305. Документ: `lollipop305_research/docs/L5_FULL_ARTICLE640_ANALOGUE_STATUS_RU.md`.
- Solidity/Yul hot-path verifier для lollipop пока не реализован намеренно: без `G2` он был бы математически некорректным/вырожденным.

## 2026-05-25 — краткий отчет и задача для deep agent

Обновлен `docs/WORK_SUMMARY_SHORT_RU.tex`: добавлены результаты `ARITHMETIC_ALGORITHM_STUDY_RU.md`, `ALGORITHM_COMPLEXITY_ESTIMATES_RU.md`, расширен блок по direct residue verifier ePrint 2024/640, добавлен блок по ePrint 2024/1627 и lollipop-305. Зафиксирован осторожный вывод: lollipop-305 арифметика дешевле MNT4-753 примерно в 1.5--1.8 раза, но пример не production-secure; безопасные lollipop-кривые могут иметь большие поля и дорогую арифметику.

Создано задание для агента `docs/DEEP_AGENT_LOLLIPOP305_G2_TWIST_TASK_RU.md`: нужно строго определить `G2`/twist/subgroup/generators/non-degenerate pairing для lollipop-305, чтобы продолжать реализацию полного verifier.

## 2026-05-25 — отчет и презентация после замечаний

В `docs/WORK_SUMMARY_SHORT_RU.tex` из таблицы Direct residue verifier удалена строка `Prepared sparse, одно сопряжение` на `79,629,106 gas`. Презентация `/Users/a.i.semenov/Desktop/diploma/MAIN2_DEFENSE_PRESENTATION_ARTICLE640.tex` расширена с 14 до 19 слайдов: добавлены слайды про исследование арифметических алгоритмов, сравнение вариантов арифметики, идею ePrint 2024/1627 и lollipop-305 gas-результаты. Собранные PDF: `/Users/a.i.semenov/mnt4-pairing-final/docs/WORK_SUMMARY_SHORT_RU.pdf` и `/Users/a.i.semenov/Desktop/diploma/Семенов презентация.pdf`.

## 2026-05-25 — правки презентации по замечаниям

В `/Users/a.i.semenov/Desktop/diploma/MAIN2_DEFENSE_PRESENTATION_ARTICLE640.tex` внесены правки: на слайд 5 добавлена реализация lollipop-305 арифметики; удален отдельный слайд `Исследование арифметических алгоритмов`; сравнение вариантов арифметики перенесено после слайда 7; из слайда ePrint 2024/1627 удалена фраза `Это не готовая замена MNT4-753...`; слайд lollipop-305 объединен с таблицей gas и удален блок `Ограничение`. PDF пересобран на 17 страниц/слайдов и скопирован в `/Users/a.i.semenov/Desktop/diploma/Семенов презентация.pdf` и `/Users/a.i.semenov/Downloads/Семенов презентация.pdf`.

## 2026-05-25 — практический смысл в кратком отчете

В `docs/WORK_SUMMARY_SHORT_RU.tex` добавлен раздел `Практический смысл работы`: зачем нужны цепочки вычислений, рекурсивные доказательства, rollup/batch/private-протоколы, почему MNT4/MNT6 полезны для рекурсии и почему отсутствие MNT-precompile в EVM делает работу актуальной. PDF пересобран: `docs/WORK_SUMMARY_SHORT_RU.pdf`, 7 страниц.

## 2026-05-25 — расширение пункта 2 краткого отчета

В `docs/WORK_SUMMARY_SHORT_RU.tex` расширен раздел `Практический смысл работы`: добавлены конкретные примеры rollup на 10,000 транзакций, цепочки из 24 hourly proofs, межсетевого моста и приватного протокола. PDF пересобран: `docs/WORK_SUMMARY_SHORT_RU.pdf`, 7 страниц.

## 2026-05-26 — Article640 pairing modes gas comparison

## 2026-05-30 — Article640 hot verifier with cache commitments

Добавлен строгий hot-path verifier `article640_mnt4_verifier/src/MNT4Article640HotCommitmentVerifier.sol`. Он сохраняет быстрый packed sparse/Yul путь из `MNT4Article640DirectHotVerifier`, но перед вычислением проверяет Keccak commitment к prepared sparse cache для фиксированного `Q` и фиксированного `S`.

Проверенные режимы:
- `verifyEquationResidueCommitted`: calldata blobs + commitment binding.
- `verifyEquationResidueCommittedCodeShards`: code-shards через `EXTCODECOPY` + commitment binding к содержимому shard-ов.

Свежий gas-report:
- старый hot calldata residue без binding-а: `93,881,355 gas`;
- старый hot code-shards residue без binding-а: `93,685,247 gas`;
- новый hot calldata residue с commitment binding: `93,974,409 gas`;
- новый hot code-shards residue с commitment binding: `94,511,193 gas`.

Вывод: строгий commitment binding для calldata sparse blobs почти не меняет стоимость относительно прежнего hot-path. Code-shards с проверкой содержимого дороже примерно на `0.83M gas`, потому что shard-код читается один раз для хеша и затем еще раз в streaming Miller hot-path.

Добавлен production-shaped fixed-shards verifier `article640_mnt4_verifier/src/MNT4Article640FixedShardsVerifier.sol`. В нем адреса shard-контрактов задаются в конструкторе, публичный `verifyEquationResidueFixedShards(P,R,c,cInv)` не принимает кэш и не считает commitment на каждом вызове. Это соответствует модели, где prepared cache является частью конфигурации verifier-а.

Свежий function gas:
- `verifyEquationFixedQParametricSResidueCodeShards`, старый API с shard-адресами как input: `93,685,247 gas`;
- `verifyEquationResidueFixedShards`, новый API с fixed shard-адресами:
  первоначально `93,705,233 gas`, после добавления проверки G1 -
  `93,734,789 function gas`;
- overhead около `19,986 gas`, в основном из-за чтения shard-адресов из storage; координаты `S` перенесены в `immutable`, чтобы убрать лишние storage reads.

Проверка: `cd article640_mnt4_verifier && forge test -vv` -> `64 tests passed, 0 failed`.

Added a dedicated gas comparison bench for `article640_mnt4_verifier`:

- `article640_mnt4_verifier/test/MNT4Article640PairingModesGas.t.sol`
- `article640_mnt4_verifier/docs/ARTICLE640_PAIRING_GAS_COMPARISON_RU.md`
- `article640_mnt4_verifier/article640_pairing_modes_gas_report.log`

Measured function-level gas:

- full on-chain fixed-Q pairing digest: `259,332,454` gas;
- prepared sparse blob digest: `79,756,052` gas;
- prepared sparse code-shards digest: `80,170,659` gas;
- article640 hot full equation: `115,993,132` gas;
- article640 hot residue equation: `93,879,746` gas.

Clarification for defense: in the `93,879,746` gas article640 hot residue path, line caches are not embedded in the main verifier contract. They are passed as prepared sparse `bytes` blobs (`dblSparseQ`, `addSparseQ`, `dblSparseS`, `addSparseS`). Helper methods generate them in tests only; production must precompute/register them outside the verify transaction.

## 2026-05-26 — Pairing equation and c-witness explanation

Added tutorial-style document:

- `article640_mnt4_verifier/docs/PAIRING_EQUATION_AND_C_WITNESS_RU.md`

The document explains:

- why `phi(f)=Y` and `phi(F)=1` are different mathematical statements;
- why `article640_mnt4_verifier` verifies `e(P,Q) * e(-R,S) = 1`;
- how this mirrors Groth16/BN254 pairing-equation verification;
- what the `c` witness proves (`F` lies in the kernel of final exponentiation);
- why replacing `e(P,Q)=Y` with `e(P,Q)=1` is not mathematically valid unless the original statement really is an identity/equation check.

## 2026-05-26: Article640 residue code-shards variant
- Added `verifyEquationFixedQParametricSResidueCodeShards(...)` in `article640_mnt4_verifier/src/MNT4Article640SameQHotVerifier.sol`.
- Added internal `pairingEquationFixedQParametricSPreparedSparseCodeShardsResidueIsOne(...)` and `_millerLoopFixedQParametricSPreparedSparseCodeShardsResidueMemTo(...)` in `article640_mnt4_verifier/src/MNT4TatePairing.sol`.
- The new path reads both Q and S prepared sparse line caches via `EXTCODECOPY` from data-contract shards instead of passing four `bytes` blobs.
- Added `testGas_article640HotResidueEquationCodeShards` and `testCodeShards_equalResidueEquationBool` in `article640_mnt4_verifier/test/MNT4Article640PairingModesGas.t.sol`.
- Fresh command: `cd /Users/a.i.semenov/mnt4-pairing-final/article640_mnt4_verifier && forge test -vv --gas-report | tee article640_full_test_gas_report.log`.
- Result: 43 tests passed, 0 failed. Gas-report: blob/memory residue path `verifyEquationFixedQParametricSResidue` max `93,881,355`; code-shards residue path `verifyEquationFixedQParametricSResidueCodeShards` max `93,685,247`.
- Interpretation: code-shards saves about `196,108 gas` at function level, but gas remains dominated by Miller-loop arithmetic. The production benefit is mainly avoiding repeated huge calldata for reused fixed caches.

## 2026-05-27 — финальный план завершения диплома
- Создан общий план завершения работы: `docs/FINAL_DIPLOMA_COMPLETION_PLAN_RU.md`.
- Дубликат в формате superpowers plan: `docs/superpowers/plans/2026-05-27-final-diploma-completion-plan.md`.
- План разбивает оставшуюся работу на F1--F10: финальный аудит 3-limb/2-limb арифметики, naive Tate baseline, optimization ladder, article640 polynomial-check trade-off, Groth16 strict proof refresh, MNT-cycle roadmap, lollipop final decision, negative/boundary result, синхронизация презентации и диплома.
- Текущий статус: арифметика и article640 реализованы частично/хорошо; отсутствуют naive baseline, единая optimization ladder, финальный polynomial PCS документ, финальный lollipop verifier или формальный stop-result, и синхронизация диплома после всех измерений.

## 2026-05-27 — корректировка финального плана
- Из `docs/FINAL_DIPLOMA_COMPLETION_PLAN_RU.md` удален этап доведения полного BN254 Groth16 proof для MNT4-753 до финала.
- Constraints-heavy аргумент теперь должен показываться через ePrint 2024/640 polynomial-check + KZG/opening layer: KZG дает короткий on-chain verifier, но переносит MNT4 arithmetic в non-native BN254 constraints; Merkle/FRI переносит стоимость в calldata.
- Добавлен финальный этап F10: создать clean-директорию с минимальным, понятным кодом, README, тестами и документами; не переносить исторические/суррогатные/неиспользуемые реализации.

## 2026-05-27 — F1 final audit of 3-limb arithmetic

Closed F1 for MNT4-753 3-limb EVM arithmetic. Added an experimental square-specialized Comba/SOS variant in `onchain_full/src/BigIntMNTSquareComba.sol` and covered it in `onchain_full/test/MNT4ArithmeticAlgorithmStudy.t.sol`. Fresh gas tests show production `BigIntMNT.sol` Montgomery/CIOS remains best: `montMul3` internal 2,959 gas/op and `montSqr3` internal 2,947 gas/op. Alternatives are worse: Barrett ~46,998 gas/op, FIOS ~18,509 gas/op, Comba/SOS ~18,772 gas/op, Square-Comba ~18,420 gas/op. Documented the lower-bound reasoning and final conclusion in `docs/F1_3LIMB_ARITHMETIC_FINAL_AUDIT_RU.md`: no safe >10% reduction was found at the base-field 3-limb layer; further gas reductions should target higher-level formulas and reducing the number of generic Fq/Fq4 operations.

## 2026-05-27 — Claude F1 optimization report checked

Checked external Claude optimization report for further 3-limb Montgomery/CIOS gas reductions. Implemented two compileable candidates: `onchain_full/src/BigIntMNTFinalSelect.sol` (branchless final subtraction) and `onchain_full/src/BigIntMNTSkipT0.sol` (skip dead `t0` write in `m*p0` blocks), with tests in `onchain_full/test/BigIntMNTClaudeOptimization.t.sol`. Also attempted full branchless-carry all-stack candidate, but it made `solc 0.8.33 --via-ir` exit with SIGKILL, so it is not retained. Results: current `BigIntMNT.montMul3` bench 1,516,911 gas / 512 ops (~2,963 gas/op); final-select candidate 1,603,003 / 512 (~3,131 gas/op), worse; skip-t0 candidate 1,516,889 / 512, effectively identical. Conclusion: Claude's predicted 10-15% reduction is not confirmed on real solc/EVM; production `BigIntMNT.sol` remains best.

## 2026-05-27 — F2 final audit of 2-limb lollipop-305 arithmetic

Closed F2 with a positive optimization result. In `lollipop305_research/src/BigIntLollipop305.sol`, applied small-high-limb optimization: since lollipop-305 has `P_1 < 2^49`, reduced high limbs satisfy `a1,b1 < 2^49`, so `a1*b1` and `a1*a1` fit in 98 bits and do not need full `mul512`/`mulmod`. Also skipped dead `t0` writes in Montgomery `m*p0` blocks. Added comparison candidates and tests in `lollipop305_research/test/Lollipop305F2Optimization.t.sol`. Fresh gas after F2: `Fp.mul` 521,228/512 = ~1,018 gas/op, `Fp.square` 481,101/512 = ~940 gas/op, `Fp2.mul stack` ~4,171, `Fp4.mul full-stack` ~14,675. This is about 2.8x-3.3x cheaper than MNT4-753 arithmetic. Documented in `docs/F2_2LIMB_ARITHMETIC_FINAL_AUDIT_RU.md` and updated `lollipop305_research/docs/L0_ARITHMETIC_BENCHMARK_RU.md`.

## F3 — naive Tate baseline

Добавлен отдельный модуль `/Users/a.i.semenov/mnt4-pairing-final/naive_tate_baseline`. Он реализует MNT4-753 `Fq/Fq2/Fq4` на чистом Solidity без Yul hot-path, fixed-Q cache, sparse line multiplication, ate-shortening и optimized final exponentiation. Это не production-код, а наивный baseline для оптимизационной лестницы.

Ключевые измерения: `Fq.mul` fixture 18,770 gas, `Fq2.mul` 110,080 gas, `Fq4.mul` 486,819 gas, `Fq4.square` 486,899 gas, один generic Miller step `f <- f^2 * line` 973,261 gas, 16-bit generic exponentiation chunk 13,779,681 gas. Экстраполяция полного naive Tate accumulator + generic FE: около 2.55 млрд gas без учета построения линий и twist-point arithmetic. Тесты: `cd /Users/a.i.semenov/mnt4-pairing-final/naive_tate_baseline && forge test --match-path test/MNT4TatePairingNaive.t.sol -vv --gas-report` — 7 passed, 0 failed.

## F4 — on-chain optimization ladder

Добавлен тест `/Users/a.i.semenov/mnt4-pairing-final/onchain_full/test/MNT4OptimizationLadder.t.sol` и документ `/Users/a.i.semenov/mnt4-pairing-final/docs/MNT4_ONCHAIN_OPTIMIZATION_LADDER_RU.md`. Ladder фиксирует вклад оптимизаций: naive Tate baseline около 2.55B gas (экстраполяция F3), `Fq.mul` 18,770 -> 2,959 gas/op, Tate accumulator -> Ate accumulator 912,988,940 -> 427,284,953 gas, fixed-Q on-chain line generation 258,753,182 gas, prepared sparse blob 79,588,799 gas, code-shards 79,586,596 gas, optimized FE overhead около 28.13M gas, aggressive fused Miller дает только небольшой остаточный выигрыш: 51,978,344 -> 51,949,399 gas для Miller digest.

## F4 — refined optimization ladder document

Документ `/Users/a.i.semenov/mnt4-pairing-final/docs/MNT4_ONCHAIN_OPTIMIZATION_LADDER_RU.md` переписан в формате постепенного применения оптимизаций. Теперь содержит: интегральную ladder-таблицу полного вычисления, отдельную арифметическую таблицу `Fq/Fq2/Fq4`, отдельные таблицы для Miller loop, final exponentiation и prepared cache. Для каждой строки указаны описание, gas result и процент снижения относительно корректной предыдущей ступени или базовой операции.

## Plan update — preliminary MNT4/MNT6 cycle-native layer

В финальном плане обнаружено, что прежний F6 покрывал только roadmap/PCS/constraints-heavy аргумент, но не требовал кодового слоя MNT4/MNT6 cycle-native направления. Добавлен отдельный этап F6B: `Предварительный MNT4/MNT6 cycle-native слой`. DoD: отдельный модуль `mnt_cycle_full/`, Rust reference для `ark-mnt4-753` и `ark-mnt6-753`, проверка равенств `Fr(MNT4)=Fq(MNT6)` и `Fr(MNT6)=Fq(MNT4)`, relation fragments для cycle-native арифметики, constraints/operation counts и сравнение с BN254 non-native переносом. Важно: это не полный CycleFold и не production EVM verifier.

## F5 — ePrint 2024/640 PCS/opening layer finalized

В `article640_mnt4_verifier` добавлены реальные PCS/opening реализации для polynomial-check ветки ePrint 2024/640:

- `src/Article640KzgBn254OpeningVerifier.sol`: KZG opening verifier over BN254 precompiles. Проверяет реальное уравнение `e(C - yG1 + x*pi, G2) = e(pi, tauG2)`; для воспроизводимого теста используется toy SRS `tau=1`, gas verifier-а репрезентативен по precompile composition.
- `src/Article640MerkleFriOpeningVerifier.sol`: Merkle-opening layer для Merkle/FRI ветки; проверяет реальные Merkle authentication paths и содержит модель calldata для MNT4-753 field elements (`96 bytes` per element). Это не полный FRI low-degree verifier, а обязательный opening/calldata layer, который показывает узкое место Merkle/FRI пути.
- `test/MNT4Article640PcsVerifiers.t.sol`: тесты acceptance/rejection/gas для KZG и Merkle openings.
- `rust/article640_backend/src/bin/pcs_constraints.rs`: реальный R1CS-замер emulated MNT4 field arithmetic inside BN254 через `ark-r1cs-std::fields::emulated_fp::EmulatedFpVar`.
- `docs/ARTICLE640_POLYNOMIAL_CHECK_TRADEOFF_RU.md`: итоговый отчет по trade-off.

Свежие результаты:

- Foundry: `forge test -vv --gas-report` в `article640_mnt4_verifier`: 51 tests passed, 0 failed.
- KZG opening verifier: `133,039 gas` по gas-report.
- Merkle opening: `1,093 gas`; 8 openings depth 16: `46,402 gas max`.
- Merkle/FRI calldata model example: `4096*96 + 128*16*32 + 16*32 = 459,264 bytes`.
- R1CS constraints (`cargo run --release --bin pcs_constraints`): `Fq mul = 3,692`, `Fq2 mul = 11,300`, `Fq4 mul model = 63,436`, approximate sparse Miller relation `63,309,128 constraints`.

Вывод F5: ePrint 2024/640 polynomial-check направление реализовано как проверяемый PCS/opening слой. KZG дает короткий on-chain verifier, но переносит MNT4-арифметику в BN254 non-native constraints; Merkle/FRI избегает части BN254 non-native constraints, но переносит стоимость в calldata/openings.

## 2026-05-29 — проверка Ehat Tate/Ate исследования для lollipop-305

Проверены документы агента `LOLLIPOP305_EHAT_TATE_ATE_RESEARCH.md` и `LOLLIPOP305_SUPERSINGULAR_PAIRING_EQUATIONS.md`. Вывод: направление `Ehat/Fq2` через prepared Ate/Tate + residue перспективно, но текущая спецификация недостаточна для безопасной реализации. Найдены критические разрывы: параметр `s=x-1` требует более строгого доказательства как ate-loop parameter; псевдокод Miller loop ошибочно возводит аккумулятор в квадрат на addition-step; формула вычисления residue witness через `p^{-1} mod (q^6-1)` невозможна, так как `p | q^6-1`; нет готовых Rust test vectors для `F_num/F_den/c`. Создан follow-up документ для агента: `lollipop305_research/docs/DEEP_AGENT_LOLLIPOP305_EHAT_TATE_ATE_FOLLOWUP_RU.md`.

## 2026-05-29 — реализация Ehat prepared-Ate/residue

По исправленной спецификации агента добавлен рабочий `Ehat/Fq2` prepared-Ate/residue путь рядом с Weil fallback. Rust backend генерирует prepared lines для `Q'=psi(Q0)`, `F_num/F_den` и witness `c`; Solidity verifier заново вычисляет `F_num/F_den` по line cache и проверяет `c^p * F_den = F_num`. Добавлены `fq6MulBy01/fq6MulBy02`, `verifyEhatAteResidue`, fixture generator и тесты. Проверка: `cargo test -q` проходит, Foundry `43 tests passed, 0 failed`. Gas: `ehatAteResidueRaw` 76,422,749; `verifyEhatAteResidue` 106,441,661; старый `verifyEhatWeilEquation` 200,977,272. Вывод: Ehat prepared-Ate/residue примерно в 1.89 раза дешевле Weil fallback, но все еще не дешевле MNT4/MNT6 article640 режимов.

## F6 — MNT4/MNT6 cycle-native roadmap and PCS/constraints-heavy argument

Закрыт этап F6 из финального плана. Добавлен документ `docs/MNT_CYCLE_NATIVE_FOLDING_ROADMAP_RU.md`.

Документ связывает три блока работы:

1. ePrint 2024/640 polynomial-check постановку: witness polynomials, separation challenge `beta`, quotient polynomial `Q(X)`, evaluation challenge `alpha`, openings в точке `alpha`.
2. KZG over BN254 путь: короткая on-chain проверка opening (`133,039 gas`), но перенос MNT4-753 arithmetic в BN254 non-native constraints. Свежий R1CS замер: `Fq mul = 3,692`, `Fq2 mul = 11,300`, `Fq4 mul model = 63,436`, approximate sparse Miller relation `63,309,128 constraints`.
3. Merkle/FRI opening layer: реальные Merkle openings (`1,093 gas` одно открытие; `46,402 gas max` для 8 openings depth 16), но большой calldata из-за 96-byte MNT4 field elements; пример модели `459,264 bytes`.
4. MNT4/MNT6 cycle-native направление: `Fr(MNT4) ~= Fq(MNT6)` и `Fr(MNT6) ~= Fq(MNT4)` объясняют, почему будущий folding должен строиться над MNT-native relation layer, а не через полную BN254 non-native эмуляцию.

Свежие проверки:

- `forge test --match-path test/MNT4Article640PcsVerifiers.t.sol -vv --gas-report` в `article640_mnt4_verifier`: 8 passed, 0 failed.
- `cargo run --release --bin pcs_constraints` в `article640_backend`: вывел `approx_sparse_miller_constraints=63309128`.
- `cargo test --manifest-path crates/mnt_cycle_constraints/Cargo.toml`: 10 total tests passed (`2` unit + `8` integration), 0 failed.
- `cargo run --manifest-path crates/mnt_cycle_constraints/Cargo.toml --bin mnt-cycle-constraints-report`: подтверждено `Total prepared residue relation = 24,178`, compiled R1CS fragment `24,181` constraints.

Важная граница: F6 не утверждает готовый CycleFold или production EVM verifier для folding. Он фиксирует защищаемый аргумент: текущие F1--F5 показывают стоимость on-chain/PCS путей, а MNT4/MNT6 cycle-native слой является обоснованным направлением следующего этапа.

## F6B — предварительный MNT4/MNT6 cycle-native слой

Переименован этап F6B в `Предварительный MNT4/MNT6 cycle-native слой`, чтобы не создавать ложного впечатления, будто реализован полный CycleFold или production EVM verifier. Обновлены `docs/FINAL_DIPLOMA_COMPLETION_PLAN_RU.md` и mirrored plan в `docs/superpowers/plans/2026-05-27-final-diploma-completion-plan.md`.

Добавлен модуль `mnt_cycle_full/`:

- `src/lib.rs`: проверка field-cycle равенств, reference pairing digests для MNT4/MNT6, operation/constraint accounting для relation fragments.
- `src/main.rs`: генератор markdown-отчета.
- `tests/cycle_reference.rs`: тесты равенств полей, deterministic reference pairing, наличие обеих сторон цикла и MNT6 tower model.
- `constraints/README.md` и `rust/README.md`: пояснение границ реализации.
- `MNT_CYCLE_FULL_REPORT.md`: сгенерированный отчет.

Ключевые результаты F6B:

- `Fr(MNT4-753) = Fq(MNT6-753)`: true.
- `Fr(MNT6-753) = Fq(MNT4-753)`: true.
- MNT4 prepared relation accounting: `24,178` multiplication constraints.
- MNT6 preliminary prepared relation accounting: `49,120` multiplication constraints.
- BN254 non-native sparse Miller estimate from F5 remains `63,309,128` constraints.
- F6B не добавляет новый on-chain gas result; gas берется из F4/F5 (`pairingPreparedSparseCodeShardsWord = 79,586,596`, `Article640 residue code-shards = 93,685,247`, KZG opening verifier function = `133,039`).

Свежая проверка:

- `cd mnt_cycle_full && cargo test --release`: 4 integration tests passed.
- `cd mnt_cycle_full && cargo run --release --bin mnt_cycle_full_report`: отчет сгенерирован.
- Дополнительно перепроверены F4/F5 anchors: `MNT4OptimizationLadder.t.sol`, `MNT4Article640PairingModesGas.t.sol`, `MNT4Article640PcsVerifiers.t.sol`, `pcs_constraints`, `mnt_cycle_constraints`.

## F6C — MNT6 on-chain/article640 verifier, first implementation slice

Started `mnt6_article640_verifier/` as separate MNT6 module. Implemented and tested:

- `BigIntMNT6.sol` + `MNT6Fp.sol` for 3-limb Montgomery/CIOS arithmetic over `Fq(MNT6)=Fr(MNT4)`.
- `MNT6Fq3.sol` for `Fq3 = Fq[v]/(v^3 - 11)`.
- `MNT6Fq6.sol` for `Fq6 = Fq3[w]/(w^2 - v)`.
- `MNT6CurveChecks.sol` for G1/G2 curve membership.
- `MNT6AteLoop.sol` correctness-first prepared ate Miller formulas; first real double-step cross-checked with arkworks.
- `MNT6Article640DirectVerifier.sol` minimal residue component checking `c*cInv=1` and `c^r=F`.
- Rust backend `mnt6_article640_backend` generating parameters/vectors from `ark-mnt6-753`.

Fresh verification: `cd mnt6_article640_verifier && forge test -vv --gas-report` -> 7 passed, 0 failed. Key gas: first Miller double-step 343,559; residue relation accept path 891,709,634. F6C is not complete yet: full prepared line cache, full Miller equation, hot sparse path, full FE baseline, code-shards/blob variants and final gas table remain to implement.

## F6C gas diagnosis

User asked why current MNT6 prototype shows hundreds of millions / almost billion gas instead of MNT4-like numbers. Diagnosis: current `MNT6Article640DirectVerifier.verifyResidueRelation` is a correctness baseline that computes `c^r` by generic Fq6 exponentiation, so it is not the optimized article640 hot path. MNT6 also has objectively heavier target-field arithmetic: Fq6 = Fq3[w]/(w^2-v), Fq3 multiplication is more expensive than MNT4's Fq2 tower, and full Miller path has many Fq6 squares/mul-by-line operations. Expected final optimized MNT6 order after prepared sparse/hot path/residue/code-shards is likely tens-to-low-hundreds of millions gas, probably not as low as MNT4; exact value requires full implementation and measurement.

## 2026-05-28 — F6C MNT6 prepared full Miller loop
- In `mnt6_article640_verifier`, the Rust backend now emits the full MNT6 prepared G2 line cache from `ark-mnt6-753`: 376 double coefficients and 123 addition coefficients, plus the full arkworks Miller output.
- Solidity now supports packed prepared-cache execution for the full MNT6 ate Miller loop via calldata blob, memory blob, and an `EXTCODECOPY` code-blob benchmark path.
- Cross-check: `forge test --match-path test/MNT6FullMillerBlob.t.sol -vv --gas-report --gas-limit 3000000000` passes 3/3 and matches arkworks for the full Miller output.
- Gas result: full prepared MNT6 Miller loop is still extremely expensive: ~1.237B gas via calldata blob, ~1.284B via memory/code blob. This is a negative result for practical MNT6 on-chain verification, not an optimized final verifier.
- Implemented arithmetic improvements: Fq3 Karatsuba multiplication, specialized Fq3/Fq6 square, bitset ate-loop digits instead of rebuilding a 376-element array, and packed blob loaders.

## 2026-05-28 — MNT6 optimization audit
- Added `mnt6_article640_verifier/test/MNT6FieldGasBench.t.sol` for comparable MNT6 gas/op measurements.
- Fresh MNT6 gas/op: `Fp.mul` 2,367; `Fp.sqr` 2,355; `Fq3.mul` 36,525; `Fq3.sqr` 26,866; `Fq6.mul` 166,828; `Fq6.sqr` 113,842.
- Compared with MNT4: `Fp.mul` 2,959; `Fp.sqr` 2,947; `Fq2.mul` 11,877; `Fq2.sqr` 10,592; `Fq4.mul` 42,764; `Fq4.sqr` 36,606.
- Audit document: `mnt6_article640_verifier/docs/MNT6_OPTIMIZATION_AUDIT_RU.md`.
- Conclusion: MNT6 constants and arithmetic are correct, but MNT6 is not yet optimized to MNT4 low-level quality: missing pointer/scratch API and full fused hot path. However, even with those, Fq3/Fq6 tower and dense line coefficients make MNT6 structurally much more expensive than MNT4 in EVM.

## 2026-05-28: MNT6 optimization pass

MNT6 verifier path was optimized and re-tested in `/Users/a.i.semenov/mnt4-pairing-final/mnt6_article640_verifier`.

Implemented:
- `src/MNT6PackedArithmetic.sol`: pointer/packed `Fp/Fq3/Fq6` arithmetic with scratch arena.
- `MNT6AteLoop.millerLoopPreparedBlobPacked`: fused `f <- f^2 * line(P)` over packed arena, no intermediate `Fq3/Fq6 memory` structs in the hot loop.
- `MNT6AteLoop.millerLoopPreparedCodeStreaming`: streaming code-shards path that avoids copying the full 504 KB cache into memory.
- `MNT6Fq3.frobeniusMap`, `MNT6Fq6.frobeniusMap`, `MNT6Fq6.finalExponentiation`: MNT6 Frobenius/w0 final exponentiation matching arkworks.
- Rust fixture now includes `prepared.final_exp_blob` for FE cross-checking.

Verification:
- `forge test -vv --gas-report --gas-limit 3000000000` passes: 21 passed, 0 failed.
- Packed arithmetic matches struct path; packed Miller digest matches existing calldata Miller digest, which is separately checked against arkworks.
- Final exponentiation digest matches arkworks.

Gas highlights:
- Struct `Fq6.mul`: 166,828 gas/op; packed harness `Fq6.mul`: 91,885 gas/op.
- Struct calldata Miller loop: 1,240,030,325 gas.
- Packed pointer Miller loop digest: 93,718,469 gas in Foundry function gas report.
- Streaming code-shards digest: 1,288,660,958 gas, worse than calldata because repeated EXTCODECOPY/allocations dominate.
- MNT6 final exponentiation via Frobenius/w0: 218,385,141 gas.

Conclusion: MNT6 now has the missing low-level optimization layer. The best MNT6 Miller path is packed pointer/scratch, not struct or code-shards. The remaining high costs are structural: Fq3/Fq6 tower and final exponentiation over Fq6.

## 2026-05-28: MNT6 packed FE and Article640 residue remeasurement

Additional MNT6 optimization completed:
- Added `MNT6Fq6.finalExponentiationPacked`: Frobenius decomposition plus packed arena for the `w0` exponent.
- The `w0` exponent now uses precomputed NAF masks: 124 non-zero NAF digits instead of 175 binary one-bits.
- Added `finalExponentiationPackedDigest` and `pairingPreparedPackedFullDigestWithPackedFE` in `MNT6Article640DirectVerifier`.
- Added `pairingPreparedPackedResidueDigest`, an Article640-style residue-loop variant with `c,cInv` inserted into the loop.

Fresh verification command:
`forge test -vv --gas-report --gas-limit 3000000000`
Result: 25 passed, 0 failed.

Gas values:
- Packed Miller loop digest: 93,728,293 gas.
- Old struct Frobenius/w0 FE: 218,388,832 gas.
- Packed Frobenius/w0 + NAF FE: 38,905,291 gas.
- Full pairing with old FE: 312,658,675 gas.
- Full pairing with packed FE: 132,637,265 gas.
- Article640-style residue path: 103,663,480 gas.

Conclusion: Article640 FE replacement is effective for MNT6 too, saving about 29M gas versus packed full FE, but Miller loop still dominates at about 93.7M gas.

## 2026-05-29: MNT6 pointer-swap micro-optimization

Tested the remaining low-level idea: reduce `fq6CopyTo` by swapping result pointers in packed Miller loop and packed `w0` final exponentiation.

Fresh MNT6 verification:
`forge test -vv --gas-report --gas-limit 3000000000`
Result: 25 passed, 0 failed.

Gas after pointer-swap:
- Packed Miller loop digest: 93,254,054 gas (was 93,728,293).
- Packed FE: 38,428,108 gas (was 38,905,291).
- Full pairing with packed FE: 131,685,843 gas (was 132,637,265).
- Article640-style residue path на тот момент: 103,294,551 gas (was
  103,663,480). После исправления знака MNT6 relation актуальная метрика
  одиночного diagnostic digest равна `103,277,505 gas`.

MNT4 check:
- Article640 MNT4 already uses pointer-swap (`pF/pTmp`, `_fq4MulAndSwap`) in the hot path, so no analogous code change is needed there.
- Control run in `article640_mnt4_verifier`: `verifyEquationFixedQParametricSResidue` 93,881,355 gas; code-shards 93,685,247 gas.

## 2026-05-29 — Lollipop-305 stick + cycle audit/update

- Added Rust formal cycle layer for ePrint 2024/1627 `lollipop-305-158`: `field_q.rs`, `cycle.rs`, `cycle_relations.rs`.
- Verified relations: `p=x^2-x+1`, `q=x^2+1`, `#E_cycle(Fp2)=p^2+1=q*Nq`, `#Ehat_cycle(Fq2)=q^2-q+1=p*Np`, deterministic subgroup points satisfy `[q]P=O` and `[p]Q=O`.
- Added Solidity/Yul q-side arithmetic: `BigIntLollipop305Q.sol`, `Lollipop305QExtensionStack.sol`, `Lollipop305CycleQArithmetic.t.sol`.
- Fresh verification: Rust backend `cargo test` passed 19 tests; Foundry `forge test -vv --gas-report` in `lollipop305_research` passed 27 tests.
- Important limitation: full EVM verifier for the two supersingular cycle pairings (`E_cycle/Fp2` order-q target `Fp4`, `Ehat_cycle/Fq2` order-p target `Fq6`) is not yet implemented. Current L8 closes formal/arithmetic foundation and measured q-side EVM arithmetic, not complete production lollipop-cycle pairing verifier.

## 2026-05-29 — Self-contained deep-agent task for lollipop-305 pairing spec

Updated `/Users/a.i.semenov/mnt4-pairing-final/lollipop305_research/docs/DEEP_AGENT_LOLLIPOP305_SUPERSINGULAR_PAIRING_EQUATION_TASK_RU.md` so it no longer assumes code access. The document now includes the full mathematical/project context, lollipop-305 parameters, curve equations, verified relations, current failed `E_cycle/Fp2` Miller/final-exponent attempt, required direct/residue formulas, expected Rust/Solidity verifier algorithms, constraints model, test plan, and a strict output format for the deep agent.

## 2026-05-29 — L9 independent lollipop supersingular pairing research

Added `/Users/a.i.semenov/mnt4-pairing-final/lollipop305_research/docs/L9_SUPERSINGULAR_PAIRING_RESEARCH_RU.md`. Main conclusion: the current `E_cycle/Fp2` failing final exponentiation is expected because the attempt paired points from the same rational `q`-subgroup. To continue, implement correct supersingular `G1/G2` separation via distortion/Frobenius maps. For `E_cycle/Fp2`, use a map of the form `psi_E(x,y)=(theta^2*x^p, theta^3*y^p)` with `theta^4=(1+mu)/(1-mu)=mu`, so `psi_E` maps the `+1` eigenspace under `p^2`-Frobenius to the independent `-1` eigenspace in `Fp4`. For `Ehat_cycle/Fq2`, derive and implement an analogous `j=0` map with `theta^6=(2+eta)/(2-eta)` in `Fq6` before porting to Solidity.

## 2026-05-29 — Lollipop E_cycle verifier implemented, Ehat blocker isolated

Implemented the corrected distorted `E_cycle/Fp2` Article640-style path. Rust now constructs `P in E(Fp2)[q]`, `Q=psi_E(Q_raw) in E(Fp4)[q]` with `psi_E(x,y)=(theta^2*x^p,theta^3*y^p)` and `theta^4=mu`; the fixture satisfies direct FE and residue checks. Added binary/hex fixtures and Solidity entrypoints `verifyCycleEDirectFinalExponent` and `verifyCycleEResidue`.

Verification:
- `cargo test -q` in `lollipop305_research/rust_backend`: passed; 2 tests ignored (old invalid cycle-E attempt and Ehat blocker).
- `forge test -vv --gas-report` in `lollipop305_research`: 35 passed, 0 failed.

Gas highlights for corrected `E_cycle/Fp2`:
- test-call Miller core: 19,143,725 gas; gas-report function max 11,444,466.
- test-call direct FE: 42,015,185 gas; gas-report function 34,070,641.
- test-call residue FE: 26,259,779 gas; gas-report function max 18,280,049.

Started `Ehat/Fq2 -> Fq6` Rust layer with `Fq6=Fq2[w]/(w^3-rho)`, `rho^2=(2+eta)/(2-eta)` and `psi_Ehat(x,y)=(w^2*x^q,w^3*y^q)`. The map lands on the curve, but naive Tate-style product does not satisfy direct FE, so Ehat remains a mathematical blocker rather than a finished verifier.

## 2026-05-29 — Ehat mathematical blocker resolved as Weil relation

Completed the remaining mathematical investigation for `Ehat_cycle/Fq2`. The naive Tate-style `F=f_{p,Q}(P)f_{p,Q}(-P)`, `F^((q^6-1)/p)=1` relation is incorrect for the current Ehat setup. The correct direction is Weil pairing: `e_p(P,Q)=(-1)^p f_{p,P}(Q)/f_{p,Q}(P)`. Rust probes confirmed `e != 1`, `e^p=1`, and `e(P,Q)e(-P,Q)=1` for `P in Ehat(Fq2)[p]` and `Q=psi_Ehat(Q_raw) in Ehat(Fq6)[p]`. Added `/Users/a.i.semenov/mnt4-pairing-final/lollipop305_research/docs/L10_EHAT_WEIL_PAIRING_FORMAL_RESULT_RU.md` with formulas and next implementation requirements.

## 2026-05-29 — Lollipop Ehat Weil relation promoted to tested code

Closed the remaining mathematical step for the lollipop-305 `Ehat_cycle/Fq2` side in code, not only in notes. Added library functions in `lollipop305_research/rust_backend/src/cycle_pairing.rs` for the full-denominator Miller function on `Ehat/Fq6`, the Weil pairing representation `e_p(P,Q)=f_{p,P}(Q)/f_{p,Q}(P)`, and a structured check of the relation. Added the ordinary Rust test `cycle_ehat_weil_pairing_relation_is_nontrivial_and_correct`.

Fresh verification:
`cargo test -q` in `lollipop305_research/rust_backend` passed. The relevant suite reports 3 passed, 2 ignored; the ignored tests are old invalid Tate-style experiments kept as documentation of rejected paths.

Mathematical status: `E_cycle/Fp2` remains Article640/Tate-residue style; `Ehat/Fq2` is Weil-equation style. Remaining lollipop work is now engineering: port the `Ehat` Weil verifier to Solidity/Yul and measure gas.

## 2026-05-29 — Full lollipop-305 implementation completed as research pipeline

Completed the lollipop-305 research pipeline in `/Users/a.i.semenov/mnt4-pairing-final/lollipop305_research`:
- Added `Fq6` Solidity arithmetic over `Fq2[w]/(w^3-rho)` with Karatsuba multiplication in `src/Lollipop305QExtensionStack.sol`.
- Added `verifyEhatWeilEquation(...)` to `src/Lollipop305Article640Verifier.sol` for the relation `f_{p,P}(Q)f_{p,-P}(Q)=f_{p,Q}(P)f_{p,Q}(-P)`.
- Added Rust fixture generator `rust_backend/src/bin/lollipop305_cycle_ehat_weil_fixture.rs` and binary/hex fixtures in `docs/lollipop305_cycle_ehat_weil_fixture.words.*`.
- Added Foundry tests in `test/Lollipop305EhatWeilVerifier.t.sol`.
- Added final report `docs/L11_FULL_LOLLIPOP_IMPLEMENTATION_REPORT_RU.md`.

Fresh verification:
- Rust: `cargo test -q` in `lollipop305_research/rust_backend` passed, 0 failed.
- Foundry: `forge test -vv --gas-report --gas-limit 3000000000` in `lollipop305_research` passed 38 tests, 0 failed.

Gas highlights after Fq6 Karatsuba:
- stick residue: 8,671,771 function gas; 12,647,052 test-call gas.
- E_cycle residue: 18,283,781 function gas; 26,263,511 test-call gas.
- Ehat Weil equation: 200,567,235 function gas; 247,140,135 test-call gas.
- Full lollipop-cycle sum: 227,522,787 function gas; 286,050,698 test-call gas.

Conclusion: lollipop-305 has cheaper 2-limb arithmetic, but full direct EVM lollipop-cycle verification is dominated by Ehat/Fq6 Weil equation requiring four Miller traces. It is valuable research evidence, not a practical replacement for optimized MNT4/MNT6 article640 verifier modes.

## 2026-05-29 — Deep-agent task for lollipop Ehat Tate/ate research

Created `/Users/a.i.semenov/mnt4-pairing-final/lollipop305_research/docs/DEEP_AGENT_LOLLIPOP305_EHAT_TATE_ATE_RESEARCH_TASK_RU.md`. The task is self-contained for an agent without code access. It asks to determine whether `Ehat/Fq2` in lollipop-305 can be implemented via reduced Tate/ate-style verifier with prepared lines and residue-check, analogous to MNT4/MNT6 article640 paths, instead of the current expensive Weil-ratio fallback. It includes all lollipop-305 parameters, curve equations, known distortion map, current gas issue, required formulas, denominator-elimination distinction, test requirements, and a warning to use fast Rust/Sage/Magma rather than slow Python for arithmetic checks.

## 2026-05-29 — FINAL_DIPLOMA_COMPLETION_PLAN updated through F7

Updated `/Users/a.i.semenov/mnt4-pairing-final/docs/FINAL_DIPLOMA_COMPLETION_PLAN_RU.md` to reflect current reality before starting F8:
- F1/F2 arithmetic audits are marked closed with links to final 3-limb and 2-limb audit docs.
- F3 naive Tate baseline and F4 optimization ladder are marked closed.
- F5 Article640 MNT4 direct residue + KZG/Merkle-FRI trade-off is marked closed for MNT4.
- F6/F6B/F6C now include the MNT4/MNT6 cycle-native layer and full MNT6 on-chain/article640 research verifier, including MNT6 packed/pointer arithmetic, prepared Miller loop, packed Frobenius/w0 FE, and residue path.
- F7 lollipop-305 is marked closed as a full-cycle research prototype: stick + E_cycle + Ehat prepared-Ate/residue. Latest lollipop Foundry verification: `forge test -vv --gas-report --gas-limit 3000000000` passed 43 tests. Best full lollipop-cycle function-level estimate: ~133.5M gas, with Ehat prepared-Ate + residue at 106,441,661 gas.
- Next planned step is F8: final negative/boundary result explaining why no current path gives simultaneously low gas and low constraints without new precompile/PCS/proof-system support.

## 2026-05-29 — F8 final negative/boundary report created

Added `/Users/a.i.semenov/mnt4-pairing-final/docs/FINAL_NEGATIVE_AND_BOUNDARY_RESULTS_RU.md`. The report consolidates F1-F7 into a single final boundary result: on-chain MNT arithmetic is gas-heavy; BN254/KZG compression is constraints-heavy due to non-native MNT4 arithmetic; Merkle/FRI moves cost into calldata; lollipop-305 improves 2-limb arithmetic but full direct EVM lollipop-cycle remains ~133.5M gas because Ehat/Fq2->Fq6 dominates and k=3 prevents denominator elimination. The report includes economic formulas for gas cost and prover/constraint cost, with scenario tables.

## 2026-05-31 — clean delivery: отделение research-вариантов и редакторский рефакторинг

В чистовой директории `/Users/a.i.semenov/diploma-final` выполнено физическое разделение production-кода и исследовательских сравнений.

- В `arithmetic/mnt4_3limb/src` оставлены только общие чистовые библиотеки `BigIntMNT.sol` и `MNT4Extension.sol`.
- Barrett, FIOS, Comba/SOS, branchless reduction, skip-t0 и варианты арифметики расширений перенесены в `arithmetic/mnt4_3limb/research_variants`.
- В `arithmetic/lollipop305_2limb/src` оставлены чистовые 2-limb библиотеки и stack API. Альтернативы branchless/skip-t0/small-high и структурная арифметика расширений перенесены в `arithmetic/lollipop305_2limb/research_variants`.
- Удалены неиспользуемые ранние MNT4-оболочки и дублирующая копия pairing-библиотеки из арифметического модуля. Pairing-специфичные тесты перенесены в `implementations/full_onchain_mnt4/test`.
- Тестовые типы Article640 вынесены в `arithmetic/mnt4_3limb/test_support`.
- Во всех Solidity-файлах production и research дерева добавлены русские пояснения к контрактам, функциям и константам. Для двух research-директорий добавлены `README_RU.md`.
- Обновлены `README.md` и `docs/FINAL_DELIVERY_OVERVIEW_RU.md`.

Проверка:

```bash
cd /Users/a.i.semenov/diploma-final
./scripts/run_all.sh
./scripts/run_naive_tate.sh
```

Полный прогон завершен с кодом `0`. Ключевые runtime gas-метрики совпадают с логом до рефакторинга:

- Article640 MNT4 fixed-shards residue: первоначально `93,705,233 gas`,
  после добавления проверки G1 - `93,734,789 function gas`;
- Article640 MNT4 calldata+commitment residue: `93,974,409 gas`;
- MNT6 packed residue на момент прогона: `103,294,551 gas`; актуальный
  одиночный diagnostic digest после исправления знака: `103,277,505 gas`;
- lollipop-305 Ehat ate residue max: `106,457,927 gas`;
- MNT4 prepared sparse blob: `79,726,321 gas`;
- MNT4 prepared sparse code-shards: `80,140,929 gas`.
## 2026-05-31: fixed-cache режимы lollipop-305

- Для трех частей lollipop pipeline добавлена безопасная привязка подготовленных линий.
- Основной путь: `implementations/lollipop305/src/Lollipop305FixedShardsVerifier.sol`.
  Он фиксирует адреса data-контрактов в конструкторе и читает runtime-код через
  `EXTCODECOPY`; пользователь не передает blob или адреса shards в verify-вызове.
- Исследовательский вариант сравнения:
  `implementations/lollipop305/research_variants/Lollipop305CommittedCacheVerifier.sol`.
  Он принимает blob в calldata и сверяет доменно-разделенный commitment.
- Оба режима используют те же внутренние residue-пути арифметического ядра:
  stick `F=c^r`, `E_cycle` `F=c^q`, `Ehat` `c^p * F_den = F_num`.
- Сравнение трех частей: fixed code-shards добавляет `48,261 gas` execution
  overhead, но экономит `2,314,092 gas` calldata. Итоговая экономия около
  `2,265,831 gas`.
- Подробности и команды: `implementations/lollipop305/docs/L12_CACHE_BINDING_MODES_RU.md`.

## 2026-05-31: план полного аудита практической части

- Подготовлен `docs/PRACTICAL_IMPLEMENTATION_FULL_AUDIT_PLAN_RU.md`.
- Следующий шаг: выполнить независимый аудит всей финальной директории без
  преждевременных исправлений production-кода.
- Ключевое правило аудита: раздельно маркировать исполняемую реализацию,
  аналитическую operation/constraint модель и будущую работу.
- Зоны повышенного внимания: фактический статус `mnt_cycle_full`, сопоставимость
  constraints с Sonobe/CycleFold, constraints-анализ полного lollipop-цикла,
  fixed-cache безопасность и воспроизводимость Rust fixtures.

## 2026-05-31: задание на полную формализацию Merkle/FRI-проверки MNT4

- Подготовлен `docs/DEEP_AGENT_MNT4_MERKLE_FRI_FULL_FORMALIZATION_TASK_RU.md`.
- Документ передается агенту вместе с
  `docs/MNT4_MERKLE_FRI_POLYNOMIAL_MILLER_SPEC_RU.md`.
- Текущая Merkle/FRI-спецификация считается проектом, а не завершенным
  криптографическим протоколом. Агент обязан независимо проверить recurrence,
  fixed divisor tables, transcript, FRI domain, soundness, бинарный формат
  proof и gas-модель.
- После получения ответа следующий шаг: проверить его по чек-листу из раздела
  `Критерии готовности исследования`. Реализацию начинать только при отсутствии
  открытых математических и криптографических вопросов.
- В задание явно добавлено требование неинтерактивности: Rust backend формирует
  один `proof.bin`, Solidity verifier проверяет его в одном вызове и
  самостоятельно восстанавливает все challenges через Fiat--Shamir transcript.

## 2026-05-31: аудит первого ответа deep agent по Merkle/FRI

- Проверен `/Users/a.i.semenov/Downloads/MNT4_MERKLE_FRI_FULL_FORMALIZATION.md`.
- Ответ полезен как исследовательский эскиз, но недостаточен для реализации:
  смешаны обычный FRI и DEEP-FRI, batching не доказывает разные degree bounds
  trace и quotient столбцов, quotient soundness оценен по размеру всего поля
  вместо sampled LDE-домена, FRI folding schedule противоречит финальной
  степени, fixed divisor tables и `proof.bin` недоопределены.
- Подготовлено задание на доработку:
  `docs/DEEP_AGENT_MNT4_MERKLE_FRI_REWORK_REQUEST_RU.md`.
- Реализацию Merkle/FRI production verifier-а начинать только после повторной
  проверки исправленного исследования.

## 2026-05-31: аудит версии 2.0 Merkle/DEEP-FRI исследования

- Проверен
  `/Users/a.i.semenov/Downloads/MNT4_MERKLE_FRI_FULL_FORMALIZATION (1).md`.
- Версия 2.0 существенно лучше, но все еще не готова для реализации.
- Главные блокеры: заявленный DEEP-FRI заменяется в gas-модели обычным
  batched polynomial; quotient по `Z` вычисляется verifier-ом и делает
  локальную проверку тождественной; блочный prepared divisor ошибочно
  считается линейным по координатам `P`; `root_fixed` не связан с OOD
  evaluations; `proof.bin` не содержит связанных openings для `x` и `-x`
  первого FRI fold; gas `24.7M` пока не воспроизводим.
- Подготовлено второе задание на доработку:
  `docs/DEEP_AGENT_MNT4_MERKLE_FRI_REWORK_V2_RU.md`.

## 2026-05-31: аудит версии 3.0 Merkle/DEEP-FRI исследования

- Проверен
  `/Users/a.i.semenov/Downloads/MNT4_MERKLE_FRI_FULL_FORMALIZATION (2).md`.
- Версия 3.0 исправила часть прежних замечаний: scalar quotient, координатные
  constraints `Fq4`, openings в `x` и `-x`, явный DEEP-полином и попытка
  описать `c^kappa`.
- Реализацию начинать нельзя. AIR блока все еще не доказывает внутренние
  line multiplications; fixed oracle противоречив; формат prepared-линий не
  совпадает с `arkworks` и чистовым sparse-форматом проекта; transcript FRI
  циклический; `c^kappa` не включен в реальную трассу; оценка `17.1M gas`
  остается эвристической.
- Отдельно подтверждено по `arkworks`: doubling coefficients MNT4 имеют
  четыре `Fp2` компоненты (`c_h`, `c_4c`, `c_j`, `c_l`), addition coefficients
  две `Fp2` компоненты (`c_l1`, `c_rz`). Чистовая Solidity/Yul-сериализация
  проекта хранит `3 * Fq2 = 576` байт на doubling step и
  `2 * Fq2 = 384` байт на addition step.
- Подготовлено третье задание на доработку:
  `docs/DEEP_AGENT_MNT4_MERKLE_FRI_REWORK_V3_RU.md`.

## 2026-05-31: исправленная спецификация Merkle/DEEP-FRI микротрассы

- По запросу пользователя вместо очередной передачи задачи deep agent
  самостоятельно подготовлена реализационная спецификация:
  `docs/MNT4_MERKLE_DEEP_FRI_MICROTRACE_SPEC_RU.md`.
- Выбран прозрачный эталон без пятишагового блочного сжатия: одна строка AIR
  соответствует одной реальной операции residue-рекурсии над `Fq4`.
- Точная длина: `1500` микроопераций, trace domain `2048`, LDE-domain
  `32768`. После последней реальной операции используются финальная строка,
  `547` HOLD-переходов и STOP-строка без wrap-перехода.
- Fixed oracle содержит `17` столбцов и только данные, не зависящие от
  пользовательских `P,R`. Prepared lines нормализуются из реального
  arkworks/Solidity sparse-формата: doubling `3 * Fq2`, addition `2 * Fq2`.
- Устранены прежние разрывы: нет агрегированных `GQ(P)` в fixed tree,
  `rootFixed` связывается с OOD через DEEP-полином, FRI transcript не имеет
  циклической зависимости, bytecode не содержит таблицу размером больше
  EIP-170 limit.
- Определены два профиля: `benchmark-32q` для gas-эксперимента и
  `conservative-128q` для консервативной проверки. Итоговый security bound обязан
  вычисляться Rust-модулем `security.rs`; неподтвержденная формула
  `(2*rho)^(R*lambda)` не используется.
- При самопроверке спецификации добавлены отсутствовавшие проверяемые
  инверсии: четыре знаменателя DEEP-проверки и `x^{-1}` для FRI-folding.
  Размер одного query с независимыми путями равен `9604` байтам; calldata
  верхняя оценка для `benchmark-32q` с публичными входами равна
  `4,994,816 gas`. Фактический multiproof обязан быть меньше.
- Отдельно формализована residue-рекурсия: целочисленный показатель
  `kappa_final` для зафиксированного ate-loop равен `-r`, поэтому финальная
  строка проверяет `Miller(P,Q,-R,S) * c^(-r) = 1`. Обратная импликация
  следует из `gcd(r, (q^4 - 1) / r) = 1`.
- Для исключения расхождений Rust/Solidity зафиксированы: каноническая
  big-endian сериализация `Fq`, точные domain separators Merkle-деревьев,
  точная Fiat--Shamir цепочка, `configDigest` и детерминированная выборка
  уникальных query indices.
- После повторного аудита proof layout независимые Merkle-пути заменены
  детерминированным компактным multiproof: набор раскрываемых листьев и
  frontier-вершин выводится verifier-ом из Fiat--Shamir queries, каждый
  frontier-хеш передается не более одного раза на дерево. Старые размеры
  `311,024` и `1,233,008` байт сохранены только как верхние оценки через
  независимые пути; фактический размер сохраняется Rust backend-ом.
- Дополнительно зафиксированы проверка параметров домена, trusted-config
  граница для фиксированных `Q,S`, точный порядок `44` AIR constraints и
  пошаговый алгоритм проверки одного FRI-query.
- Домен строится детерминированно из генератора arkworks `g = 17`:
  `eta = g^((q - 1) / 32768)`, `omega = eta^16`, `gamma = g`. Численно
  проверены порядки `eta`, `omega` и условие `gamma^32768 != 1`.
- Итоговая спецификация является готовой основой для экспериментальной
  реализации и измерения gas, но не объявляется production-verifier-ом:
  криптографическая интерпретация профилей фиксируется только после
  генерации `security_report.json`.
- В спецификацию добавлен раздел 1.1 с явным сопоставлением со старым
  `MNT4_MERKLE_FRI_POLYNOMIAL_MILLER_SPEC_RU.md`: общая идея остается той
  же, но недоопределенное пятишаговое блочное сжатие заменено прозрачной
  микротрассой `one AIR row = one residue micro-operation`. Зафиксированы
  все Merkle roots и разделение ролей: quotient relation проверяет AIR,
  multiproof связывает открытия с таблицами, DEEP-FRI доказывает низкую
  степень.
- Добавлена design-запись:
  `docs/superpowers/specs/2026-05-31-mnt4-merkle-deep-fri-microtrace-design.md`.

## 2026-05-31: завершенная экспериментальная реализация Merkle/DEEP-FRI микротрассы

- Создан изолированный модуль:
  `implementations/research_variants/mnt4_merkle_deep_fri_microtrace`.
  Исходный модуль `implementations/article640_mnt4` не изменялся и используется
  как baseline.
- Rust backend реализует весь воспроизводимый pipeline:
  `1500` реальных микроопераций residue-рекурсии, дополнение трассы до `2048`
  строк, LDE размера `32768`, quotient, Merkle-деревья, компактные
  multiproof, Fiat--Shamir transcript, DEEP-значения, `8` FRI-folding раундов,
  сериализацию и самопроверку `proof.bin`.
- Solidity-контракт
  `implementations/research_variants/mnt4_merkle_deep_fri_microtrace/src/MNT4MerkleDeepFriVerifier.sol`
  предоставляет метод
  `verifyEquationMicrotrace(P, R, c, cInv, proof)`.
  Он проверяет принадлежность точек кривой, `c * cInv = 1`, transcript,
  OOD-равенство, Merkle-multiproof, DEEP-значения и FRI-folding. Proof читается
  непосредственно из `bytes calldata`.
- Зафиксированы два экспериментальных профиля:
  `benchmark-32q` и `conservative-128q`. Они предназначены для измерения
  компромисса, а не объявляются production-стойкими без независимого анализа
  soundness.
- Сохраненные Rust-метрики:
  `benchmark-32q`: proof `263612` байт, worst-case calldata `4236224 gas`,
  генерация `9295 ms`, peak RSS `232030208` байт;
  `conservative-128q`: proof `953468` байт, worst-case calldata
  `15273920 gas`, генерация `8537 ms`, peak RSS `236077056` байт.
- Проверены Rust unit-тесты: `9 passed; 0 failed`.
  Проверены Solidity acceptance/rejection тесты: `21 passed; 0 failed`.
  Негативные тесты изменяют точки, `c`, `cInv`, конфигурацию, OOD bundle,
  финальный многочлен, листья и корни Merkle-деревьев, DEEP-инверсии и
  frontier-хеши.
- Fresh gas-сравнение метода контракта:
  Article640 fixed-shards residue baseline после проверки G1
  `93734789 function gas`;
  Merkle/DEEP-FRI `benchmark-32q` `83962252 gas`;
  Merkle/DEEP-FRI `conservative-128q` `640161168 gas`.
  После добавления верхней оценки calldata benchmark-профиль дает
  `88198476 gas`, то есть выигрыш около `5.9%` относительно Article640
  baseline. Консервативный профиль существенно дороже baseline.
- Обнаружено важное ограничение развертывания:
  runtime-код `MNT4MerkleDeepFriVerifier` занимает `27825` байт даже при
  `optimizer_runs=1`, что выше EIP-170 limit `24576` байт. Экспериментальная
  реализация завершена для корректного сравнения подходов, но не является
  готовым монолитным Ethereum mainnet-контрактом без разбиения или сокращения
  bytecode.
- Единый воспроизводимый запуск:
  `implementations/research_variants/mnt4_merkle_deep_fri_microtrace/scripts/run_report.sh`.
  Подробный отчет:
  `implementations/research_variants/mnt4_merkle_deep_fri_microtrace/docs/MNT4_MERKLE_DEEP_FRI_RESULTS_RU.md`.

## 2026-05-31: независимый аудит стоимости Merkle/DEEP-FRI микротрассы

- Проведен повторный аудит после вопроса пользователя о неожиданно высоком
  gas. Итог: модуль корректно реализует заявленный `microtrace reference
  baseline`, но не является финальной оптимальной реализацией Merkle/FRI-пути.
- Текущий контракт действительно проверяет quotient relation в случайной
  OOD-точке и DEEP-FRI доказательство низкой степени. Высокая стоимость не
  означает, что он повторно исполняет весь цикл Миллера.
- Для `benchmark-32q` proof размером `263612` байт состоит в том числе из:
  fixed openings `104448` байт, frontier hashes `61728` байт, FRI openings
  `41472` байт, trace openings `24576` байт.
- Только видимый поднабор DEEP/folding арифметики содержит около `6880`
  умножений в `Fq`; при измеренных `2959 gas/op` это около `20.36M gas` до
  учета конверсий, Merkle-проверки, памяти и служебной логики.
- Найдены устранимые расходы Solidity reference verifier-а:
  линейный `_findPosition`, insertion sort, копирования `calldata -> memory`,
  динамические массивы на каждом уровне Merkle, `abi.encodePacked` в hot path,
  повторные Montgomery-конверсии и вычисления степеней.
- Рост `32q -> 128q` составляет `83.96M -> 640.16M gas`, то есть `7.62x`
  вместо ожидаемого линейного `4x`; это подтверждает наличие сверхлинейных
  расходов.
- Важный незакрытый пункт: `security_report.json` пока не содержит численной
  soundness-оценки по конкретной теореме DEEP-FRI. Поэтому нельзя объявлять ни
  `32q`, ни `128q` минимальным production-профилем.
- Первоначальная спецификация
  `docs/MNT4_MERKLE_FRI_POLYNOMIAL_MILLER_SPEC_RU.md` предусматривала более
  агрессивное сжатие: пять раундов в блок, `76` реальных блоков, trace domain
  `128`, подстановку `zeta` в `Fq4 = Fq[Z]/(Z^4-13)` и base-field relation
  checks. Эта схема еще не реализована.
- Создан отчет:
  `implementations/research_variants/mnt4_merkle_deep_fri_microtrace/docs/MNT4_MERKLE_DEEP_FRI_INDEPENDENT_AUDIT_RU.md`.
- Дополнительное уточнение после сверки с оригинальной статьей ePrint
  `2024/640`: для защиты от подмены witness обязательна не конкретно
  DEEP-FRI-проверка полной временной микротрассы, а доказательство того, что
  значения в случайном полиномиальном равенстве являются openings заранее
  зафиксированных низкостепенных полиномов. Это может быть KZG/PCS,
  Merkle+FRI, рекурсивное доказательство или иной протокол с явно заданной
  моделью доверия. Текущий microtrace-модуль выбрал корректную, но
  перегруженную STARK-подобную EVM-инстанциацию.

## 2026-06-01: обычный FRI против DEEP-FRI для MNT4 polynomial verifier

- Для минимальной прозрачной реализации достаточно `Merkle + ordinary FRI`,
  если формально определены code rate, LDE domain, число folding-раундов,
  число независимых запросов и вычислена итоговая soundness-оценка.
- `DEEP-FRI` не меняет проверяемое MNT4-отношение. Он добавляет sampling outside
  evaluation domain и DEEP-композицию, чтобы улучшить soundness low-degree
  testing. Это может позволить уменьшить число запросов, сохранив целевой
  уровень надежности.
- В текущем microtrace verifier DEEP-слой добавляет OOD bundle, пять инверсий
  на запрос и вычисление DEEP-значений. Для `benchmark-32q` только видимый
  DEEP/folding поднабор содержит около `6880` умножений `Fq`.
- Для EVM нельзя заранее объявить обычный FRI дешевле при одинаковой
  надежности: удаление DEEP-арифметики снижает стоимость одного запроса, но
  обычному FRI может понадобиться больше запросов. Требуется сравнение двух
  профилей с численной soundness-моделью.
- Рекомендуемый следующий вариант: отдельный block-compressed verifier с
  трассовым доменом `128`, сначала `Merkle + ordinary FRI` как минимальный
  прозрачный baseline; затем опциональный `DEEP-FRI` профиль для измерения
  trade-off `дополнительная арифметика vs меньше запросов`.
## 2026-06-01: выбор между обычным FRI и DEEP-FRI для MNT4 polynomial Miller verifier

- Для замены on-chain исполнения цикла Миллера недостаточно Merkle-коммитмента: он связывает verifier с таблицей значений, но сам по себе не доказывает, что таблица является вычислением многочлена ограниченной степени.
- Обычный FRI является достаточным прозрачным механизмом доказательства близости таблицы к коду Рида-Соломона, если формально зафиксированы домен, степень, коэффициент расширения домена, число запросов и численная верхняя граница вероятности принятия некорректного доказательства.
- DEEP-FRI не проверяет новое математическое утверждение о цикле Миллера. Он добавляет раскрытие в точке вне исходного домена и улучшает надежность проверки близости к низкостепенному многочлену. Это может уменьшить требуемое число запросов, но добавляет OOD-значения, инверсии и дополнительную арифметику verifier-а.
- Для EVM нельзя заранее считать DEEP-FRI более дешевым: экономию на числе Merkle-раскрытий нужно сравнивать с дополнительной арифметикой над трехсловным полем MNT4-753.
- Следующая целевая реализация: block-compressed Merkle + обычный FRI. Один блок объединяет несколько шагов Миллера; relation проверяется через конкретные многочленные тождества, а FRI подтверждает низкую степень закоммиченных таблиц. После реализации необходимо добавить численную soundness-оценку и сравнить gas с опциональным DEEP-FRI-профилем.
- Текущий модуль `implementations/research_variants/mnt4_merkle_deep_fri_microtrace` сохраняется как reference baseline микротрассы, но не считается оптимальной production-реализацией.

## 2026-06-01: строгий production-профиль обычного FRI

- Пользователь подтвердил требование: основной профиль обычного FRI должен иметь доказанную надежность не хуже `2^-128`; более дешевые профили допустимы только как сравнительные benchmark-профили.
- Для сжатой MNT4-трассы используются: `76` реальных блоков по `5` шагов Миллера, дополнение до `N_trace = 128`, расширенный домен `N_LDE = 2048`, верхняя граница степени `deg <= 253`, скорость RS-кода `rho = 254 / 2048`.
- Упрощенная запись `(1/16)^64 = 2^-256` из прежней спецификации не является достаточным доказательством soundness FRI и не должна использоваться как финальное обоснование.
- Для smooth multiplicative RS-кодов применима доказанная оценка исходной статьи FRI: вероятность отклонения слова, достаточно далекого от кода, за одно повторение не меньше `delta0 >= (1 - 3*rho)/4 - 1/sqrt(N) - 3N/|F|`.
- Для текущих параметров получается `delta0 ~= 0.1348853`. По консервативной оценке `(1 - delta0)^q <= 2^-128` требуется минимум `613` независимых повторений. Основной production-профиль следует округлить до `640` запросов. Профиль `64q` можно оставить только для исследовательского gas-сравнения.
- Планируемая соседняя реализация: `implementations/mnt4_merkle_fri_cost_model`. Она не изменяет существующий DEEP-FRI baseline.
- Обозначение `m` в оценке обычного FRI означает число независимых случайных FRI-запросов, также называемое числом повторений проверки. Это не число шагов Миллера и не число блочных переходов. Для ясности в коде и документации следует использовать имя `query_count`.

## 2026-06-01: блокирующий пробел block-compressed ordinary-FRI схемы

- После согласования архитектуры и перед написанием кода проведена повторная проверка формализации. Формула сжатия пяти переходов корректна, но текущая спецификация не задает безопасный компактный способ связать агрегированные делители `G_t^Q(P)` и `G_t^S(-R)` с фиксированными `Q,S` и входными `P,R`.
- Нельзя принимать агрегированные делители как произвольные динамические openings: prover сможет подобрать множитель, превращающий ложный переход в истинный. Merkle-root фиксирует выбранную таблицу, но не доказывает происхождение значений.
- Наивное раскрытие всех коэффициентов подготовленного делителя и вычисление значения on-chain также неприемлемо: для блока `d=5` число коэффициентов имеет порядок до `2^(d+2)+1 = 129`, а production-профиль ordinary FRI требует `query_count = 640`.
- Создан честный статус-модуль `implementations/mnt4_merkle_fri_cost_model` без фиктивной реализации. Подробности: `implementations/mnt4_merkle_fri_cost_model/docs/BLOCK_COMPRESSED_FRI_FORMALIZATION_GAP_RU.md`.
- Перед кодом требуется выбрать и формализовать один из вариантов:
  1. обычный FRI поверх уже определенной пошаговой трассы;
  2. полноценная схема сжатых делителей `g_t(x,y)=a_t(x)+y*b_t(x)` с конкретным opening layer, low-degree proof и полной оценкой calldata/gas.

## 2026-06-01: формализация block-compressed ordinary-FRI с трассой Горнера

- Вариант со сжатыми делителями формализован в `implementations/mnt4_merkle_fri_cost_model/docs/MNT4_BLOCK_COMPRESSED_ORDINARY_FRI_FORMAL_SPEC_RU.md`.
- Для фиксированных `Q,S` Rust-индексатор однократно строит канонические делители блоков:
  `g_b^U(x,y) = a_b^U(x) + y*b_b^U(x)`, `U in {Q,S}`.
  Каждый делитель равен произведению реальных линий пяти шагов с весами `16,8,4,2,1`, редуцированному по уравнению кривой.
- Чтобы prover не мог передать произвольное значение делителя, добавлена проверяемая трасса Горнера. За один шаг одновременно обновляются четыре полинома:
  `aQ(Px)`, `bQ(Px)`, `aS(Rx)`, `bS(Rx)`.
  Значения `GQ(P)=aQ(Px)+Py*bQ(Px)` и `GS(-R)=aS(Rx)-Ry*bS(Rx)` выводятся из проверенных аккумуляторов.
- Учитывается ограничение поля: `v2(q-1)=15`, максимальный двоичный домен `32768`. Поэтому Horner-трасса из `5016` реальных строк делится на три сегмента по `2048` строк с LDE `32768`; два межсегментных перехода проверяются отдельно.
- После challenge `zeta` расширенная арифметика терминального перехода сводится к скалярным столбцам `u1..u5,vQ,vS` над `Fq`. После challenge `beta` восемь extension-relations объединяются одним `jMix`; отдельные `j1..j8` не передаются.
- Формальная схема корректна. Для сегмента `2048` композиционный полином имеет степень не выше `6141`, quotient - не выше `4093`, требуемая FRI degree bound строго меньше `4094`. Для применения доказанной теоремы используется стандартная RS-оболочка со скоростью `rho = 4096 / 32768 = 1/8`.
- Доказанная FRI-оценка дает `delta0 ~= 0.1507257`; минимум для `2^-128` равен `544` запросам. Production-профиль выбран с запасом: `query_count = 576`, что дает более `135 bit` для FRI-части оценки.
- Предварительная нижняя оценка показывает вероятный отрицательный gas-результат: минимальное первичное раскрытие трех сегментов содержит не менее `156` элементов `Fq`, то есть `14,976` байт. При `576` запросах это не менее `8,626,176` байт и до `138,018,816 gas` только calldata, без соседних раскрытий, Merkle frontier и FRI-слоев.
- Следующий обязательный этап: Rust-прототип и точная stop/go модель стоимости до написания Solidity verifier-а.

## 2026-06-01: исследование упрощения Merkle/FRI verifier-а

- Создан документ:
  `implementations/mnt4_merkle_fri_cost_model/docs/MNT4_MERKLE_FRI_SIMPLIFICATION_STUDY_RU.md`.
- Формально доказать непрактичность всего класса `Merkle + FRI` нельзя.
  Отрицательный результат относится к прежней row-major трассе Горнера: ее
  calldata lower bound равен `138,018,816 gas` без FRI-слоев, Merkle-frontier
  и исполнения арифметики, то есть она заведомо проигрывает Article640
  fixed-shards verifier-у примерно за `93.9M gas`.
- Проверенный путь к упрощению найден в ePrint `2024/640`, раздел
  `Efficient Polynomial Evaluation`: коэффициенты конкатенируются в один
  полином `C(T)`, вычисление Горнера задается столбцом `E_xi(T)`, а verifier
  открывает постоянное число значений
  `B_xi(v), h(v), C(v), E_xi(v), E_xi(g^-1 v)` вместо широкой строки трассы.
- Дополнительно применимы: сжатие пяти раундов Миллера, замена линий
  делителями `g_b(x,y)=a_b(x)+y*b_b(x)`, один quotient арифметики
  расширенного поля после challenge `beta`, Merkle multiproof, хранение
  фиксированных коэффициентов `Q,S` в `code-shards`.
- Для узкой column-wise модели посчитан предварительный ordinary-FRI
  диапазон стоимости при `N=32768`, `11` слоях и `query_count=576`:
  `6994` уникальных FRI field values, `13352` frontier hashes,
  `1,098,688` байт payload, до `17,579,008 gas` calldata. Свертки FRI
  требуют `12,672` умножения `Fq`, то есть `37,496,448 gas` без
  дедупликации арифметики. При потоковой дедупликации остается `3497`
  уникальных сверток, `6994` умножения и `20,695,246 gas`. Предварительная
  сумма двух крупных компонентов: `38,274,254--55,075,456 gas`.
- Диапазон `38.3--55.1M gas` не является итоговым gas verifier-а и не
  является формальной нижней границей всего verifier-а: не учтены source
  openings, Keccak, column-wise relations, extension arithmetic relation,
  residue relation, ABI и control-flow overhead. Это означает только, что
  узкую схему имеет смысл проверять Rust cost-model-ом.
- Следующий правильный шаг: Rust cost-model, а не Solidity. Он должен
  сравнить `ordinary-fri-strict`, benchmark-профили и `deep-fri-strict`,
  вывести soundness, calldata, Merkle-frontier, число операций и gas.
  Stop/go: Solidity имеет смысл писать только при expected gas ниже
  `93,879,746`, желательно ниже `60,000,000`.

## 2026-06-01: второй проход архитектурного упрощения Merkle/FRI

- Создан документ:
  `implementations/mnt4_merkle_fri_cost_model/docs/MNT4_MERKLE_FRI_ARCHITECTURAL_REFINEMENT_RU.md`.
- Исследован более сильный, но рискованный кандидат: разделить поле MNT4-вычисления и
  поле прозрачного proof layer. MNT4-753 арифметика задается limb/carry/range
  AIR-ограничениями, а PCS/FRI выполняется над EVM-дружественным однословным
  proof field.
- Рекомендуемый первый baseline: `BN254 Fr`, но только как поле AIR/FRI, без
  Groth16 и без BN254 pairing precompile. Оно имеет размер `254 bit` и
  `v2(p-1)=28`, чего достаточно для требуемых двоичных доменов. Сравнить
  также Starknet field (`252 bit`, `v2=192`) и Goldilocks (`64 bit`,
  `v2=32`, но нужен extension field или дополнительные повторения для
  128-bit soundness).
- Предварительный эффект только для FRI payload:
  прежний MNT4-field вариант: `6994*96 + 13352*32 = 1,098,688 bytes`;
  однословный proof field: `6994*32 + 13352*32 = 651,072 bytes`,
  до `10,417,152 gas` calldata. Дополнительно устраняется архитектурный
  bottleneck порядка `20,695,246 gas` на трехсловные FRI-умножения:
  вместо них используются однословные операции proof field.
- Цена переноса: растет trace width из-за limb/carry столбцов и
  range-check. Обязательно сравнить bit-decomposition с
  lookup/permutation range-check по образцу Cairo AIR.
- Дополнительные проверенные оптимизации:
  1. actual-chain partitioning блоков ate loop динамическим программированием
     вместо жесткого `d=5`; paper heuristic при `k=4,L=376` подтверждает,
     что равномерный baseline `d=5` оптимален среди соседних значений;
  2. fixed divisors и column-wise evaluation из ePrint `2024/640`;
  3. один extension quotient после challenge `beta`;
  4. один composition oracle и один batched FRI query set;
  5. OODS/DEEP-FRI для уменьшения query count;
  6. FRI layer skipping / folding большей арности;
  7. last-layer polynomial coefficients;
  8. сравнение tower basis с normal basis, где Frobenius является
     циклическим сдвигом.
- Важно: `code-shards` убирают повторную передачу фиксированных доменных
  таблиц, но не отменяют PCS-opening `C(v)` фиксированного полинома в
  случайной точке. Этот opening нужно батчировать с остальными.
- Критическое уточнение: этот путь возвращает non-native overhead, только в
  AIR/STARK-форме вместо R1CS/Groth16. Ненативными становятся все MNT4
  `Fq/Fq2/Fq4` операции, divisor evaluation, Miller block transitions,
  residue relation и limb/carry/range-check. Это математически корректно,
  но не является решением исходной проблемы дешевого folding без
  измеренного cost-model.
- В проекте существуют два разных non-native ориентира:
  1. реально собранный strict Groth16 full pairing circuit:
     `6,773,269 constraints`, prove около `42.26 s`, on-chain verify около
     `1.087M gas`;
  2. консервативная sparse polynomial/KZG model: `63,309,128 constraints`.
  Они относятся к разным relations и не должны смешиваться, но оба
  показывают trade-off: дешевый on-chain endpoint ценой тяжелой off-chain
  non-native арифметики.
- Следующий рациональный шаг для `proof-field AIR + DEEP-FRI`: только Rust
  stop/go cost-model как сравнительный/возможный отрицательный эксперимент.
  Основным будущим направлением остается `MNT-cycle-native relation +
  folding + terminal compression`, где terminal layer не перепроверяет всю
  MNT4 арифметику ненативно.

## 2026-06-01: возврат к оптимизированной native-field Merkle/FRI схеме

- После обсуждения non-native overhead целевой вариант возвращен к
  прозрачной схеме, где весь proof layer работает непосредственно над
  `Fq(MNT4-753)`. BN254 limb/carry AIR, Groth16 и KZG over BN254 в этот
  модуль не входят.
- Полная целевая спецификация:
  `implementations/mnt4_merkle_fri_cost_model/docs/MNT4_NATIVE_FIELD_OPTIMIZED_MERKLE_FRI_SPEC_RU.md`.
- Короткий design wrapper:
  `docs/superpowers/specs/2026-06-01-mnt4-native-field-optimized-merkle-fri-design.md`.
- Проверяемый API:
  `verifyEquation(P,R,proof)`, где `Q,S` фиксированы конфигурацией и
  доказывается `e(P,Q)e(-R,S)=1`.
- В спецификации объединены проверенные оптимизации:
  1. multi-Miller shared accumulator;
  2. residue witness вместо полной FE;
  3. exact grouping проверенной MNT4 Article640 residue-программы;
  4. adaptive block partition с baseline `d=5`;
  5. fixed compressed divisors `g_b^U=a_b^U+y*b_b^U`;
  6. раздельные fixed divisor tape `D(T)` и dynamic witness tape `C(T)`;
  7. column-wise efficient evaluation;
  8. один randomized extension quotient;
  9. один source tree, один composition oracle и один batched FRI proof;
  10. ordinary FRI correctness baseline и OODS/DEEP-FRI production candidate;
  11. layer-skipping schedule и финальный полином вместо хвостовых слоев;
  12. immutable code-shards для фиксированных коэффициентов;
  13. сегментация из-за `v2(q-1)=15`, max binary subgroup `32768`;
  14. tower vs normal basis cost comparison.
- Предварительная layer-skipping модель `(1,2,2,4,2)` для прежнего
  `query_count=576` уменьшает FRI field values `6994 -> 6208`, Merkle
  frontier `13352 -> 3983`, payload `1,098,688 -> 723,424 bytes`,
  worst-case calldata `17,579,008 -> 11,574,784 gas`, ориентир суммы двух
  крупных FRI-компонентов `38,274,254 -> 29,944,256 gas`. Это не итоговый
  gas: не учтены source openings, локальные relation checks, DEEP overhead
  и control flow.
- Перед Solidity обязателен Rust cost-model. Stop/go:
  `expected_gas < 93,879,746`, желательно `< 60,000,000`, soundness
  `<= 2^-128`.

## 2026-06-01: N1 Rust cost-model нативной Merkle/FRI-схемы

- В `/Users/a.i.semenov/diploma-final` создан локальный Git-репозиторий.
  Исходное состояние зафиксировано checkpoint-коммитом `a108281`.
- Для эксперимента открыта ветка:
  `codex/mnt4-native-fri-cost-model`.
- Реализован Rust crate:
  `implementations/mnt4_merkle_fri_cost_model/rust/native_fri_cost_model`.
- Команда запуска:
  `implementations/mnt4_merkle_fri_cost_model/scripts/run_cost_model.sh`.
- Машиночитаемый отчет:
  `implementations/mnt4_merkle_fri_cost_model/artifacts/native-field-cost-model/report.json`.
- Читаемый отчет:
  `implementations/mnt4_merkle_fri_cost_model/docs/N1_NATIVE_FIELD_COST_MODEL_RESULTS_RU.md`.
- Модель проверяет strict ordinary-FRI профиль по формуле формальной
  спецификации:
  `rho=1/8`, `delta0=0.1507257`, минимум `544` запроса, production-профиль
  `576` запросов, вклад FRI `135.762 bit`.
- Перебор layer-skipping schedules и `last_layer_size in {8,16,32,64}`
  выбрал schedule `[2,2,2,4]` с последним слоем `32`.
- Strict ordinary-FRI результат:
  нижняя оценка `51,359,352 gas`, ожидаемая модельная оценка
  `78,340,624 gas`, обязательная calldata `2,072,224 bytes`.
- Итог N1: условный `GO` относительно Article640 fixed-shards baseline
  `93,879,746 gas`, но желаемая цель `<60M gas` не достигнута strict
  ordinary-FRI профилем.
- Экспериментальные DEEP-FRI строки выведены отдельно и не объявляются
  production-ready: перед использованием требуется численная инстанциация
  конкретной DEEP-FRI теоремы.
- Модельные параметры, которые должны быть заменены измерением Solidity на
  следующих этапах: ширина source leaf, число локальных `Fq`-умножений,
  Keccak/parser budget и control-flow overhead.

## 2026-06-01: очистка MNT4 Merkle/FRI модулей

- Актуальная модель стоимости переименована в
  `implementations/mnt4_merkle_fri_cost_model`.
- Архивный исполняемый DEEP-FRI прототип перенесен в
  `implementations/research_variants/mnt4_merkle_deep_fri_microtrace`.
- В основном каталоге Merkle/FRI-направления остается только защищаемый
  результат: математическая спецификация, Rust-модель стоимости и отчет.
- Для итогового текста используется строгая ordinary-FRI модель стоимости:
  нижняя оценка `51,359,352 gas`, ожидаемая модельная оценка
  `78,340,624 gas`, обязательная calldata `2,072,224 bytes`.
- Полная Solidity-реализация блочно-сжатого ordinary-FRI verifier-а не
  продолжается: модель не показывает принципиального выигрыша относительно
  Article640 fixed-shards. Консервативная исполняемая DEEP-FRI микротрасса
  сохранена только как воспроизводимый отрицательный эксперимент.
- Архивный `scripts/run_report.sh` пересобирает fixtures во временном каталоге
  `.reports/`, сравнивает детерминированные файлы с tracked-эталонами и не
  изменяет git-дерево из-за нестабильных `provingMs` и peak RSS.

## 2026-06-01: полный аудит практической части

- Расширен план проверки:
  `docs/PRACTICAL_IMPLEMENTATION_FULL_AUDIT_PLAN_RU.md`.
- Подготовлены итоговый отчет и матрица трассируемости:
  `docs/PRACTICAL_IMPLEMENTATION_FULL_AUDIT_REPORT_RU.md`,
  `docs/PRACTICAL_IMPLEMENTATION_AUDIT_TRACEABILITY_MATRIX_RU.md`.
- Канонический `scripts/run_all.sh` завершился успешно. Дополнительно пройдены
  расширенные Foundry-тесты, Rust fixture cross-check, Merkle/FRI cost model,
  архивный DEEP-FRI report, bash syntax и проверка tracked generated-файлов.
- Главный вердикт: проект готов как исследовательская практическая часть с
  отрицательным/граничным результатом, но не как универсальная
  production-замена MNT precompile.
- Обязательные исправления перед финальной фиксацией:
  1. исправить MNT-cycle счетчики и назвать результат ручной моделью;
  2. явно документировать доверенную предрегистрацию MNT4 fixed-shards cache;
  3. добавить input validation для public verifier API либо строгую внешнюю
     предпосылку;
  4. довести MNT6 до интегрированного fixed-shards bool pairing-equation
     verifier-а;
  5. синхронизировать документацию и автоматизировать fixture cross-check.

## 2026-06-01: исправления по результатам полного аудита

- Исправлена ручная MNT-cycle модель: MNT4 использует `376/124`, MNT6 -
  `376/123` шагов удвоения/сложения. Итоги: `24,126` и `48,942`
  multiplication constraints.
- Добавлен `MNT4CurveChecks`; production и direct Article640 API MNT4
  отклоняют неканонические точки и точки вне G1 до тяжелой арифметики.
- Rust backend MNT6 теперь строит ненулевое билинейное уравнение
  `e(2G1,G2)=e(G1,2G2)` и два prepared cache.
- Добавлен `MNT6Article640FixedShardsVerifier`: фиксирует shard-адреса,
  потоково читает коэффициенты через `EXTCODECOPY`, проверяет G1-точки и
  возвращает `bool` для полного уравнения сопряжений. Gas:
  `226,073,973` для `verifyEquationFullFixedShards` до финального
  residue-прохода.
- Буквальный перенос знаков MNT4-style короткого `c`-свидетельства на MNT6
  признан некорректным. Последующая перепроверка показала, что residue-путь
  переносится с отдельным отношением `r_MNT6=q_MNT6-N`; актуальный основной
  вызов описан ниже.
- Корневой `scripts/run_all.sh` запускает актуальную ordinary-FRI cost model.
- `baselines/naive_tate_mnt4` явно оформлен как cost model: измеренные
  математически корректные микроблоки плюс строгая нижняя экстраполяция.
  Полный исполняемый reference MNT4 остается в
  `implementations/full_onchain_mnt4`.

## 2026-06-01: MNT6 shared multi-Miller residue verifier

- Перепроверено прежнее предположение о неприменимости короткого Article640
  `c`-отношения к MNT6. Буквальное копирование знаков MNT4 действительно
  неверно, но residue-путь переносится после учета
  `r_MNT6 = q_MNT6 - N`. Для MNT6 контракт проверяет
  `F * c^(N-q) = F * c^(-r) = 1`.
- Rust backend MNT6 теперь генерирует `c`, `cInv` и подтверждает
  `c^r = F` для нетривиального уравнения
  `e(2G1,G2)=e(G1,2G2)`.
- В `MNT6AteLoop` добавлен общий packed code-shards multi-Miller accumulator:
  обе пары обрабатываются в одном цикле, поэтому возведение аккумулятора в
  квадрат выполняется один раз на раунд. Полная FE в основном API не
  вычисляется.
- Добавлен основной API
  `verifyEquationResidueFixedShards(P,R,c,cInv) -> bool`; прежний
  `verifyEquationFullFixedShards` сохранен как контрольный baseline.
- Проверка: `implementations/article640_mnt6` проходит `13/13` Foundry-тестов,
  включая корректное уравнение, подмену `cInv`, ложное уравнение на валидных
  точках и раннее отклонение точки вне G1 в новом residue API.
- Function gas: baseline с полной packed FE `226,078,963`; общий residue
  verifier `172,004,717`; экономия `54,074,246 gas` (`23.92%`).
- Runtime size основного fixed-shards контракта: `20,312 bytes`, запас до
  EIP-170: `4,264 bytes`.
- Полный корневой `./scripts/run_all.sh` завершен с кодом `0`: пройдены
  арифметические модули, MNT4/MNT6 Article640, Rust fixture cross-check,
  MNT-cycle accounting и актуальная ordinary-FRI cost model.

## 2026-06-01: подробный итоговый отчет для научного руководителя

- На основе пользовательского шаблона подготовлен расширенный итоговый отчет:
  `docs/FINAL_SUPERVISOR_REPORT_RU.tex`.
- Собран PDF:
  `docs/FINAL_SUPERVISOR_REPORT_RU.pdf`.
- Отчет занимает 18 страниц и охватывает:
  постановку задачи и ограничение Sonobe/CycleFold-like подходов;
  теоретическую базу вычисления сопряжения и удаление знаменателя;
  аудит 3-limb арифметики; MNT4 naive baseline и оптимизационную лестницу;
  Article640 residue-проверку; KZG и Merkle/ordinary-FRI модели;
  MNT6 verifier и ручную MNT4/MNT6 cycle-native модель;
  исследовательский lollipop-305; итоговый trade-off gas/constraints.
- В тексте отдельно помечено, какие числа получены измерением Foundry,
  какие относятся к исполняемым Rust-моделям, а какие являются ручными
  оценками. В частности, `73,068` операций для MNT-cycle не выдаются за
  скомпилированный CycleFold-circuit.
- Локальная среда не содержит `pdflatex`, поэтому визуальная QA-сборка
  выполнена через временную XeTeX-совместимую копию с `tectonic`.
  Канонический `.tex` сохранен в `pdflatex`-совместимом виде для Overleaf:
  `fontenc[T2A]` и `inputenc[utf8]`.
- Проверено: PDF имеет формат A4, 18 страниц; в логе нет LaTeX-ошибок и
  `Overfull \hbox`; визуально проверены титул/оглавление, таблицы MNT4,
  MNT6, lollipop-305, сводная таблица и список литературы.

## 2026-06-01: расширение отчета по замечаниям руководителя

- `docs/FINAL_SUPERVISOR_REPORT_RU.tex` переведен в явный
  `pdflatex`-совместимый формат без `fontspec`: используются
  `fontenc[T2A]`, `inputenc[utf8]`, `babel`; `cmap` и `lmodern`
  подключаются только при наличии пакетов.
- Раздел статуса расширен: перечислены теоретические результаты,
  инженерные реализации, проверки и граница результата.
- Разделены два разных вида удаления знаменателей:
  вертикальные знаменатели Miller-функции и нормализующие знаменатели
  projective/prepared line-cache.
- Нижняя оценка 3-limb умножения исправлена: `2,959 gas/op` назван
  измеренным практическим минимумом, а не строгой теоретической границей.
  Добавлен opcode-only вывод `537--645 gas` до учета служебной логики EVM.
- Добавлены формальная sparse-line формула, низкоуровневые оптимизации,
  расширенная MNT4 ladder-таблица, подробная MNT4 polynomial-check модель,
  KZG non-native constraints и Merkle/ordinary-FRI оценки.
- Добавлены MNT6-леммы, отдельная проекция cycle-native constraints при
  коэффициентах обвязки `1x--12x`, lollipop-леммы и пояснение объема
  2-limb реализации.
- Экономическая таблица пересчитана по снимку 01.06.2026 13:51 MSK:
  ETH `$1,982.85`, Ethereum standard gas `0.294 gwei`,
  Arbitrum One execution gas `0.020 gwei`. Для L2 отдельно отмечена
  дополнительная стоимость L1 data posting.
- Добавлена таблица трассируемости всех пяти замечаний руководителя.
- QA PDF занимает 29 страниц A4. В журнале нет LaTeX-ошибок и
  `Overfull \hbox`; визуально проверены титул, MNT4, MNT6, cycle-native,
  lollipop, экономическая таблица, таблица замечаний и литература.

## 2026-06-01: Overleaf-пакет и уточнение нижней оценки 3-limb умножения

- Для отчета создан самодостаточный Overleaf-пакет:
  `docs/overleaf_supervisor_report/main.tex` и
  `docs/overleaf_supervisor_report/README.md`. В Downloads собран архив
  `/Users/a.i.semenov/Downloads/final-supervisor-overleaf.zip`.
- Причина путаницы с Overleaf локализована: старый
  `/Users/a.i.semenov/Downloads/main.tex` относится к прежнему шаблону и
  содержит ссылку на отсутствующий рисунок `example-image`. Для нового
  Overleaf-проекта нужно использовать только файл из подготовленного архива.
- Преамбула нового отчета упрощена до минимального `pdflatex`-варианта:
  `fontenc[T2A]`, `inputenc[utf8]`, `babel`. Убраны необязательные
  подключения `cmap` и `lmodern`.
- Повторно выполнены Foundry-бенчмарки:
  `testGasBench_montMul3_internal` дает `2,959 gas/op`;
  `testGasBench_montMul3_external_stack` дает `3,976 gas/op`.
- В отчете исправлена нижняя оценка 3-limb Montgomery/CIOS умножения.
  Число `627 gas` теперь явно называется строгой, но неполной границей
  арифметического каркаса. Добавлена структурная таблица all-stack Yul-кода:
  неизбежные `MUL/MULMOD`, сеть переносов, условные ветви и служебные расходы
  EVM отделены от измеренного практического результата `2,959 gas/op`.
- Обновленный QA PDF занимает 30 страниц A4. В логе отсутствуют LaTeX-ошибки,
  `Emergency stop` и `Overfull \hbox`.

## 2026-06-01: динамическая opcode-трасса `montMul3`

- Для устранения слабого разрыва между грубой границей и измерением снята
  geth-style opcode-трасса одиночного внешнего вызова `BigIntMNT.montMul3`.
  Использован локальный `anvil --steps-tracing`.
- Полный внешний вызов исполняет `1,012` EVM-инструкций и расходует
  `3,316 gas` без intrinsic transaction gas. Развернутое CIOS-тело занимает
  `2,843 gas`; внешняя ABI-обвязка и возврат результата занимают `473 gas`.
- Трасса подтвердила уже выполненную низкоуровневую оптимизацию: три младших
  произведения `m_i * q_0` не вычисляются полностью. После выбора коэффициента
  Montgomery-редукции младшее слово обнуляется и отбрасывается. В исполняемом
  графе остаются `18 MULMOD`, `15` полезных младших `MUL` и `3 MUL` для
  коэффициентов редукции.
- В `docs/FINAL_SUPERVISOR_REPORT_RU.tex` раздел оценки переписан. Число
  `396 gas` сохранено только как слабая математическая граница для
  восстановления произведений. Главным аргументом является динамический
  разбор CIOS-тела и экспериментальное сравнение вариантов.
- Добавлен отдельный воспроизводимый отчет
  `docs/MNT4_MONTMUL3_OPCODE_TRACE_RU.md`.
- Корректная граница утверждения: `2,959 gas/op` является лучшим подтвержденным
  практическим результатом в исследованном классе алгоритмов. Абсолютная
  минимальность среди всех EVM-bytecode программ не заявляется: для нее
  потребовалась бы отдельная задача супероптимизации байткода.

## 2026-06-01: сокращенная редакция итогового отчета

- На основе пользовательского файла
  `/Users/a.i.semenov/Downloads/итоговый отчет (2).tex` подготовлена отдельная
  редакция `docs/FINAL_SUPERVISOR_REPORT_RU_SHORT.tex`.
- Выполнено только удаление фрагментов: `0` добавленных и `117` удаленных строк.
  Существующие формулировки не переписывались.
- Удалены дублирующий обзор результатов в начале, развернутые общеизвестные
  формулы Karatsuba, повторные пояснения после таблиц и дублирующая итоговая
  таблица соответствия замечаниям руководителя.
- Сохранены формулы разреженного умножения, residue-проверки, полиномиальной
  модели цикла Миллера, KZG/Merkle-FRI, MNT-cycle accounting и lollipop-305.
- QA-сборка сокращенной редакции занимает `21` страницу A4 вместо `24`.
  В логе отсутствуют LaTeX-ошибки, `Emergency stop` и `Overfull \hbox`.
- Копии сохранены в Downloads:
  `/Users/a.i.semenov/Downloads/итоговый отчет (2) сокращенный.tex` и
  `/Users/a.i.semenov/Downloads/итоговый отчет (2) сокращенный.pdf`.

## 2026-06-01: возвращена таблица закрытия замечаний руководителя

- По запросу пользователя в конец сокращенной редакции
  `docs/FINAL_SUPERVISOR_REPORT_RU_SHORT.tex`, перед библиографией, возвращена
  таблица `Соответствие выполненной работы замечаниям руководителя`.
- Таблица извлечена из главы 10 файла
  `/Users/a.i.semenov/Downloads/итоговый_отчет.pdf` и добавлена без изменения
  остальных разделов сокращенного отчета.
- QA-сборка обновленной редакции занимает `22` страницы A4. В логе отсутствуют
  LaTeX-ошибки, `Emergency stop` и `Overfull \hbox`.
- Копии сохранены в Downloads:
  `/Users/a.i.semenov/Downloads/итоговый отчет (2) сокращенный с таблицей.tex`
  и `/Users/a.i.semenov/Downloads/итоговый отчет (2) сокращенный с таблицей.pdf`.

## 2026-06-01: независимое задание Claude для 3-limb умножения

- Добавлен документ
  `docs/CLAUDE_INDEPENDENT_3LIMB_MONTGOMERY_MUL_TASK_RU.md`.
- Цель документа: дать Claude независимое задание реализовать с нуля
  3-limb Montgomery-умножение поля MNT4-753 и попытаться достичь
  `<= 1,500 gas/op` для внутреннего библиотечного вызова.
- В документ намеренно не включены текущий production-код, примененные в нем
  оптимизации, результаты существующих вариантов и подсказки по выбору
  алгоритма. Зафиксированы только математическая семантика, API, модуль поля,
  конфигурация Foundry, требования к тестам и методика benchmark-а.
- Копия для передачи Claude сохранена в Downloads:
  `/Users/a.i.semenov/Downloads/CLAUDE_INDEPENDENT_3LIMB_MONTGOMERY_MUL_TASK_RU.md`.

## 2026-06-01: экспериментальная проверка реализации Claude

- Создан изолированный Foundry-модуль
  `experiments/claude_fieldmul3`.
- Реализация Claude проверена независимым Python-эталоном произвольной точности:
  граничные случаи, `64` быстрых случайных вектора и отдельный длинный прогон
  на `5000` детерминированных случайных векторах проходят успешно.
- Для компиляции потребовалось только переименовать внутренний Yul-флаг займа
  `b1` в `borrow1`: исходное имя конфликтовало с параметром Solidity-функции.
- Буквальный benchmark Claude на малых входах дает `5,121 gas/op`.
- Отдельный benchmark с полноразмерными входами дает `5,643 gas/op`.
- Функция Claude возвращает канонический результат `a * b mod p`, поэтому ее
  нельзя напрямую сравнивать с production hot path `montMul3`, который измеряет
  одну внутреннюю Montgomery-domain операцию и дает `2,959 gas/op`.

## 2026-06-01: MODEXP-вариант 3-limb умножения

- Создан изолированный модуль `experiments/claude_fieldmul3_modexp`.
- Проверена идея вычислять каноническое `a * b mod p` через тождество
  `(a+b)^2 - (a-b)^2 = 4ab`, два вызова MODEXP `0x05` и два модульных
  полуделения.
- Корректность подтверждена Python-эталоном на граничных случаях,
  `64` быстрых случайных векторах и отдельном прогоне из `5000` векторов.
- Проведены RPC-бенчмарки реальными транзакциями на локальных узлах
  `anvil --hardfork prague` и `anvil --hardfork osaka`.
- Результаты для умножения: полноразмерные входы дают `2,375 gas/op` на Prague
  и `2,975 gas/op` на Osaka после EIP-7883.
- Добавлена отдельная каноническая квадратура через один MODEXP:
  `578 gas/op` на Prague и `878 gas/op` на Osaka.
- Прямая замена production `montMul3` невозможна: текущая MNT4-арифметика
  хранит элементы в Montgomery-представлении. Перспективный следующий
  эксперимент должен проверить отдельную canonical-ветку `Fq/Fq2/Fq4` и
  полного цикла Миллера.
