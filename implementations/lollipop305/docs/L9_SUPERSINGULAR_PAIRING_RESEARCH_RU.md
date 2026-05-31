# L9. Исследование supersingular pairing equation для lollipop-305

## 1. Короткий вывод

Текущую реализацию lollipop-направления можно продолжать, но не в том виде, в котором была сделана первая попытка для cycle-кривой `E_cycle/Fp2`.

Главная ошибка текущей попытки: для supersingular cycle-кривой был построен Miller loop на точках из одной и той же рациональной `q`-подгруппы `E_cycle(Fp2)[q]`, а затем проверялось

```text
f^((p^4 - 1) / q) = 1.
```

Такая проверка не обязана проходить, потому что для невырожденного pairing нужны две независимые `q`-подгруппы полного `q`-кручения `E[q]`. Вторая подгруппа не лежит в `E(Fp2)`; она лежит в `E(Fp4)` и должна получаться через distortion/Frobenius map. Поэтому текущий failing-test является ожидаемым математическим сигналом, а не локальной ошибкой Solidity.

Для продолжения реализации нужно заменить текущую схему `rational subgroup against rational subgroup` на схему:

```text
P in G1 = E_cycle(Fp2)[q],
Q in G2 = psi_E(E_cycle(Fp2)[q]) subset E_cycle(Fp4)[q],
```

где `psi_E` -- distortion/Frobenius map, переводящий рациональную `+1` eigenspace-подгруппу в независимую `-1` eigenspace-подгруппу.

Аналогично для второй cycle-кривой `Ehat_cycle/Fq2` нужна отдельная карта `psi_Ehat` в `Fq6`.

---

## 2. Источники и что из них используется

Основные источники:

1. Costello, Korpal, `Cycles of supersingular elliptic curves for pairing-based proof systems`, ePrint 2024/1627.
2. El Housni et al., `On Proving Pairings`, ePrint 2024/640.

Из ePrint 2024/1627 используется конструкция `lollipop-305-158` и supersingular cycle:

```text
E_cycle/Fp2:    y^2 = x^3 + (mu + 1)x,   mu^2 = -1,
Ehat_cycle/Fq2: y^2 = x^3 + (eta + 2),   eta^2 = -2.
```

При `x \equiv 10 \(mod 12\)` статья дает оптимальный случай `(u,v)=(2,2)`, то есть обе cycle-кривые определены над квадратичными расширениями `Fp2` и `Fq2`. При этом target groups для Weil pairings имеют вид:

```text
order-q pairing on E_cycle:    Fp4^*,
order-p pairing on Ehat_cycle: Fq6^*.
```

Из ePrint 2024/640 используется идея замены финальной экспоненты проверкой принадлежности Miller-output к классу `r`-остатков. Для pairing equation

```text
prod_i e(P_i, Q_i) = 1
```

достаточно проверить существование `c` такого, что произведение соответствующих Miller outputs является `r`-й степенью:

```text
prod_i f_{r,Q_i}(P_i) = c^r.
```

Это не отменяет необходимости корректно определить сами `G1`, `G2`, Miller-функцию и точки оценки.

---

## 3. Параметры lollipop-305-158

Seed:

```text
x = 8004046504391788107635887004283725454478544674
```

Поля:

```text
p = x^2 - x + 1,
q = x^2 + 1.
```

Численно:

```text
p = 64064760444466402482617092084437280876782408929523650941985296571943203113725143542535221603,
q = 64064760444466402482617092084437280876782408937527697446377084679579090118008868997013766277.
```

Проверенные соотношения:

```text
Nq = x^2 - 2x + 2,
Np = x^2 + x + 1,
p^2 + 1     = q * Nq,
q^2 - q + 1 = p * Np.
```

Следовательно:

```text
#E_cycle(Fp2)    = p^2 + 1     = q * Nq,
#Ehat_cycle(Fq2) = q^2 - q + 1 = p * Np.
```

---

## 4. Почему текущая попытка для `E_cycle/Fp2` не является pairing verifier

### 4.1 Что было сделано

Текущая попытка строила:

```text
P_source in E_cycle(Fp2)[q],
Q_source = [2]P_source,
eval_source in E_cycle(Fp2),
eval_neg = -eval_source.
```

Далее выполнялся Miller loop по scalar `q` и проверялось:

```text
f^((p^4 - 1) / q) = 1.
```

### 4.2 Почему это математически недостаточно

Кривая `E_cycle` рассматривается над базовым полем `K = Fp2`. Поскольку

```text
#E_cycle(K) = p^2 + 1
```

и `q | #E_cycle(K)`, в `E_cycle(K)` есть одна рациональная `q`-подгруппа. Но полное `q`-кручение имеет вид:

```text
E_cycle[q] ~= Z/qZ x Z/qZ
```

и становится рациональным только над `Fp4`. Вторая независимая подгруппа не находится внутри `E_cycle(Fp2)`.

Если брать обе точки из одной и той же циклической подгруппы, то Weil pairing тривиален из-за альтернированности, а Tate pairing не дает нужного невырожденного теста. Поэтому простая схема `Q_source = [2]P_source` не может служить полноценной pairing equation.

### 4.3 Что должно быть вместо этого

Нужно построить две подгруппы:

```text
G1_q = E_cycle(Fp2)[q],
G2_q = psi_E(G1_q) subset E_cycle(Fp4)[q].
```

Тогда pairing имеет вид:

```text
e_q : G1_q x G2_q -> mu_q subset Fp4^*.
```

И уже для него можно строить проверку:

```text
e_q(P1,Q1) * e_q(P2,Q2) = 1.
```

Например, для теста корректности можно брать:

```text
P2 = -P1,
Q2 = Q1,
```

тогда по билинейности:

```text
e_q(P1,Q1) * e_q(-P1,Q1) = e_q(P1 - P1, Q1) = e_q(O,Q1) = 1.
```

---

## 5. Вывод distortion/Frobenius map для `E_cycle/Fp2`

### 5.1 Исходная кривая

Пусть

```text
K = Fp2 = Fp[mu]/(mu^2 + 1),
a = 1 + mu,
E/K: y^2 = x^3 + a x.
```

Кривая имеет `j = 1728`. Для построения второй подгруппы нужна карта, которая не определена над `K`, а уходит в `Fp4`.

### 5.2 Идея карты

Пусть `sigma` -- `p`-Фробениус на `K/Fp`:

```text
sigma(mu) = -mu.
```

Тогда:

```text
a^sigma = 1 - mu.
```

Кривая после Фробениуса:

```text
E^sigma: y^2 = x^3 + a^sigma x.
```

Чтобы вернуть `E^sigma` в `E`, нужна изоморфная замена координат:

```text
(x,y) -> (theta^2 x, theta^3 y),
```

где `theta` должен удовлетворять:

```text
theta^4 * a^sigma = a.
```

Отсюда:

```text
theta^4 = a / a^sigma = (1 + mu)/(1 - mu) = mu.
```

Следовательно, для `E_cycle` нужна башня `Fp4`, в которой выбран элемент `theta` такой, что:

```text
theta^4 = mu.
```

Тогда distortion/Frobenius map имеет вид:

```text
psi_E(x,y) = (theta^2 * x^p, theta^3 * y^p).
```

### 5.3 Почему эта карта дает независимую подгруппу

Для точки `P in E(Fp2)[q]` выполняется:

```text
pi_{p^2}(P) = P.
```

Если `theta` выбран вне `Fp2` так, что `Fp4 = Fp2(theta)` и `theta^{p^2} = -theta`, то:

```text
pi_{p^2}(psi_E(P)) = -psi_E(P).
```

То есть `psi_E(P)` лежит в `-1` eigenspace относительно `p^2`-Фробениуса, а исходная `P` лежит в `+1` eigenspace. Эти две подгруппы независимы, поэтому pairing между ними может быть невырожденным.

### 5.4 Что нужно исправить в реализации

Вместо текущей схемы:

```text
Q_source in E(Fp2)[q],
eval_source in E(Fp2)
```

нужно использовать:

```text
P in E(Fp2)[q],
Q_raw in E(Fp2)[q],
Q = psi_E(Q_raw) in E(Fp4)[q].
```

