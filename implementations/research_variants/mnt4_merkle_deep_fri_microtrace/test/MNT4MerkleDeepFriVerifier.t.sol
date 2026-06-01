// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Test} from "forge-std/Test.sol";
import {MNT4MerkleDeepFriVerifier} from "../src/MNT4MerkleDeepFriVerifier.sol";

contract MNT4MerkleDeepFriVerifierTest is Test {
    MNT4MerkleDeepFriVerifier private verifier;
    MNT4MerkleDeepFriVerifier.G1Point private p;
    MNT4MerkleDeepFriVerifier.G1Point private r;
    MNT4MerkleDeepFriVerifier.Fq4 private c;
    MNT4MerkleDeepFriVerifier.Fq4 private cInv;
    bytes private proof;

    function setUp() public {
        bytes memory fixture = vm.parseBytes(
            vm.readFile("rust/microtrace_backend/artifacts/benchmark-32q/solidity_fixture.hex")
        );
        uint256 offset;
        bytes32 configDigest = _bytes32(fixture, offset);
        offset += 32;
        bytes32 rootFixed = _bytes32(fixture, offset);
        offset += 32;
        MNT4MerkleDeepFriVerifier.Fq memory omega;
        MNT4MerkleDeepFriVerifier.Fq memory eta;
        MNT4MerkleDeepFriVerifier.Fq memory gamma;
        (omega, offset) = _fq(fixture, offset);
        (eta, offset) = _fq(fixture, offset);
        (gamma, offset) = _fq(fixture, offset);
        (p, offset) = _g1(fixture, offset);
        (r, offset) = _g1(fixture, offset);
        (c, offset) = _fq4(fixture, offset);
        (cInv, offset) = _fq4(fixture, offset);
        assertEq(offset, fixture.length);
        verifier = new MNT4MerkleDeepFriVerifier(configDigest, rootFixed, omega, eta, gamma);
        proof = vm.parseBytes(vm.readFile("rust/microtrace_backend/artifacts/benchmark-32q/proof.hex"));
    }

    function testGas_verifyEquationMicrotraceBenchmark32() public view {
        assertTrue(verifier.verifyEquationMicrotrace(p, r, c, cInv, proof));
    }

    function testGas_verifyEquationMicrotraceConservative128() public view {
        bytes memory conservative =
            vm.parseBytes(vm.readFile("rust/microtrace_backend/artifacts/conservative-128q/proof.hex"));
        assertTrue(verifier.verifyEquationMicrotrace(p, r, c, cInv, conservative));
    }

    function testRejectsTamperedProof() public view {
        bytes memory bad = proof;
        bad[bad.length - 1] ^= 0x01;
        assertFalse(verifier.verifyEquationMicrotrace(p, r, c, cInv, bad));
    }

    function testRejectsWrongPoint() public view {
        MNT4MerkleDeepFriVerifier.G1Point memory badP = p;
        badP.x.d0 ^= 0x01;
        assertFalse(verifier.verifyEquationMicrotrace(badP, r, c, cInv, proof));
    }

    function testRejectsWrongSecondPoint() public view {
        MNT4MerkleDeepFriVerifier.G1Point memory badR = r;
        badR.y.d0 ^= 0x01;
        assertFalse(verifier.verifyEquationMicrotrace(p, badR, c, cInv, proof));
    }

    function testRejectsWrongResidueWitness() public view {
        MNT4MerkleDeepFriVerifier.Fq4 memory badC = c;
        badC.a0.d0 ^= 0x01;
        assertFalse(verifier.verifyEquationMicrotrace(p, r, badC, cInv, proof));
    }

    function testRejectsWrongResidueWitnessInverse() public view {
        MNT4MerkleDeepFriVerifier.Fq4 memory badCInv = cInv;
        badCInv.a3.d0 ^= 0x01;
        assertFalse(verifier.verifyEquationMicrotrace(p, r, c, badCInv, proof));
    }

    function testRejectsTamperedTraceRoot() public view {
        bytes memory bad = proof;
        bad[16] ^= 0x01;
        assertFalse(verifier.verifyEquationMicrotrace(p, r, c, cInv, bad));
    }

    function testRejectsTamperedOodValue() public view {
        bytes memory bad = proof;
        bad[336] ^= 0x01;
        assertFalse(verifier.verifyEquationMicrotrace(p, r, c, cInv, bad));
    }

    function testRejectsTamperedFinalPolynomial() public view {
        bytes memory bad = proof;
        bad[2928] ^= 0x01;
        assertFalse(verifier.verifyEquationMicrotrace(p, r, c, cInv, bad));
    }

    function testRejectsTamperedDeepRoot() public view {
        bytes memory bad = proof;
        bad[80] ^= 0x01;
        assertFalse(verifier.verifyEquationMicrotrace(p, r, c, cInv, bad));
    }

    function testRejectsTamperedDeepInverse() public view {
        bytes memory bad = proof;
        bad[3700] ^= 0x01;
        assertFalse(verifier.verifyEquationMicrotrace(p, r, c, cInv, bad));
    }

    function testRejectsTamperedTraceLeaf() public view {
        bytes memory bad = proof;
        bad[19058] ^= 0x01;
        assertFalse(verifier.verifyEquationMicrotrace(p, r, c, cInv, bad));
    }

    function testRejectsMissingFrontierHash() public view {
        bytes memory bad = proof;
        uint256 frontierOffset = 19056 + 2 + _u16(bad, 19056) * 4 * 96;
        _setU16(bad, frontierOffset, _u16(bad, frontierOffset) - 1);
        assertFalse(verifier.verifyEquationMicrotrace(p, r, c, cInv, bad));
    }

    function testRejectsExtraFrontierHash() public view {
        bytes memory bad = proof;
        uint256 frontierOffset = 19056 + 2 + _u16(bad, 19056) * 4 * 96;
        _setU16(bad, frontierOffset, _u16(bad, frontierOffset) + 1);
        assertFalse(verifier.verifyEquationMicrotrace(p, r, c, cInv, bad));
    }

    function testRejectsReorderedFrontierHashes() public view {
        bytes memory bad = proof;
        uint256 frontierOffset = 19056 + 2 + _u16(bad, 19056) * 4 * 96 + 2;
        for (uint256 i; i < 32; ++i) {
            (bad[frontierOffset + i], bad[frontierOffset + 32 + i]) =
                (bad[frontierOffset + 32 + i], bad[frontierOffset + i]);
        }
        assertFalse(verifier.verifyEquationMicrotrace(p, r, c, cInv, bad));
    }

    function testRejectsTamperedFixedLeaf() public view {
        bytes memory bad = proof;
        uint256 fixedStart = _skipSection(bad, 19056, 4 * 96, true);
        bad[fixedStart + 2] ^= 0x01;
        assertFalse(verifier.verifyEquationMicrotrace(p, r, c, cInv, bad));
    }

    function testRejectsTamperedQuotientLeaf() public view {
        bytes memory bad = proof;
        uint256 fixedStart = _skipSection(bad, 19056, 4 * 96, true);
        uint256 quotientStart = _skipSection(bad, fixedStart, 17 * 96, true);
        bad[quotientStart + 2] ^= 0x01;
        assertFalse(verifier.verifyEquationMicrotrace(p, r, c, cInv, bad));
    }

    function testRejectsTamperedFriLeaf() public view {
        bytes memory bad = proof;
        uint256 cursor = _skipSection(bad, 19056, 4 * 96, true);
        cursor = _skipSection(bad, cursor, 17 * 96, true);
        cursor = _skipSection(bad, cursor, 2 * 96, true);
        cursor = _skipSection(bad, cursor, 0, false);
        bad[cursor + 2] ^= 0x01;
        assertFalse(verifier.verifyEquationMicrotrace(p, r, c, cInv, bad));
    }

    function testRejectsWrongConfigDigest() public {
        MNT4MerkleDeepFriVerifier wrong =
            new MNT4MerkleDeepFriVerifier(bytes32(uint256(verifier.CONFIG_DIGEST()) ^ 1), verifier.ROOT_FIXED(), _omega(), _eta(), _gamma());
        assertFalse(wrong.verifyEquationMicrotrace(p, r, c, cInv, proof));
    }

    function testRejectsNonCanonicalFieldElement() public view {
        MNT4MerkleDeepFriVerifier.G1Point memory badP = p;
        badP.x = MNT4MerkleDeepFriVerifier.Fq(
            0x1c4c62d92c41110229022eee2cdadb7f997505b8fafed5eb7e8f96c97d873,
            0x7fdb925e8a0ed8d99d124d9a15af79db117e776f218059db80f0da5cb537e38,
            0x685acce9767254a4638810719ac425f0e39d54522cdd119f5e9063de245e8001
        );
        assertFalse(verifier.verifyEquationMicrotrace(badP, r, c, cInv, proof));
    }

    function _fq(bytes memory data, uint256 offset)
        private
        pure
        returns (MNT4MerkleDeepFriVerifier.Fq memory value, uint256 next)
    {
        value.d2 = _word(data, offset);
        value.d1 = _word(data, offset + 32);
        value.d0 = _word(data, offset + 64);
        next = offset + 96;
    }

    function _fq4(bytes memory data, uint256 offset)
        private
        pure
        returns (MNT4MerkleDeepFriVerifier.Fq4 memory value, uint256 next)
    {
        (value.a0, offset) = _fq(data, offset);
        (value.a1, offset) = _fq(data, offset);
        (value.a2, offset) = _fq(data, offset);
        (value.a3, offset) = _fq(data, offset);
        next = offset;
    }

    function _g1(bytes memory data, uint256 offset)
        private
        pure
        returns (MNT4MerkleDeepFriVerifier.G1Point memory value, uint256 next)
    {
        (value.x, offset) = _fq(data, offset);
        (value.y, offset) = _fq(data, offset);
        next = offset;
    }

    function _bytes32(bytes memory data, uint256 offset) private pure returns (bytes32 value) {
        assembly ("memory-safe") {
            value := mload(add(add(data, 0x20), offset))
        }
    }

    function _word(bytes memory data, uint256 offset) private pure returns (uint256 value) {
        assembly ("memory-safe") {
            value := mload(add(add(data, 0x20), offset))
        }
    }

    function _skipSection(bytes memory data, uint256 offset, uint256 payloadBytes, bool hasPayloads)
        private
        pure
        returns (uint256)
    {
        uint256 leaves = _u16(data, offset);
        offset += 2;
        if (hasPayloads) offset += leaves * payloadBytes;
        uint256 frontier = _u16(data, offset);
        return offset + 2 + frontier * 32;
    }

    function _u16(bytes memory data, uint256 offset) private pure returns (uint256 value) {
        value = (uint256(uint8(data[offset])) << 8) | uint256(uint8(data[offset + 1]));
    }

    function _setU16(bytes memory data, uint256 offset, uint256 value) private pure {
        data[offset] = bytes1(uint8(value >> 8));
        data[offset + 1] = bytes1(uint8(value));
    }

    function _omega() private view returns (MNT4MerkleDeepFriVerifier.Fq memory value) {
        bytes memory fixture = vm.parseBytes(vm.readFile("rust/microtrace_backend/artifacts/benchmark-32q/solidity_fixture.hex"));
        (value,) = _fq(fixture, 64);
    }

    function _eta() private view returns (MNT4MerkleDeepFriVerifier.Fq memory value) {
        bytes memory fixture = vm.parseBytes(vm.readFile("rust/microtrace_backend/artifacts/benchmark-32q/solidity_fixture.hex"));
        (value,) = _fq(fixture, 160);
    }

    function _gamma() private view returns (MNT4MerkleDeepFriVerifier.Fq memory value) {
        bytes memory fixture = vm.parseBytes(vm.readFile("rust/microtrace_backend/artifacts/benchmark-32q/solidity_fixture.hex"));
        (value,) = _fq(fixture, 256);
    }
}
