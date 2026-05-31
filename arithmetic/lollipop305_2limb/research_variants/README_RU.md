# Исследовательские варианты 2-limb арифметики lollipop-305

В этой директории оставлены варианты, использованные при выборе минимальной стоимости 2-limb арифметики. Они воспроизводят сравнение, но не подключаются к чистовому lollipop-проверяющему контракту.

| Файл | Что сравнивается |
|---|---|
| `BigIntLollipop305Variants.sol` | Базовые варианты Comba и branchless-редукции. |
| `BigIntLollipop305FinalSelect.sol` | Безветвительное финальное вычитание модуля. |
| `BigIntLollipop305SkipT0.sol` | Удаление лишних записей t0. |
| `BigIntLollipop305SmallHigh.sol` | Использование малого размера старшего слова. |
| `BigIntLollipop305SmallHighSkipT0.sol` | Совместное применение двух предыдущих приемов. |
| `Lollipop305Extension.sol` | Структурная эталонная арифметика расширений для сравнения со stack API. |

Чистовой путь находится в `../src/BigIntLollipop305.sol`, `../src/BigIntLollipop305Q.sol`, `../src/Lollipop305ExtensionStack.sol` и `../src/Lollipop305QExtensionStack.sol`.
