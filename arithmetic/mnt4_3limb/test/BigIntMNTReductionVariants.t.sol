// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import "forge-std/Test.sol";
import "../src/BigIntMNT.sol";
import "../research_variants/BigIntMNTBarrett.sol";
import "../research_variants/BigIntMNTFIOS.sol";

contract BigIntMNTReductionVariantHarness {
    function barrettMul3(
        uint256 a0, uint256 a1, uint256 a2,
        uint256 b0, uint256 b1, uint256 b2
    ) external pure returns (uint256 r0, uint256 r1, uint256 r2) {
        return BigIntMNTBarrett.mul3(a0, a1, a2, b0, b1, b2);
    }

    function barrettSqr3(uint256 a0, uint256 a1, uint256 a2)
        external pure returns (uint256 r0, uint256 r1, uint256 r2)
    {
        return BigIntMNTBarrett.sqr3(a0, a1, a2);
    }

    function fiosMul3(
        uint256 a0, uint256 a1, uint256 a2,
        uint256 b0, uint256 b1, uint256 b2
    ) external pure returns (uint256 r0, uint256 r1, uint256 r2) {
        return BigIntMNTFIOS.montMul3(a0, a1, a2, b0, b1, b2);
    }

    function fiosSqr3(uint256 a0, uint256 a1, uint256 a2)
        external pure returns (uint256 r0, uint256 r1, uint256 r2)
    {
        return BigIntMNTFIOS.montSqr3(a0, a1, a2);
    }
}

contract BigIntMNTReductionVariantBench {
    uint256 internal constant N_MUL = 256;
    uint256 internal constant N_SQR = 256;

    uint256 private constant P_0 = 0x685acce9767254a4638810719ac425f0e39d54522cdd119f5e9063de245e8001;
    uint256 private constant P_1 = 0x7fdb925e8a0ed8d99d124d9a15af79db117e776f218059db80f0da5cb537e38;
    uint256 private constant P_2 = 0x1c4c62d92c41110229022eee2cdadb7f997505b8fafed5eb7e8f96c97d873;

    function benchBarrettMul3() external pure returns (uint256 r0, uint256 r1, uint256 r2) {
        uint256 a0 = P_0 - 0x123456789abcdef0123456789abcdef0;
        uint256 a1 = P_1 - 0x11111111111111111111111111111111;
        uint256 a2 = P_2 - 0x12345;
        uint256 b0 = P_0 - 0x0fedcba9876543210fedcba987654321;
        uint256 b1 = P_1 - 0x22222222222222222222222222222222;
        uint256 b2 = P_2 - 0x23456;
        for (uint256 i; i < N_MUL; ) {
            (a0, a1, a2) = BigIntMNTBarrett.mul3(a0, a1, a2, b0, b1, b2);
            unchecked { ++i; }
        }
        return (a0, a1, a2);
    }

    function benchBarrettSqr3() external pure returns (uint256 r0, uint256 r1, uint256 r2) {
        uint256 a0 = P_0 - 0x123456789abcdef0123456789abcdef0;
        uint256 a1 = P_1 - 0x11111111111111111111111111111111;
        uint256 a2 = P_2 - 0x12345;
        for (uint256 i; i < N_SQR; ) {
            (a0, a1, a2) = BigIntMNTBarrett.sqr3(a0, a1, a2);
            unchecked { ++i; }
        }
        return (a0, a1, a2);
    }

    function benchFiosMul3() external pure returns (uint256 r0, uint256 r1, uint256 r2) {
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
        for (uint256 i; i < N_MUL; ) {
            (a0, a1, a2) = BigIntMNTFIOS.montMul3(a0, a1, a2, b0, b1, b2);
            unchecked { ++i; }
        }
        return (a0, a1, a2);
    }

    function benchFiosSqr3() external pure returns (uint256 r0, uint256 r1, uint256 r2) {
        (uint256 a0, uint256 a1, uint256 a2) = BigIntMNT.toMontgomery3(
            P_0 - 0x123456789abcdef0123456789abcdef0,
            P_1 - 0x11111111111111111111111111111111,
            P_2 - 0x12345
        );
        for (uint256 i; i < N_SQR; ) {
            (a0, a1, a2) = BigIntMNTFIOS.montSqr3(a0, a1, a2);
            unchecked { ++i; }
        }
        return (a0, a1, a2);
    }
}

