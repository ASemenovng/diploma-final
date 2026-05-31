// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {Test} from "forge-std/Test.sol";
import {Lollipop305Article640Verifier} from "../src/Lollipop305Article640Verifier.sol";

contract Lollipop305EhatWeilVerifierTest is Test {
    Lollipop305Article640Verifier private verifier;
    bytes private fP_Q;
    bytes private fNegP_Q;
    bytes private fQ_P;
    bytes private fQ_NegP;
    uint256[12] private lhs;
    uint256[12] private rhs;

    function setUp() public {
        verifier = new Lollipop305Article640Verifier();
        bytes memory data = vm.readFileBinary("docs/lollipop305_cycle_ehat_weil_fixture.words.bin");
        uint256 o;
        (fP_Q, o) = _readTrace(data, o);
        (fNegP_Q, o) = _readTrace(data, o);
        (fQ_P, o) = _readTrace(data, o);
        (fQ_NegP, o) = _readTrace(data, o);
        lhs = _readFq6(data, o);
        rhs = _readFq6(data, o + 12 * 32);
        assertEq(lhs[0], rhs[0], "fixture lhs/rhs mismatch");
    }

    function testEhatWeilEquationAcceptsRustFixture() public view {
        assertTrue(verifier.verifyEhatWeilEquation(fP_Q, fNegP_Q, fQ_P, fQ_NegP));
    }

    function testEhatWeilEquationRejectsTamperedLine() public view {
        bytes memory bad = fP_Q;
        bad[96] = bytes1(uint8(bad[96]) ^ 1);
        assertFalse(verifier.verifyEhatWeilEquation(bad, fNegP_Q, fQ_P, fQ_NegP));
    }

    function testGasReport_ehatWeilEquation() public view {
        verifier.verifyEhatWeilEquation(fP_Q, fNegP_Q, fQ_P, fQ_NegP);
    }

    function _readTrace(bytes memory data, uint256 o) private pure returns (bytes memory trace, uint256 next) {
        uint256 steps = _word(data, o);
        uint256 len = steps * 13 * 32;
        trace = _slice(data, o + 32, len);
        next = o + 32 + len;
    }

    function _readFq6(bytes memory data, uint256 o) private pure returns (uint256[12] memory out) {
        for (uint256 i; i < 12; ++i) out[i] = _word(data, o + i * 32);
    }

    function _word(bytes memory data, uint256 offset) private pure returns (uint256 value) {
        assembly ("memory-safe") { value := mload(add(add(data, 0x20), offset)) }
    }

    function _slice(bytes memory data, uint256 start, uint256 len) private pure returns (bytes memory out) {
        out = new bytes(len);
        for (uint256 i; i < len; ++i) out[i] = data[start + i];
    }
}
