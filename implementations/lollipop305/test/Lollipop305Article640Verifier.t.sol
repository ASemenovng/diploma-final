// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Test} from "forge-std/Test.sol";
import {Lollipop305Article640Verifier} from "../src/Lollipop305Article640Verifier.sol";

contract Lollipop305Article640VerifierTest is Test {
    Lollipop305Article640Verifier private verifier;
    bytes private lines;
    uint256[8] private core;
    uint256[8] private c;
    uint256[8] private cInv;

    function setUp() public {
        verifier = new Lollipop305Article640Verifier();
        bytes memory data = vm.parseBytes(vm.readFile("docs/lollipop305_article640_fixture.words.hex"));
        uint256 steps = _word(data, 0);
        uint256 lineBytes = steps * 9 * 32;
        lines = _slice(data, 32, lineBytes);
        uint256 o = 32 + lineBytes;
        core = _readFp4(data, o);
        o += 8 * 32;
        c = _readFp4(data, o);
        o += 8 * 32;
        cInv = _readFp4(data, o);
    }

    function testMillerCoreMatchesRustFixture() public view {
        assertTrue(verifier.verifyMillerCore(lines, core));
    }

    function testDirectFinalExponentAcceptsRustFixture() public view {
        assertTrue(verifier.verifyDirectFinalExponent(lines));
    }

    function testResidueWitnessAcceptsRustFixture() public view {
        assertTrue(verifier.verifyResidue(lines, c, cInv));
    }

    function testRejectsTamperedLine() public view {
        bytes memory bad = lines;
        bad[100] = bytes1(uint8(bad[100]) ^ 1);
        assertFalse(verifier.verifyMillerCore(bad, core));
    }

    function testGasReport_lollipop305Article640Verifier() public view {
        verifier.verifyMillerCore(lines, core);
        verifier.verifyDirectFinalExponent(lines);
        verifier.verifyResidue(lines, c, cInv);
    }

    function _readFp4(bytes memory data, uint256 o) private pure returns (uint256[8] memory out) {
        for (uint256 i; i < 8; ++i) {
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
