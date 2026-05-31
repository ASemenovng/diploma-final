// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import "forge-std/Test.sol";
import "../src/MNT4TatePairing.sol";

contract F4CodeShardStore {
    constructor(bytes memory blob) payable {
        assembly ("memory-safe") {
            return(add(blob, 0x20), mload(blob))
        }
    }
}

contract MNT4OptimizationLadderHarness {
    function prepareFixedQBlobSparse() external pure returns (bytes memory dblSparse, bytes memory addSparse) {
        return MNT4TatePairing.prepareFixedQBlobSparse();
    }

    function pairingFixedQOnchainWord(MNT4TatePairing.G1Affine memory p) external pure returns (uint256) {
        return MNT4TatePairing.tatePairingFixedQOnchainMemWord(p);
    }

    function pairingPreparedSparseBlobWord(
        MNT4TatePairing.G1Affine memory p,
        bytes memory dblSparse,
        bytes memory addSparse
    ) external pure returns (uint256) {
        return MNT4TatePairing.tatePairingFixedQPreparedSparseMemWord(p, dblSparse, addSparse);
    }

    function pairingPreparedSparseBlobDigest(
        MNT4TatePairing.G1Affine memory p,
        bytes memory dblSparse,
        bytes memory addSparse
    ) external pure returns (bytes32) {
        return MNT4TatePairing.tatePairingFixedQPreparedSparseMemDigest(p, dblSparse, addSparse);
    }

    function pairingPreparedSparseAggressiveDigest(
        MNT4TatePairing.G1Affine memory p,
        bytes memory dblSparse,
        bytes memory addSparse
    ) external pure returns (bytes32) {
        return MNT4TatePairing.tatePairingFixedQPreparedSparseMemDigestAggressive(p, dblSparse, addSparse);
    }

    function millerPreparedSparseBlobDigest(
        MNT4TatePairing.G1Affine memory p,
        bytes memory dblSparse,
        bytes memory addSparse
    ) external pure returns (bytes32) {
        return MNT4TatePairing.millerLoopFixedQPreparedSparseBlobNoInvMemDigest(p, dblSparse, addSparse);
    }

    function millerPreparedSparseAggressiveDigest(
        MNT4TatePairing.G1Affine memory p,
        bytes memory dblSparse,
        bytes memory addSparse
    ) external pure returns (bytes32) {
        return MNT4TatePairing.millerLoopFixedQPreparedSparseBlobNoInvMemDigestAggressive(p, dblSparse, addSparse);
    }

    function pairingPreparedSparseCodeShardsWord(
        MNT4TatePairing.G1Affine memory p,
        address[] memory dblShards,
        address[] memory addShards
    ) external view returns (uint256) {
        return MNT4TatePairing.tatePairingFixedQPreparedSparseCodeShardsMemWord(p, dblShards, addShards);
    }
}

contract MNT4OptimizationLadderTest is Test {
    MNT4OptimizationLadderHarness harness;
    bytes dblSparse;
    bytes addSparse;
    address[] dblShards;
    address[] addShards;

    function setUp() public {
        harness = new MNT4OptimizationLadderHarness();
        (dblSparse, addSparse) = harness.prepareFixedQBlobSparse();
        dblShards = _deployCodeShards(dblSparse);
        addShards = _deployCodeShards(addSparse);
    }

    function _g1Gen() internal pure returns (MNT4TatePairing.G1Affine memory p) {
        p.x[0] = 0xd4b08cafff2dfb656ea99eb96cbb6fd6052f720cf67fbafc82ea8185e14d5d54;
        p.x[1] = 0xc813b87e370cda4d34c48c9b8ab9debf0c78f1afe0bd37b1e980e9a988adf90f;
        p.x[2] = 0x1bd4456a09aee9d956c795a3e78bd21790773a524d083c217e0a038c1db6;
        p.y[0] = 0x493bee51803a2b7a73296013aba459c3329803b147e38c38da05d6d7deada1ce;
        p.y[1] = 0xc263cc5a14d619cd3c971a9bca41f277c7bd91c2067595eb910c4887b84c27f2;
        p.y[2] = 0x1825593937b81fa08d2f1880d5f7435bf83c9522e6d7412d00fc9d68d790b;
    }

    function _deployCodeShards(bytes memory blob) internal returns (address[] memory shards) {
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
                for { let p := 0 } lt(p, len) { p := add(p, 0x20) } {
                    mstore(add(dst, p), mload(add(src, p)))
                }
            }
            shards[i] = address(new F4CodeShardStore(part));
            off += len;
        }
    }

    function testLadder_fixedQOnchainLineGeneration() public view {
        uint256 x0 = harness.pairingFixedQOnchainWord(_g1Gen());
        assertTrue(x0 != 0);
    }

    function testLadder_preparedSparseBlob() public view {
        uint256 x0 = harness.pairingPreparedSparseBlobWord(_g1Gen(), dblSparse, addSparse);
        assertTrue(x0 != 0);
    }

    function testLadder_preparedSparseBlobDigest() public view {
        bytes32 d = harness.pairingPreparedSparseBlobDigest(_g1Gen(), dblSparse, addSparse);
        assertTrue(d != bytes32(0));
    }

    function testLadder_preparedSparseAggressiveDigest() public view {
        bytes32 d = harness.pairingPreparedSparseAggressiveDigest(_g1Gen(), dblSparse, addSparse);
        assertTrue(d != bytes32(0));
    }

    function testLadder_millerPreparedSparseBlobDigest() public view {
        bytes32 d = harness.millerPreparedSparseBlobDigest(_g1Gen(), dblSparse, addSparse);
        assertTrue(d != bytes32(0));
    }

    function testLadder_millerPreparedSparseAggressiveDigest() public view {
        bytes32 d = harness.millerPreparedSparseAggressiveDigest(_g1Gen(), dblSparse, addSparse);
        assertTrue(d != bytes32(0));
    }

    function testLadder_preparedSparseCodeShards() public view {
        uint256 x0 = harness.pairingPreparedSparseCodeShardsWord(_g1Gen(), dblShards, addShards);
        assertTrue(x0 != 0);
    }
}
