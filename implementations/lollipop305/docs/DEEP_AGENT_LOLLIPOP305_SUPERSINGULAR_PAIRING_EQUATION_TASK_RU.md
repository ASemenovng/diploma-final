# Задание для deep agent: полная спецификация supersingular pairing equation для lollipop-305

## 0. Зачем нужен этот документ

У исполнителя **нет доступа к коду проекта**. Поэтому этот документ содержит весь необходимый контекст: цель дипломной работы, параметры кривых, уже проверенные численные соотношения, текущую неудачную попытку реализации, математический вопрос, который нужно закрыть, и точный формат результата.

Нужно выполнить самостоятельное математическое исследование и подготовить спецификацию, по которой затем можно будет реализовать verifier без дополнительных догадок.

Основные статьи:

1. C. Costello, G. Korpal. *Cycles of supersingular elliptic curves for pairing-based proof systems*, ePrint 2024/1627.
2. Y. El Housni et al. *On Proving Pairings*, ePrint 2024/640.

---

## 1. Общая цель дипломной работы

В дипломной работе исследуется, можно ли построить более дешевую основу для будущих рекурсивных доказательств и folding-схем, чем существующие подходы на больших pairing-friendly кривых.

Изначальный объект исследования — MNT4-753/MNT6-753. Для него уже было показано следующее.

1. Полное on-chain вычисление сопряжения на MNT4-753/MNT6-753 слишком дорого для практического использования в EVM.
2. Если переносить MNT4-арифметику в доказательство над BN254, возникает non-native arithmetic: элементы MNT4-поля приходится раскладывать на limb-ы и доказывать редукции в чужом поле. Это приводит к большому числу constraints.
3. Оптимизация финальной экспоненты из ePrint 2024/640 снижает стоимость, но не устраняет основную цену цикла Миллера.
4. Возникает trade-off: либо платить gas за арифметику on-chain, либо платить constraints/calldata за off-chain доказательства и polynomial commitment layer.

Статья ePrint 2024/1627 предлагает другой путь: использовать supersingular `lollipop`-конструкции, где часть арифметики может выполняться над меньшими полями. Для исследовательского примера `lollipop-305-158` базовые поля имеют около 305 бит. Это означает, что элемент поля помещается в 2 EVM-слова вместо 3 EVM-слов для MNT4-753. Поэтому нужно понять, можно ли на этих кривых получить более дешевую реализацию сопряжения и проверку pairing equation.

---

## 2. Что именно нужно исследовать

Нужно подготовить полную математическую спецификацию для двух supersingular cycle-кривых из lollipop-305-158:

1. `E_cycle / Fp2`, где pairing имеет порядок `q` и целевое поле `Fp4`.
2. `Ehat_cycle / Fq2`, где pairing имеет порядок `p` и целевое поле `Fq6`.

Для каждой кривой нужно понять:

1. какие группы участвуют в pairing;
2. какие подгруппы или eigenspace-условия нужны;
3. нужна ли distortion map;
4. какой именно Miller loop используется;
5. какой scalar используется в Miller loop;
6. как обрабатываются знаменатели Miller-функций;
7. какая финальная экспонента является корректной;
8. как записать residue-style проверку по идеям ePrint 2024/640;
9. как должна выглядеть pairing-equation API для verifier-а;
10. какие тесты однозначно подтверждают корректность.

Если текущая постановка невозможна или неверна, нужно строго объяснить почему и предложить корректную постановку.

---

## 3. Параметры lollipop-305-158

Используется Example 1 из ePrint 2024/1627.

Seed:

```text
x = 8004046504391788107635887004283725454478544674
```

Характеристики полей:

```text
p = x^2 - x + 1
q = x^2 + 1
```

Численно:

```text
p = 64064760444466402482617092084437280876782408929523650941985296571943203113725143542535221603
q = 64064760444466402482617092084437280876782408937527697446377084679579090118008868997013766277
```

Проверки по малым модулям:

```text
x ≡ 10 (mod 12)
p ≡ 7 (mod 12)
q ≡ 5 (mod 12)
```

Порядок подгруппы stick-кривой:

```text
r = 265533234376483119496574875659819072867998144101
```

Дополнительный 158-битный порядок для не-pairing cycle-части:

```text
r_hat = 265533234376483119496575739829042558313583244851
```

Вспомогательные значения:

```text
Nq = x^2 - 2x + 2
Np = x^2 + x + 1
```

Численные соотношения, которые уже проверены:

```text
p^2 + 1 = q * Nq
q^2 - q + 1 = p * Np
```

Для supersingular cycle-кривых из статьи:

```text
#E_cycle(Fp2)     = p^2 + 1     = q * Nq
#Ehat_cycle(Fq2)  = q^2 - q + 1 = p * Np
```

---

## 4. Кривые и поля

### 4.1 Stick curve

В lollipop-конструкции есть ordinary stick curve над `Fp` с embedding degree `k = 4` относительно порядка `r`. Эта часть уже использовалась как отдельный исследовательский ориентир.

Текущее задание **не требует заново выводить stick pairing**, но можно использовать его как аналогию для формата verifier-а.

Для stick verifier уже работает схема:

```text
Miller output f
final exponentiation: f^((p^4 - 1) / r)
residue witness: c such that c^r = f
```

Если существует `c` такое, что `c^r = f`, то:

```text
f^((p^4 - 1) / r) = (c^r)^((p^4 - 1) / r) = c^(p^4 - 1) = 1.
```

Именно эта идея нужна как ориентир, но для supersingular cycle-кривых надо вывести корректные аналоги.

### 4.2 Supersingular cycle curve `E_cycle / Fp2`

Из ePrint 2024/1627, Example 1:

```text
E_cycle / Fp2:
    y^2 = x^3 + (mu + 1) * x

Fp2 = Fp[mu] / (mu^2 + 1)
mu^2 = -1
```

Группа:

```text
#E_cycle(Fp2) = p^2 + 1 = q * Nq
```

Статья утверждает, что order-`q` Weil pairing on `E_cycle` имеет target group в:

```text
Fp4^*
```

Нужно вывести точную pairing-спецификацию для порядка `q`.

### 4.3 Supersingular cycle curve `Ehat_cycle / Fq2`

Из ePrint 2024/1627, Example 1:

```text
Ehat_cycle / Fq2:
    y^2 = x^3 + (eta + 2)

Fq2 = Fq[eta] / (eta^2 + 2)
eta^2 = -2
```

Группа:

```text
#Ehat_cycle(Fq2) = q^2 - q + 1 = p * Np
```

Статья утверждает, что order-`p` Weil pairing on `Ehat_cycle` имеет target group в:

```text
Fq6^*
```

Нужно вывести точную pairing-спецификацию для порядка `p`.

---

## 5. Башни расширений, которые использовались в текущих экспериментах

Эти башни не нужно принимать на веру. Их нужно проверить и подтвердить или заменить.

### 5.1 Для `Fp2`

```text
Fp2 = Fp[mu] / (mu^2 + 1),    mu^2 = -1.
```

### 5.2 Для `Fp4`

В текущих экспериментах использовалась башня:

```text
Fp4 = Fp2[v] / (v^2 - xi),
xi = 1 + mu.
```

Причина: вариант `v^2 = mu` нельзя автоматически считать корректным, потому что при данных параметрах `mu` может оказаться квадратом в `Fp2`. Нужно проверить, какая именно `Fp4`-башня совместима с pairing на `E_cycle/Fp2` и с формулами из ePrint 2024/1627.

### 5.3 Для `Fq2`

```text
Fq2 = Fq[eta] / (eta^2 + 2),    eta^2 = -2.
```

### 5.4 Для `Fq6`

Нужно вывести и зафиксировать корректную башню для `Fq6`, совместимую с `Ehat_cycle/Fq2` и target group order-`p` pairing.

Необходимо указать:

1. базовое поле;
2. расширение `Fq2`;
3. полином или tower-элемент для `Fq6`;
4. почему выбранный non-residue действительно подходит;
5. формулы Frobenius для этой башни;
6. стоимость умножения, возведения в квадрат и Frobenius на уровне компонент.

---

## 6. Текущая неудачная попытка для `E_cycle/Fp2`

Эта часть важна: нужно понять, является ли ошибка багом реализации, неверным выбором pairing equation или неверной математической постановкой.

### 6.1 Использованный экспериментальный формат

Была построена следующая попытка для `E_cycle/Fp2`.

1. Выбирается точка `P_source` на `E_cycle(Fp2)`.
2. Она очищается кофактором так, чтобы попасть в `q`-подгруппу.
3. Проверяется:

```text
[q]P_source = O.
```

4. Берется:

```text
Q_source = [2]P_source.
```

5. Выбирается отдельная точка оценки `eval_source` на `E_cycle(Fp2)`. Она не обязана лежать в `q`-подгруппе.
6. Также используется отрицательная точка оценки:

```text
eval_neg = -eval_source.
```

7. Miller scalar выбран равным:

```text
q.
```

8. Выполняется NAF Miller loop по scalar `q`.

На каждом шаге:

```text
line_value = ell_T,T(eval_source) * ell_T,T(eval_neg)
f <- f^2 * line_value
T <- [2]T
```

Если NAF digit равен `+1`:

```text
line_value = ell_T,Q_source(eval_source) * ell_T,Q_source(eval_neg)
f <- f * line_value
T <- T + Q_source
```

Если NAF digit равен `-1`:

```text
line_value = ell_T,-Q_source(eval_source) * ell_T,-Q_source(eval_neg)
f <- f * line_value
T <- T - Q_source
```

Если при addition/subtraction возникает вертикальная линия, использовался fallback:

```text
vertical_value = (x_eval_source - x_T) * (x_eval_neg - x_T)
f <- f * vertical_value
```

### 6.2 Что получилось

Локальная рекурсия Miller loop согласуется с verifier-style проверкой переходов. То есть переходы вида:

```text
f_{i+1} = f_i^2 * line_i
```

формально проверяются.

Но финальная проверка:

```text
f^((p^4 - 1) / q) = 1
```

не проходит.

Иными словами, текущая попытка **не дала корректного pairing equation** для `E_cycle/Fp2`.

### 6.3 Что нужно объяснить

Нужно строго ответить:

1. Почему проверка `f^((p^4 - 1) / q) = 1` не проходит?
2. Ошибка в выборе точек?
3. Ошибка в выборе Miller scalar?
4. Ошибка в pairing equation?
5. Нужна ли distortion map?
6. Нужны ли разные Frobenius eigenspaces для аргументов pairing?
7. Нужно ли использовать Weil pairing, Tate pairing, ate pairing или другой pairing?
8. Нужно ли оценивать Miller-функцию не в `eval_source` и `-eval_source`, а в образе через distortion/Frobenius?
9. Неверна ли сама идея проверять `e(P,Q)*e(-P,Q)=1` для этой supersingular curve?

---

## 7. Требуемая математическая спецификация для `E_cycle/Fp2`

Нужно получить документ, где для order-`q` pairing на `E_cycle/Fp2` явно указано следующее.

### 7.1 Группы

Определить группы:

```text
G1_q, G2_q ⊂ E_cycle[q]
```

или объяснить, почему такое разделение не требуется.

Нужно указать:

1. как выбрать `P`;
2. как выбрать `Q`;
3. какие subgroup checks нужны;
4. какие cofactor clearing formulas нужны;
5. какие Frobenius/eigenspace checks нужны;
6. что именно должен принимать verifier.

### 7.2 Pairing definition

Нужно формально определить pairing:

```text
e_q : G1_q × G2_q -> μ_q ⊂ Fp4^*
```

и показать:

1. билинейность;
2. невырожденность;
3. корректность target group;
4. связь с Weil/Tate pairing, если используется переход от одного определения к другому.

### 7.3 Miller function

Нужно указать:

```text
f_{m,P}
```

или аналогичную Miller-функцию:

1. какой divisor у этой функции;
2. какой scalar `m` используется;
3. почему именно этот scalar;
4. какие линии участвуют;
5. какие vertical lines участвуют;
6. можно ли удалять знаменатели;
7. если знаменатели удаляются, почему это корректно именно для данной кривой и выбранной точки оценки.

### 7.4 Distortion map или Frobenius map

Если нужна distortion map `ψ`, нужно дать формулу:

```text
ψ : E_cycle -> E_cycle
```

или

```text
ψ : E_cycle(Fp2) -> E_cycle(Fp4)
```

с явным действием на координаты:

```text
ψ(x, y) = (..., ...).
```

Если вместо distortion map используется Frobenius/eigenspace-разложение, нужно дать:

```text
π_p(x, y) = (x^p, y^p)
```

и условия на собственные подпространства.

Нужно объяснить, какая точка куда подается:

```text
Miller(P, ψ(Q))
```

или

```text
Miller(Q, ψ(P))
```

или иной вариант.

### 7.5 Direct final exponentiation

Нужно указать точную финальную экспоненту:

```text
E_direct = ?
```

Например, это может быть:

```text
(p^4 - 1) / q
```

но это нужно доказать для правильного Miller output и правильного target field.

Нужно указать:

```text
FinalExp(f) = f^E_direct
```

и точную проверку для pairing equation.

### 7.6 Residue-style relation по ePrint 2024/640

