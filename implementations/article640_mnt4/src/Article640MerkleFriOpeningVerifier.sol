// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

/// @notice Проверяет Merkle-открытия для ветки Merkle/FRI исследования ePrint 2024/640.
/// @dev Контракт проверяет настоящие пути аутентификации значений из таблиц многочленов.
///      Это не полный FRI-verifier проверки малой степени, а обязательный слой открытий,
///      на котором возникает существенный объем calldata.
contract Article640MerkleFriOpeningVerifier {
    /// @dev Константа `DOMAIN` разделяет домен хеширования и не позволяет смешать разные форматы артефактов.
    bytes32 private constant DOMAIN = keccak256("MNT4_ARTICLE640_MERKLE_FRI_OPENINGS_V1");

    struct Opening {
        bytes32 root;
        bytes32 leaf;
        uint256 index;
        bytes32[] siblings;
    }

    /// @notice Проверяет один путь от листа до Merkle-корня.
    function verifyOpening(bytes32 root, bytes32 leaf, uint256 index, bytes32[] calldata siblings)
        external
        pure
        returns (bool)
    {
        return _verifyOpening(root, leaf, index, siblings);
    }

    /// @notice Проверяет набор Merkle-открытий и связывает их с seed протокола единым transcript-хешем.
    function verifyArticle640FriOpenings(bytes32 transcriptSeed, Opening[] calldata openings)
        external
        pure
        returns (bool)
    {
        if (openings.length == 0) return false;
        bytes32 acc = keccak256(abi.encodePacked(DOMAIN, transcriptSeed, openings.length));
        for (uint256 i = 0; i < openings.length; ++i) {
            Opening calldata o = openings[i];
            if (!_verifyOpening(o.root, o.leaf, o.index, o.siblings)) return false;
            acc = keccak256(abi.encodePacked(acc, o.root, o.leaf, o.index));
        }
        return acc != bytes32(0);
    }

    /// @notice Оценивает минимальный объем calldata для открытий MNT4-элементов и Merkle-путей.
    function estimateMnt4FriCalldataBytes(
        uint256 openedMnt4FieldElements,
        uint256 merklePaths,
        uint256 merkleDepth,
        uint256 friLayerRoots
    ) external pure returns (uint256) {
        // Элемент базового поля MNT4-753 кодируется тремя словами EVM, то есть 96 байтами.
        return openedMnt4FieldElements * 96 + merklePaths * merkleDepth * 32 + friLayerRoots * 32;
    }

    /// @notice Последовательно восстанавливает Merkle-корень по листу, индексу и соседним узлам.
    function _verifyOpening(bytes32 root, bytes32 leaf, uint256 index, bytes32[] calldata siblings)
        private
        pure
        returns (bool)
    {
        bytes32 node = leaf;
        uint256 idx = index;
        for (uint256 i = 0; i < siblings.length; ++i) {
            bytes32 s = siblings[i];
            node = (idx & 1) == 0 ? keccak256(abi.encodePacked(node, s)) : keccak256(abi.encodePacked(s, node));
            idx >>= 1;
        }
        return node == root;
    }
}
