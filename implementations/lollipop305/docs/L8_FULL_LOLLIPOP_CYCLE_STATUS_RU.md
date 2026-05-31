# L8. Полный lollipop-305: stick + cycle, статус реализации и сравнение

## 1. Что означает полный lollipop-305

В статье Costello--Korpal, ePrint 2024/1627, пример `lollipop-305-158` имеет не одну, а несколько связанных кривых.

1. `Stick curve` -- обычная pairing-friendly кривая `E_stick/Fp`.
2. `Supersingular cycle curve E/Fp2` -- первая кривая 2-цикла, pairing-friendly относительно `q`.
3. `Supersingular cycle curve Ehat/Fq2` -- вторая кривая 2-цикла, pairing-friendly относительно `p`.
4. Дополнительная не-pairing-friendly 158-битная кривая над `Fr`, которая нужна для сценариев рекурсивных доказательств, но не является pairing-verifier в EVM.

Главная идея lollipop: начать вычисления/доказательства над меньшим полем `Fr` порядка около 158 бит, затем иметь возможность перейти к pairing-friendly stick curve `E_stick/Fp`, а дальше использовать supersingular cycle для рекурсивной композиции.

## 2. Формальные параметры

Используется seed:

```text
x = 8004046504391788107635887004283725454478544674.
```

Из него получаются две 305-битные характеристики:

```text
p = x^2 - x + 1,
q = x^2 + 1.
```

Численно:

```text
p = 64064760444466402482617092084437280876782408929523650941985296571943203113725143542535221603,
q = 64064760444466402482617092084437280876782408937527697446377084679579090118008868997013766277.
```

Порядок подгруппы stick-curve:

```text
r = 265533234376483119496574875659819072867998144101.
```

Дополнительный 158-битный порядок для не-pairing cycle-curve:

```text
r_hat = 265533234376483119496575739829042558313583244851.
```

Проверенные связи:

```text
#E_stick(Fp) = Nq = x^2 - 2x + 2 = h * r,
#E_cycle(Fp2) = p^2 + 1 = q * Nq,
#Ehat_cycle(Fq2) = q^2 - q + 1 = p * Np,
Np = x^2 + x + 1.
```

Для `x ≡ 10 mod 12` статья дает оптимальный случай `(u,v)=(2,2)`:

```text
E_cycle/Fp2:    y^2 = x^3 + (mu + 1) x,       mu^2 + 1 = 0,
Ehat_cycle/Fq2: y^2 = x^3 + (eta + 2),         eta^2 + 2 = 0.
```

## 3. Что реализовано в Rust

Добавлены модули:

```text
lollipop305_research/rust_backend/src/field_q.rs
lollipop305_research/rust_backend/src/cycle.rs
lollipop305_research/rust_backend/tests/cycle_relations.rs
```

Они реализуют:

1. поле `Fq`;
2. расширение `Fq2 = Fq[eta]/(eta^2+2)`;
3. кривую `E_cycle/Fp2: y^2 = x^3 + (mu+1)x`;
4. кривую `Ehat_cycle/Fq2: y^2 = x^3 + (eta+2)`;
5. детерминированный поиск точек;
6. cofactor clearing;
7. проверку подгрупп:
   ```text
   [q]P_cycle = O,
   [p]P_ehat = O.
   ```

Запуск:

```bash
cd /Users/a.i.semenov/mnt4-pairing-final/lollipop305_research/rust_backend
cargo test --test cycle_relations
```

Результат:

```text
3 passed, 0 failed.
```

## 4. Что реализовано в Solidity/Yul для второй характеристики

Добавлены файлы:

```text
lollipop305_research/src/BigIntLollipop305Q.sol
lollipop305_research/src/Lollipop305QExtensionStack.sol
lollipop305_research/test/Lollipop305CycleQArithmetic.t.sol
```

Они реализуют:

1. двухлимбовую Montgomery-арифметику по модулю `q`;
2. `Fq2`-арифметику с `eta^2=-2`;
3. тесты roundtrip `toMontgomery/fromMontgomery`;
4. тест умножения в `Fq` на малых значениях;
5. тест `eta^2=-2`;
6. gas-бенчмарки `Fq.mul`, `Fq.square`, `Fq2.mul`, `Fq2.square`.

Запуск:

```bash
cd /Users/a.i.semenov/mnt4-pairing-final/lollipop305_research
forge test --match-path test/Lollipop305CycleQArithmetic.t.sol -vv --gas-report
```

Результат:

```text
8 passed, 0 failed.
```

Gas по benchmark-функциям:

| Операция | Calls внутри benchmark | Gas функции | Оценка gas/op |
|---|---:|---:|---:|
| `Fq.mul` | 512 | 506,098 | около 989 |
| `Fq.square` | 512 | 466,125 | около 910 |
| `Fq2.mul` | 128 | 534,659 | около 4,177 |
| `Fq2.square` | 128 | 431,488 | около 3,371 |

Эти значения близки к `Fp`-стороне lollipop-305 и подтверждают главный технический тезис: обе 305-битные характеристики укладываются в 2 EVM-лимба, поэтому базовая арифметика существенно дешевле MNT4/MNT6 с 3-limb полями.

## 5. Что уже измерено для stick pairing

Для `E_stick/Fp` уже реализован Article640-style verifier над prepared line values:

```text
lollipop305_research/src/Lollipop305Article640Verifier.sol
```

Измеренные значения:

| Режим | Gas |
|---|---:|
| Miller core | 5,289,040 |
| Miller + direct final exponentiation | 30,292,044 |
| Miller + residue FE | 8,669,753 |

Это измеренная часть lollipop-направления.

## 6. Оценка размеров witness/cache для полного lollipop pipeline

### Stick pairing

В текущем fixture:

```text
steps = 199,
line value = Fp4 = 8 EVM words,
record = 1 op word + 8 value words = 9 words.
```

Размер calldata/cache:

```text
199 * 9 * 32 = 57,312 bytes.
```

### Supersingular E_cycle/Fp2 pairing относительно q

Ожидаемый loop scalar имеет около 305 бит. Для NAF-представления грубая оценка:

```text
doublings ≈ 304,
add/sub steps ≈ 305/3 ≈ 102,
total steps ≈ 406.
```

Если хранить line values в `Fp4`, то формат аналогичен stick verifier:

```text
406 * 9 * 32 ≈ 116,928 bytes.
```

### Supersingular Ehat_cycle/Fq2 pairing относительно p

Target field для order-p pairing на `Ehat/Fq2` -- `Fq6`. Один элемент `Fq6` при tower-представлении над `Fq2` занимает:

```text
Fq6 = 3 * Fq2 = 6 * Fq = 12 EVM words.
```

Тогда line-value record:

```text
1 op word + 12 value words = 13 words,
406 * 13 * 32 ≈ 168,896 bytes.
```

## 7. Constraints-оценки для folding-применимости

Для грубой оценки можно считать стоимость одного field multiplication constraint в родном поле равной единице, а стоимость non-native multiplication -- десятки или сотни constraints из-за limb-разложения и редукции.

Для lollipop-305:

1. `Fp` и `Fq` имеют около 305 бит.
2. Если circuit работает над близким по размеру родным полем, один `Fp/Fq`-mul не требует 753-битной эмуляции.
3. Для `Fp4.mul` используется около 9 базовых умножений.
4. Для `Fq6.mul` ожидается около 18 базовых умножений при tower-представлении `Fq6/Fq2`.

Поэтому направление lollipop перспективно не потому, что оно уже production-safe, а потому что уменьшает размер базового поля и длину loop scalar. Это снижает и gas, и ожидаемую стоимость native-constraint layer.

## 8. Что пока не реализовано

На текущем этапе **не реализованы** полноценные EVM-verifier'ы для двух supersingular pairings цикла:

1. order-q pairing на `E_cycle/Fp2`, target `Fp4`;
2. order-p pairing на `Ehat_cycle/Fq2`, target `Fq6`.

Для их полной реализации нужны отдельные модули:

1. `Fp4` hot-path verifier для `E_cycle/Fp2` с line coefficients, полученными из `Fp2`-точек;
2. `Fq6` arithmetic и hot-path verifier для `Ehat_cycle/Fq2`;
3. prepared line cache для обеих cycle-кривых;
4. direct FE и residue FE;
5. gas-tests для `Miller core`, `direct FE`, `residue FE`;
6. cross-check против Rust backend.

Это отдельный объем, сопоставимый с реализацией `article640_mnt4_verifier` и `mnt6_article640_verifier`. Поэтому текущий L8 закрывает формальную и арифметическую основу полного lollipop-cycle, но не является полной EVM-реализацией двух supersingular pairings.

## 9. Итоговое сравнение с MNT4/MNT6

| Направление | Что измерено | Gas / размер |
|---|---|---:|
| MNT4 Article640 residue | полный hot verifier | 93,879,746 gas |
| lollipop stick residue | полный hot verifier на prepared line values | 8,669,753 gas |
| lollipop `Fq.mul` | EVM benchmark | около 989 gas/op |
| lollipop `Fq2.mul` | EVM benchmark | около 4,177 gas/op |
| lollipop stick cache | calldata/blob estimate | 57,312 bytes |
| lollipop cycle `E/Fp2` cache | estimate | 116,928 bytes |
| lollipop cycle `Ehat/Fq2` cache | estimate | 168,896 bytes |

