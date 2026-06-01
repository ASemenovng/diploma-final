// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

/// @notice Fiat--Shamir transcript, байт-в-байт совпадающий с Rust backend.
library MNT4DeepFriTranscript {
    struct State {
        bytes32 digest;
    }

    function init() internal pure returns (State memory state) {
        state.digest = keccak256("MNT4-MICROTRACE-DEEP-FRI-V1");
    }

    function absorb(State memory state, string memory label, bytes memory payload) internal pure {
        bytes memory labelBytes = bytes(label);
        state.digest = keccak256(
            abi.encodePacked(bytes1(0xA0), state.digest, uint16(labelBytes.length), labelBytes, uint32(payload.length), payload)
        );
    }

    function challenge(State memory state, string memory label, uint32 counter) internal pure returns (bytes32) {
        bytes memory labelBytes = bytes(label);
        return keccak256(abi.encodePacked(bytes1(0xC0), state.digest, uint16(labelBytes.length), labelBytes, counter));
    }
}

