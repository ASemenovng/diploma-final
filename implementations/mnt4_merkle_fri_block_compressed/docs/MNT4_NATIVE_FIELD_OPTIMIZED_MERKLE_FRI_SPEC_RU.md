# Спецификация оптимизированной нативной Merkle/FRI-проверки MNT4-753

## 1. Статус документа

Документ задает целевую архитектуру экспериментального verifier-а для
уравнения сопряжений:

\[
e(P,Q)e(-R,S)=1,
\]

где:

- \(P,R\in G_1\) передаются при вызове;
- \(Q,S\in G_2\) фиксируются при развертывании verifier-а;
- тяжелые вычисления выполняются Rust-бэкендом;
- Solidity-контракт проверяет прозрачное Merkle/FRI-доказательство;
- арифметика proof layer выполняется в базовом поле MNT4-753;
- ненативная арифметика над BN254 или другим внешним полем не используется.

Цель — получить наиболее дешевую по gas математически корректную
Merkle/FRI-инстанциацию идей статьи *On Proving Pairings* для MNT4-753.

Документ заменяет прежнюю row-major модель в качестве целевой реализации.
Прежняя модель сохраняется как отрицательный baseline.

## 2. Проверяемое утверждение

Контракт проверяет:

\[
\operatorname{VerifyEquation}(P,R,\pi)=1
\quad\Longleftrightarrow\quad
e(P,Q)e(-R,S)=1,
\]

где:

- \(P,R\) — динамические точки;
- \(Q,S\) — фиксированные точки конфигурации;
- \(\pi\) — Merkle/FRI-proof;
- \(e\) — приведенное MNT4-сопряжение.

Эквивалентно:

\[
e(P,Q)=e(R,S).
\]

Публичные точки \(P,R\) должны быть канонически закодированы и принадлежать
требуемой подгруппе \(G_1\). Проверка принадлежности включается в
доказываемое отношение. Контракт не должен выполнять дорогое скалярное
умножение точки on-chain только ради subgroup-check.

### 2.1. Почему используется equation API

Residue-проверка статьи *On Proving Pairings* применима к проверке того, что
произведение сопряжений равно единице. Equation API позволяет:

1. встроить witness \(c\) в проход цикла Миллера;
2. не выполнять полную финальную экспоненту;
3. использовать общий аккумулятор multi-Miller loop;
4. предварительно подготовить данные для фиксированных \(Q,S\).

### 2.2. Граница применимости

Контракт не является универсальным API:

\[
Y\stackrel{?}{=}e(P,Q).
\]

Он предназначен для проверки pairing equation с двумя фиксированными
аргументами \(G_2\). Это соответствует постановке Article640 и типичным
verifier-уравнениям.

## 3. Запрет на ненативную арифметику

Все полиномиальные таблицы, quotient-полиномы, Merkle-раскрытия и FRI-слои
живут в:

\[
\mathbb F_q
=
\mathbb F_{\mathrm{MNT4\text{-}753}}.
\]

Контракт использует существующую оптимизированную трехсловную арифметику:

```text
arithmetic/mnt4_3limb/
```

Один элемент поля занимает:

\[
96\text{ байт}.
\]

Измеренная стоимость базового умножения:

\[
G_{\mathrm{mul},q}=2959\text{ gas}.
\]

В схеме нет:

- limb/carry AIR для переноса MNT4 в BN254;
- R1CS/Groth16 circuit полного MNT4-сопряжения;
- KZG-opening над BN254;
- доверия к произвольному off-chain cache.

## 4. Математические оптимизации Article640

### 4.1. Multi-Miller accumulator

Вместо отдельных аккумуляторов для двух сопряжений используется один:

\[
F
=
f_{r,Q}(P)
\cdot
f_{r,S}(-R).
\]

На каждом шаге возведение в квадрат выполняется один раз для общего
аккумулятора.

### 4.2. Residue witness вместо полной финальной экспоненты

