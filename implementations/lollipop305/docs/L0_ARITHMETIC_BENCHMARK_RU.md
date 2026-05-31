# Stage L0: lollipop-305 arithmetic benchmark

## 1. Цель

Цель этапа L0 -- проверить, дает ли 305-битное поле из примера lollipop-305-158 статьи ePrint 2024/1627 практический выигрыш в EVM по сравнению с текущей MNT4-753 арифметикой.

На этом этапе проверяется только арифметический слой:

- базовое поле `Fp`;
- расширение `Fp2`;
- расширение `Fp4`;
- альтернативные алгоритмы умножения и редукции;
- стоимость базовых операций в gas;
- корректность операций на ручных тестах, Rust reference и fuzz-тестах.

Полный Miller loop и verifier на этом этапе не реализуются. L0 отвечает на более ранний вопрос: есть ли у меньшего поля достаточно сильное преимущество, чтобы вообще рассматривать полный verifier.

## 2. Параметры поля

Использован пример lollipop-305-158 из ePrint 2024/1627. Для параметра

```text
x = 8004046504391788107635887004283725454478544674
```

поле задается простым числом

```text
p = x^2 - x + 1
  = 64064760444466402482617092084437280876782408929523650941985296571943203113725143542535221603.
```

Размер `p` равен 305 битам, поэтому элемент поля помещается в два 256-битных слова EVM. Для сравнения, MNT4-753 требует три 256-битных слова.

Разложение `p` на little-endian limbs:

```text
p[0] = 0x24240b65671ab020b2f03c6035ed8fdcdd1ff464dbb7022f6583adbbb2fef163
p[1] = 0x1f733286263df
```

## 3. Реализованные компоненты

Код находится в директории:

```text
/Users/a.i.semenov/mnt4-pairing-final/lollipop305_research
```

Основные файлы:

| Файл | Назначение |
|---|---|
| `src/BigIntLollipop305.sol` | основной 2-limb Montgomery/CIOS `Fp` hot path |
| `src/BigIntLollipop305Variants.sol` | экспериментальные варианты CIOS/FIOS/Comba/Barrett для сравнения |
| `src/Lollipop305Extension.sol` | baseline `Fp2/Fp4` через structs и memory |
| `src/Lollipop305ExtensionStack.sol` | оптимизированные stack/packed `Fp2/Fp4` hot path |
| `test/Lollipop305Arithmetic.t.sol` | Foundry correctness/fuzz tests и gas-бенчмарки |
| `rust_reference/src/lib.rs` | Rust reference на `num-bigint` |

## 4. Оптимизации

### 4.1 Двухсловное Montgomery-представление

Для умножения используется Montgomery-представление. Если `R = 2^512`, то число `a` хранится как

```text
a_M = aR mod p.
```

Умножение двух Montgomery-значений вычисляет

```text
a_M * b_M * R^{-1} = abR mod p,
```

то есть результат остается в Montgomery-представлении.

### 4.2 CIOS Montgomery reduction

Основной путь `BigIntLollipop305.montMul2` реализует 2-limb CIOS. Это лучший найденный вариант для `Fp.mul`: он не материализует полный массив произведения в memory и выполняет редукцию по ходу умножения.

Для сравнения реализованы:

- `Comba/SOS`: сначала строит полное произведение, затем делает Montgomery REDC;
- `FIOS`: интегрирует умножение и редукцию в другой форме, но использует memory-массивы;
- `Barrett`: работает в canonical representation и использует предвычисленное `mu = floor(2^1024 / p)`.

По gas все три варианта проиграли unrolled CIOS.

### 4.3 Специализированное возведение в квадрат

В первой версии `montSqr2(a)` просто вызывал `montMul2(a,a)`. В оптимизированной версии добавлен специализированный square path: общий cross-product `a0*a1` вычисляется один раз и переиспользуется. Это снижает стоимость `Fp.square` сначала снизился примерно с `~2,069 gas/op` до `~1,926 gas/op`, а после F2-аудита и учета малого high-limb -- до `~940 gas/op`.