Вывод: lollipop-305 уже демонстрирует сильное снижение стоимости для stick pairing. Полный lollipop-cycle требует реализации двух дополнительных supersingular pairing-verifier'ов; по текущей арифметике он должен быть существенно дешевле MNT4/MNT6, но этот вывод для полного цикла пока является инженерной оценкой, а не измеренным production-результатом.


## 10. Пошаговый план полного завершения lollipop-305 реализации

Этот раздел фиксирует, что именно нужно сделать, чтобы lollipop-направление было закрыто не как оценка, а как полноценная исполнимая реализация по образцу `article640_mnt4_verifier` и `mnt6_article640_verifier`.

### Этап L8.1. Формальная спецификация всех кривых

**Цель:** исключить неоднозначность между stick-curve, supersingular cycle и 158-битными не-pairing кривыми.

Нужно зафиксировать в коде и тестах:

```text
p = x^2 - x + 1,
q = x^2 + 1,
Nq = x^2 - 2x + 2,
Np = x^2 + x + 1,
#E_stick(Fp) = Nq = h*r,
#E_cycle(Fp2) = p^2 + 1 = q*Nq,
#Ehat_cycle(Fq2) = q^2 - q + 1 = p*Np.
```

Кривые:

```text
E_stick/Fp:       y^2 = x^3 + a*x + b,
E_cycle/Fp2:      y^2 = x^3 + (mu+1)*x,       mu^2=-1,
Ehat_cycle/Fq2:   y^2 = x^3 + (eta+2),        eta^2=-2.
```

Статус: выполнено в Rust через `cycle_relations.rs`.

### Этап L8.2. Арифметика второй характеристики `q` в EVM

**Цель:** иметь не только `Fp`, но и `Fq`, потому что полный lollipop-cycle использует обе 305-битные характеристики.

Нужно реализовать:

1. `Fq` Montgomery CIOS 2-limb;
2. `Fq2 = Fq[eta]/(eta^2+2)`;
3. gas-тесты `Fq.mul`, `Fq.square`, `Fq2.mul`, `Fq2.square`;
4. cross-check малых векторов с Rust.

Статус: выполнено в `BigIntLollipop305Q.sol`, `Lollipop305QExtensionStack.sol`, `Lollipop305CycleQArithmetic.t.sol`.

### Этап L8.3. Article640 verifier для stick curve

**Цель:** измерить pairing-friendly “палочку” `E_stick/Fp`.

Уже реализованный формат:

```text
Rust backend -> prepared line values -> Solidity verifier
```

Контракт проверяет recurrence:

```text
f_0 = 1,
f_{i+1} = f_i^2 * line_i     для doubling,
f_{i+1} = f_i   * line_i     для add/sub.
```

И два варианта финальной проверки:

```text
direct FE:    f^((p^4-1)/r) = 1,
residue FE:   c*c^{-1}=1 и c^r=f.
```

Статус: выполнено и измерено.

### Этап L8.4. Article640 verifier для `E_cycle/Fp2` относительно порядка `q`

**Цель:** реализовать первую pairing-часть supersingular cycle.

Нужно реализовать:

1. Rust backend для `E_cycle/Fp2`, поднятой в `Fp4`;
2. генерацию q-subgroup точек через cofactor clearing;
3. генерацию prepared line values для equation вида
   ```text
   e(P,Q) * e(-P,Q) = 1;
   ```
4. Solidity verifier над `Fp4`, но с другими степенями:
   ```text
   direct FE:    f^((p^4-1)/q) = 1,
   residue FE:   c*c^{-1}=1 и c^q=f.
   ```
5. негативный тест подмены line-value;
6. gas-таблицу `Miller core`, `direct FE`, `residue FE`.

Критерий готовности: Rust fixture принимается Solidity-контрактом; изменение одного байта line blob приводит к `false`; gas-report содержит три режима.

### Этап L8.5. Поле `Fq6` и Article640 verifier для `Ehat_cycle/Fq2` относительно порядка `p`

**Цель:** реализовать вторую pairing-часть supersingular cycle.

Нужно реализовать:

1. Rust tower для target field `Fq6`;
2. Solidity/Yul `Fq6` arithmetic поверх `Fq2`;
3. prepared line-value формат, где один line value занимает `Fq6 = 12 EVM words`;
4. direct FE:
   ```text
   f^((q^6-1)/p)=1;
   ```
5. residue FE:
   ```text
   c*c^{-1}=1 и c^p=f;
   ```
6. gas-tests и negative tamper tests.

Критерий готовности: полный Rust-generated fixture для `Ehat_cycle/Fq2` принимается Solidity verifier; tamper-test отвергается; gas-report содержит три режима.