Проверяется существование:

\[
c,c^{-1}\in\mathbb F_{q^4}^{*},
\]

связанное с Miller output relation статьи. Проверка witness встраивается в
multi-Miller loop. Длинная финальная экспонента on-chain не вычисляется.

Witness должен удовлетворять:

\[
c\cdot c^{-1}=1.
\]

Показатели \(c^{\kappa_b}\), необходимые для residue relation, распределяются
по блокам цикла Миллера. Это позволяет использовать те же возведения в
квадрат аккумулятора.

Значения \(\kappa_b\), знаки, scaling terms и Frobenius tail нельзя выводить
заново по упрощенной модели. Индексатор должен сгруппировать точную
проверенную MNT4-программу из существующего Article640 baseline:

```text
implementations/article640_mnt4/src/MNT4TatePairing.sol
```

и сформировать:

```text
residue_program.json
```

Для каждого блока файл содержит:

- диапазон исходных шагов;
- signed digits;
- divisor ids;
- показатель \(\kappa_b\);
- scaling terms;
- Frobenius tail operations.

Rust differential test обязан подтвердить эквивалентность сгруппированной
программы исходному residue verifier-у.

### 4.3. Сжатие раундов цикла Миллера

Пусть блок содержит \(d_b\) последовательных раундов. Вместо публикации
каждого промежуточного аккумулятора проверяется:

\[
f_{b+1}
=
f_b^{2^{d_b}}
\cdot
g_b^Q(P)
\cdot
g_b^S(-R)
\cdot
c^{\kappa_b}.
\]

Здесь:

\[
g_b^U
=
\prod_{j=0}^{d_b-1}
\ell_{b,j}^{\,2^{d_b-1-j}},
\qquad
U\in\{Q,S\}.
\]

### 4.4. Сжатые делители вместо отдельных линий

Для фиксированного \(U\in\{Q,S\}\):

\[
g_b^U(x,y)
=
a_b^U(x)
+
y\,b_b^U(x).
\]

Коэффициенты \(a_b^U,b_b^U\) вычисляются Rust-индексатором один раз.
Пользователь не может выбирать их при вызове.

Для блока размера \(d\) статья дает:

\[
n_b<2^{d+2}+1.
\]

При wNAF ожидается:

\[
n_b<2^{d+1}+1.
\]

### 4.5. Выбор размеров блоков

Равномерный baseline:

\[
d=5.
\]

Для:

\[
k=4,
\qquad
L=376
\]

эвристическая модель статьи:

\[
C(d)
=
(k-1)\frac{L}{d}
+
(2^d-1)(k-1)
-
k
\]

дает:

| \(d\) | \(C(d)\) |
|---:|---:|
| 3 | \(393.0\) |
| 4 | \(323.0\) |
| 5 | \(314.6\) |
| 6 | \(373.0\) |
| 7 | \(538.1\) |

Основной профиль не должен жестко фиксировать одинаковый \(d\). Для
конкретной signed-digit цепочки Rust-индексатор решает:

\[
\min_{\mathcal P}
\sum_{b\in\mathcal P}
\operatorname{cost}(b),
\]

где:

\[
d_b\in\{3,4,5,6\}.
\]

Стоимость блока учитывает:

- фактическое число ненулевых signed digits;
- число коэффициентов делителя;
- степень quotient;
- число динамических openings;
- стоимость residue-показателя.

Выбранное разбиение является частью неизменяемой конфигурации verifier-а.

## 5. Две разные ленты коэффициентов

Для корректности необходимо различать:

1. фиксированные коэффициенты делителей;
2. динамические коэффициенты witness-элементов расширенного поля.

### 5.1. Фиксированная лента делителей

Обозначим:

\[
D(T).
\]

Она содержит коэффициенты:

\[
a_b^Q,\ b_b^Q,\ a_b^S,\ b_b^S
\]

для выбранного разбиения цикла Миллера.