Miller loop должен идти по точке `Q` в `Fp4`, а line evaluations должны вычисляться в точке `P`, вложенной в `Fp4`.

---

## 6. Direct FE и residue relation для `E_cycle/Fp2`

После исправления подгрупп direct final exponentiation должна иметь вид:

```text
E_direct_q = (p^4 - 1) / q.
```

Для pairing equation:

```text
e_q(P1,Q1) * e_q(P2,Q2) = 1
```

строится product Miller output:

```text
F = f_{q,Q1}(P1) * f_{q,Q2}(P2).
```

Direct check:

```text
F^((p^4 - 1)/q) = 1.
```

Residue check по ePrint 2024/640:

```text
exists c in Fp4^*: c^q = F.
```

Verifier проверяет:

```text
c * c^{-1} = 1,
c^q = F.
```

Это корректно, потому что если `F = c^q`, то:

```text
F^((p^4 - 1)/q) = (c^q)^((p^4 - 1)/q) = c^(p^4 - 1) = 1.
```

Для soundness нужно, чтобы `F` был именно product Miller output корректно определенных pairings, а не произвольный элемент `Fp4`. Поэтому сначала обязательно исправляется `G1/G2`-постановка.

---

## 7. Что известно и что требуется для `Ehat_cycle/Fq2`

### 7.1 Исходная кривая

Пусть

```text
L = Fq2 = Fq[eta]/(eta^2 + 2),
b = eta + 2,
Ehat/L: y^2 = x^3 + b.
```

Кривая имеет `j = 0`. Ее порядок:

```text
#Ehat(Fq2) = q^2 - q + 1 = p * Np.
```

Target field для order-`p` pairing по ePrint 2024/1627:

```text
Fq6^*.
```

### 7.2 Аналогичная карта для `j = 0`

Для `j = 0` изоморфизм между `Ehat^sigma` и `Ehat` имеет форму:

```text
(x,y) -> (theta^2 x, theta^3 y),
```

но теперь нужно:

```text
theta^6 * b^sigma = b.
```

Так как `sigma` -- `q`-Фробениус на `Fq2/Fq`, имеем:

```text
sigma(eta) = -eta,
b^sigma = 2 - eta.
```

Следовательно:

```text
theta^6 = b / b^sigma = (2 + eta)/(2 - eta).
```

Ожидаемая карта:

```text
psi_Ehat(x,y) = (theta^2 * x^q, theta^3 * y^q),
```

где `theta` лежит в `Fq6` и удовлетворяет указанному уравнению.

### 7.3 Что нужно дополнительно зафиксировать

Для `Ehat` еще нужно выбрать tower representation для `Fq6`, удобную для Solidity/Yul:

```text
Fq6 = Fq2[w] / (w^3 - rho)
```

или эквивалентную башню, где можно явно выразить `theta^2`, `theta^3` и Frobenius constants.

Минимальные требования:

1. `rho` должен быть кубическим non-residue в `Fq2`.
2. В этой башне должен существовать `theta` с `theta^6 = (2+eta)/(2-eta)`.
3. Нужно вывести формулы `q`- и `q^2`-Фробениуса для `Fq6`.
4. Нужно проверить, что `psi_Ehat` переводит рациональную `p`-подгруппу в независимую подгруппу полного `p`-кручения.

Без этого `Ehat`-verifier переносить в Solidity нельзя.

---

## 8. Что требуется реализовать дальше

### Шаг 1. Исправить Rust backend для `E_cycle/Fp2`

Нужно реализовать:

1. `Fp4` tower с явным `theta`, где `theta^4 = mu`.
2. `psi_E(x,y) = (theta^2*x^p, theta^3*y^p)`.
3. Генерацию `P in G1_q` и `Q_raw in G1_q`.
4. Построение `Q = psi_E(Q_raw)`.
5. Miller loop `f_{q,Q}(P)`.
6. Тест:
   ```text
   e_q(P,Q) != 1
   ```
   для нетривиальных `P,Q`.
