# MNT4 Merkle Modules Cleanup Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [x]`) syntax for tracking.

**Goal:** Отделить актуальную MNT4 Merkle/FRI модель стоимости от архивного DEEP-FRI прототипа и сохранить воспроизводимость обоих результатов.

**Architecture:** Актуальный модуль переименовывается в `mnt4_merkle_fri_cost_model`, поскольку он содержит спецификацию и Rust-калькулятор, а не production-контракт. Исполняемый DEEP-FRI прототип целиком переносится в `implementations/research_variants`, очищается от пересобираемых файлов и получает явную архивную маркировку. Поддерживаемые README, скрипты и контекст обновляются под новую структуру.

**Tech Stack:** Git, Bash, Rust/Cargo, Foundry, Solidity 0.8.33, Markdown.

---

## Карта изменяемых файлов

| Путь | Назначение |
|---|---|
| `implementations/mnt4_merkle_fri_cost_model/` | Актуальная математическая спецификация и воспроизводимая Rust-модель стоимости. |
| `implementations/research_variants/README.md` | Реестр архивных исследовательских вариантов. |
| `implementations/research_variants/mnt4_merkle_deep_fri_microtrace/` | Архивный воспроизводимый Solidity/Rust DEEP-FRI прототип. |
| `implementations/research_variants/mnt4_merkle_deep_fri_microtrace/foundry.toml` | Относительные импорты общей MNT4-арифметики после переноса. |
| `implementations/research_variants/mnt4_merkle_deep_fri_microtrace/scripts/run_report.sh` | Команда воспроизведения архивного отчета после переноса. |
| `README.md` | Навигация по актуальным и исследовательским модулям. |
| `WORK_CONTEXT.md` | Фиксация выбранной границы результата. |

### Task 1: Переименовать актуальную модель стоимости

**Files:**
- Move: `implementations/mnt4_merkle_fri_block_compressed/`
- Create: `implementations/mnt4_merkle_fri_cost_model/`
- Modify: `implementations/mnt4_merkle_fri_cost_model/README.md`

- [x] **Step 1: Переименовать каталог средствами git**

```bash
git mv implementations/mnt4_merkle_fri_block_compressed \
  implementations/mnt4_merkle_fri_cost_model
```

- [x] **Step 2: Обновить README актуального модуля**

В `implementations/mnt4_merkle_fri_cost_model/README.md` явно зафиксировать:

```markdown
# MNT4 Merkle/FRI: модель стоимости

Этот каталог содержит математическую спецификацию и воспроизводимую Rust-модель
стоимости. Он не содержит готовый production Solidity-verifier.
```

Сохранить существующие команды запуска, заменив старое имя каталога новым.

- [x] **Step 3: Проверить воспроизводимость модели**

Run:

```bash
cd implementations/mnt4_merkle_fri_cost_model
./scripts/run_cost_model.sh
```

Expected: скрипт завершается успешно и печатает строгий ordinary-FRI профиль с оценкой gas.

- [x] **Step 4: Проверить diff**

Run:

```bash
git diff --check
```

Expected: пустой вывод.

- [x] **Step 5: Зафиксировать перенос**

```bash
git add implementations/mnt4_merkle_fri_cost_model
git commit -m "refactor: rename MNT4 Merkle FRI cost model"
```

### Task 2: Перенести DEEP-FRI прототип в research_variants

**Files:**
- Move: `implementations/mnt4_merkle_deep_fri/`
- Create: `implementations/research_variants/mnt4_merkle_deep_fri_microtrace/`
- Create: `implementations/research_variants/README.md`
- Modify: `implementations/research_variants/mnt4_merkle_deep_fri_microtrace/README.md`
- Modify: `implementations/research_variants/mnt4_merkle_deep_fri_microtrace/foundry.toml`

- [x] **Step 1: Удалить только пересобираемые каталоги**

```bash
rm -rf \
  implementations/mnt4_merkle_deep_fri/cache \
  implementations/mnt4_merkle_deep_fri/out \
  implementations/mnt4_merkle_deep_fri/rust/microtrace_backend/target
```

- [x] **Step 2: Перенести архивный модуль**

```bash
mkdir -p implementations/research_variants
git mv implementations/mnt4_merkle_deep_fri \
  implementations/research_variants/mnt4_merkle_deep_fri_microtrace
```

- [x] **Step 3: Исправить Foundry-пути**

В `implementations/research_variants/mnt4_merkle_deep_fri_microtrace/foundry.toml`
заменить:

```toml
libs = ["../../lib"]
remappings = ["@arith-mnt4/=../../arithmetic/mnt4_3limb/src/"]
allow_paths = ["../../arithmetic"]
```

на:

```toml
libs = ["../../../lib"]
remappings = ["@arith-mnt4/=../../../arithmetic/mnt4_3limb/src/"]
allow_paths = ["../../../arithmetic"]
```

- [x] **Step 4: Добавить реестр исследовательских вариантов**

Создать `implementations/research_variants/README.md`:

```markdown
# Исследовательские варианты

В этом каталоге находятся воспроизводимые эксперименты, которые нужны для
обоснования выводов диплома, но не являются выбранными финальными реализациями.

| Каталог | Статус |
|---|---|
| `mnt4_merkle_deep_fri_microtrace/` | Консервативный Solidity/Rust прототип пошаговой Merkle/DEEP-FRI микротрассы. Сохранен как отрицательный воспроизводимый результат. |
```

