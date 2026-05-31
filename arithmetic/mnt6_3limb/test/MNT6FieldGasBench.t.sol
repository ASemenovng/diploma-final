// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Test} from "forge-std/Test.sol";
import {BigIntMNT6} from "../src/BigIntMNT6.sol";
import {MNT6PairingTypes} from "../src/MNT6PairingTypes.sol";
import {MNT6Fp} from "../src/MNT6Fp.sol";
import {MNT6Fq3} from "../src/MNT6Fq3.sol";
import {MNT6Fq6} from "../src/MNT6Fq6.sol";
import {MNT6TestVectors} from "./MNT6TestVectors.sol";

contract MNT6FieldGasBenchTest is Test {
    uint256 private constant P_0 = 0xb9dff97634993aa4d6c381bc3f0057974ea099170fa13a4fd90776e240000001;
    uint256 private constant P_1 = 0x07fdb925e8a0ed8d99d124d9a15af79db26c5c28c859a99b3eebca9429212636;
    uint256 private constant P_2 = 0x0001c4c62d92c41110229022eee2cdadb7f997505b8fafed5eb7e8f96c97d873;

    function _logBench(string memory name, uint256 used, uint256 n) internal {
        emit log_named_uint(string.concat(name, " total gas"), used);
        emit log_named_uint(string.concat(name, " gas/op"), used / n);
    }

    function _benchLoopOverhead(uint256 n) internal returns (uint256 used) {
        uint256 x = 1;
        uint256 g0 = gasleft();
        for (uint256 i; i < n; ) {
            unchecked {
                x += i;
                ++i;
            }
        }
        used = g0 - gasleft();
        assertTrue(x != 0);
    }

    function testGasBench_mnt6FpMul_internal() public {
        uint256 n = 2048;
        uint256 overhead = _benchLoopOverhead(n);
        vm.pauseGasMetering();
        (uint256 a0, uint256 a1, uint256 a2) = BigIntMNT6.toMontgomery3(
            P_0 - 0x123456789abcdef0123456789abcdef0,
            P_1 - 0x11111111111111111111111111111111,
            P_2 - 0x12345
        );
        (uint256 b0, uint256 b1, uint256 b2) = BigIntMNT6.toMontgomery3(
            P_0 - 0x0fedcba9876543210fedcba987654321,
            P_1 - 0x22222222222222222222222222222222,
            P_2 - 0x23456
        );
        vm.resumeGasMetering();

        uint256 g0 = gasleft();
        for (uint256 i; i < n; ) {
            (a0, a1, a2) = BigIntMNT6.montMul3(a0, a1, a2, b0, b1, b2);
            unchecked { ++i; }
        }
        uint256 used = g0 - gasleft();

        vm.pauseGasMetering();
        _logBench("mnt6 Fp montMul3", used, n);
        emit log_named_uint("mnt6 Fp montMul3 gas/op minus loop overhead", (used - overhead) / n);
        vm.resumeGasMetering();
        assertTrue((a0 | a1 | a2) != 0);
    }

    function testGasBench_mnt6FpSqr_internal() public {
        uint256 n = 2048;
        uint256 overhead = _benchLoopOverhead(n);
        vm.pauseGasMetering();
        (uint256 a0, uint256 a1, uint256 a2) = BigIntMNT6.toMontgomery3(
            P_0 - 0x123456789abcdef0123456789abcdef0,
            P_1 - 0x11111111111111111111111111111111,
            P_2 - 0x12345
        );
        vm.resumeGasMetering();

        uint256 g0 = gasleft();
        for (uint256 i; i < n; ) {
            (a0, a1, a2) = BigIntMNT6.montSqr3(a0, a1, a2);
            unchecked { ++i; }
        }
        uint256 used = g0 - gasleft();

        vm.pauseGasMetering();
        _logBench("mnt6 Fp montSqr3", used, n);
        emit log_named_uint("mnt6 Fp montSqr3 gas/op minus loop overhead", (used - overhead) / n);
        vm.resumeGasMetering();
        assertTrue((a0 | a1 | a2) != 0);
    }

    function testGasBench_mnt6Fq3Mul() public {
        uint256 n = 128;
        uint256 overhead = _benchLoopOverhead(n);
        MNT6PairingTypes.Fq3 memory a = MNT6TestVectors.x3();
        MNT6PairingTypes.Fq3 memory b = MNT6TestVectors.y3();

        uint256 g0 = gasleft();
        for (uint256 i; i < n; ) {
            a = MNT6Fq3.mul(a, b);
            unchecked { ++i; }
        }
        uint256 used = g0 - gasleft();

        vm.pauseGasMetering();
        _logBench("mnt6 Fq3 mul", used, n);
        emit log_named_uint("mnt6 Fq3 mul gas/op minus loop overhead", (used - overhead) / n);
        vm.resumeGasMetering();
        assertTrue(!MNT6Fq3.eq(a, MNT6Fq3.zero()));
    }

    function testGasBench_mnt6Fq3Sqr() public {
        uint256 n = 128;
        uint256 overhead = _benchLoopOverhead(n);
        MNT6PairingTypes.Fq3 memory a = MNT6TestVectors.x3();

        uint256 g0 = gasleft();
        for (uint256 i; i < n; ) {
            a = MNT6Fq3.sqr(a);
            unchecked { ++i; }
        }
        uint256 used = g0 - gasleft();

        vm.pauseGasMetering();
        _logBench("mnt6 Fq3 sqr", used, n);
        emit log_named_uint("mnt6 Fq3 sqr gas/op minus loop overhead", (used - overhead) / n);
        vm.resumeGasMetering();
        assertTrue(!MNT6Fq3.eq(a, MNT6Fq3.zero()));
    }

    function testGasBench_mnt6Fq6Mul() public {
        uint256 n = 64;
        uint256 overhead = _benchLoopOverhead(n);
        MNT6PairingTypes.Fq6 memory a = MNT6TestVectors.z6();
        MNT6PairingTypes.Fq6 memory b = MNT6TestVectors.w6();

        uint256 g0 = gasleft();
        for (uint256 i; i < n; ) {
            a = MNT6Fq6.mul(a, b);
            unchecked { ++i; }
        }
        uint256 used = g0 - gasleft();

        vm.pauseGasMetering();
        _logBench("mnt6 Fq6 mul", used, n);
        emit log_named_uint("mnt6 Fq6 mul gas/op minus loop overhead", (used - overhead) / n);
        vm.resumeGasMetering();
        assertTrue(!MNT6Fq6.eq(a, MNT6Fq6.zero()));
    }

    function testGasBench_mnt6Fq6Sqr() public {
        uint256 n = 64;
        uint256 overhead = _benchLoopOverhead(n);
        MNT6PairingTypes.Fq6 memory a = MNT6TestVectors.z6();

        uint256 g0 = gasleft();
        for (uint256 i; i < n; ) {
            a = MNT6Fq6.sqr(a);
            unchecked { ++i; }
        }
        uint256 used = g0 - gasleft();

        vm.pauseGasMetering();
        _logBench("mnt6 Fq6 sqr", used, n);
        emit log_named_uint("mnt6 Fq6 sqr gas/op minus loop overhead", (used - overhead) / n);
        vm.resumeGasMetering();
        assertTrue(!MNT6Fq6.eq(a, MNT6Fq6.zero()));
    }
}