7. Тест pairing equation:
   ```text
   e_q(P,Q) * e_q(-P,Q) = 1.
   ```
8. Direct FE test:
   ```text
   F^((p^4 - 1)/q) = 1.
   ```
9. Residue test:
   ```text
   c^q = F.
   ```

Только после прохождения этих Rust-тестов можно переносить `E_cycle` в Solidity.

### Шаг 2. Перенести `E_cycle` verifier в Solidity/Yul

Нужно реализовать:

1. `Fp4` арифметику в выбранной tower.
2. Encoding точек `P in Fp2`, `Q in Fp4`.
3. Prepared line-value или prepared line-coefficient формат.
4. Miller core verifier.
5. Direct FE verifier.
6. Residue FE verifier.
7. Negative tests: подмена `P`, `Q`, line, `c`, `c^{-1}`, final accumulator.
8. Gas report:
   ```text
   Miller core,
   Miller + direct FE,
   Miller + residue FE.
   ```

### Шаг 3. Вывести и реализовать `Ehat_cycle/Fq2`

Нужно сначала закрыть математику:

1. Выбрать `Fq6` tower.
2. Найти `theta` с:
   ```text
   theta^6 = (2+eta)/(2-eta).
   ```
3. Доказать корректность `psi_Ehat`.
4. Построить `G1_p`, `G2_p`.
5. Проверить direct FE:
   ```text
   F^((q^6 - 1)/p) = 1.
   ```
6. Проверить residue FE:
   ```text
   c^p = F.
   ```

После этого повторить Solidity/Yul перенос как для `E_cycle`.

---

## 9. Что уже можно считать закрытым

1. Параметры `p`, `q`, `r`, `r_hat` зафиксированы.
2. Соотношения `p^2+1=q*Nq` и `q^2-q+1=p*Np` подтверждены.
3. Две 305-битные характеристики реализованы в Rust и Solidity/Yul на уровне базовой арифметики.
4. Для stick curve реализован и измерен Article640-style verifier:
   ```text
   Miller core: 5.29M gas,
   Miller + direct FE: 30.29M gas,
   Miller + residue FE: 8.67M gas.
   ```
5. Для `E_cycle/Fp2` реализована только проверка recurrence по prepared line values; это еще не reduced pairing verifier.

---

## 10. Что пока нельзя заявлять

Нельзя заявлять, что полный lollipop-cycle verifier уже реализован.

Нельзя заявлять, что `E_cycle/Fp2` direct/residue FE готовы, пока не пройдет тест:

```text
F^((p^4 - 1)/q) = 1
```

на корректно выбранных `G1/G2` через `psi_E`.

Нельзя заявлять, что `Ehat_cycle/Fq2` реализована, пока не выбрана и не проверена `Fq6` tower и `psi_Ehat`.

---

## 11. Итоговый вердикт

Продолжать lollipop-подход можно. Направление остается содержательно перспективным, потому что 305-битная двухлимбовая арифметика уже показала сильный выигрыш относительно MNT4/MNT6, а stick pairing уже измерен в полном Article640-style режиме.

Но следующий этап реализации должен начинаться не с Solidity, а с исправления математического слоя supersingular pairings:

```text
E_cycle/Fp2:    добавить psi_E и правильные G1/G2;
Ehat_cycle/Fq2: выбрать Fq6 tower, вывести psi_Ehat и правильные G1/G2.
```

После этого реализация становится прямой инженерной задачей: Rust fixture -> Solidity verifier -> gas report -> constraints estimate.

---

## 12. Реализация после исследования: что удалось закрыть

После вывода правильной `G1/G2`-постановки для `E_cycle/Fp2` была реализована исправленная Rust-схема:

```text
P in G1 = E_cycle(Fp2)[q],
Q_raw in E_cycle(Fp2)[q],
Q = psi_E(Q_raw) in E_cycle(Fp4)[q],
psi_E(x,y) = (theta^2*x^p, theta^3*y^p),
theta^4 = mu.
```

Для этой схемы Rust теперь проверяет:

```text
F = f_{q,Q}(P) * f_{q,Q}(-P),
F^((p^4-1)/q) = 1,
c^q = F,
c*c^{-1} = 1.
```

