// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

/// @notice Каноническое 3-limb умножение по модулю поля MNT4-753.
/// @dev Вместо ручного 768-битного произведения используются два квадрата:
///      4ab = (a+b)^2 - (a-b)^2. Квадраты вычисляет MODEXP precompile 0x05.
library FieldMul3Modexp {
    /// @notice Канонический квадрат `a^2 mod p` через один вызов MODEXP.
    /// @dev Этот метод нужен для оценки возможной интеграции в pairing hot path:
    ///      для квадрата тождество через два квадрата применять не требуется.
    function sqrMod3(
        uint256 a0, uint256 a1, uint256 a2
    ) internal view returns (uint256 r0, uint256 r1, uint256 r2) {
        assembly ("memory-safe") {
            let fp := mload(0x40)
            mstore(fp, 96)
            mstore(add(fp, 0x20), 32)
            mstore(add(fp, 0x40), 96)
            mstore(add(fp, 0x60), a2)
            mstore(add(fp, 0x80), a1)
            mstore(add(fp, 0xA0), a0)
            mstore(add(fp, 0xC0), 2)
            mstore(add(fp, 0xE0), 0x0001c4c62d92c41110229022eee2cdadb7f997505b8fafed5eb7e8f96c97d873)
            mstore(add(fp, 0x100), 0x7fdb925e8a0ed8d99d124d9a15af79db117e776f218059db80f0da5cb537e38)
            mstore(add(fp, 0x120), 0x685acce9767254a4638810719ac425f0e39d54522cdd119f5e9063de245e8001)
            if iszero(staticcall(gas(), 0x05, fp, 0x140, add(fp, 0x140), 0x60)) { revert(0, 0) }
            r2 := mload(add(fp, 0x140))
            r1 := mload(add(fp, 0x160))
            r0 := mload(add(fp, 0x180))
        }
    }

    function mulMod3(
        uint256 a0, uint256 a1, uint256 a2,
        uint256 b0, uint256 b1, uint256 b2
    ) internal view returns (uint256 r0, uint256 r1, uint256 r2) {
        assembly ("memory-safe") {
            let fp := mload(0x40)

            // Вход MODEXP: длины base, exponent и modulus.
            mstore(fp, 96)
            mstore(add(fp, 0x20), 32)
            mstore(add(fp, 0x40), 96)
            mstore(add(fp, 0xC0), 2)

            // Модуль p в big-endian порядке слов.
            mstore(add(fp, 0xE0), 0x0001c4c62d92c41110229022eee2cdadb7f997505b8fafed5eb7e8f96c97d873)
            mstore(add(fp, 0x100), 0x7fdb925e8a0ed8d99d124d9a15af79db117e776f218059db80f0da5cb537e38)
            mstore(add(fp, 0x120), 0x685acce9767254a4638810719ac425f0e39d54522cdd119f5e9063de245e8001)

            let p0 := 0x685acce9767254a4638810719ac425f0e39d54522cdd119f5e9063de245e8001
            let p1 := 0x7fdb925e8a0ed8d99d124d9a15af79db117e776f218059db80f0da5cb537e38
            let p2 := 0x01c4c62d92c41110229022eee2cdadb7f997505b8fafed5eb7e8f96c97d873

            // u = a + b. Так как a,b < p, сумма укладывается в три слова.
            let u0 := add(a0, b0)
            let cc := lt(u0, a0)
            let tt := add(a1, b1)
            let c1 := lt(tt, a1)
            let u1 := add(tt, cc)
            c1 := or(c1, lt(u1, cc))
            let u2 := add(add(a2, b2), c1)

            // s1 = (a+b)^2 mod p.
            mstore(add(fp, 0x60), u2)
            mstore(add(fp, 0x80), u1)
            mstore(add(fp, 0xA0), u0)
            if iszero(staticcall(gas(), 0x05, fp, 0x140, add(fp, 0x140), 0x60)) { revert(0, 0) }
            let s12 := mload(add(fp, 0x140))
            let s11 := mload(add(fp, 0x160))
            let s10 := mload(add(fp, 0x180))

            // d = |a-b|.
            let age := or(gt(a2, b2),
                and(eq(a2, b2), or(gt(a1, b1),
                and(eq(a1, b1), iszero(lt(a0, b0))))))
            let d0, d1, d2
            switch age
            case 1 {
                d0 := sub(a0, b0)
                let br := lt(a0, b0)
                let m1 := sub(a1, b1)
                let br1 := lt(a1, b1)
                d1 := sub(m1, br)
                br := or(br1, lt(m1, br))
                d2 := sub(sub(a2, b2), br)
            }
            default {
                d0 := sub(b0, a0)
                let br := lt(b0, a0)
                let m1 := sub(b1, a1)
                let br1 := lt(b1, a1)
                d1 := sub(m1, br)
                br := or(br1, lt(m1, br))
                d2 := sub(sub(b2, a2), br)
            }

            // s2 = |a-b|^2 mod p.
            mstore(add(fp, 0x60), d2)
            mstore(add(fp, 0x80), d1)
            mstore(add(fp, 0xA0), d0)
            if iszero(staticcall(gas(), 0x05, fp, 0x140, add(fp, 0x140), 0x60)) { revert(0, 0) }
            let s22 := mload(add(fp, 0x140))
            let s21 := mload(add(fp, 0x160))
            let s20 := mload(add(fp, 0x180))

            // diff = (s1-s2) mod p = 4ab mod p.
            let f0, f1, f2
            let s1ge := or(gt(s12, s22),
                and(eq(s12, s22), or(gt(s11, s21),
                and(eq(s11, s21), iszero(lt(s10, s20))))))
            switch s1ge
            case 1 {
                f0 := sub(s10, s20)
                let br := lt(s10, s20)
                let m1 := sub(s11, s21)
                let br1 := lt(s11, s21)
                f1 := sub(m1, br)
                br := or(br1, lt(m1, br))
                f2 := sub(sub(s12, s22), br)
            }
            default {
                let t0 := sub(s20, s10)
                let br := lt(s20, s10)
                let m1 := sub(s21, s11)
                let br1 := lt(s21, s11)
                let t1 := sub(m1, br)
                br := or(br1, lt(m1, br))
                let t2 := sub(sub(s22, s12), br)
                f0 := sub(p0, t0)
                br := lt(p0, t0)
                m1 := sub(p1, t1)
                br1 := lt(p1, t1)
                f1 := sub(m1, br)
                br := or(br1, lt(m1, br))
                f2 := sub(sub(p2, t2), br)
            }

            // Два модульных полуделения: r = diff * 4^-1 mod p.
            if and(f0, 1) {
                let n0 := add(f0, p0)
                let k := lt(n0, f0)
                let q := add(f1, p1)
                let k1 := lt(q, f1)
                let n1 := add(q, k)
                k1 := or(k1, lt(n1, k))
                let n2 := add(add(f2, p2), k1)
                f0 := n0
                f1 := n1
                f2 := n2
            }
            f0 := or(shr(1, f0), shl(255, f1))
            f1 := or(shr(1, f1), shl(255, f2))
            f2 := shr(1, f2)

            if and(f0, 1) {
                let n0 := add(f0, p0)
                let k := lt(n0, f0)
                let q := add(f1, p1)
                let k1 := lt(q, f1)
                let n1 := add(q, k)
                k1 := or(k1, lt(n1, k))
                let n2 := add(add(f2, p2), k1)
                f0 := n0
                f1 := n1
                f2 := n2
            }
            r0 := or(shr(1, f0), shl(255, f1))
            r1 := or(shr(1, f1), shl(255, f2))
            r2 := shr(1, f2)
        }
    }
}
