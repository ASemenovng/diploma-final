# Задание для deep agent: исследование практической реализуемости схемы `MNT-native proof -> BN254 compression proof -> Solidity verifier`

## 1. Контекст работы

Исследуется архитектура для дешевой проверки корректности вычисления pairing на MNT4-753 в EVM. Долгосрочная цель работы: построить первый этап будущей folding/recursive verification библиотеки на MNT4/MNT6-кривых, которая позволит избежать взрывного роста constraints, характерного для прямой non-native арифметики в BN254/Sonobe-like подходах.

В проекте уже есть несколько направлений реализации и экспериментов.

### 1.1. Полностью on-chain MNT4 pairing

Есть Solidity/Yul реализация MNT4-753 арифметики и сопряжения:

```text
/Users/a.i.semenov/mnt4-pairing-final/onchain_full
```

Она вычисляет MNT4 pairing полностью внутри EVM. Это корректный reference/baseline, но он практически непригоден по gas.

Типичный порядок стоимости:

```text
full on-chain MNT4 pairing digest ~= 260M gas
```

Вывод: прямое on-chain вычисление MNT4 pairing без precompile непрактично.

### 1.2. Попытка адаптировать идеи ePrint 2024/640 напрямую в Solidity

Была исследована архитектура по мотивам статьи:

```text
https://eprint.iacr.org/2024/640.pdf
```

Идея статьи: не вычислять pairing полностью напрямую, а использовать pairing-equation/residue checks и оптимизации финальной экспоненты. В проекте был выделен экспериментальный контур:

```text
/Users/a.i.semenov/mnt4-pairing-final/article640_mnt4_verifier
```

Основная форма уравнения:

```math
e(P,Q) \cdot e(-R,S) = 1,
```

где `Q` и `S` могут быть фиксированными prepared points, а prover/off-chain backend передает auxiliary data/cache/witness.

Были рассмотрены две части:

1. Miller loop / prepared line cache.
2. Final exponentiation / residue-style check.

Практический результат: если on-chain контракт все равно проходит по шагам Miller loop, пусть даже с prepared sparse lines, стоимость остается десятки/сотни миллионов gas. Если пытаться заменить Miller loop polynomial/quotient/opening checks, возникает необходимость в polynomial commitment/opening layer. Для KZG over BN254 возможно возвращение non-native overhead; для Merkle/FRI возможен большой calldata/hash overhead.

Вывод: прямой Solidity-путь с проверкой cache/witness без SNARK/folding не дает очевидно дешевого production-verifier для MNT4-753 на Ethereum mainnet.

### 1.3. Текущая off-chain/on-chain verify архитектура

Есть отдельный контур:

```text
/Users/a.i.semenov/mnt4-pairing-final/offchain_verify
```

Текущий поток:

```text
Rust MNT4 backend
  -> prepared proof input / commitments / digests
  -> BN254 Groth16 verifier envelope
  -> Solidity verifier через BN254 precompile
```

Файлы:

```text
offchain_verify/crates/mnt4_trace_backend/src/lib.rs
offchain_verify/crates/mnt_cycle_constraints/src/lib.rs
offchain_verify/zk/stage6_groth16/stage6_single_strict.circom
offchain_verify/src/final_mnt4_pairing/MNT4PairingFinal.sol
offchain_verify/src/final_mnt4_pairing/MNT4PairingVerifier.sol
offchain_verify/src/final_mnt4_pairing/MNT4PairingProofChecker.sol
offchain_verify/src/final_mnt4_pairing/MNT4ProofSystemVerifier.sol
```

Важно: текущий BN254 circuit не доказывает полностью утверждение:

```math
Y = e_{\mathrm{MNT4}}(P,Q).
```

Он доказывает compact prepared relation / verifier envelope over commitments and digests. Поэтому маленькое число constraints в текущем BN254 circuit нельзя считать стоимостью полного MNT4 pairing proof.

Текущие ориентировочные числа:

```text
BN254 verifier-envelope constraints ~= 1538
on-chain final verifier gas ~= 340k gas
```

Эти числа относятся к дешевой оболочке, а не к полному доказательству корректности MNT4 pairing.

