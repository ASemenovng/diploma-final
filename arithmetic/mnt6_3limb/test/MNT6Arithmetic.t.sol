// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Test} from "forge-std/Test.sol";
import {MNT6PairingTypes} from "../src/MNT6PairingTypes.sol";
import {MNT6Fp} from "../src/MNT6Fp.sol";
import {MNT6Fq3} from "../src/MNT6Fq3.sol";
import {MNT6Fq6} from "../src/MNT6Fq6.sol";
import {MNT6CurveChecks} from "../src/MNT6CurveChecks.sol";
import {MNT6AteLoop} from "../src/MNT6AteLoop.sol";
import {MNT6MillerStepVectors} from "./MNT6MillerStepVectors.sol";
import {MNT6TestVectors} from "./MNT6TestVectors.sol";

contract MNT6ArithmeticTest is Test {
    function testFpArithmeticMatchesArkworks() public pure {
        MNT6PairingTypes.Fp memory a = MNT6TestVectors.a();
        MNT6PairingTypes.Fp memory b = MNT6TestVectors.b();
        assertTrue(MNT6Fp.eq(MNT6Fp.add(a, b), MNT6TestVectors.aPlusB()), "add");
        assertTrue(MNT6Fp.eq(MNT6Fp.sub(a, b), MNT6TestVectors.aMinusB()), "sub");
        assertTrue(MNT6Fp.eq(MNT6Fp.mul(a, b), MNT6TestVectors.aMulB()), "mul");
        assertTrue(MNT6Fp.eq(MNT6Fp.sqr(a), MNT6TestVectors.aSqr()), "sqr");
        assertTrue(MNT6Fp.eq(MNT6Fp.inv(a), MNT6TestVectors.aInv()), "inv");
        assertTrue(MNT6Fp.eq(MNT6Fp.mulBy11(a), MNT6TestVectors.aMul11()), "mulBy11");
        assertTrue(MNT6Fp.eq(MNT6Fp.mul(a, MNT6Fp.inv(a)), MNT6Fp.one()), "a * inv(a)");
    }

    function testFq3ArithmeticMatchesArkworks() public pure {
        MNT6PairingTypes.Fq3 memory x = MNT6TestVectors.x3();
        MNT6PairingTypes.Fq3 memory y = MNT6TestVectors.y3();
        assertTrue(MNT6Fq3.eq(MNT6Fq3.mul(x, y), MNT6TestVectors.x3MulY3()), "fq3 mul");
        assertTrue(MNT6Fq3.eq(MNT6Fq3.sqr(x), MNT6TestVectors.x3Sqr()), "fq3 sqr");
        assertTrue(MNT6Fq3.eq(MNT6Fq3.mul(x, MNT6Fq3.inv(x)), MNT6Fq3.one()), "fq3 inv");
    }

    function testCurveGeneratorsAreOnCurve() public pure {
        assertTrue(MNT6CurveChecks.isOnG1(MNT6TestVectors.g1Generator()), "g1 generator");
        assertTrue(MNT6CurveChecks.isOnG2(MNT6TestVectors.g2Generator()), "g2 generator");

        MNT6PairingTypes.G1Point memory badG1 = MNT6TestVectors.g1Generator();
        badG1.y = MNT6Fp.add(badG1.y, MNT6Fp.one());
        assertFalse(MNT6CurveChecks.isOnG1(badG1), "bad g1 rejected");

        MNT6PairingTypes.G2Point memory badG2 = MNT6TestVectors.g2Generator();
        badG2.y.c0 = MNT6Fp.add(badG2.y.c0, MNT6Fp.one());
        assertFalse(MNT6CurveChecks.isOnG2(badG2), "bad g2 rejected");
    }


    function testFirstMillerDoubleStepMatchesArkworks() public pure {
        MNT6AteLoop.DoubleCoeff[] memory doubles = new MNT6AteLoop.DoubleCoeff[](1);
        doubles[0] = MNT6MillerStepVectors.double0();
        MNT6AteLoop.AddCoeff[] memory adds = new MNT6AteLoop.AddCoeff[](0);
        MNT6PairingTypes.Fq6 memory out = MNT6AteLoop.millerLoopPrepared(
            MNT6TestVectors.g1Generator(),
            MNT6MillerStepVectors.qXOverTwist(),
            MNT6MillerStepVectors.qYOverTwist(),
            doubles,
            adds
        );
        assertTrue(MNT6Fq6.eq(out, MNT6MillerStepVectors.afterDouble0()), "first miller double");
    }

    function testFq6ArithmeticMatchesArkworks() public pure {
        MNT6PairingTypes.Fq6 memory z = MNT6TestVectors.z6();
        MNT6PairingTypes.Fq6 memory w = MNT6TestVectors.w6();
        assertTrue(MNT6Fq6.eq(MNT6Fq6.mul(z, w), MNT6TestVectors.z6MulW6()), "fq6 mul");
        assertTrue(MNT6Fq6.eq(MNT6Fq6.sqr(z), MNT6TestVectors.z6Sqr()), "fq6 sqr");
        assertTrue(MNT6Fq6.eq(MNT6Fq6.mul(z, MNT6Fq6.inv(z)), MNT6Fq6.one()), "fq6 inv");
    }
}
