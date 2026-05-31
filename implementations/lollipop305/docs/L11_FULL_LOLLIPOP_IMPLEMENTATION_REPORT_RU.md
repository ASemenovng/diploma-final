# L11. Итоговая реализация lollipop-305: полный pipeline, тесты и сравнение с MNT4/MNT6

## 1. Короткий вывод

В модуле `lollipop305_research` реализован полный исследовательский pipeline для lollipop-305 из ePrint 2024/1627:

1. stick-часть над базовым полем `Fp`;
2. первая supersingular cycle-часть `E_cycle/Fp2 -> Fp4`;
3. вторая supersingular cycle-часть `Ehat_cycle/Fq2 -> Fq6`;
4. Rust backend, который строит prepared line-value witness;
5. Solidity verifier, который проверяет подготовленные цепочки аккумуляторов;
6. Foundry-тесты корректности и gas-report.

Главный результат: арифметика lollipop-305 как 2-limb поле действительно существенно дешевле MNT4-753/MNT6-753 арифметики, но полный lollipop-cycle в прямой EVM-проверке не становится автоматически дешевым. Причина в том, что `Ehat/Fq2` корректно реализуется через Weil-equation в `Fq6`, где требуется четыре Miller-трассы. Поэтому итоговая полная lollipop-проверка оказывается дороже, чем одна MNT4/MNT6 article640-equation проверка, несмотря на более дешевое базовое поле.

Это важный отрицательно-положительный результат: направление lollipop перспективно для арифметики и будущего folding/proof-system слоя, но прямой on-chain verifier всего lollipop-cycle не является бесплатной заменой MNT4/MNT6.

## 2. Какие кривые участвуют

В lollipop-305 используются две основные величины:

```text
x = 8004046504391788107635887004283725454478544674,
p = x^2 - x + 1,
q = x^2 + 1.
```

Поля и кривые:

| Часть | Поле | Кривая | Целевое поле |
|---|---|---|---|
| stick | `Fp` | stick pairing prototype | `Fp4` |
| cycle E | `Fp2 = Fp[mu]/(mu^2+1)` | `E: y^2 = x^3 + (mu+1)x` | `Fp4` |
| cycle Ehat | `Fq2 = Fq[eta]/(eta^2+2)` | `Ehat: y^2 = x^3 + (eta+2)` | `Fq6` |

Проверенные отношения порядков:

```text
#E_cycle(Fp2)    = p^2 + 1     = q * Nq,
#Ehat_cycle(Fq2) = q^2 - q + 1 = p * Np.
```

Это означает, что `E_cycle` дает order-`q` часть, а `Ehat` дает order-`p` часть. Вместе они образуют исследовательский lollipop-cycle.

## 3. Что делает Rust backend

Rust backend не является oracle внутри Solidity. Его задача -- построить воспроизводимые witness/fixtures, которые затем проверяются контрактом.

### 3.1. Stick и `E_cycle`

Для stick и `E_cycle` backend строит prepared line-value blob:

```text
(op_1, line_1), (op_2, line_2), ..., (op_n, line_n).
```

Здесь:

- `op = 1` означает шаг удвоения, где аккумулятор обновляется как `f <- f^2 * line`;
- `op = 0` означает шаг сложения/вычитания, где `f <- f * line`;
- `line_i` уже является значением функции линии в целевом поле.

Для `E_cycle` используется distortion/Frobenius map:

```text
psi_E(x,y) = (theta^2 * x^p, theta^3 * y^p),
theta^4 = mu.
```

Это переводит рациональную подгруппу в независимую pairing-подгруппу в `Fp4`.

### 3.2. `Ehat`

Для `Ehat` backend строит четыре Miller-трассы для Weil-equation:

```text
f_{p,P}(Q),
f_{p,-P}(Q),
f_{p,Q}(P),
f_{p,Q}(-P).
```

Используемая distortion/Frobenius map:

```text
Fq6 = Fq2[w] / (w^3 - rho),
rho^2 = (2 + eta)/(2 - eta),
psi_Ehat(x,y) = (w^2 * x^q, rho * y^q).
```

Корректная проверка для `Ehat` -- не Tate-style residue, а Weil-equation:

```text
e_p(P,Q) = f_{p,P}(Q) / f_{p,Q}(P),
e_p(P,Q) * e_p(-P,Q) = 1.
```

В раскрытом виде контракт проверяет:

```text
f_{p,P}(Q) * f_{p,-P}(Q)
=
f_{p,Q}(P) * f_{p,Q}(-P).
```

## 4. Что передается в Solidity

### 4.1. Формат prepared line blob

Для `Fp4`-частей один шаг занимает:

```text
32 bytes op + 8 * 32 bytes Fp4 = 288 bytes.
```

Для `Fq6`-части один шаг занимает:

```text
32 bytes op + 12 * 32 bytes Fq6 = 416 bytes.
```

Сгенерированные fixtures:

| Fixture | Размер |
|---|---:|
| `lollipop305_cycle_e_article640_fixture.words.bin` | 116,288 bytes |
| `lollipop305_cycle_ehat_weil_fixture.words.bin` | 668,160 bytes |