Лента:

- строится Rust-индексатором;
- не зависит от \(P,R\);
- хранится в неизменяемых `code-shards`;
- привязывается к конфигурации через адреса и `EXTCODEHASH`;
- не передается повторно в calldata.

Один shard не должен превышать лимит runtime-кода EIP-170. Индексатор
разбивает ленту на несколько shards и генерирует детерминированное
отображение:

\[
\operatorname{offset}
\longmapsto
(\operatorname{shardId},\operatorname{localOffset}).
\]

Адреса shards и ожидаемые code hashes проверяются при развертывании и
сохраняются как неизменяемая конфигурация. На каждом вызове повторно
вычислять commitment ко всей фиксированной таблице нельзя.

### 5.2. Динамическая лента witness

Обозначим:

\[
C(T).
\]

Она кодирует коэффициенты динамических элементов:

\[
w_1(X),\ldots,w_n(X)
\in
\mathbb F_q[X]/(p(X)),
\]

возникающих в проверке:

- аккумуляторов;
- residue witness;
- значений делителей;
- промежуточных результатов расширенной арифметики;
- boundary state.

Лента \(C(T)\) строится prover-ом для конкретных \(P,R\), коммитится через
Merkle tree и проверяется low-degree proof.

## 6. Column-wise efficient evaluation

### 6.1. Общая схема

Пусть:

\[
w_i(X)
=
w_{i,d}X^d+\cdots+w_{i,0}.
\]

Коэффициенты всех \(w_i\) последовательно записываются в \(C(T)\).

Пусть:

- \(H\) — домен;
- \(g\) — его генератор;
- \(Z_H(T)\) — vanishing polynomial;
- \(h(T)\) — фиксированный selector начала каждой группы коэффициентов.

Для challenge \(\alpha\) prover строит столбец Горнера:

\[
E_\alpha(T).
\]

Проверяются отношения:

\[
h(T)\bigl(C(T)-E_\alpha(T)\bigr)
=
q_0(T)Z_H(T),
\]

\[
\bigl(1-h(T)\bigr)
\Bigl(
E_\alpha(T)
-
\bigl(E_\alpha(g^{-1}T)\alpha+C(T)\bigr)
\Bigr)
=
q_1(T)Z_H(T).
\]

### 6.2. Объединение отношений

После challenge \(\gamma\):

\[
B_\alpha(T)
=
\frac{
h(T)\bigl(C(T)-E_\alpha(T)\bigr)
+
\gamma(1-h(T))
\Bigl(
E_\alpha(T)
-
\bigl(E_\alpha(g^{-1}T)\alpha+C(T)\bigr)
\Bigr)
}{
Z_H(T)
}.
\]

Verifier открывает:

\[
B_\alpha(v),
\quad
h(v),
\quad
C(v),
\quad
E_\alpha(v),
\quad
E_\alpha(g^{-1}v).
\]

### 6.3. Проверка фиксированных делителей

Для вычисления:

\[
g_b^Q(P),
\qquad
g_b^S(-R)
\]

используется тот же принцип, но входная лента \(D(T)\) является фиксированной.

Строятся evaluator columns:

\[
E_{P_x}^{D}(T),
\qquad
E_{R_x}^{D}(T).
\]

Selector вычисляется из позиции, а значения \(D(T)\) для sampled positions
читаются из `code-shards`.

Фиксированная таблица не передается в calldata. Ее корректность является
частью конфигурации конкретного развернутого verifier-а.

Rust-индексатор обязан differential-тестом подтвердить, что таблица
получена из канонических \(Q,S\). Модель доверия здесь такая же, как для
verification key: развернутый контракт проверяет утверждение относительно
конкретной неизменяемой конфигурации.

## 7. Randomized extension-field arithmetic

Расширение MNT4 задается:

\[
\mathbb F_{q^4}
\simeq
\mathbb F_q[X]/(p(X)).
\]

Для каждого relation:

\[
R_j(w_1,\ldots,w_n)=0
\quad
\text{в }
\mathbb F_{q^4}
\]

prover формирует коэффициентное представление.

После challenge \(\beta\) отношения объединяются:

\[
\sum_j
\beta^j
R_j(w_1(X),\ldots,w_n(X))
=
Q_{\mathrm{ext}}(X)p(X).
\]

После challenge \(\alpha\) verifier проверяет:

\[
\sum_j
\beta^j
R_j(w_1(\alpha),\ldots,w_n(\alpha))
=
Q_{\mathrm{ext}}(\alpha)p(\alpha).
\]

Таким образом:

- не выполняются все операции \(\mathbb F_{q^4}\) on-chain;
- не передается отдельный quotient для каждого умножения;
- стоимость зависит от числа базовых операций \(\mathbb F_q\) в
  объединенном relation-check.

## 8. Basis для расширенного поля

Нужно реализовать и измерить два режима.

### 8.1. Tower basis

Используется текущая башня расширений MNT4:

\[
\mathbb F_q
\subset
\mathbb F_{q^2}
\subset
\mathbb F_{q^4}.
\]

Преимущество:

- совместимость с существующими fixture;
- простой differential check с текущей on-chain реализацией;
- понятный baseline.

### 8.2. Normal basis

Используется представление:

\[
x
=
\sum_{i=0}^{3}
a_i\theta^{q^i}.
\]

Тогда Frobenius:

\[
x\mapsto x^q
\]

является циклическим сдвигом коэффициентов.

Преимущество:

- более дешевый Frobenius tail;
- меньше отношений для residue relation;
- возможное уменьшение динамических столбцов.

Rust cost-model выбирает basis с меньшей итоговой стоимостью proof.
Solidity verifier получает выбранный basis как часть версии конфигурации.

## 9. Прозрачный PCS-слой

### 9.1. Коммитменты

Динамические oracle-полиномы коммитятся через бинарные Merkle-деревья над
LDE evaluations.

Фиксированные таблицы:

- не коммитятся заново на каждый вызов;
- хранятся в `code-shards`;
- читаются по derived index;
- проверяются относительно `EXTCODEHASH`, зафиксированного конфигурацией.

### 9.2. Один source tree

Динамические значения sampled row пакуются в один leaf. Один Merkle path
подтверждает все необходимые значения этой строки.

Leaf содержит только минимальный реестр динамических столбцов. Полный
реестр генерируется Rust cost-model после выбора basis и разбиения блоков.

Обязательные классы столбцов:

- динамическая лента \(C(T)\);
- evaluator column \(E_\alpha(T)\);
- evaluator columns фиксированных делителей;
- объединенный extension quotient;
- column-wise quotient;
- composition oracle;
- boundary state.

### 9.3. Один composition oracle

Все локальные отношения объединяются после challenge \(\eta\):

\[
\operatorname{Comp}(T)
=
\sum_j
\eta^jR_j(T).
\]

Нельзя строить отдельный FRI proof для каждого отношения.

### 9.4. Один batched FRI proof

Все динамические низкостепенные oracle-полиномы одинакового домена
объединяются случайной линейной комбинацией:

\[
W_{\rho}(T)
=
\sum_i
\rho^iW_i(T).
\]

FRI проверяет один mixed oracle.

Значения отдельных \(W_i\) раскрываются только в sampled rows, чтобы
контракт мог самостоятельно вычислить \(W_\rho(T)\).

## 10. Ограничение размера домена и сегментация

Для поля MNT4-753:

\[
\nu_2(q-1)=15.
\]

Максимальный двоичный мультипликативный поддомен:

\[
2^{15}=32768.
\]

Если лента или ее LDE не помещается в один домен, Rust backend обязан:

1. разбить таблицу на сегменты;
2. построить отдельные roots сегментов;
3. проверить boundary relations между соседними сегментами;
4. использовать один общий набор Fiat-Shamir запросов;
5. батчировать сегменты случайной линейной комбинацией.

