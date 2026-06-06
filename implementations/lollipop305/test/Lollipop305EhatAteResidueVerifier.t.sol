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
    uint256[12] private cInv;
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
        cInv = [
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

    function testPackedEhatTraceMatchesLegacyAndRustFixture() public view {
        (uint256[12] memory packedNum, uint256[12] memory packedDen) = verifier.ehatAteResidueRawPacked(lines, px, py);
        for (uint256 i; i < 12; ++i) {
            assertEq(packedNum[i], fNum[i], "packed fNum mismatch");
            assertEq(packedDen[i], fDen[i], "packed fDen mismatch");
        }
    }

    function testPackedEhatResidueAcceptsRustFixture() public view {
        assertTrue(verifier.verifyEhatAteResiduePacked(lines, px, py, c));
    }

    function testGasReport_packedEhatAteResidue() public view {
        verifier.verifyEhatAteResiduePacked(lines, px, py, c);
    }

    function testProductTraceMatchesRustFixture() public view {
        (uint256[12] memory productNum, uint256[12] memory productDen) =
            verifier.ehatAteResidueRawProductPacked(lines, px, py);
        for (uint256 i; i < 12; ++i) {
            assertEq(productNum[i], fNum[i], "product fNum mismatch");
            assertEq(productDen[i], fDen[i], "product fDen mismatch");
        }
    }

    function testProductFrobeniusEhatResidueAcceptsRustFixture() public view {
        assertTrue(verifier.verifyEhatAteResidueProductFrobenius(lines, px, py, c, cInv));
    }

    function testProductFrobeniusRejectsTamperedInverse() public view {
        uint256[12] memory badInv = cInv;
        badInv[0] ^= 1;
        assertFalse(verifier.verifyEhatAteResidueProductFrobenius(lines, px, py, c, badInv));
    }

    function testGasReport_productFrobeniusEhatAteResidue() public view {
        verifier.verifyEhatAteResidueProductFrobenius(lines, px, py, c, cInv);
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
