// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {MNT6PairingTypes} from "@arith-mnt6/MNT6PairingTypes.sol";
import {MNT6Fq6} from "@arith-mnt6/MNT6Fq6.sol";
import {MNT6AteLoop} from "@arith-mnt6/MNT6AteLoop.sol";

/// @notice Диагностический контракт для измерения отдельных MNT6-753 путей Миллера и финальной экспоненты.
/// @dev Этот контракт не является публичным production-verifier-ом: его функции принимают подготовленные
///      данные непосредственно от вызывающей стороны и нужны для кросс-проверок и gas-бенчмарков.
///      Безопасный fixed-shards API находится в `MNT6Article640FixedShardsVerifier`.
contract MNT6Article640DirectVerifier {
    /// @notice Выполняет цикл Миллера по подготовленному blob коэффициентов линий.
    function millerLoopPreparedBlob(
        MNT6PairingTypes.G1Point calldata p,
        MNT6PairingTypes.Fq3 calldata qXOverTwist,
        MNT6PairingTypes.Fq3 calldata qYOverTwist,
        bytes calldata dblBlob,
        bytes calldata addBlob
    ) external pure returns (MNT6PairingTypes.Fq6 memory) {
        return MNT6AteLoop.millerLoopPreparedBlob(p, qXOverTwist, qYOverTwist, dblBlob, addBlob);
    }

    /// @notice Возвращает digest результата цикла Миллера для обычного blob-пути.
    function millerLoopPreparedBlobDigest(
        MNT6PairingTypes.G1Point calldata p,
        MNT6PairingTypes.Fq3 calldata qXOverTwist,
        MNT6PairingTypes.Fq3 calldata qYOverTwist,
        bytes calldata dblBlob,
        bytes calldata addBlob
    ) external pure returns (bytes32) {
        MNT6PairingTypes.Fq6 memory f =
            MNT6AteLoop.millerLoopPreparedBlob(p, qXOverTwist, qYOverTwist, dblBlob, addBlob);
        return hashFq6(f);
    }

    /// @notice Возвращает digest результата оптимизированного packed-цикла Миллера.
    function millerLoopPreparedPackedBlobDigest(
        MNT6PairingTypes.G1Point calldata p,
        MNT6PairingTypes.Fq3 calldata qXOverTwist,
        MNT6PairingTypes.Fq3 calldata qYOverTwist,
        bytes calldata dblBlob,
        bytes calldata addBlob
    ) external pure returns (bytes32) {
        MNT6PairingTypes.Fq6 memory f =
            MNT6AteLoop.millerLoopPreparedBlobPacked(p, qXOverTwist, qYOverTwist, dblBlob, addBlob);
        return hashFq6(f);
    }

    /// @notice Выполняет packed-цикл Миллера и контрольную полную финальную экспоненту.
    function pairingPreparedPackedFullDigest(
        MNT6PairingTypes.G1Point calldata p,
        MNT6PairingTypes.Fq3 calldata qXOverTwist,
        MNT6PairingTypes.Fq3 calldata qYOverTwist,
        bytes calldata dblBlob,
        bytes calldata addBlob
    ) external pure returns (bytes32) {
        MNT6PairingTypes.Fq6 memory f =
            MNT6AteLoop.millerLoopPreparedBlobPacked(p, qXOverTwist, qYOverTwist, dblBlob, addBlob);
        return hashFq6(MNT6Fq6.finalExponentiation(f));
    }

    /// @notice Выполняет packed-цикл Миллера и оптимизированную packed-финальную экспоненту.
    function pairingPreparedPackedFullDigestWithPackedFE(
        MNT6PairingTypes.G1Point calldata p,
        MNT6PairingTypes.Fq3 calldata qXOverTwist,
        MNT6PairingTypes.Fq3 calldata qYOverTwist,
        bytes calldata dblBlob,
        bytes calldata addBlob
    ) external pure returns (bytes32) {
        MNT6PairingTypes.Fq6 memory f =
            MNT6AteLoop.millerLoopPreparedBlobPacked(p, qXOverTwist, qYOverTwist, dblBlob, addBlob);
        return hashFq6(MNT6Fq6.finalExponentiationPacked(f));
    }

    /// @notice Выполняет исследовательский packed residue-фрагмент с c-свидетельством.
    /// @dev Результат нужен только для измерения. MNT4-style короткое c-отношение нельзя
    ///      автоматически переносить в production MNT6 verifier без отдельного доказательства.
    function pairingPreparedPackedResidueDigest(
        MNT6PairingTypes.G1Point calldata p,
        MNT6PairingTypes.Fq3 calldata qXOverTwist,
        MNT6PairingTypes.Fq3 calldata qYOverTwist,
        MNT6PairingTypes.Fq6 calldata c,
        MNT6PairingTypes.Fq6 calldata cInv,
        bytes calldata dblBlob,
        bytes calldata addBlob
    ) external pure returns (bytes32) {
        if (!MNT6Fq6.eq(MNT6Fq6.mul(c, cInv), MNT6Fq6.one())) return bytes32(0);
        MNT6PairingTypes.Fq6 memory f =
            MNT6AteLoop.millerLoopPreparedBlobPackedResidue(p, qXOverTwist, qYOverTwist, c, cInv, dblBlob, addBlob);
        return hashFq6(f);
    }

    /// @notice Выполняет цикл Миллера для blob, уже размещенного в памяти.
    function millerLoopPreparedMemoryBlob(
        MNT6PairingTypes.G1Point calldata p,
        MNT6PairingTypes.Fq3 calldata qXOverTwist,
        MNT6PairingTypes.Fq3 calldata qYOverTwist,
        bytes memory dblBlob,
        bytes memory addBlob
    ) public pure returns (MNT6PairingTypes.Fq6 memory) {
        return MNT6AteLoop.millerLoopPreparedBlobMem(p, qXOverTwist, qYOverTwist, dblBlob, addBlob);
    }

    /// @notice Копирует blob из runtime-кода data-контрактов и выполняет цикл Миллера.
    function millerLoopPreparedCodeBlob(
        MNT6PairingTypes.G1Point calldata p,
        MNT6PairingTypes.Fq3 calldata qXOverTwist,
        MNT6PairingTypes.Fq3 calldata qYOverTwist,
        address dblData,
        uint256 dblLen,
        address addData,
        uint256 addLen
    ) external view returns (MNT6PairingTypes.Fq6 memory) {
        return MNT6AteLoop.millerLoopPreparedBlobMem(
            p, qXOverTwist, qYOverTwist, _copyCode(dblData, dblLen), _copyCode(addData, addLen)
        );
    }

    /// @notice Потоково читает подготовленные линии из data-контрактов, не копируя весь blob в память.
    function millerLoopPreparedStreamingCodeBlobDigest(
        MNT6PairingTypes.G1Point calldata p,
        MNT6PairingTypes.Fq3 calldata qXOverTwist,
        MNT6PairingTypes.Fq3 calldata qYOverTwist,
        address dblData,
        uint256 dblLen,
        address addData,
        uint256 addLen
    ) external view returns (bytes32) {
        MNT6PairingTypes.Fq6 memory f = MNT6AteLoop.millerLoopPreparedCodeStreaming(
            p, qXOverTwist, qYOverTwist, dblData, dblLen, addData, addLen
        );
        return hashFq6(f);
    }

    /// @notice Изолированно проверяет исследовательское отношение F=c^r и корректность cInv.
    /// @dev Диагностическая функция не является заменой полной MNT6 pairing-equation проверки.
    function verifyResidueRelation(
        MNT6PairingTypes.Fq6 calldata millerProduct,
        MNT6PairingTypes.Fq6 calldata c,
        MNT6PairingTypes.Fq6 calldata cInv
    ) external pure returns (bool) {
        if (!MNT6Fq6.eq(MNT6Fq6.mul(c, cInv), MNT6Fq6.one())) return false;
        return MNT6Fq6.eq(MNT6Fq6.powByMNT6ScalarModulus(c), millerProduct);
    }

    /// @notice Возвращает digest результата контрольной полной финальной экспоненты.
    function finalExponentiationDigest(MNT6PairingTypes.Fq6 calldata millerProduct)
        external pure returns (bytes32)
    {
        return hashFq6(MNT6Fq6.finalExponentiation(millerProduct));
    }

    /// @notice Возвращает digest результата оптимизированной packed-финальной экспоненты.
    function finalExponentiationPackedDigest(MNT6PairingTypes.Fq6 calldata millerProduct)
        external pure returns (bytes32)
    {
        return hashFq6(MNT6Fq6.finalExponentiationPacked(millerProduct));
    }

    /// @notice Сериализует коэффициенты Fq6 в фиксированном порядке и вычисляет digest.
    function hashFq6(MNT6PairingTypes.Fq6 memory x) public pure returns (bytes32) {
        return keccak256(
            abi.encode(
                x.c0.c0.d2,
                x.c0.c0.d1,
                x.c0.c0.d0,
                x.c0.c1.d2,
                x.c0.c1.d1,
                x.c0.c1.d0,
                x.c0.c2.d2,
                x.c0.c2.d1,
                x.c0.c2.d0,
                x.c1.c0.d2,
                x.c1.c0.d1,
                x.c1.c0.d0,
                x.c1.c1.d2,
                x.c1.c1.d1,
                x.c1.c1.d0,
                x.c1.c2.d2,
                x.c1.c2.d1,
                x.c1.c2.d0
            )
        );
    }

    /// @notice Копирует runtime-код data-контракта в bytes-буфер инструкцией EXTCODECOPY.
    function _copyCode(address dataContract, uint256 len) private view returns (bytes memory out) {
        out = new bytes(len);
        assembly ("memory-safe") {
            extcodecopy(dataContract, add(out, 0x20), 0, len)
        }
    }
}
