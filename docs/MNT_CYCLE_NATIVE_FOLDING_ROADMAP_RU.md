# MNT4/MNT6 cycle-native roadmap и PCS/constraints-heavy аргумент

## 1. Что закрывает этот документ

Этот документ закрывает этап F6 финального плана. Его задача -- связать три части работы в одну логическую линию:

1. прямое on-chain вычисление MNT4-753 сопряжения дорого по gas;
2. ePrint 2024/640 предлагает заменить проверку цикла Миллера на polynomial relation check, но для MNT4-753 стоимость переносится либо в BN254 non-native constraints, либо в calldata;
3. MNT4/MNT6 цикл дает естественное направление для будущего folding, потому что арифметика одной кривой может быть записана в поле другой кривой без такого же non-native overhead.

Документ не утверждает, что в текущей работе реализован полный CycleFold. Текущая работа реализует арифметику, on-chain baselines, direct residue verifier, KZG/Merkle opening experiments и MNT-native constraints accounting. Полный folding layer остается следующим этапом.

## 2. Polynomial-check постановка из ePrint 2024/640

В прямой реализации цикла Миллера verifier выполняет много локальных умножений в расширенном поле. Упрощенно каждое такое отношение можно записать как

\[
c_i = a_i b_i.
\]

Если проверять все отношения напрямую, verifier фактически повторяет дорогую часть вычисления. Идея polynomial-check подхода состоит в том, чтобы записать все значения трассы как witness-многочлены:

\[
a(X), \quad b(X), \quad c(X), \quad f(X), \quad \ell(X), \quad \ldots
\]

Затем локальные равенства собираются в одно полиномиальное отношение. Для простого отношения умножения:

\[
R(X)=a(X)b(X)-c(X).
\]

Если оно выполнено на всем вычислительном домене \(H\), то \(R(X)\) делится на vanishing polynomial

\[
Z_H(X)=\prod_{h\in H}(X-h).
\]

То есть существует quotient polynomial \(Q(X)\):

\[
R(X)=Q(X)Z_H(X).
\]

Verifier не проверяет все точки домена. Он получает commitments к witness-многочленам, затем через Fiat--Shamir получает случайные challenge-и:

- \(\beta\) -- separation challenge для объединения нескольких отношений в одно;
- \(\alpha\) -- evaluation challenge, точка проверки.

После этого verifier проверяет одно равенство:

\[
R_\beta(\alpha)=Q(\alpha)Z_H(\alpha).
\]

Но этого недостаточно без opening proof. Prover обязан доказать, что значения

\[
a(\alpha), b(\alpha), c(\alpha), Q(\alpha), \ldots
\]

действительно открываются из ранее зафиксированных commitments. Поэтому центральный вопрос F6 -- не сама формула quotient check, а стоимость polynomial commitment/opening layer для MNT4-753.

## 3. KZG over BN254 путь

### 3.1. Что реализовано

В проекте реализован отдельный KZG opening verifier:

```text
article640_mnt4_verifier/src/Article640KzgBn254OpeningVerifier.sol
```

Он проверяет стандартное KZG-opening равенство над BN254:

\[
e(C-yG_1+x\pi, G_2)=e(\pi,\tau G_2).
\]

Здесь:

- \(C\) -- commitment к многочлену;
- \(x\) -- точка открытия;
- \(y=f(x)\) -- заявленное значение;
- \(\pi\) -- KZG opening proof;
- \(\tau G_2\) -- часть SRS.

Тестовый пример использует линейный многочлен

\[
f(X)=3X+5,
\]

точку \(x=7\) и значение \(y=26\). При toy-SRS \(\tau=1\):

\[
C=f(1)G_1=8G_1, \qquad \pi=3G_1.
\]

Контракт принимает корректное открытие и отвергает подмененное значение.

Свежий gas-result:

| Компонент | Gas |
|---|---:|
| KZG opening verifier over BN254 | 133,039 |

### 3.2. Почему это не решает задачу полностью

KZG over BN254 делает on-chain проверку короткой, потому что Ethereum имеет BN254 precompile. Но вычислительная relation относится к MNT4-753, а не к BN254. Если доказывать эту relation внутри BN254 circuit, элементы поля MNT4-753 становятся non-native.

MNT4-753 field element имеет размер около 753 бит. BN254 scalar field имеет размер около 254 бит. Поэтому один элемент MNT4 приходится раскладывать на несколько limb-ов:

\[
x = x_0 + 2^b x_1 + 2^{2b}x_2 + \ldots
\]

После этого одно поле умножения

\[
z = xy \pmod q
\]

