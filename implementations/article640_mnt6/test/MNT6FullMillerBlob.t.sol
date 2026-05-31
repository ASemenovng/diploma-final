// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Test, stdJson} from "forge-std/Test.sol";
import {MNT6PairingTypes} from "@arith-mnt6/MNT6PairingTypes.sol";
import {MNT6Fq6} from "@arith-mnt6/MNT6Fq6.sol";
import {MNT6Article640DirectVerifier} from "../src/MNT6Article640DirectVerifier.sol";
import {MNT6MillerStepVectors} from "./MNT6MillerStepVectors.sol";
import {MNT6ResidueVectors} from "./MNT6ResidueVectors.sol";
import {MNT6TestVectors} from "./MNT6TestVectors.sol";

contract MNT6FullMillerBlobTest is Test {
    using stdJson for string;

    // Diagnostic-only path: the uncompressed full blob loop costs about 1B gas
    // and intentionally stays outside the default Foundry test set.
    function disabledFullPreparedBlobMillerLoopMatchesArkworks() public {
        string memory json = vm.readFile("fixtures/mnt6_fixture.json");
        bytes memory dblBlobMemory = json.readBytes(".prepared.dbl_blob");
        bytes memory addBlobMemory = json.readBytes(".prepared.add_blob");
        bytes memory fullMillerBlob = json.readBytes(".prepared.full_miller_blob");

        MNT6Article640DirectVerifier verifier = new MNT6Article640DirectVerifier();
        MNT6PairingTypes.Fq6 memory out = verifier.millerLoopPreparedBlob(
            MNT6TestVectors.g1Generator(),
            MNT6MillerStepVectors.qXOverTwist(),
            MNT6MillerStepVectors.qYOverTwist(),
            dblBlobMemory,
            addBlobMemory
        );

        assertTrue(MNT6Fq6.eq(out, _loadFq6(fullMillerBlob, 0)), "full MNT6 Miller output");
    }

    function disabledFullPreparedMemoryBlobMillerLoopMatchesArkworks() public {
        string memory json = vm.readFile("fixtures/mnt6_fixture.json");
        bytes memory dblBlobMemory = json.readBytes(".prepared.dbl_blob");
        bytes memory addBlobMemory = json.readBytes(".prepared.add_blob");
        bytes memory fullMillerBlob = json.readBytes(".prepared.full_miller_blob");

        MNT6Article640DirectVerifier verifier = new MNT6Article640DirectVerifier();
        MNT6PairingTypes.Fq6 memory out = verifier.millerLoopPreparedMemoryBlob(
            MNT6TestVectors.g1Generator(),
            MNT6MillerStepVectors.qXOverTwist(),
            MNT6MillerStepVectors.qYOverTwist(),
            dblBlobMemory,
            addBlobMemory
        );

        assertTrue(MNT6Fq6.eq(out, _loadFq6(fullMillerBlob, 0)), "full MNT6 Miller output via memory blob");
    }

    function disabledFullPreparedCodeBlobMillerLoopMatchesArkworks() public {
        string memory json = vm.readFile("fixtures/mnt6_fixture.json");
        bytes memory dblBlobMemory = json.readBytes(".prepared.dbl_blob");
        bytes memory addBlobMemory = json.readBytes(".prepared.add_blob");
        bytes memory fullMillerBlob = json.readBytes(".prepared.full_miller_blob");
        address dblData = address(0xD606);
        address addData = address(0xA606);
        vm.etch(dblData, dblBlobMemory);
        vm.etch(addData, addBlobMemory);

        MNT6Article640DirectVerifier verifier = new MNT6Article640DirectVerifier();
        MNT6PairingTypes.Fq6 memory out = verifier.millerLoopPreparedCodeBlob(
            MNT6TestVectors.g1Generator(),
            MNT6MillerStepVectors.qXOverTwist(),
            MNT6MillerStepVectors.qYOverTwist(),
            dblData,
            dblBlobMemory.length,
            addData,
            addBlobMemory.length
        );

        assertTrue(MNT6Fq6.eq(out, _loadFq6(fullMillerBlob, 0)), "full MNT6 Miller output via code blob");
    }

    function disabledFullPreparedStreamingCodeBlobDigestMatchesCalldataBlob() public {
        string memory json = vm.readFile("fixtures/mnt6_fixture.json");
        bytes memory dblBlobMemory = json.readBytes(".prepared.dbl_blob");
        bytes memory addBlobMemory = json.readBytes(".prepared.add_blob");
        address dblData = address(0xD607);
        address addData = address(0xA607);
        vm.etch(dblData, dblBlobMemory);
        vm.etch(addData, addBlobMemory);

        MNT6Article640DirectVerifier verifier = new MNT6Article640DirectVerifier();
        bytes32 calldataDigest = verifier.millerLoopPreparedBlobDigest(
            MNT6TestVectors.g1Generator(),
            MNT6MillerStepVectors.qXOverTwist(),
            MNT6MillerStepVectors.qYOverTwist(),
            dblBlobMemory,
            addBlobMemory
        );
        bytes32 streamingDigest = verifier.millerLoopPreparedStreamingCodeBlobDigest(
            MNT6TestVectors.g1Generator(),
            MNT6MillerStepVectors.qXOverTwist(),
            MNT6MillerStepVectors.qYOverTwist(),
            dblData,
            dblBlobMemory.length,
            addData,
            addBlobMemory.length
        );

        assertEq(streamingDigest, calldataDigest, "streaming code blob digest");
    }

    function disabledFullPreparedPackedBlobDigestMatchesCalldataBlob() public {
        string memory json = vm.readFile("fixtures/mnt6_fixture.json");
        bytes memory dblBlobMemory = json.readBytes(".prepared.dbl_blob");
        bytes memory addBlobMemory = json.readBytes(".prepared.add_blob");

        MNT6Article640DirectVerifier verifier = new MNT6Article640DirectVerifier();
        bytes32 calldataDigest = verifier.millerLoopPreparedBlobDigest(
            MNT6TestVectors.g1Generator(),
            MNT6MillerStepVectors.qXOverTwist(),
            MNT6MillerStepVectors.qYOverTwist(),
            dblBlobMemory,
            addBlobMemory
        );
        bytes32 packedDigest = verifier.millerLoopPreparedPackedBlobDigest(
            MNT6TestVectors.g1Generator(),
            MNT6MillerStepVectors.qXOverTwist(),
            MNT6MillerStepVectors.qYOverTwist(),
            dblBlobMemory,
            addBlobMemory
        );

        assertEq(packedDigest, calldataDigest, "packed blob digest");
    }

    function testFinalExponentiationMatchesArkworks() public {
        string memory json = vm.readFile("fixtures/mnt6_fixture.json");
        bytes memory fullMillerBlob = json.readBytes(".prepared.full_miller_blob");
        bytes memory finalExpBlob = json.readBytes(".prepared.final_exp_blob");

        MNT6Article640DirectVerifier verifier = new MNT6Article640DirectVerifier();
        bytes32 actual = verifier.finalExponentiationDigest(_loadFq6(fullMillerBlob, 0));
        bytes32 expected = verifier.hashFq6(_loadFq6(finalExpBlob, 0));

        assertEq(actual, expected, "MNT6 final exponentiation");
    }

    function testPackedFinalExponentiationMatchesArkworks() public {
        string memory json = vm.readFile("fixtures/mnt6_fixture.json");
        bytes memory fullMillerBlob = json.readBytes(".prepared.full_miller_blob");
        bytes memory finalExpBlob = json.readBytes(".prepared.final_exp_blob");

        MNT6Article640DirectVerifier verifier = new MNT6Article640DirectVerifier();
        bytes32 actual = verifier.finalExponentiationPackedDigest(_loadFq6(fullMillerBlob, 0));
        bytes32 expected = verifier.hashFq6(_loadFq6(finalExpBlob, 0));

        assertEq(actual, expected, "MNT6 packed final exponentiation");
    }

    function testPackedFullPairingDigestMatchesArkworks() public {
        string memory json = vm.readFile("fixtures/mnt6_fixture.json");
        bytes memory dblBlobMemory = json.readBytes(".prepared.dbl_blob");
        bytes memory addBlobMemory = json.readBytes(".prepared.add_blob");
        bytes memory finalExpBlob = json.readBytes(".prepared.final_exp_blob");

        MNT6Article640DirectVerifier verifier = new MNT6Article640DirectVerifier();
        bytes32 actual = verifier.pairingPreparedPackedFullDigest(
            MNT6TestVectors.g1Generator(),
            MNT6MillerStepVectors.qXOverTwist(),
            MNT6MillerStepVectors.qYOverTwist(),
            dblBlobMemory,
            addBlobMemory
        );
        bytes32 expected = verifier.hashFq6(_loadFq6(finalExpBlob, 0));

        assertEq(actual, expected, "packed full pairing digest");
    }

    function testPackedFullPairingDigestWithPackedFEMatchesArkworks() public {
        string memory json = vm.readFile("fixtures/mnt6_fixture.json");
        bytes memory dblBlobMemory = json.readBytes(".prepared.dbl_blob");
        bytes memory addBlobMemory = json.readBytes(".prepared.add_blob");
        bytes memory finalExpBlob = json.readBytes(".prepared.final_exp_blob");

        MNT6Article640DirectVerifier verifier = new MNT6Article640DirectVerifier();
        bytes32 actual = verifier.pairingPreparedPackedFullDigestWithPackedFE(
            MNT6TestVectors.g1Generator(),
            MNT6MillerStepVectors.qXOverTwist(),
            MNT6MillerStepVectors.qYOverTwist(),
            dblBlobMemory,
            addBlobMemory
        );
        bytes32 expected = verifier.hashFq6(_loadFq6(finalExpBlob, 0));

        assertEq(actual, expected, "packed full pairing with packed FE digest");
    }

    function testPackedResiduePathRunsWithValidInverseWitness() public {
        string memory json = vm.readFile("fixtures/mnt6_fixture.json");
        bytes memory dblBlobMemory = json.readBytes(".prepared.dbl_blob");
        bytes memory addBlobMemory = json.readBytes(".prepared.add_blob");

        MNT6Article640DirectVerifier verifier = new MNT6Article640DirectVerifier();
        bytes32 digest = verifier.pairingPreparedPackedResidueDigest(
            MNT6TestVectors.g1Generator(),
            MNT6MillerStepVectors.qXOverTwist(),
            MNT6MillerStepVectors.qYOverTwist(),
            MNT6ResidueVectors.c(),
            MNT6ResidueVectors.cInv(),
            dblBlobMemory,
            addBlobMemory
        );

        assertTrue(digest != bytes32(0), "residue path digest");
    }

    function _loadFq6(bytes memory blob, uint256 off) private pure returns (MNT6PairingTypes.Fq6 memory r) {
        r.c0 = _loadFq3(blob, off);
        r.c1 = _loadFq3(blob, off + 288);
    }

    function _loadFq3(bytes memory blob, uint256 off) private pure returns (MNT6PairingTypes.Fq3 memory r) {
        r.c0 = _loadFp(blob, off);
        r.c1 = _loadFp(blob, off + 96);
        r.c2 = _loadFp(blob, off + 192);
    }

    function _loadFp(bytes memory blob, uint256 off) private pure returns (MNT6PairingTypes.Fp memory r) {
        assembly ("memory-safe") {
            let src := add(add(blob, 0x20), off)
            mstore(r, mload(src))
            mstore(add(r, 0x20), mload(add(src, 0x20)))
            mstore(add(r, 0x40), mload(add(src, 0x40)))
        }
    }
}