Сегментация не должна автоматически умножать `query_count` на число
сегментов.

## 11. FRI-профили

### 11.1. Ordinary FRI baseline

Обязательный reference-профиль:

- ordinary FRI;
- Fiat-Shamir;
- Merkle multiproof;
- доказанная надежность не хуже:
  \[
  2^{-128};
  \]
- без OODS/DEEP-композиции.

Он нужен для differential проверки оптимизированного профиля.

### 11.2. OODS/DEEP-FRI production candidate

Оптимизированный профиль использует раскрытия вне исходного домена и
DEEP-композицию.

Цель:

- уменьшить `query_count`;
- сократить calldata;
- уменьшить число дорогих умножений \(\mathbb F_q\).

DEEP-FRI не меняет проверяемое MNT4-отношение. Он меняет low-degree proof.

### 11.3. Пропуск FRI-слоев

Binary baseline:

```text
32768 -> 16384 -> ... -> 16
```

Оптимизированный verifier должен поддерживать schedule:

\[
(s_0,s_1,\ldots,s_t),
\]

где один раунд уменьшает домен в:

\[
2^{s_i}
\]

раз.

Для предварительной модели schedule:

```text
(1, 2, 2, 4, 2)
```

уменьшил:

| Показатель | Binary | Layer skipping |
|---|---:|---:|
| FRI field values | \(6994\) | \(6208\) |
| Merkle frontier hashes | \(13352\) | \(3983\) |
| Payload | \(1\,098\,688\) байт | \(723\,424\) байт |
| Worst-case calldata | \(17\,579\,008\) gas | \(11\,574\,784\) gas |
| Ориентир FRI-умножений | \(6994\) | \(6208\) |
| Gas умножений при \(2959\) gas/op | \(20\,695\,246\) | \(18\,369\,472\) |
| Сумма двух компонентов | \(38\,274\,254\) | \(29\,944\,256\) |

Это предварительная модель. Она не учитывает локальную интерполяцию
повышенной арности, source openings и control-flow overhead.

Rust cost-model обязан перебрать schedules и выбрать минимум полной
стоимости, а не только calldata.

### 11.4. Последний слой

Когда размер домена становится малым, prover передает коэффициенты
финального полинома. Контракт вычисляет его значение самостоятельно.

Порог `last_layer_size` выбирается Rust cost-model.

## 12. Fiat-Shamir transcript

Нужны доменно-разделенные challenges:

```text
beta       = H(domain || config || root_source)
alpha      = H(domain || beta || root_ext_quotient)
gamma      = H(domain || alpha || root_eval)
eta        = H(domain || gamma || root_composition)
rho        = H(domain || eta || roots_for_batch)
deep_z     = H(domain || rho || roots_before_oods)      // DEEP profile only
fri_alpha  = H(domain || round || fri_root)
v          = H(domain || roots_before_opening || fri_alpha)
queries    = H(domain || all_roots || final_poly)
```

Каждый challenge приводится к \(\mathbb F_q\) канонически.

Запрещено:

- выбирать challenge до соответствующего commitment;
- повторно использовать domain separator разных уровней;
- принимать неканонические элементы поля;
- допускать неоднозначную сериализацию.

## 13. API Solidity verifier-а

```solidity
function verifyEquation(
    G1Point calldata p,
    G1Point calldata r,
    bytes calldata proof
) external view returns (bool);
```

Контракт хранит:

```text
Q, S
configDigest
fixedShardAddresses[]
fixedShardCodeHashes[]
domain parameters
block partition
basis version
FRI profile
```

Контракт не принимает:

- произвольные \(Q,S\);
- произвольные линии;
- произвольные делители без proof;
- адреса shards при каждом вызове;
- replay/domain metadata, не относящиеся к математическому утверждению.

## 14. Proof layout

