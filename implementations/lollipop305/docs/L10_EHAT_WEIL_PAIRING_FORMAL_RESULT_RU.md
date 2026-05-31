# L10. Математическое закрытие `Ehat_cycle/Fq2`: нужна Weil-pairing relation

## 1. Итоговый вывод

Для второй supersingular cycle-кривой lollipop-305 нельзя напрямую повторять Tate-style проверку, которая была использована для `E_cycle/Fp2`:

```text
F = f_{p,Q}(P) * f_{p,Q}(-P),
F^((q^6 - 1)/p) = 1.
```

Эта формула в Rust не проходит. Причина не в арифметике `Fq6`: проверены корректность башни, обратные элементы, порядок точек и distortion map. Проблема в выборе pairing relation.

Для `Ehat_cycle/Fq2` нужно использовать именно Weil pairing relation, что согласуется с формулировкой ePrint 2024/1627: статья говорит о target group для order-`p` Weil pairing on `Ehat`, а не о reduced Tate pairing в той упрощенной форме, которая применялась для первой реализации.

---

## 2. Кривая и поля

Кривая:

```text
Ehat/Fq2: y^2 = x^3 + b,
b = eta + 2,
eta^2 = -2.
```

Порядок:

```text
#Ehat(Fq2) = q^2 - q + 1 = p * Np.
```

Целевое поле:

```text
Fq6 = Fq2[w] / (w^3 - rho).
```

Выбранная башня:

```text
rho^2 = b / b^q = (2 + eta)/(2 - eta),
w^3 = rho.
```

Тогда:

```text
w^6 = (2 + eta)/(2 - eta).
```

Это ровно то, что нужно для `j=0`-изоморфизма.

---

## 3. Distortion/Frobenius map

Для `j=0`-кривой изоморфизм после `q`-Фробениуса имеет вид:

```text
psi_Ehat(x,y) = (theta^2 * x^q, theta^3 * y^q),
theta^6 = b / b^q.
```

В выбранной башне можно взять:

```text
theta = w,
theta^2 = w^2,
theta^3 = rho.
```

Поэтому:

```text
psi_Ehat(x,y) = (w^2 * x^q, rho * y^q).
```

Проверено вычислительно:

```text
rho^2 = (2+eta)/(2-eta),
w^3 = rho,
w^6 = (2+eta)/(2-eta),
psi_Ehat(Q) lies on Ehat(Fq6),
[p]psi_Ehat(Q) = O.
```

Также проверено eigenspace-условие относительно `q^2`-Фробениуса:

```text
pi_{q^2}(psi_Ehat(Q)) = [q^2 mod p] psi_Ehat(Q).
```

Так как из `p | q^2-q+1` следует:

```text
q^2 ≡ q - 1 (mod p),
```

эта точка лежит в независимой pairing-подгруппе полного `p`-кручения.

---

## 4. Почему Tate-style relation не прошла

Проверялась формула:

```text
F = f_{p,Q}(P) * f_{p,Q}(-P),
F^((q^6-1)/p) = 1.
```

Она не прошла даже после включения вертикальных знаменателей Miller-функции. Это означает, что в данной постановке нельзя использовать короткую формулу `f_{p,Q}(P)` как reduced Tate pairing без дополнительной нормализации divisors.

Иными словами, для `Ehat/Fq2` выражение

```text
f_{p,Q}(P)
```

само по себе не является тем объектом, который в этой реализации можно безопасно подставлять в ePrint 2024/640 residue relation.

---

## 5. Корректная Weil-pairing relation

Для точек `P,Q in E[p]` Weil pairing можно вычислять через Miller-функции:

```text
e_p(P,Q) = (-1)^p * f_{p,P}(Q) / f_{p,Q}(P).
```

Так как `p` нечетное, знак `(-1)^p` одинаково входит в обе проверки и для equation-проверки может учитываться как фиксированная константа. Для отношения вида

```text
e_p(P,Q) * e_p(-P,Q) = 1
```

получаем:

```text
e_p(P,Q)     = - f_{p,P}(Q)  / f_{p,Q}(P),
e_p(-P,Q)    = - f_{p,-P}(Q) / f_{p,Q}(-P).
```

Произведение:

```text
e_p(P,Q) * e_p(-P,Q)
= f_{p,P}(Q) * f_{p,-P}(Q)
  / ( f_{p,Q}(P) * f_{p,Q}(-P) ).
```

Условие `e_p(P,Q) * e_p(-P,Q) = 1` эквивалентно:

```text
f_{p,P}(Q) * f_{p,-P}(Q)
=
f_{p,Q}(P) * f_{p,Q}(-P).
```

Это и есть корректная verifier relation для `Ehat`.

---

## 6. Проверенный Rust-факт

В Rust была проверена следующая схема:

```text
P in Ehat(Fq2)[p],
Q_raw in Ehat(Fq2)[p],
Q = psi_Ehat(Q_raw) in Ehat(Fq6)[p].
```

Далее вычислялось:

```text
e = f_{p,P}(Q) / f_{p,Q}(P).
```

Проверки:

```text
e != 1,
e^p = 1,
e(P,Q) * e(-P,Q) = 1.
```

Все три проверки прошли. Это означает, что математически правильный путь для `Ehat` найден.

В коде это закреплено не только исследовательским запуском, но и обычным Rust-тестом:

```text
cycle_ehat_weil_pairing_relation_is_nontrivial_and_correct
```

Тест строит `P`, `Q=psi_Ehat(Q_raw)` и проверяет принадлежность точек нужным подгруппам, Frobenius-eigenspace relation, нетривиальность pairing value, условие `e^p=1` и equation `e(P,Q)e(-P,Q)=1`.

---

## 7. Что нужно реализовать дальше в коде

Для полного завершения lollipop нужно реализовать `Ehat` не как Tate-style residue verifier, а как Weil-equation verifier.

On-chain verifier должен проверять равенство:

```text
A = B,
```

где:

```text
A = f_{p,P}(Q) * f_{p,-P}(Q),
B = f_{p,Q}(P) * f_{p,Q}(-P).
```

То есть вместо одной Miller-трассы нужно четыре Miller-трассы:

```text
f_{p,P}(Q),
f_{p,-P}(Q),
f_{p,Q}(P),
f_{p,Q}(-P).
```

Но важное преимущество: здесь не нужна финальная экспонента и не нужна residue-check, потому что Weil pairing уже сразу попадает в группу `μ_p`, если Miller-функции вычислены корректно.

Практический verifier может принимать prepared line-value blob для каждой из четырех трасс и проверять:

```text
miller(P,Q) * miller(-P,Q)
==
miller(Q,P) * miller(Q,-P).
```

---

## 8. Сравнение с `E_cycle/Fp2`

| Компонент | Корректная relation | Финальная экспонента | residue FE |
|---|---|---|---|
| `E_cycle/Fp2` | Tate-style product after distortion | нужна | работает |
| `Ehat/Fq2` | Weil ratio/product | не нужна | не нужна |

Итог: для полного lollipop-cycle будут две разные математические формы verifier-а:

1. `E_cycle/Fp2`: Article640-style Tate/residue verifier.
2. `Ehat/Fq2`: Weil-equation verifier.

Это не противоречит статье ePrint 2024/1627, потому что она формулирует target groups именно для Weil pairings на supersingular cycle-кривых.