### 1.4. MNT-native relation accounting

Есть crate:

```text
offchain_verify/crates/mnt_cycle_constraints
```

Он моделирует стоимость будущей MNT-native relation, то есть relation, которая записывает MNT4 arithmetic в родном для MNT-cycle поле, а не эмулирует 753-битную арифметику внутри BN254.

Ключевая идея MNT4/MNT6 cycle:

```math
\mathbb{F}_{r_{\mathrm{MNT4}}} \cong \mathbb{F}_{p_{\mathrm{MNT6}}},
```

```math
\mathbb{F}_{r_{\mathrm{MNT6}}} \cong \mathbb{F}_{p_{\mathrm{MNT4}}}.
```

Это потенциально позволяет записывать часть arithmetic natively в recursive/folding stack, вместо того чтобы делать non-native limb decomposition в BN254.

Текущая модель дает следующие оценки:

```text
Miller transition relation, single pair: 4514 constraints
Line-cache relation: 19554 constraints
Final exponentiation residue relation: 110 constraints
Total prepared/residue MNT-native relation: 24178 constraints
If fixed-Q line cache is amortized: around 4624 constraints per proof
```

Но `mnt_cycle_constraints` пока является accounting/scaffold layer. Он не является полным production semantic circuit: текущие compiled R1CS chains синтетические и должны быть заменены реальными gadgets.

## 2. Почему возник новый вопрос

Предыдущая попытка реализовать проверку cache/witness напрямую в Solidity по мотивам ePrint 2024/640 столкнулась с проблемой: on-chain контракт либо фактически пересчитывает Miller loop и остается очень дорогим, либо должен заменить проверку Miller loop на polynomial commitment/opening mechanism, который сам по себе может быть дорогим или сложным.

Поэтому рассматривается другой путь:

```text
MNT4 computation
  -> MNT-native proof / MNT-cycle folding evidence
  -> BN254 compression proof
  -> Solidity verifier
```

Центральный вопрос исследования:

> Возможно ли практически реализовать схему, где тяжелая MNT4 relation доказывается/сворачивается в MNT-native или MNT-cycle layer, а в Ethereum передается только компактный BN254 proof, который дешево проверяется через существующий BN254 precompile, при этом BN254 circuit не должен заново доказывать всю MNT4 арифметику non-natively?

Иначе говоря, нужно понять: является ли путь `MNT-native proof -> BN254 compression proof -> Solidity` реальным production-направлением, или он неизбежно возвращает ту же проблему non-native arithmetic, только на уровне финального compression proof.

## 3. Текущая гипотеза

Гипотеза, которую нужно проверить:

1. Полный MNT4 pairing proof внутри BN254 circuit непрактичен из-за non-native арифметики.
2. MNT-native/MNT-cycle relation может быть намного дешевле по constraints.
3. Но для Ethereum mainnet нужен terminal proof, который проверяется через BN254 precompile.
4. Если BN254 proof будет заново проверять MNT-native proof verifier, он может снова потребовать non-native MNT arithmetic в BN254 и потерять выигрыш.
5. Однако, возможно, существует схема compression/decider, где BN254 circuit проверяет только небольшой accumulator/commitment/folding result, а не всю MNT relation.

Нужно строго установить, какой из вариантов верен.

## 4. Что именно нужно исследовать

### 4.1. Proof stack design

Нужно описать возможный полный стек:

```text
Off-chain:
  1. Given P, Q, claimed Y or pairing-equation statement.
  2. Rust backend computes MNT4 pairing artifacts:
       - line coefficients,
       - Miller trace or compressed relation witness,
       - final exponentiation / residue witness,
       - commitments/roots.
  3. Build MNT-native relation witness.
  4. Prove/fold this relation in MNT4/MNT6-native proof system.
  5. Produce compact BN254 compression proof.

On-chain:
  1. Solidity contract receives:
       - public statement: P, Q, claimed Y or equation digest,
       - commitments/roots,
       - final BN254 proof.
  2. Solidity recomputes public input hashes.
  3. Solidity calls BN254 verifier/precompile.
  4. Returns true/false.
```

