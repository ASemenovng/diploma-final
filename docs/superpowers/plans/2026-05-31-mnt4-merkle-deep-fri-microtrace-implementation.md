# MNT4 Merkle/DEEP-FRI Microtrace Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Реализовать отдельный воспроизводимый эксперимент, в котором прямой on-chain цикл Миллера MNT4-753 заменяется проверкой пошаговой микротрассы через AIR, Merkle-multiproof и DEEP-FRI.

**Architecture:** Rust backend формирует фиксированную таблицу для двух фиксированных точек `Q,S`, строит witness-трассу для публичных `P,R,c,cInv`, вычисляет quotient polynomial, DEEP-композицию, FRI-слои и единый `proof.bin`. Solidity verifier не доверяет backend-у: он воспроизводит Fiat--Shamir transcript, проверяет публичные входы, компактные Merkle-multiproof, OOD-равенство, локальную DEEP-композицию и восемь FRI-сверток. Исходный `implementations/article640_mnt4` остается неизменяемым baseline.

**Tech Stack:** Rust 1.83, `arkworks 0.5`, Foundry 1.5, Solidity 0.8.33, общая библиотека трехсловной арифметики MNT4-753 из `arithmetic/mnt4_3limb`.

---

### Task 1: Bootstrap нового модуля

**Files:**
- Create: `implementations/mnt4_merkle_deep_fri/rust/microtrace_backend/Cargo.toml`
- Create: `implementations/mnt4_merkle_deep_fri/foundry.toml`
- Create: `implementations/mnt4_merkle_deep_fri/README.md`

- [ ] Создать отдельную директорию, не изменяя baseline.
- [ ] Подключить `ark-ff`, `ark-ec`, `ark-poly`, `ark-mnt4-753`, `sha3`, `serde`, `serde_json`, `hex`, `anyhow`.
- [ ] Подключить Foundry remapping `@arith-mnt4/` к общей оптимизированной арифметике.

### Task 2: Rust schedule, fixed table и trace

**Files:**
- Create: `rust/microtrace_backend/src/config.rs`
- Create: `rust/microtrace_backend/src/schedule.rs`
- Create: `rust/microtrace_backend/src/trace.rs`
- Test: `rust/microtrace_backend/src/lib.rs`

- [ ] Написать тест точного расписания: `1500` реальных операций, `547` HOLD-переходов и одна STOP-строка.
- [ ] Написать тест `kappa_final = -r`.
- [ ] Реализовать нормализацию sparse-линий из коэффициентов arkworks-compatible hot path.
- [ ] Реализовать трассу `F[r+1]` для операций `SQR`, `DBL`, `ADD`, `MUL_C`, `MUL_CINV`, `MUL_FROB_CINV`, `HOLD`.
- [ ] Проверить финальную строку `F=1` на невырожденной билинейной fixture.

### Task 3: Rust polynomial layer

**Files:**
- Create: `rust/microtrace_backend/src/polynomial.rs`
- Create: `rust/microtrace_backend/src/air.rs`
- Test: `rust/microtrace_backend/src/lib.rs`

- [ ] Написать тесты порядка домена `N=2048`, LDE-домена `M=32768` и coset-условия.
- [ ] Реализовать FFT-интерполяцию trace/fixed столбцов.
- [ ] Реализовать `44` AIR-ограничения и объединение через `beta`.
- [ ] Проверить делимость объединенного числителя на `Z_H=X^N-1`.
- [ ] Разделить quotient polynomial на два сегмента степени `<N`.

### Task 4: Rust Merkle, transcript, DEEP и FRI

**Files:**
- Create: `rust/microtrace_backend/src/merkle.rs`
- Create: `rust/microtrace_backend/src/transcript.rs`
- Create: `rust/microtrace_backend/src/deep_fri.rs`
- Create: `rust/microtrace_backend/src/security.rs`
- Test: `rust/microtrace_backend/src/lib.rs`

- [ ] Реализовать доменные разделители листьев и внутренних вершин.
- [ ] Реализовать bit-reversed раскладку листьев и детерминированный compact multiproof.
- [ ] Реализовать Fiat--Shamir transcript в точном порядке спецификации.
- [ ] Реализовать OOD-проверку в `z`, DEEP polynomial и восемь FRI-fold.
- [ ] Реализовать Rust verifier и проверить, что он принимает обе fixture и отвергает побитовую подмену proof.

### Task 5: Rust serialization и artifacts

**Files:**
- Create: `rust/microtrace_backend/src/serialize.rs`
- Create: `rust/microtrace_backend/src/bin/build_fixed_config.rs`
- Create: `rust/microtrace_backend/src/bin/prove_fixture.rs`
- Create: `rust/microtrace_backend/src/bin/inspect_proof.rs`

- [ ] Реализовать бинарный формат `proof.bin` без хвостовых байтов.
- [ ] Сформировать `fixed_config.json`, `fixed_table_h.bin`, `fixed_table_lde.bin`, `root_fixed.hex`.
- [ ] Сформировать `fixture_public_inputs.json`, `proof.bin`, `proof_debug.json`, `security_report.json`, `metrics.json`.
- [ ] Проверить round-trip serializer/parser.

### Task 6: Solidity verifier

**Files:**
- Create: `src/MNT4DeepFriField.sol`
- Create: `src/MNT4DeepFriMerkle.sol`
- Create: `src/MNT4DeepFriTranscript.sol`
- Create: `src/MNT4MerkleDeepFriVerifier.sol`
- Test: `test/MNT4MerkleDeepFriVerifier.t.sol`

- [ ] Сначала написать Foundry-тест, который не компилируется до появления verifier.
- [ ] Реализовать строгий parser канонических `Fq` и полного proof layout.
- [ ] Реализовать transcript и вывод запросов.
- [ ] Реализовать compact Merkle-multiproof для всех деревьев.
- [ ] Реализовать проверку `c*cInv=1`, OOD quotient identity, DEEP evaluations и всех FRI-fold.
- [ ] Реализовать два профиля `benchmark-32q` и `conservative-128q`.

### Task 7: Негативные тесты и газ

**Files:**
- Create: `test/MNT4MerkleDeepFriNegative.t.sol`
- Create: `test/MNT4MerkleDeepFriGas.t.sol`
- Create: `scripts/run_gas_report.sh`
- Create: `docs/MNT4_MERKLE_DEEP_FRI_RESULT_RU.md`

- [ ] Проверить положительные fixture в Rust и Solidity.
- [ ] Проверить отклонение подмен `P`, `R`, `c`, `cInv`, trace leaf, fixed leaf, quotient leaf, OOD, DEEP root, FRI sibling, final coefficient, неканонического поля и хвостовых байтов.
- [ ] Снять газ для профилей `32q` и `128q`.
- [ ] Сравнить с прямым residue baseline `article640_mnt4`.
- [ ] Зафиксировать честный вывод: уменьшает ли Merkle/DEEP-FRI путь стоимость относительно прямого цикла Миллера и какой вклад дает calldata.

