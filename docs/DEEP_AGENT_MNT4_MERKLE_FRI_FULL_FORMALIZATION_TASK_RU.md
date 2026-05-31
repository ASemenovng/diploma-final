# Задание для deep agent: полная формализация Merkle/FRI-проверки цикла Миллера для MNT4-753

## 1. Цель исследования

Нужно подготовить полностью замкнутую математическую и инженерную спецификацию нового verifier-а для EVM. Verifier должен заменить дорогое on-chain исполнение цикла Миллера при проверке MNT4-753 pairing equation на компактную проверку полиномиальных отношений с Merkle commitments и FRI.

После выполнения исследования спецификация должна быть достаточной для непосредственной реализации:

- Rust backend, который строит witness и доказательство;
- Solidity/Yul verifier, который проверяет доказательство;
- тестовые векторы;
- негативные тесты;
- точный gas- и calldata-бюджет;
- формальное обоснование корректности и soundness.

В итоговом исследовании не должно остаться пунктов вида «нужно дополнительно выбрать», «следует доказать», «можно использовать некоторый commitment» или «параметры определяются позднее». Если предлагаемый подход нельзя сделать корректным или практически осмысленным, это также является допустимым результатом, но отрицательный вывод должен быть формально обоснован.

## 2. Что будет передано вместе с этим заданием

Второй входной документ:

`MNT4_MERKLE_FRI_POLYNOMIAL_MILLER_SPEC_RU.md`

Он содержит текущий проект спецификации. Его нельзя считать заведомо корректным. Нужно провести независимый аудит, исправить формальные ошибки и при необходимости заменить предложенную конструкцию более строгой.

У агента нет доступа к исходному коду проекта. Поэтому вся существенная информация о текущей реализации приведена ниже. Если для проверки гипотез нужны вычислительные эксперименты, следует написать быстрый Rust-код. Не использовать Python для тяжелой арифметики больших конечных полей.

## 3. Исходная задача

Проверяется pairing equation с двумя фиксированными точками второй группы:

\[
e(P,Q)\cdot e(-R,S)=1,
\]

где:

- \(P,R\in G_1\) передаются пользователем;
- \(Q,S\in G_2\) фиксируются при развертывании verifier-а;
- \(e\) — приведенное ate-сопряжение на MNT4-753;
- контракт должен вернуть `true` только тогда, когда равенство выполнено.

Такой интерфейс выбран не случайно. Проверка равенства двух сопряжений

\[
e(P,Q)=e(R,S)
\]

эквивалентна приведенному выше уравнению благодаря билинейности и свойству

\[
e(-R,S)=e(R,S)^{-1}.
\]

## 4. Что уже реализовано в прямом verifier-е

В существующей реализации цикл Миллера исполняется on-chain целиком. Коэффициенты линий для фиксированных точек \(Q\) и \(S\) предварительно вычисляются off-chain и сохраняются в неизменяемых data-contract shards. Основной verifier читает коэффициенты через `EXTCODECOPY`.

Это корректный режим: пользователь не может подменить кэш, поскольку адреса shards фиксируются в состоянии verifier-а при развертывании.

### 4.1. Текущая residue-рекурсия

Пусть \(c\in \mathbb F_{q^4}^{*}\) — witness для замены полной финальной экспоненты, а \(c^{-1}\) — переданное и проверяемое обратное значение:

\[
c\cdot c^{-1}=1.
\]

Текущая MNT4-реализация инициализирует аккумулятор:

\[
F\gets c^{-1}.
\]

Для каждого signed-digit шага ate loop:

1. выполняется
   \[
   F\gets F^2;
   \]
2. применяются prepared sparse линии для обеих фиксированных точек:
   \[
   F\gets F\cdot \ell^{Q,\mathrm{dbl}}_i(P)\cdot
   \ell^{S,\mathrm{dbl}}_i(-R);
   \]