Нужно вывести корректную замену финальной экспоненты.

Ожидаемый формат, если применимо:

```text
exists c ∈ Fp4^* such that c^q = f
```

или другой аналогичный relation.

Нужно доказать эквивалентность или достаточность:

```text
c^q = f  =>  f^((p^4 - 1)/q) = 1
```

и указать, какие дополнительные условия нужны для soundness:

1. `c != 0`;
2. `c * c^{-1} = 1`;
3. subgroup condition;
4. pairing equation condition;
5. ограничения на witness.

Если для supersingular cycle эта residue-форма отличается от MNT/BLS/BN случая, нужно дать точную формулу.

---

## 8. Требуемая математическая спецификация для `Ehat_cycle/Fq2`

Аналогично разделу 7, но для order-`p` pairing на:

```text
Ehat_cycle / Fq2:
    y^2 = x^3 + (eta + 2)
```

Нужно получить:

1. `G1_p`, `G2_p` или альтернативную группу;
2. pairing:

```text
e_p : G1_p × G2_p -> μ_p ⊂ Fq6^*
```

3. точный target field `Fq6`;
4. tower representation для `Fq6`;
5. Miller scalar;
6. line formulas;
7. denominator handling;
8. direct final exponent:

```text
E_direct_hat = ?
```

9. residue relation:

```text
exists c ∈ Fq6^* such that c^p = f
```

или корректный аналог;
10. tests that uniquely validate correctness.

---

## 9. Требуемый формат будущего verifier-а

Цель реализации — получить два verifier-а:

1. verifier для `E_cycle/Fp2`, order `q`, target `Fp4`;
2. verifier для `Ehat_cycle/Fq2`, order `p`, target `Fq6`.

Каждый verifier должен иметь два режима.

### 9.1 Direct FE mode

Verifier получает:

```text
P, Q, prepared line cache, optional metadata
```

и проверяет:

```text
FinalExp(Miller(P,Q)) == expected value
```

или pairing equation:

```text
FinalExp(CombinedMiller(...)) == 1.
```

### 9.2 Residue mode

Verifier получает:

```text
P, Q, prepared line cache, c, c_inverse, optional metadata
```

и проверяет relation вида:

```text
c * c_inverse = 1
c^s = MillerOutput
```

где `s = q` для `E_cycle` или `s = p` для `Ehat_cycle`, если это действительно корректная formula.

Если правильная relation другая, нужно дать ее точную форму.

---

## 10. Что должен генерировать Rust backend

Нужно описать backend algorithm без привязки к существующему коду.

Для каждого verifier-а backend должен генерировать:

1. входные точки `P`, `Q`;
2. subgroup/cofactor evidence, если нужно;
3. prepared line coefficients;
4. Miller trace или compressed trace, если нужно;
5. final Miller accumulator `f`;
6. direct final exponentiation output;
7. residue witness `c`;
8. `c_inverse`;
9. hashes/commitments only if mathematically required;
10. JSON fixture format.

Нужно предложить конкретную JSON-схему, например:

```json
{
  "curve": "E_cycle_Fp2",
  "field": "Fp4",
  "order": "q",
  "mode": "residue",
  "P": { "x": ["...", "..."], "y": ["...", "..."] },
  "Q": { "x": ["...", "..."], "y": ["...", "..."] },
  "lines": [
    { "kind": "double", "coeffs": ["..."], "naf_index": 0 },
    { "kind": "add", "coeffs": ["..."], "naf_index": 0 }
  ],
  "miller_output": ["..."],
  "c": ["..."],
  "c_inverse": ["..."],
  "expected": ["..."]
}
```

Формат может быть другим, но должен быть достаточным для реализации verifier-а.

---

## 11. Что должен делать Solidity verifier

Нужно описать verifier algorithm так, чтобы его можно было перенести в Solidity/Yul.

Минимально нужно указать:

1. проверку принадлежности точек кривой;
2. проверку subgroup или cofactor clearing, если она должна быть on-chain;
3. формат prepared line coefficients;
4. Miller recurrence:

```text
f_{i+1} = f_i^2 * line_i(P)
```

или корректный аналог;
5. обработку addition/doubling NAF digits;
6. обработку vertical lines;
7. direct final exponentiation formula;
8. residue relation formula;
9. какие данные verifier обязан проверять, а каким может доверять только как witness;
10. какие проверки можно вынести off-chain, а какие нельзя.

Важно: если verifier не проверяет корректность line cache, нужно явно сказать, что это trusted-prepared mode, а не full untrusted-cache verifier. Если требуется untrusted-cache verifier, нужно указать, какие проверки линий добавлять.