превращается в систему ограничений для limb multiplication, переносов, редукции по модулю и проверки диапазонов.

В проекте добавлен реальный R1CS-замер через `ark-r1cs-std::fields::emulated_fp::EmulatedFpVar`:

```text
article640_mnt4_verifier/rust/article640_backend/src/bin/pcs_constraints.rs
```

Команда:

```bash
cd /Users/a.i.semenov/mnt4-pairing-final/article640_mnt4_verifier/rust/article640_backend
cargo run --release --bin pcs_constraints
```

Результат:

| Операция | Constraints |
|---|---:|
| MNT4 `Fq` multiplication inside BN254 R1CS | 3,692 |
| MNT4 `Fq2` multiplication inside BN254 R1CS | 11,300 |
| MNT4 `Fq4` multiplication model inside BN254 R1CS | 63,436 |
| Approx sparse Miller relation in BN254 R1CS | 63,309,128 |

Вывод: KZG дает короткий on-chain verifier, но переносит стоимость в constraints. Это ровно та же структурная проблема, из-за которой generic folding/decider-подходы становятся тяжелыми при переносе большой арифметики в неподходящее поле.

## 4. Merkle/FRI путь

### 4.1. Что реализовано

В проекте реализован Merkle-opening layer:

```text
article640_mnt4_verifier/src/Article640MerkleFriOpeningVerifier.sol
```

Он проверяет реальные Merkle authentication paths для открытых значений witness-таблицы. Это не полный FRI low-degree verifier. Но это обязательная часть любого Merkle/FRI варианта: если prover коммитится к таблице значений через Merkle root, verifier должен проверить, что открытые значения действительно входят в эту таблицу.

Измерения:

| Компонент | Gas |
|---|---:|
| Одно Merkle opening | 1,093 |
| 8 openings, depth 16 | 46,402 max |

### 4.2. Где возникает стоимость

Merkle hashing дешевле, чем полный Miller loop. Но для MNT4-753 основная стоимость переносится в calldata.

Один элемент поля MNT4-753 кодируется тремя EVM-словами:

\[
3\cdot 32 = 96\text{ bytes}.
\]

Для модели из теста:

```text
openedMnt4FieldElements = 4096
merklePaths = 128
merkleDepth = 16
friLayerRoots = 16
```

получается:

\[
4096\cdot 96 + 128\cdot 16\cdot 32 + 16\cdot 32 = 459264\text{ bytes}.
\]

Если открытий становится больше, размер calldata быстро доходит до мегабайт. Например, только значения witness-элементов:

\[
30000\cdot 96 = 2880000\text{ bytes}.
\]

Это еще без Merkle paths и FRI layer roots. Поэтому Merkle/FRI путь уменьшает потребность в BN254 non-native constraints, но переносит стоимость в размер доказательства и calldata.

## 5. Почему нужен MNT4/MNT6 cycle-native путь

MNT4-753 и MNT6-753 образуют цикл полей:

\[
\mathbb{F}_{r_{\mathrm{MNT4}}} \simeq \mathbb{F}_{q_{\mathrm{MNT6}}},
\]

\[
\mathbb{F}_{r_{\mathrm{MNT6}}} \simeq \mathbb{F}_{q_{\mathrm{MNT4}}}.
\]

Здесь:

- \(q\) -- модуль базового поля кривой;
- \(r\) -- порядок скалярного поля основной подгруппы;
- \(\mathbb{F}_q\) -- поле координат точек;
- \(\mathbb{F}_r\) -- поле, над которым удобно строить circuit.

Практический смысл цикла такой:

- если circuit на MNT6 проверяет арифметику MNT4, то базовое поле MNT4 совпадает со скалярным полем MNT6;
- если circuit на MNT4 проверяет арифметику MNT6, то базовое поле MNT6 совпадает со скалярным полем MNT4;
- поэтому часть вычислений можно записывать как native arithmetic, а не как BN254 non-native limb arithmetic.

Именно это является главным аргументом в пользу будущего folding на MNT4/MNT6, а не в пользу полного доказательства MNT4 pairing внутри BN254.

## 6. Текущий MNT-native constraints accounting

В проекте уже есть исследовательский crate:

```text
offchain_verify/crates/mnt_cycle_constraints
```

Он не является production folding circuit. Его роль -- воспроизводимо оценить, сколько constraints стоит MNT-native relation layer, если арифметика считается в родном для нее поле.

Команды:

```bash
cd /Users/a.i.semenov/mnt4-pairing-final/offchain_verify
cargo test --manifest-path crates/mnt_cycle_constraints/Cargo.toml
cargo run --manifest-path crates/mnt_cycle_constraints/Cargo.toml --bin mnt-cycle-constraints-report
```

