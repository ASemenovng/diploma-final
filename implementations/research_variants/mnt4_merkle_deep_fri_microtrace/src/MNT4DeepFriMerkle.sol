// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

/// @notice Проверка детерминированного компактного Merkle-multiproof.
/// @dev Позиции листьев не передаются пользователем: основной verifier выводит их из Fiat--Shamir запросов.
library MNT4DeepFriMerkle {
    /// @dev Один multiproof хранит отсортированные позиции раскрываемых листьев,
    ///      их payload и минимальный frontier из недостающих соседних хешей.
    struct Section {
        uint256[] positions;
        bytes[] payloads;
        bytes32[] frontier;
    }

    function verify(uint8 tag, bytes32 expectedRoot, uint256 leafCount, Section memory section)
        internal
        pure
        returns (bool)
    {
        // На каждом уровне уже раскрытые соседние листья объединяются без
        // повторной передачи. Для отсутствующего соседа расходуется один
        // очередной элемент frontier. В конце не должно остаться лишних хешей.
        if (section.positions.length != section.payloads.length || leafCount == 0 || leafCount & (leafCount - 1) != 0) return false;
        uint256 length = section.positions.length;
        uint256[] memory indexes = new uint256[](length);
        bytes32[] memory hashes = new bytes32[](length);
        for (uint256 i; i < length; ++i) {
            if (section.positions[i] >= leafCount || (i != 0 && section.positions[i - 1] >= section.positions[i])) return false;
            indexes[i] = section.positions[i];
            hashes[i] = hashLeaf(tag, section.positions[i], section.payloads[i]);
        }
        uint256 frontierOffset;
        uint8 level;
        uint256 width = leafCount;
        while (width > 1) {
            uint256[] memory nextIndexes = new uint256[](length);
            bytes32[] memory nextHashes = new bytes32[](length);
            uint256 nextLength;
            for (uint256 i; i < length; ++i) {
                uint256 index = indexes[i];
                if (index & 1 == 1 && i != 0 && indexes[i - 1] == (index ^ 1)) continue;
                uint256 sibling = index ^ 1;
                bytes32 siblingHash;
                if (i + 1 < length && indexes[i + 1] == sibling) {
                    siblingHash = hashes[i + 1];
                } else {
                    if (frontierOffset == section.frontier.length) return false;
                    siblingHash = section.frontier[frontierOffset++];
                }
                bytes32 parent = index & 1 == 0
                    ? hashNode(tag, level, hashes[i], siblingHash)
                    : hashNode(tag, level, siblingHash, hashes[i]);
                uint256 parentIndex = index >> 1;
                if (nextLength == 0 || nextIndexes[nextLength - 1] != parentIndex) {
                    nextIndexes[nextLength] = parentIndex;
                    nextHashes[nextLength] = parent;
                    ++nextLength;
                } else if (nextHashes[nextLength - 1] != parent) {
                    return false;
                }
            }
            indexes = nextIndexes;
            hashes = nextHashes;
            length = nextLength;
            width >>= 1;
            ++level;
        }
        return frontierOffset == section.frontier.length && length == 1 && indexes[0] == 0 && hashes[0] == expectedRoot;
    }

    function hashLeaf(uint8 tag, uint256 index, bytes memory payload) internal pure returns (bytes32) {
        // Префикс 0x00 отделяет лист от внутреннего узла; tag отделяет таблицы.
        return keccak256(abi.encodePacked(bytes1(0x00), tag, uint32(index), uint32(payload.length), payload));
    }

    function hashNode(uint8 tag, uint8 level, bytes32 left, bytes32 right) internal pure returns (bytes32) {
        // Уровень включен в хеш, чтобы исключить неоднозначность структуры.
        return keccak256(abi.encodePacked(bytes1(0x01), tag, level, left, right));
    }
}
