# MNT4 Native-Field Merkle/FRI Cost Model Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Реализовать воспроизводимую Rust-модель стоимости нативной MNT4 Merkle/FRI-схемы и принять stop/go-решение до написания Solidity verifier-а.

**Architecture:** Модель отделяет доказанную ordinary-FRI soundness-оценку от экспериментальных DEEP-FRI профилей. Для каждого профиля она перебирает FRI layer-skipping schedules, считает Merkle multiproof frontier, calldata, базовую арифметику `Fq`, технический overhead и выводит диапазон чувствительности для еще не измеренных Solidity-параметров.

**Tech Stack:** Rust 1.83 без внешних crate-зависимостей, `cargo test`, JSON/Markdown отчеты.

---

### Task 1: Проверяемая soundness-модель ordinary FRI

**Files:**
- Create: `implementations/mnt4_merkle_fri_block_compressed/rust/native_fri_cost_model/Cargo.toml`
- Create: `implementations/mnt4_merkle_fri_block_compressed/rust/native_fri_cost_model/src/lib.rs`
- Create: `implementations/mnt4_merkle_fri_block_compressed/rust/native_fri_cost_model/src/security.rs`
- Test: `implementations/mnt4_merkle_fri_block_compressed/rust/native_fri_cost_model/tests/cost_model.rs`

- [x] Написать failing-тесты для `rho=1/8`, `delta0`, минимальных `544` запросов и production-профиля `576`.
- [x] Запустить `cargo test` и подтвердить ожидаемый `RED`.
- [x] Реализовать калькулятор по формуле формальной спецификации.
- [x] Запустить `cargo test` и подтвердить `GREEN`.

### Task 2: FRI schedule и Merkle multiproof

**Files:**
- Create: `implementations/mnt4_merkle_fri_block_compressed/rust/native_fri_cost_model/src/fri.rs`
- Modify: `implementations/mnt4_merkle_fri_block_compressed/rust/native_fri_cost_model/tests/cost_model.rs`

- [x] Написать failing-тесты для multiproof frontier и полного сворачивания домена `32768 -> 16`.
- [x] Реализовать детерминированные запросы, группировку раскрытий и подсчет frontier.
- [x] Перебрать schedules с арностями `2,4,8,16`.
- [x] Запустить `cargo test`.

### Task 3: Полная gas-модель и stop/go

**Files:**
- Create: `implementations/mnt4_merkle_fri_block_compressed/rust/native_fri_cost_model/src/model.rs`
- Modify: `implementations/mnt4_merkle_fri_block_compressed/rust/native_fri_cost_model/tests/cost_model.rs`

- [x] Написать failing-тесты для декомпозиции calldata, FRI arithmetic и stop/go.
- [x] Реализовать нижнюю и ожидаемую оценки с явными допущениями.
- [x] Добавить ordinary strict profile и экспериментальные DEEP-FRI sensitivity profiles.
- [x] Запустить `cargo test`.

### Task 4: Машиночитаемый и читаемый отчеты

**Files:**
- Create: `implementations/mnt4_merkle_fri_block_compressed/rust/native_fri_cost_model/src/report.rs`
- Create: `implementations/mnt4_merkle_fri_block_compressed/rust/native_fri_cost_model/src/main.rs`
- Create: `implementations/mnt4_merkle_fri_block_compressed/scripts/run_cost_model.sh`
- Generate: `implementations/mnt4_merkle_fri_block_compressed/artifacts/native-field-cost-model/report.json`
- Generate: `implementations/mnt4_merkle_fri_block_compressed/docs/N1_NATIVE_FIELD_COST_MODEL_RESULTS_RU.md`

- [x] Написать failing-тест на обязательные секции отчета.
- [x] Реализовать JSON и Markdown serialization.
- [x] Запустить `cargo run --release`.
- [x] Проверить, что отчет явно отделяет строгий профиль от экспериментальных.

### Task 5: Финальная проверка и checkpoint

- [x] Запустить `cargo fmt --check`.
- [x] Запустить `cargo test`.
- [x] Запустить `scripts/run_cost_model.sh`.
- [x] Обновить `WORK_CONTEXT.md`.
- [x] Проверить `git diff --check`.
- [x] Создать checkpoint-коммит N1.
