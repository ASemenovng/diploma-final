# L5: статус реализации полного аналога article640_mnt4_verifier для lollipop-305

## 1. Короткий вывод

Математический блокер по второй pairing-группе для исследовательского кандидата `lollipop-305-158` частично закрыт: в Rust backend зафиксированы `G1`, twist-модель `G2`, отображение `untwist`, проверка Frobenius-eigenspace и невырожденное целевое ate-сопряжение.

При проверке обновленной спецификации была найдена важная ошибка: башня `Fp4 = Fp2[v]/(v^2-u)` не подходит для данных параметров, потому что при `p ≡ 3 (mod 8)` элемент `u` является квадратом в `Fp2`. Поэтому `v^2-u` раскладывается, а не задает поле `Fp4`. Реализация исправлена на башню

```text
Fp2 = Fp[u] / (u^2 + 1),
Fp4 = Fp2[v] / (v^2 - xi),  xi = 1 + u.
```

Для `xi=1+u` вычислительно проверено, что это неквадрат в `Fp2`, поэтому `Fp4` действительно является квадратичным расширением `Fp2`.

## 2. Что уже сделано

### Параметры

Зафиксированы параметры lollipop-305-158 из ePrint 2024/1627 Appendix A Example 1 и исходного Magma/GP-скрипта:

```text
p = x^2 - x + 1
q = x^2 + 1
r = 265533234376483119496574875659819072867998144101
embedding degree over E/Fp with respect to r: 4
```

### Исправленная башня расширений

В Rust и Solidity/Yul арифметике теперь используется:

```text
u^2 = -1,
v^2 = xi = 1 + u.
```

Это важно не только для тестов, но и для корректности всего pairing-слоя: если `v^2-u` не задает поле, то операции `inverse`, `sqrt`, финальная экспонента и проверка `Y^r=1` теряют криптографический смысл.

### Twist и G2

Для `xi=1+u` используется квадратичный twist:

```text
E:  y^2 = x^3 + a*x + b over Fp,
E': Y^2 = X^3 + (a/xi^2)*X + b/xi^3 over Fp2.
```

Отображение `untwist`:

```text
psi(X,Y) = (xi*X, xi*v*Y).
```

В Rust backend реализованы:

- `AffinePointFp2Twist`;
- cofactor clearing для получения `Q' in E'(Fp2)[r]`;
- `untwist_to_fp4(Q')`;
- проверка `[r]P = O`, `[r]Q' = O`, `[r]psi(Q') = O`;
- проверка Frobenius-eigenspace:

```text
pi_p(psi(Q')) = [p] psi(Q').
```

### Target ate pairing

Реализовано target ate-сопряжение:

```text
a_T(P,Q) = f_{T,Q}(P)^((p^4-1)/r),   T = x - 1.
```

Rust-тест проверяет:

```text
a_T(P,Q) != 1,
a_T(P,Q)^r = 1.
```

Это закрывает прежний риск: smoke-test на embedded base-field point мог давать тривиальный результат `1`, а значит не доказывал полноценную pairing-инстанциацию.

## 3. Что добавлено в код

| Компонент | Статус |
|---|---|
| `rust_backend/src/twist.rs` | Twist-модель, `G1/G2` generators, `untwist_to_fp4` |
| `rust_backend/src/pairing.rs` | Miller loop над `E(Fp4)` с source point в `Fp4`, reduced ate pairing для twist source |
| `rust_backend/src/bin/lollipop305_twist_pairing_vector.rs` | Воспроизводимый JSON-вектор `P`, `Q'`, `psi(Q')`, pairing result |
| `rust_backend/tests/backend_contract.rs` | Тест невырожденного target ate pairing |
| `src/Lollipop305Extension.sol` | Solidity tower исправлена на `v^2=1+u` |
| `src/Lollipop305ExtensionStack.sol` | Stack-oriented `Fp4` исправлена на `v^2=1+u` |
| `test/Lollipop305Arithmetic.t.sol` | Обновлены reference vectors для `Fp4.mul` |

## 4. Текущие проверки

Rust:

```text
cargo test --manifest-path lollipop305_research/rust_backend/Cargo.toml
```

Результат:

```text
16 passed, 0 failed
```

Solidity/Foundry:

```text
forge test --root lollipop305_research --match-path test/Lollipop305Arithmetic.t.sol -vv
```

Результат:

```text
10 passed, 0 failed
```

JSON-вектор:

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

## 5. Что еще не является завершенным full article640 analogue

Solidity/Yul verifier по аналогии с прямым режимом `article640_mnt4_verifier` реализован для prepared line-value path. Теперь причина уже не в математическом выборе `G2`, а в усилении soundness модели line-cache:

1. twist-aware prepared line values генерируются Rust backend;
2. полный prepared line-value blob передается в Solidity;
3. hot-path `f <- f^2 * line` / `f <- f * line` перенесен в Solidity/Yul;
4. direct FE и residue FE режимы реализованы;
5. измерены:
   - Miller core: `5,289,040 gas`;
   - Miller + direct FE: `30,292,044 gas`;
   - Miller + residue FE: `8,669,753 gas`;
   - calldata/cache size: `57,312 bytes`;
   - comparison with MNT4-753: см. `L7_ARTICLE640_VERIFIER_RESULTS_RU.md`.

Оставшееся ограничение: текущая версия проверяет recurrence по line values, но не доказывает on-chain, что line values построены из `Q`. Для production-grade line-cache soundness нужен отдельный слой: пересчет line coefficients или polynomial/commitment proof.

## 6. Текущий статус по F7

| Пункт | Статус |
|---|---|
| Зафиксировать `P in E(Fp)[r]` и `Q in E(Fp4)[r]` | Готово в Rust через twist `E'(Fp2)` |
| Проверить `e(P,Q) != 1` | Готово для target ate pairing |
| Сгенерировать prepared sparse lines | Готово как prepared line-value blob |
| Solidity/Yul hot-path verifier | Готово для recurrence/direct FE/residue FE |
| Gas comparison with MNT4-753 | Готово в `L7_ARTICLE640_VERIFIER_RESULTS_RU.md` |

## 7. Вывод для диплома

lollipop-305 остается исследовательским, а не production-secure кандидатом. Но после исправления башни и проверки target ate pairing направление стало математически осмысленным: теперь можно честно утверждать, что исследование дошло не только до дешевой 2-limb арифметики, но и до воспроизводимой pairing-инстанциации на уровне Rust reference. Следующий шаг, если продолжать это направление, — не математика `G2`, а перенос полного lollipop verifier в Solidity/Yul и измерение gas.
