// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import "forge-std/Test.sol";
import "../src/FieldMul3Modexp.sol";

contract BenchModexpSmall is Test {
    function test_GasSmall() public {
        uint256 n = 2048;
        uint256 r0 = 0x123;
        uint256 r1 = 0x456;
        uint256 r2 = 0x7;
        uint256 b0 = 0x89abcdef;
        uint256 b1 = 0xfedcba98;
        uint256 b2 = 0x3;
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
