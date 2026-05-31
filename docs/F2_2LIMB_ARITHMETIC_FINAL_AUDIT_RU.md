# F2. Финальный аудит 2-limb арифметики lollipop-305 в EVM

## 1. Цель аудита

F2 проверяет, насколько оптимальна 2-limb арифметика, реализованная для исследовательского направления lollipop-305 из ePrint 2024/1627. В отличие от MNT4-753, где элемент поля занимает три 256-битных слова, здесь поле имеет размер около 305 бит, поэтому элемент хранится двумя словами:

```text
x = x0 + x1 * 2^256.
```

Главный вопрос F2: можно ли получить существенное снижение gas за счет меньшего числа limb-ов и специальной формы старшего limb-а.

## 2. Параметры поля

Используется пример lollipop-305-158:

```text
x = 8004046504391788107635887004283725454478544674,
p = x^2 - x + 1.
```

Разложение модуля:

```text
p0 = 0x24240b65671ab020b2f03c6035ed8fdcdd1ff464dbb7022f6583adbbb2fef163
p1 = 0x1f733286263df
```

Ключевая особенность:

```text
p1 < 2^49.
```

Следовательно, у любого редуцированного элемента поля high-limb также меньше `2^49`.

## 3. Нижняя оценка для 2-limb Montgomery/CIOS

Для общего двухсловного умножения:

```text
a = a0 + a1 B,
b = b0 + b1 B,
B = 2^256.
```

Обычное произведение содержит четыре limb-products:

```text
a0b0, a0b1, a1b0, a1b1.
```

CIOS Montgomery-редукция для двух limb-ов выполняет два шага. На каждом шаге добавляется `m_i * p`, где `p` имеет два limb-а. Это еще:

```text
2 * 2 = 4
```

произведения.

Для generic 2-limb поля нижняя структура такая:

```text
4 products для a*b
+
4 products для REDC
=
8 полных 256x256 -> 512 произведений.
```

Но для lollipop-305 есть дополнительная оптимизация. Так как `a1,b1 < 2^49`, произведение

```text
a1*b1 < 2^98
```

не требует 512-битного восстановления через `mulmod`. Поэтому в `montMul2` фактическая нижняя структура после оптимизации:

```text
7 full mul512
+
1 ordinary MUL для a1*b1
+
2 ordinary MUL для Montgomery coefficients m_i.
```

Для `montSqr2` аналогично `a1*a1 < 2^98`, поэтому square-path также может заменить одно full `mul512` на обычный `MUL`.

## 4. Что было реализовано в F2

В основной production-файл lollipop-305 перенесены две безопасные оптимизации:

1. `a1*b1` в `montMul2` и `a1*a1` в `montSqr2` считаются через обычный `mul`, потому что high limbs меньше `2^49`.
2. В блоках `m*p0` больше не сохраняется новый `t0`; используется только carry, потому что этот limb сразу удаляется CIOS-сдвигом.

Измененный production-файл:

```text
lollipop305_research/src/BigIntLollipop305.sol
```

Дополнительные экспериментальные файлы для проверки гипотез:

```text
lollipop305_research/src/BigIntLollipop305FinalSelect.sol
lollipop305_research/src/BigIntLollipop305SkipT0.sol
lollipop305_research/src/BigIntLollipop305SmallHigh.sol
lollipop305_research/src/BigIntLollipop305SmallHighSkipT0.sol
```

Тестовый файл F2:

```text
lollipop305_research/test/Lollipop305F2Optimization.t.sol
```

## 5. Проверенные альтернативы

| Вариант | Идея | Результат |
|---|---|---|
| Current CIOS до F2 | обычный 2-limb CIOS | `~2081 gas/op` для `Fp.mul` |
| FinalSelect | branchless final subtraction | хуже текущего пути |
| SkipT0 | не сохранять dead `t0` | сам по себе почти не дает выигрыша |
| SmallHigh | заменить `a1*b1` / `a1*a1` на обычный `mul` | основной выигрыш |
| SmallHigh + SkipT0 | объединение двух безопасных идей | выбранный production-путь |
| Comba/SOS | materialized product | хуже CIOS |
| FIOS | memory-based FIOS | хуже CIOS |
| Barrett | canonical representation | хуже CIOS |

## 6. Gas до и после F2

До F2:

| Операция | Gas/op |
|---|---:|
| `Fp.mul` | 2,081 |
| `Fp.square` | 1,926 |
| `Fp2.mul stack` | 7,361 |
| `Fp2.square stack` | 6,289 |
| `Fp4.mul full-stack` | 24,243 |
| `Fp4.square stack` | 22,028 |