3. если signed digit равен \(+1\), выполняется
   \[
   F\gets F\cdot
   \ell^{Q,\mathrm{add}}_i(P)\cdot
   \ell^{S,\mathrm{add}}_i(-R)\cdot c^{-1};
   \]
4. если signed digit равен \(-1\), выполняется
   \[
   F\gets F\cdot
   \ell^{Q,\mathrm{add}}_i(P)\cdot
   \ell^{S,\mathrm{add}}_i(-R)\cdot c.
   \]

После основного цикла применяются tail-линии, обусловленные MNT4 ate parameter, затем Frobenius-tail:

\[
F\gets F\cdot \operatorname{Frob}_{q}(c^{-1}).
\]

Verifier принимает доказательство тогда и только тогда, когда:

\[
F=1.
\]

### 4.2. Текущие параметры цикла

В существующей реализации:

- длина кодирования ate loop: \(377\) signed digits;
- число основных итераций: \(376\);
- число ненулевых addition-шагов: \(319\);
- используются tail-линии и Frobenius-tail;
- базовое поле MNT4-753 имеет размер около \(753\) бит;
- поле результата сопряжения представлено башней:
  \[
  \mathbb F_q \subset \mathbb F_{q^2}\subset \mathbb F_{q^4}.
  \]

Агент должен независимо извлечь и проверить точные параметры из официальной реализации `ark-mnt4-753`: модули полей, коэффициенты кривой, twist, ate loop parameter, signed-digit representation, Frobenius constants и все tail-формулы.

### 4.3. Измеренные значения газа

Текущие воспроизводимые ориентиры:

| Режим | Gas |
|---|---:|
| Полное on-chain reference-вычисление MNT4 pairing digest | \(259\,719\,954\) |
| Цикл Миллера без финальной экспоненты, оптимизированный hot path | \(87\,747\,219\) |
| Pairing equation: цикл Миллера + обычная финальная экспонента | \(115\,997\,313\) |
| Pairing equation: цикл Миллера + residue-проверка | \(93\,879\,746\) |

Стоимость базовых операций оптимизированной 3-limb арифметики:

| Операция | Gas/op |
|---|---:|
| Умножение в \(\mathbb F_q\) | \(2\,959\) |
| Возведение в квадрат в \(\mathbb F_q\) | \(2\,947\) |
| Умножение в \(\mathbb F_{q^2}\) | \(11\,877\) |
| Возведение в квадрат в \(\mathbb F_{q^2}\) | \(10\,592\) |
| Умножение в \(\mathbb F_{q^4}\) | \(42\,764\) |
| Возведение в квадрат в \(\mathbb F_{q^4}\) | \(36\,606\) |

Кэш sparse-линий:

| Объект | Размер |
|---|---:|
| Double-линии одной фиксированной \(G_2\)-точки | \(216\,576\) байт |
| Addition-линии одной фиксированной \(G_2\)-точки | \(122\,880\) байт |
| Полный кэш одной фиксированной точки | \(339\,456\) байт |
| Полный кэш двух точек \(Q,S\) | \(678\,912\) байт |

### 4.4. Почему требуется новый подход

Prepared lines уменьшают стоимость, поскольку контракт не выполняет арифметику \(G_2\) для построения линий. Однако verifier все равно последовательно исполняет каждое обновление аккумулятора:

\[
F_{i+1}=F_i^2\cdot \ell_i^Q(P)\cdot \ell_i^S(-R)\cdot \rho_i(c),
\]

где \(\rho_i(c)\in\{1,c,c^{-1}\}\).

Главный остаточный расход — сотни операций в \(\mathbb F_{q^4}\). Merkle/FRI-подход должен убрать именно это последовательное on-chain исполнение.

## 5. Теоретический источник

Основной источник:

- N. El Housni, *On Proving Pairings*, IACR ePrint 2024/640:  
  https://eprint.iacr.org/2024/640.pdf

Важно разделять две идеи статьи:

1. замена полной финальной экспоненты relation-проверкой с witness \(c\);
2. randomized checking арифметики расширенного поля через полиномиальные отношения.

Статья описывает интерактивные и in-circuit протоколы проверки арифметики расширенного поля. Она не предоставляет готовый Solidity verifier с Merkle/FRI для MNT4-753. Merkle/FRI-версия является адаптацией идей статьи. Агент должен строго доказать ее корректность, а не ссылаться на статью как на готовую реализацию.

Полезные первичные источники:

- E. Ben-Sasson et al., *Fast Reed-Solomon Interactive Oracle Proofs of Proximity*, ICALP 2018:  
  https://drops.dagstuhl.de/storage/00lipics/lipics-vol107-icalp2018/LIPIcs.ICALP.2018.14/LIPIcs.ICALP.2018.14.pdf
- E. Ben-Sasson et al., *Scalable, transparent, and post-quantum secure computational integrity*, IACR ePrint 2018/046:  
  https://eprint.iacr.org/2018/046
- E. Ben-Sasson et al., *Interactive Oracle Proofs*, IACR ePrint 2016/116:  
  https://eprint.iacr.org/2016/116
- EIP-2028, calldata gas cost reduction:  
  https://eips.ethereum.org/EIPS/eip-2028
- официальная документация `ark-mnt4-753`:  
  https://docs.rs/ark-mnt4-753/latest/ark_mnt4_753/
- исходный код параметров arkworks:  
  https://github.com/arkworks-rs/curves/tree/master/mnt4_753

## 6. Что именно требуется построить

Нужно формализовать production-ready протокол:

```text
Rust backend
  -> вычисляет корректный MNT4 residue trace
  -> строит trace-oracles и quotient-oracles
  -> строит Merkle commitments
  -> получает Fiat-Shamir challenges
  -> строит FRI low-degree proof
  -> сериализует compact proof

Solidity/Yul verifier
  -> получает P, R и compact proof
  -> восстанавливает Fiat-Shamir transcript
  -> проверяет boundary constraints
  -> проверяет Merkle multiproofs
  -> проверяет quotient relation в sampled rows
  -> проверяет FRI proof
  -> возвращает true/false
```

On-chain verifier не должен:

- исполнять полный цикл Миллера;
- выполнять сотни последовательных умножений в \(\mathbb F_{q^4}\);
- принимать непроверенные произвольные значения линий;
- доверять trace без Merkle commitment;
- доверять quotient без проверки low-degree property;
- использовать секретный trusted off-chain oracle.

### 6.1. Обязательное требование: неинтерактивная схема

Целевой production-протокол должен быть неинтерактивным. Пользователь формирует
один самодостаточный объект `proof.bin` off-chain и передает его в одном вызове
Solidity verifier-а. После отправки транзакции дополнительные сообщения от
prover-а не допускаются.

Интерактивные раунды исходного IOP и FRI используются только как математическая
основа. В production-схеме они должны быть преобразованы с помощью
Fiat--Shamir transform в random oracle model:

1. prover строит очередные commitments;
2. challenge детерминированно вычисляется как результат доменно-разделенного
   хеширования текущего transcript;
3. prover добавляет следующие commitments или openings;
4. Solidity verifier повторяет те же вычисления challenges из переданного
   `proof.bin` и публичных входов.

Таким образом, последовательность логических раундов сохраняется внутри
структуры доказательства, но сетевого взаимодействия между prover-ом и
verifier-ом нет.

Нужно доказать:

- что Fiat--Shamir transcript не содержит циклических зависимостей;
- что каждый challenge вычисляется только после commitments, которые он должен
  разделять;
- что prover не может подобрать openings после получения query indices;
- что один `proof.bin` достаточно передать в единственном on-chain вызове;
- что soundness неинтерактивной схемы корректно формулируется в random oracle
  model.

## 7. Требуемая математическая модель

### 7.1. След recurrence