Нужно определить, может ли пункт 5 off-chain быть реализован так, чтобы BN254 proof оставался маленьким и не содержал полную non-native проверку MNT arithmetic.

### 4.2. Formal statement

Нужно формально описать relation.

Например для claim:

```math
Y = e_{\mathrm{MNT4}}(P,Q)
```

или для pairing equation:

```math
e_{\mathrm{MNT4}}(P,Q) \cdot e_{\mathrm{MNT4}}(-R,S) = 1.
```

Relation может быть разложена на:

```math
R_{lines}(Q, L, C_L)=1,
```

```math
R_{Miller}(P, L, F, C_F)=1,
```

```math
R_{FE}(F_N, Y, W_{FE}, C_{FE})=1.
```

Полное отношение:

```math
R_{MNT}(P,Q,Y,C_L,C_F,C_{FE}; L,F,W_{FE}) =
R_{lines} \land R_{Miller} \land R_{FE}.
```

Нужно определить, как это отношение доказывается в MNT-native layer и что именно затем проверяет BN254 compression proof.

### 4.3. Что проверяет BN254 compression proof

Нужно сравнить минимум три варианта.

#### Вариант 1. BN254 proof напрямую доказывает `R_MNT`

```text
BN254 circuit contains full MNT4 arithmetic relation.
```

Ожидаемый результат: дорого из-за non-native arithmetic. Нужно подтвердить оценками и ссылками.

#### Вариант 2. BN254 proof проверяет verifier MNT proof

```text
BN254 circuit verifies a proof generated over MNT4/MNT6 system.
```

Нужно понять, какие операции verifier-а попадают в BN254 circuit. Если там есть MNT field/curve arithmetic, это снова non-native. Нужно оценить стоимость.

#### Вариант 3. BN254 proof проверяет compact accumulator / decider output

```text
MNT-cycle folding layer produces a compact accumulator.
BN254 circuit checks only a small statement about that accumulator.
```

Нужно установить, существует ли такая схема с soundness, где BN254 layer не обязан проверять большой объем MNT arithmetic. Если существует, описать конкретный протокол, proof system, commitments, public inputs, security assumptions и стоимость.

### 4.4. Связь с Sonobe / CycleFold / Nova-like approaches

Нужно изучить:

```text
https://github.com/privacy-ethereum/sonobe
https://eprint.iacr.org/2023/1192
https://eprint.iacr.org/2024/1790
https://hackmd.io/@yelhousni/emulated-pairing
https://eprint.iacr.org/2024/640.pdf
```

Нужно объяснить:

1. Где именно в Sonobe/CycleFold возникает рост constraints.
2. Можно ли MNT4/MNT6 cycle реально уменьшить этот рост.
3. Какие части Sonobe-like architecture можно использовать.
4. Какие части нужно заменить.
5. Будет ли итоговая схема реально лучше или просто перенесет non-native overhead в другой слой.

### 4.5. Связь с ePrint 2024/640

Нужно отдельно ответить:

1. Какие идеи из ePrint 2024/640 применимы только к direct on-chain / in-circuit pairing verification.
2. Какие идеи можно использовать внутри MNT-native relation layer:
   - prepared line cache,
   - Miller relation compression,
   - residue/relation check для финальной экспоненты,
   - polynomial/IOP representation for extension-field arithmetic.
3. Нужно ли в MNT-native/folding варианте реализовывать polynomial commitment/opening layer из статьи, или folding layer заменяет эту роль.
4. Какие оптимизации статьи действительно уменьшают constraints в MNT-cycle setting.

## 5. Вопросы, на которые агент должен дать строгий ответ

### Вопрос 1

Можно ли построить practically usable Ethereum contract следующего вида?

```solidity
function verifyPairingClaim(
    MNT4G1Point[] calldata P,
    MNT4G2Point calldata Q,
    bytes32 claimedResultDigest,
    bytes32 lineCacheRoot,
    bytes32 millerRoot,
    bytes32 finalExpRoot,
    bytes calldata compressedProof
) external view returns (bool);
```

Контракт должен:

