// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {MNT4Article640SameQHotVerifier} from "./MNT4Article640SameQHotVerifier.sol";

/// @notice Режим A: прямой оптимизированный проверяющий контракт уравнения сопряжений в эксперименте Article640.
/// @dev Контракт задает короткое итоговое имя режима. Реализация наследуется от fixed-Q/parametric-S
///      пути с разреженными линиями и указательной Yul-арифметикой MNT4.
contract MNT4Article640DirectHotVerifier is MNT4Article640SameQHotVerifier {}
