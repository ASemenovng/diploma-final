// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import "forge-std/Test.sol";
import "../src/MNT4Extension.sol";
import "../src/BigIntMNT.sol";

contract MNT4ExtensionFinalHarness {
    function fq2Add(MNT4ExtensionFinal.Fq2 memory a, MNT4ExtensionFinal.Fq2 memory b)
        external
        pure
        returns (MNT4ExtensionFinal.Fq2 memory)
    {
        return MNT4ExtensionFinal.fq2Add(a, b);
    }

    function fq2Sub(MNT4ExtensionFinal.Fq2 memory a, MNT4ExtensionFinal.Fq2 memory b)
        external
        pure
        returns (MNT4ExtensionFinal.Fq2 memory)
    {
        return MNT4ExtensionFinal.fq2Sub(a, b);
    }

    function fq2Mul(MNT4ExtensionFinal.Fq2 memory a, MNT4ExtensionFinal.Fq2 memory b)
        external
        pure
        returns (MNT4ExtensionFinal.Fq2 memory)
    {
        return MNT4ExtensionFinal.fq2Mul(a, b);
    }

    function fq4Mul(MNT4ExtensionFinal.Fq4 memory a, MNT4ExtensionFinal.Fq4 memory b)
        external
        pure
        returns (MNT4ExtensionFinal.Fq4 memory)
    {
        return MNT4ExtensionFinal.fq4Mul(a, b);
    }

    function fq2Sqr(MNT4ExtensionFinal.Fq2 memory a) external pure returns (MNT4ExtensionFinal.Fq2 memory) {
        return MNT4ExtensionFinal.fq2Sqr(a);
    }

    function fq4Sqr(MNT4ExtensionFinal.Fq4 memory a) external pure returns (MNT4ExtensionFinal.Fq4 memory) {
        return MNT4ExtensionFinal.fq4Sqr(a);
    }

    function fq4MulByV(MNT4ExtensionFinal.Fq4 memory a) external pure returns (MNT4ExtensionFinal.Fq4 memory) {
        return MNT4ExtensionFinal.fq4MulByV(a);
    }

    function fq2Inv(MNT4ExtensionFinal.Fq2 memory a) external pure returns (MNT4ExtensionFinal.Fq2 memory) {
        return MNT4ExtensionFinal.fq2Inv(a);
    }

    function fq4Inv(MNT4ExtensionFinal.Fq4 memory a) external pure returns (MNT4ExtensionFinal.Fq4 memory) {
        return MNT4ExtensionFinal.fq4Inv(a);
    }

    function benchFq4Sqr(uint256 n, MNT4ExtensionFinal.Fq4 calldata x)
        external
        pure
        returns (MNT4ExtensionFinal.Fq4 memory r)
    {
        MNT4ExtensionFinal.Fq4 memory a = x;
        MNT4ExtensionFinal.Fq4 memory b;

        unchecked {
            for (uint256 i = 0; i < n; ++i) {
                if ((i & 1) == 0) {
                    MNT4ExtensionFinal.fq4SqrTo(b, a);
                } else {
                    MNT4ExtensionFinal.fq4SqrTo(a, b);
                }
            }
        }

        r = ((n & 1) == 0) ? a : b;
    }

    function benchFq4Mul(uint256 n, MNT4ExtensionFinal.Fq4 calldata x, MNT4ExtensionFinal.Fq4 calldata y)
        external
        pure
        returns (MNT4ExtensionFinal.Fq4 memory r)
    {
        MNT4ExtensionFinal.Fq4 memory a = x;
        MNT4ExtensionFinal.Fq4 memory b;
        MNT4ExtensionFinal.Fq4 memory ym = y;

        unchecked {
            for (uint256 i = 0; i < n; ++i) {
                if ((i & 1) == 0) {
                    MNT4ExtensionFinal.fq4MulTo(b, a, ym);
                } else {
                    MNT4ExtensionFinal.fq4MulTo(a, b, ym);
                }
            }
        }

        r = ((n & 1) == 0) ? a : b;
    }
}

