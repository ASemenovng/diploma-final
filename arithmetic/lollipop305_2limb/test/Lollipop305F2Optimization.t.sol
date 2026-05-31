// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import "forge-std/Test.sol";
import "../src/BigIntLollipop305.sol";
import "../research_variants/BigIntLollipop305FinalSelect.sol";
import "../research_variants/BigIntLollipop305SkipT0.sol";
import "../research_variants/BigIntLollipop305SmallHigh.sol";
import "../research_variants/BigIntLollipop305SmallHighSkipT0.sol";

contract Lollipop305F2OptimizationBench {
    uint256 internal constant N = 512;
    uint256 private constant P_0 = 0x24240b65671ab020b2f03c6035ed8fdcdd1ff464dbb7022f6583adbbb2fef163;
    uint256 private constant P_1 = 0x1f733286263df;

    function _a() internal pure returns (uint256 a0, uint256 a1) {
        return BigIntLollipop305.toMontgomery2(P_0 - 0x123456789abcdef, P_1 - 0x1234);
    }

    function _b() internal pure returns (uint256 b0, uint256 b1) {
        return BigIntLollipop305.toMontgomery2(P_0 - 0x0fedcba98765432, P_1 - 0x2345);
    }

    function benchCurrentMul2() external pure returns (uint256 r0, uint256 r1) {
        (uint256 a0, uint256 a1) = _a();
        (uint256 b0, uint256 b1) = _b();
        for (uint256 i; i < N; ) {
            (a0, a1) = BigIntLollipop305.montMul2(a0, a1, b0, b1);
            unchecked { ++i; }
        }
        return (a0, a1);
    }

    function benchCurrentSqr2() external pure returns (uint256 r0, uint256 r1) {
        (uint256 a0, uint256 a1) = _a();
        for (uint256 i; i < N; ) {
            (a0, a1) = BigIntLollipop305.montSqr2(a0, a1);
            unchecked { ++i; }
        }
        return (a0, a1);
    }

    function benchFinalSelectMul2() external pure returns (uint256 r0, uint256 r1) {
        (uint256 a0, uint256 a1) = _a();
        (uint256 b0, uint256 b1) = _b();
        for (uint256 i; i < N; ) {
            (a0, a1) = BigIntLollipop305FinalSelect.montMul2(a0, a1, b0, b1);
            unchecked { ++i; }
        }
        return (a0, a1);
    }

    function benchSkipT0Mul2() external pure returns (uint256 r0, uint256 r1) {
        (uint256 a0, uint256 a1) = _a();
        (uint256 b0, uint256 b1) = _b();
        for (uint256 i; i < N; ) {
            (a0, a1) = BigIntLollipop305SkipT0.montMul2(a0, a1, b0, b1);
            unchecked { ++i; }
        }
        return (a0, a1);
    }

    function benchSmallHighMul2() external pure returns (uint256 r0, uint256 r1) {
        (uint256 a0, uint256 a1) = _a();
        (uint256 b0, uint256 b1) = _b();
        for (uint256 i; i < N; ) {
            (a0, a1) = BigIntLollipop305SmallHigh.montMul2(a0, a1, b0, b1);
            unchecked { ++i; }
        }
        return (a0, a1);
    }

    function benchSmallHighSqr2() external pure returns (uint256 r0, uint256 r1) {
        (uint256 a0, uint256 a1) = _a();
        for (uint256 i; i < N; ) {
            (a0, a1) = BigIntLollipop305SmallHigh.montSqr2(a0, a1);
            unchecked { ++i; }
        }
        return (a0, a1);
    }

    function benchSmallHighSkipT0Mul2() external pure returns (uint256 r0, uint256 r1) {
        (uint256 a0, uint256 a1) = _a();
        (uint256 b0, uint256 b1) = _b();
        for (uint256 i; i < N; ) {
            (a0, a1) = BigIntLollipop305SmallHighSkipT0.montMul2(a0, a1, b0, b1);
            unchecked { ++i; }
        }
        return (a0, a1);
    }

    function benchSmallHighSkipT0Sqr2() external pure returns (uint256 r0, uint256 r1) {
        (uint256 a0, uint256 a1) = _a();
        for (uint256 i; i < N; ) {
            (a0, a1) = BigIntLollipop305SmallHighSkipT0.montSqr2(a0, a1);
            unchecked { ++i; }
        }
        return (a0, a1);
    }
}