### 4.4 Stack/packed API для расширений

Baseline `Fp2/Fp4` использовал nested structs и `uint256[2] memory`. Это удобно, но дорого. Для hot path добавлен `Lollipop305ExtensionStack`, где `Fp2`-операции работают напрямую с limbs:

```text
(a00, a01, a10, a11)
```

Для `Fp4.mul` дополнительно добавлен `benchFp4MulFullStack`, где основной цикл держит limbs в локальных переменных и не создает nested `Fp4` struct на каждой итерации.

### 4.5 Karatsuba и дешевое умножение на non-residue

Для `Fp2` используется башня

```text
Fp2 = Fp[u] / (u^2 + 1),       u^2 = -1.
```

Умножение в `Fp2` выполняется за три умножения в `Fp`:

```text
v0 = a0 b0,
v1 = a1 b1,
v2 = (a0+a1)(b0+b1),
c0 = v0 - v1,
c1 = v2 - v0 - v1.
```

Для `Fp4` используется

```text
Fp4 = Fp2[v] / (v^2 - (1+u)),      v^2 = 1+u.
```

Умножение на `u` и на `1+u` в `Fp2` почти бесплатно:

```text
u(a0+a1u) = -a1 + a0u.
(1+u)(a0+a1u) = (a0-a1) + (a0+a1)u.
```


### 4.6 Оптимизация малого старшего limb после F2-аудита

В F2-аудите была учтена особенность lollipop-305: старший limb модуля имеет размер меньше 49 бит. Поэтому для любых корректно редуцированных элементов `a1` и `b1` также меньше `2^49`, а произведение

```text
a1 * b1 < 2^98
```

помещается в младшее EVM-слово и не требует восстановления старших 256 бит через `mulmod`. В `montMul2` это позволяет заменить одно 512-битное произведение `mul512(a1,b1)` на обычный `mul`. В `montSqr2` аналогично заменяется `mul512(a1,a1)`. Также в блоках Montgomery-редукции `m*p0` не сохраняется новый `t0`, потому что этот limb сразу сдвигается из CIOS-аккумулятора; нужен только carry.

Эта оптимизация оказалась главным улучшением F2: `Fp.mul` снизился примерно с `2081` до `1018 gas/op`, а `Fp.square` -- примерно с `1926` до `940 gas/op`.

## 5. Проверка корректности

Команды:

```bash
cd /Users/a.i.semenov/mnt4-pairing-final/lollipop305_research/rust_reference
cargo test

cd /Users/a.i.semenov/mnt4-pairing-final/lollipop305_research
forge test --match-path test/Lollipop305Arithmetic.t.sol -vv
```

Результат последней проверки:

```text
Rust reference: 3 passed
Foundry: 10 passed
```

Проверяется:

- что `p = x^2 - x + 1` и имеет 305 бит;
- Montgomery round-trip;
- умножение около модуля: `(p-2)(p-3)=6 mod p`;
- ручные векторы для `Fp2` и `Fp4`;
- корректность CIOS, Comba, FIOS и Barrett на базовых векторах;
- fuzz распределительности в `Fp`;
- fuzz ассоциативности умножения в `Fp2`;
- fuzz равенства `Fp4.square(a)` и `Fp4.mul(a,a)`.

Важная деталь: fuzz-тесты нашли ошибку в ранней версии carry propagation для `montMul2`. После исправления carry учитывается при каждом сложении high-limb и low-limb carry.

## 6. Gas-результаты lollipop-305

Команда:

```bash
cd /Users/a.i.semenov/mnt4-pairing-final/lollipop305_research
forge test --match-path test/Lollipop305Arithmetic.t.sol --gas-report -vv
```

Финальные результаты:

| Операция | Реализация | Total gas | Повторов | Gas/op |
|---|---|---:|---:|---:|
| `Fp.mul` | Montgomery/CIOS + small-high optimization, selected | 521,240 | 512 | 1,018 |
| `Fp.square` | specialized square + small-high optimization, selected | 481,113 | 512 | 940 |
| `Fp.mul` | Comba/SOS | 3,983,382 | 512 | 7,780 |
| `Fp.mul` | FIOS | 3,467,554 | 512 | 6,773 |
| `Fp.mul` | Barrett | 7,095,327 | 512 | 13,858 |
| `Fp2.mul` | struct/memory baseline | 765,543 | 128 | 5,981 |
| `Fp2.mul` | stack, selected | 533,920 | 128 | 4,171 |
| `Fp2.square` | struct/memory baseline | 558,148 | 128 | 4,361 |
| `Fp2.square` | stack, selected | 416,468 | 128 | 3,254 |
| `Fp4.mul` | struct/memory baseline | 3,791,941 | 128 | 29,625 |
| `Fp4.mul` | packed array | 2,143,816 | 128 | 16,749 |
| `Fp4.mul` | full-stack, selected | 1,912,589 | 128 | 14,942 |
| `Fp4.square` | struct/memory baseline | 2,734,481 | 128 | 21,363 |
| `Fp4.square` | stack, selected | 1,690,986 | 128 | 13,211 |

## 7. Сравнение с MNT4-753

Сравнение проводится с текущей оптимизированной MNT4-753 реализацией из `onchain_full`.

| Операция | lollipop-305 selected gas/op | MNT4-753 gas/op | Выигрыш |
|---|---:|---:|---:|
| `Fp.mul` | 1,018 | 2,959 | 2.91x |
| `Fp.square` | 940 | 2,947 | 3.14x |
| `Fp2.mul` | 4,171 | 11,877 | 2.85x |
| `Fp2.square` | 3,254 | 10,592 | 3.26x |
| `Fp4.mul` | 14,942 | 42,764 | 2.86x |
| `Fp4.square` | 13,211 | 36,606 | 2.77x |

MNT4-753 числа берутся из существующих gas-benchmarks:

```bash
cd /Users/a.i.semenov/mnt4-pairing-final/onchain_full
forge test --match-path test/BigIntMNTFinal.t.sol --gas-report -vv
forge test --match-path test/MNT4ExtensionV3Final.t.sol --gas-report -vv
```

## 8. Вывод L0

После оптимизаций lollipop-305 показывает устойчивый выигрыш относительно MNT4-753 примерно `2.8x-3.3x` на основных операциях `Fp/Fp2/Fp4`.

Самый важный результат: выигрыш стал виден не только на базовом поле, но и в расширениях; после F2-аудита он стал существенно сильнее за счет учета малого high-limb в 305-битном поле. Это произошло после отказа от nested `memory`-структур в hot path. До первых stack-оптимизаций `Fp4.mul` выигрывал у MNT4-753 только примерно `1.2x`; после full-stack варианта и F2 small-high оптимизации выигрыш стал примерно `2.86x`.

Но это все еще не радикальное снижение на порядок. Поэтому lollipop-направление имеет смысл как исследовательский прототип для проверки гипотезы о меньшем поле, но не доказывает автоматически, что полный Miller/residue verifier станет дешевле 60 млн gas. Для следующего этапа нужно отдельно оценить:

- длину Miller loop;
- embedding degree и реальную башню расширений;
- количество `Fp4` или более высоких extension-field операций;
- размер witness/cache;
- криптографическую стойкость выбранного lollipop-параметра.

Текущий лучший арифметический слой для дальнейших экспериментов:

- `Fp.mul`: unrolled Montgomery/CIOS;
- `Fp.square`: specialized square;
- `Fp2.mul/square`: stack API;
- `Fp4.mul`: full-stack API;
- `Fp4.square`: stack API;
- Barrett/FIOS/Comba не использовать в production path, оставить только как отрицательные сравнения.
