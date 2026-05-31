// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import "forge-std/Test.sol";
import "../src/BigIntMNT.sol";
import "../research_variants/BigIntMNTComba.sol";
import "../research_variants/BigIntMNTBranchless.sol";
import "../research_variants/BigIntMNTSquareComba.sol";
import "../src/MNT4Extension.sol";
import "../research_variants/MNT4ExtensionAlgorithmVariants.sol";

contract BigIntMNTCombaHarness {
    function mul3(uint256 a0, uint256 a1, uint256 a2, uint256 b0, uint256 b1, uint256 b2)
        external pure returns (uint256 r0, uint256 r1, uint256 r2)
    {
        return BigIntMNTComba.montMul3(a0, a1, a2, b0, b1, b2);
    }

    function sqr3(uint256 a0, uint256 a1, uint256 a2)
        external pure returns (uint256 r0, uint256 r1, uint256 r2)
    {
        return BigIntMNTComba.montSqr3(a0, a1, a2);
    }

    function squareCombaSqr3(uint256 a0, uint256 a1, uint256 a2)
        external pure returns (uint256 r0, uint256 r1, uint256 r2)
    {
        return BigIntMNTSquareComba.montSqr3(a0, a1, a2);
    }

    function branchlessAdd3(uint256 a0, uint256 a1, uint256 a2, uint256 b0, uint256 b1, uint256 b2)
        external pure returns (uint256 r0, uint256 r1, uint256 r2)
    {
        return BigIntMNTBranchless.add3(a0, a1, a2, b0, b1, b2);
    }
}

contract MNT4ExtensionVariantHarness {
    function mulBy13Generic(uint256[3] memory x) external pure returns (uint256[3] memory) {
        return MNT4ExtensionAlgorithmVariants.mulBy13Generic(x);
    }

    function fq2MulByUGeneric(MNT4ExtensionFinal.Fq2 memory x)
        external pure returns (MNT4ExtensionFinal.Fq2 memory)
    {
        return MNT4ExtensionAlgorithmVariants.fq2MulByUGeneric(x);
    }

    function fq4MulByVGeneric(MNT4ExtensionFinal.Fq4 memory x)
        external pure returns (MNT4ExtensionFinal.Fq4 memory)
    {
        return MNT4ExtensionAlgorithmVariants.fq4MulByVGeneric(x);
    }

    function fq2SqrLazyDouble(MNT4ExtensionFinal.Fq2 memory x)
        external pure returns (MNT4ExtensionFinal.Fq2 memory)
    {
        return MNT4ExtensionAlgorithmVariants.fq2SqrLazyDouble(x);
    }

    function fq2MulLazyC0(MNT4ExtensionFinal.Fq2 memory x, MNT4ExtensionFinal.Fq2 memory y)
        external pure returns (MNT4ExtensionFinal.Fq2 memory)
    {
        return MNT4ExtensionAlgorithmVariants.fq2MulLazyC0(x, y);
    }
}

