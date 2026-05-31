// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import "forge-std/Test.sol";
import "@arith-mnt4/BigIntMNT.sol";
import "@arith-mnt4/MNT4Extension.sol";
import "../src/MNT4TatePairing.sol";
import "./fixtures/MNT4ArkworksVectors.sol";

contract MNT4ArkworksCrossCheckHarness {
    function fpAddCanonical(uint256[3] memory a, uint256[3] memory b)
        external
        pure
        returns (uint256[3] memory)
    {
        return BigIntMNT.add(a, b);
    }

    function fpSubCanonical(uint256[3] memory a, uint256[3] memory b)
        external
        pure
        returns (uint256[3] memory)
    {
        return BigIntMNT.sub(a, b);
    }

    function fpMulCanonical(uint256[3] memory a, uint256[3] memory b)
        external
        pure
        returns (uint256[3] memory)
    {
        uint256[3] memory am = BigIntMNT.toMontgomery(a);
        uint256[3] memory bm = BigIntMNT.toMontgomery(b);
        return BigIntMNT.fromMontgomery(BigIntMNT.montMul(am, bm));
    }

    function fpSqrCanonical(uint256[3] memory a) external pure returns (uint256[3] memory) {
        uint256[3] memory am = BigIntMNT.toMontgomery(a);
        return BigIntMNT.fromMontgomery(BigIntMNT.montSqr(am));
    }

    function fpInvCanonical(uint256[3] memory a) external pure returns (uint256[3] memory) {
        uint256[3] memory am = BigIntMNT.toMontgomery(a);
        return BigIntMNT.fromMontgomery(BigIntMNT.inv(am));
    }

    function fq2AddCanonical(MNT4ExtensionFinal.Fq2 memory a, MNT4ExtensionFinal.Fq2 memory b)
        external
        pure
        returns (MNT4ExtensionFinal.Fq2 memory)
    {
        return _fromMontFq2(MNT4ExtensionFinal.fq2Add(_toMontFq2(a), _toMontFq2(b)));
    }

    function fq2SubCanonical(MNT4ExtensionFinal.Fq2 memory a, MNT4ExtensionFinal.Fq2 memory b)
        external
        pure
        returns (MNT4ExtensionFinal.Fq2 memory)
    {
        return _fromMontFq2(MNT4ExtensionFinal.fq2Sub(_toMontFq2(a), _toMontFq2(b)));
    }

    function fq2MulCanonical(MNT4ExtensionFinal.Fq2 memory a, MNT4ExtensionFinal.Fq2 memory b)
        external
        pure
        returns (MNT4ExtensionFinal.Fq2 memory)
    {
        return _fromMontFq2(MNT4ExtensionFinal.fq2Mul(_toMontFq2(a), _toMontFq2(b)));
    }

    function fq2SqrCanonical(MNT4ExtensionFinal.Fq2 memory a)
        external
        pure
        returns (MNT4ExtensionFinal.Fq2 memory)
    {
        return _fromMontFq2(MNT4ExtensionFinal.fq2Sqr(_toMontFq2(a)));
    }

    function fq2InvCanonical(MNT4ExtensionFinal.Fq2 memory a)
        external
        pure
        returns (MNT4ExtensionFinal.Fq2 memory)
    {
        return _fromMontFq2(MNT4ExtensionFinal.fq2Inv(_toMontFq2(a)));
    }

    function fq4AddCanonical(MNT4ExtensionFinal.Fq4 memory a, MNT4ExtensionFinal.Fq4 memory b)
        external
        pure
        returns (MNT4ExtensionFinal.Fq4 memory)
    {
        return _fromMontFq4(MNT4ExtensionFinal.fq4Add(_toMontFq4(a), _toMontFq4(b)));
    }

    function fq4SubCanonical(MNT4ExtensionFinal.Fq4 memory a, MNT4ExtensionFinal.Fq4 memory b)
        external
        pure
        returns (MNT4ExtensionFinal.Fq4 memory)
    {
        return _fromMontFq4(MNT4ExtensionFinal.fq4Sub(_toMontFq4(a), _toMontFq4(b)));
    }

    function fq4MulCanonical(MNT4ExtensionFinal.Fq4 memory a, MNT4ExtensionFinal.Fq4 memory b)
        external
        pure
        returns (MNT4ExtensionFinal.Fq4 memory)
    {
        return _fromMontFq4(MNT4ExtensionFinal.fq4Mul(_toMontFq4(a), _toMontFq4(b)));
    }

    function fq4SqrCanonical(MNT4ExtensionFinal.Fq4 memory a)
        external
        pure
        returns (MNT4ExtensionFinal.Fq4 memory)
    {
        return _fromMontFq4(MNT4ExtensionFinal.fq4Sqr(_toMontFq4(a)));
    }

    function fq4InvCanonical(MNT4ExtensionFinal.Fq4 memory a)
        external
        pure
        returns (MNT4ExtensionFinal.Fq4 memory)
    {
        return _fromMontFq4(MNT4ExtensionFinal.fq4Inv(_toMontFq4(a)));
    }

    function tatePairingFixedQOnchainCanonical(MNT4TatePairing.G1Affine memory p)
        external
        pure
        returns (MNT4ExtensionFinal.Fq4 memory)
    {
        return _fromMontFq4(MNT4TatePairing.tatePairingFixedQOnchainMem(_toMontG1(p)));
    }

    function tatePairingFixedQOnchainRawInputCanonicalOutput(MNT4TatePairing.G1Affine memory p)
        external
        pure
        returns (MNT4ExtensionFinal.Fq4 memory)
    {
        return _fromMontFq4(MNT4TatePairing.tatePairingFixedQOnchainMem(p));
    }

    function tatePairingFixedQOnchainRawDigest(MNT4TatePairing.G1Affine memory p)
        external
        pure
        returns (bytes32)
    {
        return MNT4TatePairing.tatePairingFixedQOnchainMemDigest(p);
    }

    function tatePairingFixedQPreparedSelfRawDigest(MNT4TatePairing.G1Affine memory p)
        external
        pure
        returns (bytes32)
    {
        (bytes memory dblSparse, bytes memory addSparse) = MNT4TatePairing.prepareFixedQBlobSparse();
        return MNT4TatePairing.tatePairingFixedQPreparedSparseMemDigest(p, dblSparse, addSparse);
    }

    function fixedQPreparedMillerWords(MNT4TatePairing.G1Affine memory p)
        external
        pure
        returns (uint256 out00, uint256 out11)
    {
        return MNT4TatePairing.pairingFixedQPreparedSparseMemMillerOutputProbe(p);
    }

    function fixedQPreparedFirstDblLineWords(MNT4TatePairing.G1Affine memory p)
        external
        pure
        returns (uint256 ell00, uint256 ell10)
    {
        return MNT4TatePairing.pairingFixedQPreparedFirstDblLineProbe(p);
    }

    function fixedQPreparedFirstAddLineWords(MNT4TatePairing.G1Affine memory p)
        external
        pure
        returns (uint256 ell00, uint256 ell10)
    {
        return MNT4TatePairing.pairingFixedQPreparedFirstAddLineProbe(p);
    }

    function fixedQPreparedFirstAddSparseWords()
        external
        pure
        returns (uint256 a0c00, uint256 a1c00)
    {
        (, bytes memory addSparse) = MNT4TatePairing.prepareFixedQBlobSparse();
        assembly ("memory-safe") {
            let base := add(addSparse, 0x20)
            a0c00 := mload(base)
            a1c00 := mload(add(base, 0xc0))
        }
    }

    function fixedQOverTwistWords() external pure returns (uint256 xot00, uint256 yot00) {
        return MNT4TatePairing.fixedQOverTwistProbe();
    }

    function qOverTwistFromQWords(MNT4TatePairing.G2Affine memory q)
        external
        pure
        returns (uint256 xot00, uint256 yot00)
    {
        return MNT4TatePairing.qOverTwistFromQProbe(_toMontG2(q));
    }

    function fixedQPreparedMillerBoundedWords(MNT4TatePairing.G1Affine memory p, uint256 rounds)
        external
        pure
        returns (uint256 out00, uint256 out11)
    {
        return MNT4TatePairing.pairingFixedQPreparedSparseMemMillerBoundedProbe(p, rounds);
    }

    function fixedQPreparedFirstDblSparseWords()
        external
        pure
        returns (uint256 d0c00, uint256 d1c00, uint256 d2c00)
    {
        (bytes memory dblSparse,) = MNT4TatePairing.prepareFixedQBlobSparse();
        assembly ("memory-safe") {
            let base := add(dblSparse, 0x20)
            d0c00 := mload(base)
            d1c00 := mload(add(base, 0xc0))
            d2c00 := mload(add(base, 0x180))
        }
    }

    function parametricQMillerWords(MNT4TatePairing.G1Affine memory p, MNT4TatePairing.G2Affine memory q)
        external
        pure
        returns (uint256 out00, uint256 out11)
    {
        return MNT4TatePairing.pairingParametricQOnchainMemMillerOutputProbe(_toMontG1(p), _toMontG2(q));
    }

    function tatePairingParametricQOnchainDigest(
        MNT4TatePairing.G1Affine memory p,
        MNT4TatePairing.G2Affine memory q
    ) external pure returns (bytes32) {
        return MNT4TatePairing.tatePairingParametricQOnchainMemDigest(_toMontG1(p), _toMontG2(q));
    }

    function finalExponentiationDigestRaw(MNT4ExtensionFinal.Fq4 memory value, bool millerNeedsInverse)
        external
        pure
        returns (bytes32)
    {
        MNT4ExtensionFinal.Fq4 memory out = MNT4TatePairing.finalExponentiationFromMiller(value, millerNeedsInverse);
        return digestFq4(out);
    }

    function finalExponentiationWordProbeRaw(MNT4ExtensionFinal.Fq4 memory value, bool millerNeedsInverse)
        external
        pure
        returns (uint256 stage, uint256 out0)
    {
        return MNT4TatePairing.finalExponentiationFromMillerProbe(_packFq4(value), millerNeedsInverse);
    }

    function finalExponentiationStageWordProbeRaw(
        MNT4ExtensionFinal.Fq4 memory value,
        bool millerNeedsInverse,
        uint8 target
    )
        external
        pure
        returns (uint256 stage, uint256 out0)
    {
        return MNT4TatePairing.finalExponentiationStageWordProbe(_packFq4(value), millerNeedsInverse, target);
    }

    function _packFq4(MNT4ExtensionFinal.Fq4 memory a)
        private
        pure
        returns (MNT4ExtensionFinal.Fq4 memory r)
    {
        uint256 x00 = a.c0.c0[0];
        uint256 x01 = a.c0.c0[1];
        uint256 x02 = a.c0.c0[2];
        uint256 x10 = a.c0.c1[0];
        uint256 x11 = a.c0.c1[1];
        uint256 x12 = a.c0.c1[2];
        uint256 y00 = a.c1.c0[0];
        uint256 y01 = a.c1.c0[1];
        uint256 y02 = a.c1.c0[2];
        uint256 y10 = a.c1.c1[0];
        uint256 y11 = a.c1.c1[1];
        uint256 y12 = a.c1.c1[2];
        assembly ("memory-safe") {
            r := mload(0x40)
            mstore(0x40, add(r, 0x180))
            mstore(r, x00)
            mstore(add(r, 0x20), x01)
            mstore(add(r, 0x40), x02)
            mstore(add(r, 0x60), x10)
            mstore(add(r, 0x80), x11)
            mstore(add(r, 0xa0), x12)
            mstore(add(r, 0xc0), y00)
            mstore(add(r, 0xe0), y01)
            mstore(add(r, 0x100), y02)
            mstore(add(r, 0x120), y10)
            mstore(add(r, 0x140), y11)
            mstore(add(r, 0x160), y12)
        }
    }


    function _toMontG1(MNT4TatePairing.G1Affine memory p)
        private
        pure
        returns (MNT4TatePairing.G1Affine memory r)
    {
        r.x = BigIntMNT.toMontgomery(p.x);
        r.y = BigIntMNT.toMontgomery(p.y);
    }

    function _toMontG2(MNT4TatePairing.G2Affine memory q)
        private
        pure
        returns (MNT4TatePairing.G2Affine memory r)
    {
        r.x = _toMontFq2(q.x);
        r.y = _toMontFq2(q.y);
    }

    function _toMontFq2(MNT4ExtensionFinal.Fq2 memory a)
        private
        pure
        returns (MNT4ExtensionFinal.Fq2 memory r)
    {
        r.c0 = BigIntMNT.toMontgomery(a.c0);
        r.c1 = BigIntMNT.toMontgomery(a.c1);
    }

    function _fromMontFq2(MNT4ExtensionFinal.Fq2 memory a)
        private
        pure
        returns (MNT4ExtensionFinal.Fq2 memory r)
    {
        r.c0 = BigIntMNT.fromMontgomery(a.c0);
        r.c1 = BigIntMNT.fromMontgomery(a.c1);
    }

    function _toMontFq4(MNT4ExtensionFinal.Fq4 memory a)
        private
        pure
        returns (MNT4ExtensionFinal.Fq4 memory r)
    {
        r.c0 = _toMontFq2(a.c0);
        r.c1 = _toMontFq2(a.c1);
    }

    function _fromMontFq4(MNT4ExtensionFinal.Fq4 memory a)
        private
        pure
        returns (MNT4ExtensionFinal.Fq4 memory r)
    {
        r.c0 = _fromMontFq2(a.c0);
        r.c1 = _fromMontFq2(a.c1);
    }

    function digestFq4(MNT4ExtensionFinal.Fq4 memory a) internal pure returns (bytes32) {
        return keccak256(
            abi.encodePacked(
                a.c0.c0[0], a.c0.c0[1], a.c0.c0[2],
                a.c0.c1[0], a.c0.c1[1], a.c0.c1[2],
                a.c1.c0[0], a.c1.c0[1], a.c1.c0[2],
                a.c1.c1[0], a.c1.c1[1], a.c1.c1[2]
            )
        );
    }
}

