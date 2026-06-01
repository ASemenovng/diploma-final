// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {MNT6AteLoop} from "@arith-mnt6/MNT6AteLoop.sol";
import {MNT6CurveChecks} from "@arith-mnt6/MNT6CurveChecks.sol";
import {MNT6Fp} from "@arith-mnt6/MNT6Fp.sol";
import {MNT6Fq6} from "@arith-mnt6/MNT6Fq6.sol";
import {MNT6PairingTypes} from "@arith-mnt6/MNT6PairingTypes.sol";

/// @notice Проверяет уравнение e(P,Q) * e(-R,S) = 1 для двух фиксированных точек Q,S группы G2 MNT6-753.
/// @dev Контракт реализует безопасный fixed-shards режим. Prepared-кэш считается доверенной частью
///      конфигурации развертывания: адреса data-контрактов задаются конструктором и не принимаются от
///      пользователя. На каждом вызове меняются только публичные точки P,R группы G1.
///
///      В отличие от MNT4 экспериментальная встроенная residue-проверка MNT6 не используется:
///      ее короткое отношение требует отдельного доказательства разрешимости. Поэтому production-путь
///      завершает объединенный Miller product полной оптимизированной финальной экспонентой.
contract MNT6Article640FixedShardsVerifier {
    MNT6PairingTypes.Fq3 private fixedQXOverTwist;
    MNT6PairingTypes.Fq3 private fixedQYOverTwist;
    MNT6PairingTypes.Fq3 private fixedSXOverTwist;
    MNT6PairingTypes.Fq3 private fixedSYOverTwist;

    address[] private dblShardsQ;
    address[] private addShardsQ;
    address[] private dblShardsS;
    address[] private addShardsS;

    /// @notice Фиксирует подготовленные точки и адреса code-shards с коэффициентами линий.
    constructor(
        MNT6PairingTypes.Fq3 memory qXOverTwist,
        MNT6PairingTypes.Fq3 memory qYOverTwist,
        MNT6PairingTypes.Fq3 memory sXOverTwist,
        MNT6PairingTypes.Fq3 memory sYOverTwist,
        address[] memory dblQ,
        address[] memory addQ,
        address[] memory dblS,
        address[] memory addS
    ) {
        require(dblQ.length != 0 && addQ.length != 0 && dblS.length != 0 && addS.length != 0, "empty shards");
        fixedQXOverTwist = qXOverTwist;
        fixedQYOverTwist = qYOverTwist;
        fixedSXOverTwist = sXOverTwist;
        fixedSYOverTwist = sYOverTwist;
        dblShardsQ = dblQ;
        addShardsQ = addQ;
        dblShardsS = dblS;
        addShardsS = addS;
    }

    /// @notice Проверяет уравнение сопряжений для публичных точек P,R.
    /// @dev Перед дорогой арифметикой обе точки проверяются на принадлежность G1. Для MNT6-753
    ///      cofactor G1 равен единице, поэтому отдельное умножение на порядок подгруппы не требуется.
    function verifyEquationFullFixedShards(MNT6PairingTypes.G1Point memory p, MNT6PairingTypes.G1Point memory r)
        external
        view
        returns (bool)
    {
        if (!MNT6CurveChecks.isOnG1(p) || !MNT6CurveChecks.isOnG1(r)) return false;

        address[] memory dQ = dblShardsQ;
        address[] memory aQ = addShardsQ;
        address[] memory dS = dblShardsS;
        address[] memory aS = addShardsS;
        MNT6PairingTypes.Fq6 memory fQ = MNT6AteLoop.millerLoopPreparedCodeShardsPacked(
            p, fixedQXOverTwist, fixedQYOverTwist, dQ, aQ
        );
        MNT6PairingTypes.Fq6 memory fS = MNT6AteLoop.millerLoopPreparedCodeShardsPacked(
            _negG1(r), fixedSXOverTwist, fixedSYOverTwist, dS, aS
        );
        return MNT6Fq6.eq(MNT6Fq6.finalExponentiationPacked(MNT6Fq6.mul(fQ, fS)), MNT6Fq6.one());
    }

    /// @notice Возвращает количество data-контрактов для четырех последовательностей коэффициентов.
    function shardCounts() external view returns (uint256 dblQ, uint256 addQ, uint256 dblS, uint256 addS) {
        return (dblShardsQ.length, addShardsQ.length, dblShardsS.length, addShardsS.length);
    }

    /// @notice Вычисляет -P: координата x сохраняется, координата y меняет знак в Fq.
    function _negG1(MNT6PairingTypes.G1Point memory p)
        private
        pure
        returns (MNT6PairingTypes.G1Point memory out)
    {
        out.x = p.x;
        out.y = MNT6Fp.neg(p.y);
    }
}
