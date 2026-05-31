# Этап L2: параметры lollipop-305, Rust backend и выбранная Solidity/Yul арифметика

## 1. Назначение этапа

Этот этап фиксирует первую рабочую основу для дальнейшей реализации verifier на `lollipop-305-158` из статьи ePrint 2024/1627. Цель не в том, чтобы уже реализовать полный Miller/residue verifier, а в том, чтобы закрыть три подготовительных пункта:

1. зафиксировать математические параметры кривых и полей;
2. добавить Rust backend, который работает с теми же параметрами и может генерировать воспроизводимые JSON-фикстуры;
3. выбрать оптимальную Solidity/Yul арифметику для базового поля и расширений `Fp2/Fp4`.

## 2. Источник параметров

Источник истины по параметрам -- исходный Magma/GP-скрипт авторов статьи:

- `/tmp/lollipops/lollipops-magma/lollipop-305-158.m`;
- `/tmp/lollipops/lollipops-gp/lollipop-305-158.gp`;
- ePrint 2024/1627, Appendix A, Example 1.

Используется параметр

```text
x = 8004046504391788107635887004283725454478544674.
```

Из него получаются два 305-битных простых числа:

```text
p = x^2 - x + 1
q = x^2 + 1
```

В десятичном виде:

```text
p = 64064760444466402482617092084437280876782408929523650941985296571943203113725143542535221603
q = 64064760444466402482617092084437280876782408937527697446377084679579090118008868997013766277
```

В hex-формате для Solidity/Yul:

```text
p = 0x1f733286263df24240b65671ab020b2f03c6035ed8fdcdd1ff464dbb7022f6583adbbb2fef163
q = 0x1f733286263df24240b65671ab020b2f03c60375479cf7ce39138369e001f5dad2ea32fdd0085
```

Порядок подгруппы для ordinary stick-curve:

```text
r = 265533234376483119496574875659819072867998144101
  = 0x2e82ec0a69ae4cbe3c0534b5a52c85491f7c9665
```

Проверенные отношения:

```text
bitlen(p) = 305
bitlen(q) = 305
bitlen(r) = 158
p^4 = 1 mod r
p^1 != 1 mod r
p^2 != 1 mod r
```

Последние три равенства фиксируют embedding degree `4` для stick-curve относительно `r`.

## 3. Какие кривые разделяются в реализации

В статье есть несколько объектов, которые нельзя смешивать.

| Объект | Поле | Уравнение | Роль |
|---|---|---|---|
| `Ecal` | `Fp2` | `y^2 = x^3 + (mu + 1)x`, `mu^2 + 1 = 0` | часть supersingular 2-cycle |
| `Ecalhat` | `Fq3` / в тексте также используется форма над `Fq2` | `y^2 = x^3 + (eta + 2)` | вторая часть cycle |
| `E` | `Fp` | `y^2 = x^3 + a x + b` | ordinary stick-curve, pairing-friendly относительно `r` |

Для текущего исследовательского verifier нас интересует stick-curve `E/Fp`, потому что именно для нее в скрипте задан 158-битный `r` и embedding degree `4`.

Параметры stick-curve:

```text
a = 11875228336988574493882712067711066361723405878662955689469453989104183434229646197784790728
b = 44530775641606776770556944911003809865281631340093296710155954546346967839351469608314023792
E/Fp: y^2 = x^3 + a*x + b
```

## 4. Башня расширений для вычислений

Для gas-исследования и будущего verifier используется башня:

```text
Fp2 = Fp[u] / (u^2 + 1), то есть u^2 = -1.
Fp4 = Fp2[v] / (v^2 - (1+u)), то есть v^2 = 1+u.
```

Именно эта башня реализована в Solidity/Yul и Rust. Важно, что для параметров lollipop-305 элемент `u` является квадратом в `Fp2`, поэтому башня `v^2=u` не задает квадратичное расширение. В реализации используется `xi=1+u`, первый малый детерминированный неквадрат в `Fp2`. Эта башня удобна для `k=4`, потому что результат сопряжения живет в мультипликативной подгруппе расширенного поля `Fp4`.

## 5. Rust backend