contract MNT4ArithmeticAlgorithmBench {
    uint256 internal constant N_FP = 256;
    uint256 internal constant N_EXT = 128;

    uint256 private constant P_0 = 0x685acce9767254a4638810719ac425f0e39d54522cdd119f5e9063de245e8001;
    uint256 private constant P_1 = 0x7fdb925e8a0ed8d99d124d9a15af79db117e776f218059db80f0da5cb537e38;
    uint256 private constant P_2 = 0x1c4c62d92c41110229022eee2cdadb7f997505b8fafed5eb7e8f96c97d873;

    function _fp(uint256 tag) internal pure returns (uint256[3] memory r) {
        r[0] = uint256(keccak256(abi.encodePacked(tag, uint256(0))));
        r[1] = uint256(keccak256(abi.encodePacked(tag, uint256(1))));
        r[2] = uint256(keccak256(abi.encodePacked(tag, uint256(2)))) & ((uint256(1) << 112) - 1);
    }

    function _fq2(uint256 tag) internal pure returns (MNT4ExtensionFinal.Fq2 memory r) {
        r.c0 = _fp(tag);
        r.c1 = _fp(tag + 1);
    }

    function _fq4(uint256 tag) internal pure returns (MNT4ExtensionFinal.Fq4 memory r) {
        r.c0 = _fq2(tag);
        r.c1 = _fq2(tag + 2);
    }

    function benchCombaMul3() external pure returns (uint256 r0, uint256 r1, uint256 r2) {
        (uint256 a0, uint256 a1, uint256 a2) = BigIntMNT.toMontgomery3(
            P_0 - 0x123456789abcdef0123456789abcdef0,
            P_1 - 0x11111111111111111111111111111111,
            P_2 - 0x12345
        );
        (uint256 b0, uint256 b1, uint256 b2) = BigIntMNT.toMontgomery3(
            P_0 - 0x0fedcba9876543210fedcba987654321,
            P_1 - 0x22222222222222222222222222222222,
            P_2 - 0x23456
        );
        for (uint256 i; i < N_FP; ) {
            (a0, a1, a2) = BigIntMNTComba.montMul3(a0, a1, a2, b0, b1, b2);
            unchecked { ++i; }
        }
        return (a0, a1, a2);
    }

    function benchCombaSqr3() external pure returns (uint256 r0, uint256 r1, uint256 r2) {
        (uint256 a0, uint256 a1, uint256 a2) = BigIntMNT.toMontgomery3(
            P_0 - 0x123456789abcdef0123456789abcdef0,
            P_1 - 0x11111111111111111111111111111111,
            P_2 - 0x12345
        );
        for (uint256 i; i < N_FP; ) {
            (a0, a1, a2) = BigIntMNTComba.montSqr3(a0, a1, a2);
            unchecked { ++i; }
        }
        return (a0, a1, a2);
    }

    function benchSquareCombaSqr3() external pure returns (uint256 r0, uint256 r1, uint256 r2) {
        (uint256 a0, uint256 a1, uint256 a2) = BigIntMNT.toMontgomery3(
            P_0 - 0x123456789abcdef0123456789abcdef0,
            P_1 - 0x11111111111111111111111111111111,
            P_2 - 0x12345
        );
        for (uint256 i; i < N_FP; ) {
            (a0, a1, a2) = BigIntMNTSquareComba.montSqr3(a0, a1, a2);
            unchecked { ++i; }
        }
        return (a0, a1, a2);
    }

    function benchBranchlessAdd3() external pure returns (uint256 r0, uint256 r1, uint256 r2) {
        uint256 a0 = 1; uint256 a1 = 2; uint256 a2 = 3;
        uint256 b0 = 4; uint256 b1 = 5; uint256 b2 = 6;
        for (uint256 i; i < 4096; ) {
            (a0, a1, a2) = BigIntMNTBranchless.add3(a0, a1, a2, b0, b1, b2);
            unchecked { ++i; }
        }
        return (a0, a1, a2);
    }

    function benchMulBy13Specialized() external pure returns (uint256 r0, uint256 r1, uint256 r2) {
        (uint256 a0, uint256 a1, uint256 a2) = BigIntMNT.toMontgomery3(123456789, 987654321, 12345);
        for (uint256 i; i < 4096; ) {
            (a0, a1, a2) = BigIntMNT.mulBy13(a0, a1, a2);
            unchecked { ++i; }
        }
        return (a0, a1, a2);
    }

    function benchMulBy13Generic() external pure returns (uint256 r0, uint256 r1, uint256 r2) {
        (uint256 a0, uint256 a1, uint256 a2) = BigIntMNT.toMontgomery3(123456789, 987654321, 12345);
        (uint256 k0, uint256 k1, uint256 k2) = BigIntMNT.toMontgomery3(13, 0, 0);
        for (uint256 i; i < 4096; ) {
            (a0, a1, a2) = BigIntMNT.montMul3(a0, a1, a2, k0, k1, k2);
            unchecked { ++i; }
        }
        return (a0, a1, a2);
    }

    function benchFq2MulByUSpecialized() external pure returns (MNT4ExtensionFinal.Fq2 memory r) {
        MNT4ExtensionFinal.Fq2 memory a = _fq2(1);
        MNT4ExtensionFinal.Fq2 memory t;
        for (uint256 i; i < N_EXT; ) {
            if ((i & 1) == 0) MNT4ExtensionFinal.fq2MulByUTo(t, a);
            else MNT4ExtensionFinal.fq2MulByUTo(a, t);
            unchecked { ++i; }
        }
        return (N_EXT & 1) == 0 ? a : t;
    }

    function benchFq2MulByUGeneric() external pure returns (MNT4ExtensionFinal.Fq2 memory r) {
        MNT4ExtensionFinal.Fq2 memory a = _fq2(1);
        MNT4ExtensionFinal.Fq2 memory u;
        u.c1 = BigIntMNT.toMontgomery([uint256(1), uint256(0), uint256(0)]);
        for (uint256 i; i < N_EXT; ) {
            a = MNT4ExtensionFinal.fq2Mul(a, u);
            unchecked { ++i; }
        }
        return a;
    }

    function benchFq4MulByVSpecialized() external pure returns (MNT4ExtensionFinal.Fq4 memory r) {
        MNT4ExtensionFinal.Fq4 memory a = _fq4(10);
        MNT4ExtensionFinal.Fq4 memory t;
        for (uint256 i; i < N_EXT; ) {
            if ((i & 1) == 0) MNT4ExtensionFinal.fq4MulByVTo(t, a);
            else MNT4ExtensionFinal.fq4MulByVTo(a, t);
            unchecked { ++i; }
        }
        return (N_EXT & 1) == 0 ? a : t;
    }

    function benchFq4MulByVGeneric() external pure returns (MNT4ExtensionFinal.Fq4 memory r) {
        MNT4ExtensionFinal.Fq4 memory a = _fq4(10);
        MNT4ExtensionFinal.Fq4 memory v;
        v.c1.c0 = BigIntMNT.toMontgomery([uint256(1), uint256(0), uint256(0)]);
        for (uint256 i; i < N_EXT; ) {
            a = MNT4ExtensionFinal.fq4Mul(a, v);
            unchecked { ++i; }
        }
        return a;
    }

    function benchFq2SqrProduction() external pure returns (MNT4ExtensionFinal.Fq2 memory r) {
        MNT4ExtensionFinal.Fq2 memory a = _fq2(21);
        MNT4ExtensionFinal.Fq2 memory t;
        for (uint256 i; i < N_EXT; ) {
            if ((i & 1) == 0) MNT4ExtensionFinal.fq2SqrTo(t, a);
            else MNT4ExtensionFinal.fq2SqrTo(a, t);
            unchecked { ++i; }
        }
        return (N_EXT & 1) == 0 ? a : t;
    }

    function benchFq2SqrLazyDouble() external pure returns (MNT4ExtensionFinal.Fq2 memory r) {
        MNT4ExtensionFinal.Fq2 memory a = _fq2(21);
        for (uint256 i; i < N_EXT; ) {
            a = MNT4ExtensionAlgorithmVariants.fq2SqrLazyDouble(a);
            unchecked { ++i; }
        }
        return a;
    }

    function benchFq2MulProduction() external pure returns (MNT4ExtensionFinal.Fq2 memory r) {
        MNT4ExtensionFinal.Fq2 memory a = _fq2(31);
        MNT4ExtensionFinal.Fq2 memory b = _fq2(33);
        MNT4ExtensionFinal.Fq2 memory t;
        for (uint256 i; i < N_EXT; ) {
            if ((i & 1) == 0) MNT4ExtensionFinal.fq2MulTo(t, a, b);
            else MNT4ExtensionFinal.fq2MulTo(a, t, b);
            unchecked { ++i; }
        }
        return (N_EXT & 1) == 0 ? a : t;
    }

    function benchFq2MulLazyC0() external pure returns (MNT4ExtensionFinal.Fq2 memory r) {
        MNT4ExtensionFinal.Fq2 memory a = _fq2(31);
        MNT4ExtensionFinal.Fq2 memory b = _fq2(33);
        for (uint256 i; i < N_EXT; ) {
            a = MNT4ExtensionAlgorithmVariants.fq2MulLazyC0(a, b);
            unchecked { ++i; }
        }
        return a;
    }
}

