# Этап L3: curve layer, prepared sparse lines и Miller core для lollipop-305

## 1. Что реализовано

В Rust backend добавлены три слоя, необходимые для следующего этапа verifier:

1. `curve layer` -- операции с точками ordinary stick-curve `E/Fp`;
2. `prepared sparse line format` -- компактное представление линий Миллера;
3. `Miller core` -- построение prepared trace по ate-loop scalar `t-1 = x-1`.

Важно: это еще не полный pairing verifier. На этом этапе реализован backend-слой, который строит algebraic trace для Miller loop на stick-curve. Для полноценного pairing над `Fp4` следующим шагом нужно добавить слой точки/подгруппы в расширении и финальную проверку уравнения.

## 2. Tate или ate

В старом MNT4-коде названия функций исторически содержат `tate`, например `MNT4TatePairing`. Фактический Miller loop там является ate-loop: в коде используются `ATE_LOOP_ENC`, `ATE_IS_LOOP_COUNT_NEG`, а в formal spec указан `ATE_LOOP_COUNT = |t-1|`.

Для lollipop-305 также выбран ate-loop scalar:

```text
t = x,
ate scalar = t - 1 = x - 1.
```

Для параметра из ePrint 2024/1627:

```text
x = 8004046504391788107635887004283725454478544674
x - 1 = 8004046504391788107635887004283725454478544673
```

NAF-представление этого числа имеет длину `154`, а построенный trace содержит `199` line steps: удвоения плюс signed additions/subtractions.

## 3. Curve layer

Файл:

```text
/Users/a.i.semenov/mnt4-pairing-final/lollipop305_research/rust_backend/src/curve.rs
```

Реализовано:

- проверка уравнения `y^2 = x^3 + a*x + b`;
- поиск тестовой точки по малому `x` через квадратный корень в поле `Fp`;
- `neg`;
- `double`;
- `add`;
- `scalar_mul`;
- специальное представление infinity как внутренний sentinel `(0,0)`.

Проверки:

- удвоение и сложение сохраняют принадлежность кривой;
- `Q + (-Q) = O`;
- конечная точка после Miller schedule совпадает с `scalar_mul(Q, x-1)`.

## 4. Prepared sparse line format

Файл:

```text
/Users/a.i.semenov/mnt4-pairing-final/lollipop305_research/rust_backend/src/miller.rs
```

Линия хранится в виде:

```text
line(x,y) = y + x_coeff * x + const_coeff.
```

Если обычная форма линии:

```text
y = lambda * x + nu,
```

то в prepared format хранится:

```text
x_coeff     = -lambda,
const_coeff = -nu.
```

Это sparse-представление: вместо полного элемента `Fp4` линия задается двумя элементами `Fp`. При вычислении значения линии в точке `P` backend считает:

```text
line(P) = y_P - lambda*x_P - nu.
```

Затем это значение вкладывается в `Fp4` как элемент базового поля:

```text
Fp -> Fp2 -> Fp4.
```

На текущем этапе это корректно для backend-smoke trace на `E/Fp`. Для полного pairing следующим шагом нужно расширить line evaluation до точки в нужной подгруппе/расширении.

## 5. Miller core

Реализована функция:

```rust
build_prepared_miller_trace(eval_point, q, scalar)
```

Алгоритм:

```text
1. scalar переводится в NAF.
2. T <- Q, f <- 1.
3. Для NAF-цифр от старшей к младшей:
   3.1. строится tangent line для T;
   3.2. f <- f^2 * line(T,T)(P);
   3.3. T <- 2T;
   3.4. если digit = +1: строится line(T,Q), f <- f*line(T,Q)(P), T <- T+Q;
   3.5. если digit = -1: строится line(T,-Q), f <- f*line(T,-Q)(P), T <- T-Q.
4. Возвращаются steps, final T, accumulator f и commitment к линиям.
```

Для commitment пока используется deterministic SHA-256 от JSON-представления линий. Это не финальный on-chain формат, а backend-level фиксатор для воспроизводимости. При переносе в Solidity лучше заменить его на формат, удобный для calldata/Keccak.

## 6. Команды проверки

```bash
cd /Users/a.i.semenov/mnt4-pairing-final
cargo test --manifest-path lollipop305_research/rust_backend/Cargo.toml
cargo run --manifest-path lollipop305_research/rust_backend/Cargo.toml --bin lollipop305_miller_trace
```

Текущий результат:

```text
9 tests passed
naf_len = 154
step_count = 199
pairing_loop = ate loop over t-1 = x-1
```

## 7. Граница готовности

Готово:

- параметры lollipop-305;
- Rust curve layer;
- prepared sparse line format;
- ate-loop scalar `x-1`;
- Miller trace generation;
- тесты корректности базовых переходов.

Еще не готово:

- полный pairing over `Fp4`;
- проверка подгрупп `G1/G2`;
- final exponentiation/residue verifier;
- Solidity verifier для lollipop-305 Miller/residue.
