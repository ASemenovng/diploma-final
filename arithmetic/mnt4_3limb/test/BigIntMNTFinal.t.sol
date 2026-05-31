// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import "forge-std/Test.sol";
import "../src/BigIntMNT.sol";

contract BigIntMNTHarness {
    function add(uint256[3] memory a, uint256[3] memory b) external pure returns (uint256[3] memory) {
        return BigIntMNT.add(a, b);
    }
    function sub(uint256[3] memory a, uint256[3] memory b) external pure returns (uint256[3] memory) {
        return BigIntMNT.sub(a, b);
    }
    function montMul(uint256[3] memory a, uint256[3] memory b) external pure returns (uint256[3] memory) {
        return BigIntMNT.montMul(a, b);
    }
    function toMontgomery(uint256[3] memory x) external pure returns (uint256[3] memory) {
        return BigIntMNT.toMontgomery(x);
    }
    function fromMontgomery(uint256[3] memory x) external pure returns (uint256[3] memory) {
        return BigIntMNT.fromMontgomery(x);
    }
    function montSqr(uint256[3] memory a) external pure returns (uint256[3] memory) {
        return BigIntMNT.montSqr(a);
    }
    function inv(uint256[3] memory a) external pure returns (uint256[3] memory) {
        return BigIntMNT.inv(a);
    }
    function invNative(uint256[3] memory a) external pure returns (uint256[3] memory) {
        return BigIntMNT.invNative(a);
    }
    function invModexp(uint256[3] memory a) external view returns (uint256[3] memory) {
        return BigIntMNT.invModexp(a);
    }
}

/// @notice Harness с "stack API": 6 слов -> 3 слова, без memory-массивов.
contract BigIntMNTHarness3 {
    function add3(
        uint256 a0, uint256 a1, uint256 a2,
        uint256 b0, uint256 b1, uint256 b2
    ) external pure returns (uint256 r0, uint256 r1, uint256 r2) {
        return BigIntMNT.add3(a0, a1, a2, b0, b1, b2);
    }

    function sub3(
        uint256 a0, uint256 a1, uint256 a2,
        uint256 b0, uint256 b1, uint256 b2
    ) external pure returns (uint256 r0, uint256 r1, uint256 r2) {
        return BigIntMNT.sub3(a0, a1, a2, b0, b1, b2);
    }

    function montMul3(
        uint256 a0, uint256 a1, uint256 a2,
        uint256 b0, uint256 b1, uint256 b2
    ) external pure returns (uint256 r0, uint256 r1, uint256 r2) {
        return BigIntMNT.montMul3(a0, a1, a2, b0, b1, b2);
    }

    function montSqr3(
        uint256 a0, uint256 a1, uint256 a2
    ) external pure returns (uint256 r0, uint256 r1, uint256 r2) {
        return BigIntMNT.montSqr3(a0, a1, a2);
    }

    // NEW: stack-версии конвертаций, чтобы в gas-report была полная таблица
    function toMontgomery3(
        uint256 x0, uint256 x1, uint256 x2
    ) external pure returns (uint256 r0, uint256 r1, uint256 r2) {
        return BigIntMNT.toMontgomery3(x0, x1, x2);
    }

    function fromMontgomery3(
        uint256 x0, uint256 x1, uint256 x2
    ) external pure returns (uint256 r0, uint256 r1, uint256 r2) {
        return BigIntMNT.fromMontgomery3(x0, x1, x2);
    }

    function inv3(
        uint256 x0, uint256 x1, uint256 x2
    ) external pure returns (uint256 r0, uint256 r1, uint256 r2) {
        return BigIntMNT.inv3(x0, x1, x2);
    }

    function inv3Native(
        uint256 x0, uint256 x1, uint256 x2
    ) external pure returns (uint256 r0, uint256 r1, uint256 r2) {
        return BigIntMNT.inv3Native(x0, x1, x2);
    }

    function inv3Modexp(
        uint256 x0, uint256 x1, uint256 x2
    ) external view returns (uint256 r0, uint256 r1, uint256 r2) {
        return BigIntMNT.inv3Modexp(x0, x1, x2);
    }

    function mulBy13(
        uint256 x0, uint256 x1, uint256 x2
    ) external pure returns (uint256 r0, uint256 r1, uint256 r2) {
        return BigIntMNT.mulBy13(x0, x1, x2);
    }
}