Ключевые значения из отчета:

| Компонент | Constraints |
|---|---:|
| Native `Fp` multiplication | 1 |
| `Fq2` multiplication, Karatsuba | 3 |
| `Fq4` multiplication | 9 |
| `Fq4` sparse line multiplication | 6 |
| Miller transition relation | 4,514 |
| Line-cache relation | 19,554 |
| Final exponentiation residue relation | 110 |
| Total prepared residue relation | 24,178 |
| Compiled R1CS fragment | 24,181 |

Сравнение с BN254 non-native переносом:

| Подход | Constraints / стоимость |
|---|---:|
| MNT-native prepared residue relation model | 24,178 |
| Compiled MNT-native R1CS fragment | 24,181 |
| BN254 non-native sparse Miller relation estimate | 63,309,128 |
| Sonobe-like Ethereum decider reference | около 9,000,000 |

Эти числа нельзя читать как готовый CycleFold. Их нужно читать как ответ на другой вопрос: насколько дешевле выглядит relation layer, если его строить в MNT-native setting, а не переносить MNT4 arithmetic в BN254.

## 7. Как должен выглядеть будущий folding pipeline

Будущий pipeline можно разделить на пять уровней.

### Уровень 1. Rust backend

Rust backend вычисляет MNT4 pairing и строит witness:

\[
w=(\ell_1,\ldots,\ell_N, f_0,\ldots,f_N,w_{FE}).
\]

Здесь:

- \(\ell_i\) -- line coefficients цикла Миллера;
- \(f_i\) -- состояния Miller accumulator;
- \(w_{FE}\) -- witness для финальной экспоненты или residue relation.

### Уровень 2. MNT-native relation

Relation проверяет:

\[
Q \rightarrow \{\ell_i\},
\]

\[
f_{i+1}=f_i^2\ell_i(P),
\]

\[
\operatorname{FE/residue}(f_N,Y)=1.
\]

На этом уровне важно, чтобы relation была записана не в BN254, а в MNT-native поле.

### Уровень 3. Folding layer

Folding layer многократно сворачивает одинаковые relation steps. Именно здесь должен появиться будущий CycleFold-like компонент. В текущей работе он не реализуется.

### Уровень 4. Compression proof

После folding можно получить компактный proof, пригодный для EVM. Это может быть BN254 compression proof или другая EVM-friendly схема. Важно: этот proof не должен заново доказывать всю MNT4 arithmetic как non-native BN254 circuit.

### Уровень 5. Solidity verifier

Solidity verifier проверяет только компактное доказательство или его envelope. Он не исполняет Miller loop и не проверяет весь witness напрямую.

## 8. Что текущая работа уже доказывает, а что нет

Текущая работа доказывает:

1. Полное on-chain вычисление MNT4-753 сопряжения практически дорого.
2. Оптимизации арифметики и prepared sparse lines сильно снижают gas, но не делают MNT4 pairing дешевым.
3. Direct residue идея из ePrint 2024/640 снижает часть стоимости, но Miller loop остается главным вкладом.
4. Polynomial-check направление требует PCS/opening layer.
5. KZG over BN254 имеет короткий on-chain verifier, но переносит MNT4 arithmetic в non-native constraints.
6. Merkle/FRI opening layer избегает части BN254 constraints, но дает большой calldata из-за 96-байтных элементов MNT4.
7. MNT4/MNT6 cycle-native направление математически объясняет, как можно уйти от BN254 non-native bottleneck в будущей folding-схеме.

Текущая работа не доказывает:

1. что полный CycleFold уже реализован;
2. что есть production EVM-verifier для полного MNT4/MNT6 folding;
3. что BN254 proof-envelope с малым числом constraints доказывает весь MNT4 pairing;
4. что Merkle/FRI путь уже реализован как полный low-degree proof.

## 9. Итоговый вывод F6

F6 закрывает важный методологический разрыв. Если остановиться только на direct on-chain варианте, работа показывает лишь отрицательный результат по gas. Если остановиться только на KZG, возникает та же проблема non-native constraints. Если остановиться только на Merkle/FRI, стоимость уходит в calldata.

MNT4/MNT6 cycle-native путь объясняет, каким должно быть следующее развитие: нужно folding-ить MNT-native relation layer, а не доказывать MNT4-арифметику внутри BN254 напрямую. Именно поэтому текущие результаты F1--F5 являются подготовительным фундаментом: они показывают стоимость арифметики, границы on-chain подхода, цену PCS/opening layer и направление, в котором можно избежать главного bottleneck.
