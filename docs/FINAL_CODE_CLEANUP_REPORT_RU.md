# Финальный cleanup-аудит кода

Дата проверки: 2026-06-06.

## 1. Цель проверки

Код в `/Users/a.i.semenov/diploma-final` должен быть готов к публикации на GitHub и к приложению к материалам работы. Основной критерий: в чистовом дереве остаются только актуальные реализации, воспроизводимые тесты, документы и исследовательские варианты, явно отделенные от production-пути.

## 2. Что было проверено

| Пункт | Результат |
|---|---|
| Структура директорий | Production-код оставлен в `src` соответствующих модулей; альтернативы и отрицательные эксперименты отделены в `research_variants` и `experiments`. |
| Скрипты запуска | Оставлены канонические `scripts/run_*.sh`; устаревшие alias-скрипты удалены. |
| Документация входа | Обновлены `README.md` и `docs/FINAL_DELIVERY_OVERVIEW_RU.md`. |
| Комментарии | В lollipop packed-extension hot path добавлены русские комментарии к ключевым функциям и участкам памяти. |
| Архивные тесты | Из production lollipop backend удалены ignored-тесты, которые описывали уже неактуальные промежуточные постановки. |
| Устаревшие маркеры | Проверка по служебным unresolved-маркерам не нашла актуальных долгов в production-аудите. |
| Устаревшие пути | В `README.md`, `scripts` и `FINAL_DELIVERY_OVERVIEW_RU.md` не найдено ссылок на старые рабочие директории. |

## 3. Полный прогон

Был выполнен общий запуск:

```bash
./scripts/run_all.sh
```

Он прошел без ошибок и покрыл:

| Модуль | Проверка |
|---|---|
| `arithmetic/mnt4_3limb` | Foundry-тесты 3-limb арифметики. |
| `arithmetic/mnt6_3limb` | Foundry-тесты MNT6 `Fp/Fq3/Fq6`. |
| `arithmetic/lollipop305_2limb` | Foundry-тесты 2-limb lollipop-арифметики. |
| `implementations/full_onchain_mnt4` | Full on-chain MNT4 baseline и prepared/code-shards режимы. |
| `implementations/article640_mnt4` | MNT4 equation/residue verifier, calldata+commitment и fixed-shards. |
| `implementations/article640_mnt4/rust/article640_backend` | Rust backend и fixture cross-check. |
| `baselines/naive_tate_mnt4` | Наивная Tate cost model. |
| `implementations/lollipop305` | Solidity lollipop-305 verifier-ы и gas-замеры. |
| `implementations/lollipop305/rust_backend` | Rust backend, curve/tower/pairing tests. |
| `implementations/lollipop305/rust_reference` | Rust reference arithmetic. |
| `implementations/article640_mnt6` | MNT6 Article640/full/residue/fixed-shards verifier. |
| `implementations/article640_mnt6/rust/mnt6_article640_backend` | Rust backend и fixture cross-check. |
| `mnt_cycle_full` | MNT4/MNT6 cycle-native accounting. |
| `implementations/mnt4_merkle_fri_cost_model` | Ordinary-FRI/Merkle cost model. |

После удаления архивных ignored-тестов был отдельно перезапущен:

```bash
./scripts/run_lollipop305_backend.sh
```

Результат: backend-тесты lollipop проходят без ignored-тестов.

## 4. Свежие ключевые gas-результаты

| Блок | Сценарий | Gas |
|---|---|---:|
| MNT4 full on-chain | fixed-Q on-chain digest | 259,327,933 |
| MNT4 prepared | prepared sparse blob | 79,726,321 |
| MNT4 prepared | prepared sparse code-shards | 80,140,929 |
| Article640 MNT4 | residue equation, calldata | 93,913,739 |
| Article640 MNT4 | residue equation, fixed-shards с проверкой G1 | 93,734,789 |
| Article640 MNT4 | residue equation, calldata+commitment | 94,007,260 |
| MNT6 | fixed-shards bool residue equation с проверкой G1 | 172,004,717 |
| lollipop-305 | stick residue fixed-shards | 8,723,296 |
| lollipop-305 | cycle-E residue fixed-shards | 18,384,363 |
| lollipop-305 | Ehat product-Frobenius residue fixed-shards | 56,163,308 |
| lollipop-305 | сумма трех актуальных lollipop-компонент | 83,270,967 |
| Merkle/FRI model | strict expected gas | 78,340,624 |
| Merkle/FRI model | strict lower bound gas | 51,359,352 |

## 5. Остаточные замечания

Сборочные директории `out`, `cache`, `target` и `.reports` появляются после тестов и игнорируются git. Их не нужно публиковать как исходный код.

В рабочем дереве есть изменения, относящиеся к предыдущим этапам оптимизации lollipop и итогового отчета. Они не откатывались, так как являются частью актуального состояния проекта.

## 6. Итог

По результатам проверки кодовая база приведена к финальному виду: структура понятна, устаревшие alias-скрипты удалены, исследовательские варианты отделены от production-пути, основные документы актуализированы, общий прогон проходит, а статический аудит не показывает unresolved-маркеров в проверяемых production-документах и коде.
