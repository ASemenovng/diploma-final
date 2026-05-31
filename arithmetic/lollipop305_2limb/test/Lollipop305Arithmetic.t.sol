// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import "forge-std/Test.sol";
import "../src/BigIntLollipop305.sol";
import "../research_variants/BigIntLollipop305Variants.sol";
import "../research_variants/Lollipop305Extension.sol";
import "../src/Lollipop305ExtensionStack.sol";

contract Lollipop305ArithmeticBench {
    uint256 internal constant N_FP = 512;
    uint256 internal constant N_EXT = 128;

    function benchFpMul() external pure returns (uint256 r0, uint256 r1) {
        (uint256 a0, uint256 a1) = BigIntLollipop305.toMontgomery2(123456789, 0);
        (uint256 b0, uint256 b1) = BigIntLollipop305.toMontgomery2(987654321, 0);
        for (uint256 i; i < N_FP; ) {
            (a0, a1) = BigIntLollipop305.montMul2(a0, a1, b0, b1);
            unchecked { ++i; }
        }
        return (a0, a1);
    }

    function benchFpSqr() external pure returns (uint256 r0, uint256 r1) {
        (uint256 a0, uint256 a1) = BigIntLollipop305.toMontgomery2(123456789, 0);
        for (uint256 i; i < N_FP; ) {
            (a0, a1) = BigIntLollipop305.montSqr2(a0, a1);
            unchecked { ++i; }
        }
        return (a0, a1);
    }

    function benchFpMulComba() external pure returns (uint256 r0, uint256 r1) {
        (uint256 a0, uint256 a1) = BigIntLollipop305.toMontgomery2(123456789, 0);
        (uint256 b0, uint256 b1) = BigIntLollipop305.toMontgomery2(987654321, 0);
        for (uint256 i; i < N_FP; ) {
            (a0, a1) = BigIntLollipop305Comba.montMul2(a0, a1, b0, b1);
            unchecked { ++i; }
        }
        return (a0, a1);
    }

    function benchFpMulFIOS() external pure returns (uint256 r0, uint256 r1) {
        (uint256 a0, uint256 a1) = BigIntLollipop305.toMontgomery2(123456789, 0);
        (uint256 b0, uint256 b1) = BigIntLollipop305.toMontgomery2(987654321, 0);
        for (uint256 i; i < N_FP; ) {
            (a0, a1) = BigIntLollipop305FIOS.montMul2(a0, a1, b0, b1);
            unchecked { ++i; }
        }
        return (a0, a1);
    }

    function benchFpMulBarrett() external pure returns (uint256 r0, uint256 r1) {
        uint256 a0 = 123456789;
        uint256 a1 = 0;
        uint256 b0 = 987654321;
        uint256 b1 = 0;
        for (uint256 i; i < N_FP; ) {
            (a0, a1) = BigIntLollipop305Barrett.mul2(a0, a1, b0, b1);
            unchecked { ++i; }
        }
        return (a0, a1);
    }

    function benchFp2Mul() external pure returns (Lollipop305Extension.Fp2 memory r) {
        Lollipop305Extension.Fp2 memory a = Lollipop305Extension.fp2FromRaw(3, 5);
        Lollipop305Extension.Fp2 memory b = Lollipop305Extension.fp2FromRaw(7, 11);
        Lollipop305Extension.Fp2 memory t;
        for (uint256 i; i < N_EXT; ) {
            if ((i & 1) == 0) Lollipop305Extension.fp2MulTo(t, a, b);
            else Lollipop305Extension.fp2MulTo(a, t, b);
            unchecked { ++i; }
        }
        return (N_EXT & 1) == 0 ? a : t;
    }

    function benchFp2Sqr() external pure returns (Lollipop305Extension.Fp2 memory r) {
        Lollipop305Extension.Fp2 memory a = Lollipop305Extension.fp2FromRaw(3, 5);
        Lollipop305Extension.Fp2 memory t;
        for (uint256 i; i < N_EXT; ) {
            if ((i & 1) == 0) Lollipop305Extension.fp2SqrTo(t, a);
            else Lollipop305Extension.fp2SqrTo(a, t);
            unchecked { ++i; }
        }
        return (N_EXT & 1) == 0 ? a : t;
    }

    function benchFp4Mul() external pure returns (Lollipop305Extension.Fp4 memory r) {
        Lollipop305Extension.Fp4 memory a = Lollipop305Extension.fp4FromRaw(3, 5, 7, 11);
        Lollipop305Extension.Fp4 memory b = Lollipop305Extension.fp4FromRaw(13, 17, 19, 23);
        Lollipop305Extension.Fp4 memory t;
        for (uint256 i; i < N_EXT; ) {
            if ((i & 1) == 0) Lollipop305Extension.fp4MulTo(t, a, b);
            else Lollipop305Extension.fp4MulTo(a, t, b);
            unchecked { ++i; }
        }
        return (N_EXT & 1) == 0 ? a : t;
    }

    function benchFp4Sqr() external pure returns (Lollipop305Extension.Fp4 memory r) {
        Lollipop305Extension.Fp4 memory a = Lollipop305Extension.fp4FromRaw(3, 5, 7, 11);
        Lollipop305Extension.Fp4 memory t;
        for (uint256 i; i < N_EXT; ) {
            if ((i & 1) == 0) Lollipop305Extension.fp4SqrTo(t, a);
            else Lollipop305Extension.fp4SqrTo(a, t);
            unchecked { ++i; }
        }
        return (N_EXT & 1) == 0 ? a : t;
    }

    function benchFp2MulStack() external pure returns (uint256 r0, uint256 r1, uint256 r2, uint256 r3) {
        (uint256 a00, uint256 a01) = BigIntLollipop305.toMontgomery2(3, 0);
        (uint256 a10, uint256 a11) = BigIntLollipop305.toMontgomery2(5, 0);
        (uint256 b00, uint256 b01) = BigIntLollipop305.toMontgomery2(7, 0);
        (uint256 b10, uint256 b11) = BigIntLollipop305.toMontgomery2(11, 0);
        uint256 t0; uint256 t1; uint256 t2; uint256 t3;
        for (uint256 i; i < N_EXT; ) {
            if ((i & 1) == 0) {
                (t0, t1, t2, t3) = Lollipop305ExtensionStack.fp2Mul(a00, a01, a10, a11, b00, b01, b10, b11);
            } else {
                (a00, a01, a10, a11) = Lollipop305ExtensionStack.fp2Mul(t0, t1, t2, t3, b00, b01, b10, b11);
            }
            unchecked { ++i; }
        }
        return (N_EXT & 1) == 0 ? (a00, a01, a10, a11) : (t0, t1, t2, t3);
    }

    function benchFp2SqrStack() external pure returns (uint256 r0, uint256 r1, uint256 r2, uint256 r3) {
        (uint256 a00, uint256 a01) = BigIntLollipop305.toMontgomery2(3, 0);
        (uint256 a10, uint256 a11) = BigIntLollipop305.toMontgomery2(5, 0);
        uint256 t0; uint256 t1; uint256 t2; uint256 t3;
        for (uint256 i; i < N_EXT; ) {
            if ((i & 1) == 0) {
                (t0, t1, t2, t3) = Lollipop305ExtensionStack.fp2Sqr(a00, a01, a10, a11);
            } else {
                (a00, a01, a10, a11) = Lollipop305ExtensionStack.fp2Sqr(t0, t1, t2, t3);
            }
            unchecked { ++i; }
        }
        return (N_EXT & 1) == 0 ? (a00, a01, a10, a11) : (t0, t1, t2, t3);
    }

    function benchFp4MulStack() external pure returns (uint256[8] memory r) {
        uint256[8] memory a;
        uint256[8] memory b;
        uint256[8] memory t;
        (a[0], a[1]) = BigIntLollipop305.toMontgomery2(3, 0);
        (a[2], a[3]) = BigIntLollipop305.toMontgomery2(5, 0);
        (a[4], a[5]) = BigIntLollipop305.toMontgomery2(7, 0);
        (a[6], a[7]) = BigIntLollipop305.toMontgomery2(11, 0);
        (b[0], b[1]) = BigIntLollipop305.toMontgomery2(13, 0);
        (b[2], b[3]) = BigIntLollipop305.toMontgomery2(17, 0);
        (b[4], b[5]) = BigIntLollipop305.toMontgomery2(19, 0);
        (b[6], b[7]) = BigIntLollipop305.toMontgomery2(23, 0);
        for (uint256 i; i < N_EXT; ) {
            if ((i & 1) == 0) t = Lollipop305ExtensionStack.fp4Mul(a, b);
            else a = Lollipop305ExtensionStack.fp4Mul(t, b);
            unchecked { ++i; }
        }
        return (N_EXT & 1) == 0 ? a : t;
    }

    function benchFp4SqrStack() external pure returns (uint256[8] memory r) {
        uint256[8] memory a;
        uint256[8] memory t;
        (a[0], a[1]) = BigIntLollipop305.toMontgomery2(3, 0);
        (a[2], a[3]) = BigIntLollipop305.toMontgomery2(5, 0);
        (a[4], a[5]) = BigIntLollipop305.toMontgomery2(7, 0);
        (a[6], a[7]) = BigIntLollipop305.toMontgomery2(11, 0);
        for (uint256 i; i < N_EXT; ) {
            if ((i & 1) == 0) t = Lollipop305ExtensionStack.fp4Sqr(a);
            else a = Lollipop305ExtensionStack.fp4Sqr(t);
            unchecked { ++i; }
        }
        return (N_EXT & 1) == 0 ? a : t;
    }

    function benchFp4MulFullStack()
        external
        pure
        returns (uint256 r0, uint256 r1, uint256 r2, uint256 r3, uint256 r4, uint256 r5, uint256 r6, uint256 r7)
    {
        (uint256 a0, uint256 a1) = BigIntLollipop305.toMontgomery2(3, 0);
        (uint256 a2, uint256 a3) = BigIntLollipop305.toMontgomery2(5, 0);
        (uint256 a4, uint256 a5) = BigIntLollipop305.toMontgomery2(7, 0);
        (uint256 a6, uint256 a7) = BigIntLollipop305.toMontgomery2(11, 0);
        (uint256 b0, uint256 b1) = BigIntLollipop305.toMontgomery2(13, 0);
        (uint256 b2, uint256 b3) = BigIntLollipop305.toMontgomery2(17, 0);
        (uint256 b4, uint256 b5) = BigIntLollipop305.toMontgomery2(19, 0);
        (uint256 b6, uint256 b7) = BigIntLollipop305.toMontgomery2(23, 0);
        uint256 t0; uint256 t1; uint256 t2; uint256 t3; uint256 t4; uint256 t5; uint256 t6; uint256 t7;
        for (uint256 i; i < N_EXT; ) {
            if ((i & 1) == 0) {
                (t0,t1,t2,t3,t4,t5,t6,t7) = _fp4MulFullStack(a0,a1,a2,a3,a4,a5,a6,a7,b0,b1,b2,b3,b4,b5,b6,b7);
            } else {
                (a0,a1,a2,a3,a4,a5,a6,a7) = _fp4MulFullStack(t0,t1,t2,t3,t4,t5,t6,t7,b0,b1,b2,b3,b4,b5,b6,b7);
            }
            unchecked { ++i; }
        }
        return (N_EXT & 1) == 0 ? (a0,a1,a2,a3,a4,a5,a6,a7) : (t0,t1,t2,t3,t4,t5,t6,t7);
    }

    function _fp4MulFullStack(
        uint256 a0, uint256 a1, uint256 a2, uint256 a3, uint256 a4, uint256 a5, uint256 a6, uint256 a7,
        uint256 b0, uint256 b1, uint256 b2, uint256 b3, uint256 b4, uint256 b5, uint256 b6, uint256 b7
    )
        internal
        pure
        returns (uint256 c0, uint256 c1, uint256 c2, uint256 c3, uint256 c4, uint256 c5, uint256 c6, uint256 c7)
    {
        (uint256 sA0, uint256 sA1) = BigIntLollipop305.add2(a0, a1, a4, a5);
        (uint256 sA2, uint256 sA3) = BigIntLollipop305.add2(a2, a3, a6, a7);
        (uint256 sB0, uint256 sB1) = BigIntLollipop305.add2(b0, b1, b4, b5);
        (uint256 sB2, uint256 sB3) = BigIntLollipop305.add2(b2, b3, b6, b7);
        (uint256 v00, uint256 v01, uint256 v02, uint256 v03) =
            Lollipop305ExtensionStack.fp2Mul(a0, a1, a2, a3, b0, b1, b2, b3);
        (uint256 v10, uint256 v11, uint256 v12, uint256 v13) =
            Lollipop305ExtensionStack.fp2Mul(a4, a5, a6, a7, b4, b5, b6, b7);
        (uint256 v20, uint256 v21, uint256 v22, uint256 v23) =
            Lollipop305ExtensionStack.fp2Mul(sA0, sA1, sA2, sA3, sB0, sB1, sB2, sB3);
        (uint256 xi0, uint256 xi1) = BigIntLollipop305.sub2(v10, v11, v12, v13);
        (uint256 xi2, uint256 xi3) = BigIntLollipop305.add2(v12, v13, v10, v11);
        (c0, c1) = BigIntLollipop305.add2(v00, v01, xi0, xi1);
        (c2, c3) = BigIntLollipop305.add2(v02, v03, xi2, xi3);
        (c4, c5) = BigIntLollipop305.sub2(v20, v21, v00, v01);
        (c6, c7) = BigIntLollipop305.sub2(v22, v23, v02, v03);
        (c4, c5) = BigIntLollipop305.sub2(c4, c5, v10, v11);
        (c6, c7) = BigIntLollipop305.sub2(c6, c7, v12, v13);
    }
}

