# Этап L4: pairing layer over Fp4 для lollipop-305

## 1. Что добавлено

На этом этапе добавлен исследовательский слой для вычисления ate-style pairing над расширенным полем `Fp4`.

Реализованы:

1. `Fp4.inverse` и `Fp4.pow`;
2. точки `E(Fp4)`;
3. line evaluation в точке расширенного поля;
4. Miller trace над `Fp4`;
5. reduced pairing через финальную экспоненту;
6. subgroup-check API через умножение точки на `r`.

## 2. Файлы

| Файл | Назначение |
|---|---|
| `rust_backend/src/field.rs` | `Fp2.inverse`, `Fp4.inverse`, `Fp4.pow`, embedding `Fp -> Fp4` |
| `rust_backend/src/extension_curve.rs` | affine-точки `E(Fp4)`, `add`, `double`, `scalar_mul`, `is_in_r_subgroup` |
| `rust_backend/src/miller.rs` | расширенная проверка prepared line в `Fp4`-точке |
| `rust_backend/src/pairing.rs` | Miller trace over `Fp4`, final exponentiation, reduced ate smoke pairing |
| `rust_backend/src/bin/lollipop305_pairing_smoke.rs` | JSON-smoke для pairing-слоя |

## 3. Математическая схема

Кривая stick-layer:

```text
E/Fp: y^2 = x^3 + a*x + b.
```

Она поднимается в расширение:

```text
E(Fp4): y^2 = x^3 + a*x + b,
```

где `a,b` вкладываются из `Fp` в `Fp4`.

Miller accumulator строится как:

```text
f <- 1
T <- Q
for digit in NAF(x-1):
    f <- f^2 * ell_{T,T}(P)
    T <- 2T
    if digit = +1:
        f <- f * ell_{T,Q}(P)
        T <- T + Q
    if digit = -1:
        f <- f * ell_{T,-Q}(P)
        T <- T - Q
```

Здесь `Q` пока берется как base-field source point из `E(Fp)`, а `P` является точкой `E(Fp4)`. Prepared line хранится в sparse-формате:

```text
ell(x,y) = y + x_coeff*x + const_coeff.
```

Финальная экспонента:

```text
y = f^((p^4 - 1)/r).
```

После нее проверяется стандартный инвариант результата:

```text
y^r = 1.
```

## 4. Что именно проверяют тесты

Тесты в `rust_backend/tests/backend_contract.rs` проверяют:

- параметры `p,q,r` из ePrint 2024/1627;
- арифметику `Fp/Fp2/Fp4`;
- принадлежность точек `E(Fp)`;
- корректность `add/double/scalar_mul`;
- что prepared line обращается в ноль на исходных точках;
- что `Fp4.inverse` дает `a*a^{-1}=1`;
- что финальная экспонента возвращает элемент, удовлетворяющий `y^r=1`;
- что line evaluation в `Fp4` совпадает с base-field evaluation при embedding `E(Fp) -> E(Fp4)`;
- что Miller trace over `Fp4` совпадает с прежним base trace при embedded evaluation point;
- что reduced ate smoke result лежит в `r`-torsion subgroup of `Fp4*`.

## 5. Важное ограничение

Это исследовательский pairing layer, а не финальный production pairing для lollipop-305.

Причина: production-версия должна зафиксировать точный выбор второй pairing-подгруппы/twist для lollipop-305 и доказать невырожденность pairing. В коде добавлена общая арифметика `E(Fp4)` и API для subgroup-check, но default smoke использует embedded base-field point, поэтому его reduced result может быть тривиальным. Это нормально для проверки инфраструктуры, но не является доказательством полноценной криптографической инстанциации. Сейчас реализована корректная инфраструктура:

- поле `Fp4`;
- кривая `E(Fp4)`;
- subgroup-check API;
- line evaluation over `Fp4`;
- Miller core;
- final exponentiation.

Но генератор второй подгруппы и twist/subgroup selection должны быть отдельным следующим этапом, чтобы не смешивать smoke-pairing с полноценной cryptographic instantiation.

## 6. Команды

```bash
cd /Users/a.i.semenov/mnt4-pairing-final
cargo test --manifest-path lollipop305_research/rust_backend/Cargo.toml
cargo run --manifest-path lollipop305_research/rust_backend/Cargo.toml --bin lollipop305_pairing_smoke
```

Текущий smoke-output содержит:

```text
mode = research smoke: ate Miller over E(Fp4) with base-field source Q
step_count = 199
reduced_result_pow_r_is_one = true
embedded smoke может вернуть reduced_result = 1
```