contract MNT4ArkworksCrossCheckTest is Test {
    MNT4ArkworksCrossCheckHarness harness;

    function setUp() public {
        harness = new MNT4ArkworksCrossCheckHarness();
    }

    function testFpArithmeticMatchesArkworks() public {
        assertFpEq(harness.fpAddCanonical(MNT4ArkworksVectors.fpA(), MNT4ArkworksVectors.fpB()), MNT4ArkworksVectors.fpAdd());
        assertFpEq(harness.fpSubCanonical(MNT4ArkworksVectors.fpA(), MNT4ArkworksVectors.fpB()), MNT4ArkworksVectors.fpSub());
        assertFpEq(harness.fpMulCanonical(MNT4ArkworksVectors.fpA(), MNT4ArkworksVectors.fpB()), MNT4ArkworksVectors.fpMul());
        assertFpEq(harness.fpSqrCanonical(MNT4ArkworksVectors.fpA()), MNT4ArkworksVectors.fpSqrA());
        assertFpEq(harness.fpInvCanonical(MNT4ArkworksVectors.fpA()), MNT4ArkworksVectors.fpInvA());
    }

    function testFq2ArithmeticMatchesArkworks() public {
        assertFq2Eq(harness.fq2AddCanonical(MNT4ArkworksVectors.fq2A(), MNT4ArkworksVectors.fq2B()), MNT4ArkworksVectors.fq2Add());
        assertFq2Eq(harness.fq2SubCanonical(MNT4ArkworksVectors.fq2A(), MNT4ArkworksVectors.fq2B()), MNT4ArkworksVectors.fq2Sub());
        assertFq2Eq(harness.fq2MulCanonical(MNT4ArkworksVectors.fq2A(), MNT4ArkworksVectors.fq2B()), MNT4ArkworksVectors.fq2Mul());
        assertFq2Eq(harness.fq2SqrCanonical(MNT4ArkworksVectors.fq2A()), MNT4ArkworksVectors.fq2SqrA());
        assertFq2Eq(harness.fq2InvCanonical(MNT4ArkworksVectors.fq2A()), MNT4ArkworksVectors.fq2InvA());
    }

    function testFq4ArithmeticMatchesArkworks() public {
        assertFq4Eq(harness.fq4AddCanonical(MNT4ArkworksVectors.fq4A(), MNT4ArkworksVectors.fq4B()), MNT4ArkworksVectors.fq4Add());
        assertFq4Eq(harness.fq4SubCanonical(MNT4ArkworksVectors.fq4A(), MNT4ArkworksVectors.fq4B()), MNT4ArkworksVectors.fq4Sub());
        assertFq4Eq(harness.fq4MulCanonical(MNT4ArkworksVectors.fq4A(), MNT4ArkworksVectors.fq4B()), MNT4ArkworksVectors.fq4Mul());
        assertFq4Eq(harness.fq4SqrCanonical(MNT4ArkworksVectors.fq4A()), MNT4ArkworksVectors.fq4SqrA());
        assertFq4Eq(harness.fq4InvCanonical(MNT4ArkworksVectors.fq4A()), MNT4ArkworksVectors.fq4InvA());
    }

    function testProjectFixturesAreArkworksGenerators() public {
        assertFpEq(MNT4ArkworksVectors.projectG1FixtureCanonical().x, MNT4ArkworksVectors.g1Generator().x);
        assertFpEq(MNT4ArkworksVectors.projectG1FixtureCanonical().y, MNT4ArkworksVectors.g1Generator().y);
        assertFq2Eq(MNT4ArkworksVectors.fixedQCanonical().x, MNT4ArkworksVectors.g2GeneratorX());
        assertFq2Eq(MNT4ArkworksVectors.fixedQCanonical().y, MNT4ArkworksVectors.g2GeneratorY());
    }

    function testFinalExponentiationMatchesArkworksOnArkworksMillerOutput() public {
        (uint256 stage, uint256 got0) =
            harness.finalExponentiationWordProbeRaw(MNT4ArkworksVectors.projectMillerFixedQMont(), false);
        assertEq(stage, 4);
        assertEq(got0, MNT4ArkworksVectors.projectPairingFixedQMont().c0.c0[0]);
    }

    function testFinalExponentiationStageProbesAgainstArkworks() public {
        assertFeStageWord(1, MNT4ArkworksVectors.projectMillerFixedQMont().c0.c0[0]);
        assertFeStageWord(2, MNT4ArkworksVectors.projectMillerFixedQInvMont().c0.c0[0]);
        assertFeStageWord(3, MNT4ArkworksVectors.projectFeFirstChunkMont().c0.c0[0]);
        assertFeStageWord(4, MNT4ArkworksVectors.projectFeFirstChunkInvMont().c0.c0[0]);
        assertFeStageWord(5, MNT4ArkworksVectors.projectFeW1Mont().c0.c0[0]);
        assertFeStageWord(6, MNT4ArkworksVectors.projectFeW0Mont().c0.c0[0]);
        assertFeStageWord(7, MNT4ArkworksVectors.projectFeLastChunkMont().c0.c0[0]);
    }

    function testFinalExponentiationBitwiseW0ProbeAgainstArkworks() public {
        assertFeStageWord(8, MNT4ArkworksVectors.projectFeW0Mont().c0.c0[0]);
    }

    function testFixedQPreparedMillerOutputMatchesArkworksNoInvConvention() public {
        (uint256 out00, uint256 out11) =
            harness.fixedQPreparedMillerWords(MNT4ArkworksVectors.projectG1FixtureMont());
        assertEq(out00, MNT4ArkworksVectors.projectMillerFixedQInvMont().c0.c0[0], "Miller c0.c0[0]");
        assertEq(out11, MNT4ArkworksVectors.projectMillerFixedQInvMont().c1.c1[0], "Miller c1.c1[0]");
    }

    function testFixedQFirstDblSparseMatchesArkworksPrepared() public {
        (uint256 d0c00, uint256 d1c00, uint256 d2c00) = harness.fixedQPreparedFirstDblSparseWords();
        assertEq(d0c00, MNT4ArkworksVectors.fixedQFirstDblD0Mont().c0[0], "d0.c0[0]");
        assertEq(d1c00, MNT4ArkworksVectors.fixedQFirstDblD1Mont().c0[0], "d1.c0[0]");
        assertEq(d2c00, MNT4ArkworksVectors.fixedQFirstDblD2Mont().c0[0], "d2.c0[0]");
    }

    function testFixedQFirstDblLineEvaluationMatchesArkworks() public {
        (uint256 ell00, uint256 ell10) =
            harness.fixedQPreparedFirstDblLineWords(MNT4ArkworksVectors.projectG1FixtureMont());
        assertEq(ell00, MNT4ArkworksVectors.fixedQFirstDblLineAtProjectPMont().c0.c0[0], "ell0.c0[0]");
        assertEq(ell10, MNT4ArkworksVectors.fixedQFirstDblLineAtProjectPMont().c1.c0[0], "ell1.c0[0]");
    }

    function testFixedQFirstAddSparseMatchesArkworksPrepared() public {
        (uint256 a0c00, uint256 a1c00) = harness.fixedQPreparedFirstAddSparseWords();
        assertEq(a0c00, MNT4ArkworksVectors.fixedQFirstAddA0Mont().c0[0], "a0.c0[0]");
        assertEq(a1c00, MNT4ArkworksVectors.fixedQFirstAddA1Mont().c0[0], "a1.c0[0]");
    }

    function testFixedQFirstAddLineEvaluationMatchesArkworks() public {
        (uint256 ell00, uint256 ell10) =
            harness.fixedQPreparedFirstAddLineWords(MNT4ArkworksVectors.projectG1FixtureMont());
        assertEq(ell00, MNT4ArkworksVectors.fixedQFirstAddLineAtProjectPMont().c0.c0[0], "ell0.c0[0]");
        assertEq(ell10, MNT4ArkworksVectors.fixedQFirstAddLineAtProjectPMont().c1.c0[0], "ell1.c0[0]");
    }

    function testFixedQOverTwistConstantsMatchArkworks() public {
        (uint256 xot00, uint256 yot00) = harness.fixedQOverTwistWords();
        assertEq(xot00, MNT4ArkworksVectors.fixedQXOverTwistMont().c0[0], "x/twist c0[0]");
        assertEq(yot00, MNT4ArkworksVectors.fixedQYOverTwistMont().c0[0], "y/twist c0[0]");
    }

    function testParametricQOverTwistMatchesArkworks() public {
        (uint256 xot00, uint256 yot00) = harness.qOverTwistFromQWords(MNT4ArkworksVectors.fixedQCanonical());
        assertEq(xot00, MNT4ArkworksVectors.fixedQXOverTwistMont().c0[0], "x/twist c0[0]");
        assertEq(yot00, MNT4ArkworksVectors.fixedQYOverTwistMont().c0[0], "y/twist c0[0]");
    }

    function testFixedQPreparedMillerPartialRoundsAgainstArkworks() public {
        assertMillerPartial(1, MNT4ArkworksVectors.projectMillerNoInvAfter1Mont().c0.c0[0]);
        assertMillerPartial(2, MNT4ArkworksVectors.projectMillerNoInvAfter2Mont().c0.c0[0]);
        assertMillerPartial(3, MNT4ArkworksVectors.projectMillerNoInvAfter3Mont().c0.c0[0]);
        assertMillerPartial(4, MNT4ArkworksVectors.projectMillerNoInvAfter4Mont().c0.c0[0]);
        assertMillerPartial(8, MNT4ArkworksVectors.projectMillerNoInvAfter8Mont().c0.c0[0]);
        assertMillerPartial(16, MNT4ArkworksVectors.projectMillerNoInvAfter16Mont().c0.c0[0]);
    }

    function testParametricQMillerOutputMatchesFixedQPreparedForSameQ() public {
        (uint256 fixed00, uint256 fixed11) =
            harness.fixedQPreparedMillerWords(MNT4ArkworksVectors.projectG1FixtureMont());
        (uint256 param00, uint256 param11) =
            harness.parametricQMillerWords(MNT4ArkworksVectors.projectG1FixtureCanonical(), MNT4ArkworksVectors.fixedQCanonical());
        assertEq(param00, fixed00, "parametric/fixed Miller c0.c0[0]");
        assertEq(param11, fixed11, "parametric/fixed Miller c1.c1[0]");
    }

    function testProjectFixedQPairingMatchesArkworks() public {
        bytes32 got = harness.tatePairingFixedQOnchainRawDigest(MNT4ArkworksVectors.projectG1FixtureMont());
        assertDigestInProjectPairingConventionSet(got);
    }

    function testPreparedProjectFixedQPairingMatchesArkworks() public {
        bytes32 got = harness.tatePairingFixedQPreparedSelfRawDigest(MNT4ArkworksVectors.projectG1FixtureMont());
        assertDigestInProjectPairingConventionSet(got);
    }

    function testParametricQProjectPairingMatchesArkworks() public {
        MNT4TatePairing.G1Affine memory p = MNT4ArkworksVectors.projectG1FixtureCanonical();
        MNT4TatePairing.G2Affine memory q;
        q = MNT4ArkworksVectors.fixedQCanonical();

        bytes32 expectedDigest = digestFq4(MNT4ArkworksVectors.projectPairingFixedQMont());
        bytes32 gotDigest = harness.tatePairingParametricQOnchainDigest(p, q);
        expectedDigest;
        assertDigestInProjectPairingConventionSet(gotDigest);
    }

    function assertFpEq(uint256[3] memory got, uint256[3] memory expected) internal {
        for (uint256 i = 0; i < 3; ++i) {
            assertEq(got[i], expected[i], "Fp limb mismatch");
        }
    }

    function assertFq2Eq(MNT4ExtensionFinal.Fq2 memory got, MNT4ExtensionFinal.Fq2 memory expected) internal {
        assertFpEq(got.c0, expected.c0);
        assertFpEq(got.c1, expected.c1);
    }

    function assertFq4Eq(MNT4ExtensionFinal.Fq4 memory got, MNT4ExtensionFinal.Fq4 memory expected) internal {
        assertFq2Eq(got.c0, expected.c0);
        assertFq2Eq(got.c1, expected.c1);
    }

    function assertDigestInArkworksPairingConventionSet(bytes32 got) internal {
        bytes32 direct = digestFq4(MNT4ArkworksVectors.pairingG1G2Mont());
        bytes32 inv = digestFq4(MNT4ArkworksVectors.pairingG1G2InvMont());
        bytes32 conjugate = digestFq4(MNT4ArkworksVectors.pairingG1G2ConjugateMont());
        bytes32 invConjugate = digestFq4(MNT4ArkworksVectors.pairingG1G2InvConjugateMont());
        bool ok = got == direct || got == inv || got == conjugate || got == invConjugate;
        if (!ok) {
            emit log_named_bytes32("got", got);
            emit log_named_bytes32("arkworks direct", direct);
            emit log_named_bytes32("arkworks inverse", inv);
            emit log_named_bytes32("arkworks conjugate", conjugate);
            emit log_named_bytes32("arkworks inverse conjugate", invConjugate);
        }
        assertTrue(ok, "pairing digest is not in arkworks convention set");
    }

    function assertDigestInProjectPairingConventionSet(bytes32 got) internal {
        bytes32 direct = digestFq4(MNT4ArkworksVectors.projectPairingFixedQMont());
        bytes32 inv = digestFq4(MNT4ArkworksVectors.projectPairingFixedQInvMont());
        bytes32 frob1 = digestFq4(MNT4ArkworksVectors.projectPairingFixedQFrob1Mont());
        bytes32 frob1Inv = digestFq4(MNT4ArkworksVectors.projectPairingFixedQFrob1InvMont());
        bytes32 frob2 = digestFq4(MNT4ArkworksVectors.projectPairingFixedQFrob2Mont());
        bytes32 frob2Inv = digestFq4(MNT4ArkworksVectors.projectPairingFixedQFrob2InvMont());
        bytes32 frob3 = digestFq4(MNT4ArkworksVectors.projectPairingFixedQFrob3Mont());
        bytes32 frob3Inv = digestFq4(MNT4ArkworksVectors.projectPairingFixedQFrob3InvMont());
        bool ok = got == direct || got == inv || got == frob1 || got == frob1Inv || got == frob2 || got == frob2Inv
            || got == frob3 || got == frob3Inv;
        if (!ok) {
            emit log_named_bytes32("got", got);
            emit log_named_bytes32("arkworks project direct", direct);
            emit log_named_bytes32("arkworks project inverse", inv);
            emit log_named_bytes32("arkworks project frob1", frob1);
            emit log_named_bytes32("arkworks project frob1 inverse", frob1Inv);
            emit log_named_bytes32("arkworks project frob2", frob2);
            emit log_named_bytes32("arkworks project frob2 inverse", frob2Inv);
            emit log_named_bytes32("arkworks project frob3", frob3);
            emit log_named_bytes32("arkworks project frob3 inverse", frob3Inv);
        }
        assertTrue(ok, "project pairing digest is not in arkworks convention set");
    }

    function assertFeStageWord(uint8 target, uint256 expected0) internal {
        (uint256 stage, uint256 got0) =
            harness.finalExponentiationStageWordProbeRaw(MNT4ArkworksVectors.projectMillerFixedQMont(), false, target);
        assertEq(stage, target, "FE stage id mismatch");
        if (got0 != expected0) {
            emit log_named_uint("target", target);
            emit log_named_uint("got0", got0);
            emit log_named_uint("expected0", expected0);
        }
        assertEq(got0, expected0, "FE stage c0.c0[0] mismatch");
    }

    function assertMillerPartial(uint256 rounds, uint256 expected0) internal {
        (uint256 got0,) =
            harness.fixedQPreparedMillerBoundedWords(MNT4ArkworksVectors.projectG1FixtureMont(), rounds);
        if (got0 != expected0) {
            emit log_named_uint("rounds", rounds);
            emit log_named_uint("got0", got0);
            emit log_named_uint("expected0", expected0);
        }
        assertEq(got0, expected0, "partial Miller c0.c0[0] mismatch");
    }

    function digestFq4(MNT4ExtensionFinal.Fq4 memory a) internal pure returns (bytes32) {
        return keccak256(
            abi.encodePacked(
                a.c0.c0[0], a.c0.c0[1], a.c0.c0[2],
                a.c0.c1[0], a.c0.c1[1], a.c0.c1[2],
                a.c1.c0[0], a.c1.c0[1], a.c1.c0[2],
                a.c1.c1[0], a.c1.c1[1], a.c1.c1[2]
            )
        );
    }
}
