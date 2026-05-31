# L6: проверка twist-спецификации lollipop-305 и исправление башни Fp4

## 1. Что проверялось

После получения документа `lollipop305_g2_twist_spec-2.pdf` была выполнена практическая проверка, достаточно ли этой спецификации для продолжения реализации lollipop-305 pairing verifier.

Проверялись три вещи:

1. задает ли выбранная башня `Fp4` настоящее поле;
2. попадает ли `untwist(Q')` в правильное Frobenius-eigenspace;
3. дает ли target ate pairing нетривиальный результат.

## 2. Найденная проблема

В документе предлагалась башня:

```text
Fp2 = Fp[u] / (u^2 + 1),
Fp4 = Fp2[v] / (v^2 - u).
```

Для параметра lollipop-305 имеем:

```text
p = x^2 - x + 1,
p ≡ 3 (mod 8).
```

При таком `p` элемент `u`, удовлетворяющий `u^2=-1`, является квадратом в `Fp2`. Это было проверено вычислительно в Rust:

```text
u square = true
first small nonsquare = 1+u
```

Следовательно, `v^2-u` не является неприводимым над `Fp2`, а значит такая конструкция не задает поле `Fp4`. Это критично: в не-поле нельзя корректно использовать `inverse`, `sqrt`, финальную экспоненту и проверку мультипликативной подгруппы `mu_r`.

## 3. Исправление

Башня заменена на:

```text
Fp2 = Fp[u] / (u^2 + 1),
Fp4 = Fp2[v] / (v^2 - xi),
xi = 1 + u.
```

Для `xi=1+u` вычислительно проверено, что это неквадрат в `Fp2`.

После этого twist записывается так:

```text
E:  y^2 = x^3 + a*x + b,
E': Y^2 = X^3 + (a/xi^2)*X + b/xi^3.
```

Отображение из twist в исходную кривую:

```text
psi(X,Y) = (xi*X, xi*v*Y).
```

## 4. Проверки после исправления

Rust backend проверяет:

```text
[r]P = O,
[r]Q' = O,
[r]psi(Q') = O,
pi_p(psi(Q')) = [p]psi(Q'),
a_T(P,Q) != 1,
a_T(P,Q)^r = 1.
```

Команда:

```bash
cargo test --manifest-path lollipop305_research/rust_backend/Cargo.toml
```

Результат:

```text
16 passed, 0 failed
```

Сгенерирован воспроизводимый JSON-вектор:

```text
lollipop305_research/docs/lollipop305_twist_pairing_vector.json
```

Ключевые поля:

```text
frobenius_q_equals_p_times_q = true
result_is_one = false
result_pow_r_is_one = true
step_count = 199
```

## 5. Что это означает для F7

Математический блокер по `G2/twist` больше не является полным стоп-фактором: корректная pairing-инстанциация в Rust reference получена. Однако полный `article640`-аналог для lollipop-305 еще требует инженерного переноса в Solidity/Yul:

1. twist-aware sparse line format;
2. prepared line cache;
3. hot-path Miller verifier;
4. direct FE и residue FE;
5. gas comparison with MNT4-753.

Иными словами, задача перешла из стадии “не определена корректная математика G2” в стадию “нужно реализовать и измерить полный EVM verifier”.
