# MNT4 block-compressed Merkle/FRI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Реализовать отдельный block-compressed ordinary-FRI verifier для MNT4-753 и измерить его стоимость.

**Architecture:** Rust backend строит блочную residue-трассу, LDE, quotient, ordinary FRI proof и packed fixture. Solidity/Yul verifier воспроизводит transcript, потоково проверяет Merkle multiproof, локальные отношения и FRI folding.

**Tech Stack:** Rust, arkworks, Solidity 0.8.33, Yul, Foundry, Bash.

---

### Task 1: Bootstrap isolated module
- [ ] Скопировать минимальную структуру reference DEEP-FRI-модуля без артефактов и удалить DEEP-specific API.
- [ ] Добавить README с честным статусом experimental verifier.

### Task 2: Rust soundness calculator
- [ ] Добавить failing unit tests для `delta0`, минимального числа запросов и отказа небезопасного production-профиля.
- [ ] Реализовать доказанную FRI-оценку и JSON-report.
- [ ] Проверить `benchmark-64q` как небезопасный и `production-640q` как >=128 bit.

### Task 3: Rust block-compressed trace
- [ ] Добавить failing tests для равенства пяти пошаговых переходов одному блочному переходу.
- [ ] Реализовать grouping `376 -> 76 -> 128`.
- [ ] Добавить граничные отношения и padding selectors.

### Task 4: Rust ordinary FRI proof
- [ ] Добавить failing tests для honest proof и подмененных quotient/Merkle/FRI данных.
- [ ] Реализовать LDE, quotient, Merkle trees, ordinary FRI folding, Fiat-Shamir и packed serialization.
- [ ] Сгенерировать fixture для `64q` и `640q`.

### Task 5: Solidity streaming verifier
- [ ] Добавить failing Foundry acceptance test до создания verifier-а.
- [ ] Реализовать packed parser, transcript и field wrappers.
- [ ] Реализовать in-place Merkle multiproof без динамических массивов в цикле уровней.
- [ ] Реализовать локальное отношение и ordinary FRI folding.

### Task 6: Solidity negative tests
- [ ] Проверить отказ при подмене `P`, `R`, `c`, `cInv`, roots, openings, frontier hashes и финального FRI-полинома.

### Task 7: Reports
- [ ] Добавить `scripts/run_report.sh`.
- [ ] Измерить execution gas, calldata bytes/gas, total gas, proving ms и peak RSS.
- [ ] Сравнить Article640, DEEP-FRI `32q`, ordinary FRI `64q`, ordinary FRI `640q`.
- [ ] Обновить WORK_CONTEXT.md и итоговый отчет.
