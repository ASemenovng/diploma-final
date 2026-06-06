// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import "./BigIntLollipop305Q.sol";

/// @notice Pointer/scratch арифметика Fq2/Fq6 для горячего Ehat-контура.
/// @dev Значения лежат последовательно в памяти:
///      Fq  = два 256-битных слова;
///      Fq2 = два коэффициента Fq;
///      Fq6 = три коэффициента Fq2.
///      Все функции `...To` записывают результат по переданному указателю и
///      переиспользуют scratch arena вместо создания динамических memory-массивов.
library Lollipop305QExtensionPacked {
    uint256 internal constant FP = 0x40;
    uint256 internal constant FQ2 = 0x80;
    uint256 internal constant FQ6 = 0x180;

    uint256 private constant RHO_00 = 0xbca4aad3edb267660749f41c7aed6a6a0716477ec23c131ca61e91ec49395e14;
    uint256 private constant RHO_01 = 0x12e32fd6de0da;
    uint256 private constant RHO_10 = 0x5e525569f6d933b303a4fa0e3d76b535038b23bf611e098e530f48f6249caf0a;
    uint256 private constant RHO_11 = 0x97197eb6f06d;

    // Константы q-Фробениуса для Fq6=Fq2[w]/(w^3-rho).
    // Так как q = 2 (mod 3), w^q = gamma1*w^2, w^(2q)=gamma2*w.
    // Значения лежат в Montgomery-представлении Fq2 и позволяют заменить
    // дорогое возведение c^q на сопряжение Fq2-коэффициентов и две
    // умножения на фиксированные коэффициенты.
    uint256 private constant GAMMA1_00 = 0xa4eebb2f3bbd4818932a6c0c84df44b8e854560a028d54230470b289cd5cdd98;
    uint256 private constant GAMMA1_01 = 0x9ccf7936eae4;
    uint256 private constant GAMMA1_10 = 0xb26a3b4e2e0315a518a1e321e11154886da50ba9143a627881079ffb0447e427;
    uint256 private constant GAMMA1_11 = 0x17f75b7495388;
    uint256 private constant GAMMA2_00 = 0xc290a5623dab00a2187bdc373787caac8d78f3af71d498dfb31dea2d1946c4d9;
    uint256 private constant GAMMA2_01 = 0x2c30b1bd981f;
    uint256 private constant GAMMA2_10 = 0xd00c25812ff0ce2e9df3534c93b9da7c12c9a94e8381a7352fb4d79e5031cb68;
    uint256 private constant GAMMA2_11 = 0x10ed6efd000c3;

    /// @notice Копирует Fq2 из ABI-массива в packed-память без промежуточной структуры.
    function copyFq2FromArray(uint256 out, uint256[4] memory a) internal pure {
        assembly ("memory-safe") {
            mstore(out, mload(a))
            mstore(add(out, 0x20), mload(add(a, 0x20)))
            mstore(add(out, 0x40), mload(add(a, 0x40)))
            mstore(add(out, 0x60), mload(add(a, 0x60)))
        }
    }

    /// @notice Копирует Fq6 из ABI-массива в packed-память; используется на границе verifier API.
    function copyFq6FromArray(uint256 out, uint256[12] memory a) internal pure {
        assembly ("memory-safe") {
            for { let i := 0 } lt(i, 0x180) { i := add(i, 0x20) } {
                mstore(add(out, i), mload(add(a, i)))
            }
        }
    }

    /// @notice Преобразует packed Fq6 обратно в ABI-массив для тестов и публичных возвращаемых значений.
    function fq6ToArray(uint256 a) internal pure returns (uint256[12] memory out) {
        assembly ("memory-safe") {
            for { let i := 0 } lt(i, 0x180) { i := add(i, 0x20) } {
                mstore(add(out, i), mload(add(a, i)))
            }
        }
    }

    /// @notice Копирует packed Fq6 между двумя областями памяти.
    function fq6CopyTo(uint256 out, uint256 a) internal pure {
        assembly ("memory-safe") {
            for { let i := 0 } lt(i, 0x180) { i := add(i, 0x20) } {
                mstore(add(out, i), mload(add(a, i)))
            }
        }
    }

    /// @notice Записывает единицу Fq6: первый Fq-коэффициент равен 1, остальные коэффициенты нулевые.
    function fq6OneTo(uint256 out, uint256 one0, uint256 one1) internal pure {
        assembly ("memory-safe") {
            mstore(out, one0)
            mstore(add(out, 0x20), one1)
            for { let i := 0x40 } lt(i, 0x180) { i := add(i, 0x20) } {
                mstore(add(out, i), 0)
            }
        }
    }

    /// @notice Сравнивает два packed Fq6 пословно.
    function fq6Eq(uint256 a, uint256 b) internal pure returns (bool equal) {
        assembly ("memory-safe") {
            equal := 1
            for { let i := 0 } lt(i, 0x180) { i := add(i, 0x20) } {
                if iszero(eq(mload(add(a, i)), mload(add(b, i)))) {
                    equal := 0
                    break
                }
            }
        }
    }

    /// @notice Сложение Fq2 по двум координатам Fq.
    function fq2AddTo(uint256 out, uint256 a, uint256 b) internal pure {
        (uint256 r0, uint256 r1) = BigIntLollipop305Q.add2(_w(a, 0), _w(a, 1), _w(b, 0), _w(b, 1));
        _storeFp(out, r0, r1);
        (r0, r1) = BigIntLollipop305Q.add2(_w(a, 2), _w(a, 3), _w(b, 2), _w(b, 3));
        _storeFp(out + FP, r0, r1);
    }

    /// @notice Вычитание Fq2 по двум координатам Fq.
    function fq2SubTo(uint256 out, uint256 a, uint256 b) internal pure {
        (uint256 r0, uint256 r1) = BigIntLollipop305Q.sub2(_w(a, 0), _w(a, 1), _w(b, 0), _w(b, 1));
        _storeFp(out, r0, r1);
        (r0, r1) = BigIntLollipop305Q.sub2(_w(a, 2), _w(a, 3), _w(b, 2), _w(b, 3));
        _storeFp(out + FP, r0, r1);
    }

    /// @notice Аддитивное отрицание Fq2.
    function fq2NegTo(uint256 out, uint256 a) internal pure {
        (uint256 r0, uint256 r1) = BigIntLollipop305Q.sub2(0, 0, _w(a, 0), _w(a, 1));
        _storeFp(out, r0, r1);
        (r0, r1) = BigIntLollipop305Q.sub2(0, 0, _w(a, 2), _w(a, 3));
        _storeFp(out + FP, r0, r1);
    }

    /// @notice q-Фробениус в Fq2: для eta^2=-2 выполняется (a+b*eta)^q=a-b*eta.
    function fq2ConjugateTo(uint256 out, uint256 a) internal pure {
        assembly ("memory-safe") {
            mstore(out, mload(a))
            mstore(add(out, 0x20), mload(add(a, 0x20)))
        }
        (uint256 r0, uint256 r1) = BigIntLollipop305Q.sub2(0, 0, _w(a, 2), _w(a, 3));
        _storeFp(out + FP, r0, r1);
    }

    /// @notice Умножение Fq2 по формуле Карацубы для eta^2=-2.
    /// @dev `scratch` должен указывать на свободную область памяти не меньше 5*FP байт.
    function fq2MulTo(uint256 out, uint256 a, uint256 b, uint256 scratch) internal pure {
        uint256 sA = scratch;
        uint256 sB = scratch + FP;
        uint256 v0 = scratch + 2 * FP;
        uint256 v1 = scratch + 3 * FP;
        uint256 v2 = scratch + 4 * FP;

        _fpAddTo(sA, a, a + FP);
        _fpAddTo(sB, b, b + FP);
        _fpMulTo(v0, a, b);
        _fpMulTo(v1, a + FP, b + FP);
        _fpMulTo(v2, sA, sB);
        _fpAddTo(sA, v1, v1);
        _fpSubTo(out, v0, sA);
        _fpAddTo(sA, v0, v1);
        _fpSubTo(out + FP, v2, sA);
    }

    /// @notice Специализированное возведение Fq2 в квадрат; дешевле общего `fq2MulTo(a,a)`.
    function fq2SqrTo(uint256 out, uint256 a, uint256 scratch) internal pure {
        uint256 v0 = scratch;
        uint256 v1 = scratch + FP;
        uint256 v2 = scratch + 2 * FP;
        _fpSqrTo(v0, a);
        _fpSqrTo(v1, a + FP);
        _fpMulTo(v2, a, a + FP);
        _fpAddTo(v1, v1, v1);
        _fpSubTo(out, v0, v1);
        _fpAddTo(out + FP, v2, v2);
    }

    /// @notice Умножает Fq2-значение на rho, где Fq6 строится как Fq2[w]/(w^3-rho).
    function fq2MulByRhoTo(uint256 out, uint256 a, uint256 scratch) internal pure {
        _writeRho(scratch);
        fq2MulTo(out, a, scratch, scratch + FQ2);
    }

    /// @notice Умножает Fq2-значение на gamma1 из формулы w^q=gamma1*w^2.
    function fq2MulByGamma1To(uint256 out, uint256 a, uint256 scratch) internal pure {
        _writeGamma1(scratch);
        fq2MulTo(out, a, scratch, scratch + FQ2);
    }

    /// @notice Умножает Fq2-значение на gamma2 из формулы w^(2q)=gamma2*w.
    function fq2MulByGamma2To(uint256 out, uint256 a, uint256 scratch) internal pure {
        _writeGamma2(scratch);
        fq2MulTo(out, a, scratch, scratch + FQ2);
    }

    /// @notice Специализированный квадрат Fq6 без вызова общего `fq6Mul`.
    function fq6SqrTo(uint256 out, uint256 a, uint256 scratch) internal pure {
        uint256 t0 = scratch;
        uint256 t1 = scratch + FQ2;
        uint256 t2 = scratch + 2 * FQ2;
        uint256 rhoT = scratch + 3 * FQ2;
        uint256 inner = scratch + 4 * FQ2;

        // c0 = a0^2 + 2*rho*a1*a2.
        fq2SqrTo(t0, a, inner);
        fq2MulTo(t1, a + FQ2, a + 2 * FQ2, inner);
        fq2AddTo(t1, t1, t1);
        fq2MulByRhoTo(rhoT, t1, inner);
        fq2AddTo(out, t0, rhoT);

        // c1 = 2*a0*a1 + rho*a2^2.
        fq2MulTo(t0, a, a + FQ2, inner);
        fq2AddTo(t0, t0, t0);
        fq2SqrTo(t2, a + 2 * FQ2, inner);
        fq2MulByRhoTo(rhoT, t2, inner);
        fq2AddTo(out + FQ2, t0, rhoT);

        // c2 = a1^2 + 2*a0*a2.
        fq2SqrTo(t0, a + FQ2, inner);
        fq2MulTo(t1, a, a + 2 * FQ2, inner);
        fq2AddTo(t1, t1, t1);
        fq2AddTo(out + 2 * FQ2, t0, t1);
    }

    /// @notice Умножает Fq6 на разреженный множитель b0+b1*w.
    function fq6MulBy01To(uint256 out, uint256 a, uint256 b0, uint256 b1, uint256 scratch) internal pure {
        uint256 t0 = scratch;
        uint256 t1 = scratch + FQ2;
        uint256 rhoT = scratch + 2 * FQ2;
        uint256 inner = scratch + 3 * FQ2;

        fq2MulTo(t0, a, b0, inner);
        fq2MulTo(t1, a + 2 * FQ2, b1, inner);
        fq2MulByRhoTo(rhoT, t1, inner);
        fq2AddTo(out, t0, rhoT);

        fq2MulTo(t0, a, b1, inner);
        fq2MulTo(t1, a + FQ2, b0, inner);
        fq2AddTo(out + FQ2, t0, t1);

        fq2MulTo(t0, a + FQ2, b1, inner);
        fq2MulTo(t1, a + 2 * FQ2, b0, inner);
        fq2AddTo(out + 2 * FQ2, t0, t1);
    }

    /// @notice Умножает Fq6 на разреженный множитель b0+b2*w^2.
    function fq6MulBy02To(uint256 out, uint256 a, uint256 b0, uint256 b2, uint256 scratch) internal pure {
        uint256 t0 = scratch;
        uint256 t1 = scratch + FQ2;
        uint256 rhoT = scratch + 2 * FQ2;
        uint256 inner = scratch + 3 * FQ2;

        fq2MulTo(t0, a, b0, inner);
        fq2MulTo(t1, a + FQ2, b2, inner);
        fq2MulByRhoTo(rhoT, t1, inner);
        fq2AddTo(out, t0, rhoT);

        fq2MulTo(t0, a + FQ2, b0, inner);
        fq2MulTo(t1, a + 2 * FQ2, b2, inner);
        fq2MulByRhoTo(rhoT, t1, inner);
        fq2AddTo(out + FQ2, t0, rhoT);

        fq2MulTo(t0, a, b2, inner);
        fq2MulTo(t1, a + 2 * FQ2, b0, inner);
        fq2AddTo(out + 2 * FQ2, t0, t1);
    }

    /// @notice Общее умножение Fq6 по Карацубе: шесть умножений Fq2 вместо девяти.
    function fq6MulTo(uint256 out, uint256 a, uint256 b, uint256 scratch) internal pure {
        uint256 v0 = scratch;
        uint256 v1 = scratch + FQ2;
        uint256 v2 = scratch + 2 * FQ2;
        uint256 t0 = scratch + 3 * FQ2;
        uint256 t1 = scratch + 4 * FQ2;
        uint256 t2 = scratch + 5 * FQ2;
        uint256 rhoT = scratch + 6 * FQ2;
        uint256 sA = scratch + 7 * FQ2;
        uint256 sB = scratch + 8 * FQ2;
        uint256 inner = scratch + 9 * FQ2;

        fq2MulTo(v0, a, b, inner);
        fq2MulTo(v1, a + FQ2, b + FQ2, inner);
        fq2MulTo(v2, a + 2 * FQ2, b + 2 * FQ2, inner);

        fq2AddTo(sA, a + FQ2, a + 2 * FQ2);
        fq2AddTo(sB, b + FQ2, b + 2 * FQ2);
        fq2MulTo(t0, sA, sB, inner);
        fq2SubTo(t0, t0, v1);
        fq2SubTo(t0, t0, v2);
        fq2MulByRhoTo(rhoT, t0, inner);
        fq2AddTo(out, v0, rhoT);

        fq2AddTo(sA, a, a + FQ2);
        fq2AddTo(sB, b, b + FQ2);
        fq2MulTo(t1, sA, sB, inner);
        fq2SubTo(t1, t1, v0);
        fq2SubTo(t1, t1, v1);
        fq2MulByRhoTo(rhoT, v2, inner);
        fq2AddTo(out + FQ2, t1, rhoT);

        fq2AddTo(sA, a, a + 2 * FQ2);
        fq2AddTo(sB, b, b + 2 * FQ2);
        fq2MulTo(t2, sA, sB, inner);
        fq2SubTo(t2, t2, v0);
        fq2AddTo(t2, t2, v1);
        fq2SubTo(out + 2 * FQ2, t2, v2);
    }

    /// @notice q-Фробениус в Fq6.
    /// @dev Для x=x0+x1*w+x2*w^2 и q=2 mod 3:
    ///      x^q = conj(x0) + conj(x2)*gamma2*w + conj(x1)*gamma1*w^2.
    ///      Это линейно-дешевая замена общего возведения в степень q.
    function fq6FrobeniusQTo(uint256 out, uint256 a, uint256 scratch) internal pure {
        uint256 conj1 = scratch;
        uint256 conj2 = scratch + FQ2;
        uint256 inner = scratch + 2 * FQ2;
        fq2ConjugateTo(out, a);
        fq2ConjugateTo(conj2, a + 2 * FQ2);
        fq2MulByGamma2To(out + FQ2, conj2, inner);
        fq2ConjugateTo(conj1, a + FQ2);
        fq2MulByGamma1To(out + 2 * FQ2, conj1, inner);
    }

    /// @notice Внутреннее сложение Fq: читает два слова по указателям и записывает результат.
    function _fpAddTo(uint256 out, uint256 a, uint256 b) private pure {
        (uint256 r0, uint256 r1) = BigIntLollipop305Q.add2(_w(a, 0), _w(a, 1), _w(b, 0), _w(b, 1));
        _storeFp(out, r0, r1);
    }

    /// @notice Внутреннее вычитание Fq: читает два слова по указателям и записывает результат.
    function _fpSubTo(uint256 out, uint256 a, uint256 b) private pure {
        (uint256 r0, uint256 r1) = BigIntLollipop305Q.sub2(_w(a, 0), _w(a, 1), _w(b, 0), _w(b, 1));
        _storeFp(out, r0, r1);
    }

    /// @notice Внутреннее Montgomery-умножение Fq для hot path.
    function _fpMulTo(uint256 out, uint256 a, uint256 b) private pure {
        (uint256 r0, uint256 r1) = BigIntLollipop305Q.montMul2(_w(a, 0), _w(a, 1), _w(b, 0), _w(b, 1));
        _storeFp(out, r0, r1);
    }

    /// @notice Внутренний специализированный квадрат Fq для hot path.
    function _fpSqrTo(uint256 out, uint256 a) private pure {
        (uint256 r0, uint256 r1) = BigIntLollipop305Q.montSqr2(_w(a, 0), _w(a, 1));
        _storeFp(out, r0, r1);
    }

    /// @notice Записывает константу rho в scratch-память в Montgomery-представлении.
    function _writeRho(uint256 out) private pure {
        assembly ("memory-safe") {
            mstore(out, RHO_00)
            mstore(add(out, 0x20), RHO_01)
            mstore(add(out, 0x40), RHO_10)
            mstore(add(out, 0x60), RHO_11)
        }
    }

    /// @notice Записывает коэффициент gamma1 для q-Фробениуса Fq6.
    function _writeGamma1(uint256 out) private pure {
        assembly ("memory-safe") {
            mstore(out, GAMMA1_00)
            mstore(add(out, 0x20), GAMMA1_01)
            mstore(add(out, 0x40), GAMMA1_10)
            mstore(add(out, 0x60), GAMMA1_11)
        }
    }

    /// @notice Записывает коэффициент gamma2 для q-Фробениуса Fq6.
    function _writeGamma2(uint256 out) private pure {
        assembly ("memory-safe") {
            mstore(out, GAMMA2_00)
            mstore(add(out, 0x20), GAMMA2_01)
            mstore(add(out, 0x40), GAMMA2_10)
            mstore(add(out, 0x60), GAMMA2_11)
        }
    }

    /// @notice Записывает два слова Fq в packed-память.
    function _storeFp(uint256 out, uint256 r0, uint256 r1) private pure {
        assembly ("memory-safe") {
            mstore(out, r0)
            mstore(add(out, 0x20), r1)
        }
    }

    /// @notice Читает i-е 256-битное слово из packed-области памяти.
    function _w(uint256 p, uint256 i) private pure returns (uint256 x) {
        assembly ("memory-safe") {
            x := mload(add(p, mul(i, 0x20)))
        }
    }
}