```text
ProofHeader
  version
  configDigest
  rootSource
  rootExtQuotient
  rootEvaluation
  rootComposition
  friRoots[]
  finalPolynomialCoefficients[]

ResidueWitness
  c
  cInverse
  scalingTerms

OodsBundle                  // DEEP profile only
  points[]
  values[]

QueryBundle[]
  queryIndex
  packedSourceLeaf
  sourceMerkleMultiproof
  compositionValue
  compositionMerkleProof
  FriRoundOpening[]
    values[]
    merkleMultiproof
```

Фактический binary format задается Rust-сериализатором. ABI-массивы не
должны использоваться во внутреннем hot path.

Offsets фиксированных shards не передаются в proof. Контракт выводит их из:

\[
\operatorname{queryIndex}
\]

и из таблицы отображения конфигурации.

## 15. Что выполняет Rust backend

### 15.1. Indexer

Однократно:

1. фиксирует \(Q,S\);
2. строит signed-digit ate loop;
3. выбирает разбиение блоков;
4. строит сжатые делители;
5. выбирает tower или normal basis;
6. строит `code-shards`;
7. вычисляет `configDigest`;
8. генерирует Solidity-конфигурацию.

### 15.2. Prover

Для каждого \(P,R\):

1. проверяет точки;
2. строит residue witness \(c,c^{-1}\);
3. строит block-compressed multi-Miller witness;
4. строит динамическую ленту \(C(T)\);
5. строит evaluator columns;
6. строит объединенный extension quotient;
7. строит composition oracle;
8. выполняет LDE;
9. строит Merkle roots;
10. воспроизводит Fiat-Shamir transcript;
11. строит ordinary FRI или DEEP-FRI proof;
12. сериализует proof.

### 15.3. Cost-model

До Solidity-кода Rust должен перебрать:

- равномерные и адаптивные block partitions;
- tower и normal basis;
- ordinary FRI и DEEP-FRI;
- `query_count`;
- layer-skipping schedules;
- `last_layer_size`;
- leaf packing;
- Merkle multiproof layouts.
- сегментацию LDE-доменов.

Для каждого профиля выводятся:

- soundness;
- proof bytes;
- calldata gas;
- число Merkle hashes;
- число \(\mathbb F_q\)-сложений;
- число \(\mathbb F_q\)-умножений;
- число \(\mathbb F_q\)-инверсий;
- нижняя оценка gas;
- ожидаемая оценка gas;
- prover time;
- peak memory.

## 16. Что выполняет Solidity verifier

1. Проверяет `configDigest`.
2. Проверяет каноничность публичной сериализации \(P,R\); принадлежность
   кривой и подгруппе проверяется доказываемым relation.
3. Воспроизводит Fiat-Shamir transcript.
4. Читает sampled fixed coefficients из заранее зафиксированных
   `code-shards`.
5. Проверяет Merkle multiproof динамических таблиц.
6. Проверяет column-wise relations.
7. Проверяет объединенное extension-field relation.
8. Проверяет block-compressed Miller relation.
9. Проверяет residue relation.
10. Проверяет boundary constraints.
11. Проверяет ordinary FRI или DEEP-FRI proof.
12. Возвращает `true` только при выполнении всех проверок.

## 17. Soundness

Итоговая ошибка ограничивается суммой:

\[
\varepsilon_{\mathrm{total}}
\le
\varepsilon_{\mathrm{hash}}
+
\varepsilon_{\mathrm{FS}}
+
\varepsilon_{\mathrm{SZ}}
+
\varepsilon_{\mathrm{FRI}}
+
\varepsilon_{\mathrm{boundary}}.
\]

Требование production-профиля:

\[
\varepsilon_{\mathrm{total}}
\le
2^{-128}.
\]

Rust backend должен сформировать:

```text
security_report.json
```

с отдельными численными значениями каждого слагаемого.

Нельзя объявлять профиль production-ready только по числу запросов.

