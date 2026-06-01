# diploma-final

Чистовая поставка кода для дипломной работы. Исходная рабочая директория `/Users/a.i.semenov/mnt4-pairing-final` не изменялась; здесь оставлена структурированная версия без старых дублирующих модулей.

## Структура

| Директория | Назначение |
|---|---|
| `arithmetic/mnt4_3limb/` | Общая 3-limb арифметика MNT4-753: чистовой Montgomery/CIOS-путь в `src/`, сравнения Barrett/FIOS/Comba/branchless/lazy/sparse в `research_variants/`. |
| `arithmetic/mnt6_3limb/` | Общая 3-limb арифметика MNT6-753: `Fp`, `Fq3`, `Fq6`, packed hot-path, проверки кривой и ate-loop primitives. |
| `arithmetic/lollipop305_2limb/` | Общая 2-limb арифметика lollipop-305: чистовой stack API в `src/`, альтернативные варианты в `research_variants/`. |
| `implementations/full_onchain_mnt4/` | Полное on-chain вычисление MNT4-сопряжения и fixed-Q/prepared/code-shards baseline. |
| `implementations/article640_mnt4/` | Основная реализация идей ePrint 2024/640 для MNT4: calldata+commitment и fixed code-shards/EXTCODECOPY варианты, плюс Rust-бэкенд для генерации fixtures. |
| `implementations/article640_mnt6/` | MNT6-753 Article640/residue реализация поверх общей MNT6-арифметики, плюс Rust-бэкенд fixtures. |
| `implementations/lollipop305/` | Исследовательский lollipop-305 pipeline поверх общей 2-limb арифметики, Rust reference/backend и безопасный fixed-cache режим через зафиксированные code-shards. |
| `implementations/mnt4_merkle_fri_cost_model/` | Актуальная математическая спецификация и Rust-модель стоимости блочно-сжатого ordinary-FRI пути. |
| `implementations/research_variants/` | Воспроизводимые, но не выбранные исследовательские варианты. |
| `baselines/naive_tate_mnt4/` | Наивный Tate baseline без optimized hot-path; используется как отрицательная точка отсчета. |
| `mnt_cycle_full/` | Rust-модель MNT4/MNT6 cycle-native relations и constraints. |
| `docs/` | Отчеты, планы, оценки сложности, краткие материалы для защиты. |
| `scripts/` | Однокомандные проверки и gas-отчеты. |

## Быстрый запуск

```bash
cd /Users/a.i.semenov/diploma-final
./scripts/run_all.sh
```

Отдельные прогоны:

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
```

## Основные финальные числа

| Сценарий | Газ |
|---|---:|
| Full MNT4 on-chain fixed-Q | `259,327,933` |
| MNT4 prepared sparse blob | `79,726,321` |
| MNT4 prepared sparse code-shards | `80,140,929` |
| Article640 hot residue calldata | `93,881,355` |
| Article640 hot residue fixed-shards | `93,705,233` |
| Article640 hot residue calldata + commitment | `93,974,409` |
| MNT6 Article640 residue | `103,294,551` |
| Lollipop-305 Ehat ate residue | `106,457,927` |

Важно: `implementations/article640_mnt4` содержит оба финальных сравниваемых режима: `calldata + commitment` и `code-shards / EXTCODECOPY`. Остальные implementation-директории оставляют только наиболее полезный путь для соответствующего эксперимента.

## Разделение чистового и исследовательского кода

В `src/` арифметических модулей оставлены только библиотеки, которые импортируются финальными реализациями сопряжения. Альтернативы, необходимые для сравнительных таблиц диплома, вынесены в `research_variants/` и подключаются только тестами. Типы, используемые исключительно тестовой инфраструктурой, размещены в `test_support/`.

Полная MNT4-реализация сопряжения находится только в `implementations/full_onchain_mnt4/`. Она не дублируется внутри арифметического модуля: библиотека базовой арифметики остается общей зависимостью.

Merkle/FRI-направление разделено аналогично: в
`implementations/mnt4_merkle_fri_cost_model/` находится выбранная
математическая модель стоимости, а исполняемый консервативный DEEP-FRI
прототип перенесен в `implementations/research_variants/` как
воспроизводимый отрицательный эксперимент.