Размер `Ehat` fixture большой, потому что он содержит четыре Miller-трассы по 401 шагу каждая.

## 5. Что проверяет Solidity

Основной контракт:

```text
lollipop305_research/src/Lollipop305Article640Verifier.sol
```

Он реализует три группы проверок.

### 5.1. Stick / Article640-style verifier

Контракт получает prepared line blob и witness `c, c^{-1}`. Проверяется:

```text
c * c^{-1} = 1,
f = Miller(preparedLines),
c^r = f.
```

Это заменяет прямую финальную экспоненту проверкой witness-отношения.

### 5.2. `E_cycle/Fp2 -> Fp4`

Аналогично stick-части, но scalar/order -- `q`, а final exponent относится к `Fp4`:

```text
F = f_{q,Q}(P) * f_{q,Q}(-P),
F^((p^4-1)/q) = 1
```

или residue-вариант:

```text
c^q = F,
c * c^{-1} = 1.
```

### 5.3. `Ehat/Fq2 -> Fq6`

Для `Ehat` контракт проверяет Weil-equation:

```text
lhs = MillerTrace(f_{p,P}(Q)) * MillerTrace(f_{p,-P}(Q)),
rhs = MillerTrace(f_{p,Q}(P)) * MillerTrace(f_{p,Q}(-P)),
lhs == rhs.
```

Финальная экспонента здесь не нужна, потому что используется Weil-представление через отношение Miller-функций.

## 6. Какие оптимизации применены

| Оптимизация | Где применяется | Практический смысл |
|---|---|---|
| 2-limb представление | `Fp`, `Fq` | элементы lollipop-305 помещаются в два 256-bit limb |
| Montgomery/CIOS | базовые поля | быстрое умножение и редукция в EVM |
| small-high-limb optimization | `Fp`, `Fq` | старший limb малый, часть произведений дешевле полного 512-bit пути |
| stack-oriented API | `Fp2/Fp4/Fq2` | меньше nested memory structs и копирований |
| prepared line-values | все verifier-части | контракт не строит линии, а проверяет аккумулятор по подготовленным значениям |
| residue witness | stick, `E_cycle` | замена полной финальной экспоненты проверкой `c^r=f` / `c^q=F` |
| Weil-equation | `Ehat` | корректная форма для второй supersingular cycle-кривой |
| Karatsuba `Fq6.mul` | `Ehat` | 6 `Fq2.mul` вместо 9 schoolbook `Fq2.mul` в горячем пути |

Karatsuba-оптимизация для `Fq6` дала заметный выигрыш: function gas `verifyEhatWeilEquation` снизился примерно с `243.96M` до `200.57M` gas.

## 7. Gas-результаты lollipop-305

Команда:

```bash
cd /Users/a.i.semenov/mnt4-pairing-final/lollipop305_research
forge test -vv --gas-report --gas-limit 3000000000
```

Результат:

```text
38 tests passed, 0 failed.
```

### 7.1. Основные verifier-режимы

| Часть | Проверка | Test-call gas | Function gas-report |
|---|---|---:|---:|
| stick | Miller core | 9,248,055 | до 5,288,626 для stick / общий max выше из-за shared function |
| stick | direct FE | 34,237,230 | 30,297,178 |
| stick | residue FE | 12,647,052 | 8,671,771 |
| `E_cycle/Fp2` | Miller core | 19,146,357 | 11,447,098 max shared `verifyMillerCore` |
| `E_cycle/Fp2` | direct FE | 42,021,090 | 34,076,546 |
| `E_cycle/Fp2` | residue FE | 26,263,511 | 18,283,781 |
| `Ehat/Fq2` | Weil equation | 247,140,135 | 200,567,235 |

### 7.2. Полная стоимость lollipop-cycle в текущем on-chain формате

Если считать полный pipeline как сумму трех проверок по function gas-report:

```text
stick residue      =   8,671,771
E_cycle residue    =  18,283,781
Ehat Weil equation = 200,567,235
---------------------------------
total              = 227,522,787 gas
```

Если считать по test-call gas:

```text
stick residue      =  12,647,052
E_cycle residue    =  26,263,511
Ehat Weil equation = 247,140,135
---------------------------------
total              = 286,050,698 gas
```

Обе суммы показывают один вывод: `Ehat/Fq6` доминирует.

## 8. Ehat prepared-Ate/residue после уточненного исследования

После получения исправленной спецификации для `\hat{E}/\mathbb{F}_{q^2}` добавлен отдельный путь, который заменяет Weil-ratio fallback на prepared-Ate/residue проверку. Этот путь не удаляет старую реализацию, а стоит рядом с ней как более близкий к статье ePrint 2024/640 вариант.

Что реализовано:

1. Rust backend строит prepared-line записи для `Q'=\psi(Q_0)` и loop-параметра `s=x-1`.
2. Каждая запись содержит тип операции `DOUBLE/ADD`, коэффициент `xCoeffW`, свободный член `constCoeff` и `cVert` для вертикальной линии.
3. Rust отдельно накапливает `F_num` и `F_den`, строит witness `c` и проверяет `c^p * F_den = F_num`.
4. Solidity verifier заново вычисляет `F_num` и `F_den` по prepared lines и точке `P`, затем проверяет `c^p * F_den = F_num`.
5. Для тестового equation-сценария используется проверка `a(Q',P) * a(Q',-P) = 1`.

Файлы:

- `rust_backend/src/bin/lollipop305_cycle_ehat_ate_residue_fixture.rs`;
- `docs/lollipop305_cycle_ehat_ate_residue_fixture.words.hex`;
- `src/Lollipop305Article640Verifier.sol`;
- `src/Lollipop305QExtensionStack.sol`;
- `test/Lollipop305EhatAteResidueVerifier.t.sol`.

Свежий результат:

| Режим | Function-level gas |
|---|---:|
| Ehat Weil equation fallback | `200,977,272` |
| Ehat prepared-Ate raw `F_num/F_den` | `76,422,749` |
| Ehat prepared-Ate + residue check | `106,441,661` |

Вывод: уточненная Tate/Ate-реализация действительно дешевле Weil fallback примерно в `1.89x`, но не достигает оптимистичной оценки `65--80M gas`. Причина в том, что для `\hat{k}=3` standard denominator elimination невозможен, поэтому verifier ведет два аккумулятора `F_num` и `F_den`, а затем выполняет `305`-битное возведение `c^p` в `Fq6`.

## 9. Сравнение с MNT4/MNT6

| Подход | Основной режим | Gas |
|---|---|---:|
| MNT4 full on-chain reference | полное вычисление digest | 259,719,954 |
| MNT4 article640 hot residue equation | optimized MNT4 equation verifier | 93,881,355 |
| MNT6 article640 residue path | optimized MNT6 equation verifier | 103,294,551 |
| lollipop stick + E_cycle + Ehat Weil fallback | полный исследовательский lollipop-cycle, function gas | 227,522,787 |
| lollipop stick + E_cycle + Ehat prepared-Ate/residue | улучшенный исследовательский lollipop-cycle, function gas | 133,397,213 |

Интерпретация:

1. Отдельные lollipop-компоненты над `Fp/Fp2/Fp4` дешевле MNT4/MNT6: например `E_cycle residue` стоит около `18.3M` function gas.
2. Переход от Weil fallback к prepared-Ate/residue резко снижает вклад `Ehat/Fq6`: примерно `201.0M -> 106.4M`.
3. Даже после этого полный lollipop-cycle остается дороже MNT4/MNT6 article640-verifier режимов, потому что `Ehat/Fq6` требует раздельного накопления числителя и знаменателя.
4. Поэтому lollipop-305 подтверждает идею более дешевой малолимбовой арифметики, но не дает простую on-chain замену MNT4/MNT6 без дальнейшей оптимизации verifier-модели.

## 10. Корректность и тесты

### Rust

Команда:

```bash
cd /Users/a.i.semenov/mnt4-pairing-final/lollipop305_research/rust_backend
cargo test -q
```

Результат:

```text
16 passed,
4 passed, 2 ignored,
3 passed,
0 failed.
```

Игнорируемые тесты -- это старые математически неверные Tate-style попытки, оставленные как документация отвергнутых направлений.

### Foundry

Команда:

```bash
cd /Users/a.i.semenov/mnt4-pairing-final/lollipop305_research
forge test -vv --gas-report --gas-limit 3000000000
```

Результат:

```text
43 tests passed, 0 failed.
```

Проверяются:

1. арифметика `Fp/Fp2/Fp4`;
2. арифметика `Fq/Fq2`;
3. корректность optimized 2-limb Montgomery paths;
4. stick verifier;
5. `E_cycle` direct/residue verifier;
6. `Ehat` Weil verifier;
7. `Ehat` prepared-Ate/residue verifier;
8. негативные тесты на подмену prepared line и witness `c`.

## 11. Итог для диплома

Lollipop-305 направление теперь закрыто как исследовательская реализация:

1. реализована вся арифметическая база для обеих сторон `p/q`;
2. реализован `E_cycle` Article640-style verifier;
3. математически выведена и реализована `Ehat` Weil-equation проверка;
4. после уточненного исследования добавлена `Ehat` prepared-Ate/residue проверка;
5. добавлен полный Rust fixture backend;
6. добавлен Solidity verifier;
7. проведены gas-измерения;
8. выполнено сравнение с MNT4/MNT6.

Главный вывод для защиты: уменьшение размера поля и переход к 2-limb арифметике действительно снижает стоимость базовых операций, но общая стоимость pairing-verifier определяется не только размером поля. Структура pairing equation, число Miller-трасс и целевое расширение (`Fp4` против `Fq6`) могут вернуть стоимость к сотням миллионов gas. Поэтому lollipop-подход перспективен как направление для proof-system/folding-слоя, но прямое on-chain исполнение полного цикла в EVM пока не является практичной заменой оптимизированным MNT4/MNT6 article640-verifier режимам.
