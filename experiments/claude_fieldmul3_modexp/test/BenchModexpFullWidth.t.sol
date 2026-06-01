// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import "forge-std/Test.sol";
import "../src/FieldMul3Modexp.sol";

contract BenchModexpFullWidth is Test {
    function test_GasFullWidth() public {
        uint256 n = 2048;
        uint256 r0 = 0x685acce9767254a4638810719ac425f0e39d54522cdd119f5e9063de245e7ffe;
        uint256 r1 = 0x7fdb925e8a0ed8d99d124d9a15af79db117e776f218059db80f0da5cb537e37;
        uint256 r2 = 0x01c4c62d92c41110229022eee2cdadb7f997505b8fafed5eb7e8f96c97d872;
        uint256 b0 = 0xfedcba98765432100123456789abcdef00112233445566778899aabbccddeeff;
        uint256 b1 = 0x0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef;
        uint256 b2 = 0x01a4c62d92c41110229022eee2cdadb7f997505b8fafed5eb7e8f96c97d870;
        uint256 g0 = gasleft();
        for (uint256 i = 0; i < n; i++) {
            (r0, r1, r2) = FieldMul3Modexp.mulMod3(r0, r1, r2, b0, b1, b2);
        }
        uint256 used = g0 - gasleft();
        emit log_named_uint("totalGas", used);
        emit log_named_uint("gasPerOperation", used / n);
        require(r0 | r1 | r2 != type(uint256).max, "noop");
    }
}
