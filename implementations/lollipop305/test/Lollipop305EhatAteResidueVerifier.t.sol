// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Test} from "forge-std/Test.sol";
import {Lollipop305Article640Verifier} from "../src/Lollipop305Article640Verifier.sol";

contract Lollipop305EhatAteResidueVerifierTest is Test {
    Lollipop305Article640Verifier private verifier;
    bytes private lines;
    uint256[4] private px;
    uint256[4] private py;
    uint256[12] private c;
    uint256[12] private fNum;
    uint256[12] private fDen;

    function setUp() public {
        verifier = new Lollipop305Article640Verifier();
        bytes memory data = vm.parseBytes(vm.readFile("docs/lollipop305_cycle_ehat_ate_residue_fixture.words.hex"));
        uint256 steps = _word(data, 0);
        uint256 lineBytes = steps * 13 * 32;
        lines = _slice(data, 32, lineBytes);
        uint256 o = 32 + lineBytes;
        px = _readFq2(data, o);
        o += 4 * 32;
        py = _readFq2(data, o);
        o += 4 * 32;
        c = _readFq6(data, o);
        o += 12 * 32;
        fNum = _readFq6(data, o);
        o += 12 * 32;
        fDen = _readFq6(data, o);
    }

    function testEhatAteResidueAcceptsRustFixture() public view {
        (uint256[12] memory gotNum, uint256[12] memory gotDen) = verifier.ehatAteResidueRaw(lines, px, py);
        for (uint256 i; i < 12; ++i) {
            assertEq(gotNum[i], fNum[i], "fNum mismatch");
            assertEq(gotDen[i], fDen[i], "fDen mismatch");
        }
        assertTrue(verifier.verifyEhatAteResidue(lines, px, py, c));
    }

    function testEhatAteResidueRejectsTamperedLine() public view {
        bytes memory bad = lines;
        bad[96] = bytes1(uint8(bad[96]) ^ 1);
        assertFalse(verifier.verifyEhatAteResidue(bad, px, py, c));
    }

    function testEhatAteResidueRejectsTamperedWitness() public view {
        uint256[12] memory badC = c;
        badC[0] ^= 1;
        assertFalse(verifier.verifyEhatAteResidue(lines, px, py, badC));
    }

    function testEhatAteResidueDigestDependsOnRustValues() public view {
        bytes32 digest = verifier.ehatAteResidueDigest(lines, px, py, c);
        assertNotEq(digest, bytes32(0));
        assertNotEq(fNum[0], fDen[0], "fixture should not be the trivial fNum=fDen case");
    }

    function testGasReport_ehatAteResidue() public view {
        verifier.verifyEhatAteResidue(lines, px, py, c);
    }

    function _readFq2(bytes memory data, uint256 o) private pure returns (uint256[4] memory out) {
        for (uint256 i; i < 4; ++i) out[i] = _word(data, o + i * 32);
    }

    function _readFq6(bytes memory data, uint256 o) private pure returns (uint256[12] memory out) {
        for (uint256 i; i < 12; ++i) out[i] = _word(data, o + i * 32);
    }

    function _word(bytes memory data, uint256 offset) private pure returns (uint256 value) {
        assembly ("memory-safe") {
            value := mload(add(add(data, 0x20), offset))
        }
    }

    function _slice(bytes memory data, uint256 start, uint256 len) private pure returns (bytes memory out) {
        out = new bytes(len);
        for (uint256 i; i < len; ++i) out[i] = data[start + i];
    }
}