contract Lollipop305F2OptimizationTest is Test {
    Lollipop305F2OptimizationBench bench;

    function setUp() public { bench = new Lollipop305F2OptimizationBench(); }

    function _assertEq2(uint256 a0, uint256 a1, uint256 b0, uint256 b1) internal pure {
        assertEq(a0, b0);
        assertEq(a1, b1);
    }

    function testCandidatesMatchCurrentOnBoundaryVectors() public pure {
        uint256 p0 = BigIntLollipop305.P0();
        uint256 p1 = BigIntLollipop305.P1();
        for (uint256 i = 1; i <= 64; ++i) {
            (uint256 a0, uint256 a1) = BigIntLollipop305.toMontgomery2(p0 - i * 0x12345, p1 - i);
            (uint256 b0, uint256 b1) = BigIntLollipop305.toMontgomery2(p0 - i * 0x23456, p1 - i * 2);
            (uint256 e0, uint256 e1) = BigIntLollipop305.montMul2(a0, a1, b0, b1);
            (uint256 r0, uint256 r1) = BigIntLollipop305FinalSelect.montMul2(a0, a1, b0, b1);
            _assertEq2(r0, r1, e0, e1);
            (r0, r1) = BigIntLollipop305SkipT0.montMul2(a0, a1, b0, b1);
            _assertEq2(r0, r1, e0, e1);
            (r0, r1) = BigIntLollipop305SmallHigh.montMul2(a0, a1, b0, b1);
            _assertEq2(r0, r1, e0, e1);
            (r0, r1) = BigIntLollipop305SmallHighSkipT0.montMul2(a0, a1, b0, b1);
            _assertEq2(r0, r1, e0, e1);
        }
    }

    function testSmallHighSqrMatchesCurrentOnBoundaryVectors() public pure {
        uint256 p0 = BigIntLollipop305.P0();
        uint256 p1 = BigIntLollipop305.P1();
        for (uint256 i = 1; i <= 64; ++i) {
            (uint256 a0, uint256 a1) = BigIntLollipop305.toMontgomery2(p0 - i * 0x12345, p1 - i);
            (uint256 e0, uint256 e1) = BigIntLollipop305.montSqr2(a0, a1);
            (uint256 r0, uint256 r1) = BigIntLollipop305SmallHigh.montSqr2(a0, a1);
            _assertEq2(r0, r1, e0, e1);
            (r0, r1) = BigIntLollipop305SmallHighSkipT0.montSqr2(a0, a1);
            _assertEq2(r0, r1, e0, e1);
        }
    }

    function testFuzz_SmallHighMatchesCurrentForReducedInputs(
        uint256 a0,
        uint64 a1Raw,
        uint256 b0,
        uint64 b1Raw
    ) public pure {
        uint256 p1 = BigIntLollipop305.P1();
        uint256 a1 = uint256(a1Raw) % (p1 + 1);
        uint256 b1 = uint256(b1Raw) % (p1 + 1);
        if (a1 == p1 && a0 >= BigIntLollipop305.P0()) a0 = BigIntLollipop305.P0() - 1;
        if (b1 == p1 && b0 >= BigIntLollipop305.P0()) b0 = BigIntLollipop305.P0() - 1;

        (uint256 e0, uint256 e1) = BigIntLollipop305.montMul2(a0, a1, b0, b1);
        (uint256 r0, uint256 r1) = BigIntLollipop305SmallHigh.montMul2(a0, a1, b0, b1);
        _assertEq2(r0, r1, e0, e1);

        (e0, e1) = BigIntLollipop305.montSqr2(a0, a1);
        (r0, r1) = BigIntLollipop305SmallHigh.montSqr2(a0, a1);
        _assertEq2(r0, r1, e0, e1);
    }

    function testGasReport_f2Candidates() public view {
        (uint256 a0, uint256 a1) = bench.benchCurrentMul2();
        assertTrue((a0 | a1) != 0);
        (a0, a1) = bench.benchCurrentSqr2();
        assertTrue((a0 | a1) != 0);
        (a0, a1) = bench.benchFinalSelectMul2();
        assertTrue((a0 | a1) != 0);
        (a0, a1) = bench.benchSkipT0Mul2();
        assertTrue((a0 | a1) != 0);
        (a0, a1) = bench.benchSmallHighMul2();
        assertTrue((a0 | a1) != 0);
        (a0, a1) = bench.benchSmallHighSqr2();
        assertTrue((a0 | a1) != 0);
        (a0, a1) = bench.benchSmallHighSkipT0Mul2();
        assertTrue((a0 | a1) != 0);
        (a0, a1) = bench.benchSmallHighSkipT0Sqr2();
        assertTrue((a0 | a1) != 0);
    }
}