### Этап L8.6. Constraints-модель между кривыми

**Цель:** показать, зачем lollipop полезен для folding, а не только для gas.

Нужно построить две оценки:

1. **Native-cycle estimate:** сколько базовых умножений нужно в родных полях `Fp`, `Fq`, `Fr`.
2. **Non-native estimate:** сколько limb constraints возникает при переносе той же арифметики в чужое поле, например BN254.

Минимальная таблица:

| Слой | Родное поле | Базовая операция | Оценка constraints |
|---|---|---|---:|
| stick `E_stick/Fp` | `Fp` | `Fp.mul`, `Fp4.mul` | по числу mul |
| cycle `E/Fp2` | `Fp`/`Fp2` | `Fp4.mul` | по числу mul |
| cycle `Ehat/Fq2` | `Fq`/`Fq2` | `Fq6.mul` | по числу mul |
| BN254 non-native | `Fr(BN254)` | 305-bit/610-bit limbs | через limb-decomposition |

Критерий готовности: в документе есть не только асимптотика, но и численные оценки, выведенные из реального числа шагов Miller loop и измеренной стоимости базовой арифметики.

### Этап L8.7. Финальное сравнение

Нужно собрать итоговую таблицу:

| Реализация | Curve layer | Target field | Miller gas | Direct FE gas | Residue FE gas | Cache bytes | Constraints estimate |
|---|---|---|---:|---:|---:|---:|---:|
| MNT4 baseline | MNT4 | `Fp4` | measured | measured | measured | measured | estimated |
| MNT6 baseline | MNT6 | `Fp6` | measured | measured | measured | measured | estimated |
| lollipop stick | `E_stick/Fp` | `Fp4` | measured | measured | measured | measured | estimated |
| lollipop cycle E | `E/Fp2` | `Fp4` | measured | measured | measured | measured | estimated |
| lollipop cycle Ehat | `Ehat/Fq2` | `Fq6` | measured | measured | measured | measured | estimated |

Только после L8.4--L8.7 можно говорить, что lollipop-направление закрыто полностью.

## 11. Реализация L8.4: первый исполнимый слой для `E_cycle/Fp2`

После фиксации плана начата реализация этапа L8.4.

Добавлено:

```text
lollipop305_research/rust_backend/src/cycle_pairing.rs
lollipop305_research/rust_backend/tests/cycle_e_pairing.rs
lollipop305_research/rust_backend/src/bin/lollipop305_cycle_e_core_fixture.rs
lollipop305_research/docs/lollipop305_cycle_e_core_fixture.words.hex
lollipop305_research/test/Lollipop305CycleECoreVerifier.t.sol
```

Что уже работает:

1. Rust строит q-order Miller loop для `E_cycle/Fp2`, поднятой в `Fp4`.
2. Rust генерирует prepared line-value blob в том же формате, что и stick verifier.
3. Solidity verifier проверяет recurrence:
   ```text
   f_0 = 1,
   f_{i+1} = f_i^2 * line_i     для doubling,
   f_{i+1} = f_i   * line_i     для add/sub.
   ```
4. Негативный тест с подменой line-value отвергается.

Измерение:

```bash
cd /Users/a.i.semenov/mnt4-pairing-final/lollipop305_research
forge test --match-path test/Lollipop305CycleECoreVerifier.t.sol -vv --gas-report
```

Результат:

```text
3 passed, 0 failed.
```

Gas:

| Режим | Gas |
|---|---:|
| `E_cycle/Fp2` Miller core, test call | 19,136,455 |
| `verifyMillerCore` по gas-report | 11,174,476 -- 11,437,631 |

Почему есть два числа: значение теста включает расходы Foundry/test harness и подготовку calldata внутри тестового вызова; gas-report по функции ближе к стоимости самого verifier-вызова.

### Важное ограничение L8.4

Попытка напрямую перенести stick-style финальную проверку на `E_cycle/Fp2` выявила блокер: для выбранной простой equation-трассы проверка

```text
f^((p^4-1)/q) = 1
```

не проходит. Поэтому direct FE/residue FE для `E_cycle/Fp2` **не были объявлены готовыми**.

Это не Solidity-ошибка, а требование к математической части: для supersingular cycle-части нужно отдельно вывести точную pairing equation, правила denominator elimination и, при необходимости, Frobenius/scaling tail. До этого корректно измеренной является только Miller-core recurrence, а не полный reduced pairing verifier.

Следующий обязательный шаг для полного закрытия L8.4:

1. вывести корректную формулу reduced pairing equation для `E_cycle/Fp2` относительно порядка `q`;
2. проверить ее в Rust на `direct FE`;
3. только затем переносить `direct FE` и `residue FE` в Solidity.