/// @notice “Internal-style” bench: один внешний вызов, внутри N internal операций.
///         Это самое близкое к тому, что будет происходить внутри Miller loop.
contract BigIntMNTInternalBench {
    uint256 internal constant N_ADD = 16384;
    uint256 internal constant N_SUB = 16384;
    uint256 internal constant N_MUL = 512;
    uint256 internal constant N_SQR = 512;
    uint256 internal constant N_TOM = 512;
    uint256 internal constant N_FRM = 512;
    uint256 internal constant N_INV = 32;

    uint256 private constant P_0  = 0x685acce9767254a4638810719ac425f0e39d54522cdd119f5e9063de245e8001;
    uint256 private constant P_1  = 0x7fdb925e8a0ed8d99d124d9a15af79db117e776f218059db80f0da5cb537e38;
    uint256 private constant P_2  = 0x1c4c62d92c41110229022eee2cdadb7f997505b8fafed5eb7e8f96c97d873;

    // Full-width reduced seeds (< p), все limb’ы ненулевые
    uint256 internal constant SEED_A0 = P_0 - 0x123456789abcdef0123456789abcdef0;
    uint256 internal constant SEED_A1 = P_1 - 0x11111111111111111111111111111111;
    uint256 internal constant SEED_A2 = P_2 - 0x0000000000000000000000000000000000000000000000000000000000012345;

    uint256 internal constant SEED_B0 = P_0 - 0x0fedcba9876543210fedcba987654321;
    uint256 internal constant SEED_B1 = P_1 - 0x22222222222222222222222222222222;
    uint256 internal constant SEED_B2 = P_2 - 0x0000000000000000000000000000000000000000000000000000000000023456;

    function benchAdd3() external pure returns (uint256 r0, uint256 r1, uint256 r2) {
        uint256 a0 = 1; uint256 a1 = 2; uint256 a2 = 3;
        uint256 b0 = 4; uint256 b1 = 5; uint256 b2 = 6;

        for (uint256 i = 0; i < N_ADD; ) {
            (a0, a1, a2) = BigIntMNT.add3(a0, a1, a2, b0, b1, b2);
            unchecked { ++i; }
        }
        return (a0, a1, a2);
    }

    function benchSub3() external pure returns (uint256 r0, uint256 r1, uint256 r2) {
        uint256 a0 = 123; uint256 a1 = 456; uint256 a2 = 789;
        uint256 b0 = 1;   uint256 b1 = 2;   uint256 b2 = 3;

        for (uint256 i = 0; i < N_SUB; ) {
            (a0, a1, a2) = BigIntMNT.sub3(a0, a1, a2, b0, b1, b2);
            unchecked { ++i; }
        }
        return (a0, a1, a2);
    }

    // function benchMontMul3() external pure returns (uint256 r0, uint256 r1, uint256 r2) {
    //     // Берём уже "как будто Montgomery" значения (просто любые <p),
    //     // потому что нам важна стоимость montMul3 в теле loop.
    //     uint256 a0 = 1234567; uint256 a1 = 0; uint256 a2 = 0;
    //     uint256 b0 = 7654321; uint256 b1 = 0; uint256 b2 = 0;

    //     for (uint256 i = 0; i < N_MUL; ) {
    //         (a0, a1, a2) = BigIntMNT.montMul3(a0, a1, a2, b0, b1, b2);
    //         unchecked { ++i; }
    //     }
    //     return (a0, a1, a2);
    // }
    function benchMontMul3() external pure returns (uint256 r0, uint256 r1, uint256 r2) {
        uint256 a0 = SEED_A0; uint256 a1 = SEED_A1; uint256 a2 = SEED_A2;
        uint256 b0 = SEED_B0; uint256 b1 = SEED_B1; uint256 b2 = SEED_B2;

        for (uint256 i = 0; i < N_MUL; ) {
            (a0, a1, a2) = BigIntMNT.montMul3(a0, a1, a2, b0, b1, b2);
            unchecked { ++i; }
        }
        return (a0, a1, a2);
    }

    // function benchMontMulSquare3() external pure returns (uint256 a0, uint256 a1, uint256 a2) {
    //     a0 = 1234567; a1 = 0; a2 = 0;
    //     for (uint256 i = 0; i < N_SQR; ) {
    //         (a0, a1, a2) = BigIntMNT.montMul3(a0, a1, a2, a0, a1, a2);
    //         unchecked { ++i; }
    //     }
    // }
    function benchMontMulSquare3() external pure returns (uint256 a0, uint256 a1, uint256 a2) {
        a0 = SEED_A0; a1 = SEED_A1; a2 = SEED_A2;
        for (uint256 i = 0; i < N_SQR; ) {
            (a0, a1, a2) = BigIntMNT.montMul3(a0, a1, a2, a0, a1, a2);
            unchecked { ++i; }
        }
    }

    // function benchMontSqr3() external pure returns (uint256 r0, uint256 r1, uint256 r2) {
    //     uint256 a0 = 1234567; uint256 a1 = 0; uint256 a2 = 0;

    //     for (uint256 i = 0; i < N_SQR; ) {
    //         (a0, a1, a2) = BigIntMNT.montSqr3(a0, a1, a2);
    //         unchecked { ++i; }
    //     }
    //     return (a0, a1, a2);
    // }
    function benchMontSqr3() external pure returns (uint256 r0, uint256 r1, uint256 r2) {
        uint256 a0 = SEED_A0; uint256 a1 = SEED_A1; uint256 a2 = SEED_A2;

        for (uint256 i = 0; i < N_SQR; ) {
            (a0, a1, a2) = BigIntMNT.montSqr3(a0, a1, a2);
            unchecked { ++i; }
        }
        return (a0, a1, a2);
    }

    function benchToMontgomery3() external pure returns (uint256 r0, uint256 r1, uint256 r2) {
        uint256 a0 = 42; uint256 a1 = 0; uint256 a2 = 0;

        for (uint256 i = 0; i < N_TOM; ) {
            (a0, a1, a2) = BigIntMNT.toMontgomery3(a0, a1, a2);
            unchecked { ++i; }
        }
        return (a0, a1, a2);
    }

    // function benchFromMontgomery3() external pure returns (uint256 r0, uint256 r1, uint256 r2) {
    //     uint256 a0 = 42; uint256 a1 = 0; uint256 a2 = 0;

    //     for (uint256 i = 0; i < N_FRM; ) {
    //         (a0, a1, a2) = BigIntMNT.fromMontgomery3(a0, a1, a2);
    //         unchecked { ++i; }
    //     }
    //     return (a0, a1, a2);
    // }
    function benchFromMontgomery3() external pure returns (uint256 r0, uint256 r1, uint256 r2) {
        // Стартуем с корректного Montgomery-значения
        (uint256 a0, uint256 a1, uint256 a2) = BigIntMNT.toMontgomery3(
            P_0 - 0x123456789abcdef0123456789abcdef0,
            P_1 - 0x11111111111111111111111111111111,
            P_2 - 0x12345
        );

        for (uint256 i = 0; i < N_FRM; ) {
            (a0, a1, a2) = BigIntMNT.fromMontgomery3(a0, a1, a2);
            unchecked { ++i; }
        }
        return (a0, a1, a2);
    }

    function benchInv3() external pure returns (uint256 r0, uint256 r1, uint256 r2) {
        (uint256 a0, uint256 a1, uint256 a2) = BigIntMNT.toMontgomery3(5, 0, 0);
        for (uint256 i = 0; i < N_INV; ) {
            (a0, a1, a2) = BigIntMNT.inv3(a0, a1, a2);
            unchecked { ++i; }
        }
        return (a0, a1, a2);
    }

    function benchInv3Modexp() external view returns (uint256 r0, uint256 r1, uint256 r2) {
        (uint256 a0, uint256 a1, uint256 a2) = BigIntMNT.toMontgomery3(5, 0, 0);
        for (uint256 i = 0; i < N_INV; ) {
            (a0, a1, a2) = BigIntMNT.inv3Modexp(a0, a1, a2);
            unchecked { ++i; }
        }
        return (a0, a1, a2);
    }
}

