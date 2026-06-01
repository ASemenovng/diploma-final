// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import "forge-std/Test.sol";
import "../src/FieldMul3Modexp.sol";

contract FieldMul3ModexpCorrectnessTest is Test {
    uint256 constant P0 = 0x685acce9767254a4638810719ac425f0e39d54522cdd119f5e9063de245e8001;
    uint256 constant P1 = 0x7fdb925e8a0ed8d99d124d9a15af79db117e776f218059db80f0da5cb537e38;
    uint256 constant P2 = 0x01c4c62d92c41110229022eee2cdadb7f997505b8fafed5eb7e8f96c97d873;

    function _refMul(
        uint256 a0, uint256 a1, uint256 a2,
        uint256 b0, uint256 b1, uint256 b2
    ) internal returns (uint256 e0, uint256 e1, uint256 e2) {
        string[] memory cmd = new string[](8);
        cmd[0] = "python3";
        cmd[1] = "scripts/ref_mul.py";
        cmd[2] = vm.toString(a0);
        cmd[3] = vm.toString(a1);
        cmd[4] = vm.toString(a2);
        cmd[5] = vm.toString(b0);
        cmd[6] = vm.toString(b1);
        cmd[7] = vm.toString(b2);
        bytes memory out = vm.ffi(cmd);
        require(out.length == 96, "ffi len");
        assembly {
            e2 := mload(add(out, 0x20))
            e1 := mload(add(out, 0x40))
            e0 := mload(add(out, 0x60))
        }
    }

    function _check(
        uint256 a0, uint256 a1, uint256 a2,
        uint256 b0, uint256 b1, uint256 b2
    ) internal {
        (uint256 r0, uint256 r1, uint256 r2) = FieldMul3Modexp.mulMod3(a0, a1, a2, b0, b1, b2);
        (uint256 e0, uint256 e1, uint256 e2) = _refMul(a0, a1, a2, b0, b1, b2);
        assertEq(r0, e0, "r0");
        assertEq(r1, e1, "r1");
        assertEq(r2, e2, "r2");
        bool reduced = r2 < P2 || (r2 == P2 && (r1 < P1 || (r1 == P1 && r0 < P0)));
        assertTrue(reduced, "r >= p");
    }

    function test_ZeroTimesZero() public {
        _check(0, 0, 0, 0, 0, 0);
    }

    function test_ZeroTimesX() public {
        _check(0, 0, 0, 123, 456, 7);
    }

    function test_OneTimesX() public {
        _check(1, 0, 0, 0x1234, 0x5678, 0x9a);
    }

    function test_PMinusOneSquared() public {
        _check(P0 - 1, P1, P2, P0 - 1, P1, P2);
    }

    function test_HighWords() public {
        _check(type(uint256).max, type(uint256).max, P2 - 1,
               type(uint256).max, type(uint256).max, P2 - 1);
    }

    function test_SquareMatchesPython() public {
        uint256 a0 = 0xfedcba98765432100123456789abcdef00112233445566778899aabbccddeeff;
        uint256 a1 = 0x0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef;
        uint256 a2 = 0x01a4c62d92c41110229022eee2cdadb7f997505b8fafed5eb7e8f96c97d870;
        (uint256 r0, uint256 r1, uint256 r2) = FieldMul3Modexp.sqrMod3(a0, a1, a2);
        (uint256 e0, uint256 e1, uint256 e2) = _refMul(a0, a1, a2, a0, a1, a2);
        assertEq(r0, e0, "square r0");
        assertEq(r1, e1, "square r1");
        assertEq(r2, e2, "square r2");
    }

    function test_Random64AgainstPython() public {
        uint256 seed = 0xC0FFEE;
        for (uint256 i = 0; i < 64; i++) {
            uint256 a0 = uint256(keccak256(abi.encode(seed, i, 0)));
            uint256 a1 = uint256(keccak256(abi.encode(seed, i, 1)));
            uint256 a2 = uint256(keccak256(abi.encode(seed, i, 2))) % P2;
            uint256 b0 = uint256(keccak256(abi.encode(seed, i, 3)));
            uint256 b1 = uint256(keccak256(abi.encode(seed, i, 4)));
            uint256 b2 = uint256(keccak256(abi.encode(seed, i, 5))) % P2;
            _check(a0, a1, a2, b0, b1, b2);
        }
    }

    function test_Random5000AgainstPython() public {
        uint256 seed = 0xC0FFEE;
        for (uint256 i = 0; i < 5000; i++) {
            uint256 a0 = uint256(keccak256(abi.encode(seed, i, 0)));
            uint256 a1 = uint256(keccak256(abi.encode(seed, i, 1)));
            uint256 a2 = uint256(keccak256(abi.encode(seed, i, 2))) % P2;
            uint256 b0 = uint256(keccak256(abi.encode(seed, i, 3)));
            uint256 b1 = uint256(keccak256(abi.encode(seed, i, 4)));
            uint256 b2 = uint256(keccak256(abi.encode(seed, i, 5))) % P2;
            _check(a0, a1, a2, b0, b1, b2);
        }
    }
}