После F2:

| Операция | Total gas | Повторов | Gas/op |
|---|---:|---:|---:|
| `Fp.mul` | 521,240 | 512 | 1,018 |
| `Fp.square` | 481,113 | 512 | 940 |
| `Fp2.mul stack` | 533,920 | 128 | 4,171 |
| `Fp2.square stack` | 416,468 | 128 | 3,254 |
| `Fp4.mul full-stack` | 1,912,589 | 128 | 14,942 |
| `Fp4.square stack` | 1,690,986 | 128 | 13,211 |

Итоговый выигрыш F2:

| Операция | Было | Стало | Улучшение |
|---|---:|---:|---:|
| `Fp.mul` | 2,081 | 1,018 | 2.04x |
| `Fp.square` | 1,926 | 940 | 2.05x |
| `Fp2.mul stack` | 7,361 | 4,171 | 1.76x |
| `Fp2.square stack` | 6,289 | 3,254 | 1.93x |
| `Fp4.mul full-stack` | 24,243 | 14,942 | 1.62x |
| `Fp4.square stack` | 22,028 | 13,211 | 1.67x |

## 7. Сравнение с MNT4-753

| Операция | lollipop-305 после F2 | MNT4-753 | Выигрыш |
|---|---:|---:|---:|
| `Fp.mul` | 1,018 | 2,959 | 2.91x |
| `Fp.square` | 940 | 2,947 | 3.14x |
| `Fp2.mul` | 4,171 | 11,877 | 2.85x |
| `Fp2.square` | 3,254 | 10,592 | 3.26x |
| `Fp4.mul` | 14,942 | 42,764 | 2.86x |
| `Fp4.square` | 13,211 | 36,606 | 2.77x |

## 8. Почему оптимизация корректна

Для редуцированного элемента поля всегда выполнено:

```text
0 <= x < p,
p < 2^305.
```

После проверки twist-спецификации башня `Fp4` была исправлена: вместо `v^2=u` используется `v^2=1+u`, так как `u` является квадратом в `Fp2` для данного `p`. Это немного увеличивает стоимость `Fp4.mul/square` из-за дополнительного сложения в умножении на `1+u`, но делает арифметику полем, а не фактор-кольцом с разложимым модулем.

Значит high limb `x1` меньше `2^49`. Поэтому:

```text
x1*y1 < 2^98 < 2^256.
```

Следовательно, в произведениях `a1*b1` и `a1*a1` старшие 256 бит равны нулю. Полный `mul512` здесь избыточен: достаточно обычного `mul`, а вклад `hi` в следующий limb равен нулю.

Эта оптимизация не применима к `a0*b1`, `a1*b0` или `m*p1`: там один из множителей может быть полноценным 256-битным словом, поэтому результат может пересекать границу `2^256` и требует full `mul512`.

## 9. Проверки

Выполнены команды:

```bash
cd /Users/a.i.semenov/mnt4-pairing-final/lollipop305_research
forge test --match-path test/Lollipop305Arithmetic.t.sol -vv --gas-report
forge test --match-path test/Lollipop305F2Optimization.t.sol -vv --gas-report
cd rust_reference && cargo test
```

Результаты:

```text
Lollipop305Arithmetic.t.sol: 10 passed, 0 failed
Lollipop305F2Optimization.t.sol: 4 passed, 0 failed
Rust reference: 3 passed, 0 failed
```

F2-тесты дополнительно проверяют:

- boundary vectors около модуля;
- fuzz по редуцированным входам с произвольным low-limb и bounded high-limb;
- совпадение `SmallHigh` с исходным CIOS;
- совпадение square-path с текущим reference.

## 10. Итог F2

F2 дал существенный положительный результат. В отличие от 3-limb MNT4-753, где дальнейшие low-level улучшения не подтвердились, 2-limb lollipop-305 имеет специальное свойство малого high-limb. Оно позволяет убрать часть full 512-bit multiplication из hot path.

Итоговый production-выбор для 2-limb арифметики:

```text
Montgomery/CIOS + specialized square + small-high-limb optimization + stack API for extensions.
```

Пункт F2 можно считать закрытым: текущая 2-limb реализация после F2 является лучшим найденным вариантом среди рассмотренных и дает примерно `2.8x-3.3x` выигрыш относительно MNT4-753 на базовых операциях и расширениях `Fp2/Fp4`.
