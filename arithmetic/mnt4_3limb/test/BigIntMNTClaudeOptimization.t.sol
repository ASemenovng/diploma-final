// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import "forge-std/Test.sol";
import "../src/BigIntMNT.sol";
import "../research_variants/BigIntMNTFinalSelect.sol";
import "../research_variants/BigIntMNTSkipT0.sol";

contract BigIntMNTClaudeOptimizationBench {
    uint256 internal constant N = 512;
    uint256 private constant P_0 = 0x685acce9767254a4638810719ac425f0e39d54522cdd119f5e9063de245e8001;
    uint256 private constant P_1 = 0x7fdb925e8a0ed8d99d124d9a15af79db117e776f218059db80f0da5cb537e38;
    uint256 private constant P_2 = 0x1c4c62d92c41110229022eee2cdadb7f997505b8fafed5eb7e8f96c97d873;

    function _a() internal pure returns (uint256 a0, uint256 a1, uint256 a2) {
        return BigIntMNT.toMontgomery3(
            P_0 - 0x123456789abcdef0123456789abcdef0,
            P_1 - 0x11111111111111111111111111111111,
            P_2 - 0x12345
        );
    }

    function _b() internal pure returns (uint256 b0, uint256 b1, uint256 b2) {
        return BigIntMNT.toMontgomery3(
            P_0 - 0x0fedcba9876543210fedcba987654321,
            P_1 - 0x22222222222222222222222222222222,
            P_2 - 0x23456
        );
    }

    function benchCurrentMul3() external pure returns (uint256 r0, uint256 r1, uint256 r2) {
        (uint256 a0, uint256 a1, uint256 a2) = _a();
        (uint256 b0, uint256 b1, uint256 b2) = _b();
        for (uint256 i; i < N; ) {
            (a0, a1, a2) = BigIntMNT.montMul3(a0, a1, a2, b0, b1, b2);
            unchecked { ++i; }
        }
        return (a0, a1, a2);
    }

    function benchCurrentSqr3() external pure returns (uint256 r0, uint256 r1, uint256 r2) {
        (uint256 a0, uint256 a1, uint256 a2) = _a();
        for (uint256 i; i < N; ) {
            (a0, a1, a2) = BigIntMNT.montSqr3(a0, a1, a2);
            unchecked { ++i; }
        }
        return (a0, a1, a2);
    }

    function benchFinalSelectMul3() external pure returns (uint256 r0, uint256 r1, uint256 r2) {
        (uint256 a0, uint256 a1, uint256 a2) = _a();
        (uint256 b0, uint256 b1, uint256 b2) = _b();
        for (uint256 i; i < N; ) {
            (a0, a1, a2) = BigIntMNTFinalSelect.montMul3(a0, a1, a2, b0, b1, b2);
            unchecked { ++i; }
        }
        return (a0, a1, a2);
    }

    function benchFinalSelectSqr3() external pure returns (uint256 r0, uint256 r1, uint256 r2) {
        (uint256 a0, uint256 a1, uint256 a2) = _a();
        for (uint256 i; i < N; ) {
            (a0, a1, a2) = BigIntMNTFinalSelect.montSqr3(a0, a1, a2);
            unchecked { ++i; }
        }
        return (a0, a1, a2);
    }

    function benchSkipT0Mul3() external pure returns (uint256 r0, uint256 r1, uint256 r2) {
        (uint256 a0, uint256 a1, uint256 a2) = _a();
        (uint256 b0, uint256 b1, uint256 b2) = _b();
        for (uint256 i; i < N; ) {
            (a0, a1, a2) = BigIntMNTSkipT0.montMul3(a0, a1, a2, b0, b1, b2);
            unchecked { ++i; }
        }
        return (a0, a1, a2);
    }

    function benchSkipT0Sqr3() external pure returns (uint256 r0, uint256 r1, uint256 r2) {
        (uint256 a0, uint256 a1, uint256 a2) = _a();
        for (uint256 i; i < N; ) {
            (a0, a1, a2) = BigIntMNTSkipT0.montSqr3(a0, a1, a2);
            unchecked { ++i; }
        }
        return (a0, a1, a2);
    }
}

contract BigIntMNTClaudeOptimizationTest is Test {
    BigIntMNTClaudeOptimizationBench bench;

    function setUp() public {
        bench = new BigIntMNTClaudeOptimizationBench();
    }

    function _assertEq3(uint256[3] memory a, uint256[3] memory b) internal pure {
        assert(a[0] == b[0] && a[1] == b[1] && a[2] == b[2]);
    }

    function testCandidatesMatchCurrentForBoundaryVectors() public pure {
        uint256 p0 = 0x685acce9767254a4638810719ac425f0e39d54522cdd119f5e9063de245e8001;
        uint256 p1 = 0x7fdb925e8a0ed8d99d124d9a15af79db117e776f218059db80f0da5cb537e38;
        uint256 p2 = 0x1c4c62d92c41110229022eee2cdadb7f997505b8fafed5eb7e8f96c97d873;
        for (uint256 i = 1; i <= 64; ++i) {
            (uint256 a0, uint256 a1, uint256 a2) = BigIntMNT.toMontgomery3(p0 - i * 0x12345, p1 - i * 0x23456, p2 - i);
            (uint256 b0, uint256 b1, uint256 b2) = BigIntMNT.toMontgomery3(p0 - i * 0x34567, p1 - i * 0x45678, p2 - i * 2);
            (uint256 e0, uint256 e1, uint256 e2) = BigIntMNT.montMul3(a0, a1, a2, b0, b1, b2);
            (uint256 f0, uint256 f1, uint256 f2) = BigIntMNTFinalSelect.montMul3(a0, a1, a2, b0, b1, b2);
            _assertEq3([f0, f1, f2], [e0, e1, e2]);
            (uint256 s0, uint256 s1, uint256 s2) = BigIntMNTSkipT0.montMul3(a0, a1, a2, b0, b1, b2);
            _assertEq3([s0, s1, s2], [e0, e1, e2]);
        }
    }

    function testGasReport_claudeCandidates() public {
        (uint256 a0, uint256 a1, uint256 a2) = bench.benchCurrentMul3();
        assertTrue((a0 | a1 | a2) != 0);
        (a0, a1, a2) = bench.benchCurrentSqr3();
        assertTrue((a0 | a1 | a2) != 0);
        (a0, a1, a2) = bench.benchFinalSelectMul3();
        assertTrue((a0 | a1 | a2) != 0);
        (a0, a1, a2) = bench.benchFinalSelectSqr3();
        assertTrue((a0 | a1 | a2) != 0);
        (a0, a1, a2) = bench.benchSkipT0Mul3();
        assertTrue((a0 | a1 | a2) != 0);
        (a0, a1, a2) = bench.benchSkipT0Sqr3();
        assertTrue((a0 | a1 | a2) != 0);
    }
}
