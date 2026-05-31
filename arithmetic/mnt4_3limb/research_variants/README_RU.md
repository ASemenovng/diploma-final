# Исследовательские варианты арифметики MNT4-753

В этой директории собраны реализации, которые нужны для воспроизводимых сравнений алгоритмов, но не входят в чистовой путь вычисления сопряжения.

| Файл | Что сравнивается |
|---|---|
| `BigIntMNTBarrett.sol` | Barrett-редукция против выбранной Montgomery-редукции. |
| `BigIntMNTFIOS.sol` | FIOS против выбранной CIOS-схемы Montgomery-умножения. |
| `BigIntMNTComba.sol` | Product-scanning/Comba против развернутого CIOS hot path. |
| `BigIntMNTSquareComba.sol` | Специализированное Comba/SOS возведение в квадрат. |
| `BigIntMNTBranchless.sol` | Выбор по маске против условных ветвлений при редукции. |
| `BigIntMNTFinalSelect.sol` | Безветвительное финальное вычитание модуля. |
| `BigIntMNTSkipT0.sol` | Удаление лишних записей младшего слова внутри Montgomery-редукции. |
| `MNT4ExtensionAlgorithmVariants.sol` | Generic и специализированные операции в Fq2/Fq4, включая отложенную редукцию и умножение на разреженные линии. |

Тесты из `../test/` импортируют эти файлы напрямую. Production-код импортирует только `../src/BigIntMNT.sol` и `../src/MNT4Extension.sol`.
