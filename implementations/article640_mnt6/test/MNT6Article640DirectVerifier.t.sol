// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Test} from "forge-std/Test.sol";
import {MNT6PairingTypes} from "@arith-mnt6/MNT6PairingTypes.sol";
import {MNT6Fp} from "@arith-mnt6/MNT6Fp.sol";
import {MNT6Article640DirectVerifier} from "../src/MNT6Article640DirectVerifier.sol";
import {MNT6ResidueVectors} from "./MNT6ResidueVectors.sol";

contract MNT6Article640DirectVerifierTest is Test {
    function testResidueRelationAcceptsArkworksVector() public {
        MNT6Article640DirectVerifier verifier = new MNT6Article640DirectVerifier();
        assertTrue(verifier.verifyResidueRelation(MNT6ResidueVectors.cPowR(), MNT6ResidueVectors.c(), MNT6ResidueVectors.cInv()));
    }

    function testResidueRelationRejectsTamperedC() public {
        MNT6Article640DirectVerifier verifier = new MNT6Article640DirectVerifier();
        MNT6PairingTypes.Fq6 memory badC = MNT6ResidueVectors.c();
        badC.c0.c0 = MNT6Fp.add(badC.c0.c0, MNT6Fp.one());
        assertFalse(verifier.verifyResidueRelation(MNT6ResidueVectors.cPowR(), badC, MNT6ResidueVectors.cInv()));
    }
}
