// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import "forge-std/Test.sol";
import {MNT4TatePairingNaive} from "../src/MNT4TatePairingNaive.sol";

contract MNT4TatePairingNaiveTest is Test {
    MNT4TatePairingNaive naive;

    function setUp() public {
        naive = new MNT4TatePairingNaive();
    }

    function testFpRoundtripSmall() public view {
        uint256[3] memory mont = naive.fpFromUint(123456789);
        uint256[3] memory normal = naive.fpFromMontgomery(mont);
        assertEq(normal[0], 123456789);
        assertEq(normal[1], 0);
        assertEq(normal[2], 0);
    }

    function testFpMulSmall() public view {
        uint256[3] memory a = naive.fpFromUint(12345);
        uint256[3] memory b = naive.fpFromUint(6789);
        uint256[3] memory c = naive.fpMul(a, b);
        uint256[3] memory normal = naive.fpFromMontgomery(c);
        assertEq(normal[0], 83810205);
        assertEq(normal[1], 0);
        assertEq(normal[2], 0);
    }

    function testFq2MulMatchesTowerFormulaForSmallValues() public view {
        uint256[6] memory a = naive.fq2FromUint(2, 3);
        uint256[6] memory b = naive.fq2FromUint(5, 7);
        uint256[6] memory c = naive.fq2Mul(a, b);
        uint256[6] memory normal = naive.fq2FromMontgomery(c);
        // (2 + 3u)(5 + 7u), u^2 = 13 => c0 = 10 + 13*21 = 283, c1 = 14 + 15 = 29.
        assertEq(normal[0], 283);
        assertEq(normal[1], 0);
        assertEq(normal[2], 0);
        assertEq(normal[3], 29);
        assertEq(normal[4], 0);
        assertEq(normal[5], 0);
    }

    function testNaiveMillerStepMatchesGenericDefinition() public view {
        uint256[12] memory f = naive.fq4SeedA();
        uint256[12] memory line = naive.fq4SeedB();
        bytes32 direct = keccak256(abi.encode(naive.fq4Mul(naive.fq4Sqr(f), line)));
        bytes32 step = keccak256(abi.encode(naive.naiveMillerStep(f, line)));
        assertEq(step, direct);
    }

    function testGasNaiveFq4MulAndSquare() public view {
        naive.benchFq4MulOnce();
        naive.benchFq4SqrOnce();
    }

    function testGasNaiveMillerStep() public view {
        naive.benchNaiveMillerSteps(1);
    }

    function testGasNaiveFinalExponentiationChunk() public view {
        naive.benchNaiveFinalExponentiationChunk16();
    }
}