contract BigIntMNTReductionVariantsTest is Test {
    BigIntMNTReductionVariantHarness h;
    BigIntMNTReductionVariantBench bench;

    uint256 private constant P_0 = 0x685acce9767254a4638810719ac425f0e39d54522cdd119f5e9063de245e8001;
    uint256 private constant P_1 = 0x7fdb925e8a0ed8d99d124d9a15af79db117e776f218059db80f0da5cb537e38;
    uint256 private constant P_2 = 0x1c4c62d92c41110229022eee2cdadb7f997505b8fafed5eb7e8f96c97d873;

    function setUp() public {
        h = new BigIntMNTReductionVariantHarness();
        bench = new BigIntMNTReductionVariantBench();
    }

    function assertEq3(uint256[3] memory a, uint256[3] memory b) internal pure {
        assertEq(a[0], b[0], "limb0");
        assertEq(a[1], b[1], "limb1");
        assertEq(a[2], b[2], "limb2");
    }

    function mk(uint256 x) internal pure returns (uint256[3] memory r) {
        r[0] = x;
    }

    function testBarrettMulMatchesMontgomeryReference() public view {
        uint256[3] memory a;
        a[0] = P_0 - 0x123456789abcdef0123456789abcdef0;
        a[1] = P_1 - 0x11111111111111111111111111111111;
        a[2] = P_2 - 0x12345;
        uint256[3] memory b;
        b[0] = P_0 - 0x0fedcba9876543210fedcba987654321;
        b[1] = P_1 - 0x22222222222222222222222222222222;
        b[2] = P_2 - 0x23456;

        (uint256 am0, uint256 am1, uint256 am2) = BigIntMNT.toMontgomery3(a[0], a[1], a[2]);
        (uint256 bm0, uint256 bm1, uint256 bm2) = BigIntMNT.toMontgomery3(b[0], b[1], b[2]);
        (uint256 pm0, uint256 pm1, uint256 pm2) = BigIntMNT.montMul3(am0, am1, am2, bm0, bm1, bm2);
        (uint256 e0, uint256 e1, uint256 e2) = BigIntMNT.fromMontgomery3(pm0, pm1, pm2);
        (uint256 r0, uint256 r1, uint256 r2) = h.barrettMul3(a[0], a[1], a[2], b[0], b[1], b[2]);

        assertEq3([r0, r1, r2], [e0, e1, e2]);
    }

    function testBarrettMulMatchesMontgomeryReferenceForSeveralVectors() public view {
        for (uint256 i = 1; i <= 8; ++i) {
            uint256 a0 = P_0 - (0x1000 * i + 17);
            uint256 a1 = P_1 - (0x2000 * i + 19);
            uint256 a2 = P_2 - (0x3000 * i + 23);
            uint256 b0 = P_0 - (0x4000 * i + 29);
            uint256 b1 = P_1 - (0x5000 * i + 31);
            uint256 b2 = P_2 - (0x6000 * i + 37);

            (uint256 am0, uint256 am1, uint256 am2) = BigIntMNT.toMontgomery3(a0, a1, a2);
            (uint256 bm0, uint256 bm1, uint256 bm2) = BigIntMNT.toMontgomery3(b0, b1, b2);
            (uint256 pm0, uint256 pm1, uint256 pm2) = BigIntMNT.montMul3(am0, am1, am2, bm0, bm1, bm2);
            (uint256 e0, uint256 e1, uint256 e2) = BigIntMNT.fromMontgomery3(pm0, pm1, pm2);
            (uint256 r0, uint256 r1, uint256 r2) = h.barrettMul3(a0, a1, a2, b0, b1, b2);
            assertEq3([r0, r1, r2], [e0, e1, e2]);
        }
    }

    function testBarrettSmallVectors() public view {
        (uint256 r0, uint256 r1, uint256 r2) = h.barrettMul3(2, 0, 0, 3, 0, 0);
        assertEq3([r0, r1, r2], mk(6));
        (r0, r1, r2) = h.barrettSqr3(7, 0, 0);
        assertEq3([r0, r1, r2], mk(49));
    }

    function testFiosMatchesCiosMontgomery() public view {
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
        (uint256 e0, uint256 e1, uint256 e2) = BigIntMNT.montMul3(a0, a1, a2, b0, b1, b2);
        (uint256 r0, uint256 r1, uint256 r2) = h.fiosMul3(a0, a1, a2, b0, b1, b2);
        assertEq3([r0, r1, r2], [e0, e1, e2]);
    }

    function testFiosMatchesCiosMontgomeryForSeveralVectors() public view {
        for (uint256 i = 1; i <= 8; ++i) {
            (uint256 a0, uint256 a1, uint256 a2) = BigIntMNT.toMontgomery3(
                P_0 - (0x1000 * i + 17),
                P_1 - (0x2000 * i + 19),
                P_2 - (0x3000 * i + 23)
            );
            (uint256 b0, uint256 b1, uint256 b2) = BigIntMNT.toMontgomery3(
                P_0 - (0x4000 * i + 29),
                P_1 - (0x5000 * i + 31),
                P_2 - (0x6000 * i + 37)
            );
            (uint256 e0, uint256 e1, uint256 e2) = BigIntMNT.montMul3(a0, a1, a2, b0, b1, b2);
            (uint256 r0, uint256 r1, uint256 r2) = h.fiosMul3(a0, a1, a2, b0, b1, b2);
            assertEq3([r0, r1, r2], [e0, e1, e2]);
        }
    }

    function testFiosSqrMatchesCiosMontgomery() public view {
        (uint256 a0, uint256 a1, uint256 a2) = BigIntMNT.toMontgomery3(
            P_0 - 0x123456789abcdef0123456789abcdef0,
            P_1 - 0x11111111111111111111111111111111,
            P_2 - 0x12345
        );
        (uint256 e0, uint256 e1, uint256 e2) = BigIntMNT.montSqr3(a0, a1, a2);
        (uint256 r0, uint256 r1, uint256 r2) = h.fiosSqr3(a0, a1, a2);
        assertEq3([r0, r1, r2], [e0, e1, e2]);
    }

    function _logBench(string memory name, uint256 used, uint256 n) internal {
        emit log_named_uint(string.concat(name, " total gas"), used);
        emit log_named_uint(string.concat(name, " gas/op"), used / n);
    }

    function testGasBench_barrettMul3_internalStyle() public {
        uint256 g0 = gasleft();
        bench.benchBarrettMul3();
        uint256 used = g0 - gasleft();
        vm.pauseGasMetering();
        _logBench("barrettMul3 experimental", used, 256);
        vm.resumeGasMetering();
    }

    function testGasBench_barrettSqr3_internalStyle() public {
        uint256 g0 = gasleft();
        bench.benchBarrettSqr3();
        uint256 used = g0 - gasleft();
        vm.pauseGasMetering();
        _logBench("barrettSqr3 experimental", used, 256);
        vm.resumeGasMetering();
    }

    function testGasBench_fiosMul3_internalStyle() public {
        uint256 g0 = gasleft();
        bench.benchFiosMul3();
        uint256 used = g0 - gasleft();
        vm.pauseGasMetering();
        _logBench("fiosMul3 experimental", used, 256);
        vm.resumeGasMetering();
    }

    function testGasBench_fiosSqr3_internalStyle() public {
        uint256 g0 = gasleft();
        bench.benchFiosSqr3();
        uint256 used = g0 - gasleft();
        vm.pauseGasMetering();
        _logBench("fiosSqr3 experimental", used, 256);
        vm.resumeGasMetering();
    }
}
