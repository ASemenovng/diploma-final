// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import "forge-std/Test.sol";
import "../src/FieldMul3.sol";

/// @notice Буквальное воспроизведение benchmark-а, присланного Claude.
contract BenchClaudeExact is Test {
    function test_Gas() public {
        uint256 N = 2048;
        uint256 a0=0x123; uint256 a1=0x456; uint256 a2=0x7;
        uint256 b0=0x89a; uint256 b1=0xbcd; uint256 b2=0x3;
        (uint256 r0,uint256 r1,uint256 r2)=(a0,a1,a2);
        uint256 g0 = gasleft();
        for (uint256 i=0;i<N;i++){
            (r0,r1,r2)=FieldMul3.mulMod3(r0,r1,r2,b0,b1,b2);
        }
        uint256 used = g0 - gasleft();
        emit log_named_uint("totalGas", used);
        emit log_named_uint("gasPerOperation", used / N);
        require((r0|r1|r2) != type(uint256).max, "noop");
    }
}
