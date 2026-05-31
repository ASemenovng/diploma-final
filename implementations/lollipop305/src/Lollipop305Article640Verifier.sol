// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Lollipop305ExtensionStack} from "@arith-lollipop305/Lollipop305ExtensionStack.sol";
import {Lollipop305QExtensionStack} from "@arith-lollipop305/Lollipop305QExtensionStack.sol";
import {BigIntLollipop305Q} from "@arith-lollipop305/BigIntLollipop305Q.sol";

/// @notice Исследовательский аналог прямой Article640-проверки для семейства lollipop-305.
/// @dev Проверяющий контракт получает blob подготовленных значений линий, сформированный Rust-бэкендом.
///      Каждый шаг кодируется 32-байтовым флагом операции и одним элементом Fp4 в Montgomery-представлении.
///      Флаг 1 обозначает шаг удвоения: перед умножением аккумулятор возводится в квадрат.
///      Флаг 0 обозначает шаг сложения или вычитания: выполняется только умножение.
///      Коэффициенты c0.c0, c0.c1, c1.c0, c1.c1 содержат по два 256-битных слова базового поля.
contract Lollipop305Article640Verifier {
    /// @dev Константа `ONE_0` содержит соответствующее слово единицы в Montgomery-представлении.
    uint256 private constant ONE_0 = 0x47c0feefd2462a8fbf0a7174e0063fe127209905ad078b245ebadaea25a15849;
    /// @dev Константа `ONE_1` содержит соответствующее слово единицы в Montgomery-представлении.
    uint256 private constant ONE_1 = 0x886a0c3b4715;

    /// @dev Порядок r подгруппы stick-кривой; используется как экспонента в сокращенной проверке F=c^r.
    bytes private constant R_EXP = hex"2e82ec0a69ae4cbe3c0534b5a52c85491f7c9665";
    /// @dev Характеристика p поля stick-кривой; используется в Ehat-отношении c^p * F_den = F_num.
    bytes private constant P_EXP = hex"01f733286263df24240b65671ab020b2f03c6035ed8fdcdd1ff464dbb7022f6583adbbb2fef163";
    /// @dev Характеристика q второго поля lollipop-цикла; используется в соответствующей сокращенной проверке.
    bytes private constant Q_EXP = hex"01f733286263df24240b65671ab020b2f03c60375479cf7ce39138369e001f5dad2ea32fdd0085";
    /// @dev Полная финальная экспонента stick-кривой; оставлена для контрольного сравнения с сокращенным путем.
    bytes private constant FINAL_EXP =
        hex"522a07a0c3fc3751d314990c442fa002e44a4ca22ad81797b8de0ef7eca9c4f4c8f187fbd0747e43da2a95b80f955d1436e995d388f24c1cac8eac1b01f4a14b9a6190d66f4d4d677921e51e24970b9be0311ef0d9412f6ebffb0a1df861efa08058678cc9b8ac39a3b99d167b78930256fd6e3a3d88c7070287d6aca639aad8984624c490";
    /// @dev Полная финальная экспонента cycle-E кривой; оставлена для контрольного измерения.
    bytes private constant CYCLE_E_FINAL_EXP =
        hex"079833e3673807c0fd3a911f2e100c70280d423d1ac90013be53ee6bde8c8de224a0fd73deb629593126551346b01638b2e6a146d29210dfc45c225eb12415105cdf5f983fa7b72a3078b949b5975b72dcb24b73ce8a33fbdbaee65f4f4bd4db676758e36223d025615e206ddddba196d9ba90";
    /// @dev Константа `Q_ONE_0` задает слово модуля поля или связанный параметр редукции.
    uint256 private constant Q_ONE_0 = 0xe25e15ccfe1247767aae8fd54d577a0c5adb625a90b8bb435152c85cb41618bf;
    /// @dev Константа `Q_ONE_1` задает слово модуля поля или связанный параметр редукции.
    uint256 private constant Q_ONE_1 = 0x709ec77952c4;

    /// @notice Повторяет цикл Миллера по подготовленным линиям и сравнивает аккумулятор с ожидаемым Fp4.
    function verifyMillerCore(bytes memory preparedLines, uint256[8] memory expectedCore) external pure returns (bool) {
        uint256[8] memory f = _millerCore(preparedLines);
        return _eq(f, expectedCore);
    }

    /// @notice Выполняет stick-цикл Миллера и затем полную финальную экспоненту; это контрольный дорогой путь.
    function verifyDirectFinalExponent(bytes memory preparedLines) external pure returns (bool) {
        uint256[8] memory f = _millerCore(preparedLines);
        uint256[8] memory y = _pow(f, FINAL_EXP);
        return _isOne(y);
    }

    /// @notice Проверяет stick-отношение F=c^r вместо полной финальной экспоненты.
    function verifyResidue(bytes memory preparedLines, uint256[8] memory c, uint256[8] memory cInv)
        external
        pure
        returns (bool)
    {
        return _verifyResidue(preparedLines, c, cInv);
    }

    /// @notice Внутренний stick-путь используют внешняя исследовательская функция и безопасные fixed-cache обертки.
    /// @dev Выделение функции не меняет формулу: сначала проверяется обратимость c, затем F = c^r.
    function _verifyResidue(bytes memory preparedLines, uint256[8] memory c, uint256[8] memory cInv)
        internal
        pure
        returns (bool)
    {
        if (!_isOne(Lollipop305ExtensionStack.fp4Mul(c, cInv))) return false;
        uint256[8] memory f = _millerCore(preparedLines);
        uint256[8] memory cr = _pow(c, R_EXP);
        return _eq(f, cr);
    }

    /// @notice Выполняет cycle-E цикл Миллера и полную финальную экспоненту для контрольного сравнения.
    function verifyCycleEDirectFinalExponent(bytes memory preparedLines) external pure returns (bool) {
        uint256[8] memory f = _millerCore(preparedLines);
        uint256[8] memory y = _pow(f, CYCLE_E_FINAL_EXP);
        return _isOne(y);
    }

    /// @notice Проверяет сокращенное cycle-E отношение F=c^q вместо полной финальной экспоненты.
    function verifyCycleEResidue(bytes memory preparedLines, uint256[8] memory c, uint256[8] memory cInv)
        external
        pure
        returns (bool)
    {
        return _verifyCycleEResidue(preparedLines, c, cInv);
    }

    /// @notice Внутренний E_cycle-путь проверяет обратимость c и сокращенное отношение F = c^q.
    /// @dev Безопасные обертки вызывают его только после привязки blob линий.
    function _verifyCycleEResidue(bytes memory preparedLines, uint256[8] memory c, uint256[8] memory cInv)
        internal
        pure
        returns (bool)
    {
        if (!_isOne(Lollipop305ExtensionStack.fp4Mul(c, cInv))) return false;
        uint256[8] memory f = _millerCore(preparedLines);
        uint256[8] memory cq = _pow(c, Q_EXP);
        return _eq(f, cq);
    }

    /// @notice Выполняет этап цикла Миллера `millerCoreDigest`; результат является элементом поля расширения до финальной экспоненты.
    function millerCoreDigest(bytes memory preparedLines) external pure returns (bytes32) {
        return keccak256(abi.encode(_millerCore(preparedLines)));
    }

    /// @notice Выполняет этап цикла Миллера `millerCoreRaw`; результат является элементом поля расширения до финальной экспоненты.
    function millerCoreRaw(bytes memory preparedLines) external pure returns (uint256[8] memory) {
        return _millerCore(preparedLines);
    }

    /// @notice Проверяет уравнение Вейля для Ehat/Fq2-части lollipop-цикла.
    /// @dev Каждый blob содержит подготовленные шаги Миллера над Fq6. Проверяется равенство
    ///      f_{p,P}(Q) * f_{p,-P}(Q) == f_{p,Q}(P) * f_{p,Q}(-P).
    function verifyEhatWeilEquation(bytes memory fP_Q, bytes memory fNegP_Q, bytes memory fQ_P, bytes memory fQ_NegP)
        external
        pure
        returns (bool)
    {
        uint256[12] memory lhs = Lollipop305QExtensionStack.fq6Mul(_millerCoreFq6(fP_Q), _millerCoreFq6(fNegP_Q));
        uint256[12] memory rhs = Lollipop305QExtensionStack.fq6Mul(_millerCoreFq6(fQ_P), _millerCoreFq6(fQ_NegP));
        return _eqFq6(lhs, rhs);
    }

    /// @notice Проверяет сокращенное prepared-ate отношение a(Q',P)*a(Q',-P)=1 для Ehat/Fq2.
    /// @dev Протокол верхнего уровня должен заранее зафиксировать или зарегистрировать подготовленный кэш линий.
    ///      Линия кодируется как op | xCoeffW | constCoeff | cVert; каждый элемент Fq2 занимает четыре слова.
    function verifyEhatAteResidue(
        bytes memory preparedLines,
        uint256[4] memory px,
        uint256[4] memory py,
        uint256[12] memory c
    ) external pure returns (bool) {
        return _verifyEhatAteResidue(preparedLines, px, py, c);
    }

    /// @notice Внутренний Ehat-путь пересчитывает два аккумулятора prepared-Ate и проверяет c^p * F_den = F_num.
    /// @dev Линии по-прежнему вычисляются Rust-бэкендом, но безопасная обертка обязана предварительно
    ///      связать их с зарегистрированным blob. Это исключает произвольную подмену множителей prover-ом.
    function _verifyEhatAteResidue(
        bytes memory preparedLines,
        uint256[4] memory px,
        uint256[4] memory py,
        uint256[12] memory c
    ) internal pure returns (bool) {
        (uint256[12] memory n1, uint256[12] memory d1) = _millerEhatAteNumDen(preparedLines, px, py);
        uint256[4] memory negPy = _fq2Neg(py);
        (uint256[12] memory n2, uint256[12] memory d2) = _millerEhatAteNumDen(preparedLines, px, negPy);
        uint256[12] memory fNum = Lollipop305QExtensionStack.fq6Mul(n1, n2);
        uint256[12] memory fDen = Lollipop305QExtensionStack.fq6Mul(d1, d2);
        uint256[12] memory cp = _powFq6(c, P_EXP);
        return _eqFq6(Lollipop305QExtensionStack.fq6Mul(cp, fDen), fNum);
    }

    /// @notice Возвращает digest трех частей Ehat-проверки: c^p, числителя F_num и знаменателя F_den.
    function ehatAteResidueDigest(
        bytes memory preparedLines,
        uint256[4] memory px,
        uint256[4] memory py,
        uint256[12] memory c
    ) external pure returns (bytes32) {
        (uint256[12] memory n1, uint256[12] memory d1) = _millerEhatAteNumDen(preparedLines, px, py);
        uint256[4] memory negPy = _fq2Neg(py);
        (uint256[12] memory n2, uint256[12] memory d2) = _millerEhatAteNumDen(preparedLines, px, negPy);
        uint256[12] memory fNum = Lollipop305QExtensionStack.fq6Mul(n1, n2);
        uint256[12] memory fDen = Lollipop305QExtensionStack.fq6Mul(d1, d2);
        uint256[12] memory cp = _powFq6(c, P_EXP);
        return keccak256(abi.encode(cp, fDen, fNum));
    }

    /// @notice Возвращает числитель и знаменатель Ehat prepared-ate аккумулятора до проверки c-свидетельства.
    function ehatAteResidueRaw(bytes memory preparedLines, uint256[4] memory px, uint256[4] memory py)
        external
        pure
        returns (uint256[12] memory fNum, uint256[12] memory fDen)
    {
        (uint256[12] memory n1, uint256[12] memory d1) = _millerEhatAteNumDen(preparedLines, px, py);
        uint256[4] memory negPy = _fq2Neg(py);
        (uint256[12] memory n2, uint256[12] memory d2) = _millerEhatAteNumDen(preparedLines, px, negPy);
        fNum = Lollipop305QExtensionStack.fq6Mul(n1, n2);
        fDen = Lollipop305QExtensionStack.fq6Mul(d1, d2);
    }

    /// @notice Возвращает digest левой и правой частей контрольного уравнения Вейля.
    function ehatWeilEquationDigest(bytes memory fP_Q, bytes memory fNegP_Q, bytes memory fQ_P, bytes memory fQ_NegP)
        external
        pure
        returns (bytes32)
    {
        uint256[12] memory lhs = Lollipop305QExtensionStack.fq6Mul(_millerCoreFq6(fP_Q), _millerCoreFq6(fNegP_Q));
        uint256[12] memory rhs = Lollipop305QExtensionStack.fq6Mul(_millerCoreFq6(fQ_P), _millerCoreFq6(fQ_NegP));
        return keccak256(abi.encode(lhs, rhs));
    }

    /// @notice На каждом шаге читает флаг и значение линии в Fp4; при удвоении сначала возводит аккумулятор в квадрат.
    function _millerCore(bytes memory preparedLines) internal pure returns (uint256[8] memory f) {
        require(preparedLines.length % 288 == 0, "bad line blob");
        f = _one();
        uint256 steps = preparedLines.length / 288;
        for (uint256 i; i < steps;) {
            uint256 offset = i * 288;
            uint256 op = _readWord(preparedLines, offset);
            if (op == 1) {
                f = Lollipop305ExtensionStack.fp4Sqr(f);
            } else {
                require(op == 0, "bad op");
            }
            f = Lollipop305ExtensionStack.fp4Mul(f, _readFp4(preparedLines, offset + 32));
            unchecked {
                ++i;
            }
        }
    }

    /// @notice Аналогично повторяет подготовленные шаги Миллера над Fq6 для Ehat-части цикла.
    function _millerCoreFq6(bytes memory preparedLines) internal pure returns (uint256[12] memory f) {
        require(preparedLines.length % 416 == 0, "bad fq6 line blob");
        f = _oneFq6();
        uint256 steps = preparedLines.length / 416;
        for (uint256 i; i < steps;) {
            uint256 offset = i * 416;
            uint256 op = _readWord(preparedLines, offset);
            if (op == 1) {
                f = Lollipop305QExtensionStack.fq6Sqr(f);
            } else {
                require(op == 0, "bad fq6 op");
            }
            f = Lollipop305QExtensionStack.fq6Mul(f, _readFq6(preparedLines, offset + 32));
            unchecked {
                ++i;
            }
        }
    }

    /// @notice Ведет отдельные аккумуляторы числителя и знаменателя Ehat prepared-ate функции Миллера.
    /// @dev В этой башне расширений знаменатель нельзя автоматически удалить, поэтому на каждом шаге
    ///      вычисляются разреженные множители для F_num и F_den.
    function _millerEhatAteNumDen(bytes memory preparedLines, uint256[4] memory px, uint256[4] memory py)
        internal
        pure
        returns (uint256[12] memory fNum, uint256[12] memory fDen)
    {
        require(preparedLines.length % 416 == 0, "bad ehat ate blob");
        fNum = _oneFq6();
        fDen = _oneFq6();
        uint256 steps = preparedLines.length / 416;
        for (uint256 i; i < steps;) {
            uint256 offset = i * 416;
            uint256 op = _readWord(preparedLines, offset);
            uint256[4] memory xCoeffW = _readFq2(preparedLines, offset + 32);
            uint256[4] memory constCoeff = _readFq2(preparedLines, offset + 160);
            uint256[4] memory cVert = _readFq2(preparedLines, offset + 288);

            uint256[4] memory aLine = _fq2Add(py, constCoeff);
            uint256[4] memory bLine = _fq2Mul(xCoeffW, px);
            uint256[4] memory cVertical = _fq2Neg(cVert);

            if (op == 1) {
                fNum = Lollipop305QExtensionStack.fq6Sqr(fNum);
                fDen = Lollipop305QExtensionStack.fq6Sqr(fDen);
            } else {
                require(op == 0, "bad ehat ate op");
            }
            fNum = Lollipop305QExtensionStack.fq6MulBy01(fNum, aLine, bLine);
            fDen = Lollipop305QExtensionStack.fq6MulBy02(fDen, px, cVertical);
            unchecked {
                ++i;
            }
        }
    }

    /// @notice Читает подготовленные данные из указанного источника: `_readWord`.
    function _readWord(bytes memory data, uint256 o) internal pure returns (uint256 value) {
        assembly ("memory-safe") {
            value := mload(add(add(data, 0x20), o))
        }
    }

    /// @notice Выполняет внутреннюю операцию `_pow`; параметры и результат используют представление текущей библиотеки.
    function _pow(uint256[8] memory base, bytes memory exp) internal pure returns (uint256[8] memory acc) {
        acc = _one();
        bool started;
        for (uint256 i; i < exp.length;) {
            uint8 b = uint8(exp[i]);
            for (uint256 bit = 0; bit < 8;) {
                bool oneBit = (b & uint8(1 << (7 - bit))) != 0;
                if (started) {
                    acc = Lollipop305ExtensionStack.fp4Sqr(acc);
                    if (oneBit) acc = Lollipop305ExtensionStack.fp4Mul(acc, base);
                } else if (oneBit) {
                    acc = base;
                    started = true;
                }
                unchecked {
                    ++bit;
                }
            }
            unchecked {
                ++i;
            }
        }
        if (!started) acc = _one();
    }

    /// @notice Выполняет внутреннюю операцию `_powFq6`; параметры и результат используют представление текущей библиотеки.
    function _powFq6(uint256[12] memory base, bytes memory exp) internal pure returns (uint256[12] memory acc) {
        acc = _oneFq6();
        bool started;
        for (uint256 i; i < exp.length;) {
            uint8 b = uint8(exp[i]);
            for (uint256 bit = 0; bit < 8;) {
                bool oneBit = (b & uint8(1 << (7 - bit))) != 0;
                if (started) {
                    acc = Lollipop305QExtensionStack.fq6Sqr(acc);
                    if (oneBit) acc = Lollipop305QExtensionStack.fq6Mul(acc, base);
                } else if (oneBit) {
                    acc = base;
                    started = true;
                }
                unchecked {
                    ++bit;
                }
            }
            unchecked {
                ++i;
            }
        }
        if (!started) acc = _oneFq6();
    }

    /// @notice Читает подготовленные данные из указанного источника: `_readFp4`.
    function _readFp4(bytes memory data, uint256 o) internal pure returns (uint256[8] memory out) {
        assembly ("memory-safe") {
            let ptr := add(add(data, 0x20), o)
            mstore(out, mload(ptr))
            mstore(add(out, 0x20), mload(add(ptr, 0x20)))
            mstore(add(out, 0x40), mload(add(ptr, 0x40)))
            mstore(add(out, 0x60), mload(add(ptr, 0x60)))
            mstore(add(out, 0x80), mload(add(ptr, 0x80)))
            mstore(add(out, 0xa0), mload(add(ptr, 0xa0)))
            mstore(add(out, 0xc0), mload(add(ptr, 0xc0)))
            mstore(add(out, 0xe0), mload(add(ptr, 0xe0)))
        }
    }

    /// @notice Читает подготовленные данные из указанного источника: `_readFq6`.
    function _readFq6(bytes memory data, uint256 o) internal pure returns (uint256[12] memory out) {
        assembly ("memory-safe") {
            let ptr := add(add(data, 0x20), o)
            mstore(out, mload(ptr))
            mstore(add(out, 0x20), mload(add(ptr, 0x20)))
            mstore(add(out, 0x40), mload(add(ptr, 0x40)))
            mstore(add(out, 0x60), mload(add(ptr, 0x60)))
            mstore(add(out, 0x80), mload(add(ptr, 0x80)))
            mstore(add(out, 0xa0), mload(add(ptr, 0xa0)))
            mstore(add(out, 0xc0), mload(add(ptr, 0xc0)))
            mstore(add(out, 0xe0), mload(add(ptr, 0xe0)))
            mstore(add(out, 0x100), mload(add(ptr, 0x100)))
            mstore(add(out, 0x120), mload(add(ptr, 0x120)))
            mstore(add(out, 0x140), mload(add(ptr, 0x140)))
            mstore(add(out, 0x160), mload(add(ptr, 0x160)))
        }
    }

    /// @notice Читает подготовленные данные из указанного источника: `_readFq2`.
    function _readFq2(bytes memory data, uint256 o) internal pure returns (uint256[4] memory out) {
        assembly ("memory-safe") {
            let ptr := add(add(data, 0x20), o)
            mstore(out, mload(ptr))
            mstore(add(out, 0x20), mload(add(ptr, 0x20)))
            mstore(add(out, 0x40), mload(add(ptr, 0x40)))
            mstore(add(out, 0x60), mload(add(ptr, 0x60)))
        }
    }

    /// @notice Выполняет сложение `_fq2Add` с учетом модуля или структуры текущего поля.
    function _fq2Add(uint256[4] memory a, uint256[4] memory b) internal pure returns (uint256[4] memory c) {
        (c[0], c[1]) = BigIntLollipop305Q.add2(a[0], a[1], b[0], b[1]);
        (c[2], c[3]) = BigIntLollipop305Q.add2(a[2], a[3], b[2], b[3]);
    }

    /// @notice Вычисляет аддитивно обратное значение: `_fq2Neg`.
    function _fq2Neg(uint256[4] memory a) internal pure returns (uint256[4] memory c) {
        (c[0], c[1]) = BigIntLollipop305Q.sub2(0, 0, a[0], a[1]);
        (c[2], c[3]) = BigIntLollipop305Q.sub2(0, 0, a[2], a[3]);
    }

    /// @notice Выполняет умножение `_fq2Mul`; точный уровень поля и специальный множитель отражены в названии.
    function _fq2Mul(uint256[4] memory a, uint256[4] memory b) internal pure returns (uint256[4] memory c) {
        (c[0], c[1], c[2], c[3]) = Lollipop305QExtensionStack.fq2Mul(a[0], a[1], a[2], a[3], b[0], b[1], b[2], b[3]);
    }

    /// @notice Возвращает единичный элемент в используемом представлении: `_one`.
    function _one() internal pure returns (uint256[8] memory out) {
        out[0] = ONE_0;
        out[1] = ONE_1;
    }

    /// @notice Возвращает единичный элемент в используемом представлении: `_oneFq6`.
    function _oneFq6() internal pure returns (uint256[12] memory out) {
        out[0] = Q_ONE_0;
        out[1] = Q_ONE_1;
    }

    /// @notice Проверяет корректность представления или принадлежность кривой: `_isOne`.
    function _isOne(uint256[8] memory a) internal pure returns (bool) {
        return
            a[0] == ONE_0 && a[1] == ONE_1 && a[2] == 0 && a[3] == 0 && a[4] == 0 && a[5] == 0 && a[6] == 0 && a[7] == 0;
    }

    /// @notice Сравнивает два значения без изменения входных данных: `_eq`.
    function _eq(uint256[8] memory a, uint256[8] memory b) internal pure returns (bool) {
        return a[0] == b[0] && a[1] == b[1] && a[2] == b[2] && a[3] == b[3] && a[4] == b[4] && a[5] == b[5]
            && a[6] == b[6] && a[7] == b[7];
    }

    /// @notice Сравнивает два значения без изменения входных данных: `_eqFq6`.
    function _eqFq6(uint256[12] memory a, uint256[12] memory b) internal pure returns (bool) {
        return a[0] == b[0] && a[1] == b[1] && a[2] == b[2] && a[3] == b[3] && a[4] == b[4] && a[5] == b[5]
            && a[6] == b[6] && a[7] == b[7] && a[8] == b[8] && a[9] == b[9] && a[10] == b[10] && a[11] == b[11];
    }
}
