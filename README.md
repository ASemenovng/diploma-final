# diploma-final

Чистовая поставка кода практической части дипломной работы. Репозиторий разделен на production-пути, исследовательские варианты и документы так, чтобы проверяющий мог воспроизвести основные измерения без обращения к старым рабочим директориям.

## Что реализовано

| Блок | Смысл |
|---|---|
| `arithmetic/mnt4_3limb/` | Общая 3-limb арифметика MNT4-753: Montgomery/CIOS, `Fq`, `Fq2`, `Fq4`, проверки точек и тесты алгоритмических вариантов. |
| `arithmetic/mnt6_3limb/` | Общая 3-limb арифметика MNT6-753: `Fp`, `Fq3`, `Fq6`, packed hot-path, primitives для ate-loop. |
| `arithmetic/lollipop305_2limb/` | Общая 2-limb арифметика lollipop-305: stick-field, cycle-field, packed `Fq2/Fq6` для сложного Ehat-контура. |
| `baselines/naive_tate_mnt4/` | Наивная Tate/cost-model точка отсчета без выбранных оптимизаций. |
| `implementations/full_onchain_mnt4/` | Полное on-chain вычисление MNT4-сопряжения и fixed-Q/prepared/code-shards baseline. |
| `implementations/article640_mnt4/` | MNT4-реализация идей ePrint 2024/640: calldata+commitment, fixed code-shards/EXTCODECOPY, KZG/Merkle opening layers. |
| `implementations/article640_mnt6/` | MNT6-753 verifier, построенный симметрично MNT4: prepared lines, общий accumulator, residue/c-свидетельство. |
| `implementations/lollipop305/` | Исследовательский lollipop-305 pipeline: stick + cycle-E + Ehat, fixed-shards режим и Rust-бэкенды. |
| `implementations/mnt4_merkle_fri_cost_model/` | Актуальная модель стоимости Merkle/FRI-проверки цикла Миллера без production-заявления. |
| `implementations/research_variants/` | Архивные воспроизводимые эксперименты, которые не являются основным путем. |
| `experiments/` | Независимые тесты идей Claude/ModExp для 3-limb умножения; используются только как исследовательские сравнения. |
| `mnt_cycle_full/` | Rust-модель MNT4/MNT6 cycle-native учета и constraints-accounting. |
| `docs/` | Отчеты, планы аудита, оценки сложности, материалы для руководителя и защиты. |
| `scripts/` | Однокомандные проверки и gas-отчеты. |

## Production и research разделены

- В `src/` основных модулей лежат только актуальные библиотеки и контракты, которые используются финальными тестами.
- Альтернативы Barrett/FIOS/Comba/branchless/lazy, независимые варианты Claude и архивный DEEP-FRI-прототип вынесены в `research_variants/` или `experiments/`.
- Build artifacts (`out/`, `cache/`, `target/`, `.reports/`) не являются частью поставки и игнорируются git.
- Некоторые исторические документы в `docs/` и `implementations/lollipop305/docs/` сохраняют старые названия директорий как контекст исследования. Актуальная структура описана в этом README и в `docs/FINAL_DELIVERY_OVERVIEW_RU.md`.

## Быстрый запуск

Полный прогон:

```bash
cd /Users/a.i.semenov/diploma-final
./scripts/run_all.sh
```

Отдельные проверки:

```bash
./scripts/run_arith_3limb.sh
./scripts/run_arith_mnt6.sh
./scripts/run_arith_2limb.sh
./scripts/run_full_onchain_mnt4.sh
./scripts/run_article640_mnt4.sh
./scripts/run_article640_mnt4_backend.sh
./scripts/run_mnt6_article640.sh
./scripts/run_mnt6_article640_backend.sh
./scripts/run_lollipop305.sh
./scripts/run_lollipop305_backend.sh
./scripts/run_naive_tate.sh
./scripts/run_mnt_cycle.sh
./scripts/run_mnt4_merkle_fri_cost_model.sh
```

Скрипты пишут логи в `.reports/` и печатают ключевые строки gas-report, если они есть в выводе Foundry.

## Как читать результаты

Работа показывает не один “магический” контракт, а границу между тремя способами оплаты вычисления:

1. **Платить gas за on-chain арифметику.** Это реализовано в `full_onchain_mnt4`, `article640_mnt4`, `article640_mnt6` и `lollipop305`.
2. **Платить constraints/off-chain стоимость за proof/PCS слой.** Это исследуется через KZG/Merkle/FRI и cycle-native accounting.
3. **Менять семейство кривых.** Это исследуется через lollipop-305: 2-limb арифметика дешевле, но полный pipeline имеет собственные математические ограничения.

Ключевой вывод: локальные EVM-оптимизации и residue-проверка уменьшают стоимость, но без подходящего precompile/PCS/proof-слоя нельзя одновременно получить малые gas и малые constraints для полного production-пути.

## Основные документы

| Документ | Назначение |
|---|---|
| `docs/ARITHMETIC_ALGORITHM_STUDY_RU.md` | Сравнение алгоритмов арифметики и низкоуровневых вариантов. |
| `docs/ALGORITHM_COMPLEXITY_ESTIMATES_RU.md` | Формальные оценки сложности в базовых операциях. |
| `docs/MNT4_ONCHAIN_OPTIMIZATION_LADDER_RU.md` | Поэтапная оптимизация полного MNT4 on-chain пути. |
| `docs/FINAL_NEGATIVE_AND_BOUNDARY_RESULTS_RU.md` | Итоговый граничный результат: где остается trade-off gas/constraints. |
| `docs/PRACTICAL_IMPLEMENTATION_FULL_AUDIT_REPORT_RU.md` | Полный аудит практической части. |
| `docs/FINAL_DELIVERY_OVERVIEW_RU.md` | Краткое описание финальной поставки. |
