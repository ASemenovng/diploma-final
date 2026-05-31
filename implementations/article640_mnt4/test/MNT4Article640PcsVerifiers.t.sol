// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Test} from "forge-std/Test.sol";
import {Article640KzgBn254OpeningVerifier} from "../src/Article640KzgBn254OpeningVerifier.sol";
import {Article640MerkleFriOpeningVerifier} from "../src/Article640MerkleFriOpeningVerifier.sol";

contract MNT4Article640PcsVerifiersTest is Test {
    Article640KzgBn254OpeningVerifier private kzg;
    Article640MerkleFriOpeningVerifier private merkleFri;

    function setUp() public {
        kzg = new Article640KzgBn254OpeningVerifier();
        merkleFri = new Article640MerkleFriOpeningVerifier();
    }

    function testKzgOpeningAcceptedForLinearPolynomial() public view {
        // Toy SRS with tau=1. Polynomial p(X)=3X+5, challenge x=7, y=26.
        // commitment = p(tau)G1 = 8G1; proof = 3G1.
        Article640KzgBn254OpeningVerifier.G1Point memory commitment = _g1Mul(8);
        Article640KzgBn254OpeningVerifier.G1Point memory proof = _g1Mul(3);
        assertTrue(kzg.verifyOpening(commitment, 7, 26, proof));
    }

    function testKzgOpeningRejectsWrongValue() public view {
        Article640KzgBn254OpeningVerifier.G1Point memory commitment = _g1Mul(8);
        Article640KzgBn254OpeningVerifier.G1Point memory proof = _g1Mul(3);
        assertFalse(kzg.verifyOpening(commitment, 7, 27, proof));
    }

    function testGas_kzgOpeningVerifier() public view {
        Article640KzgBn254OpeningVerifier.G1Point memory commitment = _g1Mul(8);
        Article640KzgBn254OpeningVerifier.G1Point memory proof = _g1Mul(3);
        assertTrue(kzg.verifyOpening(commitment, 7, 26, proof));
    }

    function testMerkleOpeningAccepted() public view {
        (bytes32 root, bytes32 leaf, bytes32[] memory path) = _smallMerkleFixture();
        assertTrue(merkleFri.verifyOpening(root, leaf, 2, path));
    }

    function testMerkleOpeningRejectsWrongLeaf() public view {
        (bytes32 root,, bytes32[] memory path) = _smallMerkleFixture();
        assertFalse(merkleFri.verifyOpening(root, keccak256("wrong"), 2, path));
    }

    function testArticle640FriLayerAccepted() public view {
        (bytes32 root, bytes32 leaf, bytes32[] memory path) = _smallMerkleFixture();
        Article640MerkleFriOpeningVerifier.Opening[] memory openings = new Article640MerkleFriOpeningVerifier.Opening[](3);
        openings[0] = Article640MerkleFriOpeningVerifier.Opening({root: root, leaf: leaf, index: 2, siblings: path});
        openings[1] = Article640MerkleFriOpeningVerifier.Opening({root: root, leaf: leaf, index: 2, siblings: path});
        openings[2] = Article640MerkleFriOpeningVerifier.Opening({root: root, leaf: leaf, index: 2, siblings: path});
        assertTrue(merkleFri.verifyArticle640FriOpenings(bytes32(uint256(123)), openings));
    }

    function testGas_merkleFriOpeningsDepth16() public view {
        bytes32[] memory path = new bytes32[](16);
        bytes32 leaf = keccak256(abi.encodePacked(uint256(42)));
        bytes32 node = leaf;
        for (uint256 i = 0; i < path.length; ++i) {
            path[i] = keccak256(abi.encodePacked(uint256(i), bytes32(uint256(0xabc))));
            node = keccak256(abi.encodePacked(node, path[i]));
        }
        Article640MerkleFriOpeningVerifier.Opening[] memory openings = new Article640MerkleFriOpeningVerifier.Opening[](8);
        for (uint256 i = 0; i < openings.length; ++i) {
            openings[i] = Article640MerkleFriOpeningVerifier.Opening({root: node, leaf: leaf, index: 0, siblings: path});
        }
        assertTrue(merkleFri.verifyArticle640FriOpenings(bytes32(uint256(456)), openings));
    }

    function testCalldataModel_mnt4FriOpenings() public view {
        uint256 bytesNeeded = merkleFri.estimateMnt4FriCalldataBytes({
            openedMnt4FieldElements: 4096,
            merklePaths: 128,
            merkleDepth: 16,
            friLayerRoots: 16
        });
        assertEq(bytesNeeded, 4096 * 96 + 128 * 16 * 32 + 16 * 32);
    }

    function _smallMerkleFixture() private pure returns (bytes32 root, bytes32 leaf2, bytes32[] memory path) {
        bytes32 l0 = keccak256("leaf0");
        bytes32 l1 = keccak256("leaf1");
        bytes32 l2 = keccak256("leaf2");
        bytes32 l3 = keccak256("leaf3");
        bytes32 n01 = keccak256(abi.encodePacked(l0, l1));
        bytes32 n23 = keccak256(abi.encodePacked(l2, l3));
        root = keccak256(abi.encodePacked(n01, n23));
        leaf2 = l2;
        path = new bytes32[](2);
        path[0] = l3;
        path[1] = n01;
    }

    function _g1Mul(uint256 scalar) private view returns (Article640KzgBn254OpeningVerifier.G1Point memory p) {
        uint256[3] memory input = [uint256(1), uint256(2), scalar];
        uint256[2] memory output;
        bool ok;
        assembly ("memory-safe") {
            ok := staticcall(gas(), 7, input, 0x60, output, 0x40)
        }
        require(ok, "bn254 scalar mul failed");
        p = Article640KzgBn254OpeningVerifier.G1Point(output[0], output[1]);
    }
}
