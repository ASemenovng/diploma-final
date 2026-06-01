// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import "forge-std/Test.sol";
import "../src/FieldMul3.sol";

/// @notice Full-width benchmark в отдельном контракте, чтобы компоновка
///         дополнительных тестовых методов не меняла измеряемый bytecode.
contract BenchClaudeFullWidthExact is Test {
    uint256 constant P0 = 0x685acce9767254a4638810719ac425f0e39d54522cdd119f5e9063de245e8001;
    uint256 constant P1 = 0x7fdb925e8a0ed8d99d124d9a15af79db117e776f218059db80f0da5cb537e38;
    uint256 constant P2 = 0x01c4c62d92c41110229022eee2cdadb7f997505b8fafed5eb7e8f96c97d873;

    function test_GasFullWidth() public {
        uint256 N = 2048;
        uint256 a0 = P0 - 0x123456789abcdef0123456789abcdef0;
        uint256 a1 = P1 - 0x11111111111111111111111111111111;
        uint256 a2 = P2 - 0x12345;
        uint256 b0 = P0 - 0x0fedcba9876543210fedcba987654321;
        uint256 b1 = P1 - 0x22222222222222222222222222222222;
        uint256 b2 = P2 - 0x23456;
        (uint256 r0, uint256 r1, uint256 r2) = (a0, a1, a2);
        uint256 g0 = gasleft();
        for (uint256 i = 0; i < N; i++) {
            (r0, r1, r2) = FieldMul3.mulMod3(r0, r1, r2, b0, b1, b2);
        }
        uint256 used = g0 - gasleft();
        emit log_named_uint("totalGas", used);
        emit log_named_uint("gasPerOperation", used / N);
        require((r0 | r1 | r2) != type(uint256).max, "noop");
    }
}
