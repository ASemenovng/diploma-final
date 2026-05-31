# Доработка исследования G2/twist для lollipop-305-158

## 1. Контекст

Был получен документ `lollipop305_g2_twist_spec.pdf` с математической спецификацией `G2/twist` для исследовательского кандидата `lollipop-305-158` из ePrint 2024/1627.

Документ содержит полезную теоретическую часть:

- параметры `p = x^2 - x + 1`, `q = x^2 + 1`, `r`;
- проверку `ord_r(p)=4`;
- вывод квадратичного твиста над `Fp2`;
- формулу твиста

```text
E': Y^2 = X^3 - aX + b u over Fp2,
```

- отображение untwist

```text
psi(X,Y) = (uX, u v Y) in E(Fp4), where u^2=-1, v^2=u;
```

- идею определения `G2` через `E'(Fp2)[r]`;
- теоретическое объяснение невырожденности через разные собственные подпространства Фробениуса;
- предварительные формулы line evaluation и sparse multiplication.

Но для продолжения реализации в `lollipop305_research` этого пока недостаточно: документ не дает полностью воспроизводимого набора test vectors и не показывает фактически выполненный скрипт с конкретными координатами `P`, `Q'`, `Q` и результатом pairing.

## 2. Что нужно доработать

### 2.1. Дать исполняемый Sage/Magma/GP файл, а не только текст в PDF

Нужно приложить отдельный файл, например:

```text
lollipop305_g2_twist_verify.sage
```

Он должен запускаться без ручных исправлений синтаксиса и печатать итоговый JSON.

Проверки в скрипте:

```text
is_prime(p)
is_prime(r)
Nq = p + 1 - x
Nq % r == 0
ord_r(p) == 4
E/Fp has equation y^2 = x^3 + a*x + b
E'(Fp2): Y^2 = X^3 - aX + b u
#E'(Fp2) = x^4 - 2*x^3 + 2*x^2
#E'(Fp2) % r == 0
```

### 2.2. Выдать конкретные координаты генераторов

Нужно выдать конкретные координаты, а не только алгоритм cofactor clearing.

Обязательные объекты:

```text
P in E(Fp)[r]
Q' in E'(Fp2)[r]
Q = psi(Q') in E(Fp4)[r]
```

Для каждого:

```text
P != O
Q' != O
Q != O
rP = O
rQ' = O
rQ = O
```

Если генератор выбирается случайным поиском, нужно зафиксировать seed или deterministic search rule, чтобы результат был воспроизводим.

### 2.3. Проверить не только Weil pairing, но и целевой Tate/Ate pairing

В документе используется Weil pairing для проверки невырожденности. Это полезно как математическая проверка независимости подгрупп, но для реализации verifier нужен именно тот pairing, который будет реализован в Rust/Solidity.

Нужно вычислить и вывести:

```text
f_loop = MillerLoop(P,Q)       # или f_{T,Q}(P) для ate-form
Y = f_loop^((p^4 - 1)/r)
Y != 1
Y^r = 1
```

Если используется ate pairing, нужно строго подтвердить loop scalar:

```text
T = t - 1 = x - 1
```

и объяснить, почему именно этот scalar корректен для выбранных `G1/G2`.

### 2.4. Уточнить порядок аргументов pairing

В тексте встречается форма `a_T(Q,P)=f_{T,Q}(P)`. Для реализации нужно однозначно зафиксировать API:

```text
pairing(P in G1, Q in G2) -> GT
```

и внутреннюю форму Miller loop:

```text
Miller accumulator is built on Q, line functions are evaluated at P.
```

Нужно явно указать, какие координаты хранятся в prepared cache для `Q'` на twist и как они применяются к `P`.

### 2.5. Дать точную NAF/binary schedule

Нужно выдать:

```text
loop_scalar = x - 1
bit length
NAF digits or signed-bit representation
number of doubling steps
number of addition/subtraction steps
```

