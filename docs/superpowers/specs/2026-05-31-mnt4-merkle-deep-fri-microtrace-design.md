# MNT4 Merkle/DEEP-FRI microtrace design

Основная спецификация:

```text
docs/MNT4_MERKLE_DEEP_FRI_MICROTRACE_SPEC_RU.md
```

## Design decision

Для экспериментальной замены прямого on-chain цикла Миллера выбран пошаговый вариант без блочного сжатия:

```text
one AIR row = one Fq4 accumulator micro-operation
```

Это намеренно консервативный первый вариант. Он проще для аудита, чем блочная трасса, и позволяет измерить нижнюю инженерную ценность Merkle/DEEP-FRI-подхода без скрытых агрегатов.

## Fixed schedule

```text
376 * (SQR + DBL_P + DBL_R)
+ 123 * (ADD_P + ADD_R + MUL_C_OR_CINV)
+ (ADD_P + ADD_R + MUL_FROB_CINV)
= 1500 micro-operations
```

Трасса дополняется до `2048` строк:

```text
1500 real operations
1 final state row
547 HOLD transitions
1 STOP row
```

## Trusted fixed cache

Точки `Q,S` фиксированы. Контракт хранит только `rootFixed`. Строки подготовленных линий и фиксированного расписания раскрываются Merkle-путями и связываются с низкостепенным продолжением через DEEP polynomial.

## Profiles

```text
benchmark-32q: gas experiment
conservative-128q: conservative measurement profile
```

Точная численная soundness-оценка должна вычисляться Rust-калькулятором из выбранной теоремы DEEP-FRI и сохраняться в `security_report.json`.

## Compact proof layout

В чистовом формате используются не независимые Merkle-пути, а детерминированный multiproof. Наборы листьев и frontier-вершин выводятся verifier-ом из Fiat-Shamir queries, поэтому каждый frontier-хеш передается не более одного раза на дерево. Независимые пути остаются только верхней оценкой размера proof.

## Approval

Архитектура согласована пользователем 2026-05-31. Следующий отдельный этап после ревью спецификации: сформировать implementation plan и реализовать модуль.
