# F6C. Полная MNT6 on-chain/article640 verifier реализация

## 1. Причина добавления этапа

Текущий F6B закрывает только предварительный MNT4/MNT6 cycle-native слой: параметры цикла, reference pairing через arkworks и accounting relation-фрагментов. Этого недостаточно, если требование к работе состоит в том, что для MNT6 должна быть проделана такая же практическая работа, как для MNT4.

Поэтому добавляется отдельный этап F6C: полная MNT6-753 реализация on-chain/article640 verifier по аналогии с MNT4.

## 2. Что значит “аналогично MNT4”

Для MNT4 сейчас есть три уровня:

1. оптимизированная длинная арифметика `Fq/Fq2/Fq4`;
2. полный on-chain / prepared sparse Miller path;
3. article640-style verifier для уравнения сопряжений с prepared lines и residue-style проверкой финальной экспоненты.

Для MNT6 нужно реализовать тот же класс результатов, но с другой башней расширений:

```text
MNT4: Fq -> Fq2 -> Fq4
MNT6: Fq -> Fq3 -> Fq6
```

## 3. DoD F6C

Этап F6C считается закрытым только если выполнены все пункты ниже.

### 3.1 Solidity/Yul arithmetic

Нужно реализовать:

- `BigIntMNT6.sol`: 753-битная Montgomery/CIOS арифметика по модулю `Fq(MNT6)=Fr(MNT4)`;
- `MNT6Fp.sol`: ABI/wrapper над базовым полем;
- `MNT6Fq3.sol`: арифметика расширения `Fq3 = Fq[v]/(v^3 - 11)`;
- `MNT6Fq6.sol`: арифметика расширения `Fq6 = Fq3[w]/(w^2 - v)`;
- Frobenius maps для `Fq3` и `Fq6` на основе arkworks constants;
- cheap non-residue multiplication для `11` и для `v`;
- sparse line multiplication в `Fq6`.

### 3.2 Curve and line layer

Нужно реализовать:

- `MNT6PairingTypes.sol`;
- `MNT6CurveChecks.sol` для G1/G2;
- schedule ate loop из `ark-mnt6-753`;
- prepared sparse line format для MNT6;
- line evaluation на G1-точке;
- combined Miller loop для уравнения `e(P,Q)=e(R,S)`.

### 3.3 Article640 verifier

Нужно реализовать:

- `MNT6Article640DirectVerifier.sol`: calldata/blob вариант;
- `MNT6Article640DirectHotVerifier.sol`: hot-path вариант;
- `MNT6Article640SameQHotVerifier.sol` или аналог для fixed-Q/fixed-S;
- проверку `c * cInv = 1`;
- residue-style path для финальной экспоненты;
- обычный final exponentiation path как baseline для сравнения.

### 3.4 Rust backend and fixtures

Нужно реализовать Rust backend:

- генерация MNT6 fixed-Q/fixed-S prepared lines;
- генерация calldata/blob fixture;
- генерация code-shards fixture;
- генерация residue witness `c, cInv`;
- cross-check с `ark-mnt6-753`.

### 3.5 Tests

Нужно покрыть:

- `Fq/Fq3/Fq6` арифметику против Rust vectors;
- G1/G2 curve checks;
- prepared line commitments;
- Miller core acceptance/rejection;
- final exponentiation baseline;
- residue verifier acceptance/rejection;
- tamper tests: P/R/line/c/cInv;
- gas report для всех режимов.

### 3.6 Results

Нужно получить таблицу:

| MNT6 режим | Gas |
|---|---:|
| full on-chain baseline | measured |
| prepared sparse blob | measured |
| prepared sparse code-shards | measured |
| article640 full equation | measured |
| article640 residue equation | measured |

И constraints/accounting таблицу:

| MNT6 relation component | Constraints/accounting |
|---|---:|
| Miller relation | measured/model |
| line-cache relation | measured/model |
| FE residue | measured/model |
| total prepared relation | measured/model |

## 4. Архитектурное решение

Реализовать F6C в отдельной директории:

```text
mnt6_article640_verifier/
```

Не смешивать с `article640_mnt4_verifier`, чтобы не сломать текущие MNT4-результаты.

Структура:

```text
mnt6_article640_verifier/
  foundry.toml
  src/
    BigIntMNT6.sol
    MNT6PairingTypes.sol
    MNT6Fp.sol
    MNT6Fq3.sol
    MNT6Fq6.sol
    MNT6CurveChecks.sol
    MNT6AteLoop.sol
    MNT6FinalExp.sol
    MNT6Article640DirectVerifier.sol
    MNT6Article640DirectHotVerifier.sol
  test/
    MNT6Arithmetic.t.sol
    MNT6ArkworksCrossCheck.t.sol
    MNT6Article640DirectVerifier.t.sol
    MNT6Article640Gas.t.sol
  rust/
    mnt6_article640_backend/
```

## 5. Почему это нельзя сделать простым копированием MNT4

MNT4 использует `Fq2/Fq4`, а MNT6 использует `Fq3/Fq6`. Поэтому меняется:

- размер G2-точки;
- формат line coefficients;
- sparse multiplication;
- Frobenius coefficients;
- final exponentiation decomposition;
- prepared line generation;
- calldata/blob/code-shards layout.

Копирование MNT4-кода без полной переделки башни расширений даст некорректный verifier.

## 6. Минимальная последовательность реализации

1. Сгенерировать параметры MNT6 из arkworks: modulus, Montgomery constants, one, generators, Frobenius constants, ate loop.
2. Написать RED-тесты на `Fq` arithmetic против Rust vectors.
3. Реализовать `BigIntMNT6.sol` и `MNT6Fp.sol`.
4. Написать RED-тесты на `Fq3/Fq6`.
5. Реализовать `MNT6Fq3.sol` и `MNT6Fq6.sol`.
6. Написать Rust backend для prepared lines.
7. Реализовать `MNT6AteLoop.sol` и Miller core.
8. Добавить full final exponentiation baseline.
9. Добавить residue-style verifier.
10. Добавить code-shards/hot path.
11. Запустить cross-check и gas report.
12. Обновить дипломные документы.

## 7. Граница честности

До выполнения F6C нельзя утверждать, что по MNT6 проделана такая же практическая работа, как по MNT4. Сейчас можно утверждать только, что MNT6 проверен как Rust reference и как cycle-native accounting side. После F6C можно будет утверждать, что MNT6 реализован как полноценный on-chain/article640 verifier target.
