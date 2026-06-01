// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {BigIntMNT} from "./BigIntMNT.sol";

/// @notice Проверки пользовательских точек группы G1 кривой MNT4-753.
/// @dev Координаты передаются в Montgomery-представлении, которое использует
///      остальная MNT4-библиотека. У G1(MNT4-753) кофактор равен единице:
///      канонически представленная точка на кривой автоматически принадлежит
///      требуемой подгруппе простого порядка.
library MNT4CurveChecks {
    uint256 private constant P0 = 0x685acce9767254a4638810719ac425f0e39d54522cdd119f5e9063de245e8001;
    uint256 private constant P1 = 0x7fdb925e8a0ed8d99d124d9a15af79db117e776f218059db80f0da5cb537e38;
    uint256 private constant P2 = 0x0001c4c62d92c41110229022eee2cdadb7f997505b8fafed5eb7e8f96c97d873;

    // a = 2 в Montgomery-представлении.
    uint256 private constant A0 = 0xf2b130338f116c032f87c9419a28ae5d239a638cb4068d0d3151d957b3b8de84;
    uint256 private constant A1 = 0xb3168605a5e014c46418776e26670ab23c1e9b159e063ad1da4d392842112ede;
    uint256 private constant A2 = 0x0000f68f3d91c4852a8abf663ff3432a1f48fdb670cbd11880e99397fb194c42;

    // Коэффициент b кривой MNT4-753 в Montgomery-представлении.
    uint256 private constant B0 = 0x18600804d0bcdc36122b02a617b0220bf4144ce402eb4f2a25171e93506fb062;
    uint256 private constant B1 = 0x88696442003f5f9d6626f99c37f11ab9082ed0a83dae31be4adf7a3e41c5734c;
    uint256 private constant B2 = 0x00019f483a5ca38b8d306223ebeb759151b835e3477a560081a3dd7644095968;

    /// @notice Проверяет каноничность координат и равенство y^2 = x^3 + 2x + b.
    function isOnG1(uint256[3] memory x, uint256[3] memory y) internal pure returns (bool) {
        if (!_isCanonical(x) || !_isCanonical(y)) return false;
        uint256[3] memory y2 = BigIntMNT.montSqr(y);
        uint256[3] memory x3 = BigIntMNT.montMul(BigIntMNT.montSqr(x), x);
        uint256[3] memory ax = BigIntMNT.montMul(x, [A0, A1, A2]);
        uint256[3] memory rhs = _add(_add(x3, ax), [B0, B1, B2]);
        return y2[0] == rhs[0] && y2[1] == rhs[1] && y2[2] == rhs[2];
    }

    /// @notice Проверяет, что трехсловное значение лежит в диапазоне [0, p).
    function _isCanonical(uint256[3] memory x) private pure returns (bool) {
        if (x[2] != P2) return x[2] < P2;
        if (x[1] != P1) return x[1] < P1;
        return x[0] < P0;
    }

    /// @notice Складывает два приведенных элемента базового поля.
    function _add(uint256[3] memory a, uint256[3] memory b) private pure returns (uint256[3] memory r) {
        (r[0], r[1], r[2]) = BigIntMNT.add3(a[0], a[1], a[2], b[0], b[1], b[2]);
    }
}