Добавлен crate:

```text
/Users/a.i.semenov/mnt4-pairing-final/lollipop305_research/rust_backend
```

Он содержит:

| Файл | Назначение |
|---|---|
| `src/params.rs` | точные параметры `x,p,q,r,rhat,a,b`, проверки базовых соотношений |
| `src/field.rs` | reference-арифметика `Fp`, `Fp2`, `Fp4` над `BigUint` |
| `src/curve.rs` | проверка точки на ordinary stick-curve `E/Fp` |
| `src/fixture.rs` | JSON-фикстура параметров и smoke-point |
| `src/bin/lollipop305_backend_info.rs` | печать JSON-фикстуры backend-а |
| `tests/backend_contract.rs` | тесты параметров, башни полей и curve equation |

Важно: этот backend пока не строит полный witness для Miller loop. Это подготовительный production-layout: параметры, поля, кривая и сериализуемые фикстуры уже вынесены в Rust, чтобы следующие этапы не зависели от Solidity oracle.

Запуск:

```bash
cd /Users/a.i.semenov/mnt4-pairing-final/lollipop305_research/rust_backend
cargo test
cargo run --bin lollipop305_backend_info
```

## 6. Solidity/Yul арифметика

Арифметика лежит в:

```text
/Users/a.i.semenov/mnt4-pairing-final/lollipop305_research/src
```

Основные файлы:

| Файл | Что реализует |
|---|---|
| `BigIntLollipop305.sol` | выбранная 2-limb Montgomery/CIOS арифметика в `Fp` |
| `BigIntLollipop305Variants.sol` | экспериментальные Comba/SOS, FIOS и Barrett варианты для сравнения |
| `Lollipop305Extension.sol` | baseline `Fp2/Fp4` через structs/memory |
| `Lollipop305ExtensionStack.sol` | выбранная stack-oriented hot-path арифметика `Fp2/Fp4` |

Выбранный вариант:

```text
Fp: 2-limb Montgomery CIOS + специализированное square.
Fp2/Fp4: Karatsuba formulas + cheap non-residue multiplication + stack/pseudo-register API.
```

Почему выбран именно он:

- Barrett оказался существенно дороже Montgomery;
- FIOS/Comba в текущей EVM-модели дороже специализированного CIOS;
- memory/struct API в расширениях дороже stack-oriented API;
- `Fp4.mul` через полностью stack-oriented helper дешевле промежуточных array/memory вариантов.

## 7. Актуальные gas-результаты

Последний проверенный запуск:

```bash
cd /Users/a.i.semenov/mnt4-pairing-final/lollipop305_research
forge test --match-path test/Lollipop305Arithmetic.t.sol --gas-report -vv
```

| Операция | Выбранный вариант, gas/op | Альтернативы |
|---|---:|---|
| `Fp.mul` | 2,081 | Comba 7,781; FIOS 6,774; Barrett 13,861 |
| `Fp.square` | 1,926 | generic mul был дороже до специализации |
| `Fp2.mul` | 7,361 | memory baseline 9,173 |
| `Fp2.square` | 6,289 | memory baseline 7,398 |
| `Fp4.mul` | 24,243 | memory baseline 37,242; array stack 25,809 |
| `Fp4.square` | 22,028 | memory baseline 28,909 |

По сравнению с текущей MNT4-753 арифметикой это дает примерно `1.5x-1.8x` выигрыш на базовых операциях в расширенных полях. Это не делает verifier автоматически дешевым: итоговая стоимость все еще определяется числом шагов Miller loop и способом проверки финальной экспоненты. Но Stage L2 закрывает базу для реализации следующего этапа без заведомо неэффективной арифметики.

## 8. Статус готовности первых трех шагов

| Шаг | Статус |
|---|---|
| Математические параметры lollipop-305 | Готово: параметры взяты из Magma/GP-скрипта и проверены тестами |
| Rust backend | Готово как parameter/field/curve backend; Miller witness generation будет следующим этапом |
| Оптимальная Solidity/Yul арифметика | Готово для `Fp/Fp2/Fp4`; выбранный вариант подтвержден gas-сравнением |