contract MNT4ExtensionFinalTest is Test {
    MNT4ExtensionFinalHarness lib;
    MNT4ExtensionFinalHarnessPacked packed;
    MNT4ExtensionFinalInternalBench bench;

    function setUp() public {
        lib = new MNT4ExtensionFinalHarness();
        packed = new MNT4ExtensionFinalHarnessPacked();
        bench = new MNT4ExtensionFinalInternalBench();
    }

    function mk(uint256 x) internal pure returns (uint256[3] memory r) {
        r[0] = x; r[1] = 0; r[2] = 0;
    }

    function toMontU(uint256 x) internal pure returns (uint256[3] memory) {
        return BigIntMNT.toMontgomery(mk(x));
    }

    function assertEq3(uint256[3] memory a, uint256[3] memory b) internal {
        assertEq(a[0], b[0], "Limb0");
        assertEq(a[1], b[1], "Limb1");
        assertEq(a[2], b[2], "Limb2");
    }

    function assertEqFq2(MNT4ExtensionFinal.Fq2 memory a, MNT4ExtensionFinal.Fq2 memory b) internal {
        assertEq3(a.c0, b.c0);
        assertEq3(a.c1, b.c1);
    }

    function assertEqFq4(MNT4ExtensionFinal.Fq4 memory a, MNT4ExtensionFinal.Fq4 memory b) internal {
        assertEqFq2(a.c0, b.c0);
        assertEqFq2(a.c1, b.c1);
    }

    function testFq2Mul_Specific() public {
        MNT4ExtensionFinal.Fq2 memory a;
        a.c0 = toMontU(1);
        a.c1 = toMontU(2);

        MNT4ExtensionFinal.Fq2 memory b;
        b.c0 = toMontU(3);
        b.c1 = toMontU(4);

        MNT4ExtensionFinal.Fq2 memory r = lib.fq2Mul(a, b);

        assertEq3(r.c0, toMontU(107));
        assertEq3(r.c1, toMontU(10));
    }

    function testFq4Mul_Specific() public {
        MNT4ExtensionFinal.Fq4 memory a;
        a.c0.c0 = toMontU(1);
        a.c0.c1 = toMontU(2);
        a.c1.c0 = toMontU(3);
        a.c1.c1 = toMontU(4);

        MNT4ExtensionFinal.Fq4 memory b;
        b.c0.c0 = toMontU(5);
        b.c0.c1 = toMontU(6);
        b.c1.c0 = toMontU(7);
        b.c1.c1 = toMontU(8);

        MNT4ExtensionFinal.Fq4 memory r = lib.fq4Mul(a, b);

        assertEq3(r.c0.c0, toMontU(837));
        assertEq3(r.c0.c1, toMontU(453));
        assertEq3(r.c1.c0, toMontU(542));
        assertEq3(r.c1.c1, toMontU(60));
    }

    function testFq4Mul_Identity() public {
        MNT4ExtensionFinal.Fq4 memory one;
        one.c0.c0 = toMontU(1);

        MNT4ExtensionFinal.Fq4 memory r = lib.fq4Mul(one, one);

        assertEq3(r.c0.c0, toMontU(1));
        assertEq3(r.c0.c1, toMontU(0));
        assertEq3(r.c1.c0, toMontU(0));
        assertEq3(r.c1.c1, toMontU(0));
    }

    function fq2FromU64(uint64 x0, uint64 x1) internal pure returns (MNT4ExtensionFinal.Fq2 memory a) {
        a.c0 = BigIntMNT.toMontgomery(mk(uint256(x0)));
        a.c1 = BigIntMNT.toMontgomery(mk(uint256(x1)));
    }

    function testFuzz_Fq2Mul_Associativity(uint64 a0, uint64 a1, uint64 b0, uint64 b1, uint64 c0, uint64 c1) public {
        MNT4ExtensionFinal.Fq2 memory a = fq2FromU64(a0, a1);
        MNT4ExtensionFinal.Fq2 memory b = fq2FromU64(b0, b1);
        MNT4ExtensionFinal.Fq2 memory c = fq2FromU64(c0, c1);

        MNT4ExtensionFinal.Fq2 memory ab = lib.fq2Mul(a, b);
        MNT4ExtensionFinal.Fq2 memory r1 = lib.fq2Mul(ab, c);

        MNT4ExtensionFinal.Fq2 memory bc = lib.fq2Mul(b, c);
        MNT4ExtensionFinal.Fq2 memory r2 = lib.fq2Mul(a, bc);

        assertEqFq2(r1, r2);
    }

    function testFuzz_Fq2Mul_Distributivity(uint64 a0, uint64 a1, uint64 b0, uint64 b1, uint64 c0, uint64 c1) public {
        MNT4ExtensionFinal.Fq2 memory a = fq2FromU64(a0, a1);
        MNT4ExtensionFinal.Fq2 memory b = fq2FromU64(b0, b1);
        MNT4ExtensionFinal.Fq2 memory c = fq2FromU64(c0, c1);

        MNT4ExtensionFinal.Fq2 memory bpc = lib.fq2Add(b, c);
        MNT4ExtensionFinal.Fq2 memory r1 = lib.fq2Mul(a, bpc);

        MNT4ExtensionFinal.Fq2 memory ab = lib.fq2Mul(a, b);
        MNT4ExtensionFinal.Fq2 memory ac = lib.fq2Mul(a, c);
        MNT4ExtensionFinal.Fq2 memory r2 = lib.fq2Add(ab, ac);

        assertEqFq2(r1, r2);
    }

    function testFuzz_Fq4Mul_Associativity(
        uint64 a00, uint64 a01, uint64 a10, uint64 a11,
        uint64 b00, uint64 b01, uint64 b10, uint64 b11,
        uint64 c00, uint64 c01, uint64 c10, uint64 c11
    ) public {
        MNT4ExtensionFinal.Fq4 memory a;
        a.c0 = fq2FromU64(a00, a01);
        a.c1 = fq2FromU64(a10, a11);

        MNT4ExtensionFinal.Fq4 memory b;
        b.c0 = fq2FromU64(b00, b01);
        b.c1 = fq2FromU64(b10, b11);

        MNT4ExtensionFinal.Fq4 memory c;
        c.c0 = fq2FromU64(c00, c01);
        c.c1 = fq2FromU64(c10, c11);

        MNT4ExtensionFinal.Fq4 memory ab = lib.fq4Mul(a, b);
        MNT4ExtensionFinal.Fq4 memory r1 = lib.fq4Mul(ab, c);

        MNT4ExtensionFinal.Fq4 memory bc = lib.fq4Mul(b, c);
        MNT4ExtensionFinal.Fq4 memory r2 = lib.fq4Mul(a, bc);

        assertEqFq4(r1, r2);
    }

    function testFq2Sqr_MatchesMul() public {
        MNT4ExtensionFinal.Fq2 memory a;
        a.c0 = toMontU(11);
        a.c1 = toMontU(22);

        MNT4ExtensionFinal.Fq2 memory s1 = lib.fq2Sqr(a);
        MNT4ExtensionFinal.Fq2 memory s2 = lib.fq2Mul(a, a);

        assertEqFq2(s1, s2);
    }

    function testFq4Sqr_MatchesMul() public {
        MNT4ExtensionFinal.Fq4 memory a;
        a.c0.c0 = toMontU(1);
        a.c0.c1 = toMontU(2);
        a.c1.c0 = toMontU(3);
        a.c1.c1 = toMontU(4);

        MNT4ExtensionFinal.Fq4 memory s1 = lib.fq4Sqr(a);
        MNT4ExtensionFinal.Fq4 memory s2 = lib.fq4Mul(a, a);

        assertEqFq4(s1, s2);
    }

    function testFq4MulByV_MatchesGeneralMul() public {
        MNT4ExtensionFinal.Fq4 memory v;
        v.c1.c0 = toMontU(1);

        MNT4ExtensionFinal.Fq4 memory a;
        a.c0.c0 = toMontU(5);
        a.c0.c1 = toMontU(6);
        a.c1.c0 = toMontU(7);
        a.c1.c1 = toMontU(8);

        MNT4ExtensionFinal.Fq4 memory r1 = lib.fq4MulByV(a);
        MNT4ExtensionFinal.Fq4 memory r2 = lib.fq4Mul(a, v);

        assertEqFq4(r1, r2);
    }

    function testFq2Inv_MulOne() public {
        MNT4ExtensionFinal.Fq2 memory a;
        a.c0 = toMontU(11);
        a.c1 = toMontU(22);

        MNT4ExtensionFinal.Fq2 memory ai = lib.fq2Inv(a);
        MNT4ExtensionFinal.Fq2 memory prod = lib.fq2Mul(a, ai);

        MNT4ExtensionFinal.Fq2 memory one;
        one.c0 = toMontU(1);
        assertEqFq2(prod, one);
    }

    function testFq4Inv_MulOne() public {
        MNT4ExtensionFinal.Fq4 memory a;
        a.c0.c0 = toMontU(1);
        a.c0.c1 = toMontU(2);
        a.c1.c0 = toMontU(3);
        a.c1.c1 = toMontU(4);

        MNT4ExtensionFinal.Fq4 memory ai = lib.fq4Inv(a);
        MNT4ExtensionFinal.Fq4 memory prod = lib.fq4Mul(a, ai);

        MNT4ExtensionFinal.Fq4 memory one;
        one.c0.c0 = toMontU(1);
        assertEqFq4(prod, one);
    }

    function testBenchFq4Sqr64() public {
        MNT4ExtensionFinal.Fq4 memory a;
        a.c0.c0 = toMontU(1);
        a.c0.c1 = toMontU(2);
        a.c1.c0 = toMontU(3);
        a.c1.c1 = toMontU(4);

        lib.benchFq4Sqr(64, a);
    }

    function testBenchFq4Mul32() public {
        MNT4ExtensionFinal.Fq4 memory a;
        a.c0.c0 = toMontU(5);
        a.c0.c1 = toMontU(6);
        a.c1.c0 = toMontU(7);
        a.c1.c1 = toMontU(8);

        MNT4ExtensionFinal.Fq4 memory b;
        b.c0.c0 = toMontU(9);
        b.c0.c1 = toMontU(10);
        b.c1.c0 = toMontU(11);
        b.c1.c1 = toMontU(12);

        lib.benchFq4Mul(32, a, b);
    }

    function _packFq2(MNT4ExtensionFinal.Fq2 memory a) internal pure returns (uint256[6] memory p) {
        p[0]=a.c0[0]; p[1]=a.c0[1]; p[2]=a.c0[2];
        p[3]=a.c1[0]; p[4]=a.c1[1]; p[5]=a.c1[2];
    }

    function _packFq4(MNT4ExtensionFinal.Fq4 memory a) internal pure returns (uint256[12] memory p) {
        p[0]=a.c0.c0[0]; p[1]=a.c0.c0[1]; p[2]=a.c0.c0[2];
        p[3]=a.c0.c1[0]; p[4]=a.c0.c1[1]; p[5]=a.c0.c1[2];
        p[6]=a.c1.c0[0]; p[7]=a.c1.c0[1]; p[8]=a.c1.c0[2];
        p[9]=a.c1.c1[0]; p[10]=a.c1.c1[1]; p[11]=a.c1.c1[2];
    }

    function testGasBench_fq2Mul_external_memory_struct() public {
        uint256 N = 64;

        MNT4ExtensionFinal.Fq2 memory a = fq2FromU64(11, 22);
        MNT4ExtensionFinal.Fq2 memory b = fq2FromU64(33, 44);

        for (uint256 i = 0; i < N; ++i) {
            a = lib.fq2Mul(a, b);
        }

        assertTrue((a.c0[0] | a.c1[0]) != 0);
    }

    function testGasBench_fq4Mul_external_memory_struct() public {
        uint256 N = 16;

        MNT4ExtensionFinal.Fq4 memory a;
        a.c0 = fq2FromU64(1, 2);
        a.c1 = fq2FromU64(3, 4);

        MNT4ExtensionFinal.Fq4 memory b;
        b.c0 = fq2FromU64(5, 6);
        b.c1 = fq2FromU64(7, 8);

        for (uint256 i = 0; i < N; ++i) {
            a = lib.fq4Mul(a, b);
        }

        assertTrue((a.c0.c0[0] | a.c1.c1[0]) != 0);
    }

    function testGasBench_fq2Mul_external_packed() public {
        uint256 N = 512;

        MNT4ExtensionFinal.Fq2 memory a0 = fq2FromU64(11, 22);
        MNT4ExtensionFinal.Fq2 memory b0 = fq2FromU64(33, 44);

        uint256[6] memory a = _packFq2(a0);
        uint256[6] memory b = _packFq2(b0);

        for (uint256 i = 0; i < N; ++i) {
            uint256[6] memory r = packed.fq2Mul6(a, b);
            a = r;
        }

        assertTrue((a[0] | a[3]) != 0);
    }

    function testGasBench_fq4MulByV_external_packed() public {
        uint256 N = 4096;

        MNT4ExtensionFinal.Fq4 memory a0;
        a0.c0 = fq2FromU64(1, 2);
        a0.c1 = fq2FromU64(3, 4);

        uint256[12] memory a = _packFq4(a0);

        for (uint256 i = 0; i < N; ++i) {
            uint256[12] memory r = packed.fq4MulByV12(a);
            a = r;
        }

        assertTrue((a[0] | a[6]) != 0);
    }

    function testGasBench_fq2Inv_external_memory_struct() public {
        uint256 N = 8;
        MNT4ExtensionFinal.Fq2 memory a = fq2FromU64(11, 22);
        for (uint256 i = 0; i < N; ++i) {
            a = lib.fq2Inv(a);
        }
        assertTrue((a.c0[0] | a.c1[0]) != 0);
    }

    function testGasBench_fq4Inv_external_memory_struct() public {
        uint256 N = 4;
        MNT4ExtensionFinal.Fq4 memory a;
        a.c0 = fq2FromU64(1, 2);
        a.c1 = fq2FromU64(3, 4);
        for (uint256 i = 0; i < N; ++i) {
            a = lib.fq4Inv(a);
        }
        assertTrue((a.c0.c0[0] | a.c1.c1[0]) != 0);
    }

    function testGasReport_internalStyleBench_allOps() public {
        MNT4ExtensionFinal.Fq2 memory x2 = bench.benchFq2Add();
        assertTrue((x2.c0[0] | x2.c1[0]) != 0);

        x2 = bench.benchFq2Sub();
        assertTrue((x2.c0[0] | x2.c1[0]) != 0);

        x2 = bench.benchFq2Mul();
        assertTrue((x2.c0[0] | x2.c1[0]) != 0);

        x2 = bench.benchFq2Sqr();
        assertTrue((x2.c0[0] | x2.c1[0]) != 0);

        MNT4ExtensionFinal.Fq4 memory x4 = bench.benchFq4Mul();
        assertTrue((x4.c0.c0[0] | x4.c1.c1[0]) != 0);

        x4 = bench.benchFq4Sqr();
        assertTrue((x4.c0.c0[0] | x4.c1.c1[0]) != 0);

        x4 = bench.benchFq4MulByV();
        assertTrue((x4.c0.c0[0] | x4.c1.c1[0]) != 0);

        x2 = bench.benchFq2Inv();
        assertTrue((x2.c0[0] | x2.c1[0]) != 0);

        x4 = bench.benchFq4Inv();
        assertTrue((x4.c0.c0[0] | x4.c1.c1[0]) != 0);
    }
}

