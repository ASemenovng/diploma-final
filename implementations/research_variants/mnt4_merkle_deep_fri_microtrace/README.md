# MNT4-753 Merkle/DEEP-FRI microtrace verifier

> Статус: архивный исследовательский вариант. Модуль воспроизводит
> консервативную Merkle/DEEP-FRI микротрассу, но не является рекомендуемым
> production verifier-ом и не используется как итоговая оценка Merkle/FRI-пути.

Модуль реализует экспериментальную замену прямого исполнения цикла Миллера
проверкой пошаговой микротрассы. Он предназначен для воспроизводимого сравнения
с `implementations/article640_mnt4`, а не для непосредственного развертывания в
Ethereum mainnet.

## Что проверяется

Для фиксированных точек `Q,S` и входных точек `P,R` проверяется уравнение

```text
e(P,Q) * e(-R,S) = 1.
```

Rust backend строит residue-рекурсию из `1500` реальных микроопераций, дополняет
ее до трассы длины `2048`, строит quotient, Merkle-деревья и неинтерактивное
DEEP-FRI доказательство. Solidity-verifier воспроизводит Fiat-Shamir transcript,
проверяет OOD-равенство, компактные Merkle-multiproof и FRI-folding.

## Быстрый запуск

```bash
./scripts/run_report.sh
```

Скрипт:

1. запускает Rust unit-тесты;
2. пересобирает фиксированные артефакты и оба proof-профиля;
3. запускает Foundry acceptance/rejection tests;
4. снимает изолированные gas-report для двух профилей и Article640 baseline;
5. печатает краткую таблицу размеров proof и метрик backend-а.

## Профили

| Профиль | Число запросов | Назначение |
|---|---:|---|
| `benchmark-32q` | 32 | воспроизводимый исследовательский gas-бенчмарк |
| `conservative-128q` | 128 | консервативный профиль для оценки роста стоимости |

Ни один профиль не объявлен production-стойким без независимого анализа
soundness полной DEEP-FRI схемы.

## Артефакты

`rust/microtrace_backend/artifacts/<profile>/` содержит:

```text
fixed_config.json
fixed_table_h.bin
fixed_table_lde.bin
root_fixed.hex
fixture_public_inputs.json
proof.bin
proof.hex
proof_debug.json
security_report.json
metrics.json
solidity_fixture.hex
```

Подробные результаты приведены в
`docs/MNT4_MERKLE_DEEP_FRI_RESULTS_RU.md`.
