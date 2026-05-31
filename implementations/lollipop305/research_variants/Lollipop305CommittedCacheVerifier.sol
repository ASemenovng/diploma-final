// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Lollipop305Article640Verifier} from "../src/Lollipop305Article640Verifier.sol";

/// @notice Исследовательский fixed-cache режим: пользователь передает линии в calldata, контракт сверяет commitment.
/// @dev Контракт нужен для честного сравнения с code-shards. В production fixed-cache режиме выгоднее
///      не передавать крупные blob при каждом вызове, а читать их из заранее зафиксированных data-контрактов.
contract Lollipop305CommittedCacheVerifier is Lollipop305Article640Verifier {
    /// @dev Точные размеры исключают неоднозначную сериализацию и усечение подготовленных линий.
    uint256 private constant STICK_CACHE_BYTES = 57_312;
    uint256 private constant CYCLE_E_CACHE_BYTES = 115_488;
    uint256 private constant EHAT_CACHE_BYTES = 99_840;

    /// @dev Разные домены не позволяют использовать blob одной кривой вместо blob другой кривой.
    bytes32 private constant STICK_CACHE_DOMAIN = keccak256("LOLLIPOP305_STICK_CACHE_V1");
    bytes32 private constant CYCLE_E_CACHE_DOMAIN = keccak256("LOLLIPOP305_CYCLE_E_CACHE_V1");
    bytes32 private constant EHAT_CACHE_DOMAIN = keccak256("LOLLIPOP305_EHAT_CACHE_V1");

    /// @notice Неизменяемые хеши кэшей фиксируются при развертывании verifier-а.
    bytes32 public immutable STICK_CACHE_COMMITMENT;
    bytes32 public immutable CYCLE_E_CACHE_COMMITMENT;
    bytes32 public immutable EHAT_CACHE_COMMITMENT;

    constructor(bytes32 stickCommitment, bytes32 cycleECommitment, bytes32 ehatCommitment) {
        STICK_CACHE_COMMITMENT = stickCommitment;
        CYCLE_E_CACHE_COMMITMENT = cycleECommitment;
        EHAT_CACHE_COMMITMENT = ehatCommitment;
    }

    /// @notice Вычисляет commitment stick-кэша в строго определенном формате.
    function hashStickCache(bytes memory preparedLines) public pure returns (bytes32) {
        return _hashCache(STICK_CACHE_DOMAIN, preparedLines, STICK_CACHE_BYTES);
    }

    /// @notice Вычисляет commitment кэша первой cycle-кривой.
    function hashCycleECache(bytes memory preparedLines) public pure returns (bytes32) {
        return _hashCache(CYCLE_E_CACHE_DOMAIN, preparedLines, CYCLE_E_CACHE_BYTES);
    }

    /// @notice Вычисляет commitment Ehat prepared-Ate кэша.
    function hashEhatCache(bytes memory preparedLines) public pure returns (bytes32) {
        return _hashCache(EHAT_CACHE_DOMAIN, preparedLines, EHAT_CACHE_BYTES);
    }

    /// @notice Проверяет stick-отношение только после подтверждения неизменности blob линий.
    function verifyStickResidueCommitted(bytes memory preparedLines, uint256[8] memory c, uint256[8] memory cInv)
        external
        view
        returns (bool)
    {
        if (hashStickCache(preparedLines) != STICK_CACHE_COMMITMENT) return false;
        return _verifyResidue(preparedLines, c, cInv);
    }

    /// @notice Проверяет E_cycle-отношение только после подтверждения неизменности blob линий.
    function verifyCycleEResidueCommitted(bytes memory preparedLines, uint256[8] memory c, uint256[8] memory cInv)
        external
        view
        returns (bool)
    {
        if (hashCycleECache(preparedLines) != CYCLE_E_CACHE_COMMITMENT) return false;
        return _verifyCycleEResidue(preparedLines, c, cInv);
    }

    /// @notice Проверяет Ehat-отношение только после подтверждения неизменности prepared-Ate кэша.
    function verifyEhatAteResidueCommitted(
        bytes memory preparedLines,
        uint256[4] memory px,
        uint256[4] memory py,
        uint256[12] memory c
    ) external view returns (bool) {
        if (hashEhatCache(preparedLines) != EHAT_CACHE_COMMITMENT) return false;
        return _verifyEhatAteResidue(preparedLines, px, py, c);
    }

    /// @notice Хеширует домен формата, точную длину и хеш содержимого blob.
    /// @dev Двойное хеширование делает код компактным и не меняет свойство привязки:
    ///      любое изменение байта меняет внутренний keccak256 и итоговый commitment.
    function _hashCache(bytes32 domain, bytes memory preparedLines, uint256 expectedBytes)
        private
        pure
        returns (bytes32)
    {
        require(preparedLines.length == expectedBytes, "bad cache length");
        return keccak256(abi.encodePacked(domain, preparedLines.length, keccak256(preparedLines)));
    }
}