Нужно зафиксировать точную последовательность переходов текущего MNT4 residue verifier-а. Для каждого шага определить:

- тип шага: doubling, addition \(+1\), addition \(-1\), tail, Frobenius-tail;
- входное состояние \(F_i\in\mathbb F_{q^4}\);
- выходное состояние \(F_{i+1}\in\mathbb F_{q^4}\);
- подготовленные sparse-коэффициенты линий для \(Q\) и \(S\);
- точное значение \(\rho_i(c)\);
- точную формулу перехода.

Требуется доказать:

> Выполнение всей последовательности trace constraints эквивалентно выполнению текущего прямого residue verifier-а, а принятие конечного состояния \(F_{\mathrm{final}}=1\) эквивалентно истинности pairing equation при выполнении всех предпосылок протокола.

### 7.2. Полиномиальное представление \(\mathbb F_{q^4}\)

Нужно зафиксировать точную башню расширений MNT4-753:

\[
\mathbb F_{q^2}=\mathbb F_q[u]/(u^2-\xi),
\qquad
\mathbb F_{q^4}=\mathbb F_{q^2}[v]/(v^2-\eta).
\]

Затем выбрать единое плоское представление элемента:

\[
A(Z)=a_0+a_1Z+a_2Z^2+a_3Z^3,
\]

и точный неприводимый многочлен:

\[
p(Z)\in\mathbb F_q[Z],
\qquad
\mathbb F_{q^4}\cong \mathbb F_q[Z]/(p(Z)).
\]

Для каждого умножения расширенного поля:

\[
A(Z)B(Z)\equiv C(Z)\pmod{p(Z)}
\]

должен существовать quotient:

\[
A(Z)B(Z)-C(Z)=H(Z)p(Z).
\]

Нужно вывести:

- точный вид \(p(Z)\);
- степени \(A,B,C,H\);
- число коэффициентов quotient;
- формулы коэффициентов;
- способ эффективного вычисления в Rust;
- способ дешевой проверки равенства в случайной точке \(\zeta\in\mathbb F_q\).

### 7.3. Уплотнение нескольких шагов

Нужно исследовать block compression: объединение \(d\) последовательных переходов цикла Миллера в одно полиномиальное отношение.

Проверить значения:

\[
d\in\{1,4,5,6\}.
\]

Для каждого \(d\) вывести:

- точную степень итогового отношения;
- число trace rows;
- число witness columns;
- число quotient columns;
- число committed field elements;
- размер Merkle leaves;
- число openings;
- итоговый gas- и calldata-бюджет.

Нужно выбрать оптимальное \(d\) не эвристически, а по воспроизводимой модели стоимости.

### 7.4. Fixed prepared divisors

Статья использует представление функций линий и modified divisors. Для MNT4-753 требуется вывести точный формат prepared fixed-\(G_2\) данных.

Для фиксированных \(Q,S\) нужно определить:

- какие коэффициенты рассчитываются один раз при подготовке;
- какие полиномы или таблицы фиксируются в verifier-е;
- как вычисляется значение линии при произвольных \(P\) и \(-R\);
- как данные связаны с обычным sparse line format прямого verifier-а;
- какие committed tables являются публичными константами;
- как проверить, что их Merkle roots действительно соответствуют каноническим \(Q,S\).

Нельзя ограничиться формулировкой «используются подготовленные делители». Нужны явные формулы и точный бинарный формат.

## 8. Обязательный аудит текущего проекта спецификации

Текущая версия `MNT4_MERKLE_FRI_POLYNOMIAL_MILLER_SPEC_RU.md` содержит полезную основу, но в ней обнаружены потенциальные формальные разрывы. Агент обязан проверить каждый пункт и исправить его.

### 8.1. Циклическая зависимость transcript

В текущем проекте `rootTrace` местами включает quotient values. При этом quotient строится после challenges, которые выводятся из `rootTrace`.

Это циклическая зависимость.

Нужно строго разделить:

1. commitments к pre-challenge witness-oracles;
2. challenge \(\beta\);
3. commitments к quotient-oracles;
4. challenge \(\zeta\);
5. composition commitment;
6. FRI commitments;
7. query challenges.

Или предложить иной корректный transcript и доказать отсутствие циклов.

### 8.2. Неопределенные boundary terms

Нужно явно описать:

- remainder при \(376=75\cdot 5+1\), если выбирается \(d=5\);
- signed addition steps;
- tail lines;
- отрицательный ate loop parameter;
- Frobenius-tail;
- проверку \(c\cdot c^{-1}=1\);
- начальное состояние \(F_0=c^{-1}\);
- конечное состояние \(F_{\mathrm{final}}=1\).

### 8.3. Неполный soundness-анализ FRI

Недопустимо использовать только эвристику вида:

\[
\left(\frac{1}{16}\right)^{64}=2^{-256}.
\]

Нужно выбрать конкретный вариант FRI и вывести полную количественную оценку soundness:

- Reed-Solomon proximity soundness;
- blowup factor;
- число query rounds;
- folding schedule;
- terminal degree;
- ошибка batching через challenge \(\eta\);
- ошибка randomized quotient checking через \(\beta\) и \(\zeta\);
- Fiat-Shamir в random oracle model;
- вероятность коллизии Keccak-256;
- возможные зависимости между committed oracles.

Целевой уровень:

\[
\varepsilon_{\mathrm{total}}\le 2^{-128}.
\]

### 8.4. Неопределенный FRI domain

Нужно явно выбрать:

- trace domain \(H\);
- low-degree extension domain \(L\);
- генераторы;
- coset shift;
- размеры;
- fold mapping;
- правило выбора пар \(x,-x\);
- layer domains;
- terminal polynomial;
- selector polynomials;
- vanishing polynomial;
- правило проверки, что знаменатель quotient не равен нулю.

Все значения должны быть совместимы с \(\mathbb F_q\) MNT4-753. Проверить 2-adicity \(q-1\) и реально доступные размеры подгрупп.

### 8.5. Получение challenges в 753-битном поле

`keccak256` возвращает 256 бит, а элемент \(\mathbb F_q\) занимает около 753 бит.

Нужно выбрать и обосновать точный алгоритм:

- domain-separated expansion несколькими вызовами Keccak;
- rejection sampling;
- либо безопасное вложение 256-битного challenge subset с доказанной оценкой ошибки.

Для каждой challenge-переменной привести точное правило сериализации и получения:

\[
\beta,\;\zeta,\;\eta,\;\text{FRI folds},\;\text{query indices}.
\]

### 8.6. FRI batching

Если несколько committed columns объединяются:

\[
B(X)=\sum_{j=0}^{m-1}\eta^j C_j(X),
\]

требуется доказать:

- какие commitments публикуются до выбора \(\eta\);
- почему случайная линейная комбинация сохраняет soundness;
- какие degree bounds назначены каждому \(C_j\);
- можно ли объединять trace, quotient и auxiliary columns одним \(\eta\);
- как verifier проверяет consistency открытий.

### 8.7. Fixed-table trust model

Merkle root фиксированной таблицы подтверждает неизменность таблицы, но сам по себе не доказывает, что таблица соответствует точкам \(Q,S\).

Нужно выбрать production-модель:

1. канонические roots зашиты в код verifier-а;
2. roots передаются конструктору и проверяются процедурой deployment audit;
3. roots сопровождаются one-time proof корректности;
4. иной строго обоснованный вариант.

Требуется описать:

- предположение доверия;
- процедуру генерации;
- способ независимо воспроизвести roots;
- тестовый вектор;
- риск подмены.

### 8.8. AIR/STARK-подобная адаптация против исходного IOP статьи

В текущем проекте предложена trace/AIR-подобная конструкция с отдельными вспомогательными колонками и quotient constraints. В статье описан randomized columnwise evaluation IOP для arithmetic over extension fields.

