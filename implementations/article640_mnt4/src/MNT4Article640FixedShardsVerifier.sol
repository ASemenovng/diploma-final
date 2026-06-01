// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {BigIntMNT} from "@arith-mnt4/BigIntMNT.sol";
import {MNT4CurveChecks} from "@arith-mnt4/MNT4CurveChecks.sol";
import {MNT4ExtensionFinal} from "@arith-mnt4/MNT4Extension.sol";
import {MNT4TatePairing} from "./MNT4TatePairing.sol";

/// @notice Проверяет уравнение сопряжений для двух фиксированных точек G2, читая подготовленные линии из code-shards.
/// @dev Адреса data-контрактов задаются только в конструкторе. Пользователь не может заменить кэш при вызове:
///      каждый вызов читает один и тот же сериализованный набор коэффициентов инструкцией EXTCODECOPY.
contract MNT4Article640FixedShardsVerifier {
    /// @dev Константа `ONE_MONT_0` содержит соответствующее слово единицы в Montgomery-представлении.
    uint256 private constant ONE_MONT_0 = 0x79589819c788b60197c3e4a0cd14572e91cd31c65a03468698a8ecabd9dc6f42;
    /// @dev Константа `ONE_MONT_1` содержит соответствующее слово единицы в Montgomery-представлении.
    uint256 private constant ONE_MONT_1 = 0x598b4302d2f00a62320c3bb7133385591e0f4d8acf031d68ed269c942108976f;
    /// @dev Константа `ONE_MONT_2` содержит соответствующее слово единицы в Montgomery-представлении.
    uint256 private constant ONE_MONT_2 = 0x7b479ec8e24295455fb31ff9a1950fa47edb3865e88c4074c9cbfd8ca621;

    // Координаты второй фиксированной точки S в G2. Каждая координата лежит в Fq2,
    // а каждый коэффициент Fq2 хранится тремя 256-битными словами Montgomery-представления.
    uint256 private immutable S_X_C0_0;
    uint256 private immutable S_X_C0_1;
    uint256 private immutable S_X_C0_2;
    uint256 private immutable S_X_C1_0;
    uint256 private immutable S_X_C1_1;
    uint256 private immutable S_X_C1_2;
    uint256 private immutable S_Y_C0_0;
    uint256 private immutable S_Y_C0_1;
    uint256 private immutable S_Y_C0_2;
    uint256 private immutable S_Y_C1_0;
    uint256 private immutable S_Y_C1_1;
    uint256 private immutable S_Y_C1_2;

    // Адреса data-контрактов с коэффициентами линий: отдельно для шагов удвоения и сложения,
    // отдельно для фиксированной точки Q и второй фиксированной точки S.
    address[] private dblShardsQ;
    address[] private addShardsQ;
    address[] private dblShardsS;
    address[] private addShardsS;

    /// @notice Фиксирует вторую G2-точку S и четыре списка data-контрактов с линиями Q и S.
    /// @dev После развертывания пользователь не может изменить эти адреса, поэтому отдельный
    ///      commitment на каждый вызов не требуется: доверенная конфигурация задается самим контрактом.
    constructor(
        MNT4TatePairing.G2Affine memory s,
        address[] memory dblQ,
        address[] memory addQ,
        address[] memory dblS,
        address[] memory addS
    ) {
        require(dblQ.length != 0 && addQ.length != 0 && dblS.length != 0 && addS.length != 0, "empty shards");
        S_X_C0_0 = s.x.c0[0];
        S_X_C0_1 = s.x.c0[1];
        S_X_C0_2 = s.x.c0[2];
        S_X_C1_0 = s.x.c1[0];
        S_X_C1_1 = s.x.c1[1];
        S_X_C1_2 = s.x.c1[2];
        S_Y_C0_0 = s.y.c0[0];
        S_Y_C0_1 = s.y.c0[1];
        S_Y_C0_2 = s.y.c0[2];
        S_Y_C1_0 = s.y.c1[0];
        S_Y_C1_1 = s.y.c1[1];
        S_Y_C1_2 = s.y.c1[2];
        dblShardsQ = dblQ;
        addShardsQ = addQ;
        dblShardsS = dblS;
        addShardsS = addS;
    }

    /// @notice Возвращает вторую фиксированную точку S, записанную в конструкторе.
    function getFixedS() external view returns (MNT4TatePairing.G2Affine memory) {
        return _fixedS();
    }

    /// @notice Возвращает число data-контрактов в каждом из четырех наборов code-shards.
    function shardCounts() external view returns (uint256 dblQ, uint256 addQ, uint256 dblS, uint256 addS) {
        return (dblShardsQ.length, addShardsQ.length, dblShardsS.length, addShardsS.length);
    }

    /// @notice Проверяет e(P,Q) * e(-R,S) = 1 без полной финальной экспоненты.
    /// @dev Сначала проверяется, что cInv действительно обратен c. Затем библиотека вычисляет общий
    ///      цикл Миллера по зафиксированным линиям и проверяет отношение с c-свидетельством.
    function verifyEquationResidueFixedShards(
        MNT4TatePairing.G1Affine memory p,
        MNT4TatePairing.G1Affine memory r,
        MNT4ExtensionFinal.Fq4 memory c,
        MNT4ExtensionFinal.Fq4 memory cInv
    ) external view returns (bool) {
        if (!MNT4CurveChecks.isOnG1(p.x, p.y) || !MNT4CurveChecks.isOnG1(r.x, r.y)) return false;
        if (!_isOne(MNT4ExtensionFinal.fq4Mul(c, cInv))) return false;

        address[] memory dblQ = dblShardsQ;
        address[] memory addQ = addShardsQ;
        address[] memory dblS = dblShardsS;
        address[] memory addS = addShardsS;

        return MNT4TatePairing.pairingEquationFixedQParametricSPreparedSparseCodeShardsResidueIsOne(
            p, _negG1(r), _fixedS(), c, cInv, dblQ, addQ, dblS, addS
        );
    }

    /// @notice Восстанавливает точку S из immutable-слов без чтения изменяемого хранилища.
    function _fixedS() private view returns (MNT4TatePairing.G2Affine memory s) {
        s.x.c0 = [S_X_C0_0, S_X_C0_1, S_X_C0_2];
        s.x.c1 = [S_X_C1_0, S_X_C1_1, S_X_C1_2];
        s.y.c0 = [S_Y_C0_0, S_Y_C0_1, S_Y_C0_2];
        s.y.c1 = [S_Y_C1_0, S_Y_C1_1, S_Y_C1_2];
    }

    /// @notice Возвращает -P: координата x сохраняется, координата y меняет знак в Fq.
    function _negG1(MNT4TatePairing.G1Affine memory p)
        private
        pure
        returns (MNT4TatePairing.G1Affine memory out)
    {
        out.x = p.x;
        out.y = _negFp(p.y);
    }

    /// @notice Вычисляет -a mod p для элемента базового поля MNT4-753.
    function _negFp(uint256[3] memory a) private pure returns (uint256[3] memory out) {
        (out[0], out[1], out[2]) = BigIntMNT.sub3(0, 0, 0, a[0], a[1], a[2]);
    }

    /// @notice Проверяет, что элемент Fq4 равен единице в Montgomery-представлении.
    function _isOne(MNT4ExtensionFinal.Fq4 memory x) private pure returns (bool) {
        return x.c0.c0[0] == ONE_MONT_0 && x.c0.c0[1] == ONE_MONT_1 && x.c0.c0[2] == ONE_MONT_2
            && x.c0.c1[0] == 0 && x.c0.c1[1] == 0 && x.c0.c1[2] == 0
            && x.c1.c0[0] == 0 && x.c1.c0[1] == 0 && x.c1.c0[2] == 0
            && x.c1.c1[0] == 0 && x.c1.c1[1] == 0 && x.c1.c1[2] == 0;
    }
}
