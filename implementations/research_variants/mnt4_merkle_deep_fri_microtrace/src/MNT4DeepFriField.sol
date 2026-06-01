// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {BigIntMNT} from "@arith-mnt4/BigIntMNT.sol";

/// @notice Минимальный арифметический слой DEEP-FRI verifier-а для поля MNT4-753.
/// @dev Внутреннее представление всегда Montgomery: три слова идут от младшего к старшему.
///      Внешний proof хранит канонические значения big-endian; функция `fromBytes` выполняет
///      строгую проверку каноничности и единственный перевод в Montgomery-представление.
library MNT4DeepFriField {
    // Модуль базового поля q MNT4-753, разбитый на три 256-битных слова.
    uint256 internal constant P0 = 0x685acce9767254a4638810719ac425f0e39d54522cdd119f5e9063de245e8001;
    uint256 internal constant P1 = 0x7fdb925e8a0ed8d99d124d9a15af79db117e776f218059db80f0da5cb537e38;
    uint256 internal constant P2 = 0x1c4c62d92c41110229022eee2cdadb7f997505b8fafed5eb7e8f96c97d873;
    // Montgomery-представление единицы: R mod q, где R = 2^768.
    uint256 internal constant ONE0 = 0x79589819c788b60197c3e4a0cd14572e91cd31c65a03468698a8ecabd9dc6f42;
    uint256 internal constant ONE1 = 0x598b4302d2f00a62320c3bb7133385591e0f4d8acf031d68ed269c942108976f;
    uint256 internal constant ONE2 = 0x7b479ec8e24295455fb31ff9a1950fa47edb3865e88c4074c9cbfd8ca621;
    // Константы Фробениуса для башни Fq2/Fq4. Они позволяют заменить
    // возведение в степень q несколькими умножениями в базовом поле.
    uint256 internal constant FROB_FQ2_0 = 0xef0234cfaee99ea2cbc42bd0cdafcec251d0228bd2d9cb18c5e777324a8210bf;
    uint256 internal constant FROB_FQ2_1 = 0xae72762315b0e32b67c4e9228e277244930899ec2314e834cae87111aa4ae6c8;
    uint256 internal constant FROB_FQ2_2 = 0x1497e8ec9e1ce7add306fcee92c18a85518752329c7611e431f2d6f0b3251;
    uint256 internal constant FROB_FQ4_0 = 0x580f0950ee2d0f91c729995df0c170781e27fd3b9ead8a2c25eac118209420db;
    uint256 internal constant FROB_FQ4_1 = 0x19912707c043191ae6c206bb24a7f2be1a3253f2c75a19d12c5f103cbe99cc71;
    uint256 internal constant FROB_FQ4_2 = 0x94c44a4e987210dbb90d8450ff4e0a0181e8fd0ad0bdbad8bbb7cc6e9c35;

    struct Fp {
        uint256 d0;
        uint256 d1;
        uint256 d2;
    }

    /// @dev Fq4 строится башней Fq2[v] / (v^2-u), где Fq2=Fq[u]/(u^2-13).
    ///      Порядок коэффициентов соответствует arkworks: [1, u, v, uv].
    struct Fp4 {
        Fp a0;
        Fp a1;
        Fp a2;
        Fp a3;
    }

    function zero() internal pure returns (Fp memory) {}

    function one() internal pure returns (Fp memory value) {
        value = Fp(ONE0, ONE1, ONE2);
    }

    function fromUint(uint256 value) internal pure returns (Fp memory out) {
        (out.d0, out.d1, out.d2) = BigIntMNT.toMontgomery3(value, 0, 0);
    }

    function fromCanonicalWords(uint256 d2, uint256 d1, uint256 d0) internal pure returns (Fp memory out) {
        // Неканонические представления запрещены: иначе одно значение поля
        // могло бы иметь несколько байтовых кодировок в Merkle-дереве.
        require(isCanonical(d2, d1, d0), "non-canonical Fq");
        (out.d0, out.d1, out.d2) = BigIntMNT.toMontgomery3(d0, d1, d2);
    }

    function fromBytes(bytes calldata data, uint256 offset) internal pure returns (Fp memory out) {
        require(offset + 96 <= data.length, "truncated Fq");
        uint256 d2;
        uint256 d1;
        uint256 d0;
        assembly ("memory-safe") {
            d2 := calldataload(add(data.offset, offset))
            d1 := calldataload(add(add(data.offset, offset), 0x20))
            d0 := calldataload(add(add(data.offset, offset), 0x40))
        }
        return fromCanonicalWords(d2, d1, d0);
    }

    function fromMemoryBytes(bytes memory data, uint256 offset) internal pure returns (Fp memory out) {
        require(offset + 96 <= data.length, "truncated Fq");
        uint256 d2;
        uint256 d1;
        uint256 d0;
        assembly ("memory-safe") {
            d2 := mload(add(add(data, 0x20), offset))
            d1 := mload(add(add(data, 0x40), offset))
            d0 := mload(add(add(data, 0x60), offset))
        }
        return fromCanonicalWords(d2, d1, d0);
    }

    function toBytes(Fp memory value) internal pure returns (bytes memory) {
        (uint256 d0, uint256 d1, uint256 d2) = BigIntMNT.fromMontgomery3(value.d0, value.d1, value.d2);
        return abi.encodePacked(d2, d1, d0);
    }

    function isCanonical(uint256 d2, uint256 d1, uint256 d0) internal pure returns (bool) {
        return d2 < P2 || (d2 == P2 && (d1 < P1 || (d1 == P1 && d0 < P0)));
    }

    function add(Fp memory a, Fp memory b) internal pure returns (Fp memory out) {
        (out.d0, out.d1, out.d2) = BigIntMNT.add3(a.d0, a.d1, a.d2, b.d0, b.d1, b.d2);
    }

    function sub(Fp memory a, Fp memory b) internal pure returns (Fp memory out) {
        (out.d0, out.d1, out.d2) = BigIntMNT.sub3(a.d0, a.d1, a.d2, b.d0, b.d1, b.d2);
    }

    function neg(Fp memory a) internal pure returns (Fp memory out) {
        (out.d0, out.d1, out.d2) = BigIntMNT.sub3(0, 0, 0, a.d0, a.d1, a.d2);
    }

    function mul(Fp memory a, Fp memory b) internal pure returns (Fp memory out) {
        (out.d0, out.d1, out.d2) = BigIntMNT.montMul3(a.d0, a.d1, a.d2, b.d0, b.d1, b.d2);
    }

    function sqr(Fp memory a) internal pure returns (Fp memory out) {
        (out.d0, out.d1, out.d2) = BigIntMNT.montSqr3(a.d0, a.d1, a.d2);
    }

    function mul13(Fp memory a) internal pure returns (Fp memory out) {
        (out.d0, out.d1, out.d2) = BigIntMNT.mulBy13(a.d0, a.d1, a.d2);
    }

    function powSmall(Fp memory base, uint256 exponent) internal pure returns (Fp memory out) {
        // Используется только для степеней, связанных с доменом FRI.
        // Для больших криптографических экспонент этот общий цикл не подходит.
        out = one();
        while (exponent != 0) {
            if (exponent & 1 != 0) out = mul(out, base);
            exponent >>= 1;
            if (exponent != 0) base = sqr(base);
        }
    }

    function equal(Fp memory a, Fp memory b) internal pure returns (bool) {
        return a.d0 == b.d0 && a.d1 == b.d1 && a.d2 == b.d2;
    }

    function isZero(Fp memory a) internal pure returns (bool) {
        return a.d0 == 0 && a.d1 == 0 && a.d2 == 0;
    }

    function fp4One() internal pure returns (Fp4 memory out) {
        out.a0 = one();
    }

    function fp4Equal(Fp4 memory a, Fp4 memory b) internal pure returns (bool) {
        return equal(a.a0, b.a0) && equal(a.a1, b.a1) && equal(a.a2, b.a2) && equal(a.a3, b.a3);
    }

    /// @notice Умножает два элемента Fq4 в башне Fq2[v]/(v^2-u).
    /// @dev Порядок [1,u,v,uv] нельзя трактовать как последовательные степени
    ///      одного формального Z. Формулы ниже явно учитывают v^2=u и u^2=13.
    function fp4Mul(Fp4 memory a, Fp4 memory b) internal pure returns (Fp4 memory out) {
        out.a0 = add(mul(a.a0, b.a0), mul13(add(add(mul(a.a1, b.a1), mul(a.a2, b.a3)), mul(a.a3, b.a2))));
        out.a1 = add(add(add(mul(a.a0, b.a1), mul(a.a1, b.a0)), mul(a.a2, b.a2)), mul13(mul(a.a3, b.a3)));
        out.a2 = add(add(mul(a.a0, b.a2), mul(a.a2, b.a0)), mul13(add(mul(a.a1, b.a3), mul(a.a3, b.a1))));
        out.a3 = add(add(add(mul(a.a0, b.a3), mul(a.a1, b.a2)), mul(a.a2, b.a1)), mul(a.a3, b.a0));
    }

    function fp4Sqr(Fp4 memory a) internal pure returns (Fp4 memory out) {
        Fp memory two = fromUint(2);
        out.a0 = add(sqr(a.a0), mul13(add(sqr(a.a1), mul(two, mul(a.a2, a.a3)))));
        out.a1 = add(add(mul(two, mul(a.a0, a.a1)), sqr(a.a2)), mul13(sqr(a.a3)));
        out.a2 = add(mul(two, mul(a.a0, a.a2)), mul13(mul(two, mul(a.a1, a.a3))));
        out.a3 = add(mul(two, mul(a.a0, a.a3)), mul(two, mul(a.a1, a.a2)));
    }

    /// @notice Применяет q-Фробениус к Fq4 без длинного возведения в степень.
    function fp4Frobenius(Fp4 memory a) internal pure returns (Fp4 memory out) {
        Fp memory chi2 = Fp(FROB_FQ2_0, FROB_FQ2_1, FROB_FQ2_2);
        Fp memory chi4 = Fp(FROB_FQ4_0, FROB_FQ4_1, FROB_FQ4_2);
        out.a0 = a.a0;
        out.a1 = mul(a.a1, chi2);
        out.a2 = mul(a.a2, chi4);
        out.a3 = mul(mul(a.a3, chi2), chi4);
    }
}