---

## 12. Constraints-модель

Нужно оценить, подходит ли lollipop-305 для будущего folding лучше, чем MNT4-753/MNT6-753.

Нужно дать estimates для:

1. base field multiplication constraints;
2. `Fp2` multiplication constraints;
3. `Fp4` multiplication constraints;
4. `Fq2` multiplication constraints;
5. `Fq6` multiplication constraints;
6. one Miller step;
7. full Miller loop;
8. direct final exponentiation;
9. residue relation;
10. full verifier relation.

Нужно отдельно сравнить:

```text
MNT4-753: 3-limb arithmetic
lollipop-305: 2-limb arithmetic
BN254 non-native representation
MNT-cycle-native representation, если применимо
```

Если constraints-выигрыш отсутствует или уничтожается другим слоем, это нужно явно указать.

---

## 13. Что нельзя оставлять неопределенным

В ответе нельзя оставлять такие формулировки:

```text
оставить на потом
probably
standard pairing
use usual distortion map
final exponent is obvious
similar to BN/BLS
implementation-dependent
```

Если формула неизвестна, нужно честно написать:

1. почему ее нельзя вывести из имеющихся данных;
2. какой дополнительный факт из статьи или теории нужен;
3. как это блокирует реализацию.

---

## 14. Минимальные тесты, которые должна покрывать будущая реализация

Нужно предложить тесты для каждой кривой.

### 14.1 Тесты для `E_cycle/Fp2`

1. `Fp`, `Fp2`, `Fp4` arithmetic tests.
2. Проверка non-residue для chosen `Fp4` tower.
3. Проверка `#E_cycle(Fp2) = q * Nq` на уровне cofactor relations.
4. Генерация точки `P` порядка `q`.
5. Проверка `[q]P = O`.
6. Проверка subgroup/eigenspace conditions.
7. Проверка Miller recurrence на небольшом deterministic fixture.
8. Проверка direct FE identity.
9. Проверка residue witness identity.
10. Negative tests: изменить точку, line coefficient, `c`, `c_inverse`, final accumulator.

### 14.2 Тесты для `Ehat_cycle/Fq2`

Аналогично, но для:

```text
Fq, Fq2, Fq6, order p.
```

---

## 15. Главный вопрос, который нужно закрыть

Самый важный вопрос:

> Можно ли на supersingular cycle-части lollipop-305 построить корректный Article640-style verifier для pairing equation так, чтобы он был математически аналогичен MNT4 verifier-у, но дешевле за счет 2-limb арифметики?

Ответ должен быть одним из двух типов.

### Вариант A: можно

Тогда нужно дать полную спецификацию:

1. группы;
2. maps;
3. Miller algorithm;
4. final exponentiation;
5. residue relation;
6. witness format;
7. verifier algorithm;
8. tests;
9. complexity estimates.

### Вариант B: нельзя или текущая постановка неверна

Тогда нужно дать строгий отказ:

1. какая часть невозможна;
2. почему текущая pairing equation неверна;
3. какая корректная замена возможна;
4. остается ли lollipop-305 полезным исследовательским направлением;
5. что именно нужно реализовать вместо текущей схемы.

---

## 16. Ожидаемый итоговый документ от deep agent

Нужен один связный документ на русском или английском языке со структурой:

1. Executive summary.
2. Parameter verification.
3. `E_cycle/Fp2` formal pairing spec.
4. `Ehat_cycle/Fq2` formal pairing spec.
5. Explanation of current failed `f^((p^4-1)/q)` check.
6. Correct direct FE relation.
7. Correct residue relation.
8. Rust backend pseudocode.
9. Solidity verifier pseudocode.
10. Witness/cache format.
11. Constraints and gas implications.
12. Test plan.
13. Final verdict: implementable / not implementable / implementable with changed API.

Документ должен быть самодостаточным. По нему инженер должен иметь возможность начать реализацию без чтения исходного кода проекта.

---

## 17. Краткий ориентир по практической цели

Если решение окажется корректным, оно будет использовано для реализации исследовательского прототипа:

```text
lollipop305_research/
  Rust backend
  Solidity/Yul arithmetic
  prepared sparse line cache
  direct FE verifier
  residue FE verifier
  gas benchmarks
  constraints estimates
```

Если решение окажется некорректным или практически невыгодным, это также полезный результат: он будет использован в дипломе как строгий отрицательный вывод по направлению lollipop-305.
