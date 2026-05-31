# F6B. Предварительный MNT4/MNT6 cycle-native слой

## 1. Зачем нужен этот этап

Цель этапа F6B — не реализовать полный CycleFold и не заменить текущий EVM-verifier новым production-контрактом. Цель уже точнее: показать кодом и тестами, что работа не ограничивается одиночной кривой MNT4-753, а действительно выходит на MNT4/MNT6 цикл, который нужен для будущего folding.

Главное свойство цикла:

```text
Fr(MNT4-753) = Fq(MNT6-753),
Fr(MNT6-753) = Fq(MNT4-753).
```

Практический смысл такой. Если арифметика MNT4 переносится в BN254, она становится non-native: каждый элемент MNT4-поля раскладывается на limb-ы и проверяется через большое число constraints. Если же следующий слой доказательства строится на парной MNT6-кривой, то скалярное поле одной стороны совпадает с базовым полем другой стороны. Это не устраняет все расходы автоматически, но убирает самую грубую причину взрыва constraints, характерную для BN254 non-native переноса.

## 2. Что реализовано в коде

Добавлен отдельный модуль:

```text
mnt_cycle_full/
```

В нем реализованы следующие части.

1. Проверка параметров MNT4/MNT6 цикла через `arkworks`.
2. Reference pairing для MNT4-753 через `ark-mnt4-753`.
3. Reference pairing для MNT6-753 через `ark-mnt6-753`.
4. Operation/constraint accounting для MNT4 relation fragments.
5. Operation/constraint accounting для MNT6 relation fragments.
6. Сравнение cycle-native модели с BN254 non-native переносом.

Ключевые файлы:

```text
mnt_cycle_full/src/lib.rs
mnt_cycle_full/src/main.rs
mnt_cycle_full/tests/cycle_reference.rs
mnt_cycle_full/constraints/README.md
mnt_cycle_full/rust/README.md
```

## 3. Что именно проверяют тесты

Тест `mnt4_mnt6_field_equalities_hold` проверяет два равенства полей:

```text
Fr(MNT4-753) = Fq(MNT6-753),
Fr(MNT6-753) = Fq(MNT4-753).
```

Это не текстовое утверждение из документации, а программная проверка модулей полей через `arkworks`.

Тест `both_reference_pairings_are_nontrivial_and_deterministic` строит pairing от стандартных генераторов на обеих кривых и проверяет, что результат детерминированный и не сводится к нулевой заглушке.

Тест `report_contains_both_cycle_sides_and_constraints` проверяет, что итоговый отчет содержит обе стороны цикла: MNT4 и MNT6, а также ненулевые оценки для relation fragments.

Тест `mnt6_relation_uses_cubic_and_sextic_tower_costs` проверяет, что MNT6-сторона учитывает другую башню расширений: `Fq -> Fq3 -> Fq6`, а не ошибочно копирует MNT4-башню `Fq -> Fq2 -> Fq4`.

## 4. Полученные численные результаты

Команда:

```bash
cd /Users/a.i.semenov/mnt4-pairing-final/mnt_cycle_full
cargo run --release --bin mnt_cycle_full_report
```

печатает отчет со следующими ключевыми числами.

| Проверка | Результат |
|---|---:|
| `Fr(MNT4-753) = Fq(MNT6-753)` | true |
| `Fr(MNT6-753) = Fq(MNT4-753)` | true |
| `Fq(MNT4)` | 753 bits |
| `Fr(MNT4)` | 753 bits |
| `Fq(MNT6)` | 753 bits |
| `Fr(MNT6)` | 753 bits |

Reference pairing digests:

| Сторона | Digest prefix |
|---|---|
| MNT4 pairing(generator, generator) | `0xb48d54ba312ea935...781f8aeda900` |
| MNT6 pairing(generator, generator) | `0x42234eb6ce9d5f8d...58ed80cddb00` |

Operation/constraint accounting:

| Сторона | Башня | Miller rounds | Addition steps | One transition | Miller relation | Line-cache relation | FE residue | Prepared relation |
|---|---|---:|---:|---:|---:|---:|---:|---:|
| MNT4 | `Fq2/Fq4` | 377 | 124 | 10 | 4,514 | 19,554 | 110 | 24,178 |
| MNT6 | `Fq3/Fq6` | 377 | 124 | 22 | 9,782 | 39,108 | 230 | 49,120 |

Сравнительные ориентиры:

| Сценарий | Constraints / operation count |
|---|---:|
| MNT4 cycle-native prepared relation | 24,178 |
| MNT6 cycle-native prepared relation, preliminary | 49,120 |
| BN254 non-native sparse Miller estimate | 63,309,128 |
| Sonobe/CycleFold-like decider reference anchor | 9,000,000 |

## 5. Как читать эти constraints

Числа `24,178` и `49,120` не являются стоимостью готового Ethereum-контракта. Это accounting для будущего MNT-cycle-native relation layer: сколько multiplication constraints потребуется, если соответствующие операции выражаются в родном поле MNT-цикла.

Именно это отличие важно для диплома. Перенос MNT4-арифметики в BN254 дает non-native стоимость порядка десятков миллионов constraints. Cycle-native слой показывает другую картину: базовое умножение в родном поле считается как один multiplication constraint, а башни расширений строятся из таких родных операций.

## 6. Газовые итоги

F6B не добавляет новый on-chain verifier и поэтому не имеет отдельной gas-метрики. Газовые значения для текущих EVM-реализаций остаются теми, которые измерены в F4/F5:

| Компонент | Gas |
|---|---:|
| Полное on-chain вычисление MNT4-сопряжения | 258,753,182 |
| Prepared sparse blob/code-shards, одно сопряжение | 79,586,596-79,588,799 |
| Article640 residue equation, code-shards | 93,685,247 |
| KZG opening over BN254 | 133,039 |
| Merkle opening, один путь | 1,093 |
| Merkle opening, 8 путей depth=16 | 46,402 |

Вывод по gas: F6B не утверждает, что появилась дешевая on-chain проверка MNT4/MNT6 pairing без folding. Он показывает, какой слой должен быть folding-слоем, чтобы уйти от прямого EVM-исполнения и от BN254 non-native взрыва constraints.

## 7. Что не реализовано в F6B

Не реализован полный CycleFold.

Не реализован production MNT4/MNT6 recursive prover.

Не реализован новый EVM verifier, который самостоятельно проверяет MNT-cycle-native proof.

Не реализована Solidity-арифметика MNT6 по аналогии с MNT4. Для F6B MNT6 используется как reference/relation сторона через Rust и arkworks.

Это сознательное ограничение. Этап нужен, чтобы закрыть предварительную часть: параметры цикла, reference pairing, relation fragments и constraints accounting.

## 8. Итог F6B

F6B закрывает пункт плана в переименованной и честной формулировке: реализован предварительный MNT4/MNT6 cycle-native слой. Он показывает, что дальнейшее развитие работы должно идти не через перенос всей MNT4-арифметики в BN254, а через MNT-cycle-native relation layer с последующим folding/recursive proof.
