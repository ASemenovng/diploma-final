// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Lollipop305Article640Verifier} from "./Lollipop305Article640Verifier.sol";

/// @notice Производственный fixed-cache режим: подготовленные линии читаются из неизменяемых code-shards.
/// @dev Пользователь не передает blob или адреса shards в verify-вызове. Списки адресов фиксируются
///      в конструкторе, а runtime-код data-контрактов читается инструкцией EXTCODECOPY. Поэтому
///      пользователь не может заменить зарегистрированный кэш и отдельный keccak256 на каждом вызове не нужен.
contract Lollipop305FixedShardsVerifier is Lollipop305Article640Verifier {
    /// @dev Точные размеры совпадают с форматом Rust-бэкенда и не допускают усечения данных.
    uint256 private constant STICK_CACHE_BYTES = 57_312;
    uint256 private constant CYCLE_E_CACHE_BYTES = 115_488;
    uint256 private constant EHAT_CACHE_BYTES = 99_840;

    /// @dev Отдельные массивы упрощают чтение и позволяют независимо обновить конфигурацию новым deployment-ом.
    address[] private stickShards;
    address[] private cycleEShards;
    address[] private ehatShards;

    /// @notice Фиксирует data-контракты трех частей lollipop pipeline.
    /// @dev После развертывания изменить адреса невозможно. Новый набор кэшей требует нового verifier-а.
    constructor(address[] memory stick, address[] memory cycleE, address[] memory ehat) {
        require(stick.length != 0 && cycleE.length != 0 && ehat.length != 0, "empty shards");
        stickShards = stick;
        cycleEShards = cycleE;
        ehatShards = ehat;
    }

    /// @notice Возвращает количество data-контрактов для аудита конфигурации развернутого verifier-а.
    function shardCounts() external view returns (uint256 stick, uint256 cycleE, uint256 ehat) {
        return (stickShards.length, cycleEShards.length, ehatShards.length);
    }

    /// @notice Читает зарегистрированный stick-кэш и проверяет сокращенное отношение F = c^r.
    function verifyStickResidueFixedShards(uint256[8] memory c, uint256[8] memory cInv) external view returns (bool) {
        return _verifyResidue(_readCodeShards(stickShards, STICK_CACHE_BYTES), c, cInv);
    }

    /// @notice Читает зарегистрированный E_cycle-кэш и проверяет сокращенное отношение F = c^q.
    function verifyCycleEResidueFixedShards(uint256[8] memory c, uint256[8] memory cInv) external view returns (bool) {
        return _verifyCycleEResidue(_readCodeShards(cycleEShards, CYCLE_E_CACHE_BYTES), c, cInv);
    }

    /// @notice Читает зарегистрированный Ehat-кэш и проверяет c^p * F_den = F_num.
    function verifyEhatAteResidueFixedShards(uint256[4] memory px, uint256[4] memory py, uint256[12] memory c)
        external
        view
        returns (bool)
    {
        return _verifyEhatAteResidue(_readCodeShards(ehatShards, EHAT_CACHE_BYTES), px, py, c);
    }

    /// @notice Оптимальный fixed-shards Ehat-вызов: product-accumulator и c^p через q-Фробениус.
    /// @dev `cInv` передает пользователь/Rust-бэкенд, а контракт проверяет `c*cInv=1`.
    ///      Кэш линий по-прежнему читается только из адресов, зафиксированных в конструкторе.
    function verifyEhatAteResidueProductFrobeniusFixedShards(
        uint256[4] memory px,
        uint256[4] memory py,
        uint256[12] memory c,
        uint256[12] memory cInv
    ) external view returns (bool) {
        return _verifyEhatAteResidueProductFrobenius(_readCodeShards(ehatShards, EHAT_CACHE_BYTES), px, py, c, cInv);
    }

    /// @notice Собирает blob из runtime-кода нескольких data-контрактов.
    /// @dev Каждый shard обязан иметь ненулевой код. Суммарный размер должен точно совпасть
    ///      с ожидаемым: лишние и недостающие байты означают некорректную deployment-конфигурацию.
    function _readCodeShards(address[] storage shards, uint256 expectedBytes) private view returns (bytes memory blob) {
        blob = new bytes(expectedBytes);
        uint256 out;
        for (uint256 i; i < shards.length; ++i) {
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
}
