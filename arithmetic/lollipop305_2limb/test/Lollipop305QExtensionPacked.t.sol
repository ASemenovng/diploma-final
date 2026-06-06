// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Test} from "forge-std/Test.sol";
import {Lollipop305QExtensionStack} from "../src/Lollipop305QExtensionStack.sol";
import {Lollipop305QExtensionPacked} from "../src/Lollipop305QExtensionPacked.sol";

contract Lollipop305QExtensionPackedHarness {
    function square(uint256[12] memory a) external pure returns (uint256[12] memory out) {
        uint256 pA;
        uint256 pOut;
        uint256 scratch;
        assembly ("memory-safe") {
            pA := mload(0x40)
            pOut := add(pA, 0x180)
            scratch := add(pOut, 0x180)
            mstore(0x40, add(scratch, 0x800))
        }
        Lollipop305QExtensionPacked.copyFq6FromArray(pA, a);
        Lollipop305QExtensionPacked.fq6SqrTo(pOut, pA, scratch);
        return Lollipop305QExtensionPacked.fq6ToArray(pOut);
    }

    function mulBy01(uint256[12] memory a, uint256[4] memory b0, uint256[4] memory b1)
        external
        pure
        returns (uint256[12] memory out)
    {
        uint256 pA;
        uint256 pB0;
        uint256 pB1;
        uint256 pOut;
        uint256 scratch;
        assembly ("memory-safe") {
            pA := mload(0x40)
            pB0 := add(pA, 0x180)
            pB1 := add(pB0, 0x80)
            pOut := add(pB1, 0x80)
            scratch := add(pOut, 0x180)
            mstore(0x40, add(scratch, 0x800))
        }
        Lollipop305QExtensionPacked.copyFq6FromArray(pA, a);
        Lollipop305QExtensionPacked.copyFq2FromArray(pB0, b0);
        Lollipop305QExtensionPacked.copyFq2FromArray(pB1, b1);
        Lollipop305QExtensionPacked.fq6MulBy01To(pOut, pA, pB0, pB1, scratch);
        return Lollipop305QExtensionPacked.fq6ToArray(pOut);
    }

    function mulBy02(uint256[12] memory a, uint256[4] memory b0, uint256[4] memory b2)
        external
        pure
        returns (uint256[12] memory out)
    {
        uint256 pA;
        uint256 pB0;
        uint256 pB2;
        uint256 pOut;
        uint256 scratch;
        assembly ("memory-safe") {
            pA := mload(0x40)
            pB0 := add(pA, 0x180)
            pB2 := add(pB0, 0x80)
            pOut := add(pB2, 0x80)
            scratch := add(pOut, 0x180)
            mstore(0x40, add(scratch, 0x800))
        }
        Lollipop305QExtensionPacked.copyFq6FromArray(pA, a);
        Lollipop305QExtensionPacked.copyFq2FromArray(pB0, b0);
        Lollipop305QExtensionPacked.copyFq2FromArray(pB2, b2);
        Lollipop305QExtensionPacked.fq6MulBy02To(pOut, pA, pB0, pB2, scratch);
        return Lollipop305QExtensionPacked.fq6ToArray(pOut);
    }

    function mul(uint256[12] memory a, uint256[12] memory b) external pure returns (uint256[12] memory out) {
        uint256 pA;
        uint256 pB;
        uint256 pOut;
        uint256 scratch;
        assembly ("memory-safe") {
            pA := mload(0x40)
            pB := add(pA, 0x180)
            pOut := add(pB, 0x180)
            scratch := add(pOut, 0x180)
            mstore(0x40, add(scratch, 0x800))
        }
        Lollipop305QExtensionPacked.copyFq6FromArray(pA, a);
        Lollipop305QExtensionPacked.copyFq6FromArray(pB, b);
        Lollipop305QExtensionPacked.fq6MulTo(pOut, pA, pB, scratch);
        return Lollipop305QExtensionPacked.fq6ToArray(pOut);
    }
}

contract Lollipop305QExtensionPackedTest is Test {
    Lollipop305QExtensionPackedHarness private harness;

    function setUp() public {
        harness = new Lollipop305QExtensionPackedHarness();
    }

    function testPackedSquareMatchesStack() public view {
        uint256[12] memory a = _fq6();
        _assertEq(harness.square(a), Lollipop305QExtensionStack.fq6Sqr(a));
    }

    function testPackedMulBy01MatchesStack() public view {
        uint256[12] memory a = _fq6();
        uint256[4] memory b0 = [uint256(0x12), uint256(3), uint256(0x45), uint256(6)];
        uint256[4] memory b1 = [uint256(0x78), uint256(9), uint256(0xab), uint256(0xc)];
        _assertEq(harness.mulBy01(a, b0, b1), Lollipop305QExtensionStack.fq6MulBy01(a, b0, b1));
    }

    function testPackedMulBy02MatchesStack() public view {
        uint256[12] memory a = _fq6();
        uint256[4] memory b0 = [uint256(0x12), uint256(3), uint256(0x45), uint256(6)];
        uint256[4] memory b2 = [uint256(0x78), uint256(9), uint256(0xab), uint256(0xc)];
        _assertEq(harness.mulBy02(a, b0, b2), Lollipop305QExtensionStack.fq6MulBy02(a, b0, b2));
    }

    function testPackedMulMatchesStack() public view {
        uint256[12] memory a = _fq6();
        uint256[12] memory b = [uint256(13), 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24];
        _assertEq(harness.mul(a, b), Lollipop305QExtensionStack.fq6Mul(a, b));
    }

    function _fq6() private pure returns (uint256[12] memory a) {
        a = [uint256(1), 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12];
    }

    function _assertEq(uint256[12] memory a, uint256[12] memory b) private pure {
        for (uint256 i; i < 12; ++i) {
            assertEq(a[i], b[i], "packed fq6 mismatch");
        }
    }
}
