# Release Code Cleanup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** привести `/Users/a.i.semenov/diploma-final` к состоянию, в котором код можно залить на GitHub и приложить к материалам диплома.

**Architecture:** production-модули должны содержать только актуальные реализации; исследовательские альтернативы должны лежать в `research_variants/` или `experiments/`; документы и скрипты должны объяснять, что запускать и как интерпретировать результат.

**Tech Stack:** Solidity/Foundry, Rust/Cargo, shell scripts, Markdown/TeX-документы.

---

### Task 1: Инвентаризация и локальная очистка

**Files:**
- Inspect: весь `/Users/a.i.semenov/diploma-final`
- Modify: `.gitignore`, если обнаружены неигнорируемые артефакты

- [x] Убедиться, что чистовая директория — `/Users/a.i.semenov/diploma-final`.
- [x] Сохранить текущий список файлов Solidity/Rust/scripts/docs для аудита.
- [x] Удалить локальные `out/`, `cache/`, `target/`, `.reports/`, если они не нужны как исходные материалы.
- [x] Не удалять `lib/forge-std`, `research_variants/`, `experiments/`, документы и fixtures.
- [x] Проверить `git status --short --ignored`, что удалены только игнорируемые сборочные артефакты.

### Task 2: Разделить production и research пути

**Files:**
- Inspect: `arithmetic/**/src`, `implementations/**/src`, `implementations/research_variants`, `experiments`
- Modify: README-файлы при необходимости

- [x] Проверить, что выбранные production-контракты лежат в `src/` соответствующих модулей.
- [x] Проверить, что альтернативы Barrett/FIOS/Comba/branchless/lazy/Claude/modexp/Merkle-DEEP-FRI не лежат в production-пути.
- [x] Если найден устаревший production-дубль, перенести его в `research_variants/` или удалить только при наличии актуального аналога.
- [x] Обновить пояснение в README о разделении production/research.

### Task 3: Актуализировать входную документацию

**Files:**
- Modify: `/Users/a.i.semenov/diploma-final/README.md`
- Modify: `/Users/a.i.semenov/diploma-final/docs/FINAL_DELIVERY_OVERVIEW_RU.md` при необходимости

- [x] Обновить структуру директорий.
- [x] Убрать устаревшие gas-числа или пометить их как ориентиры, если они не пересчитаны свежим прогоном.
- [x] Добавить явный блок “production-модули” и “исследовательские варианты”.
- [x] Добавить команды запуска для каждого основного блока.

### Task 4: Комментарии в ключевом коде

**Files:**
- Modify: production Solidity/Rust files only when comments are missing or unclear.

- [x] Проверить ключевые контракты MNT4 Article640.
- [x] Проверить ключевые контракты MNT6 Article640.
- [x] Проверить ключевые контракты lollipop-305.
- [x] Проверить базовые арифметические библиотеки MNT4/MNT6/lollipop.
- [x] Добавить русские комментарии к контрактам, публичным функциям, важным константам и нетривиальным hot-path участкам.
- [x] Не менять алгоритмы ради косметики, если это может изменить gas.

### Task 5: Скрипты и воспроизводимость

**Files:**
- Inspect/Modify: `/Users/a.i.semenov/diploma-final/scripts/*.sh`

- [x] Проверить, что `scripts/run_all.sh` запускает актуальные модули.
- [x] Проверить, что Merkle/FRI cost model присутствует в общем запуске.
- [x] Проверить, что скрипты не ссылаются на старую `/Users/a.i.semenov/mnt4-pairing-final`.
- [x] При необходимости добавить короткое текстовое пояснение в вывод скриптов.

### Task 6: Финальная проверка

**Files:**
- Generate: локальные логи в `.reports/` допускаются, но не считаются исходным кодом.

- [x] Запустить быстрый индексный аудит: `rg` по устаревшим путям, служебным unresolved-маркерам.
- [x] Запустить `./scripts/run_all.sh` либо, если полный прогон слишком дорогой, набор основных скриптов и явно перечислить, что не запускалось.
- [x] Запустить `cargo test` для `mnt_cycle_full`.
- [x] Проверить `git status --short` и перечислить фактически измененные файлы.
- [x] Сверить этот план: каждый пункт закрыт, либо указан объективный остаточный риск.

---

## Execution result

- Production/research split rechecked: selected production paths remain in module `src/`, rejected/archival variants are kept under `research_variants/` or `experiments/`.
- Duplicate legacy runner aliases were removed; canonical runner names are listed in the root README and final delivery overview.
- Full verification was run through `./scripts/run_all.sh`; after removing archival ignored lollipop tests, `./scripts/run_lollipop305_backend.sh` was rerun and passes without ignored tests.
- Static audits for stale paths and unresolved markers were rerun after cleanup.
