// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {MNT6PairingTypes} from "./MNT6PairingTypes.sol";
import {MNT6Fq3} from "./MNT6Fq3.sol";
import {MNT6Fq6} from "./MNT6Fq6.sol";
import {MNT6PackedArithmetic} from "./MNT6PackedArithmetic.sol";

/// @notice Цикл Миллера ate-сопряжения MNT6-753 по заранее подготовленным коэффициентам G2.
/// @dev Последовательность шагов соответствует `ark-ec::mnt6::ate_miller_loop`.
///      Модуль используется как проверяемый слой корректности и как основа gas-измерений.
library MNT6AteLoop {
    /// @dev Константа `FP_BYTES` фиксирует размер или число элементов сериализованного формата.
    uint256 internal constant FP_BYTES = 96;
    /// @dev Константа `FQ3_BYTES` фиксирует размер или число элементов сериализованного формата.
    uint256 internal constant FQ3_BYTES = 288;
    /// @dev Константа `DBL_STEP_BYTES` фиксирует размер или число элементов сериализованного формата.
    uint256 internal constant DBL_STEP_BYTES = 1152;
    /// @dev Константа `ADD_STEP_BYTES` фиксирует размер или число элементов сериализованного формата.
    uint256 internal constant ADD_STEP_BYTES = 576;
    /// @dev Константа `MNT6_DBL_COUNT` фиксирует размер или число элементов сериализованного формата.
    uint256 internal constant MNT6_DBL_COUNT = 376;
    /// @dev Константа `MNT6_ADD_COUNT` фиксирует размер или число элементов сериализованного формата.
    uint256 internal constant MNT6_ADD_COUNT = 123;

    struct DoubleCoeff {
        MNT6PairingTypes.Fq3 cH;
        MNT6PairingTypes.Fq3 c4C;
        MNT6PairingTypes.Fq3 cJ;
        MNT6PairingTypes.Fq3 cL;
    }

    struct AddCoeff {
        MNT6PairingTypes.Fq3 cL1;
        MNT6PairingTypes.Fq3 cRZ;
    }

    /// @notice Signed ate loop digits for ark-mnt6-753, excluding the leading digit.
    function loopDigit(uint256 i) internal pure returns (int8) {
        uint256 j = i;
        uint256 plus;
        uint256 minus;
        if (i < 256) {
            plus = 0x11442022552800221001014008902a04a00140801008080100024420040a12a;
            minus = 0xa8410820000009208800448042202801004001424448222481400100540a0800;
        } else {
            j = i - 256;
            plus = 0x44042028014100942020a0a220;
            minus = 0x10120008090100a000284020080;
        }
        uint256 mask = 1 << j;
        if (plus & mask != 0) return 1;
        if (minus & mask != 0) return -1;
        return 0;
    }

    /// @notice Формирует подготовленные данные `millerLoopPrepared`, которые затем переиспользуются в цикле Миллера.
    function millerLoopPrepared(
        MNT6PairingTypes.G1Point memory p,
        MNT6PairingTypes.Fq3 memory qXOverTwist,
        MNT6PairingTypes.Fq3 memory qYOverTwist,
        DoubleCoeff[] memory doubles,
        AddCoeff[] memory adds
    ) internal pure returns (MNT6PairingTypes.Fq6 memory f) {
        f = MNT6Fq6.one();
        MNT6PairingTypes.Fq3 memory pXTwist = _twistByFp(p.x);
        MNT6PairingTypes.Fq3 memory pYTwist = _twistByFp(p.y);
        MNT6PairingTypes.Fq3 memory l1Coeff = MNT6Fq3.sub(_fpAsFq3C0(p.x), qXOverTwist);
        MNT6PairingTypes.Fq3 memory yOverTwistNeg = MNT6Fq3.neg(qYOverTwist);
        uint256 addIdx = 0;
        for (uint256 i = 0; i < doubles.length; i++) {
            DoubleCoeff memory dc = doubles[i];
            MNT6PairingTypes.Fq3 memory g0 = MNT6Fq3.sub(MNT6Fq3.sub(dc.cL, dc.c4C), MNT6Fq3.mul(dc.cJ, pXTwist));
            MNT6PairingTypes.Fq3 memory g1 = MNT6Fq3.mul(dc.cH, pYTwist);
            f = MNT6Fq6.mulByLine(MNT6Fq6.sqr(f), g0, g1);

            int8 bit = loopDigit(i);
            if (bit == 1) {
                AddCoeff memory ac = adds[addIdx++];
                f = MNT6Fq6.mul(f, _addLine(qYOverTwist, l1Coeff, pYTwist, ac));
            } else if (bit == -1) {
                AddCoeff memory acn = adds[addIdx++];
                f = MNT6Fq6.mul(f, _addLine(yOverTwistNeg, l1Coeff, pYTwist, acn));
            }
        }
    }

    /// @notice Формирует подготовленные данные `millerLoopPreparedBlob`, которые затем переиспользуются в цикле Миллера.
    function millerLoopPreparedBlob(
        MNT6PairingTypes.G1Point memory p,
        MNT6PairingTypes.Fq3 memory qXOverTwist,
        MNT6PairingTypes.Fq3 memory qYOverTwist,
        bytes calldata dblBlob,
        bytes calldata addBlob
    ) internal pure returns (MNT6PairingTypes.Fq6 memory f) {
        require(dblBlob.length == MNT6_DBL_COUNT * DBL_STEP_BYTES, "bad dbl blob");
        require(addBlob.length == MNT6_ADD_COUNT * ADD_STEP_BYTES, "bad add blob");

        f = MNT6Fq6.one();
        MNT6PairingTypes.Fq3 memory pXTwist = _twistByFp(p.x);
        MNT6PairingTypes.Fq3 memory pYTwist = _twistByFp(p.y);
        MNT6PairingTypes.Fq3 memory l1Coeff = MNT6Fq3.sub(_fpAsFq3C0(p.x), qXOverTwist);
        MNT6PairingTypes.Fq3 memory yOverTwistNeg = MNT6Fq3.neg(qYOverTwist);
        uint256 addIdx = 0;

        for (uint256 i = 0; i < MNT6_DBL_COUNT; i++) {
            DoubleCoeff memory dc = _loadDoubleCoeff(dblBlob, i * DBL_STEP_BYTES);
            MNT6PairingTypes.Fq3 memory g0 = MNT6Fq3.sub(MNT6Fq3.sub(dc.cL, dc.c4C), MNT6Fq3.mul(dc.cJ, pXTwist));
            MNT6PairingTypes.Fq3 memory g1 = MNT6Fq3.mul(dc.cH, pYTwist);
            f = MNT6Fq6.mulByLine(MNT6Fq6.sqr(f), g0, g1);

            int8 bit = loopDigit(i);
            if (bit == 1) {
                AddCoeff memory ac = _loadAddCoeff(addBlob, addIdx * ADD_STEP_BYTES);
                addIdx++;
                f = MNT6Fq6.mul(f, _addLine(qYOverTwist, l1Coeff, pYTwist, ac));
            } else if (bit == -1) {
                AddCoeff memory acn = _loadAddCoeff(addBlob, addIdx * ADD_STEP_BYTES);
                addIdx++;
                f = MNT6Fq6.mul(f, _addLine(yOverTwistNeg, l1Coeff, pYTwist, acn));
            }
        }
    }

    /// @notice Same prepared Miller loop as `millerLoopPreparedBlob`, but with a packed scratch arena.
    /// @dev The function deliberately keeps Fq3/Fq6 values as pointer-addressed words in one arena.
    ///      It avoids constructing `DoubleCoeff`, `AddCoeff`, `Fq3`, and `Fq6` memory structs inside
    ///      the hot loop. The mathematical formulas are identical to the struct implementation above.
    function millerLoopPreparedBlobPacked(
        MNT6PairingTypes.G1Point memory p,
        MNT6PairingTypes.Fq3 memory qXOverTwist,
        MNT6PairingTypes.Fq3 memory qYOverTwist,
        bytes calldata dblBlob,
        bytes calldata addBlob
    ) internal pure returns (MNT6PairingTypes.Fq6 memory) {
        require(dblBlob.length == MNT6_DBL_COUNT * DBL_STEP_BYTES, "bad dbl blob");
        require(addBlob.length == MNT6_ADD_COUNT * ADD_STEP_BYTES, "bad add blob");

        uint256 base = MNT6PackedArithmetic.arenaPtr(384);
        uint256 f = base;
        uint256 fSqr = base + 0x240;
        uint256 next = base + 0x480;
        uint256 pXTwist = base + 0x6c0;
        uint256 pYTwist = base + 0x7e0;
        uint256 qX = base + 0x900;
        uint256 qY = base + 0xa20;
        uint256 l1 = base + 0xb40;
        uint256 yNeg = base + 0xc60;
        uint256 cH = base + 0xd80;
        uint256 c4C = base + 0xea0;
        uint256 cJ = base + 0xfc0;
        uint256 cL = base + 0x10e0;
        uint256 addL1 = base + 0x1200;
        uint256 addRZ = base + 0x1320;
        uint256 g0 = base + 0x1440;
        uint256 g1 = base + 0x1560;
        uint256 tmp3 = base + 0x1680;
        uint256 scratch = base + 0x17a0;

        MNT6PackedArithmetic.fq6OneTo(f);

        MNT6PackedArithmetic.zeroTo(pXTwist, 0x120);
        MNT6PackedArithmetic.fpStoreTo(pXTwist + 0x60, p.x);
        MNT6PackedArithmetic.zeroTo(pYTwist, 0x120);
        MNT6PackedArithmetic.fpStoreTo(pYTwist + 0x60, p.y);
        MNT6PackedArithmetic.fq3StoreTo(qX, qXOverTwist);
        MNT6PackedArithmetic.fq3StoreTo(qY, qYOverTwist);

        MNT6PackedArithmetic.zeroTo(tmp3, 0x120);
        MNT6PackedArithmetic.fpStoreTo(tmp3, p.x);
        MNT6PackedArithmetic.fq3SubTo(l1, tmp3, qX);
        MNT6PackedArithmetic.fq3NegTo(yNeg, qY);

        uint256 addIdx = 0;
        for (uint256 i = 0; i < MNT6_DBL_COUNT; i++) {
            uint256 dblOff = i * DBL_STEP_BYTES;
            MNT6PackedArithmetic.loadFq3FromCalldataBETo(cH, dblBlob, dblOff);
            MNT6PackedArithmetic.loadFq3FromCalldataBETo(c4C, dblBlob, dblOff + FQ3_BYTES);
            MNT6PackedArithmetic.loadFq3FromCalldataBETo(cJ, dblBlob, dblOff + 2 * FQ3_BYTES);
            MNT6PackedArithmetic.loadFq3FromCalldataBETo(cL, dblBlob, dblOff + 3 * FQ3_BYTES);

            // Double line: g0 = (cL - c4C) - cJ * (P.x * twist), g1 = cH * (P.y * twist).
            MNT6PackedArithmetic.fq3SubTo(g0, cL, c4C);
            MNT6PackedArithmetic.fq3MulTo(g1, cJ, pXTwist, scratch);
            MNT6PackedArithmetic.fq3SubTo(g0, g0, g1);
            MNT6PackedArithmetic.fq3MulTo(g1, cH, pYTwist, scratch);

            // Fused горячего пути: f <- f^2 * (g0 + g1*w).
            MNT6PackedArithmetic.fq6SqrTo(fSqr, f, scratch);
            MNT6PackedArithmetic.fq6MulByLineTo(next, fSqr, g0, g1, scratch);
            (f, next) = (next, f);

            int8 bit = loopDigit(i);
            if (bit != 0) {
                uint256 addOff = addIdx * ADD_STEP_BYTES;
                addIdx++;
                MNT6PackedArithmetic.loadFq3FromCalldataBETo(addL1, addBlob, addOff);
                MNT6PackedArithmetic.loadFq3FromCalldataBETo(addRZ, addBlob, addOff + FQ3_BYTES);

                // Addition line:
                // g0 = cRZ * (P.y * twist)
                // g1 = -(sign(Q.y/twist) * cRZ + l1 * cL1)
                MNT6PackedArithmetic.fq3MulTo(g0, addRZ, pYTwist, scratch);
                MNT6PackedArithmetic.fq3MulTo(g1, bit == 1 ? qY : yNeg, addRZ, scratch);
                MNT6PackedArithmetic.fq3MulTo(tmp3, l1, addL1, scratch);
                MNT6PackedArithmetic.fq3AddTo(g1, g1, tmp3);
                MNT6PackedArithmetic.fq3NegTo(g1, g1);
                MNT6PackedArithmetic.fq6MulByLineTo(next, f, g0, g1, scratch);
                (f, next) = (next, f);
            }
        }

        return MNT6PackedArithmetic.fq6Load(f);
    }

    /// @notice Формирует подготовленные данные `millerLoopPreparedBlobPackedResidue`, которые затем переиспользуются в цикле Миллера.
    function millerLoopPreparedBlobPackedResidue(
        MNT6PairingTypes.G1Point memory p,
        MNT6PairingTypes.Fq3 memory qXOverTwist,
        MNT6PairingTypes.Fq3 memory qYOverTwist,
        MNT6PairingTypes.Fq6 memory c,
        MNT6PairingTypes.Fq6 memory cInv,
        bytes calldata dblBlob,
        bytes calldata addBlob
    ) internal pure returns (MNT6PairingTypes.Fq6 memory) {
        require(dblBlob.length == MNT6_DBL_COUNT * DBL_STEP_BYTES, "bad dbl blob");
        require(addBlob.length == MNT6_ADD_COUNT * ADD_STEP_BYTES, "bad add blob");

        uint256 base = MNT6PackedArithmetic.arenaPtr(432);
        uint256 f = base;
        uint256 fSqr = base + 0x240;
        uint256 next = base + 0x480;
        uint256 pXTwist = base + 0x6c0;
        uint256 pYTwist = base + 0x7e0;
        uint256 qX = base + 0x900;
        uint256 qY = base + 0xa20;
        uint256 l1 = base + 0xb40;
        uint256 yNeg = base + 0xc60;
        uint256 cH = base + 0xd80;
        uint256 c4C = base + 0xea0;
        uint256 cJ = base + 0xfc0;
        uint256 cL = base + 0x10e0;
        uint256 addL1 = base + 0x1200;
        uint256 addRZ = base + 0x1320;
        uint256 g0 = base + 0x1440;
        uint256 g1 = base + 0x1560;
        uint256 tmp3 = base + 0x1680;
        uint256 pC = base + 0x17a0;
        uint256 pCInv = base + 0x19e0;
        uint256 pCInvQ = base + 0x1c20;
        uint256 scratch = base + 0x1e60;

        MNT6PackedArithmetic.fq6StoreTo(pC, c);
        MNT6PackedArithmetic.fq6StoreTo(pCInv, cInv);
        MNT6PackedArithmetic.fq6CopyTo(f, pCInv);

        MNT6PackedArithmetic.zeroTo(pXTwist, 0x120);
        MNT6PackedArithmetic.fpStoreTo(pXTwist + 0x60, p.x);
        MNT6PackedArithmetic.zeroTo(pYTwist, 0x120);
        MNT6PackedArithmetic.fpStoreTo(pYTwist + 0x60, p.y);
        MNT6PackedArithmetic.fq3StoreTo(qX, qXOverTwist);
        MNT6PackedArithmetic.fq3StoreTo(qY, qYOverTwist);

        MNT6PackedArithmetic.zeroTo(tmp3, 0x120);
        MNT6PackedArithmetic.fpStoreTo(tmp3, p.x);
        MNT6PackedArithmetic.fq3SubTo(l1, tmp3, qX);
        MNT6PackedArithmetic.fq3NegTo(yNeg, qY);

        uint256 addIdx = 0;
        for (uint256 i = 0; i < MNT6_DBL_COUNT; i++) {
            uint256 dblOff = i * DBL_STEP_BYTES;
            MNT6PackedArithmetic.loadFq3FromCalldataBETo(cH, dblBlob, dblOff);
            MNT6PackedArithmetic.loadFq3FromCalldataBETo(c4C, dblBlob, dblOff + FQ3_BYTES);
            MNT6PackedArithmetic.loadFq3FromCalldataBETo(cJ, dblBlob, dblOff + 2 * FQ3_BYTES);
            MNT6PackedArithmetic.loadFq3FromCalldataBETo(cL, dblBlob, dblOff + 3 * FQ3_BYTES);

            MNT6PackedArithmetic.fq3SubTo(g0, cL, c4C);
            MNT6PackedArithmetic.fq3MulTo(g1, cJ, pXTwist, scratch);
            MNT6PackedArithmetic.fq3SubTo(g0, g0, g1);
            MNT6PackedArithmetic.fq3MulTo(g1, cH, pYTwist, scratch);

            MNT6PackedArithmetic.fq6SqrTo(fSqr, f, scratch);
            MNT6PackedArithmetic.fq6MulByLineTo(next, fSqr, g0, g1, scratch);
            (f, next) = (next, f);

            int8 bit = loopDigit(i);
            if (bit != 0) {
                uint256 addOff = addIdx * ADD_STEP_BYTES;
                addIdx++;
                MNT6PackedArithmetic.loadFq3FromCalldataBETo(addL1, addBlob, addOff);
                MNT6PackedArithmetic.loadFq3FromCalldataBETo(addRZ, addBlob, addOff + FQ3_BYTES);

                MNT6PackedArithmetic.fq3MulTo(g0, addRZ, pYTwist, scratch);
                MNT6PackedArithmetic.fq3MulTo(g1, bit == 1 ? qY : yNeg, addRZ, scratch);
                MNT6PackedArithmetic.fq3MulTo(tmp3, l1, addL1, scratch);
                MNT6PackedArithmetic.fq3AddTo(g1, g1, tmp3);
                MNT6PackedArithmetic.fq3NegTo(g1, g1);
                MNT6PackedArithmetic.fq6MulByLineTo(next, f, g0, g1, scratch);
                MNT6PackedArithmetic.fq6MulTo(f, next, bit == 1 ? pCInv : pC, scratch);
            }
        }

        MNT6PackedArithmetic.fq6StoreTo(pCInvQ, MNT6Fq6.frobeniusMap(cInv, 1));
        MNT6PackedArithmetic.fq6MulTo(next, f, pCInvQ, scratch);
        return MNT6PackedArithmetic.fq6Load(next);
    }

    /// @notice Формирует подготовленные данные `millerLoopPreparedBlobMem`, которые затем переиспользуются в цикле Миллера.
    function millerLoopPreparedBlobMem(
        MNT6PairingTypes.G1Point memory p,
        MNT6PairingTypes.Fq3 memory qXOverTwist,
        MNT6PairingTypes.Fq3 memory qYOverTwist,
        bytes memory dblBlob,
        bytes memory addBlob
    ) internal pure returns (MNT6PairingTypes.Fq6 memory f) {
        require(dblBlob.length == MNT6_DBL_COUNT * DBL_STEP_BYTES, "bad dbl blob");
        require(addBlob.length == MNT6_ADD_COUNT * ADD_STEP_BYTES, "bad add blob");

        f = MNT6Fq6.one();
        MNT6PairingTypes.Fq3 memory pXTwist = _twistByFp(p.x);
        MNT6PairingTypes.Fq3 memory pYTwist = _twistByFp(p.y);
        MNT6PairingTypes.Fq3 memory l1Coeff = MNT6Fq3.sub(_fpAsFq3C0(p.x), qXOverTwist);
        MNT6PairingTypes.Fq3 memory yOverTwistNeg = MNT6Fq3.neg(qYOverTwist);
        uint256 addIdx = 0;

        for (uint256 i = 0; i < MNT6_DBL_COUNT; i++) {
            DoubleCoeff memory dc = _loadDoubleCoeffMem(dblBlob, i * DBL_STEP_BYTES);
            MNT6PairingTypes.Fq3 memory g0 = MNT6Fq3.sub(MNT6Fq3.sub(dc.cL, dc.c4C), MNT6Fq3.mul(dc.cJ, pXTwist));
            MNT6PairingTypes.Fq3 memory g1 = MNT6Fq3.mul(dc.cH, pYTwist);
            f = MNT6Fq6.mulByLine(MNT6Fq6.sqr(f), g0, g1);

            int8 bit = loopDigit(i);
            if (bit == 1) {
                AddCoeff memory ac = _loadAddCoeffMem(addBlob, addIdx * ADD_STEP_BYTES);
                addIdx++;
                f = MNT6Fq6.mul(f, _addLine(qYOverTwist, l1Coeff, pYTwist, ac));
            } else if (bit == -1) {
                AddCoeff memory acn = _loadAddCoeffMem(addBlob, addIdx * ADD_STEP_BYTES);
                addIdx++;
                f = MNT6Fq6.mul(f, _addLine(yOverTwistNeg, l1Coeff, pYTwist, acn));
            }
        }
    }

    /// @notice Формирует подготовленные данные `millerLoopPreparedCodeStreaming`, которые затем переиспользуются в цикле Миллера.
    function millerLoopPreparedCodeStreaming(
        MNT6PairingTypes.G1Point memory p,
        MNT6PairingTypes.Fq3 memory qXOverTwist,
        MNT6PairingTypes.Fq3 memory qYOverTwist,
        address dblData,
        uint256 dblLen,
        address addData,
        uint256 addLen
    ) internal view returns (MNT6PairingTypes.Fq6 memory f) {
        require(dblLen == MNT6_DBL_COUNT * DBL_STEP_BYTES, "bad dbl code");
        require(addLen == MNT6_ADD_COUNT * ADD_STEP_BYTES, "bad add code");

        f = MNT6Fq6.one();
        MNT6PairingTypes.Fq3 memory pXTwist = _twistByFp(p.x);
        MNT6PairingTypes.Fq3 memory pYTwist = _twistByFp(p.y);
        MNT6PairingTypes.Fq3 memory l1Coeff = MNT6Fq3.sub(_fpAsFq3C0(p.x), qXOverTwist);
        MNT6PairingTypes.Fq3 memory yOverTwistNeg = MNT6Fq3.neg(qYOverTwist);
        uint256 addIdx = 0;

        for (uint256 i = 0; i < MNT6_DBL_COUNT; i++) {
            DoubleCoeff memory dc = _loadDoubleCoeffMem(_copyCodeSlice(dblData, i * DBL_STEP_BYTES, DBL_STEP_BYTES), 0);
            MNT6PairingTypes.Fq3 memory g0 = MNT6Fq3.sub(MNT6Fq3.sub(dc.cL, dc.c4C), MNT6Fq3.mul(dc.cJ, pXTwist));
            MNT6PairingTypes.Fq3 memory g1 = MNT6Fq3.mul(dc.cH, pYTwist);
            f = MNT6Fq6.mulByLine(MNT6Fq6.sqr(f), g0, g1);

            int8 bit = loopDigit(i);
            if (bit == 1) {
                AddCoeff memory ac = _loadAddCoeffMem(_copyCodeSlice(addData, addIdx * ADD_STEP_BYTES, ADD_STEP_BYTES), 0);
                addIdx++;
                f = MNT6Fq6.mul(f, _addLine(qYOverTwist, l1Coeff, pYTwist, ac));
            } else if (bit == -1) {
                AddCoeff memory acn = _loadAddCoeffMem(_copyCodeSlice(addData, addIdx * ADD_STEP_BYTES, ADD_STEP_BYTES), 0);
                addIdx++;
                f = MNT6Fq6.mul(f, _addLine(yOverTwistNeg, l1Coeff, pYTwist, acn));
            }
        }
    }

    /// @notice Выполняет сложение `_addLine` с учетом модуля или структуры текущего поля.
    function _addLine(
        MNT6PairingTypes.Fq3 memory yOverTwist,
        MNT6PairingTypes.Fq3 memory l1Coeff,
        MNT6PairingTypes.Fq3 memory pYTwist,
        AddCoeff memory ac
    ) private pure returns (MNT6PairingTypes.Fq6 memory g) {
        g.c0 = MNT6Fq3.mul(ac.cRZ, pYTwist);
        g.c1 = MNT6Fq3.neg(MNT6Fq3.add(MNT6Fq3.mul(yOverTwist, ac.cRZ), MNT6Fq3.mul(l1Coeff, ac.cL1)));
    }

    /// @notice Выполняет внутреннюю операцию `_twistByFp`; параметры и результат используют представление текущей библиотеки.
    function _twistByFp(MNT6PairingTypes.Fp memory x) private pure returns (MNT6PairingTypes.Fq3 memory r) {
        r.c1 = x;
    }

    /// @notice Выполняет внутреннюю операцию `_fpAsFq3C0`; параметры и результат используют представление текущей библиотеки.
    function _fpAsFq3C0(MNT6PairingTypes.Fp memory x) private pure returns (MNT6PairingTypes.Fq3 memory r) {
        r.c0 = x;
    }

    /// @notice Выполняет сложение `_loadDoubleCoeff` с учетом модуля или структуры текущего поля.
    function _loadDoubleCoeff(bytes calldata blob, uint256 off) private pure returns (DoubleCoeff memory dc) {
        dc.cH = _loadFq3(blob, off);
        dc.c4C = _loadFq3(blob, off + FQ3_BYTES);
        dc.cJ = _loadFq3(blob, off + 2 * FQ3_BYTES);
        dc.cL = _loadFq3(blob, off + 3 * FQ3_BYTES);
    }

    /// @notice Выполняет сложение `_loadAddCoeff` с учетом модуля или структуры текущего поля.
    function _loadAddCoeff(bytes calldata blob, uint256 off) private pure returns (AddCoeff memory ac) {
        ac.cL1 = _loadFq3(blob, off);
        ac.cRZ = _loadFq3(blob, off + FQ3_BYTES);
    }

    /// @notice Читает подготовленные данные из указанного источника: `_loadFq3`.
    function _loadFq3(bytes calldata blob, uint256 off) private pure returns (MNT6PairingTypes.Fq3 memory r) {
        r.c0 = _loadFp(blob, off);
        r.c1 = _loadFp(blob, off + FP_BYTES);
        r.c2 = _loadFp(blob, off + 2 * FP_BYTES);
    }

    /// @notice Читает подготовленные данные из указанного источника: `_loadFp`.
    function _loadFp(bytes calldata blob, uint256 off) private pure returns (MNT6PairingTypes.Fp memory r) {
        assembly ("memory-safe") {
            let src := add(blob.offset, off)
            mstore(r, calldataload(src))
            mstore(add(r, 0x20), calldataload(add(src, 0x20)))
            mstore(add(r, 0x40), calldataload(add(src, 0x40)))
        }
    }

    /// @notice Выполняет сложение `_loadDoubleCoeffMem` с учетом модуля или структуры текущего поля.
    function _loadDoubleCoeffMem(bytes memory blob, uint256 off) private pure returns (DoubleCoeff memory dc) {
        dc.cH = _loadFq3Mem(blob, off);
        dc.c4C = _loadFq3Mem(blob, off + FQ3_BYTES);
        dc.cJ = _loadFq3Mem(blob, off + 2 * FQ3_BYTES);
        dc.cL = _loadFq3Mem(blob, off + 3 * FQ3_BYTES);
    }

    /// @notice Выполняет сложение `_loadAddCoeffMem` с учетом модуля или структуры текущего поля.
    function _loadAddCoeffMem(bytes memory blob, uint256 off) private pure returns (AddCoeff memory ac) {
        ac.cL1 = _loadFq3Mem(blob, off);
        ac.cRZ = _loadFq3Mem(blob, off + FQ3_BYTES);
    }

    /// @notice Читает подготовленные данные из указанного источника: `_loadFq3Mem`.
    function _loadFq3Mem(bytes memory blob, uint256 off) private pure returns (MNT6PairingTypes.Fq3 memory r) {
        r.c0 = _loadFpMem(blob, off);
        r.c1 = _loadFpMem(blob, off + FP_BYTES);
        r.c2 = _loadFpMem(blob, off + 2 * FP_BYTES);
    }

    /// @notice Читает подготовленные данные из указанного источника: `_loadFpMem`.
    function _loadFpMem(bytes memory blob, uint256 off) private pure returns (MNT6PairingTypes.Fp memory r) {
        assembly ("memory-safe") {
            let src := add(add(blob, 0x20), off)
            mstore(r, mload(src))
            mstore(add(r, 0x20), mload(add(src, 0x20)))
            mstore(add(r, 0x40), mload(add(src, 0x40)))
        }
    }

    /// @notice Копирует представление значения между буферами памяти: `_copyCodeSlice`.
    function _copyCodeSlice(address dataContract, uint256 off, uint256 len) private view returns (bytes memory out) {
        out = new bytes(len);
        assembly ("memory-safe") {
            extcodecopy(dataContract, add(out, 0x20), off, len)
        }
    }
}
