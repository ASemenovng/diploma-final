// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {BigIntMNT} from "@arith-mnt4/BigIntMNT.sol";
import {MNT4ExtensionFinal} from "@arith-mnt4/MNT4Extension.sol";
import {MNT4TatePairing} from "./MNT4TatePairing.sol";

/// @notice Быстрый проверяющий контракт для уравнений сопряжений с фиксированной точкой Q.
/// @dev Контракт использует указательный Yul-путь из полной on-chain реализации. Режим same-Q проверяет
///      e(P,Q)=e(R,Q), то есть e(P,Q) * e(-R,Q)=1. Фиксация Q позволяет многократно использовать
///      один подготовленный разреженный кэш линий генератора G2.
contract MNT4Article640SameQHotVerifier {
    /// @dev Константа `ONE_MONT_0` содержит соответствующее слово единицы в Montgomery-представлении.
    uint256 private constant ONE_MONT_0 = 0x79589819c788b60197c3e4a0cd14572e91cd31c65a03468698a8ecabd9dc6f42;
    /// @dev Константа `ONE_MONT_1` содержит соответствующее слово единицы в Montgomery-представлении.
    uint256 private constant ONE_MONT_1 = 0x598b4302d2f00a62320c3bb7133385591e0f4d8acf031d68ed269c942108976f;
    /// @dev Константа `ONE_MONT_2` содержит соответствующее слово единицы в Montgomery-представлении.
    uint256 private constant ONE_MONT_2 = 0x7b479ec8e24295455fb31ff9a1950fa47edb3865e88c4074c9cbfd8ca621;

    /// @notice Строит разреженный кэш линий для встроенного генератора Q; функция нужна для тестов и подготовки fixture.
    function prepareFixedQBlobSparse() external pure returns (bytes memory dblSparse, bytes memory addSparse) {
        return MNT4TatePairing.prepareFixedQBlobSparse();
    }

    /// @notice Строит разреженный кэш линий для произвольной точки S; функция нужна для тестов и подготовки fixture.
    function prepareParametricQBlobSparse(MNT4TatePairing.G2Affine memory q)
        external
        pure
        returns (bytes memory dblSparse, bytes memory addSparse)
    {
        return MNT4TatePairing.prepareParametricQBlobSparse(q);
    }

    /// @notice Проверяет e(P,Q) * e(-R,S) = 1 обычной финальной экспонентой.
    function verifyEquationFixedQParametricS(
        MNT4TatePairing.G1Affine memory p,
        MNT4TatePairing.G1Affine memory r,
        MNT4TatePairing.G2Affine memory s,
        bytes memory dblSparseQ,
        bytes memory addSparseQ,
        bytes memory dblSparseS,
        bytes memory addSparseS
    ) external pure returns (bool) {
        return MNT4TatePairing.pairingEquationFixedQParametricSPreparedSparseMemIsOne(
            p, _negG1(r), s, dblSparseQ, addSparseQ, dblSparseS, addSparseS
        );
    }

    /// @notice Запускает только общий цикл Миллера без финальной экспоненты; используется для измерения gas.
    function verifyEquationFixedQParametricSCore(
        MNT4TatePairing.G1Affine memory p,
        MNT4TatePairing.G1Affine memory r,
        MNT4TatePairing.G2Affine memory s,
        bytes memory dblSparseQ,
        bytes memory addSparseQ,
        bytes memory dblSparseS,
        bytes memory addSparseS
    ) external pure returns (bool) {
        bytes32 digest = MNT4TatePairing.millerLoopFixedQParametricSPreparedSparseMemDigest(
            p, _negG1(r), s, dblSparseQ, addSparseQ, dblSparseS, addSparseS
        );
        return digest != bytes32(0);
    }

    /// @notice Проверяет e(P,Q) * e(-R,S) = 1 через c-свидетельство вместо полной финальной экспоненты.
    function verifyEquationFixedQParametricSResidue(
        MNT4TatePairing.G1Affine memory p,
        MNT4TatePairing.G1Affine memory r,
        MNT4TatePairing.G2Affine memory s,
        MNT4ExtensionFinal.Fq4 memory c,
        MNT4ExtensionFinal.Fq4 memory cInv,
        bytes memory dblSparseQ,
        bytes memory addSparseQ,
        bytes memory dblSparseS,
        bytes memory addSparseS
    ) external pure returns (bool) {
        if (!_isOne(MNT4ExtensionFinal.fq4Mul(c, cInv))) return false;
        return MNT4TatePairing.pairingEquationFixedQParametricSPreparedSparseMemResidueIsOne(
            p, _negG1(r), s, c, cInv, dblSparseQ, addSparseQ, dblSparseS, addSparseS
        );
    }

    /// @notice Аналог residue-проверки, читающий подготовленные линии из code-shards через EXTCODECOPY.
    function verifyEquationFixedQParametricSResidueCodeShards(
        MNT4TatePairing.G1Affine memory p,
        MNT4TatePairing.G1Affine memory r,
        MNT4TatePairing.G2Affine memory s,
        MNT4ExtensionFinal.Fq4 memory c,
        MNT4ExtensionFinal.Fq4 memory cInv,
        address[] memory dblShardsQ,
        address[] memory addShardsQ,
        address[] memory dblShardsS,
        address[] memory addShardsS
    ) external view returns (bool) {
        if (!_isOne(MNT4ExtensionFinal.fq4Mul(c, cInv))) return false;
        return MNT4TatePairing.pairingEquationFixedQParametricSPreparedSparseCodeShardsResidueIsOne(
            p, _negG1(r), s, c, cInv, dblShardsQ, addShardsQ, dblShardsS, addShardsS
        );
    }

    /// @notice Проверяет, что cInv является мультипликативно обратным элементом к c.
    function residueWitnessInverseOk(MNT4ExtensionFinal.Fq4 memory c, MNT4ExtensionFinal.Fq4 memory cInv)
        external
        pure
        returns (bool)
    {
        return _isOne(MNT4ExtensionFinal.fq4Mul(c, cInv));
    }

    /// @notice Диагностический вызов цикла Миллера для обнаружения нулевого аккумулятора.
    function millerEquationFixedQParametricSIsZero(
        MNT4TatePairing.G1Affine memory p,
        MNT4TatePairing.G1Affine memory r,
        MNT4TatePairing.G2Affine memory s,
        bytes memory dblSparseQ,
        bytes memory addSparseQ,
        bytes memory dblSparseS,
        bytes memory addSparseS
    ) external pure returns (bool) {
        return MNT4TatePairing.millerLoopFixedQParametricSPreparedSparseMemIsZero(
            p, _negG1(r), s, dblSparseQ, addSparseQ, dblSparseS, addSparseS
        );
    }

    /// @notice Проверяет e(P,Q) * e(-R,Q) = 1 при единственном общем кэше линий.
    function verifyEquationSameQ(
        MNT4TatePairing.G1Affine memory p,
        MNT4TatePairing.G1Affine memory r,
        bytes memory dblSparse,
        bytes memory addSparse
    ) external pure returns (bool) {
        MNT4TatePairing.G1Affine[] memory points = _equationPoints(p, r);
        MNT4ExtensionFinal.Fq4 memory out =
            MNT4TatePairing.tateMultiPairingFixedQPreparedSparseMem(points, dblSparse, addSparse);
        return _isOne(out);
    }

    /// @notice Выполняет только общий цикл Миллера режима same-Q; используется для раздельного измерения стоимости.
    function verifyEquationSameQCore(
        MNT4TatePairing.G1Affine memory p,
        MNT4TatePairing.G1Affine memory r,
        bytes memory dblSparse,
        bytes memory addSparse
    ) external pure returns (bool) {
        MNT4TatePairing.G1Affine[] memory points = _equationPoints(p, r);
        MNT4TatePairing.multiMillerLoopFixedQPreparedSparseBlobNoInvMem(points, dblSparse, addSparse);
        return true;
    }

    /// @notice Формирует две точки G1 для уравнения: P и -R.
    function _equationPoints(MNT4TatePairing.G1Affine memory p, MNT4TatePairing.G1Affine memory r)
        private
        pure
        returns (MNT4TatePairing.G1Affine[] memory points)
    {
        points = new MNT4TatePairing.G1Affine[](2);
        points[0] = p;
        points[1].x = r.x;
        points[1].y = _negFp(r.y);
    }

    /// @notice Вычисляет -a mod p для элемента Fq.
    function _negFp(uint256[3] memory a) private pure returns (uint256[3] memory out) {
        (out[0], out[1], out[2]) = BigIntMNT.sub3(0, 0, 0, a[0], a[1], a[2]);
    }

    /// @notice Возвращает -P в G1.
    function _negG1(MNT4TatePairing.G1Affine memory p) private pure returns (MNT4TatePairing.G1Affine memory out) {
        out.x = p.x;
        out.y = _negFp(p.y);
    }

    /// @notice Проверяет равенство элемента Fq4 единице в Montgomery-представлении.
    function _isOne(MNT4ExtensionFinal.Fq4 memory x) private pure returns (bool) {
        return x.c0.c0[0] == ONE_MONT_0 && x.c0.c0[1] == ONE_MONT_1 && x.c0.c0[2] == ONE_MONT_2
            && x.c0.c1[0] == 0 && x.c0.c1[1] == 0 && x.c0.c1[2] == 0
            && x.c1.c0[0] == 0 && x.c1.c0[1] == 0 && x.c1.c0[2] == 0
            && x.c1.c1[0] == 0 && x.c1.c1[1] == 0 && x.c1.c1[2] == 0;
    }

    /// @notice Проверяет равенство элемента Fq4 нулю.
    function _isZero(MNT4ExtensionFinal.Fq4 memory x) private pure returns (bool) {
        return x.c0.c0[0] == 0 && x.c0.c0[1] == 0 && x.c0.c0[2] == 0
            && x.c0.c1[0] == 0 && x.c0.c1[1] == 0 && x.c0.c1[2] == 0
            && x.c1.c0[0] == 0 && x.c1.c0[1] == 0 && x.c1.c0[2] == 0
            && x.c1.c1[0] == 0 && x.c1.c1[1] == 0 && x.c1.c1[2] == 0;
    }
}
