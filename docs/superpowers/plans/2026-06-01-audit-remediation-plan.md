# Audit Remediation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Закрыть подтвержденные ошибки аудита: валидацию G1, MNT6 fixed-shards parity, счетчики MNT-cycle, полный naive Tate baseline и запуск ordinary-FRI модели из корневого runner-а.

**Architecture:** Fixed-G2 кэши остаются доверенной предрегистрацией. Пользовательские G1-точки проверяются перед тяжелой арифметикой. MNT6 получает отдельный packed streaming fixed-shards verifier с двумя G2-кэшами, общим multi-Miller аккумулятором и Article640 residue-проверкой. Для MNT6 используется отдельный знак: `r=q-N`, поэтому `c^{-r}=c^{N-q}`.

**Tech Stack:** Solidity 0.8.33, Foundry, Yul hot paths, Rust, arkworks.

---

### Task 1: Исправить MNT-cycle accounting

**Files:**
- Modify: `mnt_cycle_full/src/lib.rs`
- Modify: `mnt_cycle_full/tests/cycle_reference.rs`

- [ ] Добавить тесты точных счетчиков и ожидаемых итогов `24_126`, `48_942`.
- [ ] Запустить `cargo test --release` и увидеть падение.
- [ ] Исправить счетчики и комментарии.
- [ ] Повторить `cargo test --release`.
- [ ] Зафиксировать чекпоинт git.

### Task 2: Добавить MNT4 G1 validation

**Files:**
- Create: `arithmetic/mnt4_3limb/src/MNT4CurveChecks.sol`
- Modify: `implementations/article640_mnt4/src/MNT4Article640FixedShardsVerifier.sol`
- Modify: `implementations/article640_mnt4/src/MNT4Article640HotCommitmentVerifier.sol`
- Modify: `implementations/article640_mnt4/test/MNT4Article640HotCommitmentVerifier.t.sol`

- [ ] Написать отрицательные тесты подмены координат `P` и `R`.
- [ ] Запустить targeted Foundry test и увидеть падение.
- [ ] Реализовать canonical limb check и `y^2 = x^3 + 2x + b`.
- [ ] Вызывать проверку перед тяжелой арифметикой.
- [ ] Снять обновленные gas-строки.
- [ ] Зафиксировать чекпоинт git.

### Task 3: Добавить MNT6 fixture двух пар

**Files:**
- Modify: `implementations/article640_mnt6/rust/mnt6_article640_backend/src/lib.rs`
- Modify: `implementations/article640_mnt6/rust/mnt6_article640_backend/src/bin/gen_fixture.rs`
- Modify: `implementations/article640_mnt6/fixtures/mnt6_fixture.json`

- [ ] Добавить Rust-тест билинейного уравнения `e(2G1,G2)=e(G1,2G2)`.
- [ ] Расширить fixture двумя prepared-кэшами и residue witness.
- [ ] Перегенерировать fixture.
- [ ] Запустить `cargo test --release`.
- [ ] Зафиксировать чекпоинт git.

### Task 4: Реализовать MNT6 packed streaming fixed-shards verifier

**Files:**
- Modify: `arithmetic/mnt6_3limb/src/MNT6AteLoop.sol`
- Create: `implementations/article640_mnt6/src/MNT6Article640FixedShardsVerifier.sol`
- Create: `implementations/article640_mnt6/test/MNT6Article640FixedShardsVerifier.t.sol`

- [ ] Написать positive и negative Foundry-тесты.
- [ ] Запустить targeted test и увидеть падение компиляции из-за отсутствующего verifier-а.
- [ ] Реализовать потоковый packed reader code-shards.
- [x] Проверить возможность переноса MNT4-style residue accumulator и вывести
      корректное MNT6-отношение `F*c^(N-q)=1`.
- [x] Реализовать общий residue accumulator двух пар с одним возведением в
      квадрат на раунд.
- [x] Добавить G1 validation через `MNT6CurveChecks`.
- [x] Проверить корректный fixture и подмены.
- [x] Снять gas-report и runtime size.
- [ ] Зафиксировать чекпоинт git.

### Task 5: Разделить полный reference-контур и naive Tate cost model

**Files:**
- Modify: `baselines/naive_tate_mnt4/src/MNT4TatePairingNaive.sol`
- Modify: `baselines/naive_tate_mnt4/test/MNT4TatePairingNaive.t.sol`
- Create: `baselines/naive_tate_mnt4/README.md`

- [x] Проверить фактический объем текущего baseline.
- [x] Явно назвать модуль cost model, а не полным исполняемым Tate-вызовом.
- [x] Зафиксировать состав измеряемых математически корректных микроблоков.
- [x] Сослаться на полный исполняемый reference-контур
      `implementations/full_onchain_mnt4`.
- [ ] Зафиксировать чекпоинт git.

### Task 6: Подключить ordinary-FRI cost model к runner-у

**Files:**
- Modify: `scripts/run_all.sh`
- Create: `scripts/run_mnt4_fri_cost_model.sh`
- Create: `scripts/run_audit_all.sh`

- [ ] Добавить shell-проверку наличия FRI-строк в общем отчете.
- [ ] Подключить ordinary-FRI cost model.
- [ ] Оставить архивный DEEP-FRI отдельным opt-in этапом.
- [ ] Выполнить `bash -n scripts/*.sh`.
- [ ] Зафиксировать чекпоинт git.

### Task 7: Полная верификация и обновление отчетов

**Files:**
- Modify: `docs/PRACTICAL_IMPLEMENTATION_FULL_AUDIT_REPORT_RU.md`
- Modify: `docs/PRACTICAL_IMPLEMENTATION_AUDIT_TRACEABILITY_MATRIX_RU.md`
- Modify: `docs/FINAL_DIPLOMA_COMPLETION_PLAN_RU.md`
- Modify: `WORK_CONTEXT.md`

- [ ] Выполнить `./scripts/run_all.sh`.
- [ ] Выполнить расширенные targeted тесты и fixture cross-check.
- [ ] Обновить gas-таблицы, статусы и ограничения.
- [ ] Выполнить `git diff --check`.
- [ ] Зафиксировать финальный чекпоинт git.