Нужно сравнить минимум три варианта:

1. прямое инстанцирование IOP из Section 6 статьи с Merkle+FRI PCS;
2. текущая AIR/STARK-подобная trace quotient адаптация;
3. гибридная конструкция, если она дает меньший proof/gas.

Для каждого варианта:

- привести точные отношения;
- доказать корректность;
- оценить число колонок;
- оценить степени;
- оценить calldata;
- оценить gas;
- оценить сложность Rust backend.

После сравнения выбрать один production-кандидат.

## 9. Формальная спецификация Merkle PCS

Нужно полностью зафиксировать:

- hash-функцию: Keccak-256;
- доменное разделение для leaf/internal nodes;
- порядок байтов;
- canonical encoding элементов \(\mathbb F_q\);
- leaf layouts;
- tree padding;
- tree depth;
- multiproof format;
- правила дедупликации siblings;
- сортировку индексов;
- проверку duplicate indices;
- проверку out-of-range indices;
- защиту от ambiguous encodings.

Нужно отдельно описать Merkle trees для:

- фиксированных divisor/selector tables;
- dynamic trace columns;
- quotient columns;
- batched composition oracle;
- FRI layers.

Для каждого дерева привести:

- размер;
- число листьев;
- размер листа в байтах;
- root;
- набор открытий, который реально передается verifier-у.

## 10. Формальная спецификация FRI

Нужно выбрать конкретный FRI-протокол и привести:

1. commitment phase;
2. folding equations;
3. challenge generation;
4. query phase;
5. Merkle openings;
6. terminal polynomial;
7. acceptance predicate;
8. degree bound;
9. soundness theorem;
10. параметры для безопасности не ниже 128 бит.

Не использовать фразу «стандартная FRI-проверка» без раскрытия алгоритма.

## 11. Fiat-Shamir transcript

Нужно определить точный последовательный transcript. Для каждого шага указать:

- строковый domain tag;
- номер версии протокола;
- `chainId`, если он нужен;
- адрес verifier-а, если он нужен;
- точки \(P,R\);
- фиксированные roots;
- dynamic roots;
- предыдущие challenges;
- текущие roots;
- порядок сериализации;
- правила получения challenge.

Нужно доказать:

- commitments делаются до challenges, от которых зависят;
- prover не может адаптивно подобрать quotient после query indices;
- отсутствуют циклические зависимости;
- один proof нельзя интерпретировать в другом протоколе или другой версии.

## 12. Точный формат proof

Нужна бинарная спецификация `proof.bin`, пригодная для прямого разбора в Solidity/Yul без ABI-массивов.

Для каждого сегмента указать:

- offset;
- length;
- число элементов;
- размер элемента;
- endianess;
- допустимый диапазон;
- какой этап verifier-а его читает.

Минимально включить:

- protocol version;
- Merkle roots;
- claimed terminal data;
- sampled trace rows;
- sampled quotient rows;
- fixed-table openings;
- dynamic Merkle multiproofs;
- FRI layer values;
- FRI Merkle multiproofs;
- terminal polynomial coefficients.

Нужно рассчитать полный worst-case размер proof в байтах.

## 13. Gas-модель

Нужно получить воспроизводимую аналитическую оценку gas:

### 13.1. Calldata

По EIP-2028:

- ненулевой calldata byte: \(16\) gas;
- нулевой calldata byte: \(4\) gas.

Дать:

- worst-case стоимость;
- реалистичную стоимость на generated fixture;
- разбивку по сегментам proof.

### 13.2. Выполнение verifier-а

Подсчитать:

- число вызовов Keccak;
- число Merkle hash steps;
- число проверок multiproof;
- число операций в \(\mathbb F_q\);
- число проверок quotient identity;
- число FRI folds;
- число boundary checks;
- memory expansion;
- `calldataload`, `mload`, `mstore`;
- ожидаемый runtime gas.

