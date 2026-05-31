// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Test} from "forge-std/Test.sol";
import {MNT6PairingTypes} from "../src/MNT6PairingTypes.sol";
import {MNT6Fq3} from "../src/MNT6Fq3.sol";
import {MNT6Fq6} from "../src/MNT6Fq6.sol";
import {MNT6PackedArithmetic} from "../src/MNT6PackedArithmetic.sol";
import {MNT6TestVectors} from "./MNT6TestVectors.sol";

contract MNT6PackedArithmeticHarness {
    function fq3Mul(MNT6PairingTypes.Fq3 memory a, MNT6PairingTypes.Fq3 memory b)
        external
        pure
        returns (MNT6PairingTypes.Fq3 memory)
    {
        uint256 base = MNT6PackedArithmetic.arenaPtr(64);
        uint256 aPtr = base;
        uint256 bPtr = base + 0x120;
        uint256 out = base + 2 * 0x120;
        uint256 scratch = base + 3 * 0x120;
        MNT6PackedArithmetic.fq3StoreTo(aPtr, a);
        MNT6PackedArithmetic.fq3StoreTo(bPtr, b);
        MNT6PackedArithmetic.fq3MulTo(out, aPtr, bPtr, scratch);
        return MNT6PackedArithmetic.fq3Load(out);
    }

    function fq3Sqr(MNT6PairingTypes.Fq3 memory a) external pure returns (MNT6PairingTypes.Fq3 memory) {
        uint256 base = MNT6PackedArithmetic.arenaPtr(48);
        uint256 aPtr = base;
        uint256 out = base + 0x120;
        uint256 scratch = base + 2 * 0x120;
        MNT6PackedArithmetic.fq3StoreTo(aPtr, a);
        MNT6PackedArithmetic.fq3SqrTo(out, aPtr, scratch);
        return MNT6PackedArithmetic.fq3Load(out);
    }

    function fq6Mul(MNT6PairingTypes.Fq6 memory a, MNT6PairingTypes.Fq6 memory b)
        external
        pure
        returns (MNT6PairingTypes.Fq6 memory)
    {
        uint256 base = MNT6PackedArithmetic.arenaPtr(128);
        uint256 aPtr = base;
        uint256 bPtr = base + 0x240;
        uint256 out = base + 2 * 0x240;
        uint256 scratch = base + 3 * 0x240;
        MNT6PackedArithmetic.fq6CopyTo(aPtr, _storeFq6(base + 5 * 0x240, a));
        MNT6PackedArithmetic.fq6CopyTo(bPtr, _storeFq6(base + 6 * 0x240, b));
        MNT6PackedArithmetic.fq6MulTo(out, aPtr, bPtr, scratch);
        return MNT6PackedArithmetic.fq6Load(out);
    }

    function fq6Sqr(MNT6PairingTypes.Fq6 memory a) external pure returns (MNT6PairingTypes.Fq6 memory) {
        uint256 base = MNT6PackedArithmetic.arenaPtr(128);
        uint256 aPtr = base;
        uint256 out = base + 0x240;
        uint256 scratch = base + 2 * 0x240;
        MNT6PackedArithmetic.fq6CopyTo(aPtr, _storeFq6(base + 5 * 0x240, a));
        MNT6PackedArithmetic.fq6SqrTo(out, aPtr, scratch);
        return MNT6PackedArithmetic.fq6Load(out);
    }

    function _storeFq6(uint256 ptr, MNT6PairingTypes.Fq6 memory x) private pure returns (uint256) {
        MNT6PackedArithmetic.fq3StoreTo(ptr, x.c0);
        MNT6PackedArithmetic.fq3StoreTo(ptr + 0x120, x.c1);
        return ptr;
    }
}

contract MNT6PackedArithmeticTest is Test {
    function testPackedFq3ArithmeticMatchesStructPath() public {
        MNT6PackedArithmeticHarness h = new MNT6PackedArithmeticHarness();
        MNT6PairingTypes.Fq3 memory x = MNT6TestVectors.x3();
        MNT6PairingTypes.Fq3 memory y = MNT6TestVectors.y3();
        assertTrue(MNT6Fq3.eq(h.fq3Mul(x, y), MNT6Fq3.mul(x, y)), "packed fq3 mul");
        assertTrue(MNT6Fq3.eq(h.fq3Sqr(x), MNT6Fq3.sqr(x)), "packed fq3 sqr");
    }

    function testPackedFq6ArithmeticMatchesStructPath() public {
        MNT6PackedArithmeticHarness h = new MNT6PackedArithmeticHarness();
        MNT6PairingTypes.Fq6 memory z = MNT6TestVectors.z6();
        MNT6PairingTypes.Fq6 memory w = MNT6TestVectors.w6();
        assertTrue(MNT6Fq6.eq(h.fq6Mul(z, w), MNT6Fq6.mul(z, w)), "packed fq6 mul");
        assertTrue(MNT6Fq6.eq(h.fq6Sqr(z), MNT6Fq6.sqr(z)), "packed fq6 sqr");
    }
}
