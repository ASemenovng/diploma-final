// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Test} from "forge-std/Test.sol";
import {Lollipop305Article640Verifier} from "../src/Lollipop305Article640Verifier.sol";

contract Lollipop305CycleECoreVerifierTest is Test {
    Lollipop305Article640Verifier private verifier;
    bytes private lines;
    uint256[8] private core;
    uint256[8] private c;
    uint256[8] private cInv;

    function setUp() public {
        verifier = new Lollipop305Article640Verifier();
        bytes memory data = vm.readFileBinary("docs/lollipop305_cycle_e_article640_fixture.words.bin");
        uint256 steps = _word(data, 0);
        uint256 lineBytes = steps * 9 * 32;
        lines = _slice(data, 32, lineBytes);
        core = _readFp4(data, 32 + lineBytes);
        c = _readFp4(data, 32 + lineBytes + 8 * 32);
        cInv = _readFp4(data, 32 + lineBytes + 16 * 32);
    }

    function testCycleEMillerCoreMatchesRustFixture() public view {
        assertTrue(verifier.verifyMillerCore(lines, core));
    }

    function testCycleEMillerCoreRejectsTamperedLine() public view {
        bytes memory bad = lines;
        bad[777] = bytes1(uint8(bad[777]) ^ 1);
        assertFalse(verifier.verifyMillerCore(bad, core));
    }

    function testGasReport_cycleEMillerCore() public view {
        verifier.verifyMillerCore(lines, core);
    }

    function testCycleEDirectFinalExponentAcceptsRustFixture() public view {
        assertTrue(verifier.verifyCycleEDirectFinalExponent(lines));
    }

    function testCycleEResidueAcceptsRustFixture() public view {
        assertTrue(verifier.verifyCycleEResidue(lines, c, cInv));
    }

    function testCycleEResidueRejectsTamperedWitness() public view {
        uint256[8] memory badC = c;
        badC[0] ^= 1;
        assertFalse(verifier.verifyCycleEResidue(lines, badC, cInv));
    }

    function testGasReport_cycleEDirectFinalExponent() public view {
        verifier.verifyCycleEDirectFinalExponent(lines);
    }

    function testGasReport_cycleEResidue() public view {
        verifier.verifyCycleEResidue(lines, c, cInv);
    }

    function _readFp4(bytes memory data, uint256 o) private pure returns (uint256[8] memory out) {
        for (uint256 i; i < 8; ++i) out[i] = _word(data, o + i * 32);
    }

    function _word(bytes memory data, uint256 offset) private pure returns (uint256 value) {
        assembly ("memory-safe") { value := mload(add(add(data, 0x20), offset)) }
    }

    function _slice(bytes memory data, uint256 start, uint256 len) private pure returns (bytes memory out) {
        out = new bytes(len);
        for (uint256 i; i < len; ++i) out[i] = data[start + i];
    }
}