contract MNT4ExtensionFinalHarnessPacked {
    function _fpMulBy13(uint256 x0, uint256 x1, uint256 x2) internal pure returns (uint256 y0, uint256 y1, uint256 y2) {
        (uint256 x2_0, uint256 x2_1, uint256 x2_2) = BigIntMNT.add3(x0, x1, x2, x0, x1, x2);
        (uint256 x4_0, uint256 x4_1, uint256 x4_2) = BigIntMNT.add3(x2_0, x2_1, x2_2, x2_0, x2_1, x2_2);
        (uint256 x8_0, uint256 x8_1, uint256 x8_2) = BigIntMNT.add3(x4_0, x4_1, x4_2, x4_0, x4_1, x4_2);
        (uint256 x12_0, uint256 x12_1, uint256 x12_2) = BigIntMNT.add3(x8_0, x8_1, x8_2, x4_0, x4_1, x4_2);
        (y0, y1, y2) = BigIntMNT.add3(x12_0, x12_1, x12_2, x0, x1, x2);
    }

    function fq2Add6(uint256[6] calldata a, uint256[6] calldata b) external pure returns (uint256[6] memory r) {
        (r[0], r[1], r[2]) = BigIntMNT.add3(a[0], a[1], a[2], b[0], b[1], b[2]);
        (r[3], r[4], r[5]) = BigIntMNT.add3(a[3], a[4], a[5], b[3], b[4], b[5]);
    }

    function fq2Sub6(uint256[6] calldata a, uint256[6] calldata b) external pure returns (uint256[6] memory r) {
        (r[0], r[1], r[2]) = BigIntMNT.sub3(a[0], a[1], a[2], b[0], b[1], b[2]);
        (r[3], r[4], r[5]) = BigIntMNT.sub3(a[3], a[4], a[5], b[3], b[4], b[5]);
    }

    function fq2Mul6(uint256[6] calldata a, uint256[6] calldata b) external pure returns (uint256[6] memory r) {
        (r[0], r[1], r[2]) = BigIntMNT.montMul3(a[0], a[1], a[2], b[0], b[1], b[2]);
        (r[3], r[4], r[5]) = BigIntMNT.montMul3(a[3], a[4], a[5], b[3], b[4], b[5]);

        (uint256 s0, uint256 s1, uint256 s2) = BigIntMNT.add3(r[0], r[1], r[2], r[3], r[4], r[5]);

        (uint256 bv0, uint256 bv1, uint256 bv2) = _fpMulBy13(r[3], r[4], r[5]);
        (r[0], r[1], r[2]) = BigIntMNT.add3(r[0], r[1], r[2], bv0, bv1, bv2);

        (uint256 as0, uint256 as1, uint256 as2) = BigIntMNT.add3(a[0], a[1], a[2], a[3], a[4], a[5]);
        (uint256 bs0, uint256 bs1, uint256 bs2) = BigIntMNT.add3(b[0], b[1], b[2], b[3], b[4], b[5]);
        (uint256 v20, uint256 v21, uint256 v22) = BigIntMNT.montMul3(as0, as1, as2, bs0, bs1, bs2);

        (r[3], r[4], r[5]) = BigIntMNT.sub3(v20, v21, v22, s0, s1, s2);
    }

    function fq2Sqr6(uint256[6] calldata a) external pure returns (uint256[6] memory r) {
        (uint256 v00, uint256 v01, uint256 v02) = BigIntMNT.montSqr3(a[0], a[1], a[2]);
        (uint256 v10, uint256 v11, uint256 v12) = BigIntMNT.montSqr3(a[3], a[4], a[5]);

        (uint256 bv0, uint256 bv1, uint256 bv2) = _fpMulBy13(v10, v11, v12);
        (r[0], r[1], r[2]) = BigIntMNT.add3(v00, v01, v02, bv0, bv1, bv2);

        (uint256 t0, uint256 t1, uint256 t2) = BigIntMNT.montMul3(a[0], a[1], a[2], a[3], a[4], a[5]);
        (r[3], r[4], r[5]) = BigIntMNT.add3(t0, t1, t2, t0, t1, t2);
    }

    function fq4MulByV12(uint256[12] calldata a) external pure returns (uint256[12] memory r) {
        (r[0], r[1], r[2]) = _fpMulBy13(a[9], a[10], a[11]);
        r[3] = a[6];
        r[4] = a[7];
        r[5] = a[8];

        r[6] = a[0];
        r[7] = a[1];
        r[8] = a[2];
        r[9] = a[3];
        r[10] = a[4];
        r[11] = a[5];
    }
}

