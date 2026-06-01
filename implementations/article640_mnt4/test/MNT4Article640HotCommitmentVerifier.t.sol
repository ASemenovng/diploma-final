// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Test} from "forge-std/Test.sol";
import {MNT4PairingTypes} from "@arith-mnt4-test/MNT4PairingTypes.sol";
import {MNT4TatePairing} from "../src/MNT4TatePairing.sol";
import {MNT4ExtensionFinal} from "@arith-mnt4/MNT4Extension.sol";
import {MNT4Article640DirectHotVerifier} from "../src/MNT4Article640DirectHotVerifier.sol";
import {MNT4Article640HotCommitmentVerifier} from "../src/MNT4Article640HotCommitmentVerifier.sol";
import {MNT4Article640FixedShardsVerifier} from "../src/MNT4Article640FixedShardsVerifier.sol";

contract HotCommitmentCodeShardStore {
    constructor(bytes memory blob) payable {
        assembly ("memory-safe") {
            return(add(blob, 0x20), mload(blob))
        }
    }
}

contract MNT4Article640HotCommitmentVerifierTest is Test {
    MNT4Article640DirectHotVerifier private hot;
    MNT4Article640HotCommitmentVerifier private committed;
    MNT4Article640FixedShardsVerifier private fixedShards;

    MNT4TatePairing.G1Affine private p;
    MNT4TatePairing.G1Affine private r;
    MNT4TatePairing.G2Affine private s;

    bytes private dblSparseQ;
    bytes private addSparseQ;
    bytes private dblSparseS;
    bytes private addSparseS;

    address[] private dblShardsQ;
    address[] private addShardsQ;
    address[] private dblShardsS;
    address[] private addShardsS;

    function setUp() public {
        hot = new MNT4Article640DirectHotVerifier();

        bytes memory data = vm.parseBytes(vm.readFile("fixtures/article640_hot.words.hex"));
        MNT4PairingTypes.G1Point memory parsedP;
        MNT4PairingTypes.G1Point memory parsedR;
        MNT4PairingTypes.G2Point memory ignoredQ;
        MNT4PairingTypes.G2Point memory parsedS;
        uint256 o;
        (parsedP, o) = _readG1(data, o);
        (parsedR, o) = _readG1(data, o);
        (ignoredQ, o) = _readG2(data, o);
        (parsedS, o) = _readG2(data, o);

        p = _toHotG1(parsedP);
        r = _toHotG1(parsedR);
        s = _toHotG2(parsedS);

        (dblSparseQ, addSparseQ) = hot.prepareFixedQBlobSparse();
        (dblSparseS, addSparseS) = hot.prepareParametricQBlobSparse(s);

        MNT4Article640HotCommitmentVerifier helper = new MNT4Article640HotCommitmentVerifier(s, bytes32(0), bytes32(0));
        bytes32 commitmentQ = helper.hashSparseCacheForFixedQ(dblSparseQ, addSparseQ);
        bytes32 commitmentS = helper.hashSparseCacheForPoint(s, dblSparseS, addSparseS);
        committed = new MNT4Article640HotCommitmentVerifier(s, commitmentQ, commitmentS);

        dblShardsQ = _deployCodeShards(dblSparseQ);
        addShardsQ = _deployCodeShards(addSparseQ);
        dblShardsS = _deployCodeShards(dblSparseS);
        addShardsS = _deployCodeShards(addSparseS);
        fixedShards = new MNT4Article640FixedShardsVerifier(s, dblShardsQ, addShardsQ, dblShardsS, addShardsS);
    }

    function testCommittedCalldataResidueAcceptsValidFixture() public view {
        (MNT4ExtensionFinal.Fq4 memory c, MNT4ExtensionFinal.Fq4 memory cInv) = _hotResidueWitness();
        assertTrue(committed.verifyEquationResidueCommitted(p, r, c, cInv, dblSparseQ, addSparseQ, dblSparseS, addSparseS));
    }

    function testCommittedCodeShardsResidueAcceptsValidFixture() public view {
        (MNT4ExtensionFinal.Fq4 memory c, MNT4ExtensionFinal.Fq4 memory cInv) = _hotResidueWitness();
        assertTrue(
            committed.verifyEquationResidueCommittedCodeShards(
                p, r, c, cInv, dblShardsQ, addShardsQ, dblShardsS, addShardsS
            )
        );
    }

    function testFixedShardsResidueAcceptsValidFixture() public view {
        (MNT4ExtensionFinal.Fq4 memory c, MNT4ExtensionFinal.Fq4 memory cInv) = _hotResidueWitness();
        assertTrue(fixedShards.verifyEquationResidueFixedShards(p, r, c, cInv));
    }

    function testFixedShardsMatchesHotCodeShardsResult() public view {
        (MNT4ExtensionFinal.Fq4 memory c, MNT4ExtensionFinal.Fq4 memory cInv) = _hotResidueWitness();
        bool hotOk = hot.verifyEquationFixedQParametricSResidueCodeShards(
            p, r, s, c, cInv, dblShardsQ, addShardsQ, dblShardsS, addShardsS
        );
        bool fixedOk = fixedShards.verifyEquationResidueFixedShards(p, r, c, cInv);
        assertEq(fixedOk, hotOk);
        assertTrue(fixedOk);
    }

    function testFixedShardsRejectsTamperedResidueWitness() public view {
        (MNT4ExtensionFinal.Fq4 memory c, MNT4ExtensionFinal.Fq4 memory cInv) = _hotResidueWitness();
        cInv.c0.c0[0] ^= 1;
        assertFalse(fixedShards.verifyEquationResidueFixedShards(p, r, c, cInv));
    }

    function testFixedShardsRejectsPointOutsideG1() public view {
        (MNT4ExtensionFinal.Fq4 memory c, MNT4ExtensionFinal.Fq4 memory cInv) = _hotResidueWitness();
        MNT4TatePairing.G1Affine memory badP = p;
        badP.x[0] ^= 1;
        assertFalse(fixedShards.verifyEquationResidueFixedShards(badP, r, c, cInv));
    }

    function testCommittedRejectsPointOutsideG1() public view {
        (MNT4ExtensionFinal.Fq4 memory c, MNT4ExtensionFinal.Fq4 memory cInv) = _hotResidueWitness();
        MNT4TatePairing.G1Affine memory badR = r;
        badR.y[0] ^= 1;
        assertFalse(
            committed.verifyEquationResidueCommitted(
                p, badR, c, cInv, dblSparseQ, addSparseQ, dblSparseS, addSparseS
            )
        );
    }

    function testCommittedCalldataMatchesHotResult() public view {
        (MNT4ExtensionFinal.Fq4 memory c, MNT4ExtensionFinal.Fq4 memory cInv) = _hotResidueWitness();
        bool hotOk = hot.verifyEquationFixedQParametricSResidue(p, r, s, c, cInv, dblSparseQ, addSparseQ, dblSparseS, addSparseS);
        bool committedOk = committed.verifyEquationResidueCommitted(p, r, c, cInv, dblSparseQ, addSparseQ, dblSparseS, addSparseS);
        assertEq(committedOk, hotOk);
        assertTrue(committedOk);
    }

    function testCommittedRejectsTamperedQBlobByCommitment() public view {
        (MNT4ExtensionFinal.Fq4 memory c, MNT4ExtensionFinal.Fq4 memory cInv) = _hotResidueWitness();
        bytes memory bad = dblSparseQ;
        bad[100] = bytes1(uint8(bad[100]) ^ 1);
        assertFalse(committed.verifyEquationResidueCommitted(p, r, c, cInv, bad, addSparseQ, dblSparseS, addSparseS));
    }

    function testCommittedRejectsTamperedSBlobByCommitment() public view {
        (MNT4ExtensionFinal.Fq4 memory c, MNT4ExtensionFinal.Fq4 memory cInv) = _hotResidueWitness();
        bytes memory bad = addSparseS;
        bad[100] = bytes1(uint8(bad[100]) ^ 1);
        assertFalse(committed.verifyEquationResidueCommitted(p, r, c, cInv, dblSparseQ, addSparseQ, dblSparseS, bad));
    }

    function testCommittedRejectsWrongConstructorCommitment() public {
        bytes32 commitmentQ = committed.hashSparseCacheForFixedQ(dblSparseQ, addSparseQ);
        bytes32 commitmentS = committed.hashSparseCacheForPoint(s, dblSparseS, addSparseS);
        MNT4Article640HotCommitmentVerifier bad = new MNT4Article640HotCommitmentVerifier(
            s, bytes32(uint256(commitmentQ) ^ 1), commitmentS
        );
        (MNT4ExtensionFinal.Fq4 memory c, MNT4ExtensionFinal.Fq4 memory cInv) = _hotResidueWitness();
        assertFalse(bad.verifyEquationResidueCommitted(p, r, c, cInv, dblSparseQ, addSparseQ, dblSparseS, addSparseS));
    }

    function testCommittedRejectsTamperedResidueWitness() public view {
        (MNT4ExtensionFinal.Fq4 memory c, MNT4ExtensionFinal.Fq4 memory cInv) = _hotResidueWitness();
        c.c0.c0[0] ^= 1;
        assertFalse(committed.verifyEquationResidueCommitted(p, r, c, cInv, dblSparseQ, addSparseQ, dblSparseS, addSparseS));
    }

    function _deployCodeShards(bytes memory blob) private returns (address[] memory shards) {
        uint256 chunkBytes = 0x6000;
        require(chunkBytes % 0xc0 == 0, "bad chunk");
        uint256 count = (blob.length + chunkBytes - 1) / chunkBytes;
        shards = new address[](count);
        uint256 off;
        for (uint256 i = 0; i < count; ++i) {
            uint256 len = blob.length - off;
            if (len > chunkBytes) len = chunkBytes;
            require(len % 0xc0 == 0, "bad shard align");
            bytes memory part = new bytes(len);
            assembly ("memory-safe") {
                let src := add(add(blob, 0x20), off)
                let dst := add(part, 0x20)
                for { let pos := 0 } lt(pos, len) { pos := add(pos, 0x20) } {
                    mstore(add(dst, pos), mload(add(src, pos)))
                }
            }
            shards[i] = address(new HotCommitmentCodeShardStore(part));
            off += len;
        }
        require(off == blob.length, "bad shard split");
    }

    function _hotResidueWitness()
        private
        pure
        returns (MNT4ExtensionFinal.Fq4 memory c, MNT4ExtensionFinal.Fq4 memory cInv)
    {
        c.c0.c0 = [uint256(0x7b8bdcfd96f07d07815bb71544ac9e72b23b0c1150725cec0761329ab2647e2b), uint256(0xd3f71151375fe8bce5b0b6b78de0732f4d5904f62c7f2b6b3d9055e0f673e435), uint256(0x0001c3534c6b148bc4069735c9241e98c5bdf7361f9d2b436d5b4065d9180520)];
        c.c0.c1 = [uint256(0xb37f3f069246d82d8093b73483817dd79afde98b309b53053e2644ef0a4f4f54), uint256(0xdbd08112fdc212a8d46fa3e06088e7809afc60aeed9675fdc68a7e547db86315), uint256(0x00018961aab7c241502055151b98d8cf064c045b2568a2657b643a238bea1df2)];
        c.c1.c0 = [uint256(0x2cba8c184109f80bcc250e25139748f9de707135b30d9e03b90dd070d60cca3e), uint256(0x9e5f91cef9ad2e946d9a61e7872795bad0159658e370b87c9a200954490c860b), uint256(0x00004661d90786d45b80e448520102bd5f029829731b414f23d4a7da8be892b1)];
        c.c1.c1 = [uint256(0xcfc9dcd4d05558e85c5ec5f3d09133880d7d2dfb43cd9e5076fad370b44ca44b), uint256(0x9d40bc3284eb1c8d44b8de9af7cd490143db6231cb8d7e905f972544261ac042), uint256(0x00008e00c9aa1442233ba65ff78700af45f36c81ac893b3d629ea5a43793ba3e)];
        cInv.c0.c0 = [uint256(0x61f77d59f9757f4e3cbc629c418fb4113afa07fde34d47daa53186e412c30c87), uint256(0x7323efde13980917f80ec0b368b6146b3b98132b64c5f495fcfe854f64a2136e), uint256(0x0000ebb316230285982d1beda2c4b634a72634a552c0ca7bb2e8cd025eeb7b23)];
        cInv.c0.c1 = [uint256(0xbd9f2de3222ad2ab2c0a0c444fc1e347735db299639c372a0b2dcd9bdef6b03f), uint256(0x7fe83a815beb50206e8c461eece9873b11d5efc16b454d421b6bc42539200e3b), uint256(0x0000c77476635849e6a0835eec46fdd2d1c0b8c6723e71af327c09ac2a63d81a)];
        cInv.c1.c0 = [uint256(0x8f6f9332e8d06dd51affea4e87aedae563797e09ede9864ca952555049b57519), uint256(0x9cb95f3ac402fa7dfd31aa5b20817489ab7b51c3f7bf544781cc527cb9eaef8b), uint256(0x00003931c3af779dd1c39b0b23d4dda1abde2ac7b636c48c8a4475933454c7d4)];
        cInv.c1.c1 = [uint256(0xf0b486c73c38067e7293912e6f7bc5b375273cb86bc19ff6c5b8a8fd67106c2a), uint256(0x29cc2d26a275ed8923ea535352c23acc21c9d4721dc397b365838cde7935fe32), uint256(0x00008537d6ddce741ecff763ea820574fbee9c78739b1c766ad98f4d9b76a6b3)];
    }

    function _toHotG1(MNT4PairingTypes.G1Point memory point) private pure returns (MNT4TatePairing.G1Affine memory out) {
        out.x = [point.x.d0, point.x.d1, point.x.d2]; out.y = [point.y.d0, point.y.d1, point.y.d2];
    }

    function _toHotG2(MNT4PairingTypes.G2Point memory point) private pure returns (MNT4TatePairing.G2Affine memory out) {
        out.x.c0 = [point.x.c0.d0, point.x.c0.d1, point.x.c0.d2]; out.x.c1 = [point.x.c1.d0, point.x.c1.d1, point.x.c1.d2];
        out.y.c0 = [point.y.c0.d0, point.y.c0.d1, point.y.c0.d2]; out.y.c1 = [point.y.c1.d0, point.y.c1.d1, point.y.c1.d2];
    }

    function _readG1(bytes memory data, uint256 o) private pure returns (MNT4PairingTypes.G1Point memory point, uint256 next) {
        (point.x, o) = _readFp(data, o); (point.y, o) = _readFp(data, o); next = o;
    }

    function _readG2(bytes memory data, uint256 o) private pure returns (MNT4PairingTypes.G2Point memory point, uint256 next) {
        (point.x, o) = _readFq2(data, o); (point.y, o) = _readFq2(data, o); next = o;
    }

    function _readFq2(bytes memory data, uint256 o) private pure returns (MNT4PairingTypes.Fq2 memory x, uint256 next) {
        (x.c0, o) = _readFp(data, o); (x.c1, o) = _readFp(data, o); next = o;
    }

    function _readFp(bytes memory data, uint256 o) private pure returns (MNT4PairingTypes.Fp memory x, uint256 next) {
        x.d2 = _word(data, o); o += 32; x.d1 = _word(data, o); o += 32; x.d0 = _word(data, o); o += 32; next = o;
    }

    function _word(bytes memory data, uint256 offset) private pure returns (uint256 value) {
        assembly ("memory-safe") { value := mload(add(add(data, 0x20), offset)) }
    }
}