## 18. Предварительная gas-модель

### 18.1. Отрицательный row-major baseline

Прежняя широкая трасса:

\[
138\,018\,816\text{ gas}
\]

только на первичную calldata. Ее реализовывать не нужно.

### 18.2. Узкий native-field baseline

Для binary ordinary FRI:

\[
38.3\text{--}55.1\text{ млн gas}
\]

на два крупных FRI-компонента до source openings и локальных проверок.

### 18.3. Layer-skipping candidate

Для предварительного schedule:

```text
(1, 2, 2, 4, 2)
```

два крупных компонента дают:

\[
29\,944\,256\text{ gas}.
\]

Это не итоговая стоимость. Но нижняя модель оставляет запас относительно:

\[
93\,879\,746\text{ gas}
\]

Article640 fixed-shards verifier-а.

## 19. Stop/go критерии

### 19.1. После Rust cost-model

Переходить к Solidity имеет смысл, если строгий профиль показывает:

\[
G_{\mathrm{expected}}
<
93\,879\,746.
\]

Желательная цель:

\[
G_{\mathrm{expected}}
<
60\,000\,000.
\]

### 19.2. После Solidity verifier-а

Реализация считается успешной, если:

1. valid proof принимается;
2. tamper любого динамического значения отклоняется;
3. tamper Merkle path отклоняется;
4. tamper fixed shard configuration отклоняется;
5. tamper residue witness отклоняется;
6. tamper FRI root отклоняется;
7. tamper final polynomial отклоняется;
8. differential result совпадает с Rust reference;
9. измеренный gas ниже Article640 fixed-shards baseline;
10. сформирован security report не хуже \(2^{-128}\).

## 20. Последовательность реализации

### N1. Rust cost-model

- реализовать profile optimizer;
- выбрать block partition;
- сравнить basis;
- сравнить ordinary FRI и DEEP-FRI;
- выбрать layer-skipping schedule;
- сформировать stop/go отчет.

### N2. Rust indexer

- сгенерировать fixed divisors;
- собрать `code-shards`;
- сгенерировать Solidity config.

### N3. Rust prover ordinary FRI

- реализовать минимальный корректный baseline;
- добавить differential tests.

### N4. Rust prover DEEP-FRI

- добавить OODS/DEEP-композицию;
- сравнить proof size и стоимость verifier-а.

### N5. Solidity verifier

- реализовать только профиль, выбранный cost-model;
- использовать packed bytes и потоковый parser;
- читать fixed tables через `EXTCODECOPY`;
- использовать Merkle multiproof;
- не добавлять ABI arrays в hot path.

### N6. Проверка

- correctness;
- negative tests;
- gas report;
- security report;
- сравнение с Article640 fixed-shards.

## 21. Что не входит в реализацию

- Groth16;
- BN254 non-native circuit;
- MNT4/MNT6 folding;
- универсальный API \(Y=e(P,Q)\);
- parametric \(Q,S\);
- recursive compression;
- production audit.

## 22. Проверенные источники

1. Housni, E. и др. *On Proving Pairings*. ePrint 2024/640:
   https://eprint.iacr.org/2024/640.pdf
2. Ben-Sasson, E. и др. *Fast Reed-Solomon Interactive Oracle Proofs of
   Proximity*. ECCC TR17-134:
   https://eccc.weizmann.ac.il/report/2017/134/
3. Ben-Sasson, E. и др. *DEEP-FRI: Sampling Outside the Box Improves
   Soundness*. ITCS 2020:
   https://drops.dagstuhl.de/entities/document/10.4230/LIPIcs.ITCS.2020.5
4. Starknet. *FRI Protocol*:
   https://zksecurity.github.io/RFCs/rfcs/starknet/fri.html
5. StarkWare. *stone-prover*:
   https://github.com/starkware-libs/stone-prover
6. Meta. *Winterfell*:
   https://github.com/facebook/winterfell