contract MNT4ExtensionFinalInternalBench {
    uint256 internal constant N_ADD = 16384;
    uint256 internal constant N_SUB = 16384;
    uint256 internal constant N_MUL = 512;
    uint256 internal constant N_SQR = 512;
    uint256 internal constant N_INV = 16;

    function _initFq2(uint256 tag) internal pure returns (MNT4ExtensionFinal.Fq2 memory a) {
        a.c0[0] = uint256(keccak256(abi.encodePacked(tag, uint256(0))));
        a.c0[1] = uint256(keccak256(abi.encodePacked(tag, uint256(1))));
        a.c0[2] = uint256(keccak256(abi.encodePacked(tag, uint256(2)))) & ((uint256(1) << 112) - 1);

        a.c1[0] = uint256(keccak256(abi.encodePacked(tag, uint256(3))));
        a.c1[1] = uint256(keccak256(abi.encodePacked(tag, uint256(4))));
        a.c1[2] = uint256(keccak256(abi.encodePacked(tag, uint256(5)))) & ((uint256(1) << 112) - 1);
    }

    function _initFq4(uint256 tag) internal pure returns (MNT4ExtensionFinal.Fq4 memory a) {
        a.c0 = _initFq2(tag);
        a.c1 = _initFq2(tag + 1);
    }

    function benchFq2Add() external pure returns (MNT4ExtensionFinal.Fq2 memory r) {
        MNT4ExtensionFinal.Fq2 memory a = _initFq2(1);
        MNT4ExtensionFinal.Fq2 memory b = _initFq2(2);
        MNT4ExtensionFinal.Fq2 memory t;

        unchecked {
            for (uint256 i = 0; i < N_ADD; ++i) {
                if ((i & 1) == 0) MNT4ExtensionFinal.fq2AddTo(t, a, b);
                else MNT4ExtensionFinal.fq2AddTo(a, t, b);
            }
        }
        r = ((N_ADD & 1) == 0) ? a : t;
    }

    function benchFq2Sub() external pure returns (MNT4ExtensionFinal.Fq2 memory r) {
        MNT4ExtensionFinal.Fq2 memory a = _initFq2(3);
        MNT4ExtensionFinal.Fq2 memory b = _initFq2(4);
        MNT4ExtensionFinal.Fq2 memory t;

        unchecked {
            for (uint256 i = 0; i < N_SUB; ++i) {
                if ((i & 1) == 0) MNT4ExtensionFinal.fq2SubTo(t, a, b);
                else MNT4ExtensionFinal.fq2SubTo(a, t, b);
            }
        }
        r = ((N_SUB & 1) == 0) ? a : t;
    }

    function benchFq2Mul() external pure returns (MNT4ExtensionFinal.Fq2 memory r) {
        MNT4ExtensionFinal.Fq2 memory a = _initFq2(5);
        MNT4ExtensionFinal.Fq2 memory b = _initFq2(6);
        MNT4ExtensionFinal.Fq2 memory t;

        unchecked {
            for (uint256 i = 0; i < N_MUL; ++i) {
                if ((i & 1) == 0) MNT4ExtensionFinal.fq2MulTo(t, a, b);
                else MNT4ExtensionFinal.fq2MulTo(a, t, b);
            }
        }
        r = ((N_MUL & 1) == 0) ? a : t;
    }

    function benchFq2Sqr() external pure returns (MNT4ExtensionFinal.Fq2 memory r) {
        MNT4ExtensionFinal.Fq2 memory a = _initFq2(7);
        MNT4ExtensionFinal.Fq2 memory t;

        unchecked {
            for (uint256 i = 0; i < N_SQR; ++i) {
                if ((i & 1) == 0) MNT4ExtensionFinal.fq2SqrTo(t, a);
                else MNT4ExtensionFinal.fq2SqrTo(a, t);
            }
        }
        r = ((N_SQR & 1) == 0) ? a : t;
    }

    function benchFq4Mul() external pure returns (MNT4ExtensionFinal.Fq4 memory r) {
        MNT4ExtensionFinal.Fq4 memory a = _initFq4(8);
        MNT4ExtensionFinal.Fq4 memory b = _initFq4(10);
        MNT4ExtensionFinal.Fq4 memory t;

        unchecked {
            for (uint256 i = 0; i < N_MUL; ++i) {
                if ((i & 1) == 0) MNT4ExtensionFinal.fq4MulTo(t, a, b);
                else MNT4ExtensionFinal.fq4MulTo(a, t, b);
            }
        }
        r = ((N_MUL & 1) == 0) ? a : t;
    }

    function benchFq4Sqr() external pure returns (MNT4ExtensionFinal.Fq4 memory r) {
        MNT4ExtensionFinal.Fq4 memory a = _initFq4(12);
        MNT4ExtensionFinal.Fq4 memory t;

        unchecked {
            for (uint256 i = 0; i < N_SQR; ++i) {
                if ((i & 1) == 0) MNT4ExtensionFinal.fq4SqrTo(t, a);
                else MNT4ExtensionFinal.fq4SqrTo(a, t);
            }
        }
        r = ((N_SQR & 1) == 0) ? a : t;
    }

    function benchFq4MulByV() external pure returns (MNT4ExtensionFinal.Fq4 memory r) {
        MNT4ExtensionFinal.Fq4 memory a = _initFq4(14);
        MNT4ExtensionFinal.Fq4 memory t;

        unchecked {
            for (uint256 i = 0; i < N_ADD; ++i) {
                if ((i & 1) == 0) MNT4ExtensionFinal.fq4MulByVTo(t, a);
                else MNT4ExtensionFinal.fq4MulByVTo(a, t);
            }
        }
        r = ((N_ADD & 1) == 0) ? a : t;
    }

    function benchFq2Inv() external pure returns (MNT4ExtensionFinal.Fq2 memory r) {
        MNT4ExtensionFinal.Fq2 memory a = _initFq2(21);
        MNT4ExtensionFinal.Fq2 memory t;
        unchecked {
            for (uint256 i = 0; i < N_INV; ++i) {
                if ((i & 1) == 0) MNT4ExtensionFinal.fq2InvTo(t, a);
                else MNT4ExtensionFinal.fq2InvTo(a, t);
            }
        }
        r = ((N_INV & 1) == 0) ? a : t;
    }

    function benchFq4Inv() external pure returns (MNT4ExtensionFinal.Fq4 memory r) {
        MNT4ExtensionFinal.Fq4 memory a = _initFq4(22);
        MNT4ExtensionFinal.Fq4 memory t;
        unchecked {
            for (uint256 i = 0; i < N_INV; ++i) {
                if ((i & 1) == 0) MNT4ExtensionFinal.fq4InvTo(t, a);
                else MNT4ExtensionFinal.fq4InvTo(a, t);
            }
        }
        r = ((N_INV & 1) == 0) ? a : t;
    }
}