### 13.3. Профили параметров

Сравнить минимум:

- block compression \(d=1,4,5,6\);
- несколько blowup factors;
- несколько query counts;
- отдельные trees против batched trees;
- обычные Merkle paths против multiproofs;
- фиксированные таблицы в code-shards против Merkle openings, если оба варианта допустимы.

Вывести итоговую таблицу:

| Профиль | Proof bytes | Calldata gas | Runtime gas | Total gas | Soundness bits |
|---|---:|---:|---:|---:|---:|

Целевой вопрос:

> Становится ли production-ready Merkle/FRI verifier существенно дешевле текущего direct residue verifier с \(93\,879\,746\) gas?

Не подгонять вывод под желаемый ответ.

## 14. Rust backend

Нужно описать точные модули будущего Rust backend:

```text
mnt4_params
fixed_tables
residue_trace
block_compression
extension_quotients
air_or_iop
merkle
fri
transcript
proof_format
fixture_generator
gas_model
```

Для каждого модуля указать:

- входы;
- выходы;
- алгоритм;
- инварианты;
- тесты.

Нужно предоставить сигнатуры основных Rust-функций и псевдокод. Если агент пишет вычислительные утилиты для подтверждения параметров, приложить их исходный Rust-код.

## 15. Solidity/Yul verifier

Нужно описать итоговый API:

```solidity
function verifyEquation(
    G1Point calldata p,
    G1Point calldata r,
    bytes calldata proof
) external view returns (bool);
```

Если требуются дополнительные публичные параметры, обосновать каждый из них.

Нужно определить:

- constructor arguments;
- immutable values;
- fixed roots;
- порядок проверок;
- Yul hot paths;
- memory layout;
- способ early return при некорректном proof;
- отсутствие циклов, зависящих от неконтролируемой длины пользовательского массива;
- верхнюю границу газа.

## 16. Корректность и безопасность

Нужно сформулировать и доказать:

### Теорема полноты

Если:

- \(e(P,Q)e(-R,S)=1\);
- Rust backend честно построил trace;
- commitments, quotient-oracles и FRI proof построены по спецификации;

то Solidity verifier принимает proof.

### Теорема soundness

Если Solidity verifier принимает proof, то кроме события с вероятностью не более

\[
\varepsilon_{\mathrm{total}}\le 2^{-128},
\]

выполнено:

\[
e(P,Q)e(-R,S)=1.
\]

Нужно явно перечислить все предположения:

- криптографическая стойкость Keccak-256;
- random oracle model для Fiat-Shamir;
- корректность фиксированных таблиц;
- свойства MNT4-753;
- Reed-Solomon proximity soundness;
- Schwartz-Zippel bounds;
- canonical encoding.

Отдельно привести сумму всех ошибок:

\[
\varepsilon_{\mathrm{total}}
\le
\varepsilon_{\mathrm{Merkle}}
+
\varepsilon_{\mathrm{quotient}}
+
\varepsilon_{\mathrm{batch}}
+
\varepsilon_{\mathrm{FRI}}
+
\varepsilon_{\mathrm{FS}}.
\]

## 17. Тестовые векторы

Нужно подготовить точные тестовые векторы:

1. корректное уравнение для генераторов;
2. корректное уравнение для нескольких скаляров;
3. некорректный \(P\);
4. некорректный \(R\);
5. подмена trace row;
6. подмена quotient row;
7. подмена fixed-table opening;
8. подмена Merkle sibling;
9. подмена FRI fold value;
10. подмена terminal polynomial;
11. повторное использование proof с другими \(P,R\);
12. неправильная canonical encoding;
13. неправильная длина proof;
14. duplicate Merkle indices;
15. out-of-range Merkle indices.

Для каждого теста указать ожидаемый результат и причину отказа.

## 18. Что нельзя считать достаточным результатом

Недостаточно:

- проверить несколько Merkle paths без FRI;
- измерить prototype gas только для Merkle opening;
- написать общие формулы \(a_i(\alpha)b_i(\alpha)=c_i(\alpha)\) без привязки к реальным переходам цикла Миллера;
- передать quotient values без low-degree proof;
- доверять fixed-table root без описания trust model;
- использовать эвристическую оценку soundness;
- назвать Article 640 готовой спецификацией Merkle/FRI verifier-а;
- оставить выбор параметров на этап реализации.

Для ориентира: существующий компонентный prototype дает около \(46\,402\) gas для небольшой группы Merkle openings. Это не стоимость полного Merkle/FRI verifier-а и не должно использоваться как итоговая метрика.

## 19. Обязательные результаты исследования

Агент должен вернуть один самостоятельный Markdown-документ со следующими разделами:

1. Краткий вердикт: реализуемо ли решение.
2. Аудит текущего проекта спецификации.
3. Исправленная математическая модель MNT4 residue trace.
4. Вывод fixed prepared divisor representation.
5. Сравнение IOP/AIR/hybrid вариантов.
6. Выбранный production-протокол.
7. Полная спецификация Merkle PCS.
8. Полная спецификация FRI.
9. Полный Fiat-Shamir transcript.
10. Формат `proof.bin`.
11. Теоремы полноты и soundness с доказательствами.
12. Таблица параметров безопасности.
13. Gas-модель с численными результатами.
14. Calldata-модель с численными результатами.
15. Сигнатуры Rust backend.
16. API Solidity verifier-а.
17. План реализации по шагам.
18. Набор тестовых векторов.
19. Реестр рисков и ограничений.
20. Список первичных источников.

## 20. Критерии готовности исследования

Исследование считается завершенным только если выполнены все пункты:

- [ ] Точная MNT4-753 residue recurrence независимо проверена.
- [ ] Все параметры MNT4-753 извлечены из официального источника.
- [ ] Исправлена циклическая зависимость transcript.
- [ ] Зафиксирована неинтерактивная Fiat--Shamir-схема с одним `proof.bin` и
      одним on-chain вызовом.
- [ ] Формально описаны fixed divisor tables для \(Q,S\).
- [ ] Зафиксирован конкретный FRI variant.
- [ ] Зафиксированы trace и LDE domains.
- [ ] Проверена доступная 2-adicity поля.
- [ ] Выбраны параметры безопасности не ниже 128 бит.
- [ ] Доказана корректность challenge generation в 753-битном поле.
- [ ] Доказана корректность batching.
- [ ] Зафиксирована модель доверия fixed roots.
- [ ] Выбран и обоснован production-кандидат IOP/AIR/hybrid.
- [ ] Определены все leaf layouts.
- [ ] Определен multiproof format.
- [ ] Определен бинарный формат `proof.bin`.
- [ ] Рассчитан полный proof size.
- [ ] Рассчитан calldata gas.
- [ ] Рассчитан runtime gas.
- [ ] Результат сравнен с \(93\,879\,746\) gas.
- [ ] Доказаны completeness и soundness.
- [ ] Подготовлены Rust interfaces.
- [ ] Подготовлен Solidity API.
- [ ] Подготовлены позитивные и негативные тестовые векторы.
- [ ] Не осталось открытых математических или криптографических вопросов.

## 21. Дополнительное требование: критический режим исследования

Необходимо попытаться опровергнуть предлагаемый подход.

Если выяснится, что:

- FRI proof слишком велик;
- calldata стоит дороже прямого verifier-а;
- MNT4-753 не имеет подходящей подгруппы для выбранного domain;
- fixed divisor model некорректен;
- soundness нельзя довести до 128 бит без неприемлемой стоимости;
- Merkle/FRI не дает выигрыша относительно direct residue verifier-а;

нужно прямо зафиксировать отрицательный результат и показать расчет.

Цель исследования — получить корректную основу для реализации или строгий отрицательный вывод, а не подтвердить заранее выбранную гипотезу.
