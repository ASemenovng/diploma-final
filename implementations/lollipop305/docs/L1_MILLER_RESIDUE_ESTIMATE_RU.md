# Stage L1: оценка полного Miller/residue verifier для lollipop-305

## 1. Цель оценки

Цель этого документа -- оценить, имеет ли смысл реализовывать для lollipop-305 аналог `article640_mnt4_verifier`: контракт, который проверяет pairing-equation через прямой on-chain Miller loop по prepared/sparse lines и использует residue-подход для финальной экспоненты по ePrint 2024/640.

Это пока оценка, а не реализация полного verifier. Она использует:

- измеренную арифметику lollipop-305 из Stage L0;
- измеренные gas-результаты MNT4-753 из `article640_mnt4_verifier`;
- параметры lollipop-305-158 из ePrint 2024/1627.

## 2. Исходные факты

### 2.1 MNT4-753 direct-hot baseline

Из `article640_mnt4_verifier/docs/ARTICLE640_STAGE_A_DIRECT_RESIDUE_RESULTS.md`:

| Режим | Gas |
|---|---:|
| Two-pair Miller core, sparse blobs | 87,747,219 |
| Two-pair equation + полная FE | 115,997,313 |
| Two-pair equation + embedded residue FE | 93,879,746 |

Отсюда:

```text
MNT4 FE direct overhead = 115,997,313 - 87,747,219
                       = 28,250,094 gas.

MNT4 residue overhead = 93,879,746 - 87,747,219
                     = 6,132,527 gas.
```

### 2.2 Lollipop-305 арифметика

Из Stage L0:

| Операция | lollipop-305 gas/op | MNT4-753 gas/op | Отношение |
|---|---:|---:|---:|
| `Fp4.mul` | 14,942 | 42,764 | 0.349 |
| `Fp4.square` | 13,211 | 36,606 | 0.361 |

Для Miller accumulator грубое среднее отношение стоимости одного шага:

```text
rho_step = (Fp4S_lolli + Fp4M_lolli) / (Fp4S_mnt + Fp4M_mnt)
         = (13,211 + 14,942) / (36,606 + 42,764)
         = 28,153 / 79,370
         ≈ 0.355.
```

### 2.3 Длина Miller loop

Для MNT4-753 в текущих оценках используется около `376` doubling-раундов.

Для lollipop-305-158 из ePrint 2024/1627 используется stick curve `E305/Fp` с embedding degree `4` относительно 158-битного простого `r`. Поэтому прямой Tate/ate-style loop имеет порядок примерно:

```text
L_lolli ≈ bitlen(r) - 1 ≈ 157.
```

Точное число addition-шагов зависит от выбранной signed/NAF-записи loop parameter. Для предварительной оценки достаточно масштабировать по длине loop; это дает консервативный порядок величины.

## 3. Оценка Miller core

Берем MNT4 direct-hot core:

```text
G_core_mnt = 87,747,219 gas.
```

Масштабируем по длине loop и стоимости `Fp4` операций:

```text
G_core_lolli ≈ G_core_mnt * (L_lolli / L_mnt) * rho_step
             ≈ 87,747,219 * (157 / 376) * 0.355
             ≈ 13,030,000 gas.
```

С учетом line evaluation, calldata, дополнительных сложений и неопределенности signed representation разумный диапазон:

```text
Miller core lollipop-305 ≈ 13M - 18M gas.
```

Это существенно ниже MNT4-753 `87.7M`, но не на порядок. Главные причины снижения:

1. 305-битное поле использует 2 limbs вместо 3.
2. `r` имеет 158 бит, а не сотни бит.
3. `Fp4.mul/square` стали дешевле примерно в `2.8x`.

## 4. Финальная экспонента: прямой путь

Для embedding degree `k=4` финальная экспонента имеет вид:

```text
H = (p^4 - 1) / r.
```

Обычно она раскладывается на easy part и hard part:

```text
p^4 - 1 = (p^2 - 1)(p^2 + 1).
```

Easy part использует Frobenius/conjugation и относительно дешевле. Hard part примерно соответствует степени:

```text
H_hard = (p^2 + 1) / r.
```

Для lollipop-305:

```text
bitlen(H_hard) ≈ 2*305 - 158 = 452 bits.
```

Для MNT4-753 в текущей формальной модели доминирующий hard exponent имеет около `377` бит. Тогда грубая оценка прямой FE для lollipop:

```text
G_FE_direct_lolli ≈ G_FE_direct_mnt * (452 / 377) * rho_step
                  ≈ 28,250,094 * 1.199 * 0.583
                  ≈ 19,750,000 gas.
```

Разумный диапазон:

```text
Direct FE lollipop-305 ≈ 18M - 23M gas.
```

Тогда полный direct verifier без residue:

```text
G_full_direct_lolli ≈ G_core_lolli + G_FE_direct_lolli
                    ≈ 21M + 20M
                    ≈ 41M gas.
```

С учетом неопределенности:

```text
Full direct lollipop-305 ≈ 38M - 48M gas.
```

## 5. Финальная экспонента: residue-путь из ePrint 2024/640

Идея статьи ePrint 2024/640: вместо полной финальной экспоненты проверять, что Miller output принадлежит нужному классу через residue witness. Для BN-кривых это дает большой выигрыш, потому что exponent для residue check существенно короче, а Frobenius-структура позволяет встроить проверку в Miller loop.

Для MNT4-753 этот выигрыш оказался ограниченным: direct hard exponent и оптимизированный residue-путь оба сводились к примерно 377-битному возведению в `Fq4`, поэтому экономия была только относительно полной hot equation, а не радикальной.

Для lollipop-305 ситуация лучше. Здесь `r` имеет 158 бит. Наивный residue exponent `c^r` имеет длину около:

```text
bitlen(r) = 158.
```

По сравнению с прямым hard exponent:

```text
452 / 158 ≈ 2.86.
```

То есть residue-проверка потенциально заменяет ~452-битную hard часть на ~158-битное возведение. Оценка:

```text
G_FE_residue_lolli ≈ G_FE_direct_mnt * (158 / 377) * rho_step
                   ≈ 28,250,094 * 0.419 * 0.583
                   ≈ 6,900,000 gas.
```

С учетом дополнительных операций `c`, `c^{-1}`, Frobenius-tail и упаковки witness:

```text
Residue FE lollipop-305 ≈ 7M - 10M gas.
```

Тогда полный verifier с direct Miller loop и residue FE:

```text
G_residue_lolli ≈ G_core_lolli + G_FE_residue_lolli
                ≈ 21M + 7M
                ≈ 28M gas.
```

С учетом неопределенности:

```text
Full residue lollipop-305 ≈ 28M - 35M gas.
```

## 6. Сводная оценка

| Режим | MNT4-753 measured | lollipop-305 estimate |
|---|---:|---:|
| Miller core | 87.7M | 20M - 25M |
| Miller + direct FE | 116.0M | 38M - 48M |
| Miller + residue FE | 93.9M | 28M - 35M |

## 7. Насколько полезна оптимизация финальной экспоненты именно здесь

Для MNT4-753:

```text
Экономия = 115,997,313 - 93,879,746 = 22,117,567 gas.
Относительно full equation: около 19%.
```

Но основная стоимость оставалась в Miller core:

```text
Miller core = 87,747,219 gas.
```

Для lollipop-305 ожидается:

```text
Direct FE ≈ 18M - 23M gas.
Residue FE ≈ 7M - 10M gas.
Экономия ≈ 10M - 15M gas.
```

Относительно полного lollipop direct verifier это может быть около `25%-35%` экономии. То есть для lollipop-305 оптимизация FE из ePrint 2024/640 должна быть более заметной, чем для MNT4-753, потому что `r` здесь всего 158 бит.

## 8. Главный вывод

Реализовывать lollipop-305 Miller/residue verifier осмысленно как исследовательский прототип.

Причины:

1. Оценка direct residue verifier находится в диапазоне `28M-35M gas`, то есть ниже целевого барьера `60M`.
2. Оптимизация финальной экспоненты из ePrint 2024/640 здесь должна быть полезнее, чем на MNT4-753.
3. Уже измеренная 2-limb арифметика дает устойчивый выигрыш `1.5x-1.8x` на `Fp/Fp2/Fp4`.

Но это не production-кандидат:

1. По ePrint 2024/1627 lollipop-305-158 имеет security около `77-88` бит по DLP-оценкам.
2. Для production-уровня нужно смотреть более крупные lollipop-кандидаты, например `lollipop-956-451`, но там поле уже значительно больше, и gas-выигрыш может исчезнуть.
3. Для окончательного вывода нужна реализация реального Miller loop для конкретной кривой, потому что line formulas, signed loop representation и calldata layout могут сдвинуть оценку на миллионы gas.

## 9. Рекомендация

Следующий этап имеет смысл только как controlled research prototype:

1. Реализовать lollipop-305 curve operations и prepared sparse line format.
2. Реализовать two-pair equation API:

```text
e(P,Q) * e(-R,S) = 1
```

3. Сначала снять gas для `Miller core` без FE.
4. Затем добавить direct FE.
5. Затем добавить residue FE по ePrint 2024/640.
6. Сравнить три числа:

```text
Miller core
Miller + direct FE
Miller + residue FE
```

Если `Miller + residue FE` получится близко к `30M-40M gas`, направление подтверждено как полезный исследовательский результат. Если окажется выше `60M`, значит даже малое поле не спасает direct on-chain verifier, и нужно возвращаться к polynomial/opening proof для Miller loop.
