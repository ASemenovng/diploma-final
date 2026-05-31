# Lollipop-305 Cache Binding Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Добавить commitment и fixed code-shards режимы привязки трех lollipop-305 кэшей без дублирования арифметики.

**Architecture:** Текущий проверяющий контракт получает внутренние residue-функции. Исследовательская commitment-обертка проверяет доменно-разделенные хеши blob. Производственная fixed-shards обертка читает заранее зафиксированный runtime-код data-контрактов через `EXTCODECOPY`.

**Tech Stack:** Solidity 0.8.33, Foundry, Yul `EXTCODECOPY`, Rust fixtures.

---

### Task 1: Тесты поведения

**Files:**
- Create: `implementations/lollipop305/test/Lollipop305CacheBindingModes.t.sol`

- [ ] Добавить тесты принятия корректных fixtures двумя режимами.
- [ ] Добавить тесты отклонения подмененного blob.
- [ ] Добавить gas-тесты и расчет стоимости calldata.
- [ ] Запустить тест и убедиться, что сборка падает из-за отсутствующих оберток.

### Task 2: Общий внутренний путь

**Files:**
- Modify: `implementations/lollipop305/src/Lollipop305Article640Verifier.sol`

- [ ] Вынести тела трех residue-проверок во внутренние функции.
- [ ] Сохранить существующие внешние методы как совместимые обертки.
- [ ] Запустить прежние тесты lollipop-305.

### Task 3: Commitment-режим

**Files:**
- Create: `implementations/lollipop305/research_variants/Lollipop305CommittedCacheVerifier.sol`

- [ ] Добавить три immutable commitment-а.
- [ ] Добавить доменно-разделенные функции хеширования с точной проверкой размеров.
- [ ] Проверять хеш до тяжелой арифметики.

### Task 4: Fixed code-shards режим

**Files:**
- Create: `implementations/lollipop305/src/Lollipop305FixedShardsVerifier.sol`

- [ ] Зафиксировать массивы адресов в конструкторе.
- [ ] Читать runtime-код data-контрактов через `EXTCODECOPY`.
- [ ] Не принимать blob или shard-адреса в публичных verify-методах.

### Task 5: Измерения и документация

**Files:**
- Create: `implementations/lollipop305/docs/L12_CACHE_BINDING_MODES_RU.md`
- Modify: `scripts/run_lollipop305.sh`
- Modify: `WORK_CONTEXT.md`

- [ ] Запустить lollipop gas-report.
- [ ] Сравнить execution gas и calldata gas.
- [ ] Описать выбранный производственный режим.
- [ ] Запустить общую проверку проекта.
