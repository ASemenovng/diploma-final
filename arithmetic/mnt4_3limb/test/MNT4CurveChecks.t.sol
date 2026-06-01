// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Test} from "forge-std/Test.sol";
import {MNT4CurveChecks} from "../src/MNT4CurveChecks.sol";

contract MNT4CurveChecksTest is Test {
    function testG1GeneratorIsAccepted() public pure {
        (uint256[3] memory x, uint256[3] memory y) = _g1GeneratorMontgomery();
        assertTrue(MNT4CurveChecks.isOnG1(x, y));
    }

    function testTamperedG1CoordinateIsRejected() public pure {
        (uint256[3] memory x, uint256[3] memory y) = _g1GeneratorMontgomery();
        x[0] ^= 1;
        assertFalse(MNT4CurveChecks.isOnG1(x, y));
    }

    function testNonCanonicalCoordinateIsRejected() public pure {
        (uint256[3] memory x, uint256[3] memory y) = _g1GeneratorMontgomery();
        x = [
            uint256(0x685acce9767254a4638810719ac425f0e39d54522cdd119f5e9063de245e8001),
            uint256(0x7fdb925e8a0ed8d99d124d9a15af79db117e776f218059db80f0da5cb537e38),
            uint256(0x0001c4c62d92c41110229022eee2cdadb7f997505b8fafed5eb7e8f96c97d873)
        ];
        assertFalse(MNT4CurveChecks.isOnG1(x, y));
    }

    function _g1GeneratorMontgomery() private pure returns (uint256[3] memory x, uint256[3] memory y) {
        x = [
            uint256(0xd4b08cafff2dfb656ea99eb96cbb6fd6052f720cf67fbafc82ea8185e14d5d54),
            uint256(0xc813b87e370cda4d34c48c9b8ab9debf0c78f1afe0bd37b1e980e9a988adf90f),
            uint256(0x00001bd4456a09aee9d956c795a3e78bd21790773a524d083c217e0a038c1db6)
        ];
        y = [
            uint256(0x493bee51803a2b7a73296013aba459c3329803b147e38c38da05d6d7deada1ce),
            uint256(0xc263cc5a14d619cd3c971a9bca41f277c7bd91c2067595eb910c4887b84c27f2),
            uint256(0x0001825593937b81fa08d2f1880d5f7435bf83c9522e6d7412d00fc9d68d790b)
        ];
    }
}