1. Не пересчитывать MNT4 pairing.
2. Не проверять MNT arithmetic в Solidity.
3. Проверять compact proof через BN254 precompile.
4. Быть sound: нельзя подделать `claimedResultDigest`, `lineCacheRoot`, `millerRoot`, `finalExpRoot`.

Если да, агент должен описать полный proof stack. Если нет, агент должен строго объяснить, где возникает невозможность или экономическая непрактичность.

### Вопрос 2

Можно ли сделать final BN254 proof так, чтобы он не доказывал заново всю MNT4 arithmetic non-natively?

Если да:

- что именно доказывает BN254 circuit;
- какие public inputs;
- какие private inputs;
- какие constraints;
- какие commitments;
- как обеспечивается soundness.

Если нет:

- почему compression неизбежно требует non-native verification;
- какая минимальная нижняя оценка constraints;
- почему без MNT precompile или custom VM это не станет production-practical.

### Вопрос 3

Что дает MNT4/MNT6 cycle practically?

Нужно не просто сказать “native arithmetic cheaper”, а показать:

```math
\mathbb{F}_{r_{\mathrm{MNT4}}} \cong \mathbb{F}_{p_{\mathrm{MNT6}}}
```

и объяснить, какие именно операции становятся native в recursive/folding setting.

Нужно также указать, какие операции все равно могут остаться non-native при terminal BN254 compression.

### Вопрос 4

Какая минимальная реализация нужна, чтобы текущая диссертация честно утверждала:

```text
Мы реализовали первый этап будущей дешевой folding-библиотеки на MNT-cycle,
но не реализовали сам production folding layer.
```

Нужно указать, достаточно ли текущих компонентов:

```text
onchain_full baseline
article640 direct/residue experiments
offchain_verify BN254 envelope
mnt4_trace_backend Rust backend
mnt_cycle_constraints accounting/scaffold
```

или нужно добавить еще один обязательный компонент, например:

```text
semantic MNT-cycle circuit fragment
```

который реально проверяет хотя бы один Miller transition / line-cache relation / FE residue relation не synthetic chain, а настоящими формулами.

## 6. Ожидаемые формулы и модели стоимости

Агент должен построить формальные оценки для минимум следующих вариантов.

### 6.1. Direct BN254 non-native proof

Оценка:

```text
MNT4 field element ~= 753 bits
BN254 scalar field ~= 254 bits
=> at least 3 limbs, practically more constraints due multiplication/reduction/range checks
```

Нужно оценить:

```text
cost(F_MNT4 mul in BN254 circuit)
cost(Fq2/Fq4 operations)
cost(Miller relation)
cost(FE relation)
total constraints
```

### 6.2. MNT-native relation proof

Использовать текущую модель как стартовую точку:

```text
Fq2.mul = 3 native mul
Fq4.mul = 9 native mul
Fq4.square = 4 native mul
sparse line mul = 6 native mul
```

И текущие параметры:

```text
Miller rounds = 377
addition steps = 124
```

Оценка:

```text
Miller single = 4514 constraints
Line-cache = 19554 constraints
FE residue = 110 constraints
Total = 24178 constraints
Fixed-Q amortized = about 4624 constraints per proof
```

Агент должен проверить, насколько эта модель реалистична после добавления настоящих gadgets: canonical checks, subgroup checks, range/carry checks, commitments, transcript, openings.

### 6.3. Terminal BN254 compression

Нужно дать оценку стоимости final compression proof:

```text
BN254 proof constraints
proof generation time
on-chain gas
public input size
```

Самое важное: агент должен объяснить, что именно доказывается в terminal BN254 circuit и почему это не возвращает полный non-native MNT4 overhead.

## 7. Что агент должен изучить в литературе

Минимальный список источников:

1. ePrint 2024/640, `On Proving Pairings`:
   ```text
   https://eprint.iacr.org/2024/640.pdf
   ```
2. ePrint 2024/1790:
   ```text
   https://eprint.iacr.org/2024/1790
   ```
3. Emulated pairing notes:
   ```text
   https://hackmd.io/@yelhousni/emulated-pairing
   ```
4. ePrint 2023/1192:
   ```text
   https://eprint.iacr.org/2023/1192
   ```
5. Sonobe repository:
   ```text
   https://github.com/privacy-ethereum/sonobe
   ```
