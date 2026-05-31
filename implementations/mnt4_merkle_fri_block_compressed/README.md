# MNT4-753 block-compressed Merkle/FRI verifier

Статус: математический пробел устранен формальной спецификацией:

[`docs/MNT4_BLOCK_COMPRESSED_ORDINARY_FRI_FORMAL_SPEC_RU.md`](docs/MNT4_BLOCK_COMPRESSED_ORDINARY_FRI_FORMAL_SPEC_RU.md).

Целевая оптимизированная архитектура описана в:

[`docs/MNT4_NATIVE_FIELD_OPTIMIZED_MERKLE_FRI_SPEC_RU.md`](docs/MNT4_NATIVE_FIELD_OPTIMIZED_MERKLE_FRI_SPEC_RU.md).

## Реализованный этап N1

Rust-модель стоимости находится в:

```text
rust/native_fri_cost_model
```

Она:

1. численно проверяет ordinary-FRI soundness-параметры;
2. перебирает FRI layer-skipping schedules и размер последнего слоя;
3. моделирует бинарный Merkle multiproof с дедупликацией frontier;
4. считает обязательную calldata и базовые `Fq`-операции;
5. строит lower-bound и expected gas-оценки;
6. выводит sensitivity-таблицу для еще не измеренных Solidity-параметров;
7. отделяет строгий ordinary-FRI профиль от экспериментального DEEP-FRI
   диапазона.

Запуск:

```bash
./scripts/run_cost_model.sh
```

Результаты сохраняются в:

```text
artifacts/native-field-cost-model/report.json
docs/N1_NATIVE_FIELD_COST_MODEL_RESULTS_RU.md
```

Solidity verifier не входит в N1. Его реализация начинается только после
stop/go решения по Rust-модели.
