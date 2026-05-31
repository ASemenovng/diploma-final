# MNT4-753 block-compressed Merkle/FRI verifier design

## Goal

Создать отдельный исследовательский модуль `implementations/mnt4_merkle_fri_block_compressed`, который проверяет уравнение сопряжений

\[
e(P,Q)e(-R,S)=1
\]

для фиксированных `Q,S`, не исполняя полный цикл Миллера в EVM. Модуль должен использовать блочное сжатие по пять шагов, Merkle-коммитменты, обычный FRI с Fiat-Shamir-преобразованием и строго маркированный профиль надежности `production-128`.

## Scope

Модуль является прозрачной EVM-инстанциацией полиномиальной проверки. Существующий `implementations/mnt4_merkle_deep_fri` не изменяется и служит reference baseline. Новый модуль не использует OOD-значения и DEEP-композицию.

## Mathematical relation

Для пяти последовательных переходов цикла Миллера:

\[
F_{t+5}=F_t^{32}G_t^Q(P)G_t^S(-R)c^{\kappa_t}.
\]

В базисе \(\mathbb F_{q^4}\simeq\mathbb F_q[Z]/(Z^4-13)\) backend строит частный многочлен `H_t(Z)` и фиксирует точное отношение:

\[
F_{t+5}(Z)-F_t(Z)^{32}G_t^Q(P;Z)G_t^S(-R;Z)c(Z)^{\kappa_t}=H_t(Z)(Z^4-13).
\]

Для всей трассы отношения батчируются separation challenge `beta`. Таблицы состояний, подготовленных делителей и quotient кодируются низкостепенными многочленами по переменной номера блока `X`. Контракт проверяет локальные раскрытия в случайных позициях и ordinary FRI proof их низкой степени.

## Profiles

- `benchmark-64q`: исследовательский профиль, не заявляется production-стойким.
- `production-640q`: профиль с консервативной доказанной оценкой надежности не хуже `2^-128`.

Для `N_LDE=2048`, `degree_bound=254`, `rho=254/2048` используется доказанная FRI-оценка:

\[
\delta_0\geq(1-3\rho)/4-1/\sqrt{N}-3N/|\mathbb F_q|.
\]

Soundness calculator обязан вычислять `delta0`, минимальное число повторений и итоговое число бит надежности. Профиль `production-640q` принимается только если итоговая оценка не хуже `128 bit`.

## Rust backend

Backend:

1. Загружает канонический fixture фиксированных `Q,S` и входных `P,R`.
2. Строит реальную residue-рекурсию MNT4.
3. Группирует пять шагов в один блок и проверяет блочное равенство против пошаговой рекурсии.
4. Дополняет `76` блоков до домена `128` строк.
5. Строит LDE длины `2048`, quotient и batched FRI polynomial.
6. Строит Merkle multiproof и packed proof.
7. Локально проверяет proof тем же порядком, который реализован в Solidity.
8. Сохраняет `metrics.json` и `security_report.json`.

## Solidity verifier

Verifier:

1. Проверяет каноничность и принадлежность `P,R` кривой.
2. Проверяет `c*cInv=1`.
3. Воспроизводит Fiat-Shamir transcript.
4. Потоково читает packed calldata без копирования полного proof в memory.
5. Проверяет Merkle multiproof с предварительно отсортированными раскрытиями.
6. Проверяет локальное композиционное отношение.
7. Проверяет ordinary FRI folding и финальный многочлен.
8. Возвращает `false` при любой подмене.

## EVM optimizations

- Блочное сжатие `d=5`.
- Только ordinary FRI, без OOD и DEEP arithmetic.
- Row-major leaves.
- Предварительно отсортированные позиции раскрытий.
- Merge-cursors вместо `_findPosition`.
- Yul scratch arena для Merkle hash path.
- `keccak256` непосредственно над scratch memory.
- Packed calldata и фиксированные размеры строк.
- Публичная оболочка превращает revert в `false`.

## Verification

Обязательны:

- Rust unit-тесты блочного отношения, quotient, FRI и сериализации.
- Негативные Rust-тесты для подмены состояния, quotient, Merkle frontier и FRI layer.
- Foundry acceptance test.
- Foundry rejection tests для публичных входов, корней, раскрытий, frontier и финального FRI-полинома.
- Изолированный gas-report для `64q`, `640q`, DEEP-FRI baseline и Article640 fixed-shards baseline.
