# Финальная директория проекта

Финальная очищенная версия проекта находится в `/Users/a.i.semenov/diploma-final`. Исходная рабочая директория `/Users/a.i.semenov/mnt4-pairing-final` не изменялась.

## 1. Архитектура директорий

В финальной версии арифметика вынесена отдельно от реализаций сопряжения. Это убирает дублирование: implementation-контракты импортируют общие библиотеки через remappings.

| Блок | Назначение |
|---|---|
| `arithmetic/mnt4_3limb` | Общая MNT4-753 арифметика. Чистовой путь находится в `src`, сравниваемые варианты алгоритмов — в `research_variants`. |
| `arithmetic/mnt6_3limb` | Общая MNT6-753 арифметика и тесты `Fp/Fq3/Fq6`. |
| `arithmetic/lollipop305_2limb` | Общая 2-limb арифметика lollipop-305. Чистовой stack API отделен от `research_variants`. |
| `implementations/full_onchain_mnt4` | Основной full on-chain MNT4 baseline. |
| `implementations/article640_mnt4` | Основная Article640 MNT4 реализация: calldata+commitment и code-shards/EXTCODECOPY. |
| `implementations/article640_mnt6` | MNT6 Article640/residue реализация. |
| `implementations/lollipop305` | Lollipop-305 research pipeline. |
| `baselines/naive_tate_mnt4` | Наивная Tate-точка отсчета. |
| `mnt_cycle_full` | Rust-модель MNT4/MNT6 cycle-native constraints. |

Отдельный модуль `fixed_q_prepared` удален: он дублировал логику `article640_mnt4` и больше не нужен как самостоятельная реализация.

Из `arithmetic/mnt4_3limb/src` также удалены ранние модульные оболочки и копия полной pairing-библиотеки. Они не участвовали в финальном пути и дублировали код из `implementations/full_onchain_mnt4`. Pairing-специфичные тесты перенесены в директорию соответствующей реализации; в арифметическом модуле остались только тесты арифметики и сравнений алгоритмов.

## 1.1. Исследовательские варианты

Сравнительные реализации сохранены, но физически отделены от чистового кода:

| Директория | Содержание |
|---|---|
| `arithmetic/mnt4_3limb/research_variants` | Barrett, FIOS, Comba/SOS, branchless reduction, skip-t0, lazy и специализированные операции расширений. |
| `arithmetic/lollipop305_2limb/research_variants` | Branchless reduction, skip-t0, small-high-limb варианты и структурная арифметика расширений для сравнения со stack API. |
| `arithmetic/mnt4_3limb/test_support` | Типы, необходимые только тестовым контрактам Article640. |

Такое разделение сохраняет воспроизводимость таблиц диплома, но делает зависимости production-кода однозначными.

## 2. Запуск

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
```

## 3. Article640 MNT4: два финальных варианта

В `implementations/article640_mnt4` сохранены оба сравниваемых подхода:

| Вариант | Что проверяет | Зачем оставлен |
|---|---|---|
| `calldata + commitment` | Пользователь передает prepared cache, контракт проверяет commitment и затем выполняет residue equation. | Формально показывает binding к переданному кэшу. |
| `fixed code-shards / EXTCODECOPY` | Адреса data-shards фиксируются в конструкторе; пользователь не может подменить кэш в вызове. | Production-shaped вариант для часто переиспользуемых fixed G2-точек. |

Оба режима дают близкий порядок gas, что и является важным экспериментальным результатом.

## 4. Основные результаты

| Блок | Сценарий | Gas |
|---|---|---:|
| MNT4 full on-chain | fixed-Q on-chain digest | 259,327,933 |
| MNT4 prepared | prepared sparse blob | 79,726,321 |
| MNT4 prepared | prepared sparse code-shards | 80,140,929 |
| Article640 MNT4 | residue equation, calldata | 93,881,355 |
| Article640 MNT4 | residue equation, fixed-shards с проверкой G1 | 93,734,789 |
| Article640 MNT4 | residue equation, calldata+commitment | 93,974,409 |
| MNT6 | fixed-shards bool residue equation с проверкой G1 | 172,004,717 |
| lollipop-305 | Ehat ate residue verifier | 106,457,927 |
| lollipop-305 | Ehat Weil equation | 201,002,138 |

## 5. Ограничения

В `implementations/article640_mnt6` сохранены оба сопоставимых режима:
контрольный fixed-shards baseline с полной оптимизированной финальной
экспонентой (`226,078,963 gas`) и основной fixed-shards residue verifier
(`172,004,717 gas`). Для MNT6 перенос требует другого знака: поскольку
`r_MNT6=q_MNT6-N`, проверяется отношение `F*c^(N-q)=1`.

Build artifacts (`out`, `cache`, `target`) не входят в поставку. Скрипты пересобирают проект заново.