6. Arkworks MNT4/MNT6 documentation and crates:
   ```text
   https://github.com/arkworks-rs/curves
   ```

Агент может добавлять дополнительные источники, но должен явно отделять:

```text
source-backed claims
```

от

```text
own inference / estimate
```

## 8. DoD исследования

Исследование считается завершенным, если агент предоставил следующие результаты.

### 8.1. Вердикт реализуемости

Один из трех вердиктов:

1. `Practically feasible`: схема может быть реализована для Ethereum mainnet без MNT precompile, и агент описывает конкретный proof stack.
2. `Feasible only as research prototype`: схема возможна, но production-практичность требует folding layer/custom assumptions/large prover cost.
3. `Not feasible without MNT precompile or custom VM`: terminal BN254 compression неизбежно возвращает non-native bottleneck или слишком дорогой verifier.

### 8.2. Полная архитектура

Должен быть описан pipeline:

```text
Rust backend -> MNT-native proof/folding -> BN254 compression proof -> Solidity verifier
```

С указанием:

- что считается off-chain;
- что является witness;
- что является public input;
- что именно доказывает MNT-native layer;
- что именно доказывает BN254 layer;
- что проверяет Solidity;
- почему verifier sound.

### 8.3. Формальная relation

Должны быть формулы для:

```text
line-cache relation
Miller relation
final exponentiation/residue relation
folding/compression relation
```

### 8.4. Оценки constraints/gas/ms

Должна быть таблица минимум для вариантов:

| Вариант | MNT relation constraints | BN254 compression constraints | On-chain gas | Prover time estimate | Practical verdict |
|---|---:|---:|---:|---:|---|
| Direct BN254 non-native MNT proof | | | | | |
| MNT-native relation + no compression | | | | | |
| MNT-native relation + BN254 compression | | | | | |
| Current BN254 verifier envelope | 1538 envelope only | | ~340k | | not full proof |
| Full on-chain baseline | | | ~260M | | impractical |

### 8.5. Что нужно реализовать в текущем проекте

Агент должен дать конкретный список доработок:

1. Что уже достаточно реализовано.
2. Что нужно заменить.
3. Какой минимальный semantic circuit fragment нужно добавить.
4. Нужно ли реализовывать actual folding now, или достаточно сделать proof-of-possibility через constraints/model.
5. Что именно можно честно защищать в текущей магистерской работе.

### 8.6. Риски и невозможные места

Агент должен явно перечислить:

- где может вернуться non-native overhead;
- где нужны trusted setup / CRS;
- где появляются assumptions commitment scheme;
- где нужен MNT precompile или custom VM;
- где текущая схема может быть только исследовательской, а не production-ready.

## 9. Требования к стилю ответа агента

Ответ должен быть строгим и проверяемым.

Не допускаются общие фразы вида:

```text
This should be possible with recursion.
```

Нужно писать конкретно:

```text
BN254 circuit verifies X.
X consists of these equations.
These equations cost approximately Y constraints.
This avoids / does not avoid non-native arithmetic because Z.
```

Если какой-то блок невозможно оценить точно, агент должен:

1. указать, почему невозможно;
2. дать верхнюю и нижнюю оценку;
3. указать, какой эксперимент/код нужен для уточнения.

## 10. Главный вопрос, на который нужно ответить

Можно ли построить production-usable Ethereum verifier для MNT4 pairing claim без MNT precompile, используя стек:

```text
MNT-native relation / MNT-cycle folding
  -> BN254 compression proof
  -> Solidity verifier
```

так, чтобы:

1. on-chain gas оставался порядка сотен тысяч или низких миллионов gas;
2. proof constraints не возвращались к миллионам/десяткам миллионов из-за BN254 non-native arithmetic;
3. контракт был sound и реально проверял корректность MNT4 pairing claim, а не только binding commitments/digests.

Если да -- подробно описать как.

Если нет -- строго доказать, где возникает фундаментальный bottleneck и какие условия нужны, чтобы он исчез:

```text
MNT precompile,
custom VM,
другой terminal curve,
другой proof system,
или отказ от Ethereum-mainnet production verifier.
```
