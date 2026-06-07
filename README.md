# diploma-final

## Что реализовано

| Блок | Смысл |
|---|---|
| `arithmetic/mnt4_3limb/` | Общая 3-limb арифметика MNT4-753: Montgomery/CIOS, `Fq`, `Fq2`, `Fq4`, проверки точек и тесты алгоритмических вариантов. |
| `arithmetic/mnt6_3limb/` | Общая 3-limb арифметика MNT6-753: `Fp`, `Fq3`, `Fq6`, packed hot-path, primitives для ate-loop. |
| `arithmetic/lollipop305_2limb/` | Общая 2-limb арифметика lollipop-305: stick-field, cycle-field, packed `Fq2/Fq6` для сложного Ehat-контура. |
| `baselines/naive_tate_mnt4/` | Наивная Tate/cost-model точка отсчета без выбранных оптимизаций. |
| `implementations/full_onchain_mnt4/` | Полное on-chain вычисление MNT4-сопряжения и fixed-Q/prepared/code-shards baseline. |
| `implementations/article640_mnt4/` | MNT4-реализация идей ePrint 2024/640: calldata+commitment, fixed code-shards/EXTCODECOPY, KZG/Merkle opening layers. |
| `implementations/article640_mnt6/` | MNT6-753 verifier, построенный симметрично MNT4: prepared lines, общий accumulator, residue/c-свидетельство. |
| `implementations/lollipop305/` | Исследовательский lollipop-305 pipeline: stick + cycle-E + Ehat, fixed-shards режим и Rust-бэкенды. |
| `implementations/mnt4_merkle_fri_cost_model/` | Актуальная модель стоимости Merkle/FRI-проверки цикла Миллера без production-заявления. |
| `implementations/research_variants/` | Эксперименты, которые не являются основным путем. |
| `experiments/` | Независимые тесты идей Claude/ModExp для 3-limb умножения; используются только как исследовательские сравнения. |
| `mnt_cycle_full/` | Rust-модель MNT4/MNT6 cycle-native учета и constraints-accounting. |
| `docs/` | Отчеты, планы аудита, оценки сложности, материалы для защиты. |
| `scripts/` | Однокомандные проверки и gas-отчеты. |

Скрипты пишут логи в `.reports/` и печатают строки gas-report, если они есть в выводе.

Ключевой вывод: локальные EVM-оптимизации и residue-проверка уменьшают стоимость, но без precompile/proof-слоя нельзя одновременно получить малые gas и малые constraints для полного пути.
