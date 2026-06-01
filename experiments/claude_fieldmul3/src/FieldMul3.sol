// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

/// @notice 3-limb (768-bit) умножение по модулю фиксированного простого p.
/// Элементы хранятся little-endian: x = x0 + 2^256*x1 + 2^512*x2, 0 <= x < p.
library FieldMul3 {
    uint256 internal constant P0 =
        0x685acce9767254a4638810719ac425f0e39d54522cdd119f5e9063de245e8001;
    uint256 internal constant P1 =
        0x7fdb925e8a0ed8d99d124d9a15af79db117e776f218059db80f0da5cb537e38;
    uint256 internal constant P2 =
        0x01c4c62d92c41110229022eee2cdadb7f997505b8fafed5eb7e8f96c97d873;
    uint256 internal constant N0INV =
        0x4adb7a6352a3a656d9e1947eee113b7a7fd403903e304c4cf2044cfbe45e7fff;
    uint256 internal constant R2_0 =
        0xa896a656a0714c7da24bea56242b3507c7d9ff8e7df03c0a84717088cfd190c8;
    uint256 internal constant R2_1 =
        0xe03c79cac4f7ef07a8c86d4604a3b5972f47839ef88d7ce880a46659ff6f3ddf;
    uint256 internal constant R2_2 =
        0x00002a33e89cb485b081f15bcbfdacaf8e4605754c3817232505daf1f4a81245;

    function mulMod3(
        uint256 a0, uint256 a1, uint256 a2,
        uint256 b0, uint256 b1, uint256 b2
    ) internal pure returns (uint256 r0, uint256 r1, uint256 r2) {
        assembly {
            function fm(x, y) -> hi, lo {
                lo := mul(x, y)
                let mm := mulmod(x, y, not(0))
                hi := sub(sub(mm, lo), lt(mm, lo))
            }
            function mul3(a_0,a_1,a_2,b_0,b_1,b_2) -> t0,t1,t2,t3,t4,t5 {
                let hi, lo := fm(a_0, b_0)
                t0 := lo
                let c := hi
                hi, lo := fm(a_0, b_1)
                let tl := add(t1, lo) let k1 := lt(tl, lo)
                let tl2 := add(tl, c) let k2 := lt(tl2, c)
                t1 := tl2 c := add(hi, add(k1, k2))
                hi, lo := fm(a_0, b_2)
                tl := add(t2, lo) k1 := lt(tl, lo)
                tl2 := add(tl, c) k2 := lt(tl2, c)
                t2 := tl2 c := add(hi, add(k1, k2))
                t3 := c
                c := 0
                hi, lo := fm(a_1, b_0)
                tl := add(t1, lo) k1 := lt(tl, lo)
                tl2 := add(tl, c) k2 := lt(tl2, c)
                t1 := tl2 c := add(hi, add(k1, k2))
                hi, lo := fm(a_1, b_1)
                tl := add(t2, lo) k1 := lt(tl, lo)
                tl2 := add(tl, c) k2 := lt(tl2, c)
                t2 := tl2 c := add(hi, add(k1, k2))
                hi, lo := fm(a_1, b_2)
                tl := add(t3, lo) k1 := lt(tl, lo)
                tl2 := add(tl, c) k2 := lt(tl2, c)
                t3 := tl2 c := add(hi, add(k1, k2))
                t4 := c
                c := 0
                hi, lo := fm(a_2, b_0)
                tl := add(t2, lo) k1 := lt(tl, lo)
                tl2 := add(tl, c) k2 := lt(tl2, c)
                t2 := tl2 c := add(hi, add(k1, k2))
                hi, lo := fm(a_2, b_1)
                tl := add(t3, lo) k1 := lt(tl, lo)
                tl2 := add(tl, c) k2 := lt(tl2, c)
                t3 := tl2 c := add(hi, add(k1, k2))
                hi, lo := fm(a_2, b_2)
                tl := add(t4, lo) k1 := lt(tl, lo)
                tl2 := add(tl, c) k2 := lt(tl2, c)
                t4 := tl2 c := add(hi, add(k1, k2))
                t5 := c
            }
            function redc(i0,i1,i2,i3,i4,i5) -> o0,o1,o2 {
                let T0 := i0 let T1 := i1 let T2 := i2
                let T3 := i3 let T4 := i4 let T5 := i5
                let T6 := 0  let T7 := 0
                let p0 := P0 let p1 := P1 let p2 := P2 let np := N0INV
                let m := mul(T0, np)
                let hi, lo := fm(m, p0)
                let tl := add(T0, lo) let k1 := lt(tl, lo)
                let tl2 := add(tl, 0) let k2 := lt(tl2, 0)
                T0 := tl2 let c := add(hi, add(k1, k2))
                hi, lo := fm(m, p1)
                tl := add(T1, lo) k1 := lt(tl, lo)
                tl2 := add(tl, c) k2 := lt(tl2, c)
                T1 := tl2 c := add(hi, add(k1, k2))
                hi, lo := fm(m, p2)
                tl := add(T2, lo) k1 := lt(tl, lo)
                tl2 := add(tl, c) k2 := lt(tl2, c)
                T2 := tl2 c := add(hi, add(k1, k2))
                let ts := add(T3, c) let kc := lt(ts, c) T3 := ts
                ts := add(T4, kc) kc := lt(ts, kc) T4 := ts
                ts := add(T5, kc) kc := lt(ts, kc) T5 := ts
                ts := add(T6, kc) kc := lt(ts, kc) T6 := ts
                ts := add(T7, kc) kc := lt(ts, kc) T7 := ts
                m := mul(T1, np)
                hi, lo := fm(m, p0)
                tl := add(T1, lo) k1 := lt(tl, lo)
                tl2 := add(tl, 0) k2 := lt(tl2, 0)
                T1 := tl2 c := add(hi, add(k1, k2))
                hi, lo := fm(m, p1)
                tl := add(T2, lo) k1 := lt(tl, lo)
                tl2 := add(tl, c) k2 := lt(tl2, c)
                T2 := tl2 c := add(hi, add(k1, k2))
                hi, lo := fm(m, p2)
                tl := add(T3, lo) k1 := lt(tl, lo)
                tl2 := add(tl, c) k2 := lt(tl2, c)
                T3 := tl2 c := add(hi, add(k1, k2))
                ts := add(T4, c) kc := lt(ts, c) T4 := ts
                ts := add(T5, kc) kc := lt(ts, kc) T5 := ts
                ts := add(T6, kc) kc := lt(ts, kc) T6 := ts
                ts := add(T7, kc) kc := lt(ts, kc) T7 := ts
                m := mul(T2, np)
                hi, lo := fm(m, p0)
                tl := add(T2, lo) k1 := lt(tl, lo)
                tl2 := add(tl, 0) k2 := lt(tl2, 0)
                T2 := tl2 c := add(hi, add(k1, k2))
                hi, lo := fm(m, p1)
                tl := add(T3, lo) k1 := lt(tl, lo)
                tl2 := add(tl, c) k2 := lt(tl2, c)
                T3 := tl2 c := add(hi, add(k1, k2))
                hi, lo := fm(m, p2)
                tl := add(T4, lo) k1 := lt(tl, lo)
                tl2 := add(tl, c) k2 := lt(tl2, c)
                T4 := tl2 c := add(hi, add(k1, k2))
                ts := add(T5, c) kc := lt(ts, c) T5 := ts
                ts := add(T6, kc) kc := lt(ts, kc) T6 := ts
                ts := add(T7, kc) kc := lt(ts, kc) T7 := ts
                o0 := T3 o1 := T4 o2 := T5
                let g := or(gt(T5, p2), and(eq(T5, p2), or(gt(T4, p1), and(eq(T4, p1), iszero(lt(T3, p0))))))
                if or(iszero(iszero(T6)), g) {
                    let d0 := sub(o0, p0)
                    let br := lt(o0, p0)
                    let r1a := sub(o1, br)
                    let borrow1 := lt(o1, br)
                    let d1 := sub(r1a, p1)
                    br := or(borrow1, lt(r1a, p1))
                    let d2 := sub(sub(o2, p2), br)
                    o0 := d0 o1 := d1 o2 := d2
                }
            }
            let t0,t1,t2,t3,t4,t5 := mul3(a0,a1,a2,b0,b1,b2)
            let m0,m1,m2 := redc(t0,t1,t2,t3,t4,t5)
            let u0,u1,u2,u3,u4,u5 := mul3(m0,m1,m2, R2_0, R2_1, R2_2)
            r0, r1, r2 := redc(u0,u1,u2,u3,u4,u5)
        }
    }
}