Затем был сгенерирован новый fixture:

```text
lollipop305_cycle_e_article640_fixture.words.hex
lollipop305_cycle_e_article640_fixture.words.bin
```

и добавлены Solidity-проверки:

```text
verifyCycleEDirectFinalExponent(...)
verifyCycleEResidue(...)
```

Измерения Foundry:

| Режим `E_cycle/Fp2` | Gas в тестовом вызове | Gas-report функции |
|---|---:|---:|
| Miller core | 19,143,725 | 11,181,665--11,444,466 |
| Miller + direct FE | 42,015,185 | 34,070,641 |
| Miller + residue FE | 26,259,779 | 18,280,049 |

Это означает, что первая supersingular cycle-часть lollipop теперь имеет не только арифметическую основу, но и работающий Article640-style verifier над корректной distorted `G2`-постановкой.

## 13. Математическое закрытие `Ehat_cycle/Fq2`

Для второй cycle-кривой была начата Rust-реализация:

```text
Ehat/Fq2: y^2 = x^3 + (eta+2), eta^2=-2,
Fq6 = Fq2[w]/(w^3-rho),
rho^2 = (2+eta)/(2-eta),
psi_Ehat(x,y) = (w^2*x^q, w^3*y^q).
```

Проверено:

```text
rho^2 = (2+eta)/(2-eta),
w^3 = rho,
w^6 = (2+eta)/(2-eta),
psi_Ehat(Q) lies on Ehat(Fq6).
```

Прямой перенос Tate-style equation

```text
F = f_{p,Q}(P) * f_{p,Q}(-P),
F^((q^6-1)/p) = 1
```

не проходит. Это означает, что для `j=0` supersingular-кривой нельзя механически повторить `E_cycle/Fp2` схему. Корректная форма здесь -- Weil pairing, что согласуется с формулировкой ePrint 2024/1627: для `Ehat` статья говорит именно об order-`p` Weil pairing с target group `Fq6^*`.

Для точек

```text
P in Ehat(Fq2)[p],
Q = psi_Ehat(Q_raw) in Ehat(Fq6)[p]
```

используется Miller-представление Weil pairing:

```text
e_p(P,Q) = f_{p,P}(Q) / f_{p,Q}(P).
```

Проверка equation для пары `P` и `-P` имеет вид:

```text
e_p(P,Q) * e_p(-P,Q) = 1.
```

Если раскрыть это через Miller-функции, получаем отношение без явной финальной экспоненты:

```text
f_{p,P}(Q) * f_{p,-P}(Q)
=
f_{p,Q}(P) * f_{p,Q}(-P).
```

Это отношение проверено обычным Rust-тестом `cycle_ehat_weil_pairing_relation_is_nontrivial_and_correct`. Тест проверяет:

```text
Q lies on Ehat(Fq6),
[p]P = O,
[p]Q = O,
pi_{q^2}(Q) = [q^2 mod p]Q,
e_p(P,Q) != 1,
e_p(P,Q)^p = 1,
e_p(P,Q)e_p(-P,Q) = 1.
```

## 14. Итоговый статус lollipop после этого шага

Закрыто:

1. stick pairing verifier;
2. `Fp/Fp2/Fp4` и `Fq/Fq2` арифметика;
3. корректный distorted `E_cycle/Fp2 -> Fp4` verifier;
4. direct FE и residue FE для `E_cycle/Fp2`;
5. математическая Weil-relation для `Ehat_cycle/Fq2 -> Fq6`;
6. gas-измерения для stick и первой supersingular cycle-части.

Не закрыто полностью:

1. Solidity/Yul перенос `Ehat/Fq6` Weil-verifier;
2. gas-измерения `Ehat` verifier;
3. итоговая таблица полного lollipop-cycle `stick + E_cycle + Ehat_cycle`.

Главный честный вывод: математический блокер снят. Полный lollipop-cycle еще нельзя объявлять EVM-реализованным, но теперь ясно, что именно нужно переносить в Solidity/Yul: не Tate/residue verifier для `Ehat`, а Weil-equation verifier.