contract MNT4ArithmeticAlgorithmStudyTest is Test {
    uint256 private constant P_0 = 0x685acce9767254a4638810719ac425f0e39d54522cdd119f5e9063de245e8001;
    uint256 private constant P_1 = 0x7fdb925e8a0ed8d99d124d9a15af79db117e776f218059db80f0da5cb537e38;
    uint256 private constant P_2 = 0x1c4c62d92c41110229022eee2cdadb7f997505b8fafed5eb7e8f96c97d873;

    BigIntMNTCombaHarness h;
    MNT4ExtensionVariantHarness eh;
    MNT4ArithmeticAlgorithmBench bench;

    function setUp() public {
        h = new BigIntMNTCombaHarness();
        eh = new MNT4ExtensionVariantHarness();
        bench = new MNT4ArithmeticAlgorithmBench();
    }

    function assertEq3(uint256[3] memory a, uint256[3] memory b) internal pure {
        assert(a[0] == b[0] && a[1] == b[1] && a[2] == b[2]);
    }

    function assertEqFq2(MNT4ExtensionFinal.Fq2 memory a, MNT4ExtensionFinal.Fq2 memory b) internal pure {
        assertEq3(a.c0, b.c0);
        assertEq3(a.c1, b.c1);
    }

    function assertEqFq4(MNT4ExtensionFinal.Fq4 memory a, MNT4ExtensionFinal.Fq4 memory b) internal pure {
        assertEqFq2(a.c0, b.c0);
        assertEqFq2(a.c1, b.c1);
    }

    function testCombaMatchesCiosForSeveralVectors() public view {
        for (uint256 i = 1; i <= 8; ++i) {
            (uint256 a0, uint256 a1, uint256 a2) = BigIntMNT.toMontgomery3(1000 + i, 2000 + i, 3000 + i);
            (uint256 b0, uint256 b1, uint256 b2) = BigIntMNT.toMontgomery3(4000 + i, 5000 + i, 6000 + i);
            (uint256 e0, uint256 e1, uint256 e2) = BigIntMNT.montMul3(a0, a1, a2, b0, b1, b2);
            (uint256 r0, uint256 r1, uint256 r2) = h.mul3(a0, a1, a2, b0, b1, b2);
            assertEq3([r0, r1, r2], [e0, e1, e2]);
        }
    }

    function testCombaMatchesCiosForFullWidthVectors() public view {
        uint256 p0 = 0x685acce9767254a4638810719ac425f0e39d54522cdd119f5e9063de245e8001;
        uint256 p1 = 0x7fdb925e8a0ed8d99d124d9a15af79db117e776f218059db80f0da5cb537e38;
        uint256 p2 = 0x1c4c62d92c41110229022eee2cdadb7f997505b8fafed5eb7e8f96c97d873;
        (uint256 a0, uint256 a1, uint256 a2) = BigIntMNT.toMontgomery3(
            p0 - 0x123456789abcdef0123456789abcdef0,
            p1 - 0x11111111111111111111111111111111,
            p2 - 0x12345
        );
        (uint256 b0, uint256 b1, uint256 b2) = BigIntMNT.toMontgomery3(
            p0 - 0x0fedcba9876543210fedcba987654321,
            p1 - 0x22222222222222222222222222222222,
            p2 - 0x23456
        );
        (uint256 e0, uint256 e1, uint256 e2) = BigIntMNT.montMul3(a0, a1, a2, b0, b1, b2);
        (uint256 r0, uint256 r1, uint256 r2) = h.mul3(a0, a1, a2, b0, b1, b2);
        assertEq3([r0, r1, r2], [e0, e1, e2]);
    }

    function testCombaSqrMatchesCios() public view {
        (uint256 a0, uint256 a1, uint256 a2) = BigIntMNT.toMontgomery3(777, 888, 999);
        (uint256 e0, uint256 e1, uint256 e2) = BigIntMNT.montSqr3(a0, a1, a2);
        (uint256 r0, uint256 r1, uint256 r2) = h.sqr3(a0, a1, a2);
        assertEq3([r0, r1, r2], [e0, e1, e2]);
    }

    function testSquareCombaSqrMatchesCiosForSeveralVectors() public view {
        for (uint256 i = 1; i <= 8; ++i) {
            (uint256 a0, uint256 a1, uint256 a2) = BigIntMNT.toMontgomery3(
                P_0 - i * 0x12345,
                P_1 - i * 0x23456,
                P_2 - i
            );
            (uint256 e0, uint256 e1, uint256 e2) = BigIntMNT.montSqr3(a0, a1, a2);
            (uint256 r0, uint256 r1, uint256 r2) = h.squareCombaSqr3(a0, a1, a2);
            assertEq3([r0, r1, r2], [e0, e1, e2]);
        }
    }

    function testBranchlessAddMatchesProduction() public view {
        (uint256 e0, uint256 e1, uint256 e2) = BigIntMNT.add3(1, 2, 3, 4, 5, 6);
        (uint256 r0, uint256 r1, uint256 r2) = h.branchlessAdd3(1, 2, 3, 4, 5, 6);
        assertEq3([r0, r1, r2], [e0, e1, e2]);
    }

    function testSpecializedNonResidueMatchesGeneric() public view {
        uint256[3] memory x = BigIntMNT.toMontgomery([uint256(123), uint256(456), uint256(789)]);
        (uint256 s0, uint256 s1, uint256 s2) = BigIntMNT.mulBy13(x[0], x[1], x[2]);
        uint256[3] memory generic = eh.mulBy13Generic(x);
        assertEq3([s0, s1, s2], generic);

        MNT4ExtensionFinal.Fq2 memory a2;
        a2.c0 = BigIntMNT.toMontgomery([uint256(1), uint256(2), uint256(3)]);
        a2.c1 = BigIntMNT.toMontgomery([uint256(4), uint256(5), uint256(6)]);
        MNT4ExtensionFinal.Fq2 memory sp2 = MNT4ExtensionFinal.fq2MulByU(a2);
        MNT4ExtensionFinal.Fq2 memory ge2 = eh.fq2MulByUGeneric(a2);
        assertEqFq2(sp2, ge2);

        MNT4ExtensionFinal.Fq4 memory a4;
        a4.c0 = a2;
        a4.c1.c0 = BigIntMNT.toMontgomery([uint256(7), uint256(8), uint256(9)]);
        a4.c1.c1 = BigIntMNT.toMontgomery([uint256(10), uint256(11), uint256(12)]);
        MNT4ExtensionFinal.Fq4 memory sp4 = MNT4ExtensionFinal.fq4MulByV(a4);
        MNT4ExtensionFinal.Fq4 memory ge4 = eh.fq4MulByVGeneric(a4);
        assertEqFq4(sp4, ge4);
    }

    function testLazyVariantsMatchProduction() public view {
        MNT4ExtensionFinal.Fq2 memory a;
        a.c0 = BigIntMNT.toMontgomery([uint256(123), uint256(456), uint256(789)]);
        a.c1 = BigIntMNT.toMontgomery([uint256(321), uint256(654), uint256(987)]);
        MNT4ExtensionFinal.Fq2 memory b;
        b.c0 = BigIntMNT.toMontgomery([uint256(111), uint256(222), uint256(333)]);
        b.c1 = BigIntMNT.toMontgomery([uint256(444), uint256(555), uint256(666)]);

        assertEqFq2(MNT4ExtensionFinal.fq2Sqr(a), eh.fq2SqrLazyDouble(a));
        assertEqFq2(MNT4ExtensionFinal.fq2Mul(a, b), eh.fq2MulLazyC0(a, b));
    }

    function testGasReport_algorithmStudy_allOps() public {
        (uint256 a0, uint256 a1, uint256 a2) = bench.benchCombaMul3();
        assertTrue((a0 | a1 | a2) != 0);
        (a0, a1, a2) = bench.benchCombaSqr3();
        assertTrue((a0 | a1 | a2) != 0);
        (a0, a1, a2) = bench.benchSquareCombaSqr3();
        assertTrue((a0 | a1 | a2) != 0);
        (a0, a1, a2) = bench.benchBranchlessAdd3();
        assertTrue((a0 | a1 | a2) != 0);
        (a0, a1, a2) = bench.benchMulBy13Specialized();
        assertTrue((a0 | a1 | a2) != 0);
        (a0, a1, a2) = bench.benchMulBy13Generic();
        assertTrue((a0 | a1 | a2) != 0);
        MNT4ExtensionFinal.Fq2 memory x2 = bench.benchFq2MulByUSpecialized();
        assertTrue((x2.c0[0] | x2.c1[0]) != 0);
        x2 = bench.benchFq2MulByUGeneric();
        assertTrue((x2.c0[0] | x2.c1[0]) != 0);
        MNT4ExtensionFinal.Fq4 memory x4 = bench.benchFq4MulByVSpecialized();
        assertTrue((x4.c0.c0[0] | x4.c1.c1[0]) != 0);
        x4 = bench.benchFq4MulByVGeneric();
        assertTrue((x4.c0.c0[0] | x4.c1.c1[0]) != 0);
        x2 = bench.benchFq2SqrProduction();
        assertTrue((x2.c0[0] | x2.c1[0]) != 0);
        x2 = bench.benchFq2SqrLazyDouble();
        assertTrue((x2.c0[0] | x2.c1[0]) != 0);
        x2 = bench.benchFq2MulProduction();
        assertTrue((x2.c0[0] | x2.c1[0]) != 0);
        x2 = bench.benchFq2MulLazyC0();
        assertTrue((x2.c0[0] | x2.c1[0]) != 0);
    }
}