- [x] **Step 5: Явно отметить архивный статус DEEP-FRI README**

В начале `implementations/research_variants/mnt4_merkle_deep_fri_microtrace/README.md`
добавить:

```markdown
> Статус: архивный исследовательский вариант. Модуль воспроизводит
> консервативную Merkle/DEEP-FRI микротрассу, но не является рекомендуемым
> production verifier-ом и не используется как итоговая оценка Merkle/FRI-пути.
```

- [x] **Step 6: Проверить Rust-бэкенд**

Run:

```bash
cd implementations/research_variants/mnt4_merkle_deep_fri_microtrace/rust/microtrace_backend
cargo test --release
```

Expected: все Rust-тесты проходят.

- [x] **Step 7: Проверить Foundry-модуль**

Run:

```bash
cd implementations/research_variants/mnt4_merkle_deep_fri_microtrace
forge test -vv
```

Expected: все Foundry-тесты проходят.

- [x] **Step 8: Зафиксировать перенос**

```bash
git add implementations/research_variants
git commit -m "refactor: archive MNT4 Merkle DEEP FRI microtrace"
```

### Task 3: Улучшить русские комментарии архивного прототипа

**Files:**
- Modify: `implementations/research_variants/mnt4_merkle_deep_fri_microtrace/src/MNT4MerkleDeepFriVerifier.sol`
- Modify: `implementations/research_variants/mnt4_merkle_deep_fri_microtrace/src/MNT4DeepFriField.sol`
- Modify: `implementations/research_variants/mnt4_merkle_deep_fri_microtrace/src/MNT4DeepFriMerkle.sol`
- Modify: `implementations/research_variants/mnt4_merkle_deep_fri_microtrace/src/MNT4DeepFriTranscript.sol`

- [x] **Step 1: Добавить комментарии без изменения алгоритма**

Добавить русские `///`-комментарии:

- к назначению каждого файла;
- к публичным функциям;
- к основным внутренним этапам `verify`;
- к константам размеров домена и FRI-слоев;
- к сериализации и доменному разделению transcript.

Не менять сигнатуры, выражения и порядок вычислений.

- [x] **Step 2: Проверить отсутствие функционального diff в байткоде**

Run:

```bash
cd implementations/research_variants/mnt4_merkle_deep_fri_microtrace
forge test -vv
```

Expected: те же тесты проходят.

- [x] **Step 3: Зафиксировать комментарии**

```bash
git add implementations/research_variants/mnt4_merkle_deep_fri_microtrace/src
git commit -m "docs: explain archived MNT4 DEEP FRI verifier"
```

### Task 4: Обновить навигацию и итоговый контекст

**Files:**
- Modify: `README.md`
- Modify: `WORK_CONTEXT.md`
- Modify: `implementations/research_variants/mnt4_merkle_deep_fri_microtrace/scripts/run_report.sh`

- [x] **Step 1: Исправить относительный baseline-путь архивного отчета**

В `implementations/research_variants/mnt4_merkle_deep_fri_microtrace/scripts/run_report.sh`
использовать путь к Article640 baseline относительно нового каталога:

```bash
ARTICLE640_DIR="$MODULE_DIR/../../article640_mnt4"
```

- [x] **Step 2: Дополнить корневой README**

Добавить в таблицу модулей:

```markdown
| `implementations/mnt4_merkle_fri_cost_model/` | Актуальная математическая спецификация и Rust-модель стоимости блочно-сжатого ordinary-FRI пути. |
| `implementations/research_variants/` | Воспроизводимые, но не выбранные исследовательские варианты. |
```

- [x] **Step 3: Обновить WORK_CONTEXT**

Добавить запись:

```markdown
## 2026-06-01: очистка MNT4 Merkle/FRI модулей

- Актуальная модель стоимости находится в `implementations/mnt4_merkle_fri_cost_model`.
- Архивный исполняемый DEEP-FRI прототип перенесен в
  `implementations/research_variants/mnt4_merkle_deep_fri_microtrace`.
- Для итогового текста используется строгая ordinary-FRI модель стоимости:
  ожидаемый порядок `50--70M gas`; полная реализация не продолжается, поскольку
  она не дает принципиального выигрыша относительно Article640 fixed-shards.
```

- [x] **Step 4: Запустить архивный отчет**

Run:

```bash
cd implementations/research_variants/mnt4_merkle_deep_fri_microtrace
./scripts/run_report.sh
```

Expected: Rust fixtures пересобираются, Foundry-проверки проходят, отчет печатает benchmark- и conservative-профили.

- [x] **Step 5: Проверить актуальные ссылки**

Run:

```bash
rg -n "implementations/mnt4_merkle_deep_fri|implementations/mnt4_merkle_fri_block_compressed" \
  README.md WORK_CONTEXT.md scripts implementations \
  -g '!**/target/**' -g '!**/out/**' -g '!**/cache/**'
```

Expected: нет поддерживаемых runtime-ссылок на старые каталоги. Допустимы только исторические упоминания в старых отчетах, если они явно описывают прежний этап.

- [x] **Step 6: Выполнить финальную проверку**

Run:

```bash
git diff --check
git status --short
```

Expected: `git diff --check` не печатает ошибок; `git status --short` показывает только ожидаемые изменения документации и скрипта.

- [x] **Step 7: Зафиксировать документацию**

```bash
git add README.md WORK_CONTEXT.md implementations/research_variants
git commit -m "docs: document MNT4 Merkle research variants"
```