Это нужно, чтобы Rust backend и Solidity verifier имели одинаковый порядок coefficients.

### 2.6. Дать exact JSON vector

Нужен JSON следующего вида:

```json
{
  "p": "...",
  "r": "...",
  "curve": {"a": "...", "b": "..."},
  "tower": {
    "fp2": "u^2 + 1 = 0",
    "fp4": "v^2 - u = 0"
  },
  "twist": {
    "equation": "Y^2 = X^3 - aX + b*u",
    "untwist": "psi(X,Y)=(uX,u*v*Y)"
  },
  "g1": {"x": "...", "y": "..."},
  "g2_twist": {
    "x": ["x0", "x1"],
    "y": ["y0", "y1"]
  },
  "g2_untwisted": {
    "x": ["... four Fp coordinates ..."],
    "y": ["... four Fp coordinates ..."]
  },
  "pairing_type": "ate",
  "loop_scalar": "...",
  "naf_digits": ["..."],
  "miller_output": ["... four Fp coordinates ..."],
  "final_exponent": "...",
  "pairing_result": ["... four Fp coordinates ..."],
  "checks": {
    "rP_is_zero": true,
    "rQ_twist_is_zero": true,
    "rQ_untwisted_is_zero": true,
    "pairing_nontrivial": true,
    "pairing_result_pow_r_is_one": true
  }
}
```

### 2.7. Уточнить line formulas для prepared cache

Нужно дать формулы в виде, пригодном для кода:

- какие coefficients хранятся для doubling;
- какие coefficients хранятся для addition/subtraction;
- какие из них лежат в `Fp`, какие в `Fp2`, какие после untwist попадают в `Fp4`;
- как выглядит sparse multiplication `f <- f^2 * ell(P)`;
- сколько `Fp` multiplication требуется на один doubling-step и на один addition-step.

Особенно важно: если line evaluation содержит denominator factors, нужно явно указать, какие denominators удаляются за счет финальной экспоненты, а какие нельзя удалять.

### 2.8. Исправить/проверить мелкие неоднозначности текста

В текущем PDF есть места, которые нужно перепроверить и записать без опечаток:

1. `G2` после untwist должен лежать в `E(Fp4)`, а не в `E(Fp2)`.
2. В формуле обратного twist map встречается опечатка вида `-vx * y`; нужно записать корректно:

```text
phi(x,y) = (u^{-1}x, (uv)^{-1}y) = (-u*x, -v*y)
```

3. Таблица “без твиста / с твистом” должна сравнивать полную точку в `E(Fp4)` с twist-точкой в `E'(Fp2)`: это `8 Fp coordinates` против `4 Fp coordinates`, то есть примерно 2x по хранению точки.
4. Gas-оценки в PDF нужно пометить как предварительные, потому что реальные значения должны быть получены Foundry-тестами после реализации. Нельзя утверждать `~11M gas` как результат без кода.

## 3. Дополнительный вопрос для агента

Нужно явно ответить:

> В lollipop-305 для реализации полного verifier требуется один pairing на одной stick-curve или несколько pairings/loops по нескольким кривым lollipop-конструкции?

Ответ должен быть связан с ePrint 2024/1627: какие кривые из статьи являются частью lollipop-cycle, а какая конкретно используется для pairing-friendly verifier в нашем проекте.

## 4. Definition of Done

Доработка считается завершенной, если есть:

1. исполняемый Sage/Magma/GP скрипт;
2. конкретные координаты `P`, `Q'`, `Q`;
3. JSON vector;
4. проверка `rP=O`, `rQ=O`;
5. проверка `Miller + final exponentiation` для целевого Tate/Ate pairing;
6. проверка `pairing_result != 1` и `pairing_result^r = 1`;
7. точный loop schedule;
8. code-ready formulas для prepared line coefficients;
9. ответ, один или несколько Miller loops нужны в полном lollipop verifier;
10. исправленные замечания по опечаткам/неоднозначностям.
