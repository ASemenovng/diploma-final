// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Test} from "forge-std/Test.sol";
import {Lollipop305CommittedCacheVerifier} from "../research_variants/Lollipop305CommittedCacheVerifier.sol";
import {Lollipop305FixedShardsVerifier} from "../src/Lollipop305FixedShardsVerifier.sol";

/// @notice Data-контракт хранит переданный blob непосредственно в runtime-коде.
/// @dev Код не исполняется: проверяющий контракт читает его инструкцией EXTCODECOPY.
contract Lollipop305CodeShardStore {
    constructor(bytes memory blob) payable {
        assembly ("memory-safe") {
            return(add(blob, 0x20), mload(blob))
        }
    }
}

/// @notice Сравнивает два безопасных fixed-cache режима на одинаковых fixtures Rust-бэкенда.
contract Lollipop305CacheBindingModesTest is Test {
    uint256 private constant SHARD_BYTES = 23_040;

    Lollipop305CommittedCacheVerifier private committed;
    Lollipop305FixedShardsVerifier private fixedShards;

    bytes private stickLines;
    uint256[8] private stickC;
    uint256[8] private stickCInv;

    bytes private cycleELines;
    uint256[8] private cycleEC;
    uint256[8] private cycleECInv;

    bytes private ehatLines;
    uint256[4] private ehatPx;
    uint256[4] private ehatPy;
    uint256[12] private ehatC;
    uint256[12] private ehatCInv;

    address[] private stickShards;
    address[] private cycleEShards;
    address[] private ehatShards;

    function setUp() public {
        _loadStickFixture();
        _loadCycleEFixture();
        _loadEhatFixture();

        Lollipop305CommittedCacheVerifier helper =
            new Lollipop305CommittedCacheVerifier(bytes32(0), bytes32(0), bytes32(0));
        committed = new Lollipop305CommittedCacheVerifier(
            helper.hashStickCache(stickLines), helper.hashCycleECache(cycleELines), helper.hashEhatCache(ehatLines)
        );

        stickShards = _deployCodeShards(stickLines);
        cycleEShards = _deployCodeShards(cycleELines);
        ehatShards = _deployCodeShards(ehatLines);
        fixedShards = new Lollipop305FixedShardsVerifier(stickShards, cycleEShards, ehatShards);
    }

    /// @notice Проверяет совпадение результатов двух режимов для stick-части.
    function testStickResidueModesAcceptSameFixture() public view {
        assertTrue(committed.verifyStickResidueCommitted(stickLines, stickC, stickCInv));
        assertTrue(fixedShards.verifyStickResidueFixedShards(stickC, stickCInv));
    }

    /// @notice Проверяет совпадение результатов двух режимов для первой cycle-кривой.
    function testCycleEResidueModesAcceptSameFixture() public view {
        assertTrue(committed.verifyCycleEResidueCommitted(cycleELines, cycleEC, cycleECInv));
        assertTrue(fixedShards.verifyCycleEResidueFixedShards(cycleEC, cycleECInv));
    }

    /// @notice Проверяет совпадение результатов двух режимов для Ehat-части.
    function testEhatResidueModesAcceptSameFixture() public view {
        assertTrue(committed.verifyEhatAteResidueCommitted(ehatLines, ehatPx, ehatPy, ehatC));
        assertTrue(fixedShards.verifyEhatAteResidueFixedShards(ehatPx, ehatPy, ehatC));
        assertTrue(fixedShards.verifyEhatAteResidueProductFrobeniusFixedShards(ehatPx, ehatPy, ehatC, ehatCInv));
    }

    /// @notice Commitment должен отбрасывать подмененный stick-кэш до тяжелого вычисления.
    function testCommittedRejectsTamperedStickCache() public view {
        bytes memory bad = stickLines;
        bad[100] = bytes1(uint8(bad[100]) ^ 1);
        assertFalse(committed.verifyStickResidueCommitted(bad, stickC, stickCInv));
    }

    /// @notice Commitment должен отбрасывать подмененный E_cycle-кэш.
    function testCommittedRejectsTamperedCycleECache() public view {
        bytes memory bad = cycleELines;
        bad[100] = bytes1(uint8(bad[100]) ^ 1);
        assertFalse(committed.verifyCycleEResidueCommitted(bad, cycleEC, cycleECInv));
    }

    /// @notice Commitment должен отбрасывать подмененный Ehat-кэш.
    function testCommittedRejectsTamperedEhatCache() public view {
        bytes memory bad = ehatLines;
        bad[100] = bytes1(uint8(bad[100]) ^ 1);
        assertFalse(committed.verifyEhatAteResidueCommitted(bad, ehatPx, ehatPy, ehatC));
    }

    /// @notice Если при развертывании зафиксирован испорченный shard, проверка не должна пройти.
    function testFixedShardsRejectsTamperedDeploymentCache() public {
        bytes memory bad = stickLines;
        bad[100] = bytes1(uint8(bad[100]) ^ 1);
        Lollipop305FixedShardsVerifier badVerifier =
            new Lollipop305FixedShardsVerifier(_deployCodeShards(bad), cycleEShards, ehatShards);
        assertFalse(badVerifier.verifyStickResidueFixedShards(stickC, stickCInv));
    }

    /// @notice Gas-report для трех commitment-проверок с передачей blob в calldata.
    function testGasReport_committedCacheModes() public view {
        assertTrue(committed.verifyStickResidueCommitted(stickLines, stickC, stickCInv));
        assertTrue(committed.verifyCycleEResidueCommitted(cycleELines, cycleEC, cycleECInv));
        assertTrue(committed.verifyEhatAteResidueCommitted(ehatLines, ehatPx, ehatPy, ehatC));
    }

    /// @notice Gas-report для трех code-shards проверок без передачи blob пользователем.
    function testGasReport_fixedShardsModes() public view {
        assertTrue(fixedShards.verifyStickResidueFixedShards(stickC, stickCInv));
        assertTrue(fixedShards.verifyCycleEResidueFixedShards(cycleEC, cycleECInv));
        assertTrue(fixedShards.verifyEhatAteResidueFixedShards(ehatPx, ehatPy, ehatC));
        assertTrue(fixedShards.verifyEhatAteResidueProductFrobeniusFixedShards(ehatPx, ehatPy, ehatC, ehatCInv));
    }

    /// @notice Печатает точную длину ABI-calldata и стоимость байтов calldata для сравнения режимов.
    function testReport_calldataCost() public {
        bytes memory committedStick =
            abi.encodeCall(committed.verifyStickResidueCommitted, (stickLines, stickC, stickCInv));
        bytes memory fixedStick = abi.encodeCall(fixedShards.verifyStickResidueFixedShards, (stickC, stickCInv));
        bytes memory committedCycle =
            abi.encodeCall(committed.verifyCycleEResidueCommitted, (cycleELines, cycleEC, cycleECInv));
        bytes memory fixedCycle = abi.encodeCall(fixedShards.verifyCycleEResidueFixedShards, (cycleEC, cycleECInv));
        bytes memory committedEhat =
            abi.encodeCall(committed.verifyEhatAteResidueCommitted, (ehatLines, ehatPx, ehatPy, ehatC));
        bytes memory fixedEhat = abi.encodeCall(fixedShards.verifyEhatAteResidueFixedShards, (ehatPx, ehatPy, ehatC));
        bytes memory fixedEhatOptimized =
            abi.encodeCall(fixedShards.verifyEhatAteResidueProductFrobeniusFixedShards, (ehatPx, ehatPy, ehatC, ehatCInv));

        emit log_named_uint("commitment stick calldata bytes", committedStick.length);
        emit log_named_uint("fixed-shards stick calldata bytes", fixedStick.length);
        emit log_named_uint("commitment stick calldata gas", _calldataGas(committedStick));
        emit log_named_uint("fixed-shards stick calldata gas", _calldataGas(fixedStick));
        emit log_named_uint("commitment cycle-E calldata bytes", committedCycle.length);
        emit log_named_uint("fixed-shards cycle-E calldata bytes", fixedCycle.length);
        emit log_named_uint("commitment cycle-E calldata gas", _calldataGas(committedCycle));
        emit log_named_uint("fixed-shards cycle-E calldata gas", _calldataGas(fixedCycle));
        emit log_named_uint("commitment Ehat calldata bytes", committedEhat.length);
        emit log_named_uint("fixed-shards Ehat calldata bytes", fixedEhat.length);
        emit log_named_uint("commitment Ehat calldata gas", _calldataGas(committedEhat));
        emit log_named_uint("fixed-shards Ehat calldata gas", _calldataGas(fixedEhat));
        emit log_named_uint("fixed-shards optimized Ehat calldata bytes", fixedEhatOptimized.length);
        emit log_named_uint("fixed-shards optimized Ehat calldata gas", _calldataGas(fixedEhatOptimized));
    }

    function _loadStickFixture() private {
        bytes memory data = vm.parseBytes(vm.readFile("docs/lollipop305_article640_fixture.words.hex"));
        uint256 lineBytes = _word(data, 0) * 9 * 32;
        stickLines = _slice(data, 32, lineBytes);
        uint256 o = 32 + lineBytes + 8 * 32;
        stickC = _readFp4(data, o);
        stickCInv = _readFp4(data, o + 8 * 32);
    }

    function _loadCycleEFixture() private {
        bytes memory data = vm.readFileBinary("docs/lollipop305_cycle_e_article640_fixture.words.bin");
        uint256 lineBytes = _word(data, 0) * 9 * 32;
        cycleELines = _slice(data, 32, lineBytes);
        uint256 o = 32 + lineBytes + 8 * 32;
        cycleEC = _readFp4(data, o);
        cycleECInv = _readFp4(data, o + 8 * 32);
    }

    function _loadEhatFixture() private {
        bytes memory data = vm.parseBytes(vm.readFile("docs/lollipop305_cycle_ehat_ate_residue_fixture.words.hex"));
        uint256 lineBytes = _word(data, 0) * 13 * 32;
        ehatLines = _slice(data, 32, lineBytes);
        uint256 o = 32 + lineBytes;
        ehatPx = _readFq2(data, o);
        ehatPy = _readFq2(data, o + 4 * 32);
        ehatC = _readFq6(data, o + 8 * 32);
        ehatCInv = [
            uint256(0x4e67f6aa7048b5f7286c79d12a08adcaa236b0a397e79f3e7d5b9e10fe6c0d2c),
            uint256(0x1eaf206656d0b),
            uint256(0xaf69299ed4d754202a58225b8f17e21f3d6f879def194bdd5a070664c1cec89),
            uint256(0x19e4d1032b70d),
            uint256(0x41449e85d1b45e9b3a5ef353758b9dc99414ea172497f9fa01cbd70cc289703),
            uint256(0xf37864e255ff),
            uint256(0xc11997be73b1276a100863438f42092976c7f8fd47fddcd6b719792b0a84dbc7),
            uint256(0x17926ca365702),
            uint256(0x822a697d17e4c8891e3398b6c2e4e7a5c7e08a5486905cf40f87c06481c6ab43),
            uint256(0x1defa2666beb),
            uint256(0x841785963bc12f94b666ae33f86ea2b7bbd3c721245e6955b957069b7fbdb693),
            uint256(0xaadf6175da11)
        ];
    }

    function _deployCodeShards(bytes memory blob) private returns (address[] memory shards) {
        uint256 count = (blob.length + SHARD_BYTES - 1) / SHARD_BYTES;
        shards = new address[](count);
        uint256 offset;
        for (uint256 i; i < count; ++i) {
            uint256 len = blob.length - offset;
            if (len > SHARD_BYTES) len = SHARD_BYTES;
            shards[i] = address(new Lollipop305CodeShardStore(_slice(blob, offset, len)));
            offset += len;
        }
        require(offset == blob.length, "bad shard split");
    }

    function _calldataGas(bytes memory data) private pure returns (uint256 gasCost) {
        for (uint256 i; i < data.length; ++i) {
            gasCost += data[i] == bytes1(0) ? 4 : 16;
        }
    }

    function _readFp4(bytes memory data, uint256 o) private pure returns (uint256[8] memory out) {
        for (uint256 i; i < 8; ++i) {
            out[i] = _word(data, o + i * 32);
        }
    }

    function _readFq2(bytes memory data, uint256 o) private pure returns (uint256[4] memory out) {
        for (uint256 i; i < 4; ++i) {
            out[i] = _word(data, o + i * 32);
        }
    }

    function _readFq6(bytes memory data, uint256 o) private pure returns (uint256[12] memory out) {
        for (uint256 i; i < 12; ++i) {
            out[i] = _word(data, o + i * 32);
        }
    }

    function _word(bytes memory data, uint256 offset) private pure returns (uint256 value) {
        assembly ("memory-safe") {
            value := mload(add(add(data, 0x20), offset))
        }
    }

    function _slice(bytes memory data, uint256 start, uint256 len) private pure returns (bytes memory out) {
        out = new bytes(len);
        for (uint256 i; i < len; ++i) {
            out[i] = data[start + i];
        }
    }
}