contract Lollipop305ArithmeticTest is Test {
    Lollipop305ArithmeticBench bench;

    function setUp() public {
        bench = new Lollipop305ArithmeticBench();
    }

    function testFieldModulusMatchesArticleExample1() public pure {
        assertEq(BigIntLollipop305.P0(), 0x24240b65671ab020b2f03c6035ed8fdcdd1ff464dbb7022f6583adbbb2fef163);
        assertEq(BigIntLollipop305.P1(), 0x1f733286263df);
    }

    function testFpMontgomeryRoundTripAndMul() public pure {
        (uint256 a0, uint256 a1) = BigIntLollipop305.toMontgomery2(123456789, 0);
        (uint256 b0, uint256 b1) = BigIntLollipop305.toMontgomery2(987654321, 0);
        (uint256 c0, uint256 c1) = BigIntLollipop305.montMul2(a0, a1, b0, b1);
        (c0, c1) = BigIntLollipop305.fromMontgomery2(c0, c1);
        assertEq(c0, 121932631112635269);
        assertEq(c1, 0);

        (uint256 d0, uint256 d1) = BigIntLollipop305Comba.montMul2(a0, a1, b0, b1);
        (d0, d1) = BigIntLollipop305.fromMontgomery2(d0, d1);
        assertEq(d0, 121932631112635269);
        assertEq(d1, 0);

        (d0, d1) = BigIntLollipop305FIOS.montMul2(a0, a1, b0, b1);
        (d0, d1) = BigIntLollipop305.fromMontgomery2(d0, d1);
        assertEq(d0, 121932631112635269);
        assertEq(d1, 0);

        (d0, d1) = BigIntLollipop305Barrett.mul2(123456789, 0, 987654321, 0);
        assertEq(d0, 121932631112635269);
        assertEq(d1, 0);
    }

    function testFpAddSubRoundTrip() public pure {
        (uint256 r0, uint256 r1) = BigIntLollipop305.add2(100, 0, 200, 0);
        assertEq(r0, 300);
        assertEq(r1, 0);
        (r0, r1) = BigIntLollipop305.sub2(r0, r1, 200, 0);
        assertEq(r0, 100);
        assertEq(r1, 0);
    }

    function testFpMulNearModulus() public pure {
        (uint256 pm2_0, uint256 pm2_1) = BigIntLollipop305.sub2(BigIntLollipop305.P0(), BigIntLollipop305.P1(), 2, 0);
        (uint256 pm3_0, uint256 pm3_1) = BigIntLollipop305.sub2(BigIntLollipop305.P0(), BigIntLollipop305.P1(), 3, 0);
        (uint256 a0, uint256 a1) = BigIntLollipop305.toMontgomery2(pm2_0, pm2_1);
        (uint256 b0, uint256 b1) = BigIntLollipop305.toMontgomery2(pm3_0, pm3_1);
        (uint256 c0, uint256 c1) = BigIntLollipop305.montMul2(a0, a1, b0, b1);
        (c0, c1) = BigIntLollipop305.fromMontgomery2(c0, c1);
        assertEq(c0, 6);
        assertEq(c1, 0);

        (c0, c1) = BigIntLollipop305Comba.montMul2(a0, a1, b0, b1);
        (c0, c1) = BigIntLollipop305.fromMontgomery2(c0, c1);
        assertEq(c0, 6);
        assertEq(c1, 0);

        (c0, c1) = BigIntLollipop305FIOS.montMul2(a0, a1, b0, b1);
        (c0, c1) = BigIntLollipop305.fromMontgomery2(c0, c1);
        assertEq(c0, 6);
        assertEq(c1, 0);

        (c0, c1) = BigIntLollipop305Barrett.mul2(pm2_0, pm2_1, pm3_0, pm3_1);
        assertEq(c0, 6);
        assertEq(c1, 0);
    }

    function testFuzz_FpMulDistributivity(uint128 ax, uint128 bx, uint128 cx) public pure {
        (uint256 a0, uint256 a1) = BigIntLollipop305.toMontgomery2(uint256(ax), 0);
        (uint256 b0, uint256 b1) = BigIntLollipop305.toMontgomery2(uint256(bx), 0);
        (uint256 c0, uint256 c1) = BigIntLollipop305.toMontgomery2(uint256(cx), 0);

        (uint256 ab0, uint256 ab1) = BigIntLollipop305.add2(a0, a1, b0, b1);
        (uint256 lhs0, uint256 lhs1) = BigIntLollipop305.montMul2(ab0, ab1, c0, c1);

        (uint256 ac0, uint256 ac1) = BigIntLollipop305.montMul2(a0, a1, c0, c1);
        (uint256 bc0, uint256 bc1) = BigIntLollipop305.montMul2(b0, b1, c0, c1);
        (uint256 rhs0, uint256 rhs1) = BigIntLollipop305.add2(ac0, ac1, bc0, bc1);

        assertEq(lhs0, rhs0);
        assertEq(lhs1, rhs1);
    }

    function testFp2MulMatchesReferenceSmallValues() public pure {
        Lollipop305Extension.Fp2 memory a = Lollipop305Extension.fp2FromRaw(3, 5);
        Lollipop305Extension.Fp2 memory b = Lollipop305Extension.fp2FromRaw(7, 11);
        Lollipop305Extension.Fp2 memory out;
        Lollipop305Extension.fp2MulTo(out, a, b);
        (uint256 c00, uint256 c01) = BigIntLollipop305.fromMontgomery2(out.c0[0], out.c0[1]);
        (uint256 c10, uint256 c11) = BigIntLollipop305.fromMontgomery2(out.c1[0], out.c1[1]);
        // u^2 = -1: (3+5u)(7+11u) = -34 + 68u mod p.
        (uint256 neg34_0, uint256 neg34_1) = BigIntLollipop305.sub2(0, 0, 34, 0);
        assertEq(c00, neg34_0);
        assertEq(c01, neg34_1);
        assertEq(c10, 68);
        assertEq(c11, 0);
    }

    function testFp4MulMatchesReferenceSmallValues() public pure {
        Lollipop305Extension.Fp4 memory a = Lollipop305Extension.fp4FromRaw(3, 5, 7, 11);
        Lollipop305Extension.Fp4 memory b = Lollipop305Extension.fp4FromRaw(13, 17, 19, 23);
        Lollipop305Extension.Fp4 memory out;
        Lollipop305Extension.fp4MulTo(out, a, b);
        // Tower u^2=-1, v^2=1+u:
        // ((3+5u)+(7+11u)v)((13+17u)+(19+23u)v)
        // = (-536+366u)+(-154+426u)v.
        (uint256 neg536_0, uint256 neg536_1) = BigIntLollipop305.sub2(0, 0, 536, 0);
        (uint256 neg154_0, uint256 neg154_1) = BigIntLollipop305.sub2(0, 0, 154, 0);
        Lollipop305Extension.Fp4 memory expected = Lollipop305Extension.fp4FromRaw(0, 0, 0, 0);
        expected.c0.c0 = Lollipop305Extension.fpFromRaw(neg536_0, neg536_1);
        expected.c0.c1 = Lollipop305Extension.fpFromRaw(366, 0);
        expected.c1.c0 = Lollipop305Extension.fpFromRaw(neg154_0, neg154_1);
        expected.c1.c1 = Lollipop305Extension.fpFromRaw(426, 0);
        assertTrue(Lollipop305Extension.eqFp4(out, expected));

        uint256[8] memory pa;
        uint256[8] memory pb;
        (pa[0], pa[1]) = BigIntLollipop305.toMontgomery2(3, 0);
        (pa[2], pa[3]) = BigIntLollipop305.toMontgomery2(5, 0);
        (pa[4], pa[5]) = BigIntLollipop305.toMontgomery2(7, 0);
        (pa[6], pa[7]) = BigIntLollipop305.toMontgomery2(11, 0);
        (pb[0], pb[1]) = BigIntLollipop305.toMontgomery2(13, 0);
        (pb[2], pb[3]) = BigIntLollipop305.toMontgomery2(17, 0);
        (pb[4], pb[5]) = BigIntLollipop305.toMontgomery2(19, 0);
        (pb[6], pb[7]) = BigIntLollipop305.toMontgomery2(23, 0);
        uint256[8] memory packed = Lollipop305ExtensionStack.fp4Mul(pa, pb);
        assertEq(packed[0], expected.c0.c0[0]);
        assertEq(packed[1], expected.c0.c0[1]);
        assertEq(packed[2], expected.c0.c1[0]);
        assertEq(packed[3], expected.c0.c1[1]);
        assertEq(packed[4], expected.c1.c0[0]);
        assertEq(packed[5], expected.c1.c0[1]);
        assertEq(packed[6], expected.c1.c1[0]);
        assertEq(packed[7], expected.c1.c1[1]);
    }

    function testFuzz_Fp2MulAssociativity(uint64 a0, uint64 a1, uint64 b0, uint64 b1, uint64 c0, uint64 c1)
        public
        pure
    {
        Lollipop305Extension.Fp2 memory a = Lollipop305Extension.fp2FromRaw(a0, a1);
        Lollipop305Extension.Fp2 memory b = Lollipop305Extension.fp2FromRaw(b0, b1);
        Lollipop305Extension.Fp2 memory c = Lollipop305Extension.fp2FromRaw(c0, c1);
        Lollipop305Extension.Fp2 memory ab;
        Lollipop305Extension.Fp2 memory bc;
        Lollipop305Extension.Fp2 memory lhs;
        Lollipop305Extension.Fp2 memory rhs;
        Lollipop305Extension.fp2MulTo(ab, a, b);
        Lollipop305Extension.fp2MulTo(lhs, ab, c);
        Lollipop305Extension.fp2MulTo(bc, b, c);
        Lollipop305Extension.fp2MulTo(rhs, a, bc);
        assertTrue(Lollipop305Extension.eqFp2(lhs, rhs));
    }

    function testFuzz_Fp4SqrMatchesMul(uint64 a00, uint64 a01, uint64 a10, uint64 a11) public pure {
        Lollipop305Extension.Fp4 memory a = Lollipop305Extension.fp4FromRaw(a00, a01, a10, a11);
        Lollipop305Extension.Fp4 memory sqr;
        Lollipop305Extension.Fp4 memory mul;
        Lollipop305Extension.fp4SqrTo(sqr, a);
        Lollipop305Extension.fp4MulTo(mul, a, a);
        assertTrue(Lollipop305Extension.eqFp4(sqr, mul));
    }

    function testGasReport_lollipop305Arithmetic() public view {
        bench.benchFpMul();
        bench.benchFpMulComba();
        bench.benchFpMulFIOS();
        bench.benchFpMulBarrett();
        bench.benchFpSqr();
        bench.benchFp2Mul();
        bench.benchFp2Sqr();
        bench.benchFp4Mul();
        bench.benchFp4Sqr();
        bench.benchFp2MulStack();
        bench.benchFp2SqrStack();
        bench.benchFp4MulStack();
        bench.benchFp4MulFullStack();
        bench.benchFp4SqrStack();
    }
}
