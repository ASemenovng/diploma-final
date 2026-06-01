// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {BigIntMNT} from "@arith-mnt4/BigIntMNT.sol";
import {MNT4CurveChecks} from "@arith-mnt4/MNT4CurveChecks.sol";
import {MNT4ExtensionFinal} from "@arith-mnt4/MNT4Extension.sol";
import {MNT4TatePairing} from "./MNT4TatePairing.sol";

/// @notice Проверяет уравнение сопряжений и связывает упакованный разреженный кэш линий с commitment-ами.
/// @dev Быстрый packed/Yul-путь цикла Миллера сохраняется, но вызов отклоняется, если хеш переданного
///      blob не совпадает с commitment-ом, зафиксированным при развертывании контракта.
contract MNT4Article640HotCommitmentVerifier {
    /// @dev Константа `ONE_MONT_0` содержит соответствующее слово единицы в Montgomery-представлении.
    uint256 private constant ONE_MONT_0 = 0x79589819c788b60197c3e4a0cd14572e91cd31c65a03468698a8ecabd9dc6f42;
    /// @dev Константа `ONE_MONT_1` содержит соответствующее слово единицы в Montgomery-представлении.
    uint256 private constant ONE_MONT_1 = 0x598b4302d2f00a62320c3bb7133385591e0f4d8acf031d68ed269c942108976f;
    /// @dev Константа `ONE_MONT_2` содержит соответствующее слово единицы в Montgomery-представлении.
    uint256 private constant ONE_MONT_2 = 0x7b479ec8e24295455fb31ff9a1950fa47edb3865e88c4074c9cbfd8ca621;

    /// @dev Размер одного элемента Fq2: два коэффициента Fq по три слова EVM, всего 192 байта.
    uint256 private constant FQ2_BYTES = 0xc0;
    /// @dev Один разреженный шаг удвоения содержит три коэффициента Fq2.
    uint256 private constant DBL_SPARSE_STEP_BYTES = 3 * FQ2_BYTES;
    /// @dev Один разреженный шаг сложения содержит два коэффициента Fq2.
    uint256 private constant ADD_SPARSE_STEP_BYTES = 2 * FQ2_BYTES;
    /// @dev Полный blob линий удвоения: 376 шагов цикла ate.
    uint256 private constant FIXED_DBL_SPARSE_BYTES = 376 * DBL_SPARSE_STEP_BYTES;
    /// @dev Полный blob линий сложения: 124 ненулевых шага цикла ate.
    uint256 private constant FIXED_ADD_SPARSE_BYTES = 124 * ADD_SPARSE_STEP_BYTES;

    /// @dev Константа `CACHE_DOMAIN` разделяет домен хеширования и не позволяет смешать разные форматы артефактов.
    bytes32 private constant CACHE_DOMAIN = keccak256("MNT4_ARTICLE640_PACKED_SPARSE_CACHE_V1");

    // Фиксированный генератор G2 MNT4-753 для оптимизированного горячего пути fixed-Q.
    uint256 private constant G2_X_C0_0 = 0xf5199b0d7e333053db197417e18872316a123355ee93878564cd9e87e5f14e2d;
    /// @dev Константа `G2_X_C0_1` является параметром кривой или поля расширения в Montgomery-представлении.
    uint256 private constant G2_X_C0_1 = 0x1ea26a53c24e41623f8ccbdf316d6964d1117417b290f004397da434e85b78a7;
    /// @dev Константа `G2_X_C0_2` является параметром кривой или поля расширения в Montgomery-представлении.
    uint256 private constant G2_X_C0_2 = 0x13635a0d01b785b05c21a27b7acc73c355554caad25804fa40c8be29a9276;
    /// @dev Константа `G2_X_C1_0` является параметром кривой или поля расширения в Montgomery-представлении.
    uint256 private constant G2_X_C1_0 = 0xe67355775c8eb87e9217aa6ceb0cf80802b8029c87df25f6b56fc312dc34c98b;
    /// @dev Константа `G2_X_C1_1` является параметром кривой или поля расширения в Montgomery-представлении.
    uint256 private constant G2_X_C1_1 = 0xf1e11281b99054d1de8489295782a1036bebff63e88338c290eb471ebb74c1b1;
    /// @dev Константа `G2_X_C1_2` является параметром кривой или поля расширения в Montgomery-представлении.
    uint256 private constant G2_X_C1_2 = 0x16aea1ba33dc031facd7fa4614cca6ec60806cb661af7071e05664c68aa32;
    /// @dev Константа `G2_Y_C0_0` является параметром кривой или поля расширения в Montgomery-представлении.
    uint256 private constant G2_Y_C0_0 = 0x36739870b33ba70fa567a1375a9e2a27220b34b2b9daee2f438d727bf4c5002e;
    /// @dev Константа `G2_Y_C0_1` является параметром кривой или поля расширения в Montgomery-представлении.
    uint256 private constant G2_Y_C0_1 = 0xe526639d49ef3efff64a68ade535340fdb048df87997b3b7b058c55679b63f3e;
    /// @dev Константа `G2_Y_C0_2` является параметром кривой или поля расширения в Montgomery-представлении.
    uint256 private constant G2_Y_C0_2 = 0x1202d1e47ccef4f6af38904883c288e46b4ca897b87bbd52be2d6e4bee8fd;
    /// @dev Константа `G2_Y_C1_0` является параметром кривой или поля расширения в Montgomery-представлении.
    uint256 private constant G2_Y_C1_0 = 0xbbf8387b3a74937a6a393d84e066ddfca41dbc2a99750c11f06781d5bec3ed74;
    /// @dev Константа `G2_Y_C1_1` является параметром кривой или поля расширения в Montgomery-представлении.
    uint256 private constant G2_Y_C1_1 = 0x92e8c3c2f80404545c089d226f9c345d380c74d14f4e2d84ecb6da0ba28e9879;
    /// @dev Константа `G2_Y_C1_2` является параметром кривой или поля расширения в Montgomery-представлении.
    uint256 private constant G2_Y_C1_2 = 0x11e7b5c581fa35de638cd06f1c4e659a934e501a154debf6ce50f1d3555;

    MNT4TatePairing.G2Affine private fixedS;
    bytes32 public immutable COMMITMENT_Q;
    bytes32 public immutable COMMITMENT_S;

    /// @notice Фиксирует точку S и два commitment-а подготовленных разреженных кэшей Q и S.
    /// @dev Пользователь передает blob при каждом вызове, но тяжелое вычисление начинается
    ///      только после совпадения обоих хешей с этими неизменяемыми значениями.
    constructor(MNT4TatePairing.G2Affine memory s, bytes32 commitmentQ, bytes32 commitmentS) {
        fixedS = s;
        COMMITMENT_Q = commitmentQ;
        COMMITMENT_S = commitmentS;
    }

    /// @notice Возвращает вторую фиксированную точку S, заданную в конструкторе.
    function getFixedS() external view returns (MNT4TatePairing.G2Affine memory) {
        return fixedS;
    }

    /// @notice Вычисляет commitment разреженного кэша для встроенного генератора Q.
    function hashSparseCacheForFixedQ(bytes memory dblSparse, bytes memory addSparse)
        public
        pure
        returns (bytes32)
    {
        _requireSparseBlobLengths(dblSparse, addSparse);
        return _hashPackedCache(_fixedQGenerator(), dblSparse, addSparse);
    }

    /// @notice Вычисляет commitment разреженного кэша для произвольной переданной точки G2.
    function hashSparseCacheForPoint(
        MNT4TatePairing.G2Affine memory point,
        bytes memory dblSparse,
        bytes memory addSparse
    ) public pure returns (bytes32) {
        _requireSparseBlobLengths(dblSparse, addSparse);
        return _hashPackedCache(point, dblSparse, addSparse);
    }

    /// @notice Проверяет e(P,Q) * e(-R,S) = 1 для blob-кэшей, переданных в calldata.
    /// @dev Перед тяжелой арифметикой сверяются оба commitment-а и обратимость c-свидетельства.
    function verifyEquationResidueCommitted(
        MNT4TatePairing.G1Affine memory p,
        MNT4TatePairing.G1Affine memory r,
        MNT4ExtensionFinal.Fq4 memory c,
        MNT4ExtensionFinal.Fq4 memory cInv,
        bytes memory dblSparseQ,
        bytes memory addSparseQ,
        bytes memory dblSparseS,
        bytes memory addSparseS
    ) external view returns (bool) {
        if (!MNT4CurveChecks.isOnG1(p.x, p.y) || !MNT4CurveChecks.isOnG1(r.x, r.y)) return false;
        if (hashSparseCacheForFixedQ(dblSparseQ, addSparseQ) != COMMITMENT_Q) return false;
        MNT4TatePairing.G2Affine memory s = fixedS;
        if (hashSparseCacheForPoint(s, dblSparseS, addSparseS) != COMMITMENT_S) return false;
        if (!_isOne(MNT4ExtensionFinal.fq4Mul(c, cInv))) return false;

        return MNT4TatePairing.pairingEquationFixedQParametricSPreparedSparseMemResidueIsOne(
            p, _negG1(r), s, c, cInv, dblSparseQ, addSparseQ, dblSparseS, addSparseS
        );
    }

    /// @notice Проверяет то же уравнение, читая blob-кэши из переданных code-shards.
    /// @dev В отличие от `MNT4Article640FixedShardsVerifier`, адреса shards здесь передает пользователь,
    ///      поэтому контракт сначала собирает blob и проверяет его commitment.
    function verifyEquationResidueCommittedCodeShards(
        MNT4TatePairing.G1Affine memory p,
        MNT4TatePairing.G1Affine memory r,
        MNT4ExtensionFinal.Fq4 memory c,
        MNT4ExtensionFinal.Fq4 memory cInv,
        address[] memory dblShardsQ,
        address[] memory addShardsQ,
        address[] memory dblShardsS,
        address[] memory addShardsS
    ) external view returns (bool) {
        if (!MNT4CurveChecks.isOnG1(p.x, p.y) || !MNT4CurveChecks.isOnG1(r.x, r.y)) return false;
        bytes memory dblSparseQ = _readCodeShards(dblShardsQ, FIXED_DBL_SPARSE_BYTES);
        bytes memory addSparseQ = _readCodeShards(addShardsQ, FIXED_ADD_SPARSE_BYTES);
        if (hashSparseCacheForFixedQ(dblSparseQ, addSparseQ) != COMMITMENT_Q) return false;

        MNT4TatePairing.G2Affine memory s = fixedS;
        bytes memory dblSparseS = _readCodeShards(dblShardsS, FIXED_DBL_SPARSE_BYTES);
        bytes memory addSparseS = _readCodeShards(addShardsS, FIXED_ADD_SPARSE_BYTES);
        if (hashSparseCacheForPoint(s, dblSparseS, addSparseS) != COMMITMENT_S) return false;
        if (!_isOne(MNT4ExtensionFinal.fq4Mul(c, cInv))) return false;

        return MNT4TatePairing.pairingEquationFixedQParametricSPreparedSparseCodeShardsResidueIsOne(
            p, _negG1(r), s, c, cInv, dblShardsQ, addShardsQ, dblShardsS, addShardsS
        );
    }

    /// @notice Хеширует домен формата, точку G2, размеры и хеши двух blob кэша линий.
    function _hashPackedCache(
        MNT4TatePairing.G2Affine memory point,
        bytes memory dblSparse,
        bytes memory addSparse
    ) private pure returns (bytes32) {
        return keccak256(
            abi.encodePacked(
                CACHE_DOMAIN,
                point.x.c0[0],
                point.x.c0[1],
                point.x.c0[2],
                point.x.c1[0],
                point.x.c1[1],
                point.x.c1[2],
                point.y.c0[0],
                point.y.c0[1],
                point.y.c0[2],
                point.y.c1[0],
                point.y.c1[1],
                point.y.c1[2],
                dblSparse.length,
                keccak256(dblSparse),
                addSparse.length,
                keccak256(addSparse)
            )
        );
    }

    /// @notice Собирает единый blob из runtime-кода нескольких data-контрактов через EXTCODECOPY.
    function _readCodeShards(address[] memory shards, uint256 expectedBytes)
        private
        view
        returns (bytes memory blob)
    {
        blob = new bytes(expectedBytes);
        uint256 out;
        for (uint256 i = 0; i < shards.length; ++i) {
            address shard = shards[i];
            uint256 size;
            assembly ("memory-safe") {
                size := extcodesize(shard)
            }
            if (size == 0 || out + size > expectedBytes) revert("bad shard size");
            assembly ("memory-safe") {
                extcodecopy(shard, add(add(blob, 0x20), out), 0, size)
            }
            out += size;
        }
        if (out != expectedBytes) revert("bad shard total");
    }

    /// @notice Проверяет точные размеры сериализованных кэшей, чтобы исключить неоднозначный формат.
    function _requireSparseBlobLengths(bytes memory dblSparse, bytes memory addSparse) private pure {
        require(dblSparse.length == FIXED_DBL_SPARSE_BYTES, "bad dbl sparse");
        require(addSparse.length == FIXED_ADD_SPARSE_BYTES, "bad add sparse");
    }

    /// @notice Возвращает встроенный генератор G2, используемый как фиксированная точка Q.
    function _fixedQGenerator() private pure returns (MNT4TatePairing.G2Affine memory q) {
        q.x.c0 = [G2_X_C0_0, G2_X_C0_1, G2_X_C0_2];
        q.x.c1 = [G2_X_C1_0, G2_X_C1_1, G2_X_C1_2];
        q.y.c0 = [G2_Y_C0_0, G2_Y_C0_1, G2_Y_C0_2];
        q.y.c1 = [G2_Y_C1_0, G2_Y_C1_1, G2_Y_C1_2];
    }

    /// @notice Возвращает -P в G1.
    function _negG1(MNT4TatePairing.G1Affine memory p)
        private
        pure
        returns (MNT4TatePairing.G1Affine memory out)
    {
        out.x = p.x;
        out.y = _negFp(p.y);
    }

    /// @notice Вычисляет -a mod p для элемента базового поля.
    function _negFp(uint256[3] memory a) private pure returns (uint256[3] memory out) {
        (out[0], out[1], out[2]) = BigIntMNT.sub3(0, 0, 0, a[0], a[1], a[2]);
    }

    /// @notice Проверяет равенство элемента Fq4 единице в Montgomery-представлении.
    function _isOne(MNT4ExtensionFinal.Fq4 memory x) private pure returns (bool) {
        return x.c0.c0[0] == ONE_MONT_0 && x.c0.c0[1] == ONE_MONT_1 && x.c0.c0[2] == ONE_MONT_2
            && x.c0.c1[0] == 0 && x.c0.c1[1] == 0 && x.c0.c1[2] == 0
            && x.c1.c0[0] == 0 && x.c1.c0[1] == 0 && x.c1.c0[2] == 0
            && x.c1.c1[0] == 0 && x.c1.c1[1] == 0 && x.c1.c1[2] == 0;
    }
}