contract BigIntMNTV3Test is Test {
    BigIntMNTHarness lib;
    BigIntMNTHarness3 lib3;
    BigIntMNTInternalBench bench;

    uint256 private constant P_0  = 0x685acce9767254a4638810719ac425f0e39d54522cdd119f5e9063de245e8001;
    uint256 private constant P_1  = 0x07fdb925e8a0ed8d99d124d9a15af79db117e776f218059db80f0da5cb537e38;
    uint256 private constant P_2  = 0x001c4c62d92c41110229022eee2cdadb7f997505b8fafed5eb7e8f96c97d873;

    function setUp() public {
        lib = new BigIntMNTHarness();
        lib3 = new BigIntMNTHarness3();
        bench = new BigIntMNTInternalBench();
    }

    function mk(uint256 x) internal pure returns (uint256[3] memory r) {
        r[0] = x; r[1] = 0; r[2] = 0;
    }

    function pMinus1() internal pure returns (uint256[3] memory r) {
        r[0] = P_0 - 1;
        r[1] = P_1;
        r[2] = P_2;
    }

    function pMinus2() internal pure returns (uint256[3] memory r) {
        r[0] = P_0 - 2;
        r[1] = P_1;
        r[2] = P_2;
    }

    function assertEq3(uint256[3] memory a, uint256[3] memory b) internal pure {
        assertEq(a[0], b[0], "Limb 0 mismatch");
        assertEq(a[1], b[1], "Limb 1 mismatch");
        assertEq(a[2], b[2], "Limb 2 mismatch");
    }

    function testAddSimple() public view {
        assertEq3(lib.add(mk(100), mk(200)), mk(300));
    }

    function testAddCarry() public view {
        uint256[3] memory a; a[0] = type(uint256).max;
        uint256[3] memory res = lib.add(a, mk(1));
        assertEq(res[0], 0);
        assertEq(res[1], 1);
        assertEq(res[2], 0);
    }

    function testAddWrapModP() public view {
        assertEq3(lib.add(pMinus1(), mk(1)), mk(0));
    }

    function testAddLargeNoWrap() public view {
        assertEq3(lib.add(pMinus1(), pMinus1()), pMinus2());
    }

    function testSubSimple() public view {
        assertEq3(lib.sub(mk(10), mk(3)), mk(7));
    }

    function testSubUnderflow() public view {
        uint256[3] memory res = lib.sub(mk(5), mk(6));
        assertEq3(res, pMinus1());
    }

    function testMontgomeryRoundtripSmall() public view {
        uint256[3] memory x = mk(42);
        uint256[3] memory x_m = lib.toMontgomery(x);
        uint256[3] memory x_back = lib.fromMontgomery(x_m);
        assertEq3(x_back, x);
    }

    function testMontgomeryRoundtripLarge() public view {
        uint256[3] memory x = pMinus1();
        uint256[3] memory x_m = lib.toMontgomery(x);
        uint256[3] memory x_back = lib.fromMontgomery(x_m);
        assertEq3(x_back, x);
    }

    function testMontMulSmall() public view {
        uint256[3] memory a = mk(2);
        uint256[3] memory b = mk(3);
        uint256[3] memory am = lib.toMontgomery(a);
        uint256[3] memory bm = lib.toMontgomery(b);
        uint256[3] memory resM = lib.montMul(am, bm);
        uint256[3] memory res = lib.fromMontgomery(resM);
        assertEq3(res, mk(6));
    }

    function testMontMulNegOneSquare() public view {
        uint256[3] memory neg1 = pMinus1();
        uint256[3] memory one = mk(1);

        uint256[3] memory neg1m = lib.toMontgomery(neg1);
        uint256[3] memory resM = lib.montMul(neg1m, neg1m);
        uint256[3] memory res = lib.fromMontgomery(resM);

        assertEq3(res, one);
    }

    function testMontMulOne() public {
        uint256[3] memory one = mk(1);
        uint256[3] memory one_m = lib.toMontgomery(one);
        uint256[3] memory res_m = lib.montMul(one_m, one_m);
        uint256[3] memory res = lib.fromMontgomery(res_m);
        assertEq3(res, one);
    }

    function testMontSqrMatchesMul() public {
        uint256[3] memory x = mk(1234567);
        uint256[3] memory xm = lib.toMontgomery(x);

        uint256[3] memory sq1 = lib.montSqr(xm);
        uint256[3] memory sq2 = lib.montMul(xm, xm);

        assertEq3(sq1, sq2);
    }

    function testInvMulOne() public {
        uint256[3] memory x = lib.toMontgomery(mk(7));
        uint256[3] memory invX = lib.inv(x);
        uint256[3] memory oneM = lib.toMontgomery(mk(1));
        uint256[3] memory prod = lib.montMul(x, invX);
        assertEq3(prod, oneM);
    }

    function testInvModexpMulOne() public {
        uint256[3] memory x = lib.toMontgomery(mk(7));
        uint256[3] memory invX = lib.invModexp(x);
        uint256[3] memory oneM = lib.toMontgomery(mk(1));
        uint256[3] memory prod = lib.montMul(x, invX);
        assertEq3(prod, oneM);
    }

    function testInvNativeEqualsModexp() public {
        uint256[3] memory x = lib.toMontgomery(mk(123456789));
        uint256[3] memory invN = lib.invNative(x);
        uint256[3] memory invM = lib.invModexp(x);
        assertEq3(invN, invM);
    }

    function testMulBy13MatchesRepeatedAdd() public {
        uint256 a0 = P_0 - 12345;
        uint256 a1 = P_1 - 67890;
        uint256 a2 = P_2 - 111;

        (uint256 r0, uint256 r1, uint256 r2) = lib3.mulBy13(a0, a1, a2);

        (uint256 t0, uint256 t1, uint256 t2) = BigIntMNT.add3(a0, a1, a2, a0, a1, a2); // 2a
        (t0, t1, t2) = BigIntMNT.add3(t0, t1, t2, t0, t1, t2); // 4a
        (uint256 e0, uint256 e1, uint256 e2) = BigIntMNT.add3(t0, t1, t2, t0, t1, t2); // 8a
        (e0, e1, e2) = BigIntMNT.add3(e0, e1, e2, t0, t1, t2); // 12a
        (e0, e1, e2) = BigIntMNT.add3(e0, e1, e2, a0, a1, a2); // 13a

        assertEq(r0, e0, "mulBy13 limb0");
        assertEq(r1, e1, "mulBy13 limb1");
        assertEq(r2, e2, "mulBy13 limb2");
    }

    // ---------------- GAS BENCHES (твои) ----------------

    function _logBench(string memory name, uint256 used, uint256 n) internal {
        emit log_named_uint(string.concat(name, " total gas"), used);
        emit log_named_uint(string.concat(name, " gas/op"), used / n);
    }

    function _benchLoopOverhead(uint256 n) internal returns (uint256 used) {
        uint256 x = 1;
        uint256 g0 = gasleft();
        for (uint256 i = 0; i < n; i++) {
            unchecked { x += i; }
        }
        used = g0 - gasleft();
        assertTrue(x != 0);
    }

    function testGasBench_add3_internal() public {
        uint256 N = 16384;

        uint256 a0 = 1; uint256 a1 = 2; uint256 a2 = 3;
        uint256 b0 = 4; uint256 b1 = 5; uint256 b2 = 6;

        uint256 overhead = _benchLoopOverhead(N);

        uint256 g0 = gasleft();
        for (uint256 i = 0; i < N; i++) {
            (a0, a1, a2) = BigIntMNT.add3(a0, a1, a2, b0, b1, b2);
        }
        uint256 used = g0 - gasleft();

        vm.pauseGasMetering();
        _logBench("add3 internal", used, N);
        emit log_named_uint("add3 internal approx gas/op minus loop overhead", (used - overhead) / N);
        vm.resumeGasMetering();

        assertTrue((a0 | a1 | a2) != 0);
    }

    function testGasBench_add3_external_stack() public {
        uint256 N = 4096;

        uint256 a0 = 1; uint256 a1 = 2; uint256 a2 = 3;
        uint256 b0 = 4; uint256 b1 = 5; uint256 b2 = 6;

        uint256 g0 = gasleft();
        for (uint256 i = 0; i < N; i++) {
            (a0, a1, a2) = lib3.add3(a0, a1, a2, b0, b1, b2);
        }
        uint256 used = g0 - gasleft();

        vm.pauseGasMetering();
        _logBench("add3 external (stack ABI)", used, N);
        vm.resumeGasMetering();

        assertTrue((a0 | a1 | a2) != 0);
    }

    function testGasBench_add_external_memory_array() public {
        uint256 N = 256;

        uint256[3] memory a = mk(1);
        uint256[3] memory b = mk(2);

        uint256 g0 = gasleft();
        for (uint256 i = 0; i < N; i++) {
            a = lib.add(a, b);
        }
        uint256 used = g0 - gasleft();

        vm.pauseGasMetering();
        _logBench("add external (uint256[3] memory ABI)", used, N);
        vm.resumeGasMetering();

        assertTrue((a[0] | a[1] | a[2]) != 0);
    }

    // function testGasBench_montMul3_internal() public {
    //     uint256 N = 2048;

    //     vm.pauseGasMetering();
    //     uint256[3] memory am = BigIntMNT.toMontgomery(mk(1234567));
    //     uint256[3] memory bm = BigIntMNT.toMontgomery(mk(7654321));
    //     vm.resumeGasMetering();

    //     uint256 a0 = am[0]; uint256 a1 = am[1]; uint256 a2 = am[2];
    //     uint256 b0 = bm[0]; uint256 b1 = bm[1]; uint256 b2 = bm[2];

    //     uint256 g0 = gasleft();
    //     for (uint256 i = 0; i < N; i++) {
    //         (a0, a1, a2) = BigIntMNT.montMul3(a0, a1, a2, b0, b1, b2);
    //     }
    //     uint256 used = g0 - gasleft();

    //     vm.pauseGasMetering();
    //     _logBench("montMul3 internal", used, N);
    //     vm.resumeGasMetering();

    //     assertTrue((a0 | a1 | a2) != 0);
    // }
    function testGasBench_montMul3_internal() public {
        uint256 N = 2048;

        vm.pauseGasMetering();
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
        vm.resumeGasMetering();

        uint256 g0 = gasleft();
        for (uint256 i = 0; i < N; i++) {
            (a0, a1, a2) = BigIntMNT.montMul3(a0, a1, a2, b0, b1, b2);
        }
        uint256 used = g0 - gasleft();

        vm.pauseGasMetering();
        _logBench("montMul3 internal (full-width)", used, N);
        vm.resumeGasMetering();

        assertTrue((a0 | a1 | a2) != 0);
    }

    // function testGasBench_montSqr3_internal() public {
    //     uint256 N = 2048;

    //     vm.pauseGasMetering();
    //     uint256[3] memory xm = BigIntMNT.toMontgomery(mk(1234567));
    //     vm.resumeGasMetering();

    //     uint256 a0 = xm[0]; uint256 a1 = xm[1]; uint256 a2 = xm[2];

    //     uint256 g0 = gasleft();
    //     for (uint256 i = 0; i < N; i++) {
    //         (a0, a1, a2) = BigIntMNT.montSqr3(a0, a1, a2);
    //     }
    //     uint256 used = g0 - gasleft();

    //     vm.pauseGasMetering();
    //     _logBench("montSqr3 internal", used, N);
    //     vm.resumeGasMetering();

    //     assertTrue((a0 | a1 | a2) != 0);
    // }
    function testGasBench_montSqr3_internal() public {
        uint256 N = 2048;

        vm.pauseGasMetering();
        (uint256 a0, uint256 a1, uint256 a2) = BigIntMNT.toMontgomery3(
            P_0 - 0x123456789abcdef0123456789abcdef0,
            P_1 - 0x11111111111111111111111111111111,
            P_2 - 0x12345
        );
        vm.resumeGasMetering();

        uint256 g0 = gasleft();
        for (uint256 i = 0; i < N; i++) {
            (a0, a1, a2) = BigIntMNT.montSqr3(a0, a1, a2);
        }
        uint256 used = g0 - gasleft();

        vm.pauseGasMetering();
        _logBench("montSqr3 internal (full-width)", used, N);
        vm.resumeGasMetering();

        assertTrue((a0 | a1 | a2) != 0);
    }

    function testGasBench_sub3_external_stack() public {
        uint256 N = 4096;

        uint256 a0 = 123; uint256 a1 = 456; uint256 a2 = 789;
        uint256 b0 = 1;   uint256 b1 = 2;   uint256 b2 = 3;

        uint256 g0 = gasleft();
        for (uint256 i = 0; i < N; i++) {
            (a0, a1, a2) = lib3.sub3(a0, a1, a2, b0, b1, b2);
        }
        uint256 used = g0 - gasleft();

        vm.pauseGasMetering();
        emit log_named_uint("sub3 external (stack ABI) total gas", used);
        emit log_named_uint("sub3 external (stack ABI) gas/op", used / N);
        vm.resumeGasMetering();

        assertTrue((a0 | a1 | a2) != 0);
    }

    // function testGasBench_montMul3_external_stack() public {
    //     uint256 N = 512;

    //     vm.pauseGasMetering();
    //     uint256[3] memory am = BigIntMNT.toMontgomery(mk(1234567));
    //     uint256[3] memory bm = BigIntMNT.toMontgomery(mk(7654321));
    //     vm.resumeGasMetering();

    //     uint256 a0 = am[0]; uint256 a1 = am[1]; uint256 a2 = am[2];
    //     uint256 b0 = bm[0]; uint256 b1 = bm[1]; uint256 b2 = bm[2];

    //     uint256 g0 = gasleft();
    //     for (uint256 i = 0; i < N; i++) {
    //         (a0, a1, a2) = lib3.montMul3(a0, a1, a2, b0, b1, b2);
    //     }
    //     uint256 used = g0 - gasleft();

    //     vm.pauseGasMetering();
    //     emit log_named_uint("montMul3 external (stack ABI) total gas", used);
    //     emit log_named_uint("montMul3 external (stack ABI) gas/op", used / N);
    //     vm.resumeGasMetering();

    //     assertTrue((a0 | a1 | a2) != 0);
    // }
    function testGasBench_montMul3_external_stack() public {
        uint256 N = 512;

        vm.pauseGasMetering();
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
        vm.resumeGasMetering();

        uint256 g0 = gasleft();
        for (uint256 i = 0; i < N; i++) {
            (a0, a1, a2) = lib3.montMul3(a0, a1, a2, b0, b1, b2);
        }
        uint256 used = g0 - gasleft();

        vm.pauseGasMetering();
        emit log_named_uint("montMul3 external (stack ABI, full-width) total gas", used);
        emit log_named_uint("montMul3 external (stack ABI, full-width) gas/op", used / N);
        vm.resumeGasMetering();

        assertTrue((a0 | a1 | a2) != 0);
    }

    function testGasBench_montSqr3_external_stack() public {
        uint256 N = 512;

        vm.pauseGasMetering();
        uint256[3] memory xm = BigIntMNT.toMontgomery(mk(1234567));
        vm.resumeGasMetering();

        uint256 a0 = xm[0]; uint256 a1 = xm[1]; uint256 a2 = xm[2];

        uint256 g0 = gasleft();
        for (uint256 i = 0; i < N; i++) {
            (a0, a1, a2) = lib3.montSqr3(a0, a1, a2);
        }
        uint256 used = g0 - gasleft();

        vm.pauseGasMetering();
        emit log_named_uint("montSqr3 external (stack ABI) total gas", used);
        emit log_named_uint("montSqr3 external (stack ABI) gas/op", used / N);
        vm.resumeGasMetering();

        assertTrue((a0 | a1 | a2) != 0);
    }

    // NEW: чтобы в BigIntMNTHarness3 появились to/from в gas-report
    function testGasBench_toMontgomery3_external_stack() public {
        uint256 N = 256;
        uint256 x0 = 42; uint256 x1 = 0; uint256 x2 = 0;

        uint256 g0 = gasleft();
        for (uint256 i = 0; i < N; i++) {
            (x0, x1, x2) = lib3.toMontgomery3(x0, x1, x2);
        }
        uint256 used = g0 - gasleft();

        vm.pauseGasMetering();
        emit log_named_uint("toMontgomery3 external (stack ABI) total gas", used);
        emit log_named_uint("toMontgomery3 external (stack ABI) gas/op", used / N);
        vm.resumeGasMetering();

        assertTrue((x0 | x1 | x2) != 0);
    }

    // function testGasBench_fromMontgomery3_external_stack() public {
    //     uint256 N = 256;
    //     uint256 x0 = 42; uint256 x1 = 0; uint256 x2 = 0;

    //     uint256 g0 = gasleft();
    //     for (uint256 i = 0; i < N; i++) {
    //         (x0, x1, x2) = lib3.fromMontgomery3(x0, x1, x2);
    //     }
    //     uint256 used = g0 - gasleft();

    //     vm.pauseGasMetering();
    //     emit log_named_uint("fromMontgomery3 external (stack ABI) total gas", used);
    //     emit log_named_uint("fromMontgomery3 external (stack ABI) gas/op", used / N);
    //     vm.resumeGasMetering();

    //     assertTrue((x0 | x1 | x2) != 0);
    // }
    function testGasBench_fromMontgomery3_external_stack() public {
        uint256 N = 256;

        vm.pauseGasMetering();
        (uint256 x0, uint256 x1, uint256 x2) = BigIntMNT.toMontgomery3(42, 0, 0);
        vm.resumeGasMetering();

        uint256 g0 = gasleft();
        for (uint256 i = 0; i < N; i++) {
            (x0, x1, x2) = lib3.fromMontgomery3(x0, x1, x2);
        }
        uint256 used = g0 - gasleft();

        vm.pauseGasMetering();
        emit log_named_uint("fromMontgomery3 external (stack ABI) total gas", used);
        emit log_named_uint("fromMontgomery3 external (stack ABI) gas/op", used / N);
        vm.resumeGasMetering();

        assertTrue((x0 | x1 | x2) != 0);
    }

    function testGasBench_inv3_external_stack() public {
        uint256 N = 16;
        (uint256 x0, uint256 x1, uint256 x2) = BigIntMNT.toMontgomery3(5, 0, 0);

        uint256 g0 = gasleft();
        for (uint256 i = 0; i < N; i++) {
            (x0, x1, x2) = lib3.inv3(x0, x1, x2);
        }
        uint256 used = g0 - gasleft();

        vm.pauseGasMetering();
        emit log_named_uint("inv3 external (stack ABI) total gas", used);
        emit log_named_uint("inv3 external (stack ABI) gas/op", used / N);
        vm.resumeGasMetering();

        assertTrue((x0 | x1 | x2) != 0);
    }

    function testGasBench_inv3Modexp_external_stack() public {
        uint256 N = 16;
        (uint256 x0, uint256 x1, uint256 x2) = BigIntMNT.toMontgomery3(5, 0, 0);

        uint256 g0 = gasleft();
        for (uint256 i = 0; i < N; i++) {
            (x0, x1, x2) = lib3.inv3Modexp(x0, x1, x2);
        }
        uint256 used = g0 - gasleft();

        vm.pauseGasMetering();
        emit log_named_uint("inv3Modexp external (stack ABI) total gas", used);
        emit log_named_uint("inv3Modexp external (stack ABI) gas/op", used / N);
        vm.resumeGasMetering();

        assertTrue((x0 | x1 | x2) != 0);
    }

    // NEW: один тест, чтобы в gas-report появилась “internal-style” таблица bench-контракта
    function testGasReport_internalStyleBench_allOps() public {
        (uint256 a0, uint256 a1, uint256 a2) = bench.benchAdd3();
        assertTrue((a0 | a1 | a2) != 0);

        (a0, a1, a2) = bench.benchSub3();
        assertTrue((a0 | a1 | a2) != 0);

        (a0, a1, a2) = bench.benchMontMul3();
        assertTrue((a0 | a1 | a2) != 0);

        (a0, a1, a2) = bench.benchMontSqr3();
        assertTrue((a0 | a1 | a2) != 0);

        (a0, a1, a2) = bench.benchMontMulSquare3();
        assertTrue((a0 | a1 | a2) != 0);

        (a0, a1, a2) = bench.benchToMontgomery3();
        assertTrue((a0 | a1 | a2) != 0);

        (a0, a1, a2) = bench.benchFromMontgomery3();
        assertTrue((a0 | a1 | a2) != 0);

        (a0, a1, a2) = bench.benchInv3();
        assertTrue((a0 | a1 | a2) != 0);

        (a0, a1, a2) = bench.benchInv3Modexp();
        assertTrue((a0 | a1 | a2) != 0);
    }
}
