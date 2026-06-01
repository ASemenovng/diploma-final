// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Test, stdJson} from "forge-std/Test.sol";
import {MNT6PairingTypes} from "@arith-mnt6/MNT6PairingTypes.sol";
import {MNT6Article640FixedShardsVerifier} from "../src/MNT6Article640FixedShardsVerifier.sol";

/// @notice Минимальный data-контракт: его runtime-кодом становится переданный фрагмент prepared-кэша.
contract MNT6CodeShardStore {
    constructor(bytes memory blob) payable {
        assembly ("memory-safe") {
            return(add(blob, 0x20), mload(blob))
        }
    }
}

contract MNT6Article640FixedShardsVerifierTest is Test {
    using stdJson for string;

    MNT6Article640FixedShardsVerifier private verifier;
    MNT6PairingTypes.G1Point private p;
    MNT6PairingTypes.G1Point private r;

    function setUp() public {
        string memory json = vm.readFile("fixtures/mnt6_fixture.json");
        p = _readG1(json, ".equation.p");
        r = _readG1(json, ".equation.r");

        verifier = new MNT6Article640FixedShardsVerifier(
            _readFq3(json, ".equation.q_x_over_twist"),
            _readFq3(json, ".equation.q_y_over_twist"),
            _readFq3(json, ".equation.s_x_over_twist"),
            _readFq3(json, ".equation.s_y_over_twist"),
            _deployCodeShards(json.readBytes(".equation.q_dbl_blob")),
            _deployCodeShards(json.readBytes(".equation.q_add_blob")),
            _deployCodeShards(json.readBytes(".equation.s_dbl_blob")),
            _deployCodeShards(json.readBytes(".equation.s_add_blob"))
        );
    }

    function testAcceptsArkworksBilinearEquation() public view {
        assertTrue(verifier.verifyEquationFullFixedShards(p, r));
    }

    function testResidueVerifierAcceptsArkworksBilinearEquation() public view {
        string memory json = vm.readFile("fixtures/mnt6_fixture.json");
        assertTrue(
            verifier.verifyEquationResidueFixedShards(
                p,
                r,
                _readFq6(json, ".equation.residue_c"),
                _readFq6(json, ".equation.residue_c_inv")
            )
        );
    }

    function testResidueVerifierRejectsCorruptedWitness() public view {
        string memory json = vm.readFile("fixtures/mnt6_fixture.json");
        MNT6PairingTypes.Fq6 memory badC = _readFq6(json, ".equation.residue_c");
        badC.c0.c0.d0 ^= 1;
        assertFalse(
            verifier.verifyEquationResidueFixedShards(
                p,
                r,
                badC,
                _readFq6(json, ".equation.residue_c_inv")
            )
        );
    }

    function testResidueVerifierRejectsFalseEquationWithValidPoints() public view {
        string memory json = vm.readFile("fixtures/mnt6_fixture.json");
        assertFalse(
            verifier.verifyEquationResidueFixedShards(
                p,
                p,
                _readFq6(json, ".equation.residue_c"),
                _readFq6(json, ".equation.residue_c_inv")
            )
        );
    }

    function testRejectsPointOutsideG1BeforeMillerLoop() public view {
        MNT6PairingTypes.G1Point memory badP = p;
        badP.x.d0 ^= 1;
        assertFalse(verifier.verifyEquationFullFixedShards(badP, r));
    }

    /// @notice Новый residue API обязан отклонять точку вне G1 до запуска
    ///         дорогостоящего multi-Miller цикла.
    function testResidueVerifierRejectsPointOutsideG1BeforeMillerLoop() public view {
        string memory json = vm.readFile("fixtures/mnt6_fixture.json");
        MNT6PairingTypes.G1Point memory badP = p;
        badP.x.d0 ^= 1;
        assertFalse(
            verifier.verifyEquationResidueFixedShards(
                badP,
                r,
                _readFq6(json, ".equation.residue_c"),
                _readFq6(json, ".equation.residue_c_inv")
            )
        );
    }

    function _deployCodeShards(bytes memory blob) private returns (address[] memory shards) {
        // 0x5e80 = 24192 < EIP-170 limit and is divisible by 288-byte Fq3.
        uint256 chunkBytes = 0x5e80;
        uint256 count = (blob.length + chunkBytes - 1) / chunkBytes;
        shards = new address[](count);
        uint256 off;
        for (uint256 i = 0; i < count; ++i) {
            uint256 len = blob.length - off;
            if (len > chunkBytes) len = chunkBytes;
            require(len % 0x120 == 0, "bad shard alignment");
            bytes memory part = new bytes(len);
            assembly ("memory-safe") {
                let src := add(add(blob, 0x20), off)
                let dst := add(part, 0x20)
                for { let pos := 0 } lt(pos, len) { pos := add(pos, 0x20) } {
                    mstore(add(dst, pos), mload(add(src, pos)))
                }
            }
            shards[i] = address(new MNT6CodeShardStore(part));
            off += len;
        }
        require(off == blob.length, "bad shard split");
    }

    function _readG1(string memory json, string memory path)
        private
        pure
        returns (MNT6PairingTypes.G1Point memory out)
    {
        out.x = _readFp(json, string.concat(path, ".x"));
        out.y = _readFp(json, string.concat(path, ".y"));
    }

    function _readFq3(string memory json, string memory path)
        private
        pure
        returns (MNT6PairingTypes.Fq3 memory out)
    {
        out.c0 = _readFp(json, string.concat(path, ".c0"));
        out.c1 = _readFp(json, string.concat(path, ".c1"));
        out.c2 = _readFp(json, string.concat(path, ".c2"));
    }

    function _readFq6(string memory json, string memory path)
        private
        pure
        returns (MNT6PairingTypes.Fq6 memory out)
    {
        out.c0 = _readFq3(json, string.concat(path, ".c0"));
        out.c1 = _readFq3(json, string.concat(path, ".c1"));
    }

    function _readFp(string memory json, string memory path)
        private
        pure
        returns (MNT6PairingTypes.Fp memory out)
    {
        out.d2 = json.readUint(string.concat(path, ".d2"));
        out.d1 = json.readUint(string.concat(path, ".d1"));
        out.d0 = json.readUint(string.concat(path, ".d0"));
    }
}
