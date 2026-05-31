// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import "forge-std/Test.sol";
import "../src/BigIntLollipop305Q.sol";
import "../src/Lollipop305QExtensionStack.sol";

contract Lollipop305CycleQArithmeticBench {
    uint256 internal constant N_FP = 512;

    function benchFqMul() external pure returns (uint256 r0, uint256 r1) {
        (uint256 a0, uint256 a1) = BigIntLollipop305Q.toMontgomery2(123456789, 0);
        (uint256 b0, uint256 b1) = BigIntLollipop305Q.toMontgomery2(987654321, 0);
        for (uint256 i; i < N_FP; ) {
            (a0, a1) = BigIntLollipop305Q.montMul2(a0, a1, b0, b1);
            unchecked { ++i; }
        }
        return (a0, a1);
    }

    function benchFq2Mul() external pure returns (uint256 r0, uint256 r1, uint256 r2, uint256 r3) {
        (uint256 a00, uint256 a01) = BigIntLollipop305Q.toMontgomery2(3, 0);
        (uint256 a10, uint256 a11) = BigIntLollipop305Q.toMontgomery2(5, 0);
        (uint256 b00, uint256 b01) = BigIntLollipop305Q.toMontgomery2(7, 0);
        (uint256 b10, uint256 b11) = BigIntLollipop305Q.toMontgomery2(11, 0);
        uint256 t0; uint256 t1; uint256 t2; uint256 t3;
        for (uint256 i; i < 128; ) {
            if ((i & 1) == 0) {
                (t0,t1,t2,t3) = Lollipop305QExtensionStack.fq2Mul(a00,a01,a10,a11,b00,b01,b10,b11);
            } else {
                (a00,a01,a10,a11) = Lollipop305QExtensionStack.fq2Mul(t0,t1,t2,t3,b00,b01,b10,b11);
            }
            unchecked { ++i; }
        }
        return (N_FP & 1) == 0 ? (a00,a01,a10,a11) : (t0,t1,t2,t3);
    }

    function benchFq2Sqr() external pure returns (uint256 r0, uint256 r1, uint256 r2, uint256 r3) {
        (uint256 a00, uint256 a01) = BigIntLollipop305Q.toMontgomery2(3, 0);
        (uint256 a10, uint256 a11) = BigIntLollipop305Q.toMontgomery2(5, 0);
        uint256 t0; uint256 t1; uint256 t2; uint256 t3;
        for (uint256 i; i < 128; ) {
            if ((i & 1) == 0) {
                (t0,t1,t2,t3) = Lollipop305QExtensionStack.fq2Sqr(a00,a01,a10,a11);
            } else {
                (a00,a01,a10,a11) = Lollipop305QExtensionStack.fq2Sqr(t0,t1,t2,t3);
            }
            unchecked { ++i; }
        }
        return (N_FP & 1) == 0 ? (a00,a01,a10,a11) : (t0,t1,t2,t3);
    }

    function benchFqSqr() external pure returns (uint256 r0, uint256 r1) {
        (uint256 a0, uint256 a1) = BigIntLollipop305Q.toMontgomery2(123456789, 0);
        for (uint256 i; i < N_FP; ) {
            (a0, a1) = BigIntLollipop305Q.montSqr2(a0, a1);
            unchecked { ++i; }
        }
        return (a0, a1);
    }
}

contract Lollipop305CycleQArithmeticTest is Test {
    Lollipop305CycleQArithmeticBench bench;

    function setUp() public {
        bench = new Lollipop305CycleQArithmeticBench();
    }

    function testQModulusConstantsMatchEprint1627Example1() public pure {
        assertEq(BigIntLollipop305Q.Q0(), 0x24240b65671ab020b2f03c60375479cf7ce39138369e001f5dad2ea32fdd0085);
        assertEq(BigIntLollipop305Q.Q1(), 0x1f733286263df);
    }

    function testFqMontgomeryRoundtrip() public pure {
        (uint256 a0, uint256 a1) = BigIntLollipop305Q.toMontgomery2(123456789, 0);
        (uint256 r0, uint256 r1) = BigIntLollipop305Q.fromMontgomery2(a0, a1);
        assertEq(r0, 123456789);
        assertEq(r1, 0);
    }

    function testFqMulMatchesSmallIntegerProduct() public pure {
        (uint256 a0, uint256 a1) = BigIntLollipop305Q.toMontgomery2(123456789, 0);
        (uint256 b0, uint256 b1) = BigIntLollipop305Q.toMontgomery2(987654321, 0);
        (uint256 c0, uint256 c1) = BigIntLollipop305Q.montMul2(a0, a1, b0, b1);
        (uint256 r0, uint256 r1) = BigIntLollipop305Q.fromMontgomery2(c0, c1);
        assertEq(r0, 121932631112635269);
        assertEq(r1, 0);
    }

    function testGasFqMul() public view {
        bench.benchFqMul();
    }

    function testGasFqSqr() public view {
        bench.benchFqSqr();
    }

    function testFq2MulMatchesEtaSquaredMinusTwo() public pure {
        (uint256 zero0, uint256 zero1) = BigIntLollipop305Q.toMontgomery2(0, 0);
        (uint256 one0, uint256 one1) = BigIntLollipop305Q.toMontgomery2(1, 0);
        (uint256 r0, uint256 r1, uint256 r2, uint256 r3) =
            Lollipop305QExtensionStack.fq2Sqr(zero0, zero1, one0, one1);
        (uint256 out0, uint256 out1) = BigIntLollipop305Q.fromMontgomery2(r0, r1);
        assertEq(out0, BigIntLollipop305Q.Q0() - 2);
        assertEq(out1, BigIntLollipop305Q.Q1());
        (uint256 out2, uint256 out3) = BigIntLollipop305Q.fromMontgomery2(r2, r3);
        assertEq(out2, 0);
        assertEq(out3, 0);
    }

    function testGasFq2Mul() public view {
        bench.benchFq2Mul();
    }

    function testGasFq2Sqr() public view {
        bench.benchFq2Sqr();
    }
}
