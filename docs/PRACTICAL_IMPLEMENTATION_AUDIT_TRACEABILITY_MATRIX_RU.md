# Матрица трассируемости практической части

Матрица связывает защищаемые тезисы с кодом, тестами, метриками и
ограничениями. Статус «закрыто кодом» не означает production-готовность API:
ограничения указаны отдельно.

| Тезис | Реализация | Проверка | Метрика | Ограничение | Статус |
|---|---|---|---|---|---|
| Оптимизированная MNT4 3-limb арифметика | `arithmetic/mnt4_3limb` | `forge test -vv` | `Fq mul = 2 959 gas/op` | Для прямого EVM пути порядок стоимости сохраняется | Закрыто кодом |
| Оптимизированная MNT6 3-limb арифметика | `arithmetic/mnt6_3limb` | `forge test -vv` | `Fp mul = 2 314 gas/op`, `Fq6 mul = 166 774` | Streaming hot path еще можно улучшить | Закрыто кодом |
| Исследовательская 2-limb арифметика | `arithmetic/lollipop305_2limb` | `forge test -vv` | 22 теста пройдено | Не является production-кривой | Закрыто кодом |
| Полное on-chain MNT4-сопряжение непрактично | `implementations/full_onchain_mnt4` | `forge test -vv` и arkworks fixtures | `259 346 808 gas` | Reference baseline | Закрыто кодом |
| Prepared sparse lines снижают стоимость MNT4 | `implementations/article640_mnt4` | `forge test -vv` | code-shards digest `80 188 440 gas` | Fixed-Q конфигурация | Закрыто кодом |
| Residue-путь ePrint 2024/640 снижает FE overhead | `implementations/article640_mnt4` | `forge test -vv` | fixed-shards equation `93 705 233 gas` | Доверенная регистрация кэша | Закрыто для fixed-cache модели |
| Runtime-подмена fixed shards невозможна | `MNT4Article640FixedShardsVerifier.sol` | negative tests | shard-адреса хранятся в контракте | Развертыватель может зарегистрировать некорректный cache | Закрыто частично |
| Commitment связывает вызов с зарегистрированным blob | `MNT4Article640HotCommitmentVerifier.sol` | negative tests | calldata путь `130 756 045 gas` | Хеш не доказывает правильность генерации lines | Закрыто частично |
| MNT6 packed Miller и FE реализованы | `implementations/article640_mnt6` | `forge test -vv`, Rust fixture `cmp` | packed residue digest `103 294 551 gas` | Нет интегрированного bool pairing-equation fixed-shards verifier-а | Закрыто частично |
| Поля MNT4/MNT6 образуют цикл | `mnt_cycle_full` и arkworks | `cargo run --release --quiet` | Проверка field equalities | Модель constraints ручная | Закрыто кодом |
| MNT-cycle relation потенциально мала | `mnt_cycle_full` | accounting model | MNT4 `24 126`, MNT6 `48 942` multiplication constraints после исправления | Не compiled circuit; нельзя напрямую сравнивать с целым Sonobe decider | Требует исправления |
| Sonobe задает практический ориентир | официальный README Sonobe | внешняя сверка | около `9M constraints`, около `3 min` | Не apples-to-apples с relation-фрагментом | Закрыто как ориентир |
| KZG opening layer реализуем | `Article640KZGOpeningVerifier.sol` | Foundry test | около `151 826 test gas` | MNT4 non-native PCS требует constraints-heavy слой | Закрыто как эксперимент |
| Merkle opening layer реализуем | `Article640MerkleFriOpeningVerifier.sol` | Foundry test | depth-16 около `80 853 test gas` | Это не полный FRI verifier | Закрыто как эксперимент |
| Ordinary-FRI replacement не дает принципиального выигрыша | `implementations/mnt4_merkle_fri_cost_model` | `./scripts/run_cost_model.sh` | lower bound `51 359 352`, expected `78 340 624 gas` | Аналитическая модель, не production Solidity | Закрыто аналитически |
| DEEP-FRI микротрасса воспроизводимо исполняется | `implementations/research_variants/mnt4_merkle_deep_fri_microtrace` | `./scripts/run_report.sh` | 32q `83 962 252`, 128q `640 161 168 gas` | Нет numerical soundness closure; runtime > EIP-170 | Архивный отрицательный эксперимент |
| lollipop-305 уменьшает цену базовой арифметики | `implementations/lollipop305` | Foundry и Rust fixtures | Stick residue `12 675 796`, Cycle E residue `26 320 346` test-call gas | Исследовательские параметры безопасности | Закрыто как прототип |
| Полный дешевый lollipop pipeline не получен | `implementations/lollipop305` | gas tests | combined fixed-shards `133 756 330 gas` | Ehat остается дорогой | Закрыто как отрицательный результат |
| Naive Tate дает исходный порядок стоимости | `baselines/naive_tate_mnt4` | Foundry tests | фрагменты и экстраполяция | Не полный Tate pairing | Требует уточнения формулировки |
| Проект воспроизводим одной командой | `scripts/run_all.sh` | ручной запуск | exit code `0` | FRI cost model и fixture `cmp` не включены | Закрыто частично |

## Обязательные правки матрицы после исправлений

1. Пересчитать MNT-cycle строки после изменения счетчиков в коде.
2. Добавить MNT6 fixed-shards bool-verifier и его отрицательные тесты.
3. Добавить проверки входных точек или явно закрепить внешнюю предпосылку.
4. Добавить автоматическую fixture-регенерацию и FRI cost model в audit-скрипт.
