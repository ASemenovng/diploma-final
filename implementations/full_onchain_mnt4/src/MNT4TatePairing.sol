// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import "@arith-mnt4/BigIntMNT.sol";
import "@arith-mnt4/MNT4Extension.sol";

/// @notice Низкоуровневая библиотека Tate/ate-сопряжения MNT4-753 для полного on-chain ориентира.
/// @dev В одном модуле собран оптимизированный указательный Yul-путь. Он служит эталоном
///      для измерения стоимости цикла Миллера, подготовленных линий и финальной экспоненты.
library MNT4TatePairing {
    struct G1Affine {
        uint256[3] x;
        uint256[3] y;
    }

    struct G2Affine {
        MNT4ExtensionFinal.Fq2 x;
        MNT4ExtensionFinal.Fq2 y;
    }

    struct G2ProjectiveExtended {
        MNT4ExtensionFinal.Fq2 x;
        MNT4ExtensionFinal.Fq2 y;
        MNT4ExtensionFinal.Fq2 z;
        MNT4ExtensionFinal.Fq2 t;
    }

    struct AteDoubleCoefficients {
        MNT4ExtensionFinal.Fq2 c_h;
        MNT4ExtensionFinal.Fq2 c_4c;
        MNT4ExtensionFinal.Fq2 c_j;
        MNT4ExtensionFinal.Fq2 c_l;
    }

    struct AteAdditionCoefficients {
        MNT4ExtensionFinal.Fq2 c_l1;
        MNT4ExtensionFinal.Fq2 c_rz;
    }

    /// @dev Константа `ONE_MONT_0` содержит соответствующее слово единицы в Montgomery-представлении.
    uint256 private constant ONE_MONT_0 = 0x79589819c788b60197c3e4a0cd14572e91cd31c65a03468698a8ecabd9dc6f42;
    /// @dev Константа `ONE_MONT_1` содержит соответствующее слово единицы в Montgomery-представлении.
    uint256 private constant ONE_MONT_1 = 0x598b4302d2f00a62320c3bb7133385591e0f4d8acf031d68ed269c942108976f;
    /// @dev Константа `ONE_MONT_2` содержит соответствующее слово единицы в Montgomery-представлении.
    uint256 private constant ONE_MONT_2 = 0x7b479ec8e24295455fb31ff9a1950fa47edb3865e88c4074c9cbfd8ca621;

    // Коэффициент A скрученной кривой: (26, 0) в Fq2, в Montgomery-представлении.
    uint256 private constant TWIST_A_C0_0 = 0x7883d83c06c22baab12cc53998b3d1249589bfe5ea49ae4feb354e6121cdccad;
    /// @dev Константа `TWIST_A_C0_1` является параметром кривой или поля расширения в Montgomery-представлении.
    uint256 private constant TWIST_A_C0_1 = 0xe034be400ffa8f19e0860ea489bec5bd35e68bd867a8d5580d828782cb96edc7;
    /// @dev Константа `TWIST_A_C0_2` является параметром кривой или поля расширения в Montgomery-представлении.
    uint256 private constant TWIST_A_C0_2 = 0x23dae1639e4bb819c73cb726c9638ee1bf11396bcec0f4d51fe5c821f43d;

    // Обратный twist: (0, 13^{-1}) в Fq2, в Montgomery-представлении.
    uint256 private constant INV13_MONT_0 = 0xb6ed664d48f4b88f9124006c9dbd479ecbc586f483fae0c0690f840802a95754;
    /// @dev Константа `INV13_MONT_1` фиксирует параметр алгоритма; значение не изменяется во время выполнения.
    uint256 private constant INV13_MONT_1 = 0x6a943554d18daf3107d259082dfe440b6c539fba83f03e34072cabaebf5c4673;
    /// @dev Константа `INV13_MONT_2` фиксирует параметр алгоритма; значение не изменяется во время выполнения.
    uint256 private constant INV13_MONT_2 = 0x4f23ff887e56841e589cffd3a239e26e210988941942ffd682225f49908a;

    // Коэффициенты отображения Фробениуса в Montgomery-представлении.
    uint256 private constant FROB_FQ2_C1_1_0 = 0xef0234cfaee99ea2cbc42bd0cdafcec251d0228bd2d9cb18c5e777324a8210bf;
    /// @dev Константа `FROB_FQ2_C1_1_1` является параметром кривой или поля расширения в Montgomery-представлении.
    uint256 private constant FROB_FQ2_C1_1_1 = 0xae72762315b0e32b67c4e9228e277244930899ec2314e834cae87111aa4ae6c8;
    /// @dev Константа `FROB_FQ2_C1_1_2` является параметром кривой или поля расширения в Montgomery-представлении.
    uint256 private constant FROB_FQ2_C1_1_2 = 0x1497e8ec9e1ce7add306fcee92c18a85518752329c7611e431f2d6f0b3251;

    /// @dev Константа `FROB_FQ4_C1_1_0` является параметром кривой или поля расширения в Montgomery-представлении.
    uint256 private constant FROB_FQ4_C1_1_0 = 0x580f0950ee2d0f91c729995df0c170781e27fd3b9ead8a2c25eac118209420db;
    /// @dev Константа `FROB_FQ4_C1_1_1` является параметром кривой или поля расширения в Montgomery-представлении.
    uint256 private constant FROB_FQ4_C1_1_1 = 0x19912707c043191ae6c206bb24a7f2be1a3253f2c75a19d12c5f103cbe99cc71;
    /// @dev Константа `FROB_FQ4_C1_1_2` является параметром кривой или поля расширения в Montgomery-представлении.
    uint256 private constant FROB_FQ4_C1_1_2 = 0x94c44a4e987210dbb90d8450ff4e0a0181e8fd0ad0bdbad8bbb7cc6e9c35;

    // Arkworks MNT4-753 ATE_LOOP_COUNT encoded as bytes: -1 => 0x00, 0 => 0x01, +1 => 0x02.
    bytes constant ATE_LOOP_ENC = hex"0201020102010201010201010001020102010001000101020101010001000100010102010101010201000102010102010101010101010100010001010102010100010100010100010201000101010001020101010001010001020100010101000101000102010100010001020102010101010101010101000101020102010102010001010101020102010201000100010102010102010001020100010101010001010102010201010001010001020100010101010101010101020101000102010001020101010001010001010001010102010201010201020102010201010201010102010101000101010201000101020100010201020100010201010001000100010101010102010001020101010201020100010101020102010100010102010001000101010201010101020102010102010001000101010102010101000102010201010100010100010101020102010001010101010201010101020101000101000102010101020100010101010101010101010101010101";
    /// @dev Константа `ATE_IS_LOOP_COUNT_NEG` фиксирует размер или число элементов сериализованного формата.
    bool private constant ATE_IS_LOOP_COUNT_NEG = true;

    // Абсолютное значение w0-части финальной экспоненты MNT4-753, слова от младшего к старшему.
    uint256 private constant W0ABS_0 = 0x51852c8cbe26e600733b714aa43c31a66b0344c4e2c428b07a7713041ba17fff;
    /// @dev Константа `W0ABS_1` фиксирует параметр алгоритма; значение не изменяется во время выполнения.
    uint256 private constant W0ABS_1 = 0x15474b1d641a3fd86dcbcee5dcda7fe;
    /// @dev Константа `W0ABS_1_BITS` фиксирует параметр алгоритма; значение не изменяется во время выполнения.
    uint256 private constant W0ABS_1_BITS = 121;
    /// @dev Константа `W0_IS_NEG` фиксирует параметр алгоритма; значение не изменяется во время выполнения.
    bool private constant W0_IS_NEG = true;
    // Фиксированная программа цепочки сложений для W0ABS со скользящим окном w=5.
    // В байте: старшая половина задает число возведений в квадрат, младшая — индекс нечетной степени; 0 означает отсутствие умножения.
    bytes private constant W0_CHAIN_W5 = hex"105b1010105f1010461010105f105d101010101047101010505f11101010105e103410105c5a5c10105c103410105e105a50341010331010102210101010331010461010594510501010105a1034101022101010101010101010103410105d5e10341010103310105b1045101010104810101010221010104710105d5b11101010101010471010105a1010105a59102210101011101010103310101046101010101048105a5c1010105a10101010101110101010105e33101010105c505022";

    // Генератор G2 кривой MNT4-753 в Montgomery-представлении.
    uint256 private constant G2_X_C0_0 = 0xf5199b0d7e333053db197417e18872316a123355ee93878564cd9e87e5f14e2d;
    /// @dev Константа `G2_X_C0_1` является параметром кривой или поля расширения в Montgomery-представлении.
    uint256 private constant G2_X_C0_1 = 0x1ea26a53c24e41623f8ccbdf316d6964d1117417b290f004397da434e85b78a7;
    /// @dev Константа `G2_X_C0_2` является параметром кривой или поля расширения в Montgomery-представлении.
    uint256 private constant G2_X_C0_2 = 0x13635a0d01b785b05c21a27b7acc73c355554caad25804fa40c8be29a9276;
    /// @dev Константа `G2_X_C1_0` является параметром кривой или поля расширения в Montgomery-представлении.
    uint256 private constant G2_X_C1_0 = 0xe67355775c8eb87e9217aa6ceb0cf80802b8029c87df25f6b56fc312dc34c98b;
    /// @dev Константа `G2_X_C1_1` является параметром кривой или поля расширения в Montgomery-представлении.
    uint256 private constant G2_X_C1_1 = 0xf1e11281b99054d1de8489295782a1036bebff63e88338c290eb471ebb74c1b1;
    /// @dev Константа `G2_X_C1_2` является параметром кривой или поля расширения в Montgomery-представлении.
    uint256 private constant G2_X_C1_2 = 0x16aea1ba33dc031facd7fa4614cca6ec60806cb661af7071e05664c68aa32;
    /// @dev Константа `G2_Y_C0_0` является параметром кривой или поля расширения в Montgomery-представлении.
    uint256 private constant G2_Y_C0_0 = 0x36739870b33ba70fa567a1375a9e2a27220b34b2b9daee2f438d727bf4c5002e;
    /// @dev Константа `G2_Y_C0_1` является параметром кривой или поля расширения в Montgomery-представлении.
    uint256 private constant G2_Y_C0_1 = 0xe526639d49ef3efff64a68ade535340fdb048df87997b3b7b058c55679b63f3e;
    /// @dev Константа `G2_Y_C0_2` является параметром кривой или поля расширения в Montgomery-представлении.
    uint256 private constant G2_Y_C0_2 = 0x1202d1e47ccef4f6af38904883c288e46b4ca897b87bbd52be2d6e4bee8fd;
    /// @dev Константа `G2_Y_C1_0` является параметром кривой или поля расширения в Montgomery-представлении.
    uint256 private constant G2_Y_C1_0 = 0xbbf8387b3a74937a6a393d84e066ddfca41dbc2a99750c11f06781d5bec3ed74;
    /// @dev Константа `G2_Y_C1_1` является параметром кривой или поля расширения в Montgomery-представлении.
    uint256 private constant G2_Y_C1_1 = 0x92e8c3c2f80404545c089d226f9c345d380c74d14f4e2d84ecb6da0ba28e9879;
    /// @dev Константа `G2_Y_C1_2` является параметром кривой или поля расширения в Montgomery-представлении.
    uint256 private constant G2_Y_C1_2 = 0x11e7b5c581fa35de638cd06f1c4e659a934e501a154debf6ce50f1d3555;

    // Предварительно вычисленные константы режима fixed-Q.
    uint256 private constant ADD_STEPS = 123;
    /// @dev Константа `ADD_STEPS_WITH_NEG` фиксирует параметр алгоритма; значение не изменяется во время выполнения.
    uint256 private constant ADD_STEPS_WITH_NEG = 124;
    /// @dev Константа `FP3_BYTES` фиксирует размер или число элементов сериализованного формата.
    uint256 private constant FP3_BYTES = 0x60;
    /// @dev Константа `FQ2_BYTES` фиксирует размер или число элементов сериализованного формата.
    uint256 private constant FQ2_BYTES = 0xc0;
    /// @dev Константа `FQ4_BYTES` фиксирует размер или число элементов сериализованного формата.
    uint256 private constant FQ4_BYTES = 0x180;
    /// @dev Константа `WORD` фиксирует параметр алгоритма; значение не изменяется во время выполнения.
    uint256 private constant WORD = 0x20;
    /// @dev Константа `FP3_WORDS` фиксирует размер или число элементов сериализованного формата.
    uint256 private constant FP3_WORDS = 3;
    /// @dev Константа `FQ2_WORDS` фиксирует размер или число элементов сериализованного формата.
    uint256 private constant FQ2_WORDS = 6;
    /// @dev Константа `FQ4_WORDS` фиксирует размер или число элементов сериализованного формата.
    uint256 private constant FQ4_WORDS = 12;
    /// @dev Константа `DBL_SPARSE_FQ2_PER_STEP` фиксирует параметр алгоритма; значение не изменяется во время выполнения.
    uint256 private constant DBL_SPARSE_FQ2_PER_STEP = 3;
    /// @dev Константа `ADD_SPARSE_FQ2_PER_STEP` фиксирует параметр алгоритма; значение не изменяется во время выполнения.
    uint256 private constant ADD_SPARSE_FQ2_PER_STEP = 2;
    /// @dev Константа `DBL_SPARSE_STEP_BYTES` фиксирует размер или число элементов сериализованного формата.
    uint256 private constant DBL_SPARSE_STEP_BYTES = DBL_SPARSE_FQ2_PER_STEP * FQ2_BYTES;
    /// @dev Константа `ADD_SPARSE_STEP_BYTES` фиксирует размер или число элементов сериализованного формата.
    uint256 private constant ADD_SPARSE_STEP_BYTES = ADD_SPARSE_FQ2_PER_STEP * FQ2_BYTES;
    /// @dev Константа `DBL_SPARSE_STEP_WORDS` фиксирует размер или число элементов сериализованного формата.
    uint256 private constant DBL_SPARSE_STEP_WORDS = DBL_SPARSE_FQ2_PER_STEP * FQ2_WORDS;
    /// @dev Константа `ADD_SPARSE_STEP_WORDS` фиксирует размер или число элементов сериализованного формата.
    uint256 private constant ADD_SPARSE_STEP_WORDS = ADD_SPARSE_FQ2_PER_STEP * FQ2_WORDS;
    /// @dev Константа `FIXED_DBL_SPARSE_BYTES` фиксирует размер или число элементов сериализованного формата.
    uint256 private constant FIXED_DBL_SPARSE_BYTES = (377 - 1) * DBL_SPARSE_FQ2_PER_STEP * FQ2_BYTES;
    /// @dev Константа `FIXED_ADD_SPARSE_BYTES` фиксирует размер или число элементов сериализованного формата.
    uint256 private constant FIXED_ADD_SPARSE_BYTES = ADD_STEPS_WITH_NEG * ADD_SPARSE_FQ2_PER_STEP * FQ2_BYTES;

    // Координаты qx_over_twist и qy_over_twist для фиксированного генератора G2.
    uint256 private constant QXOT_C0_0 = 0xe67355775c8eb87e9217aa6ceb0cf80802b8029c87df25f6b56fc312dc34c98b;
    /// @dev Константа `QXOT_C0_1` задает слово модуля поля или связанный параметр редукции.
    uint256 private constant QXOT_C0_1 = 0xf1e11281b99054d1de8489295782a1036bebff63e88338c290eb471ebb74c1b1;
    /// @dev Константа `QXOT_C0_2` задает слово модуля поля или связанный параметр редукции.
    uint256 private constant QXOT_C0_2 = 0x00016aea1ba33dc031facd7fa4614cca6ec60806cb661af7071e05664c68aa32;
    /// @dev Константа `QXOT_C1_0` задает слово модуля поля или связанный параметр редукции.
    uint256 private constant QXOT_C1_0 = 0xc132dcb9d355314b46729ba178606bfbaa1b09f7c80c3b4c620ecbd0d6808604;
    /// @dev Константа `QXOT_C1_1` задает слово модуля поля или связанный параметр редукции.
    uint256 private constant QXOT_C1_1 = 0x2e0b447d512198a292ca373795c33eab6f70acf319f0b3067b3927ac1ce5398d;
    /// @dev Константа `QXOT_C1_2` задает слово модуля поля или связанный параметр редукции.
    uint256 private constant QXOT_C1_2 = 0x00010ba9e9d5309c4ac448d9bec354a7f18a7f6cde6e619d60835707383644bd;

    /// @dev Константа `QYOT_C0_0` задает слово модуля поля или связанный параметр редукции.
    uint256 private constant QYOT_C0_0 = 0xbbf8387b3a74937a6a393d84e066ddfca41dbc2a99750c11f06781d5bec3ed74;
    /// @dev Константа `QYOT_C0_1` задает слово модуля поля или связанный параметр редукции.
    uint256 private constant QYOT_C0_1 = 0x92e8c3c2f80404545c089d226f9c345d380c74d14f4e2d84ecb6da0ba28e9879;
    /// @dev Константа `QYOT_C0_2` задает слово модуля поля или связанный параметр редукции.
    uint256 private constant QYOT_C0_2 = 0x0000011e7b5c581fa35de638cd06f1c4e659a934e501a154debf6ce50f1d3555;
    /// @dev Константа `QYOT_C1_0` задает слово модуля поля или связанный параметр редукции.
    uint256 private constant QYOT_C1_0 = 0x18a1f813b17f54ca46b2752ff3ba11d5d05110cae4798f40ee7d7dfc8347313f;
    /// @dev Константа `QYOT_C1_1` задает слово модуля поля или связанный параметр редукции.
    uint256 private constant QYOT_C1_1 = 0x63783b2e5f28ea0f130764fe9e75d96541449f05c8ed8623680c9e466b41d2f3;
    /// @dev Константа `QYOT_C1_2` задает слово модуля поля или связанный параметр редукции.
    uint256 private constant QYOT_C1_2 = 0x0000c44fb1655b2ca9da718e2126a28102ef481acb54757d6fe7a621b1842a18;

    /// @dev Константа `QYOTN_C0_0` задает слово модуля поля или связанный параметр редукции.
    uint256 private constant QYOTN_C0_0 = 0xac62946e3bfdc129f94ed2ecba5d47f43f7f98279368058d6e28e208659a928d;
    /// @dev Константа `QYOTN_C0_1` задает слово модуля поля или связанный параметр редукции.
    uint256 private constant QYOTN_C0_1 = 0x7514f562f09ce9393dc887b731bec340790b72a5a2c9d818cb58339a28c4e5be;
    /// @dev Константа `QYOTN_C0_2` задает слово модуля поля или связанный параметр редукции.
    uint256 private constant QYOTN_C0_2 = 0x0001c3a7b2366bf16cc4a9ea21dbdbe8d19fee1b768e0e987ff87c145d7aa31d;
    /// @dev Константа `QYOTN_C1_0` задает слово модуля поля или связанный параметр редукции.
    uint256 private constant QYOTN_C1_0 = 0x4fb8d4d5c4f2ffda1cd59b41a70a141b134c43874863825e7012e5e1a1174ec2;
    /// @dev Константа `QYOTN_C1_1` задает слово модуля поля или связанный параметр редукции.
    uint256 private constant QYOTN_C1_1 = 0xa4857df78978037e86c9bfdb02e51e386fd34871292a7f7a50026f5f6011ab45;
    /// @dev Константа `QYOTN_C1_2` задает слово модуля поля или связанный параметр редукции.
    uint256 private constant QYOTN_C1_2 = 0x000100767c2d68e466481e94cdbc2b2cb50a4f35903b3a6feed042d7bb13ae5a;

    /// @notice Выполняет умножение `_fpMul`; точный уровень поля и специальный множитель отражены в названии.
    function _fpMul(
        uint256[3] memory a,
        uint256[3] memory b
    ) private pure returns (uint256[3] memory r) {
        (r[0], r[1], r[2]) = BigIntMNT.montMul3(a[0], a[1], a[2], b[0], b[1], b[2]);
    }

    /// @notice Возвращает единичный элемент в используемом представлении: `_fq2One`.
    function _fq2One() private pure returns (MNT4ExtensionFinal.Fq2 memory r) {
        r.c0[0] = ONE_MONT_0;
        r.c0[1] = ONE_MONT_1;
        r.c0[2] = ONE_MONT_2;
        r.c1[0] = 0;
        r.c1[1] = 0;
        r.c1[2] = 0;
    }

    /// @notice Возвращает единичный элемент в используемом представлении: `_fq4One`.
    function _fq4One() private pure returns (MNT4ExtensionFinal.Fq4 memory r) {
        r.c0 = _fq2One();
        r.c1.c0[0] = 0;
        r.c1.c0[1] = 0;
        r.c1.c0[2] = 0;
        r.c1.c1[0] = 0;
        r.c1.c1[1] = 0;
        r.c1.c1[2] = 0;
    }

    /// @notice Выполняет внутреннюю операцию `_fq2FromFp`; параметры и результат используют представление текущей библиотеки.
    function _fq2FromFp(uint256[3] memory a) private pure returns (MNT4ExtensionFinal.Fq2 memory r) {
        r.c0 = a;
        r.c1[0] = 0;
        r.c1[1] = 0;
        r.c1[2] = 0;
    }

    /// @notice Вычисляет аддитивно обратное значение: `_fq2Neg`.
    function _fq2Neg(MNT4ExtensionFinal.Fq2 memory a) private pure returns (MNT4ExtensionFinal.Fq2 memory r) {
        (r.c0[0], r.c0[1], r.c0[2]) = BigIntMNT.sub3(0, 0, 0, a.c0[0], a.c0[1], a.c0[2]);
        (r.c1[0], r.c1[1], r.c1[2]) = BigIntMNT.sub3(0, 0, 0, a.c1[0], a.c1[1], a.c1[2]);
    }

    // (a0 + a1*u) * (0 + s*u) with u^2 = 13.
    function _fq2MulByTwistFp(
        MNT4ExtensionFinal.Fq2 memory a,
        uint256[3] memory s
    ) private pure returns (MNT4ExtensionFinal.Fq2 memory r) {
        (uint256 t10, uint256 t11, uint256 t12) = BigIntMNT.montMul3(
            a.c1[0], a.c1[1], a.c1[2],
            s[0], s[1], s[2]
        );
        (r.c0[0], r.c0[1], r.c0[2]) = MNT4ExtensionFinal.fpMulBy13(t10, t11, t12);

        (r.c1[0], r.c1[1], r.c1[2]) = BigIntMNT.montMul3(
            a.c0[0], a.c0[1], a.c0[2],
            s[0], s[1], s[2]
        );
    }

    /// @notice Выполняет умножение `_fq2MulByTwistFpTo`; точный уровень поля и специальный множитель отражены в названии.
    function _fq2MulByTwistFpTo(
        MNT4ExtensionFinal.Fq2 memory out,
        MNT4ExtensionFinal.Fq2 memory a,
        uint256[3] memory s
    ) private pure {
        (uint256 t10, uint256 t11, uint256 t12) = BigIntMNT.montMul3(
            a.c1[0], a.c1[1], a.c1[2],
            s[0], s[1], s[2]
        );
        (out.c0[0], out.c0[1], out.c0[2]) = MNT4ExtensionFinal.fpMulBy13(t10, t11, t12);

        (out.c1[0], out.c1[1], out.c1[2]) = BigIntMNT.montMul3(
            a.c0[0], a.c0[1], a.c0[2],
            s[0], s[1], s[2]
        );
    }

    /// @notice Применяет отображение Фробениуса: `_fq2Frobenius1`.
    function _fq2Frobenius1(
        MNT4ExtensionFinal.Fq2 memory a
    ) private pure returns (MNT4ExtensionFinal.Fq2 memory r) {
        r.c0 = a.c0;
        (r.c1[0], r.c1[1], r.c1[2]) = BigIntMNT.montMul3(
            a.c1[0], a.c1[1], a.c1[2],
            FROB_FQ2_C1_1_0, FROB_FQ2_C1_1_1, FROB_FQ2_C1_1_2
        );
    }

    /// @notice Вычисляет сопряженный элемент расширения: `_fq4Conjugate`.
    function _fq4Conjugate(
        MNT4ExtensionFinal.Fq4 memory a
    ) private pure returns (MNT4ExtensionFinal.Fq4 memory r) {
        r.c0 = a.c0;
        r.c1 = _fq2Neg(a.c1);
    }

    /// @notice Вычисляет мультипликативно обратное значение: `_fq4InvToNewPtr`.
    function _fq4InvToNewPtr(uint256 aPtr) private pure returns (uint256 outPtr) {
        outPtr = _allocWords(12);
        uint256 pScratch = _allocWords(54);
        MNT4Extension.fq4InvTo(outPtr, aPtr, pScratch);
    }

    /// @notice Выполняет умножение `_fq4MulPtrAlloc`; точный уровень поля и специальный множитель отражены в названии.
    function _fq4MulPtrAlloc(
        MNT4ExtensionFinal.Fq4 memory a,
        MNT4ExtensionFinal.Fq4 memory b
    ) private pure returns (MNT4ExtensionFinal.Fq4 memory r) {
        r = _allocFq4();
        uint256 pScratch = _allocWords(54);
        MNT4Extension.fq4MulTo(_ptrFq4(r), _ptrFq4(a), _ptrFq4(b), pScratch);
    }

    /// @notice Вычисляет сопряженный элемент расширения: `_fq4ConjugatePtrTo`.
    function _fq4ConjugatePtrTo(uint256 outPtr, uint256 aPtr) private pure {
        assembly ("memory-safe") {
            mstore(outPtr, mload(aPtr))
            mstore(add(outPtr, 0x20), mload(add(aPtr, 0x20)))
            mstore(add(outPtr, 0x40), mload(add(aPtr, 0x40)))
            mstore(add(outPtr, 0x60), mload(add(aPtr, 0x60)))
            mstore(add(outPtr, 0x80), mload(add(aPtr, 0x80)))
            mstore(add(outPtr, 0xa0), mload(add(aPtr, 0xa0)))
        }
        MNT4Extension.fq2NegTo(outPtr + 6 * WORD, aPtr + 6 * WORD);
    }

    /// @notice Применяет отображение Фробениуса: `_fq2Frobenius1PtrTo`.
    function _fq2Frobenius1PtrTo(uint256 outPtr, uint256 aPtr) private pure {
        uint256 a10;
        uint256 a11;
        uint256 a12;
        assembly ("memory-safe") {
            // c0 unchanged
            mstore(outPtr, mload(aPtr))
            mstore(add(outPtr, 0x20), mload(add(aPtr, 0x20)))
            mstore(add(outPtr, 0x40), mload(add(aPtr, 0x40)))
            a10 := mload(add(aPtr, 0x60))
            a11 := mload(add(aPtr, 0x80))
            a12 := mload(add(aPtr, 0xa0))
        }
        (uint256 r10, uint256 r11, uint256 r12) = BigIntMNT.montMul3(
            a10, a11, a12,
            FROB_FQ2_C1_1_0, FROB_FQ2_C1_1_1, FROB_FQ2_C1_1_2
        );
        assembly ("memory-safe") {
            mstore(add(outPtr, 0x60), r10)
            mstore(add(outPtr, 0x80), r11)
            mstore(add(outPtr, 0xa0), r12)
        }
    }

    /// @notice Применяет отображение Фробениуса: `_fq4Frobenius1PtrTo`.
    function _fq4Frobenius1PtrTo(uint256 outPtr, uint256 aPtr) private pure {
        _fq2Frobenius1PtrTo(outPtr, aPtr);
        uint256 pTmp = _allocWords(6);
        _fq2Frobenius1PtrTo(pTmp, aPtr + 6 * WORD);
        uint256 pFrobC = _allocWords(3);
        assembly ("memory-safe") {
            mstore(pFrobC, FROB_FQ4_C1_1_0)
            mstore(add(pFrobC, 0x20), FROB_FQ4_C1_1_1)
            mstore(add(pFrobC, 0x40), FROB_FQ4_C1_1_2)
        }
        MNT4Extension.fq2MulByFp3To(outPtr + 6 * WORD, pTmp, pFrobC);
    }

    /// @notice Применяет отображение Фробениуса: `_fq4Frobenius2PtrTo`.
    function _fq4Frobenius2PtrTo(uint256 outPtr, uint256 aPtr) private pure {
        uint256 pTmp = _allocWords(12);
        _fq4Frobenius1PtrTo(pTmp, aPtr);
        _fq4Frobenius1PtrTo(outPtr, pTmp);
    }

    /// @notice Применяет отображение Фробениуса: `_fq4Frobenius1`.
    function _fq4Frobenius1(
        MNT4ExtensionFinal.Fq4 memory a
    ) private pure returns (MNT4ExtensionFinal.Fq4 memory r) {
        r.c0 = _fq2Frobenius1(a.c0);
        MNT4ExtensionFinal.Fq2 memory c1 = _fq2Frobenius1(a.c1);
        MNT4ExtensionFinal.fq2MulByFp3To(
            r.c1,
            c1,
            FROB_FQ4_C1_1_0,
            FROB_FQ4_C1_1_1,
            FROB_FQ4_C1_1_2
        );
    }

    /// @notice Выполняет внутреннюю операцию `_decodeLoopMem`; параметры и результат используют представление текущей библиотеки.
    function _decodeLoopMem(bytes memory loop, uint256 i) private pure returns (int8 v) {
        uint8 c = uint8(loop[i]);
        if (c == 2) return 1;
        if (c == 1) return 0;
        return -1;
    }

    /// @notice Выполняет внутреннюю операцию `_fixedQOverTwist`; параметры и результат используют представление текущей библиотеки.
    function _fixedQOverTwist(
    ) private pure returns (MNT4ExtensionFinal.Fq2 memory qxOverTwist, MNT4ExtensionFinal.Fq2 memory qyOverTwist, MNT4ExtensionFinal.Fq2 memory qyOverTwistNeg) {
        qxOverTwist.c0[0] = QXOT_C0_0; qxOverTwist.c0[1] = QXOT_C0_1; qxOverTwist.c0[2] = QXOT_C0_2;
        qxOverTwist.c1[0] = QXOT_C1_0; qxOverTwist.c1[1] = QXOT_C1_1; qxOverTwist.c1[2] = QXOT_C1_2;

        qyOverTwist.c0[0] = QYOT_C0_0; qyOverTwist.c0[1] = QYOT_C0_1; qyOverTwist.c0[2] = QYOT_C0_2;
        qyOverTwist.c1[0] = QYOT_C1_0; qyOverTwist.c1[1] = QYOT_C1_1; qyOverTwist.c1[2] = QYOT_C1_2;

        qyOverTwistNeg.c0[0] = QYOTN_C0_0; qyOverTwistNeg.c0[1] = QYOTN_C0_1; qyOverTwistNeg.c0[2] = QYOTN_C0_2;
        qyOverTwistNeg.c1[0] = QYOTN_C1_0; qyOverTwistNeg.c1[1] = QYOTN_C1_1; qyOverTwistNeg.c1[2] = QYOTN_C1_2;
    }

    /// @notice Выполняет внутреннюю операцию `_fixedQOverTwistPtrs`; параметры и результат используют представление текущей библиотеки.
    function _fixedQOverTwistPtrs(
    ) private pure returns (uint256 pQxOverTwist, uint256 pQyOverTwist, uint256 pQyOverTwistNeg) {
        pQxOverTwist = _allocWords(18);
        pQyOverTwist = pQxOverTwist + 6 * WORD;
        pQyOverTwistNeg = pQyOverTwist + 6 * WORD;
        assembly ("memory-safe") {
            mstore(pQxOverTwist, QXOT_C0_0)
            mstore(add(pQxOverTwist, 0x20), QXOT_C0_1)
            mstore(add(pQxOverTwist, 0x40), QXOT_C0_2)
            mstore(add(pQxOverTwist, 0x60), QXOT_C1_0)
            mstore(add(pQxOverTwist, 0x80), QXOT_C1_1)
            mstore(add(pQxOverTwist, 0xa0), QXOT_C1_2)

            mstore(pQyOverTwist, QYOT_C0_0)
            mstore(add(pQyOverTwist, 0x20), QYOT_C0_1)
            mstore(add(pQyOverTwist, 0x40), QYOT_C0_2)
            mstore(add(pQyOverTwist, 0x60), QYOT_C1_0)
            mstore(add(pQyOverTwist, 0x80), QYOT_C1_1)
            mstore(add(pQyOverTwist, 0xa0), QYOT_C1_2)

            mstore(pQyOverTwistNeg, QYOTN_C0_0)
            mstore(add(pQyOverTwistNeg, 0x20), QYOTN_C0_1)
            mstore(add(pQyOverTwistNeg, 0x40), QYOTN_C0_2)
            mstore(add(pQyOverTwistNeg, 0x60), QYOTN_C1_0)
            mstore(add(pQyOverTwistNeg, 0x80), QYOTN_C1_1)
            mstore(add(pQyOverTwistNeg, 0xa0), QYOTN_C1_2)
        }
    }

    /// @notice Выполняет внутреннюю операцию `_qOverTwistPtrsFromQ`; параметры и результат используют представление текущей библиотеки.
    function _qOverTwistPtrsFromQ(
        G2Affine memory q
    ) private pure returns (uint256 pQxOverTwist, uint256 pQyOverTwist, uint256 pQyOverTwistNeg) {
        pQxOverTwist = _allocWords(18);
        pQyOverTwist = pQxOverTwist + 6 * WORD;
        pQyOverTwistNeg = pQyOverTwist + 6 * WORD;

        // For MNT4 twist map we use q / twist, where twist^{-1} = (0, 13^{-1}) in Fq2.
        MNT4ExtensionFinal.Fq2 memory tInv = _twistInv();
        MNT4ExtensionFinal.Fq2 memory qxOverTwist = MNT4ExtensionFinal.fq2Mul(q.x, tInv);
        MNT4ExtensionFinal.Fq2 memory qyOverTwist = MNT4ExtensionFinal.fq2Mul(q.y, tInv);
        MNT4ExtensionFinal.Fq2 memory qyOverTwistNeg = _fq2Neg(qyOverTwist);

        _storeFq2ToPtr(pQxOverTwist, qxOverTwist);
        _storeFq2ToPtr(pQyOverTwist, qyOverTwist);
        _storeFq2ToPtr(pQyOverTwistNeg, qyOverTwistNeg);
    }

    /// @notice Записывает подготовленное значение в целевой буфер: `_storeWordToBytes`.
    function _storeWordToBytes(bytes memory out, uint256 offsetBytes, uint256 v) private pure {
        assembly ("memory-safe") {
            mstore(add(add(out, 0x20), offsetBytes), v)
        }
    }

    /// @notice Записывает подготовленное значение в целевой буфер: `_storeFq2ToBytes`.
    function _storeFq2ToBytes(
        bytes memory out,
        uint256 offsetBytes,
        MNT4ExtensionFinal.Fq2 memory a
    ) private pure returns (uint256 outOff) {
        _storeWordToBytes(out, offsetBytes, a.c0[0]); offsetBytes += WORD;
        _storeWordToBytes(out, offsetBytes, a.c0[1]); offsetBytes += WORD;
        _storeWordToBytes(out, offsetBytes, a.c0[2]); offsetBytes += WORD;
        _storeWordToBytes(out, offsetBytes, a.c1[0]); offsetBytes += WORD;
        _storeWordToBytes(out, offsetBytes, a.c1[1]); offsetBytes += WORD;
        _storeWordToBytes(out, offsetBytes, a.c1[2]); offsetBytes += WORD;
        outOff = offsetBytes;
    }

    /// @notice Выполняет вычитание `_storeFq2SubToBytes` с учетом модуля или структуры текущего поля.
    function _storeFq2SubToBytes(
        bytes memory out,
        uint256 offsetBytes,
        MNT4ExtensionFinal.Fq2 memory a,
        MNT4ExtensionFinal.Fq2 memory b
    ) private pure returns (uint256 outOff) {
        (uint256 r00, uint256 r01, uint256 r02) = BigIntMNT.sub3(
            a.c0[0], a.c0[1], a.c0[2],
            b.c0[0], b.c0[1], b.c0[2]
        );
        (uint256 r10, uint256 r11, uint256 r12) = BigIntMNT.sub3(
            a.c1[0], a.c1[1], a.c1[2],
            b.c1[0], b.c1[1], b.c1[2]
        );
        _storeWordToBytes(out, offsetBytes, r00); offsetBytes += WORD;
        _storeWordToBytes(out, offsetBytes, r01); offsetBytes += WORD;
        _storeWordToBytes(out, offsetBytes, r02); offsetBytes += WORD;
        _storeWordToBytes(out, offsetBytes, r10); offsetBytes += WORD;
        _storeWordToBytes(out, offsetBytes, r11); offsetBytes += WORD;
        _storeWordToBytes(out, offsetBytes, r12); offsetBytes += WORD;
        outOff = offsetBytes;
    }

    /// @notice Записывает подготовленное значение в целевой буфер: `_storeFq2ToPtr`.
    function _storeFq2ToPtr(
        uint256 outPtr,
        MNT4ExtensionFinal.Fq2 memory a
    ) private pure {
        uint256 a00 = a.c0[0];
        uint256 a01 = a.c0[1];
        uint256 a02 = a.c0[2];
        uint256 a10 = a.c1[0];
        uint256 a11 = a.c1[1];
        uint256 a12 = a.c1[2];
        assembly ("memory-safe") {
            mstore(outPtr, a00)
            mstore(add(outPtr, 0x20), a01)
            mstore(add(outPtr, 0x40), a02)
            mstore(add(outPtr, 0x60), a10)
            mstore(add(outPtr, 0x80), a11)
            mstore(add(outPtr, 0xa0), a12)
        }
    }

    /// @notice Записывает подготовленное значение в целевой буфер: `_storeFq2LimbsToPtr`.
    function _storeFq2LimbsToPtr(
        uint256 outPtr,
        uint256 a00, uint256 a01, uint256 a02,
        uint256 a10, uint256 a11, uint256 a12
    ) private pure {
        assembly ("memory-safe") {
            mstore(outPtr, a00)
            mstore(add(outPtr, 0x20), a01)
            mstore(add(outPtr, 0x40), a02)
            mstore(add(outPtr, 0x60), a10)
            mstore(add(outPtr, 0x80), a11)
            mstore(add(outPtr, 0xa0), a12)
        }
    }

    /// @notice Записывает подготовленное значение в целевой буфер: `_storeFq2LimbsToBytes`.
    function _storeFq2LimbsToBytes(
        bytes memory out,
        uint256 offsetBytes,
        uint256 a00, uint256 a01, uint256 a02,
        uint256 a10, uint256 a11, uint256 a12
    ) private pure returns (uint256 outOff) {
        _storeWordToBytes(out, offsetBytes, a00); offsetBytes += WORD;
        _storeWordToBytes(out, offsetBytes, a01); offsetBytes += WORD;
        _storeWordToBytes(out, offsetBytes, a02); offsetBytes += WORD;
        _storeWordToBytes(out, offsetBytes, a10); offsetBytes += WORD;
        _storeWordToBytes(out, offsetBytes, a11); offsetBytes += WORD;
        _storeWordToBytes(out, offsetBytes, a12); offsetBytes += WORD;
        outOff = offsetBytes;
    }

    /// @notice Выполняет вычитание `_storeFq2SubToPtr` с учетом модуля или структуры текущего поля.
    function _storeFq2SubToPtr(
        uint256 outPtr,
        MNT4ExtensionFinal.Fq2 memory a,
        MNT4ExtensionFinal.Fq2 memory b
    ) private pure {
        (uint256 r00, uint256 r01, uint256 r02) = BigIntMNT.sub3(
            a.c0[0], a.c0[1], a.c0[2],
            b.c0[0], b.c0[1], b.c0[2]
        );
        (uint256 r10, uint256 r11, uint256 r12) = BigIntMNT.sub3(
            a.c1[0], a.c1[1], a.c1[2],
            b.c1[0], b.c1[1], b.c1[2]
        );
        assembly ("memory-safe") {
            mstore(outPtr, r00)
            mstore(add(outPtr, 0x20), r01)
            mstore(add(outPtr, 0x40), r02)
            mstore(add(outPtr, 0x60), r10)
            mstore(add(outPtr, 0x80), r11)
            mstore(add(outPtr, 0xa0), r12)
        }
    }

    /// @notice Формирует подготовленные данные `_prepareQBlobSparse`, которые затем переиспользуются в цикле Миллера.
    function _prepareQBlobSparse(
        G2Affine memory q
    ) private pure returns (bytes memory dblSparse, bytes memory addSparse) {
        dblSparse = new bytes(FIXED_DBL_SPARSE_BYTES);
        addSparse = new bytes(FIXED_ADD_SPARSE_BYTES);
        bytes memory loop = ATE_LOOP_ENC;

        MNT4ExtensionFinal.Fq2 memory qNegY = _fq2Neg(q.y);
        G2ProjectiveExtended memory r;
        r.x = q.x;
        r.y = q.y;
        r.z = _fq2One();
        r.t = _fq2One();

        uint256 outD;
        uint256 outA;
        for (uint256 i = 1; i < loop.length; ++i) {
            (G2ProjectiveExtended memory r2, AteDoubleCoefficients memory dc) = _doublingStep(r);
            r = r2;

            // Разреженная тройка шага удвоения: d0=c_l-c_4c, d1=c_j, d2=c_h.
            outD = _storeFq2SubToBytes(dblSparse, outD, dc.c_l, dc.c_4c);
            outD = _storeFq2LimbsToBytes(
                dblSparse, outD,
                dc.c_j.c0[0], dc.c_j.c0[1], dc.c_j.c0[2],
                dc.c_j.c1[0], dc.c_j.c1[1], dc.c_j.c1[2]
            );
            outD = _storeFq2LimbsToBytes(
                dblSparse, outD,
                dc.c_h.c0[0], dc.c_h.c0[1], dc.c_h.c0[2],
                dc.c_h.c1[0], dc.c_h.c1[1], dc.c_h.c1[2]
            );

            int8 bit = _decodeLoopMem(loop, i);
            if (bit == 0) continue;

            (G2ProjectiveExtended memory r3, AteAdditionCoefficients memory ac) = bit == 1
                ? _mixedAdditionStep(q.x, q.y, r)
                : _mixedAdditionStep(q.x, qNegY, r);
            r = r3;

            // Разреженная пара шага сложения: a0=c_rz, a1=c_l1.
            outA = _storeFq2LimbsToBytes(
                addSparse, outA,
                ac.c_rz.c0[0], ac.c_rz.c0[1], ac.c_rz.c0[2],
                ac.c_rz.c1[0], ac.c_rz.c1[1], ac.c_rz.c1[2]
            );
            outA = _storeFq2LimbsToBytes(
                addSparse, outA,
                ac.c_l1.c0[0], ac.c_l1.c0[1], ac.c_l1.c0[2],
                ac.c_l1.c1[0], ac.c_l1.c1[1], ac.c_l1.c1[2]
            );
        }

        if (ATE_IS_LOOP_COUNT_NEG) {
            MNT4ExtensionFinal.Fq2 memory rzInv = MNT4ExtensionFinal.fq2Inv(r.z);
            MNT4ExtensionFinal.Fq2 memory rz2Inv = MNT4ExtensionFinal.fq2Sqr(rzInv);
            MNT4ExtensionFinal.Fq2 memory rz3Inv = MNT4ExtensionFinal.fq2Mul(rzInv, rz2Inv);
            MNT4ExtensionFinal.Fq2 memory minusRAffineX = MNT4ExtensionFinal.fq2Mul(r.x, rz2Inv);
            MNT4ExtensionFinal.Fq2 memory minusRAffineY = _fq2Neg(MNT4ExtensionFinal.fq2Mul(r.y, rz3Inv));
            (, AteAdditionCoefficients memory acNeg) = _mixedAdditionStep(minusRAffineX, minusRAffineY, r);
            outA = _storeFq2LimbsToBytes(
                addSparse, outA,
                acNeg.c_rz.c0[0], acNeg.c_rz.c0[1], acNeg.c_rz.c0[2],
                acNeg.c_rz.c1[0], acNeg.c_rz.c1[1], acNeg.c_rz.c1[2]
            );
            outA = _storeFq2LimbsToBytes(
                addSparse, outA,
                acNeg.c_l1.c0[0], acNeg.c_l1.c0[1], acNeg.c_l1.c0[2],
                acNeg.c_l1.c1[0], acNeg.c_l1.c1[1], acNeg.c_l1.c1[2]
            );
        }

        require(outD == FIXED_DBL_SPARSE_BYTES, "dbl sparse size");
        require(outA == FIXED_ADD_SPARSE_BYTES, "add sparse size");
    }

    /// @notice Формирует подготовленные данные `prepareFixedQBlobSparse`, которые затем переиспользуются в цикле Миллера.
    function prepareFixedQBlobSparse()
        internal
        pure
        returns (bytes memory dblSparse, bytes memory addSparse)
    {
        return _prepareQBlobSparse(_fixedQGenerator());
    }

    /// @notice Формирует подготовленные данные `prepareParametricQBlobSparse`, которые затем переиспользуются в цикле Миллера.
    function prepareParametricQBlobSparse(
        G2Affine memory q
    ) internal pure returns (bytes memory dblSparse, bytes memory addSparse) {
        return _prepareQBlobSparse(q);
    }

    /// @notice Читает подготовленные данные из указанного источника: `_loadWordsCalldataToPtr`.
    function _loadWordsCalldataToPtr(
        uint256 outPtr,
        bytes calldata blob,
        uint256 offsetBytes,
        uint256 words
    ) private pure {
        assembly ("memory-safe") {
            let src := add(blob.offset, offsetBytes)
            let dst := outPtr
            let end := add(dst, shl(5, words))
            for { } lt(dst, end) { dst := add(dst, 0x20) src := add(src, 0x20) } {
                mstore(dst, calldataload(src))
            }
        }
    }

    /// @notice Читает подготовленные данные из указанного источника: `_loadWordsMemoryToPtr`.
    function _loadWordsMemoryToPtr(
        uint256 outPtr,
        bytes memory blob,
        uint256 offsetBytes,
        uint256 words
    ) private pure {
        assembly ("memory-safe") {
            let src := add(add(blob, 0x20), offsetBytes)
            let dst := outPtr
            let end := add(dst, shl(5, words))
            for { } lt(dst, end) { dst := add(dst, 0x20) src := add(src, 0x20) } {
                mstore(dst, mload(src))
            }
        }
    }

    /// @notice Читает подготовленные данные из указанного источника: `_loadFp3BytesCalldataToPtr`.
    function _loadFp3BytesCalldataToPtr(
        uint256 outPtr,
        bytes calldata blob,
        uint256 offsetBytes
    ) private pure {
        _loadWordsCalldataToPtr(outPtr, blob, offsetBytes, FP3_WORDS);
    }

    /// @notice Читает подготовленные данные из указанного источника: `_loadFq2BytesCalldataToPtr`.
    function _loadFq2BytesCalldataToPtr(
        uint256 outPtr,
        bytes calldata blob,
        uint256 offsetBytes
    ) private pure {
        assembly ("memory-safe") {
            let p := add(blob.offset, offsetBytes)
            mstore(outPtr, calldataload(p))
            mstore(add(outPtr, 0x20), calldataload(add(p, 0x20)))
            mstore(add(outPtr, 0x40), calldataload(add(p, 0x40)))
            mstore(add(outPtr, 0x60), calldataload(add(p, 0x60)))
            mstore(add(outPtr, 0x80), calldataload(add(p, 0x80)))
            mstore(add(outPtr, 0xa0), calldataload(add(p, 0xa0)))
        }
    }

    /// @notice Читает подготовленные данные из указанного источника: `_loadFq4BytesCalldataToPtr`.
    function _loadFq4BytesCalldataToPtr(
        uint256 outPtr,
        bytes calldata blob,
        uint256 offsetBytes
    ) private pure {
        _loadWordsCalldataToPtr(outPtr, blob, offsetBytes, FQ4_WORDS);
    }

    /// @notice Читает подготовленные данные из указанного источника: `_loadFp3BytesMemoryToPtr`.
    function _loadFp3BytesMemoryToPtr(
        uint256 outPtr,
        bytes memory blob,
        uint256 offsetBytes
    ) private pure {
        _loadWordsMemoryToPtr(outPtr, blob, offsetBytes, FP3_WORDS);
    }

    /// @notice Читает подготовленные данные из указанного источника: `_loadFq2BytesMemoryToPtr`.
    function _loadFq2BytesMemoryToPtr(
        uint256 outPtr,
        bytes memory blob,
        uint256 offsetBytes
    ) private pure {
        assembly ("memory-safe") {
            let p := add(add(blob, 0x20), offsetBytes)
            mstore(outPtr, mload(p))
            mstore(add(outPtr, 0x20), mload(add(p, 0x20)))
            mstore(add(outPtr, 0x40), mload(add(p, 0x40)))
            mstore(add(outPtr, 0x60), mload(add(p, 0x60)))
            mstore(add(outPtr, 0x80), mload(add(p, 0x80)))
            mstore(add(outPtr, 0xa0), mload(add(p, 0xa0)))
        }
    }

    /// @notice Читает подготовленные данные из указанного источника: `_loadFq4BytesMemoryToPtr`.
    function _loadFq4BytesMemoryToPtr(
        uint256 outPtr,
        bytes memory blob,
        uint256 offsetBytes
    ) private pure {
        _loadWordsMemoryToPtr(outPtr, blob, offsetBytes, FQ4_WORDS);
    }

    /// @notice Читает подготовленные данные из указанного источника: `_loadSparseDblStepCalldataToPtr`.
    function _loadSparseDblStepCalldataToPtr(
        uint256 outD0Ptr,
        bytes calldata dblSparse,
        uint256 offsetBytes
    ) private pure returns (uint256 nextOffsetBytes) {
        uint256 byteLen = DBL_SPARSE_STEP_BYTES;
        assembly ("memory-safe") {
            calldatacopy(outD0Ptr, add(dblSparse.offset, offsetBytes), byteLen)
        }
        nextOffsetBytes = offsetBytes + DBL_SPARSE_STEP_BYTES;
    }

    /// @notice Выполняет сложение `_loadSparseAddStepCalldataToPtr` с учетом модуля или структуры текущего поля.
    function _loadSparseAddStepCalldataToPtr(
        uint256 outA0Ptr,
        bytes calldata addSparse,
        uint256 offsetBytes
    ) private pure returns (uint256 nextOffsetBytes) {
        uint256 byteLen = ADD_SPARSE_STEP_BYTES;
        assembly ("memory-safe") {
            calldatacopy(outA0Ptr, add(addSparse.offset, offsetBytes), byteLen)
        }
        nextOffsetBytes = offsetBytes + ADD_SPARSE_STEP_BYTES;
    }

    /// @notice Читает подготовленные данные из указанного источника: `_loadSparseDblStepMemoryToPtr`.
    function _loadSparseDblStepMemoryToPtr(
        uint256 outD0Ptr,
        bytes memory dblSparse,
        uint256 offsetBytes
    ) private pure returns (uint256 nextOffsetBytes) {
        uint256 byteLen = DBL_SPARSE_STEP_BYTES;
        assembly ("memory-safe") {
            mcopy(outD0Ptr, add(add(dblSparse, 0x20), offsetBytes), byteLen)
        }
        nextOffsetBytes = offsetBytes + DBL_SPARSE_STEP_BYTES;
    }

    /// @notice Выполняет сложение `_loadSparseAddStepMemoryToPtr` с учетом модуля или структуры текущего поля.
    function _loadSparseAddStepMemoryToPtr(
        uint256 outA0Ptr,
        bytes memory addSparse,
        uint256 offsetBytes
    ) private pure returns (uint256 nextOffsetBytes) {
        uint256 byteLen = ADD_SPARSE_STEP_BYTES;
        assembly ("memory-safe") {
            mcopy(outA0Ptr, add(add(addSparse, 0x20), offsetBytes), byteLen)
        }
        nextOffsetBytes = offsetBytes + ADD_SPARSE_STEP_BYTES;
    }

    /// @notice Выполняет внутреннюю операцию `_extCodeSize`; параметры и результат используют представление текущей библиотеки.
    function _extCodeSize(address code) private view returns (uint256 size) {
        assembly ("memory-safe") { size := extcodesize(code) }
    }

    /// @notice Читает подготовленные данные из указанного источника: `_loadCodeBytesToPtr`.
    function _loadCodeBytesToPtr(
        uint256 outPtr,
        address code,
        uint256 offsetBytes,
        uint256 byteLen
    ) private view {
        assembly ("memory-safe") {
            extcodecopy(code, outPtr, offsetBytes, byteLen)
        }
    }

    /// @notice Читает подготовленные данные из указанного источника: `_loadFp3CodeToPtr`.
    function _loadFp3CodeToPtr(
        uint256 outPtr,
        address code,
        uint256 offsetBytes
    ) private view {
        _loadCodeBytesToPtr(outPtr, code, offsetBytes, FP3_BYTES);
    }

    /// @notice Читает подготовленные данные из указанного источника: `_loadFq2CodeToPtr`.
    function _loadFq2CodeToPtr(
        uint256 outPtr,
        address code,
        uint256 offsetBytes
    ) private view {
        _loadCodeBytesToPtr(outPtr, code, offsetBytes, FQ2_BYTES);
    }

    /// @notice Читает подготовленные данные из указанного источника: `_loadFq4CodeToPtr`.
    function _loadFq4CodeToPtr(
        uint256 outPtr,
        address code,
        uint256 offsetBytes
    ) private view {
        _loadCodeBytesToPtr(outPtr, code, offsetBytes, FQ4_BYTES);
    }

    /// @notice Выполняет внутреннюю операцию `_initCodeShardStreamByChunk`; параметры и результат используют представление текущей библиотеки.
    function _initCodeShardStreamByChunk(
        address[] memory shards,
        uint256 expectedBytes,
        uint256 chunkBytes
    ) private view returns (uint256 shardIdx, uint256 offsetBytes, uint256 shardSize) {
        require(shards.length > 0, "no code shards");
        uint256 total;
        for (uint256 i = 0; i < shards.length; ++i) {
            uint256 sz = _extCodeSize(shards[i]);
            require(sz > 0 && sz % chunkBytes == 0, "bad shard size");
            total += sz;
        }
        require(total == expectedBytes, "bad shard total");
        shardIdx = 0;
        offsetBytes = 0;
        shardSize = _extCodeSize(shards[0]);
    }

    /// @notice Выполняет внутреннюю операцию `_initCodeShardStream`; параметры и результат используют представление текущей библиотеки.
    function _initCodeShardStream(
        address[] memory shards,
        uint256 expectedBytes
    ) private view returns (uint256 shardIdx, uint256 offsetBytes, uint256 shardSize) {
        return _initCodeShardStreamByChunk(shards, expectedBytes, FQ2_BYTES);
    }

    /// @notice Читает подготовленные данные из указанного источника: `_streamLoadCodeShardsToPtr`.
    function _streamLoadCodeShardsToPtr(
        uint256 outPtr,
        uint256 nBytes,
        address[] memory shards,
        uint256 shardIdx,
        uint256 offsetBytes,
        uint256 shardSize
    ) private view returns (uint256 nextShardIdx, uint256 nextOffsetBytes, uint256 nextShardSize) {
        uint256 dst = outPtr;
        uint256 remaining = nBytes;
        nextShardIdx = shardIdx;
        nextOffsetBytes = offsetBytes;
        nextShardSize = shardSize;

        while (remaining > 0) {
            uint256 canTake = nextShardSize - nextOffsetBytes;
            uint256 take = remaining < canTake ? remaining : canTake;
            _loadCodeBytesToPtr(dst, shards[nextShardIdx], nextOffsetBytes, take);

            dst += take;
            remaining -= take;
            nextOffsetBytes += take;

            if (nextOffsetBytes == nextShardSize) {
                nextShardIdx += 1;
                if (nextShardIdx < shards.length) {
                    nextOffsetBytes = 0;
                    nextShardSize = _extCodeSize(shards[nextShardIdx]);
                } else {
                    nextOffsetBytes = 0;
                    nextShardSize = 0;
                    require(remaining == 0, "bad stream read");
                }
            }
        }
    }

    /// @notice Читает подготовленные данные из указанного источника: `_streamLoadFp3CodeShardsToPtr`.
    function _streamLoadFp3CodeShardsToPtr(
        uint256 outPtr,
        address[] memory shards,
        uint256 shardIdx,
        uint256 offsetBytes,
        uint256 shardSize
    ) private view returns (uint256 nextShardIdx, uint256 nextOffsetBytes, uint256 nextShardSize) {
        return _streamLoadCodeShardsToPtr(outPtr, FP3_BYTES, shards, shardIdx, offsetBytes, shardSize);
    }

    /// @notice Читает подготовленные данные из указанного источника: `_streamLoadFq2CodeShardsToPtr`.
    function _streamLoadFq2CodeShardsToPtr(
        uint256 outPtr,
        address[] memory shards,
        uint256 shardIdx,
        uint256 offsetBytes,
        uint256 shardSize
    ) private view returns (uint256 nextShardIdx, uint256 nextOffsetBytes, uint256 nextShardSize) {
        _loadFq2CodeToPtr(outPtr, shards[shardIdx], offsetBytes);
        nextShardIdx = shardIdx;
        nextOffsetBytes = offsetBytes + FQ2_BYTES;
        nextShardSize = shardSize;

        if (nextOffsetBytes == shardSize) {
            nextShardIdx = shardIdx + 1;
            if (nextShardIdx < shards.length) {
                nextOffsetBytes = 0;
                nextShardSize = _extCodeSize(shards[nextShardIdx]);
            } else {
                nextOffsetBytes = 0;
                nextShardSize = 0;
            }
        }
    }

    /// @notice Читает подготовленные данные из указанного источника: `_streamLoadFq4CodeShardsToPtr`.
    function _streamLoadFq4CodeShardsToPtr(
        uint256 outPtr,
        address[] memory shards,
        uint256 shardIdx,
        uint256 offsetBytes,
        uint256 shardSize
    ) private view returns (uint256 nextShardIdx, uint256 nextOffsetBytes, uint256 nextShardSize) {
        return _streamLoadCodeShardsToPtr(outPtr, FQ4_BYTES, shards, shardIdx, offsetBytes, shardSize);
    }

    /// @notice Читает подготовленные данные из указанного источника: `_streamLoadSparseDblStepCodeShardsToPtr`.
    function _streamLoadSparseDblStepCodeShardsToPtr(
        uint256 outD0Ptr,
        address[] memory shards,
        uint256 shardIdx,
        uint256 offsetBytes,
        uint256 shardSize
    ) private view returns (uint256 nextShardIdx, uint256 nextOffsetBytes, uint256 nextShardSize) {
        if (offsetBytes + DBL_SPARSE_STEP_BYTES <= shardSize) {
            _loadCodeBytesToPtr(outD0Ptr, shards[shardIdx], offsetBytes, DBL_SPARSE_STEP_BYTES);
            nextShardIdx = shardIdx;
            nextOffsetBytes = offsetBytes + DBL_SPARSE_STEP_BYTES;
            nextShardSize = shardSize;
            if (nextOffsetBytes == shardSize) {
                nextShardIdx = shardIdx + 1;
                if (nextShardIdx < shards.length) {
                    nextOffsetBytes = 0;
                    nextShardSize = _extCodeSize(shards[nextShardIdx]);
                } else {
                    nextOffsetBytes = 0;
                    nextShardSize = 0;
                }
            }
            return (nextShardIdx, nextOffsetBytes, nextShardSize);
        }
        return _streamLoadCodeShardsToPtr(outD0Ptr, DBL_SPARSE_STEP_BYTES, shards, shardIdx, offsetBytes, shardSize);
    }

    /// @notice Выполняет сложение `_streamLoadSparseAddStepCodeShardsToPtr` с учетом модуля или структуры текущего поля.
    function _streamLoadSparseAddStepCodeShardsToPtr(
        uint256 outA0Ptr,
        address[] memory shards,
        uint256 shardIdx,
        uint256 offsetBytes,
        uint256 shardSize
    ) private view returns (uint256 nextShardIdx, uint256 nextOffsetBytes, uint256 nextShardSize) {
        if (offsetBytes + ADD_SPARSE_STEP_BYTES <= shardSize) {
            _loadCodeBytesToPtr(outA0Ptr, shards[shardIdx], offsetBytes, ADD_SPARSE_STEP_BYTES);
            nextShardIdx = shardIdx;
            nextOffsetBytes = offsetBytes + ADD_SPARSE_STEP_BYTES;
            nextShardSize = shardSize;
            if (nextOffsetBytes == shardSize) {
                nextShardIdx = shardIdx + 1;
                if (nextShardIdx < shards.length) {
                    nextOffsetBytes = 0;
                    nextShardSize = _extCodeSize(shards[nextShardIdx]);
                } else {
                    nextOffsetBytes = 0;
                    nextShardSize = 0;
                }
            }
            return (nextShardIdx, nextOffsetBytes, nextShardSize);
        }
        return _streamLoadCodeShardsToPtr(outA0Ptr, ADD_SPARSE_STEP_BYTES, shards, shardIdx, offsetBytes, shardSize);
    }

    /// @notice Копирует представление значения между буферами памяти: `_copyFq4`.
    function _copyFq4(
        MNT4ExtensionFinal.Fq4 memory dst,
        MNT4ExtensionFinal.Fq4 memory src
    ) private pure {
        assembly ("memory-safe") {
            mstore(dst, mload(src))
            mstore(add(dst, 0x20), mload(add(src, 0x20)))
            mstore(add(dst, 0x40), mload(add(src, 0x40)))
            mstore(add(dst, 0x60), mload(add(src, 0x60)))
            mstore(add(dst, 0x80), mload(add(src, 0x80)))
            mstore(add(dst, 0xa0), mload(add(src, 0xa0)))
            mstore(add(dst, 0xc0), mload(add(src, 0xc0)))
            mstore(add(dst, 0xe0), mload(add(src, 0xe0)))
            mstore(add(dst, 0x100), mload(add(src, 0x100)))
            mstore(add(dst, 0x120), mload(add(src, 0x120)))
            mstore(add(dst, 0x140), mload(add(src, 0x140)))
            mstore(add(dst, 0x160), mload(add(src, 0x160)))
        }
    }

    /// @notice Копирует представление значения между буферами памяти: `_copyFq4Ptr`.
    function _copyFq4Ptr(uint256 dstPtr, uint256 srcPtr) private pure {
        assembly ("memory-safe") {
            mstore(dstPtr, mload(srcPtr))
            mstore(add(dstPtr, 0x20), mload(add(srcPtr, 0x20)))
            mstore(add(dstPtr, 0x40), mload(add(srcPtr, 0x40)))
            mstore(add(dstPtr, 0x60), mload(add(srcPtr, 0x60)))
            mstore(add(dstPtr, 0x80), mload(add(srcPtr, 0x80)))
            mstore(add(dstPtr, 0xa0), mload(add(srcPtr, 0xa0)))
            mstore(add(dstPtr, 0xc0), mload(add(srcPtr, 0xc0)))
            mstore(add(dstPtr, 0xe0), mload(add(srcPtr, 0xe0)))
            mstore(add(dstPtr, 0x100), mload(add(srcPtr, 0x100)))
            mstore(add(dstPtr, 0x120), mload(add(srcPtr, 0x120)))
            mstore(add(dstPtr, 0x140), mload(add(srcPtr, 0x140)))
            mstore(add(dstPtr, 0x160), mload(add(srcPtr, 0x160)))
        }
    }

    /// @notice Копирует представление значения между буферами памяти: `_copyFq2Ptr`.
    function _copyFq2Ptr(uint256 dstPtr, uint256 srcPtr) private pure {
        assembly ("memory-safe") {
            mstore(dstPtr, mload(srcPtr))
            mstore(add(dstPtr, 0x20), mload(add(srcPtr, 0x20)))
            mstore(add(dstPtr, 0x40), mload(add(srcPtr, 0x40)))
            mstore(add(dstPtr, 0x60), mload(add(srcPtr, 0x60)))
            mstore(add(dstPtr, 0x80), mload(add(srcPtr, 0x80)))
            mstore(add(dstPtr, 0xa0), mload(add(srcPtr, 0xa0)))
        }
    }

    /// @notice Выполняет внутреннюю операцию `_digestFq4Ptr`; параметры и результат используют представление текущей библиотеки.
    function _digestFq4Ptr(uint256 pFq4) private pure returns (bytes32 digest) {
        assembly ("memory-safe") { digest := keccak256(pFq4, 0x180) }
    }

    /// @notice Выполняет внутреннюю операцию `_reduceFp3Ptr`; параметры и результат используют представление текущей библиотеки.
    function _reduceFp3Ptr(uint256 p) private pure {
        uint256 a0;
        uint256 a1;
        uint256 a2;
        assembly ("memory-safe") {
            a0 := mload(p)
            a1 := mload(add(p, 0x20))
            a2 := mload(add(p, 0x40))
        }
        (uint256 r0, uint256 r1, uint256 r2) = BigIntMNT.add3(a0, a1, a2, 0, 0, 0);
        assembly ("memory-safe") {
            mstore(p, r0)
            mstore(add(p, 0x20), r1)
            mstore(add(p, 0x40), r2)
        }
    }

    /// @notice Выполняет внутреннюю операцию `_normalizeFq4Ptr`; параметры и результат используют представление текущей библиотеки.
    function _normalizeFq4Ptr(uint256 pFq4) private pure {
        _reduceFp3Ptr(pFq4);
        _reduceFp3Ptr(pFq4 + 3 * WORD);
        _reduceFp3Ptr(pFq4 + 6 * WORD);
        _reduceFp3Ptr(pFq4 + 9 * WORD);
    }

    /// @notice Выполняет внутреннюю операцию `_normalizeFq4PtrStrong`; параметры и результат используют представление текущей библиотеки.
    function _normalizeFq4PtrStrong(uint256 pFq4) private pure {
        // Вспомогательная канонизация только для диагностических сравнений.
        for (uint256 i = 0; i < 512; ++i) {
            _normalizeFq4Ptr(pFq4);
        }
    }

    /// @notice Выполняет внутреннюю операцию `_digestNormalizedFq4PtrStrong`; параметры и результат используют представление текущей библиотеки.
    function _digestNormalizedFq4PtrStrong(uint256 pIn) private pure returns (bytes32 digest) {
        uint256 pTmp = _allocWords(12);
        _copyFq4Ptr(pTmp, pIn);
        _normalizeFq4PtrStrong(pTmp);
        assembly ("memory-safe") { digest := keccak256(pTmp, 0x180) }
    }

    /// @notice Выделяет временную область памяти для горячего пути: `_allocFq2`.
    function _allocFq2() private pure returns (MNT4ExtensionFinal.Fq2 memory r) {
        assembly ("memory-safe") {
            r := mload(0x40)
            mstore(0x40, add(r, 0xc0))
        }
    }

    /// @notice Выделяет временную область памяти для горячего пути: `_allocFq4`.
    function _allocFq4() private pure returns (MNT4ExtensionFinal.Fq4 memory r) {
        assembly ("memory-safe") {
            r := mload(0x40)
            mstore(0x40, add(r, 0x180))
        }
    }

    /// @notice Выделяет временную область памяти для горячего пути: `_allocWords`.
    function _allocWords(uint256 words) private pure returns (uint256 p) {
        assembly ("memory-safe") {
            p := mload(0x40)
            mstore(0x40, add(p, shl(5, words)))
        }
    }

    /// @notice Возвращает нулевой элемент в используемом представлении: `_zeroWords`.
    function _zeroWords(uint256 ptr, uint256 words) private pure {
        assembly ("memory-safe") {
            let end := add(ptr, shl(5, words))
            for { let p := ptr } lt(p, end) { p := add(p, 0x20) } {
                mstore(p, 0)
            }
        }
    }

    /// @notice Выполняет внутреннюю операцию `_ptrFq2`; параметры и результат используют представление текущей библиотеки.
    function _ptrFq2(MNT4ExtensionFinal.Fq2 memory a) private pure returns (uint256 p) {
        assembly ("memory-safe") { p := a }
    }

    /// @notice Выполняет внутреннюю операцию `_ptrFq4`; параметры и результат используют представление текущей библиотеки.
    function _ptrFq4(MNT4ExtensionFinal.Fq4 memory a) private pure returns (uint256 p) {
        assembly ("memory-safe") { p := a }
    }

    /// @notice Выполняет внутреннюю операцию `_ptrFp3`; параметры и результат используют представление текущей библиотеки.
    function _ptrFp3(uint256[3] memory a) private pure returns (uint256 p) {
        assembly ("memory-safe") { p := a }
    }

    /// @notice Возвращает единичный элемент в используемом представлении: `_setFq4OnePtr`.
    function _setFq4OnePtr(uint256 outPtr) private pure {
        assembly ("memory-safe") {
            mstore(outPtr, ONE_MONT_0)
            mstore(add(outPtr, 0x20), ONE_MONT_1)
            mstore(add(outPtr, 0x40), ONE_MONT_2)
            mstore(add(outPtr, 0x60), 0)
            mstore(add(outPtr, 0x80), 0)
            mstore(add(outPtr, 0xa0), 0)
            mstore(add(outPtr, 0xc0), 0)
            mstore(add(outPtr, 0xe0), 0)
            mstore(add(outPtr, 0x100), 0)
            mstore(add(outPtr, 0x120), 0)
            mstore(add(outPtr, 0x140), 0)
            mstore(add(outPtr, 0x160), 0)
        }
    }

    /// @notice Выполняет вычитание `_fq2SubOnePtrInPlace` с учетом модуля или структуры текущего поля.
    function _fq2SubOnePtrInPlace(uint256 pFq2) private pure {
        uint256 a0;
        uint256 a1;
        uint256 a2;
        assembly ("memory-safe") {
            a0 := mload(pFq2)
            a1 := mload(add(pFq2, 0x20))
            a2 := mload(add(pFq2, 0x40))
        }
        (uint256 r0, uint256 r1, uint256 r2) =
            BigIntMNT.sub3(a0, a1, a2, ONE_MONT_0, ONE_MONT_1, ONE_MONT_2);
        assembly ("memory-safe") {
            mstore(pFq2, r0)
            mstore(add(pFq2, 0x20), r1)
            mstore(add(pFq2, 0x40), r2)
        }
    }

    /// @notice Возводит значение в квадрат: `_fq4CyclotomicSquarePtrTo`.
    function _fq4CyclotomicSquarePtrTo(
        uint256 outPtr,
        uint256 aPtr,
        uint256 scratchFq4
    ) private pure {
        // In arkworks Fp4 implements fast cyclotomic inversion, but not a
        // Здесь используется специализированное возведение в квадрат в циклотомической подгруппе.
        // over MNT4-753/Fp4 uses the ordinary Fq4 square. The previous
        // degree-12-style shortcut is not valid for this tower.
        MNT4Extension.fq4SqrTo(outPtr, aPtr, scratchFq4);
    }

    /// @notice Выполняет умножение `_fq4CyclotomicMulPtrTo`; точный уровень поля и специальный множитель отражены в названии.
    function _fq4CyclotomicMulPtrTo(
        uint256 outPtr,
        uint256 aPtr,
        uint256 bPtr,
        uint256 scratchFq4
    ) private pure {
        MNT4Extension.fq4MulTo(outPtr, aPtr, bPtr, scratchFq4);
    }

    /// @notice Выполняет внутреннюю операцию `_buildL1CoeffFromPxPtrTo`; параметры и результат используют представление текущей библиотеки.
    function _buildL1CoeffFromPxPtrTo(
        uint256 outL1Ptr,
        uint256 pxPtr,
        uint256 qxOverTwistPtr
    ) private pure {
        assembly ("memory-safe") {
            mstore(outL1Ptr, mload(pxPtr))
            mstore(add(outL1Ptr, 0x20), mload(add(pxPtr, 0x20)))
            mstore(add(outL1Ptr, 0x40), mload(add(pxPtr, 0x40)))
            mstore(add(outL1Ptr, 0x60), 0)
            mstore(add(outL1Ptr, 0x80), 0)
            mstore(add(outL1Ptr, 0xa0), 0)
        }
        MNT4Extension.fq2SubTo(outL1Ptr, outL1Ptr, qxOverTwistPtr);
    }

    /// @notice Выполняет внутреннюю операцию `_lineDoubleSparsePtrTo`; параметры и результат используют представление текущей библиотеки.
    function _lineDoubleSparsePtrTo(
        uint256 outEll0Ptr,
        uint256 outEll1Ptr,
        uint256 tmpPtr,
        uint256 d0Ptr,
        uint256 d1Ptr,
        uint256 d2Ptr,
        uint256 pxPtr,
        uint256 pyPtr,
        uint256 scratchFq2Ptr
    ) private pure {
        MNT4Extension.fq2MulByFp3To(tmpPtr, d1Ptr, pxPtr);
        MNT4Extension.fq2MulByUTo(tmpPtr, tmpPtr, scratchFq2Ptr);
        MNT4Extension.fq2SubTo(outEll0Ptr, d0Ptr, tmpPtr);

        MNT4Extension.fq2MulByFp3To(outEll1Ptr, d2Ptr, pyPtr);
        MNT4Extension.fq2MulByUTo(outEll1Ptr, outEll1Ptr, scratchFq2Ptr);
    }

    /// @notice Выполняет сложение `_lineAddSparsePtrTo` с учетом модуля или структуры текущего поля.
    function _lineAddSparsePtrTo(
        uint256 outEll0Ptr,
        uint256 outEll1Ptr,
        uint256 tmp0Ptr,
        uint256 tmp1Ptr,
        uint256 a0Ptr,
        uint256 a1Ptr,
        uint256 l1CoeffPtr,
        uint256 yOverTwistPtr,
        uint256 pyPtr,
        uint256 scratchFq2Ptr
    ) private pure {
        MNT4Extension.fq2MulByFp3To(outEll0Ptr, a0Ptr, pyPtr);
        MNT4Extension.fq2MulByUTo(outEll0Ptr, outEll0Ptr, scratchFq2Ptr);

        MNT4Extension.fq2MulTo(tmp0Ptr, yOverTwistPtr, a0Ptr, scratchFq2Ptr);
        MNT4Extension.fq2MulTo(tmp1Ptr, l1CoeffPtr, a1Ptr, scratchFq2Ptr);
        MNT4Extension.fq2AddTo(outEll1Ptr, tmp0Ptr, tmp1Ptr);
        MNT4Extension.fq2NegTo(outEll1Ptr, outEll1Ptr);
    }

    /// @notice Выполняет умножение `_fq4MulByLinePtrTo`; точный уровень поля и специальный множитель отражены в названии.
    function _fq4MulByLinePtrTo(
        uint256 outPtr,
        uint256 fPtr,
        uint256 l0Ptr,
        uint256 l1Ptr,
        uint256 scratchPtr
    ) private pure {
        uint256 pV0 = scratchPtr;
        uint256 pV1 = scratchPtr + 6 * WORD;
        uint256 pFS = scratchPtr + 12 * WORD;
        uint256 pLS = scratchPtr + 18 * WORD;
        uint256 pFq2Scratch = scratchPtr + 24 * WORD;

        MNT4Extension.fq2MulTo(pV0, fPtr, l0Ptr, pFq2Scratch);
        MNT4Extension.fq2MulTo(pV1, fPtr + 6 * WORD, l1Ptr, pFq2Scratch);

        MNT4Extension.fq2MulByUTo(outPtr, pV1, pFq2Scratch);
        MNT4Extension.fq2AddTo(outPtr, outPtr, pV0);

        MNT4Extension.fq2AddTo(pFS, fPtr, fPtr + 6 * WORD);
        MNT4Extension.fq2AddTo(pLS, l0Ptr, l1Ptr);
        MNT4Extension.fq2MulTo(outPtr + 6 * WORD, pFS, pLS, pFq2Scratch);
        MNT4Extension.fq2SubTo(outPtr + 6 * WORD, outPtr + 6 * WORD, pV0);
        MNT4Extension.fq2SubTo(outPtr + 6 * WORD, outPtr + 6 * WORD, pV1);
    }

    /// @notice Возводит значение в квадрат: `_fq4SqrMulByLinePtrTo`.
    function _fq4SqrMulByLinePtrTo(
        uint256 outPtr,
        uint256 fPtr,
        uint256 l0Ptr,
        uint256 l1Ptr,
        uint256 scratchPtr
    ) private pure {
        uint256 pS0 = scratchPtr;
        uint256 pS1 = scratchPtr + 6 * WORD;
        uint256 pB2 = scratchPtr + 12 * WORD;
        uint256 pV0 = scratchPtr + 18 * WORD;
        uint256 pV1 = scratchPtr + 24 * WORD;
        uint256 pFS = scratchPtr + 30 * WORD;
        uint256 pLS = scratchPtr + 36 * WORD;
        uint256 pV2 = scratchPtr + 42 * WORD;
        uint256 pFq2Scratch = scratchPtr + 48 * WORD;

        // Fq4 is represented as a + b*v, v^2 = u.  Compute f^2 and immediately
        // Значение сразу используется в разреженном умножении на линию без сохранения полного
        // intermediate Fq4 element.
        MNT4Extension.fq2SqrTo(pV0, fPtr, pFq2Scratch);
        MNT4Extension.fq2SqrTo(pV1, fPtr + 6 * WORD, pFq2Scratch);
        MNT4Extension.fq2MulByUTo(pB2, pV1, pFq2Scratch);
        MNT4Extension.fq2AddTo(pS0, pV0, pB2);

        MNT4Extension.fq2MulTo(pS1, fPtr, fPtr + 6 * WORD, pFq2Scratch);
        MNT4Extension.fq2AddTo(pS1, pS1, pS1);

        MNT4Extension.fq2MulTo(pV0, pS0, l0Ptr, pFq2Scratch);
        MNT4Extension.fq2MulTo(pV1, pS1, l1Ptr, pFq2Scratch);

        MNT4Extension.fq2MulByUTo(outPtr, pV1, pFq2Scratch);
        MNT4Extension.fq2AddTo(outPtr, outPtr, pV0);

        MNT4Extension.fq2AddTo(pFS, pS0, pS1);
        MNT4Extension.fq2AddTo(pLS, l0Ptr, l1Ptr);
        MNT4Extension.fq2MulTo(pV2, pFS, pLS, pFq2Scratch);
        MNT4Extension.fq2AddTo(pFS, pV0, pV1);
        MNT4Extension.fq2SubTo(outPtr + 6 * WORD, pV2, pFS);
    }

    /// @notice Выполняет умножение `_lineDoubleSparseMulPtrTo`; точный уровень поля и специальный множитель отражены в названии.
    function _lineDoubleSparseMulPtrTo(
        uint256 outPtr,
        uint256 fPtr,
        uint256 ell0Ptr,
        uint256 ell1Ptr,
        uint256 tmpPtr,
        uint256 d0Ptr,
        uint256 d1Ptr,
        uint256 d2Ptr,
        uint256 pxPtr,
        uint256 pyPtr,
        uint256 scratchFq2Ptr,
        uint256 scratchFq4Ptr
    ) private pure {
        MNT4Extension.fq2MulByFp3To(tmpPtr, d1Ptr, pxPtr);
        MNT4Extension.fq2MulByUTo(tmpPtr, tmpPtr, scratchFq2Ptr);
        MNT4Extension.fq2SubTo(ell0Ptr, d0Ptr, tmpPtr);

        MNT4Extension.fq2MulByFp3To(ell1Ptr, d2Ptr, pyPtr);
        MNT4Extension.fq2MulByUTo(ell1Ptr, ell1Ptr, scratchFq2Ptr);
        uint256 pV0 = scratchFq4Ptr;
        uint256 pV1 = scratchFq4Ptr + 6 * WORD;
        uint256 pFS = scratchFq4Ptr + 12 * WORD;
        uint256 pLS = scratchFq4Ptr + 18 * WORD;
        uint256 pFq2Scratch = scratchFq4Ptr + 24 * WORD;

        MNT4Extension.fq2MulTo(pV0, fPtr, ell0Ptr, pFq2Scratch);
        MNT4Extension.fq2MulTo(pV1, fPtr + 6 * WORD, ell1Ptr, pFq2Scratch);

        MNT4Extension.fq2MulByUTo(outPtr, pV1, pFq2Scratch);
        MNT4Extension.fq2AddTo(outPtr, outPtr, pV0);

        MNT4Extension.fq2AddTo(pFS, fPtr, fPtr + 6 * WORD);
        MNT4Extension.fq2AddTo(pLS, ell0Ptr, ell1Ptr);
        MNT4Extension.fq2MulTo(outPtr + 6 * WORD, pFS, pLS, pFq2Scratch);
        MNT4Extension.fq2SubTo(outPtr + 6 * WORD, outPtr + 6 * WORD, pV0);
        MNT4Extension.fq2SubTo(outPtr + 6 * WORD, outPtr + 6 * WORD, pV1);
    }

    /// @notice Возводит значение в квадрат: `_lineDoubleSparseSqrMulPtrTo`.
    function _lineDoubleSparseSqrMulPtrTo(
        uint256 outPtr,
        uint256 fPtr,
        uint256 ell0Ptr,
        uint256 ell1Ptr,
        uint256 tmpPtr,
        uint256 d0Ptr,
        uint256 d1Ptr,
        uint256 d2Ptr,
        uint256 pxPtr,
        uint256 pyPtr,
        uint256 scratchFq2Ptr,
        uint256 scratchFusedPtr
    ) private pure {
        MNT4Extension.fq2MulByFp3To(tmpPtr, d1Ptr, pxPtr);
        MNT4Extension.fq2MulByUTo(tmpPtr, tmpPtr, scratchFq2Ptr);
        MNT4Extension.fq2SubTo(ell0Ptr, d0Ptr, tmpPtr);

        MNT4Extension.fq2MulByFp3To(ell1Ptr, d2Ptr, pyPtr);
        MNT4Extension.fq2MulByUTo(ell1Ptr, ell1Ptr, scratchFq2Ptr);
        _fq4SqrMulByLinePtrTo(outPtr, fPtr, ell0Ptr, ell1Ptr, scratchFusedPtr);
    }

    /// @notice Выполняет умножение `_lineAddSparseMulPtrTo`; точный уровень поля и специальный множитель отражены в названии.
    function _lineAddSparseMulPtrTo(
        uint256 outPtr,
        uint256 fPtr,
        uint256 ell0Ptr,
        uint256 ell1Ptr,
        uint256 tmpPtr,
        uint256 a0Ptr,
        uint256 a1Ptr,
        uint256 l1CoeffPtr,
        uint256 yOverTwistPtr,
        uint256 pyPtr,
        uint256 scratchFq2Ptr,
        uint256 scratchFq4Ptr
    ) private pure {
        MNT4Extension.fq2MulByFp3To(ell0Ptr, a0Ptr, pyPtr);
        MNT4Extension.fq2MulByUTo(ell0Ptr, ell0Ptr, scratchFq2Ptr);

        MNT4Extension.fq2MulTo(ell1Ptr, yOverTwistPtr, a0Ptr, scratchFq2Ptr);
        MNT4Extension.fq2MulTo(tmpPtr, l1CoeffPtr, a1Ptr, scratchFq2Ptr);
        MNT4Extension.fq2AddTo(ell1Ptr, ell1Ptr, tmpPtr);
        MNT4Extension.fq2NegTo(ell1Ptr, ell1Ptr);
        uint256 pV0 = scratchFq4Ptr;
        uint256 pV1 = scratchFq4Ptr + 6 * WORD;
        uint256 pFS = scratchFq4Ptr + 12 * WORD;
        uint256 pLS = scratchFq4Ptr + 18 * WORD;
        uint256 pFq2Scratch = scratchFq4Ptr + 24 * WORD;

        MNT4Extension.fq2MulTo(pV0, fPtr, ell0Ptr, pFq2Scratch);
        MNT4Extension.fq2MulTo(pV1, fPtr + 6 * WORD, ell1Ptr, pFq2Scratch);

        MNT4Extension.fq2MulByUTo(outPtr, pV1, pFq2Scratch);
        MNT4Extension.fq2AddTo(outPtr, outPtr, pV0);

        MNT4Extension.fq2AddTo(pFS, fPtr, fPtr + 6 * WORD);
        MNT4Extension.fq2AddTo(pLS, ell0Ptr, ell1Ptr);
        MNT4Extension.fq2MulTo(outPtr + 6 * WORD, pFS, pLS, pFq2Scratch);
        MNT4Extension.fq2SubTo(outPtr + 6 * WORD, outPtr + 6 * WORD, pV0);
        MNT4Extension.fq2SubTo(outPtr + 6 * WORD, outPtr + 6 * WORD, pV1);
    }

    /// @notice Выполняет внутреннюю операцию `_twistACoeff`; параметры и результат используют представление текущей библиотеки.
    function _twistACoeff() private pure returns (MNT4ExtensionFinal.Fq2 memory aCoeff) {
        aCoeff.c0[0] = TWIST_A_C0_0;
        aCoeff.c0[1] = TWIST_A_C0_1;
        aCoeff.c0[2] = TWIST_A_C0_2;
        aCoeff.c1[0] = 0;
        aCoeff.c1[1] = 0;
        aCoeff.c1[2] = 0;
    }

    /// @notice Вычисляет мультипликативно обратное значение: `_twistInv`.
    function _twistInv() private pure returns (MNT4ExtensionFinal.Fq2 memory tInv) {
        tInv.c0[0] = 0;
        tInv.c0[1] = 0;
        tInv.c0[2] = 0;
        tInv.c1[0] = INV13_MONT_0;
        tInv.c1[1] = INV13_MONT_1;
        tInv.c1[2] = INV13_MONT_2;
    }

    /// @notice Выполняет внутреннюю операцию `_doublingStep`; параметры и результат используют представление текущей библиотеки.
    function _doublingStep(
        G2ProjectiveExtended memory r
    ) private pure returns (G2ProjectiveExtended memory r2, AteDoubleCoefficients memory coeff) {
        MNT4ExtensionFinal.Fq2 memory a = MNT4ExtensionFinal.fq2Sqr(r.t);
        MNT4ExtensionFinal.Fq2 memory b = MNT4ExtensionFinal.fq2Sqr(r.x);
        MNT4ExtensionFinal.Fq2 memory c = MNT4ExtensionFinal.fq2Sqr(r.y);
        MNT4ExtensionFinal.Fq2 memory d = MNT4ExtensionFinal.fq2Sqr(c);

        MNT4ExtensionFinal.Fq2 memory e = MNT4ExtensionFinal.fq2Sub(
            MNT4ExtensionFinal.fq2Sub(MNT4ExtensionFinal.fq2Sqr(MNT4ExtensionFinal.fq2Add(r.x, c)), b),
            d
        );

        MNT4ExtensionFinal.Fq2 memory f = MNT4ExtensionFinal.fq2Add(b, MNT4ExtensionFinal.fq2Add(b, b));
        f = MNT4ExtensionFinal.fq2Add(f, MNT4ExtensionFinal.fq2Mul(_twistACoeff(), a));
        MNT4ExtensionFinal.Fq2 memory g = MNT4ExtensionFinal.fq2Sqr(f);

        MNT4ExtensionFinal.Fq2 memory d8 = MNT4ExtensionFinal.fq2Add(d, d);
        d8 = MNT4ExtensionFinal.fq2Add(d8, d8);
        d8 = MNT4ExtensionFinal.fq2Add(d8, d8);

        MNT4ExtensionFinal.Fq2 memory e4 = MNT4ExtensionFinal.fq2Add(e, e);
        e4 = MNT4ExtensionFinal.fq2Add(e4, e4);

        r2.x = MNT4ExtensionFinal.fq2Sub(g, e4);

        MNT4ExtensionFinal.Fq2 memory twoEminusX = MNT4ExtensionFinal.fq2Sub(MNT4ExtensionFinal.fq2Add(e, e), r2.x);
        r2.y = MNT4ExtensionFinal.fq2Sub(MNT4ExtensionFinal.fq2Mul(f, twoEminusX), d8);

        r2.z = MNT4ExtensionFinal.fq2Sub(
            MNT4ExtensionFinal.fq2Sub(MNT4ExtensionFinal.fq2Sqr(MNT4ExtensionFinal.fq2Add(r.y, r.z)), c),
            MNT4ExtensionFinal.fq2Sqr(r.z)
        );
        r2.t = MNT4ExtensionFinal.fq2Sqr(r2.z);

        coeff.c_h = MNT4ExtensionFinal.fq2Sub(
            MNT4ExtensionFinal.fq2Sub(MNT4ExtensionFinal.fq2Sqr(MNT4ExtensionFinal.fq2Add(r2.z, r.t)), r2.t),
            a
        );

        coeff.c_4c = MNT4ExtensionFinal.fq2Add(c, c);
        coeff.c_4c = MNT4ExtensionFinal.fq2Add(coeff.c_4c, coeff.c_4c);

        coeff.c_j = MNT4ExtensionFinal.fq2Sub(
            MNT4ExtensionFinal.fq2Sub(MNT4ExtensionFinal.fq2Sqr(MNT4ExtensionFinal.fq2Add(f, r.t)), g),
            a
        );

        coeff.c_l = MNT4ExtensionFinal.fq2Sub(
            MNT4ExtensionFinal.fq2Sub(MNT4ExtensionFinal.fq2Sqr(MNT4ExtensionFinal.fq2Add(f, r.x)), g),
            b
        );
    }

    /// @notice Выполняет сложение `_mixedAdditionStep` с учетом модуля или структуры текущего поля.
    function _mixedAdditionStep(
        MNT4ExtensionFinal.Fq2 memory x,
        MNT4ExtensionFinal.Fq2 memory y,
        G2ProjectiveExtended memory r
    ) private pure returns (G2ProjectiveExtended memory r2, AteAdditionCoefficients memory coeff) {
        MNT4ExtensionFinal.Fq2 memory a = MNT4ExtensionFinal.fq2Sqr(y);
        MNT4ExtensionFinal.Fq2 memory b = MNT4ExtensionFinal.fq2Mul(r.t, x);
        MNT4ExtensionFinal.Fq2 memory d = MNT4ExtensionFinal.fq2Mul(
            MNT4ExtensionFinal.fq2Sub(MNT4ExtensionFinal.fq2Sub(MNT4ExtensionFinal.fq2Sqr(MNT4ExtensionFinal.fq2Add(r.z, y)), a), r.t),
            r.t
        );
        MNT4ExtensionFinal.Fq2 memory h = MNT4ExtensionFinal.fq2Sub(b, r.x);
        MNT4ExtensionFinal.Fq2 memory i = MNT4ExtensionFinal.fq2Sqr(h);

        MNT4ExtensionFinal.Fq2 memory e = MNT4ExtensionFinal.fq2Add(i, i);
        e = MNT4ExtensionFinal.fq2Add(e, e);

        MNT4ExtensionFinal.Fq2 memory j = MNT4ExtensionFinal.fq2Mul(h, e);
        MNT4ExtensionFinal.Fq2 memory v = MNT4ExtensionFinal.fq2Mul(r.x, e);

        MNT4ExtensionFinal.Fq2 memory y2 = MNT4ExtensionFinal.fq2Add(r.y, r.y);
        MNT4ExtensionFinal.Fq2 memory l1 = MNT4ExtensionFinal.fq2Sub(d, y2);

        r2.x = MNT4ExtensionFinal.fq2Sub(MNT4ExtensionFinal.fq2Sub(MNT4ExtensionFinal.fq2Sqr(l1), j), MNT4ExtensionFinal.fq2Add(v, v));
        r2.y = MNT4ExtensionFinal.fq2Sub(MNT4ExtensionFinal.fq2Mul(l1, MNT4ExtensionFinal.fq2Sub(v, r2.x)), MNT4ExtensionFinal.fq2Mul(j, y2));
        r2.z = MNT4ExtensionFinal.fq2Sub(MNT4ExtensionFinal.fq2Sub(MNT4ExtensionFinal.fq2Sqr(MNT4ExtensionFinal.fq2Add(r.z, h)), r.t), i);
        r2.t = MNT4ExtensionFinal.fq2Sqr(r2.z);

        coeff.c_l1 = l1;
        coeff.c_rz = r2.z;
    }

    /// @notice Выполняет внутреннюю операцию `_lineDoubleAtP4To`; параметры и результат используют представление текущей библиотеки.
    function _lineDoubleAtP4To(
        MNT4ExtensionFinal.Fq2 memory out0,
        MNT4ExtensionFinal.Fq2 memory out1,
        MNT4ExtensionFinal.Fq2 memory c_h,
        MNT4ExtensionFinal.Fq2 memory c_4c,
        MNT4ExtensionFinal.Fq2 memory c_j,
        MNT4ExtensionFinal.Fq2 memory c_l,
        uint256[3] memory px,
        uint256[3] memory py
    ) private pure {
        // out0 = c_l - c_4c - c_j*px*twist
        MNT4ExtensionFinal.Fq2 memory c_j_x = _fq2MulByTwistFp(c_j, px);
        (out0.c0[0], out0.c0[1], out0.c0[2]) = BigIntMNT.sub3(
            c_l.c0[0], c_l.c0[1], c_l.c0[2],
            c_4c.c0[0], c_4c.c0[1], c_4c.c0[2]
        );
        (out0.c0[0], out0.c0[1], out0.c0[2]) = BigIntMNT.sub3(
            out0.c0[0], out0.c0[1], out0.c0[2],
            c_j_x.c0[0], c_j_x.c0[1], c_j_x.c0[2]
        );

        (out0.c1[0], out0.c1[1], out0.c1[2]) = BigIntMNT.sub3(
            c_l.c1[0], c_l.c1[1], c_l.c1[2],
            c_4c.c1[0], c_4c.c1[1], c_4c.c1[2]
        );
        (out0.c1[0], out0.c1[1], out0.c1[2]) = BigIntMNT.sub3(
            out0.c1[0], out0.c1[1], out0.c1[2],
            c_j_x.c1[0], c_j_x.c1[1], c_j_x.c1[2]
        );

        MNT4ExtensionFinal.fq2MulByFpTo(out1, c_h, py);
        uint256 t00 = out1.c0[0];
        uint256 t01 = out1.c0[1];
        uint256 t02 = out1.c0[2];
        uint256 t10 = out1.c1[0];
        uint256 t11 = out1.c1[1];
        uint256 t12 = out1.c1[2];
        (out1.c0[0], out1.c0[1], out1.c0[2]) = MNT4ExtensionFinal.fpMulBy13(t10, t11, t12);
        out1.c1[0] = t00;
        out1.c1[1] = t01;
        out1.c1[2] = t02;
    }

    /// @notice Выполняет сложение `_lineAddAtP2To` с учетом модуля или структуры текущего поля.
    function _lineAddAtP2To(
        MNT4ExtensionFinal.Fq2 memory out0,
        MNT4ExtensionFinal.Fq2 memory out1,
        MNT4ExtensionFinal.Fq2 memory c_l1,
        MNT4ExtensionFinal.Fq2 memory c_rz,
        MNT4ExtensionFinal.Fq2 memory l1Coeff,
        MNT4ExtensionFinal.Fq2 memory yOverTwist,
        uint256[3] memory py
    ) private pure {
        MNT4ExtensionFinal.fq2MulByFpTo(out0, c_rz, py);
        uint256 t00 = out0.c0[0];
        uint256 t01 = out0.c0[1];
        uint256 t02 = out0.c0[2];
        uint256 t10 = out0.c1[0];
        uint256 t11 = out0.c1[1];
        uint256 t12 = out0.c1[2];
        (out0.c0[0], out0.c0[1], out0.c0[2]) = MNT4ExtensionFinal.fpMulBy13(t10, t11, t12);
        out0.c1[0] = t00;
        out0.c1[1] = t01;
        out0.c1[2] = t02;

        MNT4ExtensionFinal.Fq2 memory t0 = _allocFq2();
        MNT4ExtensionFinal.Fq2 memory t1 = _allocFq2();
        MNT4ExtensionFinal.fq2MulTo(t0, yOverTwist, c_rz);
        MNT4ExtensionFinal.fq2MulTo(t1, l1Coeff, c_l1);

        (out1.c0[0], out1.c0[1], out1.c0[2]) = BigIntMNT.add3(
            t0.c0[0], t0.c0[1], t0.c0[2],
            t1.c0[0], t1.c0[1], t1.c0[2]
        );
        (out1.c1[0], out1.c1[1], out1.c1[2]) = BigIntMNT.add3(
            t0.c1[0], t0.c1[1], t0.c1[2],
            t1.c1[0], t1.c1[1], t1.c1[2]
        );

        (out1.c0[0], out1.c0[1], out1.c0[2]) = BigIntMNT.sub3(0, 0, 0, out1.c0[0], out1.c0[1], out1.c0[2]);
        (out1.c1[0], out1.c1[1], out1.c1[2]) = BigIntMNT.sub3(0, 0, 0, out1.c1[0], out1.c1[1], out1.c1[2]);
    }

    /// @notice Выполняет внутреннюю операцию `_lineDoubleSparseTo`; параметры и результат используют представление текущей библиотеки.
    function _lineDoubleSparseTo(
        MNT4ExtensionFinal.Fq2 memory out0,
        MNT4ExtensionFinal.Fq2 memory out1,
        MNT4ExtensionFinal.Fq2 memory tmp,
        MNT4ExtensionFinal.Fq2 memory d0,
        MNT4ExtensionFinal.Fq2 memory d1,
        MNT4ExtensionFinal.Fq2 memory d2,
        uint256[3] memory px,
        uint256[3] memory py
    ) private pure {
        _fq2MulByTwistFpTo(tmp, d1, px);
        MNT4ExtensionFinal.fq2SubTo(out0, d0, tmp);
        _fq2MulByTwistFpTo(out1, d2, py);
    }

    /// @notice Выполняет сложение `_lineAddSparseTo` с учетом модуля или структуры текущего поля.
    function _lineAddSparseTo(
        MNT4ExtensionFinal.Fq2 memory out0,
        MNT4ExtensionFinal.Fq2 memory out1,
        MNT4ExtensionFinal.Fq2 memory tmp0,
        MNT4ExtensionFinal.Fq2 memory tmp1,
        MNT4ExtensionFinal.Fq2 memory a0,
        MNT4ExtensionFinal.Fq2 memory a1,
        MNT4ExtensionFinal.Fq2 memory l1Coeff,
        MNT4ExtensionFinal.Fq2 memory yOverTwist,
        uint256[3] memory py
    ) private pure {
        _fq2MulByTwistFpTo(out0, a0, py);
        MNT4ExtensionFinal.fq2MulTo(tmp0, yOverTwist, a0);
        MNT4ExtensionFinal.fq2MulTo(tmp1, l1Coeff, a1);
        MNT4ExtensionFinal.fq2AddTo(out1, tmp0, tmp1);
        MNT4ExtensionFinal.fq2NegTo(out1, out1);
    }

    /// @notice Выполняет умножение `_fq4MulByLine`; точный уровень поля и специальный множитель отражены в названии.
    function _fq4MulByLine(
        MNT4ExtensionFinal.Fq4 memory f,
        MNT4ExtensionFinal.Fq2 memory l0,
        MNT4ExtensionFinal.Fq2 memory l1
    ) private pure returns (MNT4ExtensionFinal.Fq4 memory r) {
        // Специализированная ветка для значения линейной функции.
        MNT4ExtensionFinal.Fq2 memory v0 = MNT4ExtensionFinal.fq2Mul(f.c0, l0);
        MNT4ExtensionFinal.Fq2 memory v1 = MNT4ExtensionFinal.fq2Mul(f.c1, l1);

        r.c0 = MNT4ExtensionFinal.fq2Add(v0, MNT4ExtensionFinal.fq2MulByU(v1));

        MNT4ExtensionFinal.Fq2 memory fs = MNT4ExtensionFinal.fq2Add(f.c0, f.c1);
        MNT4ExtensionFinal.Fq2 memory ls = MNT4ExtensionFinal.fq2Add(l0, l1);
        r.c1 = MNT4ExtensionFinal.fq2Sub(MNT4ExtensionFinal.fq2Sub(MNT4ExtensionFinal.fq2Mul(fs, ls), v0), v1);
    }

    /// @notice Выполняет умножение `_fq4MulByLineTo`; точный уровень поля и специальный множитель отражены в названии.
    function _fq4MulByLineTo(
        MNT4ExtensionFinal.Fq4 memory out,
        MNT4ExtensionFinal.Fq4 memory f,
        MNT4ExtensionFinal.Fq2 memory l0,
        MNT4ExtensionFinal.Fq2 memory l1
    ) private pure {
        MNT4ExtensionFinal.Fq2 memory v0 = _allocFq2();
        MNT4ExtensionFinal.Fq2 memory v1 = _allocFq2();
        MNT4ExtensionFinal.Fq2 memory fs = _allocFq2();
        MNT4ExtensionFinal.Fq2 memory ls = _allocFq2();

        MNT4ExtensionFinal.fq2MulTo(v0, f.c0, l0);
        MNT4ExtensionFinal.fq2MulTo(v1, f.c1, l1);

        MNT4ExtensionFinal.fq2MulByUTo(out.c0, v1);
        MNT4ExtensionFinal.fq2AddTo(out.c0, out.c0, v0);

        MNT4ExtensionFinal.fq2AddTo(fs, f.c0, f.c1);
        MNT4ExtensionFinal.fq2AddTo(ls, l0, l1);
        MNT4ExtensionFinal.fq2MulTo(out.c1, fs, ls);
        MNT4ExtensionFinal.fq2SubTo(out.c1, out.c1, v0);
        MNT4ExtensionFinal.fq2SubTo(out.c1, out.c1, v1);
    }

    /// @notice Выполняет умножение `_fq4MulByLineToScratch`; точный уровень поля и специальный множитель отражены в названии.
    function _fq4MulByLineToScratch(
        MNT4ExtensionFinal.Fq4 memory out,
        MNT4ExtensionFinal.Fq4 memory f,
        MNT4ExtensionFinal.Fq2 memory l0,
        MNT4ExtensionFinal.Fq2 memory l1,
        MNT4ExtensionFinal.Fq2 memory v0,
        MNT4ExtensionFinal.Fq2 memory v1,
        MNT4ExtensionFinal.Fq2 memory fs,
        MNT4ExtensionFinal.Fq2 memory ls
    ) private pure {
        MNT4ExtensionFinal.fq2MulTo(v0, f.c0, l0);
        MNT4ExtensionFinal.fq2MulTo(v1, f.c1, l1);

        MNT4ExtensionFinal.fq2MulByUTo(out.c0, v1);
        MNT4ExtensionFinal.fq2AddTo(out.c0, out.c0, v0);

        MNT4ExtensionFinal.fq2AddTo(fs, f.c0, f.c1);
        MNT4ExtensionFinal.fq2AddTo(ls, l0, l1);
        MNT4ExtensionFinal.fq2MulTo(out.c1, fs, ls);
        MNT4ExtensionFinal.fq2SubTo(out.c1, out.c1, v0);
        MNT4ExtensionFinal.fq2SubTo(out.c1, out.c1, v1);
    }

    /// @notice Формирует подготовленные данные `millerLoopFixedQPreparedSparseBlobNoInv`, которые затем переиспользуются в цикле Миллера.
    function millerLoopFixedQPreparedSparseBlobNoInv(
        G1Affine memory p,
        bytes calldata dblSparse,
        bytes calldata addSparse
    ) internal pure returns (MNT4ExtensionFinal.Fq4 memory f) {
        require(dblSparse.length == FIXED_DBL_SPARSE_BYTES, "bad dbl sparse");
        require(addSparse.length == FIXED_ADD_SPARSE_BYTES, "bad add sparse");
        bytes memory loop = ATE_LOOP_ENC;

        (uint256 pQxOverTwist, uint256 pQyOverTwist, uint256 pQyOverTwistNeg) = _fixedQOverTwistPtrs();
        uint256 pPx = _ptrFp3(p.x);
        uint256 pPy = _ptrFp3(p.y);

        f = _allocFq4();
        uint256 pFBase = _ptrFq4(f);
        _setFq4OnePtr(pFBase);

        uint256 arena = _allocWords(174);
        _zeroWords(arena, 174);
        uint256 pTmp = arena;
        uint256 pD0 = pTmp + 12 * WORD;
        uint256 pD1 = pD0 + 6 * WORD;
        uint256 pD2 = pD1 + 6 * WORD;
        uint256 pA0 = pD2 + 6 * WORD;
        uint256 pA1 = pA0 + 6 * WORD;
        uint256 pEll0 = pA1 + 6 * WORD;
        uint256 pEll1 = pEll0 + 6 * WORD;
        uint256 pEvalTmp = pEll1 + 6 * WORD;
        uint256 pL1Coeff = pEvalTmp + 6 * WORD;
        uint256 pScratchSqr = pL1Coeff + 6 * WORD;
        uint256 pScratchMulByLine = pScratchSqr + 54 * WORD;

        _buildL1CoeffFromPxPtrTo(pL1Coeff, pPx, pQxOverTwist);

        uint256 pF = pFBase;
        uint256 dOff;
        uint256 aOff;
        for (uint256 i = 1; i < loop.length; ++i) {
            dOff = _loadSparseDblStepCalldataToPtr(pD0, dblSparse, dOff);

            MNT4Extension.fq4SqrTo(pTmp, pF, pScratchSqr);
            uint256 tmpSwap = pF;
            pF = pTmp;
            pTmp = tmpSwap;
            _lineDoubleSparseMulPtrTo(
                pTmp, pF, pEll0, pEll1, pEvalTmp, pD0, pD1, pD2, pPx, pPy, pScratchSqr, pScratchMulByLine
            );
            tmpSwap = pF;
            pF = pTmp;
            pTmp = tmpSwap;

            int8 bit = _decodeLoopMem(loop, i);
            if (bit == 0) continue;

            aOff = _loadSparseAddStepCalldataToPtr(pA0, addSparse, aOff);

            _lineAddSparseMulPtrTo(
                pTmp,
                pF,
                pEll0,
                pEll1,
                pEvalTmp,
                pA0,
                pA1,
                pL1Coeff,
                bit == 1 ? pQyOverTwist : pQyOverTwistNeg,
                pPy,
                pScratchSqr,
                pScratchMulByLine
            );
            tmpSwap = pF;
            pF = pTmp;
            pTmp = tmpSwap;
        }

        if (ATE_IS_LOOP_COUNT_NEG) {
            aOff = _loadSparseAddStepCalldataToPtr(pA0, addSparse, aOff);

            uint256 tmpSwap = pF;
            _lineAddSparseMulPtrTo(
                pTmp, pF, pEll0, pEll1, pEvalTmp, pA0, pA1, pL1Coeff, pQyOverTwist, pPy, pScratchSqr,
                pScratchMulByLine
            );
            pF = pTmp;
            pTmp = tmpSwap;
        }

        if (pF != pFBase) {
            _copyFq4Ptr(pFBase, pF);
        }
    }

    /// @notice Формирует подготовленные данные `multiMillerLoopFixedQPreparedSparseBlobNoInv`, которые затем переиспользуются в цикле Миллера.
    function multiMillerLoopFixedQPreparedSparseBlobNoInv(
        G1Affine[] calldata points,
        bytes calldata dblSparse,
        bytes calldata addSparse
    ) internal pure returns (MNT4ExtensionFinal.Fq4 memory f) {
        require(points.length > 0, "no points");
        require(dblSparse.length == FIXED_DBL_SPARSE_BYTES, "bad dbl sparse");
        require(addSparse.length == FIXED_ADD_SPARSE_BYTES, "bad add sparse");
        bytes memory loop = ATE_LOOP_ENC;

        (uint256 pQxOverTwist, uint256 pQyOverTwist, uint256 pQyOverTwistNeg) = _fixedQOverTwistPtrs();

        f = _allocFq4();
        uint256 pFBase = _ptrFq4(f);
        _setFq4OnePtr(pFBase);

        uint256 n = points.length;
        uint256 pPoints = _allocWords(12 * n); // per point: px(3), py(3), l1Coeff(6)
        for (uint256 i = 0; i < n; ++i) {
            uint256 pPoint = pPoints + i * 12 * WORD;
            uint256 x0 = points[i].x[0];
            uint256 x1 = points[i].x[1];
            uint256 x2 = points[i].x[2];
            uint256 y0 = points[i].y[0];
            uint256 y1 = points[i].y[1];
            uint256 y2 = points[i].y[2];
            assembly ("memory-safe") {
                mstore(pPoint, x0)
                mstore(add(pPoint, 0x20), x1)
                mstore(add(pPoint, 0x40), x2)
                mstore(add(pPoint, 0x60), y0)
                mstore(add(pPoint, 0x80), y1)
                mstore(add(pPoint, 0xa0), y2)
            }
            _buildL1CoeffFromPxPtrTo(pPoint + 6 * WORD, pPoint, pQxOverTwist);
        }

        uint256 arena = _allocWords(168);
        _zeroWords(arena, 168);
        uint256 pTmp = arena;
        uint256 pD0 = pTmp + 12 * WORD;
        uint256 pD1 = pD0 + 6 * WORD;
        uint256 pD2 = pD1 + 6 * WORD;
        uint256 pA0 = pD2 + 6 * WORD;
        uint256 pA1 = pA0 + 6 * WORD;
        uint256 pEll0 = pA1 + 6 * WORD;
        uint256 pEll1 = pEll0 + 6 * WORD;
        uint256 pEvalTmp = pEll1 + 6 * WORD;
        uint256 pScratchSqr = pEvalTmp + 6 * WORD;
        uint256 pScratchMulByLine = pScratchSqr + 54 * WORD;

        uint256 pF = pFBase;
        uint256 dOff;
        uint256 aOff;
        for (uint256 i = 1; i < loop.length; ++i) {
            MNT4Extension.fq4SqrTo(pTmp, pF, pScratchSqr);
            uint256 tmpSwap = pF;
            pF = pTmp;
            pTmp = tmpSwap;

            dOff = _loadSparseDblStepCalldataToPtr(pD0, dblSparse, dOff);

            for (uint256 j = 0; j < n; ++j) {
                uint256 pPoint = pPoints + j * 12 * WORD;
                uint256 pPx = pPoint;
                uint256 pPy = pPoint + 3 * WORD;

                _lineDoubleSparseMulPtrTo(
                    pTmp, pF, pEll0, pEll1, pEvalTmp, pD0, pD1, pD2, pPx, pPy, pScratchSqr, pScratchMulByLine
                );
                tmpSwap = pF;
                pF = pTmp;
                pTmp = tmpSwap;
            }

            int8 bit = _decodeLoopMem(loop, i);
            if (bit == 0) continue;

            aOff = _loadSparseAddStepCalldataToPtr(pA0, addSparse, aOff);
            uint256 pYOT = bit == 1 ? pQyOverTwist : pQyOverTwistNeg;

            for (uint256 j = 0; j < n; ++j) {
                uint256 pPoint = pPoints + j * 12 * WORD;
                uint256 pPy = pPoint + 3 * WORD;
                uint256 pL1Coeff = pPoint + 6 * WORD;

                _lineAddSparseMulPtrTo(
                    pTmp, pF, pEll0, pEll1, pEvalTmp, pA0, pA1, pL1Coeff, pYOT, pPy, pScratchSqr,
                    pScratchMulByLine
                );
                tmpSwap = pF;
                pF = pTmp;
                pTmp = tmpSwap;
            }
        }

        if (ATE_IS_LOOP_COUNT_NEG) {
            aOff = _loadSparseAddStepCalldataToPtr(pA0, addSparse, aOff);

            for (uint256 j = 0; j < n; ++j) {
                uint256 pPoint = pPoints + j * 12 * WORD;
                uint256 pPy = pPoint + 3 * WORD;
                uint256 pL1Coeff = pPoint + 6 * WORD;

                uint256 tmpSwap = pF;
                _lineAddSparseMulPtrTo(
                    pTmp, pF, pEll0, pEll1, pEvalTmp, pA0, pA1, pL1Coeff, pQyOverTwist, pPy, pScratchSqr,
                    pScratchMulByLine
                );
                pF = pTmp;
                pTmp = tmpSwap;
            }
        }

        if (pF != pFBase) {
            _copyFq4Ptr(pFBase, pF);
        }
    }

    /// @notice Формирует подготовленные данные `_millerLoopFixedQPreparedSparseBlobNoInvMemTo`, которые затем переиспользуются в цикле Миллера.
    function _millerLoopFixedQPreparedSparseBlobNoInvMemTo(
        uint256 pFBase,
        G1Affine memory p,
        bytes memory dblSparse,
        bytes memory addSparse
    ) private pure {
        G1Affine[] memory one = new G1Affine[](1);
        one[0] = p;
        _multiMillerLoopFixedQPreparedSparseBlobNoInvMemTo(pFBase, one, dblSparse, addSparse);
    }

    /// @notice Формирует подготовленные данные `millerLoopFixedQPreparedSparseBlobNoInvMem`, которые затем переиспользуются в цикле Миллера.
    function millerLoopFixedQPreparedSparseBlobNoInvMem(
        G1Affine memory p,
        bytes memory dblSparse,
        bytes memory addSparse
    ) internal pure returns (MNT4ExtensionFinal.Fq4 memory f) {
        f = _allocFq4();
        _millerLoopFixedQPreparedSparseBlobNoInvMemTo(_ptrFq4(f), p, dblSparse, addSparse);
    }

    /// @notice Формирует подготовленные данные `millerLoopFixedQPreparedSparseBlobNoInvMemDigest`, которые затем переиспользуются в цикле Миллера.
    function millerLoopFixedQPreparedSparseBlobNoInvMemDigest(
        G1Affine memory p,
        bytes memory dblSparse,
        bytes memory addSparse
    ) internal pure returns (bytes32 digest) {
        uint256 pM = _allocWords(12);
        _millerLoopFixedQPreparedSparseBlobNoInvMemTo(pM, p, dblSparse, addSparse);
        _normalizeFq4PtrStrong(pM);
        assembly ("memory-safe") { digest := keccak256(pM, 0x180) }
    }

    /// @notice Формирует подготовленные данные `_multiMillerLoopFixedQPreparedSparseBlobNoInvMemTo`, которые затем переиспользуются в цикле Миллера.
    function _multiMillerLoopFixedQPreparedSparseBlobNoInvMemTo(
        uint256 pFBase,
        G1Affine[] memory points,
        bytes memory dblSparse,
        bytes memory addSparse
    ) private pure {
        require(points.length > 0, "no points");
        require(dblSparse.length == FIXED_DBL_SPARSE_BYTES, "bad dbl sparse");
        require(addSparse.length == FIXED_ADD_SPARSE_BYTES, "bad add sparse");
        bytes memory loop = ATE_LOOP_ENC;

        (uint256 pQxOverTwist, uint256 pQyOverTwist, uint256 pQyOverTwistNeg) = _fixedQOverTwistPtrs();

        _setFq4OnePtr(pFBase);

        uint256 n = points.length;
        uint256 pPoints = _allocWords(12 * n); // per point: px(3), py(3), l1Coeff(6)
        for (uint256 i = 0; i < n; ++i) {
            uint256 pPoint = pPoints + i * 12 * WORD;
            uint256 x0 = points[i].x[0];
            uint256 x1 = points[i].x[1];
            uint256 x2 = points[i].x[2];
            uint256 y0 = points[i].y[0];
            uint256 y1 = points[i].y[1];
            uint256 y2 = points[i].y[2];
            assembly ("memory-safe") {
                mstore(pPoint, x0)
                mstore(add(pPoint, 0x20), x1)
                mstore(add(pPoint, 0x40), x2)
                mstore(add(pPoint, 0x60), y0)
                mstore(add(pPoint, 0x80), y1)
                mstore(add(pPoint, 0xa0), y2)
            }
            _buildL1CoeffFromPxPtrTo(pPoint + 6 * WORD, pPoint, pQxOverTwist);
        }

        uint256 arena = _allocWords(168);
        _zeroWords(arena, 168);
        uint256 pTmp = arena;
        uint256 pD0 = pTmp + 12 * WORD;
        uint256 pD1 = pD0 + 6 * WORD;
        uint256 pD2 = pD1 + 6 * WORD;
        uint256 pA0 = pD2 + 6 * WORD;
        uint256 pA1 = pA0 + 6 * WORD;
        uint256 pEll0 = pA1 + 6 * WORD;
        uint256 pEll1 = pEll0 + 6 * WORD;
        uint256 pEvalTmp = pEll1 + 6 * WORD;
        uint256 pScratchSqr = pEvalTmp + 6 * WORD;
        uint256 pScratchMulByLine = pScratchSqr + 54 * WORD;

        uint256 pF = pFBase;
        uint256 dOff;
        uint256 aOff;
        for (uint256 i = 1; i < loop.length; ++i) {
            MNT4Extension.fq4SqrTo(pTmp, pF, pScratchSqr);
            uint256 tmpSwap = pF;
            pF = pTmp;
            pTmp = tmpSwap;

            dOff = _loadSparseDblStepMemoryToPtr(pD0, dblSparse, dOff);

            for (uint256 j = 0; j < n; ++j) {
                uint256 pPoint = pPoints + j * 12 * WORD;
                uint256 pPx = pPoint;
                uint256 pPy = pPoint + 3 * WORD;

                _lineDoubleSparseMulPtrTo(
                    pTmp, pF, pEll0, pEll1, pEvalTmp, pD0, pD1, pD2, pPx, pPy, pScratchSqr, pScratchMulByLine
                );
                tmpSwap = pF;
                pF = pTmp;
                pTmp = tmpSwap;
            }

            int8 bit = _decodeLoopMem(loop, i);
            if (bit == 0) continue;

            aOff = _loadSparseAddStepMemoryToPtr(pA0, addSparse, aOff);
            uint256 pYOT = bit == 1 ? pQyOverTwist : pQyOverTwistNeg;

            for (uint256 j = 0; j < n; ++j) {
                uint256 pPoint = pPoints + j * 12 * WORD;
                uint256 pPy = pPoint + 3 * WORD;
                uint256 pL1Coeff = pPoint + 6 * WORD;

                _lineAddSparseMulPtrTo(
                    pTmp, pF, pEll0, pEll1, pEvalTmp, pA0, pA1, pL1Coeff, pYOT, pPy, pScratchSqr,
                    pScratchMulByLine
                );
                tmpSwap = pF;
                pF = pTmp;
                pTmp = tmpSwap;
            }
        }

        if (ATE_IS_LOOP_COUNT_NEG) {
            aOff = _loadSparseAddStepMemoryToPtr(pA0, addSparse, aOff);

            for (uint256 j = 0; j < n; ++j) {
                uint256 pPoint = pPoints + j * 12 * WORD;
                uint256 pPy = pPoint + 3 * WORD;
                uint256 pL1Coeff = pPoint + 6 * WORD;

                uint256 tmpSwap = pF;
                _lineAddSparseMulPtrTo(
                    pTmp, pF, pEll0, pEll1, pEvalTmp, pA0, pA1, pL1Coeff, pQyOverTwist, pPy, pScratchSqr,
                    pScratchMulByLine
                );
                pF = pTmp;
                pTmp = tmpSwap;
            }
        }

        if (pF != pFBase) {
            _copyFq4Ptr(pFBase, pF);
        }
    }

    /// @notice Выполняет внутреннюю операцию `_ptrWords`; параметры и результат используют представление текущей библиотеки.
    function _ptrWords(G1Affine[] memory arr) private pure returns (uint256 p) {
        assembly ("memory-safe") { p := arr }
    }

    /// @notice Выполняет внутреннюю операцию `_bytesEndPtr`; параметры и результат используют представление текущей библиотеки.
    function _bytesEndPtr(bytes memory data) private pure returns (uint256 endPtr) {
        assembly ("memory-safe") {
            endPtr := add(add(data, 0x20), mload(data))
        }
    }

    /// @notice Формирует подготовленные данные `multiMillerLoopFixedQPreparedSparseBlobNoInvMem`, которые затем переиспользуются в цикле Миллера.
    function multiMillerLoopFixedQPreparedSparseBlobNoInvMem(
        G1Affine[] memory points,
        bytes memory dblSparse,
        bytes memory addSparse
    ) internal pure returns (MNT4ExtensionFinal.Fq4 memory f) {
        f = _allocFq4();
        _multiMillerLoopFixedQPreparedSparseBlobNoInvMemTo(_ptrFq4(f), points, dblSparse, addSparse);
    }

    /// @notice Формирует подготовленные данные `multiMillerLoopFixedQPreparedSparseBlobNoInvMemDigest`, которые затем переиспользуются в цикле Миллера.
    function multiMillerLoopFixedQPreparedSparseBlobNoInvMemDigest(
        G1Affine[] memory points,
        bytes memory dblSparse,
        bytes memory addSparse
    ) internal pure returns (bytes32 digest) {
        uint256 pM = _allocWords(12);
        _multiMillerLoopFixedQPreparedSparseBlobNoInvMemTo(pM, points, dblSparse, addSparse);
        _normalizeFq4PtrStrong(pM);
        assembly ("memory-safe") { digest := keccak256(pM, 0x180) }
    }

    /// @notice Формирует подготовленные данные `_millerLoopFixedQPreparedSparseBlobNoInvMemAggressiveTo`, которые затем переиспользуются в цикле Миллера.
    function _millerLoopFixedQPreparedSparseBlobNoInvMemAggressiveTo(
        uint256 pFBase,
        G1Affine memory p,
        bytes memory dblSparse,
        bytes memory addSparse
    ) private pure {
        G1Affine[] memory one = new G1Affine[](1);
        one[0] = p;
        _multiMillerLoopFixedQPreparedSparseBlobNoInvMemAggressiveTo(pFBase, one, dblSparse, addSparse);
    }

    /// @notice Формирует подготовленные данные `_multiMillerLoopFixedQPreparedSparseBlobNoInvMemAggressiveTo`, которые затем переиспользуются в цикле Миллера.
    function _multiMillerLoopFixedQPreparedSparseBlobNoInvMemAggressiveTo(
        uint256 pFBase,
        G1Affine[] memory points,
        bytes memory dblSparse,
        bytes memory addSparse
    ) private pure {
        require(points.length > 0, "no points");
        require(dblSparse.length == FIXED_DBL_SPARSE_BYTES, "bad dbl sparse");
        require(addSparse.length == FIXED_ADD_SPARSE_BYTES, "bad add sparse");
        bytes memory loop = ATE_LOOP_ENC;

        (uint256 pQxOverTwist, uint256 pQyOverTwist, uint256 pQyOverTwistNeg) = _fixedQOverTwistPtrs();
        _setFq4OnePtr(pFBase);

        uint256 n = points.length;
        uint256 pPoints = _allocWords(12 * n); // per point: px(3), py(3), l1Coeff(6)
        for (uint256 i = 0; i < n; ++i) {
            uint256 pPoint = pPoints + i * 12 * WORD;
            uint256 x0 = points[i].x[0];
            uint256 x1 = points[i].x[1];
            uint256 x2 = points[i].x[2];
            uint256 y0 = points[i].y[0];
            uint256 y1 = points[i].y[1];
            uint256 y2 = points[i].y[2];
            assembly ("memory-safe") {
                mstore(pPoint, x0)
                mstore(add(pPoint, 0x20), x1)
                mstore(add(pPoint, 0x40), x2)
                mstore(add(pPoint, 0x60), y0)
                mstore(add(pPoint, 0x80), y1)
                mstore(add(pPoint, 0xa0), y2)
            }
            _buildL1CoeffFromPxPtrTo(pPoint + 6 * WORD, pPoint, pQxOverTwist);
        }

        uint256 arena = _allocWords(180);
        _zeroWords(arena, 180);
        uint256 pTmp = arena;
        uint256 pD0 = pTmp + 12 * WORD;
        uint256 pD1 = pD0 + 6 * WORD;
        uint256 pD2 = pD1 + 6 * WORD;
        uint256 pA0 = pD2 + 6 * WORD;
        uint256 pA1 = pA0 + 6 * WORD;
        uint256 pEll0 = pA1 + 6 * WORD;
        uint256 pEll1 = pEll0 + 6 * WORD;
        uint256 pEvalTmp = pEll1 + 6 * WORD;
        uint256 pScratchSqr = pEvalTmp + 6 * WORD;
        uint256 pScratchFused = pScratchSqr + 54 * WORD;

        uint256 pF = pFBase;
        uint256 dOff;
        uint256 aOff;
        for (uint256 i = 1; i < loop.length; ++i) {
            dOff = _loadSparseDblStepMemoryToPtr(pD0, dblSparse, dOff);

            for (uint256 j = 0; j < n; ++j) {
                uint256 pPoint = pPoints + j * 12 * WORD;
                uint256 pPx = pPoint;
                uint256 pPy = pPoint + 3 * WORD;
                uint256 tmpSwap = pF;
                if (j == 0) {
                    _lineDoubleSparseSqrMulPtrTo(
                        pTmp, pF, pEll0, pEll1, pEvalTmp, pD0, pD1, pD2, pPx, pPy, pScratchSqr, pScratchFused
                    );
                } else {
                    _lineDoubleSparseMulPtrTo(
                        pTmp, pF, pEll0, pEll1, pEvalTmp, pD0, pD1, pD2, pPx, pPy, pScratchSqr, pScratchFused
                    );
                }
                pF = pTmp;
                pTmp = tmpSwap;
            }

            int8 bit = _decodeLoopMem(loop, i);
            if (bit == 0) continue;

            aOff = _loadSparseAddStepMemoryToPtr(pA0, addSparse, aOff);
            uint256 pYOT = bit == 1 ? pQyOverTwist : pQyOverTwistNeg;

            for (uint256 j = 0; j < n; ++j) {
                uint256 pPoint = pPoints + j * 12 * WORD;
                uint256 pPy = pPoint + 3 * WORD;
                uint256 pL1Coeff = pPoint + 6 * WORD;

                uint256 tmpSwap = pF;
                _lineAddSparseMulPtrTo(
                    pTmp, pF, pEll0, pEll1, pEvalTmp, pA0, pA1, pL1Coeff, pYOT, pPy, pScratchSqr,
                    pScratchFused
                );
                pF = pTmp;
                pTmp = tmpSwap;
            }
        }

        if (ATE_IS_LOOP_COUNT_NEG) {
            aOff = _loadSparseAddStepMemoryToPtr(pA0, addSparse, aOff);

            for (uint256 j = 0; j < n; ++j) {
                uint256 pPoint = pPoints + j * 12 * WORD;
                uint256 pPy = pPoint + 3 * WORD;
                uint256 pL1Coeff = pPoint + 6 * WORD;

                uint256 tmpSwap = pF;
                _lineAddSparseMulPtrTo(
                    pTmp, pF, pEll0, pEll1, pEvalTmp, pA0, pA1, pL1Coeff, pQyOverTwist, pPy, pScratchSqr,
                    pScratchFused
                );
                pF = pTmp;
                pTmp = tmpSwap;
            }
        }

        if (pF != pFBase) {
            _copyFq4Ptr(pFBase, pF);
        }
    }

    /// @notice Формирует подготовленные данные `millerLoopFixedQPreparedSparseBlobNoInvMemDigestAggressive`, которые затем переиспользуются в цикле Миллера.
    function millerLoopFixedQPreparedSparseBlobNoInvMemDigestAggressive(
        G1Affine memory p,
        bytes memory dblSparse,
        bytes memory addSparse
    ) internal pure returns (bytes32 digest) {
        uint256 pM = _allocWords(12);
        _millerLoopFixedQPreparedSparseBlobNoInvMemAggressiveTo(pM, p, dblSparse, addSparse);
        _normalizeFq4PtrStrong(pM);
        assembly ("memory-safe") { digest := keccak256(pM, 0x180) }
    }

    /// @notice Формирует подготовленные данные `multiMillerLoopFixedQPreparedSparseBlobNoInvMemDigestAggressive`, которые затем переиспользуются в цикле Миллера.
    function multiMillerLoopFixedQPreparedSparseBlobNoInvMemDigestAggressive(
        G1Affine[] memory points,
        bytes memory dblSparse,
        bytes memory addSparse
    ) internal pure returns (bytes32 digest) {
        uint256 pM = _allocWords(12);
        _multiMillerLoopFixedQPreparedSparseBlobNoInvMemAggressiveTo(pM, points, dblSparse, addSparse);
        _normalizeFq4PtrStrong(pM);
        assembly ("memory-safe") { digest := keccak256(pM, 0x180) }
    }

    /// @notice Формирует подготовленные данные `tatePairingFixedQPreparedSparseMemDigestAggressive`, которые затем переиспользуются в цикле Миллера.
    function tatePairingFixedQPreparedSparseMemDigestAggressive(
        G1Affine memory p,
        bytes memory dblSparse,
        bytes memory addSparse
    ) internal pure returns (bytes32 digest) {
        uint256 pM = _allocWords(12);
        _millerLoopFixedQPreparedSparseBlobNoInvMemAggressiveTo(pM, p, dblSparse, addSparse);
        uint256 pOut = _allocWords(12);
        _finalExponentiationFromMillerPtrTo(pOut, pM, ATE_IS_LOOP_COUNT_NEG);
        _normalizeFq4PtrStrong(pOut);
        assembly ("memory-safe") { digest := keccak256(pOut, 0x180) }
    }

    /// @notice Формирует подготовленные данные `_millerLoopFixedQPreparedSparseCodeShardsNoInvMemTo`, которые затем переиспользуются в цикле Миллера.
    function _millerLoopFixedQPreparedSparseCodeShardsNoInvMemTo(
        uint256 pFBase,
        G1Affine memory p,
        address[] memory dblShards,
        address[] memory addShards
    ) private view {
        G1Affine[] memory one = new G1Affine[](1);
        one[0] = p;
        _multiMillerLoopFixedQPreparedSparseCodeShardsNoInvMemTo(pFBase, one, dblShards, addShards);
    }

    /// @notice Формирует подготовленные данные `_multiMillerLoopFixedQPreparedSparseCodeShardsNoInvMemTo`, которые затем переиспользуются в цикле Миллера.
    function _multiMillerLoopFixedQPreparedSparseCodeShardsNoInvMemTo(
        uint256 pFBase,
        G1Affine[] memory points,
        address[] memory dblShards,
        address[] memory addShards
    ) private view {
        require(points.length > 0, "no points");
        bytes memory loop = ATE_LOOP_ENC;
        (uint256 pQxOverTwist, uint256 pQyOverTwist, uint256 pQyOverTwistNeg) = _fixedQOverTwistPtrs();
        _setFq4OnePtr(pFBase);

        uint256 n = points.length;
        uint256 pPoints = _allocWords(12 * n); // per point: px(3), py(3), l1Coeff(6)
        for (uint256 i = 0; i < n; ++i) {
            uint256 pPoint = pPoints + i * 12 * WORD;
            uint256 x0 = points[i].x[0];
            uint256 x1 = points[i].x[1];
            uint256 x2 = points[i].x[2];
            uint256 y0 = points[i].y[0];
            uint256 y1 = points[i].y[1];
            uint256 y2 = points[i].y[2];
            assembly ("memory-safe") {
                mstore(pPoint, x0)
                mstore(add(pPoint, 0x20), x1)
                mstore(add(pPoint, 0x40), x2)
                mstore(add(pPoint, 0x60), y0)
                mstore(add(pPoint, 0x80), y1)
                mstore(add(pPoint, 0xa0), y2)
            }
            _buildL1CoeffFromPxPtrTo(pPoint + 6 * WORD, pPoint, pQxOverTwist);
        }

        uint256 arena = _allocWords(168);
        _zeroWords(arena, 168);
        uint256 pTmp = arena;
        uint256 pD0 = pTmp + 12 * WORD;
        uint256 pD1 = pD0 + 6 * WORD;
        uint256 pD2 = pD1 + 6 * WORD;
        uint256 pA0 = pD2 + 6 * WORD;
        uint256 pA1 = pA0 + 6 * WORD;
        uint256 pEll0 = pA1 + 6 * WORD;
        uint256 pEll1 = pEll0 + 6 * WORD;
        uint256 pEvalTmp = pEll1 + 6 * WORD;
        uint256 pScratchSqr = pEvalTmp + 6 * WORD;
        uint256 pScratchMulByLine = pScratchSqr + 54 * WORD;

        (uint256 dShardIdx, uint256 dOff, uint256 dShardSize) = _initCodeShardStream(dblShards, FIXED_DBL_SPARSE_BYTES);
        (uint256 aShardIdx, uint256 aOff, uint256 aShardSize) = _initCodeShardStream(addShards, FIXED_ADD_SPARSE_BYTES);

        uint256 pF = pFBase;
        for (uint256 i = 1; i < loop.length; ++i) {
            MNT4Extension.fq4SqrTo(pTmp, pF, pScratchSqr);
            uint256 tmpSwap = pF;
            pF = pTmp;
            pTmp = tmpSwap;

            (dShardIdx, dOff, dShardSize) = _streamLoadSparseDblStepCodeShardsToPtr(
                pD0, dblShards, dShardIdx, dOff, dShardSize
            );

            for (uint256 j = 0; j < n; ++j) {
                uint256 pPoint = pPoints + j * 12 * WORD;
                uint256 pPx = pPoint;
                uint256 pPy = pPoint + 3 * WORD;

                _lineDoubleSparseMulPtrTo(
                    pTmp, pF, pEll0, pEll1, pEvalTmp, pD0, pD1, pD2, pPx, pPy, pScratchSqr, pScratchMulByLine
                );
                tmpSwap = pF;
                pF = pTmp;
                pTmp = tmpSwap;
            }

            int8 bit = _decodeLoopMem(loop, i);
            if (bit == 0) continue;

            (aShardIdx, aOff, aShardSize) = _streamLoadSparseAddStepCodeShardsToPtr(
                pA0, addShards, aShardIdx, aOff, aShardSize
            );
            uint256 pYOT = bit == 1 ? pQyOverTwist : pQyOverTwistNeg;

            for (uint256 j = 0; j < n; ++j) {
                uint256 pPoint = pPoints + j * 12 * WORD;
                uint256 pPy = pPoint + 3 * WORD;
                uint256 pL1Coeff = pPoint + 6 * WORD;

                _lineAddSparseMulPtrTo(
                    pTmp, pF, pEll0, pEll1, pEvalTmp, pA0, pA1, pL1Coeff, pYOT, pPy, pScratchSqr,
                    pScratchMulByLine
                );
                tmpSwap = pF;
                pF = pTmp;
                pTmp = tmpSwap;
            }
        }

        if (ATE_IS_LOOP_COUNT_NEG) {
            (aShardIdx, aOff, aShardSize) = _streamLoadSparseAddStepCodeShardsToPtr(
                pA0, addShards, aShardIdx, aOff, aShardSize
            );

            for (uint256 j = 0; j < n; ++j) {
                uint256 pPoint = pPoints + j * 12 * WORD;
                uint256 pPy = pPoint + 3 * WORD;
                uint256 pL1Coeff = pPoint + 6 * WORD;

                uint256 tmpSwap = pF;
                _lineAddSparseMulPtrTo(
                    pTmp, pF, pEll0, pEll1, pEvalTmp, pA0, pA1, pL1Coeff, pQyOverTwist, pPy, pScratchSqr,
                    pScratchMulByLine
                );
                pF = pTmp;
                pTmp = tmpSwap;
            }
        }

        require(dShardIdx == dblShards.length && dOff == 0 && dShardSize == 0, "bad dbl stream end");
        require(aShardIdx == addShards.length && aOff == 0 && aShardSize == 0, "bad add stream end");

        if (pF != pFBase) {
            _copyFq4Ptr(pFBase, pF);
        }
    }

    /// @notice Формирует подготовленные данные `millerLoopFixedQPreparedSparseCodeShardsNoInvMem`, которые затем переиспользуются в цикле Миллера.
    function millerLoopFixedQPreparedSparseCodeShardsNoInvMem(
        G1Affine memory p,
        address[] memory dblShards,
        address[] memory addShards
    ) internal view returns (MNT4ExtensionFinal.Fq4 memory f) {
        f = _allocFq4();
        _millerLoopFixedQPreparedSparseCodeShardsNoInvMemTo(_ptrFq4(f), p, dblShards, addShards);
    }

    /// @notice Формирует подготовленные данные `millerLoopFixedQPreparedSparseCodeShardsNoInvMemDigest`, которые затем переиспользуются в цикле Миллера.
    function millerLoopFixedQPreparedSparseCodeShardsNoInvMemDigest(
        G1Affine memory p,
        address[] memory dblShards,
        address[] memory addShards
    ) internal view returns (bytes32 digest) {
        uint256 pM = _allocWords(12);
        _millerLoopFixedQPreparedSparseCodeShardsNoInvMemTo(pM, p, dblShards, addShards);
        _normalizeFq4PtrStrong(pM);
        assembly ("memory-safe") { digest := keccak256(pM, 0x180) }
    }

    /// @notice Формирует подготовленные данные `multiMillerLoopFixedQPreparedSparseCodeShardsNoInvMem`, которые затем переиспользуются в цикле Миллера.
    function multiMillerLoopFixedQPreparedSparseCodeShardsNoInvMem(
        G1Affine[] memory points,
        address[] memory dblShards,
        address[] memory addShards
    ) internal view returns (MNT4ExtensionFinal.Fq4 memory f) {
        f = _allocFq4();
        _multiMillerLoopFixedQPreparedSparseCodeShardsNoInvMemTo(_ptrFq4(f), points, dblShards, addShards);
    }

    /// @notice Формирует подготовленные данные `multiMillerLoopFixedQPreparedSparseCodeShardsNoInvMemDigest`, которые затем переиспользуются в цикле Миллера.
    function multiMillerLoopFixedQPreparedSparseCodeShardsNoInvMemDigest(
        G1Affine[] memory points,
        address[] memory dblShards,
        address[] memory addShards
    ) internal view returns (bytes32 digest) {
        uint256 pM = _allocWords(12);
        _multiMillerLoopFixedQPreparedSparseCodeShardsNoInvMemTo(pM, points, dblShards, addShards);
        _normalizeFq4PtrStrong(pM);
        assembly ("memory-safe") { digest := keccak256(pM, 0x180) }
    }

    /// @notice Формирует подготовленные данные `millerSinglesProductFixedQPreparedSparseBlobNoInvMem`, которые затем переиспользуются в цикле Миллера.
    function millerSinglesProductFixedQPreparedSparseBlobNoInvMem(
        G1Affine[] memory points,
        bytes memory dblSparse,
        bytes memory addSparse
    ) internal pure returns (MNT4ExtensionFinal.Fq4 memory out) {
        // Совместимый псевдоним: после общего цикла R2 результат равен произведению отдельных значений,
        // но использует один аккумулятор Миллера и одно возведение в квадрат на раунд.
        return multiMillerLoopFixedQPreparedSparseBlobNoInvMem(points, dblSparse, addSparse);
    }

    /// @notice Формирует подготовленные данные `millerSinglesProductFixedQPreparedSparseBlobNoInvMemDigest`, которые затем переиспользуются в цикле Миллера.
    function millerSinglesProductFixedQPreparedSparseBlobNoInvMemDigest(
        G1Affine[] memory points,
        bytes memory dblSparse,
        bytes memory addSparse
    ) internal pure returns (bytes32 digest) {
        MNT4ExtensionFinal.Fq4 memory out = millerSinglesProductFixedQPreparedSparseBlobNoInvMem(points, dblSparse, addSparse);
        uint256 pOut = _ptrFq4(out);
        _normalizeFq4PtrStrong(pOut);
        assembly ("memory-safe") { digest := keccak256(pOut, 0x180) }
    }

    /// @notice Выполняет этап цикла Миллера `_millerLoopFixedQOnchainNoInvMemTo`; результат является элементом поля расширения до финальной экспоненты.
    function _millerLoopFixedQOnchainNoInvMemTo(
        uint256 pFBase,
        G1Affine memory p
    ) private pure {
        G1Affine[] memory one = new G1Affine[](1);
        one[0] = p;
        _multiMillerLoopFixedQOnchainNoInvMemTo(pFBase, one);
    }

    /// @notice Выполняет этап цикла Миллера `millerLoopFixedQOnchainNoInvMem`; результат является элементом поля расширения до финальной экспоненты.
    function millerLoopFixedQOnchainNoInvMem(
        G1Affine memory p
    ) internal pure returns (MNT4ExtensionFinal.Fq4 memory f) {
        f = _allocFq4();
        _millerLoopFixedQOnchainNoInvMemTo(_ptrFq4(f), p);
    }

    /// @notice Выполняет этап цикла Миллера `millerLoopFixedQOnchainNoInvMemDigest`; результат является элементом поля расширения до финальной экспоненты.
    function millerLoopFixedQOnchainNoInvMemDigest(
        G1Affine memory p
    ) internal pure returns (bytes32 digest) {
        uint256 pM = _allocWords(12);
        _millerLoopFixedQOnchainNoInvMemTo(pM, p);
        _normalizeFq4PtrStrong(pM);
        assembly ("memory-safe") { digest := keccak256(pM, 0x180) }
    }

    /// @notice Выполняет этап цикла Миллера `_multiMillerLoopOnchainNoInvMemTo`; результат является элементом поля расширения до финальной экспоненты.
    function _multiMillerLoopOnchainNoInvMemTo(
        uint256 pFBase,
        G1Affine[] memory points,
        G2Affine memory q,
        uint256 pQxOverTwist,
        uint256 pQyOverTwist,
        uint256 pQyOverTwistNeg
    ) private pure {
        require(points.length > 0, "no points");
        bytes memory loop = ATE_LOOP_ENC;

        MNT4ExtensionFinal.Fq2 memory qNegY = _fq2Neg(q.y);

        _setFq4OnePtr(pFBase);

        uint256 n = points.length;
        uint256 pPoints = _allocWords(12 * n); // per point: px(3), py(3), l1Coeff(6)
        for (uint256 i = 0; i < n; ++i) {
            uint256 pPoint = pPoints + i * 12 * WORD;
            uint256 x0 = points[i].x[0];
            uint256 x1 = points[i].x[1];
            uint256 x2 = points[i].x[2];
            uint256 y0 = points[i].y[0];
            uint256 y1 = points[i].y[1];
            uint256 y2 = points[i].y[2];
            assembly ("memory-safe") {
                mstore(pPoint, x0)
                mstore(add(pPoint, 0x20), x1)
                mstore(add(pPoint, 0x40), x2)
                mstore(add(pPoint, 0x60), y0)
                mstore(add(pPoint, 0x80), y1)
                mstore(add(pPoint, 0xa0), y2)
            }
            _buildL1CoeffFromPxPtrTo(pPoint + 6 * WORD, pPoint, pQxOverTwist);
        }

        uint256 arena = _allocWords(168);
        _zeroWords(arena, 168);
        uint256 pTmp = arena;
        uint256 pD0 = pTmp + 12 * WORD;
        uint256 pD1 = pD0 + 6 * WORD;
        uint256 pD2 = pD1 + 6 * WORD;
        uint256 pA0 = pD2 + 6 * WORD;
        uint256 pA1 = pA0 + 6 * WORD;
        uint256 pEll0 = pA1 + 6 * WORD;
        uint256 pEll1 = pEll0 + 6 * WORD;
        uint256 pEvalTmp = pEll1 + 6 * WORD;
        uint256 pScratchSqr = pEvalTmp + 6 * WORD;
        uint256 pScratchMulByLine = pScratchSqr + 54 * WORD;

        G2ProjectiveExtended memory r;
        r.x = q.x;
        r.y = q.y;
        r.z = _fq2One();
        r.t = _fq2One();

        uint256 pF = pFBase;
        for (uint256 i = 1; i < loop.length; ++i) {
            MNT4Extension.fq4SqrTo(pTmp, pF, pScratchSqr);
            uint256 tmpSwap = pF;
            pF = pTmp;
            pTmp = tmpSwap;

            (G2ProjectiveExtended memory r2, AteDoubleCoefficients memory dc) = _doublingStep(r);
            r = r2;

            _storeFq2SubToPtr(pD0, dc.c_l, dc.c_4c);
            _storeFq2LimbsToPtr(
                pD1,
                dc.c_j.c0[0], dc.c_j.c0[1], dc.c_j.c0[2],
                dc.c_j.c1[0], dc.c_j.c1[1], dc.c_j.c1[2]
            );
            _storeFq2LimbsToPtr(
                pD2,
                dc.c_h.c0[0], dc.c_h.c0[1], dc.c_h.c0[2],
                dc.c_h.c1[0], dc.c_h.c1[1], dc.c_h.c1[2]
            );

            for (uint256 j = 0; j < n; ++j) {
                uint256 pPoint = pPoints + j * 12 * WORD;
                uint256 pPx = pPoint;
                uint256 pPy = pPoint + 3 * WORD;

                _lineDoubleSparseMulPtrTo(
                    pTmp, pF, pEll0, pEll1, pEvalTmp, pD0, pD1, pD2, pPx, pPy, pScratchSqr, pScratchMulByLine
                );
                tmpSwap = pF;
                pF = pTmp;
                pTmp = tmpSwap;
            }

            int8 bit = _decodeLoopMem(loop, i);
            if (bit == 0) continue;

            (G2ProjectiveExtended memory r3, AteAdditionCoefficients memory ac) = bit == 1
                ? _mixedAdditionStep(q.x, q.y, r)
                : _mixedAdditionStep(q.x, qNegY, r);
            r = r3;

            _storeFq2LimbsToPtr(
                pA0,
                ac.c_rz.c0[0], ac.c_rz.c0[1], ac.c_rz.c0[2],
                ac.c_rz.c1[0], ac.c_rz.c1[1], ac.c_rz.c1[2]
            );
            _storeFq2LimbsToPtr(
                pA1,
                ac.c_l1.c0[0], ac.c_l1.c0[1], ac.c_l1.c0[2],
                ac.c_l1.c1[0], ac.c_l1.c1[1], ac.c_l1.c1[2]
            );
            uint256 pYOT = bit == 1 ? pQyOverTwist : pQyOverTwistNeg;

            for (uint256 j = 0; j < n; ++j) {
                uint256 pPoint = pPoints + j * 12 * WORD;
                uint256 pPy = pPoint + 3 * WORD;
                uint256 pL1Coeff = pPoint + 6 * WORD;

                _lineAddSparseMulPtrTo(
                    pTmp, pF, pEll0, pEll1, pEvalTmp, pA0, pA1, pL1Coeff, pYOT, pPy, pScratchSqr,
                    pScratchMulByLine
                );
                tmpSwap = pF;
                pF = pTmp;
                pTmp = tmpSwap;
            }
        }

        if (ATE_IS_LOOP_COUNT_NEG) {
            MNT4ExtensionFinal.Fq2 memory rzInv = MNT4ExtensionFinal.fq2Inv(r.z);
            MNT4ExtensionFinal.Fq2 memory rz2Inv = MNT4ExtensionFinal.fq2Sqr(rzInv);
            MNT4ExtensionFinal.Fq2 memory rz3Inv = MNT4ExtensionFinal.fq2Mul(rzInv, rz2Inv);
            MNT4ExtensionFinal.Fq2 memory minusRAffineX = MNT4ExtensionFinal.fq2Mul(r.x, rz2Inv);
            MNT4ExtensionFinal.Fq2 memory minusRAffineY = _fq2Neg(MNT4ExtensionFinal.fq2Mul(r.y, rz3Inv));

            (, AteAdditionCoefficients memory acNeg) = _mixedAdditionStep(minusRAffineX, minusRAffineY, r);
            _storeFq2LimbsToPtr(
                pA0,
                acNeg.c_rz.c0[0], acNeg.c_rz.c0[1], acNeg.c_rz.c0[2],
                acNeg.c_rz.c1[0], acNeg.c_rz.c1[1], acNeg.c_rz.c1[2]
            );
            _storeFq2LimbsToPtr(
                pA1,
                acNeg.c_l1.c0[0], acNeg.c_l1.c0[1], acNeg.c_l1.c0[2],
                acNeg.c_l1.c1[0], acNeg.c_l1.c1[1], acNeg.c_l1.c1[2]
            );

            for (uint256 j = 0; j < n; ++j) {
                uint256 pPoint = pPoints + j * 12 * WORD;
                uint256 pPy = pPoint + 3 * WORD;
                uint256 pL1Coeff = pPoint + 6 * WORD;

                uint256 tmpSwap = pF;
                _lineAddSparseMulPtrTo(
                    pTmp, pF, pEll0, pEll1, pEvalTmp, pA0, pA1, pL1Coeff, pQyOverTwist, pPy, pScratchSqr,
                    pScratchMulByLine
                );
                pF = pTmp;
                pTmp = tmpSwap;
            }
        }

        if (pF != pFBase) {
            _copyFq4Ptr(pFBase, pF);
        }
    }

    /// @notice Выполняет этап цикла Миллера `_multiMillerLoopFixedQOnchainNoInvMemTo`; результат является элементом поля расширения до финальной экспоненты.
    function _multiMillerLoopFixedQOnchainNoInvMemTo(
        uint256 pFBase,
        G1Affine[] memory points
    ) private pure {
        G2Affine memory q = _fixedQGenerator();
        (uint256 pQxOverTwist, uint256 pQyOverTwist, uint256 pQyOverTwistNeg) = _fixedQOverTwistPtrs();
        _multiMillerLoopOnchainNoInvMemTo(pFBase, points, q, pQxOverTwist, pQyOverTwist, pQyOverTwistNeg);
    }

    /// @notice Выполняет этап цикла Миллера `_multiMillerLoopParametricQOnchainNoInvMemTo`; результат является элементом поля расширения до финальной экспоненты.
    function _multiMillerLoopParametricQOnchainNoInvMemTo(
        uint256 pFBase,
        G1Affine[] memory points,
        G2Affine memory q
    ) private pure {
        (uint256 pQxOverTwist, uint256 pQyOverTwist, uint256 pQyOverTwistNeg) = _qOverTwistPtrsFromQ(q);
        _multiMillerLoopOnchainNoInvMemTo(pFBase, points, q, pQxOverTwist, pQyOverTwist, pQyOverTwistNeg);
    }

    /// @notice Выполняет этап цикла Миллера `multiMillerLoopFixedQOnchainNoInvMem`; результат является элементом поля расширения до финальной экспоненты.
    function multiMillerLoopFixedQOnchainNoInvMem(
        G1Affine[] memory points
    ) internal pure returns (MNT4ExtensionFinal.Fq4 memory f) {
        f = _allocFq4();
        _multiMillerLoopFixedQOnchainNoInvMemTo(_ptrFq4(f), points);
    }

    /// @notice Выполняет этап цикла Миллера `multiMillerLoopFixedQOnchainNoInvMemDigest`; результат является элементом поля расширения до финальной экспоненты.
    function multiMillerLoopFixedQOnchainNoInvMemDigest(
        G1Affine[] memory points
    ) internal pure returns (bytes32 digest) {
        uint256 pM = _allocWords(12);
        _multiMillerLoopFixedQOnchainNoInvMemTo(pM, points);
        _normalizeFq4PtrStrong(pM);
        assembly ("memory-safe") { digest := keccak256(pM, 0x180) }
    }

    /// @notice Выполняет этап цикла Миллера `multiMillerLoopParametricQOnchainNoInvMem`; результат является элементом поля расширения до финальной экспоненты.
    function multiMillerLoopParametricQOnchainNoInvMem(
        G1Affine[] memory points,
        G2Affine memory q
    ) internal pure returns (MNT4ExtensionFinal.Fq4 memory f) {
        f = _allocFq4();
        _multiMillerLoopParametricQOnchainNoInvMemTo(_ptrFq4(f), points, q);
    }

    /// @notice Выполняет этап цикла Миллера `multiMillerLoopParametricQOnchainNoInvMemDigest`; результат является элементом поля расширения до финальной экспоненты.
    function multiMillerLoopParametricQOnchainNoInvMemDigest(
        G1Affine[] memory points,
        G2Affine memory q
    ) internal pure returns (bytes32 digest) {
        uint256 pM = _allocWords(12);
        _multiMillerLoopParametricQOnchainNoInvMemTo(pM, points, q);
        _normalizeFq4PtrStrong(pM);
        assembly ("memory-safe") { digest := keccak256(pM, 0x180) }
    }

    /// @notice Выполняет этап цикла Миллера `millerSinglesProductFixedQOnchainNoInvMemDigest`; результат является элементом поля расширения до финальной экспоненты.
    function millerSinglesProductFixedQOnchainNoInvMemDigest(
        G1Affine[] memory points
    ) internal pure returns (bytes32 digest) {
        // Совместимое имя для ветки R2 с общим циклом.
        return multiMillerLoopFixedQOnchainNoInvMemDigest(points);
    }

    /// @notice Выполняет этап цикла Миллера `millerSinglesProductParametricQOnchainNoInvMemDigest`; результат является элементом поля расширения до финальной экспоненты.
    function millerSinglesProductParametricQOnchainNoInvMemDigest(
        G1Affine[] memory points,
        G2Affine memory q
    ) internal pure returns (bytes32 digest) {
        return multiMillerLoopParametricQOnchainNoInvMemDigest(points, q);
    }

    /// @notice Формирует подготовленные данные `debugOnchainVsPreparedSingleFirstMismatchMem`, которые затем переиспользуются в цикле Миллера.
    function debugOnchainVsPreparedSingleFirstMismatchMem(
        G1Affine memory p,
        bytes memory dblSparse,
        bytes memory addSparse
    ) internal pure returns (
        uint256 stage,
        uint256 round,
        bytes32 onchainDigest,
        bytes32 preparedDigest
    ) {
        require(dblSparse.length == FIXED_DBL_SPARSE_BYTES, "bad dbl sparse");
        require(addSparse.length == FIXED_ADD_SPARSE_BYTES, "bad add sparse");
        bytes memory loop = ATE_LOOP_ENC;

        (uint256 pQxOverTwist, uint256 pQyOverTwist, uint256 pQyOverTwistNeg) = _fixedQOverTwistPtrs();
        uint256 pPx = _ptrFp3(p.x);
        uint256 pPy = _ptrFp3(p.y);
        uint256 pL1Coeff = _allocWords(6);
        _buildL1CoeffFromPxPtrTo(pL1Coeff, pPx, pQxOverTwist);

        uint256 pPBase = _allocWords(12);
        _setFq4OnePtr(pPBase);
        uint256 arenaP = _allocWords(174);
        uint256 pPTmp = arenaP;
        uint256 pPD0 = pPTmp + 12 * WORD;
        uint256 pPD1 = pPD0 + 6 * WORD;
        uint256 pPD2 = pPD1 + 6 * WORD;
        uint256 pPA0 = pPD2 + 6 * WORD;
        uint256 pPA1 = pPA0 + 6 * WORD;
        uint256 pPEll0 = pPA1 + 6 * WORD;
        uint256 pPEll1 = pPEll0 + 6 * WORD;
        uint256 pPT0 = pPEll1 + 6 * WORD;
        uint256 pPT1 = pPT0 + 6 * WORD;
        uint256 pPScratchSqr = pPT1 + 6 * WORD;
        uint256 pPScratchMulByLine = pPScratchSqr + 54 * WORD;
        uint256 pPF = pPBase;
        uint256 dOff;
        uint256 aOff;

        uint256 pOBase = _allocWords(12);
        _setFq4OnePtr(pOBase);
        uint256 arenaO = _allocWords(174);
        uint256 pOTmp = arenaO;
        uint256 pOD0 = pOTmp + 12 * WORD;
        uint256 pOD1 = pOD0 + 6 * WORD;
        uint256 pOD2 = pOD1 + 6 * WORD;
        uint256 pOA0 = pOD2 + 6 * WORD;
        uint256 pOA1 = pOA0 + 6 * WORD;
        uint256 pOEll0 = pOA1 + 6 * WORD;
        uint256 pOEll1 = pOEll0 + 6 * WORD;
        uint256 pOT0 = pOEll1 + 6 * WORD;
        uint256 pOT1 = pOT0 + 6 * WORD;
        uint256 pOScratchSqr = pOT1 + 6 * WORD;
        uint256 pOScratchMulByLine = pOScratchSqr + 54 * WORD;
        uint256 pOF = pOBase;

        G2Affine memory q = _fixedQGenerator();
        MNT4ExtensionFinal.Fq2 memory qNegY = _fq2Neg(q.y);
        G2ProjectiveExtended memory r;
        r.x = q.x;
        r.y = q.y;
        r.z = _fq2One();
        r.t = _fq2One();

        for (uint256 i = 1; i < loop.length; ++i) {
            round = i;

            MNT4Extension.fq4SqrTo(pPTmp, pPF, pPScratchSqr);
            uint256 pSwap = pPF; pPF = pPTmp; pPTmp = pSwap;
            MNT4Extension.fq4SqrTo(pOTmp, pOF, pOScratchSqr);
            pSwap = pOF; pOF = pOTmp; pOTmp = pSwap;

            _loadFq2BytesMemoryToPtr(pPD0, dblSparse, dOff); dOff += FQ2_BYTES;
            _loadFq2BytesMemoryToPtr(pPD1, dblSparse, dOff); dOff += FQ2_BYTES;
            _loadFq2BytesMemoryToPtr(pPD2, dblSparse, dOff); dOff += FQ2_BYTES;

            (G2ProjectiveExtended memory r2, AteDoubleCoefficients memory dc) = _doublingStep(r);
            r = r2;
            _storeFq2SubToPtr(pOD0, dc.c_l, dc.c_4c);
            _storeFq2LimbsToPtr(
                pOD1,
                dc.c_j.c0[0], dc.c_j.c0[1], dc.c_j.c0[2],
                dc.c_j.c1[0], dc.c_j.c1[1], dc.c_j.c1[2]
            );
            _storeFq2LimbsToPtr(
                pOD2,
                dc.c_h.c0[0], dc.c_h.c0[1], dc.c_h.c0[2],
                dc.c_h.c1[0], dc.c_h.c1[1], dc.c_h.c1[2]
            );

            {
                bytes32 pd0;
                bytes32 od0;
                bytes32 pd1;
                bytes32 od1;
                bytes32 pd2;
                bytes32 od2;
                assembly ("memory-safe") {
                    pd0 := keccak256(pPD0, 0xc0)
                    od0 := keccak256(pOD0, 0xc0)
                    pd1 := keccak256(pPD1, 0xc0)
                    od1 := keccak256(pOD1, 0xc0)
                    pd2 := keccak256(pPD2, 0xc0)
                    od2 := keccak256(pOD2, 0xc0)
                }
                if (pd0 != od0) {
                    stage = 111;
                    preparedDigest = pd0;
                    onchainDigest = od0;
                    return (stage, round, onchainDigest, preparedDigest);
                }
                if (pd1 != od1) {
                    if (pd1 == od2) {
                        stage = 212;
                    } else if (pd1 == od0) {
                        stage = 210;
                    } else {
                        stage = 112;
                    }
                    preparedDigest = pd1;
                    onchainDigest = od1;
                    return (stage, round, onchainDigest, preparedDigest);
                }
                if (pd2 != od2) {
                    stage = 113;
                    preparedDigest = pd2;
                    onchainDigest = od2;
                    return (stage, round, onchainDigest, preparedDigest);
                }
            }

            _lineDoubleSparsePtrTo(pPEll0, pPEll1, pPT0, pPD0, pPD1, pPD2, pPx, pPy, pPScratchSqr);
            _fq4MulByLinePtrTo(pPTmp, pPF, pPEll0, pPEll1, pPScratchMulByLine);
            pSwap = pPF; pPF = pPTmp; pPTmp = pSwap;

            _lineDoubleSparsePtrTo(pOEll0, pOEll1, pOT0, pOD0, pOD1, pOD2, pPx, pPy, pOScratchSqr);
            _fq4MulByLinePtrTo(pOTmp, pOF, pOEll0, pOEll1, pOScratchMulByLine);
            pSwap = pOF; pOF = pOTmp; pOTmp = pSwap;

            {
                bytes32 pe;
                bytes32 oe;
                assembly ("memory-safe") {
                    pe := keccak256(pPEll0, 0x180)
                    oe := keccak256(pOEll0, 0x180)
                }
                if (pe != oe) {
                    stage = 12;
                    preparedDigest = pe;
                    onchainDigest = oe;
                    return (stage, round, onchainDigest, preparedDigest);
                }
            }

            onchainDigest = _digestNormalizedFq4PtrStrong(pOF);
            preparedDigest = _digestNormalizedFq4PtrStrong(pPF);
            if (onchainDigest != preparedDigest) {
                stage = 1;
                return (stage, round, onchainDigest, preparedDigest);
            }

            int8 bit = _decodeLoopMem(loop, i);
            if (bit == 0) continue;

            _loadFq2BytesMemoryToPtr(pPA0, addSparse, aOff); aOff += FQ2_BYTES;
            _loadFq2BytesMemoryToPtr(pPA1, addSparse, aOff); aOff += FQ2_BYTES;
            uint256 pPYOT = bit == 1 ? pQyOverTwist : pQyOverTwistNeg;

            (G2ProjectiveExtended memory r3, AteAdditionCoefficients memory ac) = bit == 1
                ? _mixedAdditionStep(q.x, q.y, r)
                : _mixedAdditionStep(q.x, qNegY, r);
            r = r3;
            _storeFq2LimbsToPtr(
                pOA0,
                ac.c_rz.c0[0], ac.c_rz.c0[1], ac.c_rz.c0[2],
                ac.c_rz.c1[0], ac.c_rz.c1[1], ac.c_rz.c1[2]
            );
            _storeFq2LimbsToPtr(
                pOA1,
                ac.c_l1.c0[0], ac.c_l1.c0[1], ac.c_l1.c0[2],
                ac.c_l1.c1[0], ac.c_l1.c1[1], ac.c_l1.c1[2]
            );
            uint256 pOYOT = bit == 1 ? pQyOverTwist : pQyOverTwistNeg;

            _lineAddSparsePtrTo(pPEll0, pPEll1, pPT0, pPT1, pPA0, pPA1, pL1Coeff, pPYOT, pPy, pPScratchSqr);
            _fq4MulByLinePtrTo(pPTmp, pPF, pPEll0, pPEll1, pPScratchMulByLine);
            pSwap = pPF; pPF = pPTmp; pPTmp = pSwap;

            _lineAddSparsePtrTo(pOEll0, pOEll1, pOT0, pOT1, pOA0, pOA1, pL1Coeff, pOYOT, pPy, pOScratchSqr);
            _fq4MulByLinePtrTo(pOTmp, pOF, pOEll0, pOEll1, pOScratchMulByLine);
            pSwap = pOF; pOF = pOTmp; pOTmp = pSwap;

            onchainDigest = _digestNormalizedFq4PtrStrong(pOF);
            preparedDigest = _digestNormalizedFq4PtrStrong(pPF);
            if (onchainDigest != preparedDigest) {
                stage = 2;
                return (stage, round, onchainDigest, preparedDigest);
            }
        }

        if (ATE_IS_LOOP_COUNT_NEG) {
            _loadFq2BytesMemoryToPtr(pPA0, addSparse, aOff); aOff += FQ2_BYTES;
            _loadFq2BytesMemoryToPtr(pPA1, addSparse, aOff); aOff += FQ2_BYTES;

            MNT4ExtensionFinal.Fq2 memory rzInv = MNT4ExtensionFinal.fq2Inv(r.z);
            MNT4ExtensionFinal.Fq2 memory rz2Inv = MNT4ExtensionFinal.fq2Sqr(rzInv);
            MNT4ExtensionFinal.Fq2 memory rz3Inv = MNT4ExtensionFinal.fq2Mul(rzInv, rz2Inv);
            MNT4ExtensionFinal.Fq2 memory minusRAffineX = MNT4ExtensionFinal.fq2Mul(r.x, rz2Inv);
            MNT4ExtensionFinal.Fq2 memory minusRAffineY = _fq2Neg(MNT4ExtensionFinal.fq2Mul(r.y, rz3Inv));
            (, AteAdditionCoefficients memory acNeg) = _mixedAdditionStep(minusRAffineX, minusRAffineY, r);
            _storeFq2LimbsToPtr(
                pOA0,
                acNeg.c_rz.c0[0], acNeg.c_rz.c0[1], acNeg.c_rz.c0[2],
                acNeg.c_rz.c1[0], acNeg.c_rz.c1[1], acNeg.c_rz.c1[2]
            );
            _storeFq2LimbsToPtr(
                pOA1,
                acNeg.c_l1.c0[0], acNeg.c_l1.c0[1], acNeg.c_l1.c0[2],
                acNeg.c_l1.c1[0], acNeg.c_l1.c1[1], acNeg.c_l1.c1[2]
            );

            _lineAddSparsePtrTo(pPEll0, pPEll1, pPT0, pPT1, pPA0, pPA1, pL1Coeff, pQyOverTwist, pPy, pPScratchSqr);
            uint256 pSwap = pPF;
            _fq4MulByLinePtrTo(pPTmp, pPF, pPEll0, pPEll1, pPScratchMulByLine);
            pPF = pPTmp;
            pPTmp = pSwap;

            _lineAddSparsePtrTo(pOEll0, pOEll1, pOT0, pOT1, pOA0, pOA1, pL1Coeff, pQyOverTwist, pPy, pOScratchSqr);
            pSwap = pOF;
            _fq4MulByLinePtrTo(pOTmp, pOF, pOEll0, pOEll1, pOScratchMulByLine);
            pOF = pOTmp;
            pOTmp = pSwap;

            onchainDigest = _digestNormalizedFq4PtrStrong(pOF);
            preparedDigest = _digestNormalizedFq4PtrStrong(pPF);
            if (onchainDigest != preparedDigest) {
                stage = 3;
                round = loop.length;
                return (stage, round, onchainDigest, preparedDigest);
            }
        }

        round = loop.length;
        onchainDigest = _digestNormalizedFq4PtrStrong(pOF);
        preparedDigest = _digestNormalizedFq4PtrStrong(pPF);
    }

    /// @notice Формирует подготовленные данные `debugPreparedSparseSingleVsMultiOneFirstMismatchMem`, которые затем переиспользуются в цикле Миллера.
    function debugPreparedSparseSingleVsMultiOneFirstMismatchMem(
        G1Affine memory p,
        bytes memory dblSparse,
        bytes memory addSparse
    ) internal pure returns (
        uint256 stage,
        uint256 round,
        bytes32 singleDigest,
        bytes32 multiDigest
    ) {
        require(dblSparse.length == FIXED_DBL_SPARSE_BYTES, "bad dbl sparse");
        require(addSparse.length == FIXED_ADD_SPARSE_BYTES, "bad add sparse");
        bytes memory loop = ATE_LOOP_ENC;

        (uint256 pQxOverTwist, uint256 pQyOverTwist, uint256 pQyOverTwistNeg) = _fixedQOverTwistPtrs();
        uint256 pPx = _ptrFp3(p.x);
        uint256 pPy = _ptrFp3(p.y);

        uint256 pSBase = _allocWords(12);
        _setFq4OnePtr(pSBase);
        uint256 arenaS = _allocWords(180);
        uint256 pSTmp = arenaS;
        uint256 pSD0 = pSTmp + 12 * WORD;
        uint256 pSD1 = pSD0 + 6 * WORD;
        uint256 pSD2 = pSD1 + 6 * WORD;
        uint256 pSA0 = pSD2 + 6 * WORD;
        uint256 pSA1 = pSA0 + 6 * WORD;
        uint256 pSEll0 = pSA1 + 6 * WORD;
        uint256 pSEll1 = pSEll0 + 6 * WORD;
        uint256 pST0 = pSEll1 + 6 * WORD;
        uint256 pST1 = pST0 + 6 * WORD;
        uint256 pSL1Coeff = pST1 + 6 * WORD;
        uint256 pSScratchSqr = pSL1Coeff + 6 * WORD;
        uint256 pSScratchMulByLine = pSScratchSqr + 54 * WORD;
        _buildL1CoeffFromPxPtrTo(pSL1Coeff, pPx, pQxOverTwist);

        uint256 pPoint = _allocWords(12);
        assembly ("memory-safe") {
            mstore(pPoint, mload(pPx))
            mstore(add(pPoint, 0x20), mload(add(pPx, 0x20)))
            mstore(add(pPoint, 0x40), mload(add(pPx, 0x40)))
            mstore(add(pPoint, 0x60), mload(pPy))
            mstore(add(pPoint, 0x80), mload(add(pPy, 0x20)))
            mstore(add(pPoint, 0xa0), mload(add(pPy, 0x40)))
        }
        _buildL1CoeffFromPxPtrTo(pPoint + 6 * WORD, pPoint, pQxOverTwist);

        uint256 pMBase = _allocWords(12);
        _setFq4OnePtr(pMBase);
        uint256 arenaM = _allocWords(174);
        uint256 pMTmp = arenaM;
        uint256 pMD0 = pMTmp + 12 * WORD;
        uint256 pMD1 = pMD0 + 6 * WORD;
        uint256 pMD2 = pMD1 + 6 * WORD;
        uint256 pMA0 = pMD2 + 6 * WORD;
        uint256 pMA1 = pMA0 + 6 * WORD;
        uint256 pMEll0 = pMA1 + 6 * WORD;
        uint256 pMEll1 = pMEll0 + 6 * WORD;
        uint256 pMT0 = pMEll1 + 6 * WORD;
        uint256 pMT1 = pMT0 + 6 * WORD;
        uint256 pMScratchSqr = pMT1 + 6 * WORD;
        uint256 pMScratchMulByLine = pMScratchSqr + 54 * WORD;

        uint256 pSF = pSBase;
        uint256 pMF = pMBase;
        uint256 dOff;
        uint256 aOff;
        for (uint256 i = 1; i < loop.length; ++i) {
            round = i;

            _loadFq2BytesMemoryToPtr(pSD0, dblSparse, dOff);
            _loadFq2BytesMemoryToPtr(pMD0, dblSparse, dOff);
            dOff += FQ2_BYTES;
            _loadFq2BytesMemoryToPtr(pSD1, dblSparse, dOff);
            _loadFq2BytesMemoryToPtr(pMD1, dblSparse, dOff);
            dOff += FQ2_BYTES;
            _loadFq2BytesMemoryToPtr(pSD2, dblSparse, dOff);
            _loadFq2BytesMemoryToPtr(pMD2, dblSparse, dOff);
            dOff += FQ2_BYTES;

            _lineDoubleSparsePtrTo(pSEll0, pSEll1, pST0, pSD0, pSD1, pSD2, pPx, pPy, pSScratchSqr);
            MNT4Extension.fq4SqrTo(pSTmp, pSF, pSScratchSqr);
            uint256 swapSF = pSF;
            pSF = pSTmp;
            pSTmp = swapSF;

            MNT4Extension.fq4SqrTo(pMTmp, pMF, pMScratchSqr);
            uint256 swapMF = pMF;
            pMF = pMTmp;
            pMTmp = swapMF;

            singleDigest = _digestFq4Ptr(pSF);
            multiDigest = _digestFq4Ptr(pMF);
            if (singleDigest != multiDigest) {
                stage = 1;
                return (stage, round, singleDigest, multiDigest);
            }

            _fq4MulByLinePtrTo(pSTmp, pSF, pSEll0, pSEll1, pSScratchMulByLine);
            swapSF = pSF;
            pSF = pSTmp;
            pSTmp = swapSF;

            _lineDoubleSparsePtrTo(pMEll0, pMEll1, pMT0, pMD0, pMD1, pMD2, pPoint, pPoint + 3 * WORD, pMScratchSqr);
            _fq4MulByLinePtrTo(pMTmp, pMF, pMEll0, pMEll1, pMScratchMulByLine);
            swapMF = pMF;
            pMF = pMTmp;
            pMTmp = swapMF;

            singleDigest = _digestFq4Ptr(pSF);
            multiDigest = _digestFq4Ptr(pMF);
            if (singleDigest != multiDigest) {
                stage = 2;
                return (stage, round, singleDigest, multiDigest);
            }

            int8 bit = _decodeLoopMem(loop, i);
            if (bit != 0) {
                _loadFq2BytesMemoryToPtr(pSA0, addSparse, aOff);
                _loadFq2BytesMemoryToPtr(pMA0, addSparse, aOff);
                aOff += FQ2_BYTES;
                _loadFq2BytesMemoryToPtr(pSA1, addSparse, aOff);
                _loadFq2BytesMemoryToPtr(pMA1, addSparse, aOff);
                aOff += FQ2_BYTES;

                uint256 pYOT = bit == 1 ? pQyOverTwist : pQyOverTwistNeg;
                _lineAddSparsePtrTo(pSEll0, pSEll1, pST0, pST1, pSA0, pSA1, pSL1Coeff, pYOT, pPy, pSScratchSqr);
                _fq4MulByLinePtrTo(pSTmp, pSF, pSEll0, pSEll1, pSScratchMulByLine);
                swapSF = pSF;
                pSF = pSTmp;
                pSTmp = swapSF;

                _lineAddSparsePtrTo(
                    pMEll0,
                    pMEll1,
                    pMT0,
                    pMT1,
                    pMA0,
                    pMA1,
                    pPoint + 6 * WORD,
                    pYOT,
                    pPoint + 3 * WORD,
                    pMScratchSqr
                );
                _fq4MulByLinePtrTo(pMTmp, pMF, pMEll0, pMEll1, pMScratchMulByLine);
                swapMF = pMF;
                pMF = pMTmp;
                pMTmp = swapMF;
            }

            singleDigest = _digestFq4Ptr(pSF);
            multiDigest = _digestFq4Ptr(pMF);
            if (singleDigest != multiDigest) {
                stage = 3;
                return (stage, round, singleDigest, multiDigest);
            }
        }

        if (ATE_IS_LOOP_COUNT_NEG) {
            round = loop.length;
            _loadFq2BytesMemoryToPtr(pSA0, addSparse, aOff);
            _loadFq2BytesMemoryToPtr(pMA0, addSparse, aOff);
            aOff += FQ2_BYTES;
            _loadFq2BytesMemoryToPtr(pSA1, addSparse, aOff);
            _loadFq2BytesMemoryToPtr(pMA1, addSparse, aOff);

            _lineAddSparsePtrTo(pSEll0, pSEll1, pST0, pST1, pSA0, pSA1, pSL1Coeff, pQyOverTwist, pPy, pSScratchSqr);
            uint256 swapSF = pSF;
            _fq4MulByLinePtrTo(pSTmp, pSF, pSEll0, pSEll1, pSScratchMulByLine);
            pSF = pSTmp;
            pSTmp = swapSF;

            _lineAddSparsePtrTo(
                pMEll0,
                pMEll1,
                pMT0,
                pMT1,
                pMA0,
                pMA1,
                pPoint + 6 * WORD,
                pQyOverTwist,
                pPoint + 3 * WORD,
                pMScratchSqr
            );
            uint256 swapMF = pMF;
            _fq4MulByLinePtrTo(pMTmp, pMF, pMEll0, pMEll1, pMScratchMulByLine);
            pMF = pMTmp;
            pMTmp = swapMF;

            singleDigest = _digestFq4Ptr(pSF);
            multiDigest = _digestFq4Ptr(pMF);
            if (singleDigest != multiDigest) {
                stage = 4;
                return (stage, round, singleDigest, multiDigest);
            }
        }
    }

    /// @notice Формирует подготовленные данные `debugPreparedSparseTwoSinglesVsMultiFirstMismatchMem`, которые затем переиспользуются в цикле Миллера.
    function debugPreparedSparseTwoSinglesVsMultiFirstMismatchMem(
        G1Affine[] memory points,
        bytes memory dblSparse,
        bytes memory addSparse
    ) internal pure returns (
        uint256 stage,
        uint256 round,
        bytes32 multiDigest,
        bytes32 singlesDigest
    ) {
        require(points.length == 2, "need 2 points");
        require(dblSparse.length == FIXED_DBL_SPARSE_BYTES, "bad dbl sparse");
        require(addSparse.length == FIXED_ADD_SPARSE_BYTES, "bad add sparse");
        bytes memory loop = ATE_LOOP_ENC;

        (uint256 pQxOverTwist, uint256 pQyOverTwist, uint256 pQyOverTwistNeg) = _fixedQOverTwistPtrs();

        uint256 pPoints = _allocWords(24); // 2 * (px(3), py(3), l1(6))
        for (uint256 i = 0; i < 2; ++i) {
            uint256 pPoint = pPoints + i * 12 * WORD;
            uint256 x0 = points[i].x[0];
            uint256 x1 = points[i].x[1];
            uint256 x2 = points[i].x[2];
            uint256 y0 = points[i].y[0];
            uint256 y1 = points[i].y[1];
            uint256 y2 = points[i].y[2];
            assembly ("memory-safe") {
                mstore(pPoint, x0)
                mstore(add(pPoint, 0x20), x1)
                mstore(add(pPoint, 0x40), x2)
                mstore(add(pPoint, 0x60), y0)
                mstore(add(pPoint, 0x80), y1)
                mstore(add(pPoint, 0xa0), y2)
            }
            _buildL1CoeffFromPxPtrTo(pPoint + 6 * WORD, pPoint, pQxOverTwist);
        }

        uint256 pF0 = _allocWords(12);
        uint256 pF1 = _allocWords(12);
        uint256 pFM = _allocWords(12);
        _setFq4OnePtr(pF0);
        _setFq4OnePtr(pF1);
        _setFq4OnePtr(pFM);

        uint256 arena = _allocWords(186);
        uint256 pTmp = arena;
        uint256 pD0 = pTmp + 12 * WORD;
        uint256 pD1 = pD0 + 6 * WORD;
        uint256 pD2 = pD1 + 6 * WORD;
        uint256 pA0 = pD2 + 6 * WORD;
        uint256 pA1 = pA0 + 6 * WORD;
        uint256 pEll0 = pA1 + 6 * WORD;
        uint256 pEll1 = pEll0 + 6 * WORD;
        uint256 pT0 = pEll1 + 6 * WORD;
        uint256 pT1 = pT0 + 6 * WORD;
        uint256 pScratchSqr = pT1 + 6 * WORD;
        uint256 pScratchMulByLine = pScratchSqr + 54 * WORD;
        uint256 pProd = pScratchMulByLine + 54 * WORD;

        uint256 dOff;
        uint256 aOff;
        for (uint256 i = 1; i < loop.length; ++i) {
            round = i;
            _loadFq2BytesMemoryToPtr(pD0, dblSparse, dOff); dOff += FQ2_BYTES;
            _loadFq2BytesMemoryToPtr(pD1, dblSparse, dOff); dOff += FQ2_BYTES;
            _loadFq2BytesMemoryToPtr(pD2, dblSparse, dOff); dOff += FQ2_BYTES;

            // Первая пара: шаг удвоения.
            {
                uint256 pPoint0 = pPoints;
                _lineDoubleSparsePtrTo(pEll0, pEll1, pT0, pD0, pD1, pD2, pPoint0, pPoint0 + 3 * WORD, pScratchSqr);
                MNT4Extension.fq4SqrTo(pTmp, pF0, pScratchSqr);
                uint256 swapPtr = pF0; pF0 = pTmp; pTmp = swapPtr;
                _fq4MulByLinePtrTo(pTmp, pF0, pEll0, pEll1, pScratchMulByLine);
                swapPtr = pF0; pF0 = pTmp; pTmp = swapPtr;
            }

            // Вторая пара: шаг удвоения.
            {
                uint256 pPoint1 = pPoints + 12 * WORD;
                _lineDoubleSparsePtrTo(pEll0, pEll1, pT0, pD0, pD1, pD2, pPoint1, pPoint1 + 3 * WORD, pScratchSqr);
                MNT4Extension.fq4SqrTo(pTmp, pF1, pScratchSqr);
                uint256 swapPtr = pF1; pF1 = pTmp; pTmp = swapPtr;
                _fq4MulByLinePtrTo(pTmp, pF1, pEll0, pEll1, pScratchMulByLine);
                swapPtr = pF1; pF1 = pTmp; pTmp = swapPtr;
            }

            // Общий цикл: шаг удвоения.
            MNT4Extension.fq4SqrTo(pTmp, pFM, pScratchSqr);
            {
                uint256 swapPtr = pFM; pFM = pTmp; pTmp = swapPtr;
            }
            for (uint256 j = 0; j < 2; ++j) {
                uint256 pPoint = pPoints + j * 12 * WORD;
                _lineDoubleSparsePtrTo(pEll0, pEll1, pT0, pD0, pD1, pD2, pPoint, pPoint + 3 * WORD, pScratchSqr);
                _fq4MulByLinePtrTo(pTmp, pFM, pEll0, pEll1, pScratchMulByLine);
                uint256 swapPtr = pFM; pFM = pTmp; pTmp = swapPtr;
            }

            MNT4Extension.fq4MulTo(pProd, pF0, pF1, pScratchSqr);
            multiDigest = _digestNormalizedFq4PtrStrong(pFM);
            singlesDigest = _digestNormalizedFq4PtrStrong(pProd);
            if (multiDigest != singlesDigest) {
                stage = 1;
                return (stage, round, multiDigest, singlesDigest);
            }

            int8 bit = _decodeLoopMem(loop, i);
            if (bit == 0) continue;

            _loadFq2BytesMemoryToPtr(pA0, addSparse, aOff); aOff += FQ2_BYTES;
            _loadFq2BytesMemoryToPtr(pA1, addSparse, aOff); aOff += FQ2_BYTES;
            uint256 pYOT = bit == 1 ? pQyOverTwist : pQyOverTwistNeg;

            // Первая пара: шаг сложения.
            {
                uint256 pPoint0 = pPoints;
                _lineAddSparsePtrTo(
                    pEll0,
                    pEll1,
                    pT0,
                    pT1,
                    pA0,
                    pA1,
                    pPoint0 + 6 * WORD,
                    pYOT,
                    pPoint0 + 3 * WORD,
                    pScratchSqr
                );
                uint256 swapPtr = pF0;
                _fq4MulByLinePtrTo(pTmp, pF0, pEll0, pEll1, pScratchMulByLine);
                pF0 = pTmp;
                pTmp = swapPtr;
            }

            // Вторая пара: шаг сложения.
            {
                uint256 pPoint1 = pPoints + 12 * WORD;
                _lineAddSparsePtrTo(
                    pEll0,
                    pEll1,
                    pT0,
                    pT1,
                    pA0,
                    pA1,
                    pPoint1 + 6 * WORD,
                    pYOT,
                    pPoint1 + 3 * WORD,
                    pScratchSqr
                );
                uint256 swapPtr = pF1;
                _fq4MulByLinePtrTo(pTmp, pF1, pEll0, pEll1, pScratchMulByLine);
                pF1 = pTmp;
                pTmp = swapPtr;
            }

            // Общий цикл: шаг сложения.
            for (uint256 j = 0; j < 2; ++j) {
                uint256 pPoint = pPoints + j * 12 * WORD;
                _lineAddSparsePtrTo(
                    pEll0,
                    pEll1,
                    pT0,
                    pT1,
                    pA0,
                    pA1,
                    pPoint + 6 * WORD,
                    pYOT,
                    pPoint + 3 * WORD,
                    pScratchSqr
                );
                _fq4MulByLinePtrTo(pTmp, pFM, pEll0, pEll1, pScratchMulByLine);
                uint256 swapPtr = pFM; pFM = pTmp; pTmp = swapPtr;
            }

            MNT4Extension.fq4MulTo(pProd, pF0, pF1, pScratchSqr);
            multiDigest = _digestNormalizedFq4PtrStrong(pFM);
            singlesDigest = _digestNormalizedFq4PtrStrong(pProd);
            if (multiDigest != singlesDigest) {
                stage = 2;
                return (stage, round, multiDigest, singlesDigest);
            }
        }

        if (ATE_IS_LOOP_COUNT_NEG) {
            _loadFq2BytesMemoryToPtr(pA0, addSparse, aOff); aOff += FQ2_BYTES;
            _loadFq2BytesMemoryToPtr(pA1, addSparse, aOff); aOff += FQ2_BYTES;

            {
                uint256 pPoint0 = pPoints;
                _lineAddSparsePtrTo(
                    pEll0,
                    pEll1,
                    pT0,
                    pT1,
                    pA0,
                    pA1,
                    pPoint0 + 6 * WORD,
                    pQyOverTwist,
                    pPoint0 + 3 * WORD,
                    pScratchSqr
                );
                uint256 swapPtr = pF0;
                _fq4MulByLinePtrTo(pTmp, pF0, pEll0, pEll1, pScratchMulByLine);
                pF0 = pTmp;
                pTmp = swapPtr;
            }
            {
                uint256 pPoint1 = pPoints + 12 * WORD;
                _lineAddSparsePtrTo(
                    pEll0,
                    pEll1,
                    pT0,
                    pT1,
                    pA0,
                    pA1,
                    pPoint1 + 6 * WORD,
                    pQyOverTwist,
                    pPoint1 + 3 * WORD,
                    pScratchSqr
                );
                uint256 swapPtr = pF1;
                _fq4MulByLinePtrTo(pTmp, pF1, pEll0, pEll1, pScratchMulByLine);
                pF1 = pTmp;
                pTmp = swapPtr;
            }
            for (uint256 j = 0; j < 2; ++j) {
                uint256 pPoint = pPoints + j * 12 * WORD;
                _lineAddSparsePtrTo(
                    pEll0,
                    pEll1,
                    pT0,
                    pT1,
                    pA0,
                    pA1,
                    pPoint + 6 * WORD,
                    pQyOverTwist,
                    pPoint + 3 * WORD,
                    pScratchSqr
                );
                _fq4MulByLinePtrTo(pTmp, pFM, pEll0, pEll1, pScratchMulByLine);
                uint256 swapPtr = pFM; pFM = pTmp; pTmp = swapPtr;
            }

            MNT4Extension.fq4MulTo(pProd, pF0, pF1, pScratchSqr);
            multiDigest = _digestNormalizedFq4PtrStrong(pFM);
            singlesDigest = _digestNormalizedFq4PtrStrong(pProd);
            if (multiDigest != singlesDigest) {
                stage = 3;
                round = loop.length;
                return (stage, round, multiDigest, singlesDigest);
            }
        }

        // Возвращаем нормализованные хеши и при отсутствии расхождений.
        round = loop.length;
        multiDigest = _digestNormalizedFq4PtrStrong(pFM);
        singlesDigest = _digestNormalizedFq4PtrStrong(pProd);
    }

    /// @notice Формирует подготовленные данные `debugPreparedSparseTwoSinglesVsMultiPathMatrixMem`, которые затем переиспользуются в цикле Миллера.
    function debugPreparedSparseTwoSinglesVsMultiPathMatrixMem(
        G1Affine[] memory points,
        bytes memory dblSparse,
        bytes memory addSparse
    ) internal pure returns (
        uint256 stage,
        uint256 round,
        bytes32 manualMultiDigest,
        bytes32 manualSinglesDigest,
        bytes32 prodMultiDigest,
        bytes32 prodSinglesDigest
    ) {
        (stage, round, manualMultiDigest, manualSinglesDigest) =
            debugPreparedSparseTwoSinglesVsMultiFirstMismatchMem(points, dblSparse, addSparse);
        prodMultiDigest = multiMillerLoopFixedQPreparedSparseBlobNoInvMemDigest(points, dblSparse, addSparse);
        prodSinglesDigest = millerSinglesProductFixedQPreparedSparseBlobNoInvMemDigest(points, dblSparse, addSparse);
    }

    /// @notice Формирует подготовленные данные `debugPreparedSparseDuplicateSingleSquareVsMultiFirstMismatchMem`, которые затем переиспользуются в цикле Миллера.
    function debugPreparedSparseDuplicateSingleSquareVsMultiFirstMismatchMem(
        G1Affine memory p,
        bytes memory dblSparse,
        bytes memory addSparse
    ) internal pure returns (
        uint256 stage,
        uint256 round,
        bytes32 multiDigest,
        bytes32 singleSqDigest
    ) {
        require(dblSparse.length == FIXED_DBL_SPARSE_BYTES, "bad dbl sparse");
        require(addSparse.length == FIXED_ADD_SPARSE_BYTES, "bad add sparse");
        bytes memory loop = ATE_LOOP_ENC;

        (uint256 pQxOverTwist, uint256 pQyOverTwist, uint256 pQyOverTwistNeg) = _fixedQOverTwistPtrs();

        uint256 pPoint = _allocWords(12); // px(3), py(3), l1(6)
        uint256 x0 = p.x[0];
        uint256 x1 = p.x[1];
        uint256 x2 = p.x[2];
        uint256 y0 = p.y[0];
        uint256 y1 = p.y[1];
        uint256 y2 = p.y[2];
        assembly ("memory-safe") {
            mstore(pPoint, x0)
            mstore(add(pPoint, 0x20), x1)
            mstore(add(pPoint, 0x40), x2)
            mstore(add(pPoint, 0x60), y0)
            mstore(add(pPoint, 0x80), y1)
            mstore(add(pPoint, 0xa0), y2)
        }
        _buildL1CoeffFromPxPtrTo(pPoint + 6 * WORD, pPoint, pQxOverTwist);

        uint256 pFS = _allocWords(12);
        uint256 pFM = _allocWords(12);
        _setFq4OnePtr(pFS);
        _setFq4OnePtr(pFM);

        uint256 arena = _allocWords(186);
        uint256 pTmp = arena;
        uint256 pD0 = pTmp + 12 * WORD;
        uint256 pD1 = pD0 + 6 * WORD;
        uint256 pD2 = pD1 + 6 * WORD;
        uint256 pA0 = pD2 + 6 * WORD;
        uint256 pA1 = pA0 + 6 * WORD;
        uint256 pEll0 = pA1 + 6 * WORD;
        uint256 pEll1 = pEll0 + 6 * WORD;
        uint256 pT0 = pEll1 + 6 * WORD;
        uint256 pT1 = pT0 + 6 * WORD;
        uint256 pScratchSqr = pT1 + 6 * WORD;
        uint256 pScratchMulByLine = pScratchSqr + 54 * WORD;
        uint256 pSingleSq = pScratchMulByLine + 54 * WORD;

        uint256 dOff;
        uint256 aOff;
        for (uint256 i = 1; i < loop.length; ++i) {
            round = i;
            _loadFq2BytesMemoryToPtr(pD0, dblSparse, dOff); dOff += FQ2_BYTES;
            _loadFq2BytesMemoryToPtr(pD1, dblSparse, dOff); dOff += FQ2_BYTES;
            _loadFq2BytesMemoryToPtr(pD2, dblSparse, dOff); dOff += FQ2_BYTES;

            _lineDoubleSparsePtrTo(pEll0, pEll1, pT0, pD0, pD1, pD2, pPoint, pPoint + 3 * WORD, pScratchSqr);

            {
                MNT4Extension.fq4SqrTo(pTmp, pFS, pScratchSqr);
                uint256 swapPtr = pFS; pFS = pTmp; pTmp = swapPtr;
                _fq4MulByLinePtrTo(pTmp, pFS, pEll0, pEll1, pScratchMulByLine);
                swapPtr = pFS; pFS = pTmp; pTmp = swapPtr;
            }

            {
                MNT4Extension.fq4SqrTo(pTmp, pFM, pScratchSqr);
                uint256 swapPtr = pFM; pFM = pTmp; pTmp = swapPtr;
                _fq4MulByLinePtrTo(pTmp, pFM, pEll0, pEll1, pScratchMulByLine);
                swapPtr = pFM; pFM = pTmp; pTmp = swapPtr;
                _fq4MulByLinePtrTo(pTmp, pFM, pEll0, pEll1, pScratchMulByLine);
                swapPtr = pFM; pFM = pTmp; pTmp = swapPtr;
            }

            MNT4Extension.fq4SqrTo(pSingleSq, pFS, pScratchSqr);
            multiDigest = _digestNormalizedFq4PtrStrong(pFM);
            singleSqDigest = _digestNormalizedFq4PtrStrong(pSingleSq);
            if (multiDigest != singleSqDigest) {
                stage = 1;
                return (stage, round, multiDigest, singleSqDigest);
            }

            int8 bit = _decodeLoopMem(loop, i);
            if (bit == 0) continue;

            _loadFq2BytesMemoryToPtr(pA0, addSparse, aOff); aOff += FQ2_BYTES;
            _loadFq2BytesMemoryToPtr(pA1, addSparse, aOff); aOff += FQ2_BYTES;
            uint256 pYOT = bit == 1 ? pQyOverTwist : pQyOverTwistNeg;

            _lineAddSparsePtrTo(
                pEll0,
                pEll1,
                pT0,
                pT1,
                pA0,
                pA1,
                pPoint + 6 * WORD,
                pYOT,
                pPoint + 3 * WORD,
                pScratchSqr
            );

            {
                uint256 swapPtr = pFS;
                _fq4MulByLinePtrTo(pTmp, pFS, pEll0, pEll1, pScratchMulByLine);
                pFS = pTmp;
                pTmp = swapPtr;
            }
            {
                uint256 swapPtr = pFM;
                _fq4MulByLinePtrTo(pTmp, pFM, pEll0, pEll1, pScratchMulByLine);
                pFM = pTmp;
                pTmp = swapPtr;
                _fq4MulByLinePtrTo(pTmp, pFM, pEll0, pEll1, pScratchMulByLine);
                swapPtr = pFM;
                pFM = pTmp;
                pTmp = swapPtr;
            }

            MNT4Extension.fq4SqrTo(pSingleSq, pFS, pScratchSqr);
            multiDigest = _digestNormalizedFq4PtrStrong(pFM);
            singleSqDigest = _digestNormalizedFq4PtrStrong(pSingleSq);
            if (multiDigest != singleSqDigest) {
                stage = 2;
                return (stage, round, multiDigest, singleSqDigest);
            }
        }

        if (ATE_IS_LOOP_COUNT_NEG) {
            _loadFq2BytesMemoryToPtr(pA0, addSparse, aOff); aOff += FQ2_BYTES;
            _loadFq2BytesMemoryToPtr(pA1, addSparse, aOff); aOff += FQ2_BYTES;

            _lineAddSparsePtrTo(
                pEll0,
                pEll1,
                pT0,
                pT1,
                pA0,
                pA1,
                pPoint + 6 * WORD,
                pQyOverTwist,
                pPoint + 3 * WORD,
                pScratchSqr
            );
            {
                uint256 swapPtr = pFS;
                _fq4MulByLinePtrTo(pTmp, pFS, pEll0, pEll1, pScratchMulByLine);
                pFS = pTmp;
                pTmp = swapPtr;
            }
            {
                uint256 swapPtr = pFM;
                _fq4MulByLinePtrTo(pTmp, pFM, pEll0, pEll1, pScratchMulByLine);
                pFM = pTmp;
                pTmp = swapPtr;
                _fq4MulByLinePtrTo(pTmp, pFM, pEll0, pEll1, pScratchMulByLine);
                swapPtr = pFM;
                pFM = pTmp;
                pTmp = swapPtr;
            }

            MNT4Extension.fq4SqrTo(pSingleSq, pFS, pScratchSqr);
            multiDigest = _digestNormalizedFq4PtrStrong(pFM);
            singleSqDigest = _digestNormalizedFq4PtrStrong(pSingleSq);
            if (multiDigest != singleSqDigest) {
                stage = 3;
                round = loop.length;
                return (stage, round, multiDigest, singleSqDigest);
            }
        }
    }

    /// @notice Формирует подготовленные данные `sparsePreparedArenaProbe`, которые затем переиспользуются в цикле Миллера.
    function sparsePreparedArenaProbe(uint256 pairs) internal pure returns (uint256 wordsUsed) {
        uint256 beforePtr;
        assembly ("memory-safe") { beforePtr := mload(0x40) }
        _allocWords(174 + 12 * pairs);
        uint256 afterPtr;
        assembly ("memory-safe") { afterPtr := mload(0x40) }
        wordsUsed = (afterPtr - beforePtr) / WORD;
    }

    /// @notice Выполняет умножение `debugFirstRoundDoubleLineMulConsistencyMem`; точный уровень поля и специальный множитель отражены в названии.
    function debugFirstRoundDoubleLineMulConsistencyMem(
        G1Affine memory p,
        bytes memory dblSparse,
        bytes memory addSparse
    ) internal pure returns (bytes32 dMulByLineTwice, bytes32 dGenericMulTwice, bytes32 dSquareFromSingle) {
        require(dblSparse.length == FIXED_DBL_SPARSE_BYTES, "bad dbl sparse");
        addSparse;

        uint256 pOne = _allocWords(12);
        uint256 pTmp = _allocWords(12);
        uint256 pA = _allocWords(12);
        uint256 pB = _allocWords(12);
        uint256 pLine = _allocWords(12);
        uint256 pD0 = _allocWords(6);
        uint256 pD1 = _allocWords(6);
        uint256 pD2 = _allocWords(6);
        uint256 pEll0 = _allocWords(6);
        uint256 pEll1 = _allocWords(6);
        uint256 pT0 = _allocWords(6);
        uint256 pScratchSqr = _allocWords(54);
        uint256 pScratchMulByLine = _allocWords(54);
        uint256 pScratchMul = _allocWords(54);

        _setFq4OnePtr(pOne);
        _loadFq2BytesMemoryToPtr(pD0, dblSparse, 0);
        _loadFq2BytesMemoryToPtr(pD1, dblSparse, FQ2_BYTES);
        _loadFq2BytesMemoryToPtr(pD2, dblSparse, 2 * FQ2_BYTES);
        _lineDoubleSparsePtrTo(
            pEll0,
            pEll1,
            pT0,
            pD0,
            pD1,
            pD2,
            _ptrFp3(p.x),
            _ptrFp3(p.y),
            pScratchSqr
        );
        assembly ("memory-safe") {
            mstore(pLine, mload(pEll0))
            mstore(add(pLine, 0x20), mload(add(pEll0, 0x20)))
            mstore(add(pLine, 0x40), mload(add(pEll0, 0x40)))
            mstore(add(pLine, 0x60), mload(add(pEll0, 0x60)))
            mstore(add(pLine, 0x80), mload(add(pEll0, 0x80)))
            mstore(add(pLine, 0xa0), mload(add(pEll0, 0xa0)))
            mstore(add(pLine, 0xc0), mload(pEll1))
            mstore(add(pLine, 0xe0), mload(add(pEll1, 0x20)))
            mstore(add(pLine, 0x100), mload(add(pEll1, 0x40)))
            mstore(add(pLine, 0x120), mload(add(pEll1, 0x60)))
            mstore(add(pLine, 0x140), mload(add(pEll1, 0x80)))
            mstore(add(pLine, 0x160), mload(add(pEll1, 0xa0)))
        }

        // Вариант A: дважды умножаем единицу на линию.
        _fq4MulByLinePtrTo(pTmp, pOne, pEll0, pEll1, pScratchMulByLine);
        _fq4MulByLinePtrTo(pA, pTmp, pEll0, pEll1, pScratchMulByLine);

        // B: generic fq4 mul twice from one.
        MNT4Extension.fq4MulTo(pTmp, pOne, pLine, pScratchMul);
        MNT4Extension.fq4MulTo(pB, pTmp, pLine, pScratchMul);

        // Вариант C: возводим в квадрат single, где single=one*line.
        uint256 pC = _allocWords(12);
        MNT4Extension.fq4SqrTo(pC, pTmp, pScratchSqr);

        dMulByLineTwice = _digestNormalizedFq4PtrStrong(pA);
        dGenericMulTwice = _digestNormalizedFq4PtrStrong(pB);
        dSquareFromSingle = _digestNormalizedFq4PtrStrong(pC);
    }

    /// @notice Формирует подготовленные данные `sparsePreparedLoopLenProbe`, которые затем переиспользуются в цикле Миллера.
    function sparsePreparedLoopLenProbe() internal pure returns (uint256 loopLen) {
        bytes memory loop = ATE_LOOP_ENC;
        loopLen = loop.length;
    }

    /// @notice Формирует подготовленные данные `sparsePreparedMulByLineProbeMem`, которые затем переиспользуются в цикле Миллера.
    function sparsePreparedMulByLineProbeMem(
        bytes memory dblSparse,
        uint256 rounds
    ) internal pure returns (uint256 stage, uint256 loopLen, uint256 limit, uint256 freePtr) {
        stage = 1;
        require(dblSparse.length == FIXED_DBL_SPARSE_BYTES, "bad dbl sparse");
        bytes memory loop = ATE_LOOP_ENC;
        loopLen = loop.length;

        stage = 2;
        MNT4ExtensionFinal.Fq4 memory f = _allocFq4();
        uint256 pFBase = _ptrFq4(f);
        _setFq4OnePtr(pFBase);

        stage = 3;
        uint256 arena = _allocWords(132);
        uint256 pTmp = arena;
        uint256 pL0 = pTmp + 12 * WORD;
        uint256 pL1 = pL0 + 6 * WORD;
        uint256 pScratchSqr = pL1 + 6 * WORD;
        uint256 pScratchMulByLine = pScratchSqr + 54 * WORD;
        pScratchMulByLine;

        stage = 4;
        _loadFq2BytesMemoryToPtr(pL0, dblSparse, 0);
        _loadFq2BytesMemoryToPtr(pL1, dblSparse, FQ2_BYTES);

        stage = 5;
        uint256 effRounds = rounds;
        uint256 maxRounds = loopLen - 1;
        if (effRounds > maxRounds) {
            effRounds = maxRounds;
        }
        limit = effRounds + 1;

        stage = 6;
        assembly ("memory-safe") { freePtr := mload(0x40) }
    }

    /// @notice Формирует подготовленные данные `sparsePreparedMulByLineProbeMemRet`, которые затем переиспользуются в цикле Миллера.
    function sparsePreparedMulByLineProbeMemRet(
        bytes memory dblSparse,
        uint256 rounds
    ) internal pure returns (uint256 stage, MNT4ExtensionFinal.Fq4 memory f) {
        require(dblSparse.length == FIXED_DBL_SPARSE_BYTES, "bad dbl sparse");
        bytes memory loop = ATE_LOOP_ENC;

        stage = 1;
        f = _allocFq4();
        uint256 pFBase = _ptrFq4(f);
        _setFq4OnePtr(pFBase);

        uint256 arena = _allocWords(132);
        uint256 pTmp = arena;
        uint256 pL0 = pTmp + 12 * WORD;
        uint256 pL1 = pL0 + 6 * WORD;
        uint256 pScratchSqr = pL1 + 6 * WORD;
        uint256 pScratchMulByLine = pScratchSqr + 54 * WORD;
        pScratchMulByLine;

        stage = 2;
        _loadFq2BytesMemoryToPtr(pL0, dblSparse, 0);
        _loadFq2BytesMemoryToPtr(pL1, dblSparse, FQ2_BYTES);

        uint256 effRounds = rounds;
        uint256 maxRounds = loop.length - 1;
        if (effRounds > maxRounds) {
            effRounds = maxRounds;
        }
        uint256 limit = effRounds + 1;
        for (uint256 i = 1; i < limit; ++i) {
            MNT4Extension.fq4SqrTo(pTmp, pFBase, pScratchSqr);
            _fq4MulByLinePtrTo(pFBase, pTmp, pL0, pL1, pScratchMulByLine);

            int8 bit = _decodeLoopMem(loop, i);
            if (bit != 0) {
                _fq4MulByLinePtrTo(pTmp, pFBase, pL0, pL1, pScratchMulByLine);
                _copyFq4Ptr(pFBase, pTmp);
            }
        }

        if (ATE_IS_LOOP_COUNT_NEG && limit == loop.length) {
            _fq4MulByLinePtrTo(pTmp, pFBase, pL0, pL1, pScratchMulByLine);
            _copyFq4Ptr(pFBase, pTmp);
        }
        stage = 3;
    }

    /// @notice Формирует подготовленные данные `pairingFixedQPreparedSparseMemProbe`, которые затем переиспользуются в цикле Миллера.
    function pairingFixedQPreparedSparseMemProbe(
        G1Affine memory p
    ) internal pure returns (uint256 stage, uint256 freePtr) {
        stage = 1;
        (bytes memory dblSparse, bytes memory addSparse) = prepareFixedQBlobSparse();

        stage = 2;
        MNT4ExtensionFinal.Fq4 memory m = _allocFq4();
        _millerLoopFixedQPreparedSparseBlobNoInvMemTo(_ptrFq4(m), p, dblSparse, addSparse);

        stage = 3;
        assembly ("memory-safe") { freePtr := mload(0x40) }
    }

    /// @notice Формирует подготовленные данные `pairingFixedQPreparedSparseMemProbeWithFinal`, которые затем переиспользуются в цикле Миллера.
    function pairingFixedQPreparedSparseMemProbeWithFinal(
        G1Affine memory p
    ) internal pure returns (uint256 stage, uint256 out0, uint256 freePtr) {
        stage = 1;
        (bytes memory dblSparse, bytes memory addSparse) = prepareFixedQBlobSparse();

        stage = 2;
        uint256 pM = _allocWords(12);
        _millerLoopFixedQPreparedSparseBlobNoInvMemTo(pM, p, dblSparse, addSparse);

        stage = 3;
        MNT4ExtensionFinal.Fq4 memory m;
        assembly ("memory-safe") { m := pM }
        (uint256 feStage, uint256 feOut0) = finalExponentiationFromMillerProbe(m, ATE_IS_LOOP_COUNT_NEG);
        out0 = feOut0;
        require(feStage == 4, "fe probe");

        stage = 4;
        assembly ("memory-safe") { freePtr := mload(0x40) }
    }

    /// @notice Выполняет этап цикла Миллера `finalExponentiationFromMillerProbe`; результат является элементом поля расширения до финальной экспоненты.
    function finalExponentiationFromMillerProbe(
        MNT4ExtensionFinal.Fq4 memory value,
        bool millerNeedsInverse
    ) internal pure returns (uint256 stage, uint256 out0) {
        stage = 1;
        uint256 pValueNorm = _allocWords(12);
        _copyFq4Ptr(pValueNorm, _ptrFq4(value));
        _normalizeFq4Ptr(pValueNorm);
        MNT4ExtensionFinal.Fq4 memory valueNorm;
        assembly ("memory-safe") { valueNorm := pValueNorm }

        uint256 pValueInv = _fq4InvToNewPtr(pValueNorm);

        stage = 2;
        uint256 pFirst = _allocWords(12);
        _finalExpFirstChunkPtrTo(pFirst, pValueNorm, pValueInv);
        if (millerNeedsInverse) {
            MNT4Extension.fq2NegTo(pFirst + 6 * WORD, pFirst + 6 * WORD);
        }
        MNT4ExtensionFinal.Fq4 memory first;
        assembly ("memory-safe") { first := pFirst }
        valueNorm;

        stage = 3;
        uint256 pFirstInv = _allocWords(12);
        _fq4ConjugatePtrTo(pFirstInv, pFirst);
        uint256 pOut = _allocWords(12);
        _finalExpLastChunkPtrTo(pOut, pFirst, pFirstInv);
        assembly ("memory-safe") { out0 := mload(pOut) }

        stage = 4;
    }

    /// @dev Диагностическая функция для сверки с arkworks.
    /// номер проверяемого этапа:
    /// 1 = normalized Miller value, 2 = inverse, 3 = first chunk after optional
    /// с учетом соглашения об обращении результата цикла Миллера; 4 = обратный первый блок; 5 = часть W1
    /// часть Фробениуса; 6 = возведение в степень W0; 7 = итог финальной экспоненты.
    function finalExponentiationStageWordProbe(
        MNT4ExtensionFinal.Fq4 memory value,
        bool millerNeedsInverse,
        uint8 target
    ) internal pure returns (uint256 stage, uint256 out0) {
        uint256 pValueNorm = _allocWords(12);
        _copyFq4Ptr(pValueNorm, _ptrFq4(value));
        _normalizeFq4Ptr(pValueNorm);
        if (target == 1) {
            assembly ("memory-safe") { out0 := mload(pValueNorm) }
            return (1, out0);
        }

        uint256 pValueInv = _fq4InvToNewPtr(pValueNorm);
        if (target == 2) {
            assembly ("memory-safe") { out0 := mload(pValueInv) }
            return (2, out0);
        }

        uint256 pFirst = _allocWords(12);
        _finalExpFirstChunkPtrTo(pFirst, pValueNorm, pValueInv);
        if (millerNeedsInverse) {
            MNT4Extension.fq2NegTo(pFirst + 6 * WORD, pFirst + 6 * WORD);
        }
        if (target == 3) {
            assembly ("memory-safe") { out0 := mload(pFirst) }
            return (3, out0);
        }

        uint256 pFirstInv = _allocWords(12);
        _fq4ConjugatePtrTo(pFirstInv, pFirst);
        if (target == 4) {
            assembly ("memory-safe") { out0 := mload(pFirstInv) }
            return (4, out0);
        }

        uint256 pW1 = _allocWords(12);
        _fq4Frobenius1PtrTo(pW1, pFirst);
        if (target == 5) {
            assembly ("memory-safe") { out0 := mload(pW1) }
            return (5, out0);
        }

        uint256 pW0 = _allocWords(12);
        if (W0_IS_NEG) {
            _expW0PtrTo(pW0, pFirstInv);
        } else {
            _expW0PtrTo(pW0, pFirst);
        }
        if (target == 6) {
            assembly ("memory-safe") { out0 := mload(pW0) }
            return (6, out0);
        }

        if (target == 8) {
            uint256 pW0Bit = _allocWords(12);
            if (W0_IS_NEG) {
                _expW0BitPtrTo(pW0Bit, pFirstInv);
            } else {
                _expW0BitPtrTo(pW0Bit, pFirst);
            }
            assembly ("memory-safe") { out0 := mload(pW0Bit) }
            return (8, out0);
        }

        uint256 pScratch = _allocWords(54);
        uint256 pOut = _allocWords(12);
        _fq4CyclotomicMulPtrTo(pOut, pW1, pW0, pScratch);
        assembly ("memory-safe") { out0 := mload(pOut) }
        stage = 7;
    }

    /// @notice Формирует подготовленные данные `pairingFixedQPreparedSparseMemFinalStageProbe`, которые затем переиспользуются в цикле Миллера.
    function pairingFixedQPreparedSparseMemFinalStageProbe(
        G1Affine memory p
    ) internal pure returns (uint256 millerStage, uint256 feStage, uint256 out0) {
        millerStage = 1;
        (bytes memory dblSparse, bytes memory addSparse) = prepareFixedQBlobSparse();

        millerStage = 2;
        uint256 pM = _allocWords(12);
        _millerLoopFixedQPreparedSparseBlobNoInvMemTo(pM, p, dblSparse, addSparse);

        millerStage = 3;
        MNT4ExtensionFinal.Fq4 memory m;
        assembly ("memory-safe") { m := pM }
        (feStage, out0) = finalExponentiationFromMillerProbe(m, ATE_IS_LOOP_COUNT_NEG);
    }

    /// @notice Формирует подготовленные данные `pairingFixedQPreparedSparseMemFirstChunkProbe`, которые затем переиспользуются в цикле Миллера.
    function pairingFixedQPreparedSparseMemFirstChunkProbe(
        G1Affine memory p
    ) internal pure returns (uint256 stage, uint256 out0) {
        stage = 1;
        (bytes memory dblSparse, bytes memory addSparse) = prepareFixedQBlobSparse();
        uint256 pM = _allocWords(12);
        _millerLoopFixedQPreparedSparseBlobNoInvMemTo(pM, p, dblSparse, addSparse);

        stage = 2;
        _normalizeFq4Ptr(pM);
        uint256 pInv = _fq4InvToNewPtr(pM);

        stage = 3;
        uint256 pFirst = _allocWords(12);
        _finalExpFirstChunkPtrTo(pFirst, pM, pInv);
        if (ATE_IS_LOOP_COUNT_NEG) {
            MNT4Extension.fq2NegTo(pFirst + 6 * WORD, pFirst + 6 * WORD);
        }
        assembly ("memory-safe") { out0 := mload(pFirst) }
        stage = 4;
    }

    /// @notice Формирует подготовленные данные `pairingFixedQPreparedSparseMemW1Probe`, которые затем переиспользуются в цикле Миллера.
    function pairingFixedQPreparedSparseMemW1Probe(
        G1Affine memory p
    ) internal pure returns (uint256 stage, uint256 out0) {
        stage = 1;
        (bytes memory dblSparse, bytes memory addSparse) = prepareFixedQBlobSparse();
        uint256 pM = _allocWords(12);
        _millerLoopFixedQPreparedSparseBlobNoInvMemTo(pM, p, dblSparse, addSparse);
        _normalizeFq4Ptr(pM);

        uint256 pInv = _fq4InvToNewPtr(pM);

        stage = 2;
        uint256 pFirst = _allocWords(12);
        _finalExpFirstChunkPtrTo(pFirst, pM, pInv);
        if (ATE_IS_LOOP_COUNT_NEG) {
            MNT4Extension.fq2NegTo(pFirst + 6 * WORD, pFirst + 6 * WORD);
        }

        stage = 3;
        uint256 pW1 = _allocWords(12);
        _fq4Frobenius1PtrTo(pW1, pFirst);
        assembly ("memory-safe") { out0 := mload(pW1) }
        stage = 4;
    }

    /// @notice Формирует подготовленные данные `pairingFixedQPreparedSparseMemW0Probe`, которые затем переиспользуются в цикле Миллера.
    function pairingFixedQPreparedSparseMemW0Probe(
        G1Affine memory p
    ) internal pure returns (uint256 stage, uint256 out0) {
        stage = 1;
        (bytes memory dblSparse, bytes memory addSparse) = prepareFixedQBlobSparse();
        uint256 pM = _allocWords(12);
        _millerLoopFixedQPreparedSparseBlobNoInvMemTo(pM, p, dblSparse, addSparse);
        _normalizeFq4Ptr(pM);

        uint256 pInv = _fq4InvToNewPtr(pM);

        stage = 2;
        uint256 pFirst = _allocWords(12);
        _finalExpFirstChunkPtrTo(pFirst, pM, pInv);
        if (ATE_IS_LOOP_COUNT_NEG) {
            MNT4Extension.fq2NegTo(pFirst + 6 * WORD, pFirst + 6 * WORD);
        }

        stage = 3;
        uint256 pW0 = _allocWords(12);
        if (W0_IS_NEG) {
            uint256 pFirstInv = _allocWords(12);
            _fq4ConjugatePtrTo(pFirstInv, pFirst);
            _expW0PtrTo(pW0, pFirstInv);
        } else {
            _expW0PtrTo(pW0, pFirst);
        }
        assembly ("memory-safe") { out0 := mload(pW0) }
        stage = 4;
    }

    /// @notice Формирует подготовленные данные `pairingFixedQPreparedSparseMemMillerOutputProbe`, которые затем переиспользуются в цикле Миллера.
    function pairingFixedQPreparedSparseMemMillerOutputProbe(
        G1Affine memory p
    ) internal pure returns (uint256 out00, uint256 out11) {
        (bytes memory dblSparse, bytes memory addSparse) = prepareFixedQBlobSparse();
        uint256 pM = _allocWords(12);
        _millerLoopFixedQPreparedSparseBlobNoInvMemTo(pM, p, dblSparse, addSparse);
        assembly ("memory-safe") {
            out00 := mload(pM)
            out11 := mload(add(pM, 0x120))
        }
    }

    /// @notice Формирует подготовленные данные `pairingFixedQPreparedFirstDblLineProbe`, которые затем переиспользуются в цикле Миллера.
    function pairingFixedQPreparedFirstDblLineProbe(
        G1Affine memory p
    ) internal pure returns (uint256 ell00, uint256 ell10) {
        (bytes memory dblSparse,) = prepareFixedQBlobSparse();
        uint256 pPx = _ptrFp3(p.x);
        uint256 pPy = _ptrFp3(p.y);

        uint256 arena = _allocWords(60);
        uint256 pD0 = arena;
        uint256 pD1 = pD0 + 6 * WORD;
        uint256 pD2 = pD1 + 6 * WORD;
        uint256 pEll0 = pD2 + 6 * WORD;
        uint256 pEll1 = pEll0 + 6 * WORD;
        uint256 pTmp = pEll1 + 6 * WORD;
        uint256 pScratch = pTmp + 6 * WORD;

        _loadSparseDblStepMemoryToPtr(pD0, dblSparse, 0);
        _lineDoubleSparsePtrTo(pEll0, pEll1, pTmp, pD0, pD1, pD2, pPx, pPy, pScratch);
        assembly ("memory-safe") {
            ell00 := mload(pEll0)
            ell10 := mload(pEll1)
        }
    }

    /// @notice Формирует подготовленные данные `pairingFixedQPreparedFirstAddLineProbe`, которые затем переиспользуются в цикле Миллера.
    function pairingFixedQPreparedFirstAddLineProbe(
        G1Affine memory p
    ) internal pure returns (uint256 ell00, uint256 ell10) {
        (, bytes memory addSparse) = prepareFixedQBlobSparse();
        (uint256 pQxOverTwist, uint256 pQyOverTwist,) = _fixedQOverTwistPtrs();
        uint256 pPx = _ptrFp3(p.x);
        uint256 pPy = _ptrFp3(p.y);

        uint256 arena = _allocWords(42);
        uint256 pA0 = arena;
        uint256 pA1 = pA0 + 6 * WORD;
        uint256 pEll0 = pA1 + 6 * WORD;
        uint256 pEll1 = pEll0 + 6 * WORD;
        uint256 pTmp0 = pEll1 + 6 * WORD;
        uint256 pTmp1 = pTmp0 + 6 * WORD;
        uint256 pL1Coeff = pTmp1 + 6 * WORD;
        uint256 pScratch = pL1Coeff + 6 * WORD;

        _buildL1CoeffFromPxPtrTo(pL1Coeff, pPx, pQxOverTwist);
        _loadSparseAddStepMemoryToPtr(pA0, addSparse, 0);
        _lineAddSparsePtrTo(pEll0, pEll1, pTmp0, pTmp1, pA0, pA1, pL1Coeff, pQyOverTwist, pPy, pScratch);
        assembly ("memory-safe") {
            ell00 := mload(pEll0)
            ell10 := mload(pEll1)
        }
    }

    /// @notice Выполняет внутреннюю операцию `fixedQOverTwistProbe`; параметры и результат используют представление текущей библиотеки.
    function fixedQOverTwistProbe() internal pure returns (uint256 xot00, uint256 yot00) {
        (uint256 pQxOverTwist, uint256 pQyOverTwist,) = _fixedQOverTwistPtrs();
        assembly ("memory-safe") {
            xot00 := mload(pQxOverTwist)
            yot00 := mload(pQyOverTwist)
        }
    }

    /// @notice Выполняет внутреннюю операцию `qOverTwistFromQProbe`; параметры и результат используют представление текущей библиотеки.
    function qOverTwistFromQProbe(G2Affine memory q) internal pure returns (uint256 xot00, uint256 yot00) {
        (uint256 pQxOverTwist, uint256 pQyOverTwist,) = _qOverTwistPtrsFromQ(q);
        assembly ("memory-safe") {
            xot00 := mload(pQxOverTwist)
            yot00 := mload(pQyOverTwist)
        }
    }

    /// @notice Формирует подготовленные данные `pairingFixedQPreparedSparseMemMillerBoundedProbe`, которые затем переиспользуются в цикле Миллера.
    function pairingFixedQPreparedSparseMemMillerBoundedProbe(
        G1Affine memory p,
        uint256 rounds
    ) internal pure returns (uint256 out00, uint256 out11) {
        (bytes memory dblSparse, bytes memory addSparse) = prepareFixedQBlobSparse();
        bytes memory loop = ATE_LOOP_ENC;
        (uint256 pQxOverTwist, uint256 pQyOverTwist, uint256 pQyOverTwistNeg) = _fixedQOverTwistPtrs();
        uint256 pPx = _ptrFp3(p.x);
        uint256 pPy = _ptrFp3(p.y);

        uint256 pFBase = _allocWords(12);
        _setFq4OnePtr(pFBase);

        uint256 arena = _allocWords(174);
        _zeroWords(arena, 174);
        uint256 pTmp = arena;
        uint256 pD0 = pTmp + 12 * WORD;
        uint256 pD1 = pD0 + 6 * WORD;
        uint256 pD2 = pD1 + 6 * WORD;
        uint256 pA0 = pD2 + 6 * WORD;
        uint256 pA1 = pA0 + 6 * WORD;
        uint256 pEll0 = pA1 + 6 * WORD;
        uint256 pEll1 = pEll0 + 6 * WORD;
        uint256 pEvalTmp = pEll1 + 6 * WORD;
        uint256 pL1Coeff = pEvalTmp + 6 * WORD;
        uint256 pScratchSqr = pL1Coeff + 6 * WORD;
        uint256 pScratchMulByLine = pScratchSqr + 54 * WORD;

        _buildL1CoeffFromPxPtrTo(pL1Coeff, pPx, pQxOverTwist);

        uint256 pF = pFBase;
        uint256 dOff;
        uint256 aOff;
        uint256 maxRounds = loop.length - 1;
        if (rounds > maxRounds) rounds = maxRounds;
        uint256 limit = rounds + 1;
        for (uint256 i = 1; i < limit; ++i) {
            dOff = _loadSparseDblStepMemoryToPtr(pD0, dblSparse, dOff);
            MNT4Extension.fq4SqrTo(pTmp, pF, pScratchSqr);
            uint256 tmpSwap = pF;
            pF = pTmp;
            pTmp = tmpSwap;
            _lineDoubleSparseMulPtrTo(
                pTmp, pF, pEll0, pEll1, pEvalTmp, pD0, pD1, pD2, pPx, pPy, pScratchSqr, pScratchMulByLine
            );
            tmpSwap = pF;
            pF = pTmp;
            pTmp = tmpSwap;

            int8 bit = _decodeLoopMem(loop, i);
            if (bit == 0) continue;
            aOff = _loadSparseAddStepMemoryToPtr(pA0, addSparse, aOff);
            _lineAddSparseMulPtrTo(
                pTmp,
                pF,
                pEll0,
                pEll1,
                pEvalTmp,
                pA0,
                pA1,
                pL1Coeff,
                bit == 1 ? pQyOverTwist : pQyOverTwistNeg,
                pPy,
                pScratchSqr,
                pScratchMulByLine
            );
            tmpSwap = pF;
            pF = pTmp;
            pTmp = tmpSwap;
        }
        assembly ("memory-safe") {
            out00 := mload(pF)
            out11 := mload(add(pF, 0x120))
        }
    }

    /// @notice Формирует подготовленные данные `pairingFixedQPreparedSparseMemInvProbe`, которые затем переиспользуются в цикле Миллера.
    function pairingFixedQPreparedSparseMemInvProbe(
        G1Affine memory p
    ) internal pure returns (uint256 stage, uint256 out0) {
        stage = 1;
        (bytes memory dblSparse, bytes memory addSparse) = prepareFixedQBlobSparse();
        uint256 pM = _allocWords(12);
        _millerLoopFixedQPreparedSparseBlobNoInvMemTo(pM, p, dblSparse, addSparse);

        stage = 2;
        uint256 pInv = _fq4InvToNewPtr(pM);
        assembly ("memory-safe") { out0 := mload(pInv) }
        stage = 3;
    }

    /// @notice Формирует подготовленные данные `pairingFixedQPreparedSparseMemInvProbeCopied`, которые затем переиспользуются в цикле Миллера.
    function pairingFixedQPreparedSparseMemInvProbeCopied(
        G1Affine memory p
    ) internal pure returns (uint256 stage, uint256 out0, uint256 freeBeforeInv) {
        stage = 1;
        (bytes memory dblSparse, bytes memory addSparse) = prepareFixedQBlobSparse();
        uint256 pM = _allocWords(12);
        _millerLoopFixedQPreparedSparseBlobNoInvMemTo(pM, p, dblSparse, addSparse);

        stage = 2;
        MNT4ExtensionFinal.Fq4 memory mCopy = _allocFq4();
        _copyFq4Ptr(_ptrFq4(mCopy), pM);
        assembly ("memory-safe") { freeBeforeInv := mload(0x40) }

        stage = 3;
        uint256 pInv = _fq4InvToNewPtr(_ptrFq4(mCopy));
        assembly ("memory-safe") { out0 := mload(pInv) }
        stage = 4;
    }

    /// @notice Формирует подготовленные данные `pairingFixedQPreparedSparseMemInvPtrProbe`, которые затем переиспользуются в цикле Миллера.
    function pairingFixedQPreparedSparseMemInvPtrProbe(
        G1Affine memory p
    ) internal pure returns (
        uint256 stage,
        uint256 freeBeforeInv,
        uint256 den0,
        uint256 den1,
        uint256 den2,
        uint256 out0
    ) {
        stage = 1;
        (bytes memory dblSparse, bytes memory addSparse) = prepareFixedQBlobSparse();
        uint256 pM = _allocWords(12);
        _millerLoopFixedQPreparedSparseBlobNoInvMemTo(pM, p, dblSparse, addSparse);

        stage = 2;
        uint256 pInv = _allocWords(12);
        uint256 pScratch = _allocWords(54);
        assembly ("memory-safe") { freeBeforeInv := mload(0x40) }

        uint256 pT0 = pScratch;
        uint256 pT1 = pScratch + 6 * WORD;
        uint256 pUT1 = pScratch + 12 * WORD;
        uint256 pDen = pScratch + 18 * WORD;
        uint256 pDenInv = pScratch + 24 * WORD;
        uint256 pNegC1 = pScratch + 30 * WORD;
        uint256 pFq2Scratch = pScratch + 36 * WORD;
        pNegC1;

        stage = 3;
        MNT4Extension.fq2SqrTo(pT0, pM, pFq2Scratch);
        MNT4Extension.fq2SqrTo(pT1, pM + 6 * WORD, pFq2Scratch);
        MNT4Extension.fq2MulByUTo(pUT1, pT1, pFq2Scratch);
        MNT4Extension.fq2SubTo(pDen, pT0, pUT1);
        assembly ("memory-safe") {
            den0 := mload(pDen)
            den1 := mload(add(pDen, 0x20))
            den2 := mload(add(pDen, 0x40))
        }

        stage = 4;
        MNT4Extension.fq2InvTo(pDenInv, pDen, pFq2Scratch);

        stage = 5;
        MNT4Extension.fq4InvTo(pInv, pM, pScratch);
        assembly ("memory-safe") { out0 := mload(pInv) }
        stage = 6;
    }

    /// @notice Выполняет этап цикла Миллера `pairingParametricQOnchainMemMillerOutputProbe`; результат является элементом поля расширения до финальной экспоненты.
    function pairingParametricQOnchainMemMillerOutputProbe(
        G1Affine memory p,
        G2Affine memory q
    ) internal pure returns (uint256 out00, uint256 out11) {
        G1Affine[] memory one = new G1Affine[](1);
        one[0] = p;
        uint256 pM = _allocWords(12);
        _multiMillerLoopParametricQOnchainNoInvMemTo(pM, one, q);
        assembly ("memory-safe") {
            out00 := mload(pM)
            out11 := mload(add(pM, 0x120))
        }
    }

    /// @notice Выполняет операцию сопряжения `pairingParametricQOnchainMemInvProbe` в режиме, отраженном в названии функции.
    function pairingParametricQOnchainMemInvProbe(
        G1Affine memory p,
        G2Affine memory q
    ) internal pure returns (uint256 stage, uint256 out0) {
        stage = 1;
        G1Affine[] memory one = new G1Affine[](1);
        one[0] = p;
        uint256 pM = _allocWords(12);
        _multiMillerLoopParametricQOnchainNoInvMemTo(pM, one, q);

        stage = 2;
        uint256 pInv = _fq4InvToNewPtr(pM);
        assembly ("memory-safe") { out0 := mload(pInv) }
        stage = 3;
    }

    /// @notice Выполняет операцию сопряжения `pairingParametricQOnchainMemFirstChunkProbe` в режиме, отраженном в названии функции.
    function pairingParametricQOnchainMemFirstChunkProbe(
        G1Affine memory p,
        G2Affine memory q
    ) internal pure returns (uint256 stage, uint256 out0) {
        stage = 1;
        G1Affine[] memory one = new G1Affine[](1);
        one[0] = p;
        uint256 pM = _allocWords(12);
        _multiMillerLoopParametricQOnchainNoInvMemTo(pM, one, q);

        stage = 2;
        _normalizeFq4Ptr(pM);
        uint256 pInv = _fq4InvToNewPtr(pM);

        stage = 3;
        uint256 pFirst = _allocWords(12);
        _finalExpFirstChunkPtrTo(pFirst, pM, pInv);
        if (ATE_IS_LOOP_COUNT_NEG) {
            MNT4Extension.fq2NegTo(pFirst + 6 * WORD, pFirst + 6 * WORD);
        }
        assembly ("memory-safe") { out0 := mload(pFirst) }
        stage = 4;
    }

    /// @notice Выполняет операцию сопряжения `pairingParametricQOnchainMemW1Probe` в режиме, отраженном в названии функции.
    function pairingParametricQOnchainMemW1Probe(
        G1Affine memory p,
        G2Affine memory q
    ) internal pure returns (uint256 stage, uint256 out0) {
        stage = 1;
        G1Affine[] memory one = new G1Affine[](1);
        one[0] = p;
        uint256 pM = _allocWords(12);
        _multiMillerLoopParametricQOnchainNoInvMemTo(pM, one, q);
        _normalizeFq4Ptr(pM);

        uint256 pInv = _fq4InvToNewPtr(pM);

        stage = 2;
        uint256 pFirst = _allocWords(12);
        _finalExpFirstChunkPtrTo(pFirst, pM, pInv);
        if (ATE_IS_LOOP_COUNT_NEG) {
            MNT4Extension.fq2NegTo(pFirst + 6 * WORD, pFirst + 6 * WORD);
        }

        stage = 3;
        uint256 pW1 = _allocWords(12);
        _fq4Frobenius1PtrTo(pW1, pFirst);
        assembly ("memory-safe") { out0 := mload(pW1) }
        stage = 4;
    }

    /// @notice Выполняет операцию сопряжения `pairingParametricQOnchainMemW0Probe` в режиме, отраженном в названии функции.
    function pairingParametricQOnchainMemW0Probe(
        G1Affine memory p,
        G2Affine memory q
    ) internal pure returns (uint256 stage, uint256 out0) {
        stage = 1;
        G1Affine[] memory one = new G1Affine[](1);
        one[0] = p;
        uint256 pM = _allocWords(12);
        _multiMillerLoopParametricQOnchainNoInvMemTo(pM, one, q);
        _normalizeFq4Ptr(pM);

        uint256 pInv = _fq4InvToNewPtr(pM);

        stage = 2;
        uint256 pFirst = _allocWords(12);
        _finalExpFirstChunkPtrTo(pFirst, pM, pInv);
        if (ATE_IS_LOOP_COUNT_NEG) {
            MNT4Extension.fq2NegTo(pFirst + 6 * WORD, pFirst + 6 * WORD);
        }

        stage = 3;
        uint256 pW0 = _allocWords(12);
        if (W0_IS_NEG) {
            uint256 pFirstInv = _allocWords(12);
            _fq4ConjugatePtrTo(pFirstInv, pFirst);
            _expW0PtrTo(pW0, pFirstInv);
        } else {
            _expW0PtrTo(pW0, pFirst);
        }
        assembly ("memory-safe") { out0 := mload(pW0) }
        stage = 4;
    }

    /// @notice Формирует подготовленные данные `sparsePreparedLoadOnly`, которые затем переиспользуются в цикле Миллера.
    function sparsePreparedLoadOnly(
        bytes calldata dblSparse,
        bytes calldata addSparse
    ) internal pure returns (uint256 acc) {
        require(dblSparse.length == FIXED_DBL_SPARSE_BYTES, "bad dbl sparse");
        require(addSparse.length == FIXED_ADD_SPARSE_BYTES, "bad add sparse");
        bytes memory loop = ATE_LOOP_ENC;

        uint256 pD0 = _allocWords(6);
        uint256 pD1 = _allocWords(6);
        uint256 pD2 = _allocWords(6);
        uint256 pA0 = _allocWords(6);
        uint256 pA1 = _allocWords(6);

        uint256 dOff;
        uint256 aOff;
        for (uint256 i = 1; i < loop.length; ++i) {
            dOff = _loadSparseDblStepCalldataToPtr(pD0, dblSparse, dOff);
            assembly ("memory-safe") {
                acc := xor(acc, mload(pD0))
                acc := xor(acc, mload(add(pD1, 0x20)))
                acc := xor(acc, mload(add(pD2, 0x40)))
            }

            int8 bit = _decodeLoopMem(loop, i);
            if (bit == 0) continue;

            aOff = _loadSparseAddStepCalldataToPtr(pA0, addSparse, aOff);
            assembly ("memory-safe") {
                acc := xor(acc, mload(pA0))
                acc := xor(acc, mload(add(pA1, 0x20)))
            }
        }

        if (ATE_IS_LOOP_COUNT_NEG) {
            aOff = _loadSparseAddStepCalldataToPtr(pA0, addSparse, aOff);
            assembly ("memory-safe") {
                acc := xor(acc, mload(add(pA0, 0x40)))
                acc := xor(acc, mload(add(pA1, 0x60)))
            }
        }
    }

    /// @notice Формирует подготовленные данные `sparsePreparedLoadOnlyMem`, которые затем переиспользуются в цикле Миллера.
    function sparsePreparedLoadOnlyMem(
        bytes memory dblSparse,
        bytes memory addSparse
    ) internal pure returns (uint256 acc) {
        require(dblSparse.length == FIXED_DBL_SPARSE_BYTES, "bad dbl sparse");
        require(addSparse.length == FIXED_ADD_SPARSE_BYTES, "bad add sparse");
        bytes memory loop = ATE_LOOP_ENC;

        uint256 pD0 = _allocWords(6);
        uint256 pD1 = _allocWords(6);
        uint256 pD2 = _allocWords(6);
        uint256 pA0 = _allocWords(6);
        uint256 pA1 = _allocWords(6);

        uint256 dOff;
        uint256 aOff;
        for (uint256 i = 1; i < loop.length; ++i) {
            dOff = _loadSparseDblStepMemoryToPtr(pD0, dblSparse, dOff);
            assembly ("memory-safe") {
                acc := xor(acc, mload(pD0))
                acc := xor(acc, mload(add(pD1, 0x20)))
                acc := xor(acc, mload(add(pD2, 0x40)))
            }

            int8 bit = _decodeLoopMem(loop, i);
            if (bit == 0) continue;

            aOff = _loadSparseAddStepMemoryToPtr(pA0, addSparse, aOff);
            assembly ("memory-safe") {
                acc := xor(acc, mload(pA0))
                acc := xor(acc, mload(add(pA1, 0x20)))
            }
        }

        if (ATE_IS_LOOP_COUNT_NEG) {
            aOff = _loadSparseAddStepMemoryToPtr(pA0, addSparse, aOff);
            assembly ("memory-safe") {
                acc := xor(acc, mload(add(pA0, 0x40)))
                acc := xor(acc, mload(add(pA1, 0x60)))
            }
        }
    }

    /// @notice Формирует подготовленные данные `_sparsePreparedLineEvalOnlyBoundedTo`, которые затем переиспользуются в цикле Миллера.
    function _sparsePreparedLineEvalOnlyBoundedTo(
        uint256 outEll0Ptr,
        uint256 outEll1Ptr,
        G1Affine memory p,
        bytes calldata dblSparse,
        bytes calldata addSparse,
        uint256 rounds
    ) private pure {
        require(dblSparse.length == FIXED_DBL_SPARSE_BYTES, "bad dbl sparse");
        require(addSparse.length == FIXED_ADD_SPARSE_BYTES, "bad add sparse");
        bytes memory loop = ATE_LOOP_ENC;
        (uint256 pQxOverTwist, uint256 pQyOverTwist, uint256 pQyOverTwistNeg) = _fixedQOverTwistPtrs();
        uint256 pPx = _ptrFp3(p.x);
        uint256 pPy = _ptrFp3(p.y);

        uint256 arena = _allocWords(66);
        uint256 pD0 = arena;
        uint256 pD1 = pD0 + 6 * WORD;
        uint256 pD2 = pD1 + 6 * WORD;
        uint256 pA0 = pD2 + 6 * WORD;
        uint256 pA1 = pA0 + 6 * WORD;
        uint256 pT0 = pA1 + 6 * WORD;
        uint256 pT1 = pT0 + 6 * WORD;
        uint256 pL1Coeff = pT1 + 6 * WORD;
        uint256 pScratchFq2 = pL1Coeff + 6 * WORD;

        _buildL1CoeffFromPxPtrTo(pL1Coeff, pPx, pQxOverTwist);
        assembly ("memory-safe") {
            mstore(outEll0Ptr, 0)
            mstore(add(outEll0Ptr, 0x20), 0)
            mstore(add(outEll0Ptr, 0x40), 0)
            mstore(add(outEll0Ptr, 0x60), 0)
            mstore(add(outEll0Ptr, 0x80), 0)
            mstore(add(outEll0Ptr, 0xa0), 0)
            mstore(outEll1Ptr, 0)
            mstore(add(outEll1Ptr, 0x20), 0)
            mstore(add(outEll1Ptr, 0x40), 0)
            mstore(add(outEll1Ptr, 0x60), 0)
            mstore(add(outEll1Ptr, 0x80), 0)
            mstore(add(outEll1Ptr, 0xa0), 0)
        }

        uint256 effRounds = rounds;
        uint256 maxRounds = loop.length - 1;
        if (effRounds > maxRounds) {
            effRounds = maxRounds;
        }
        uint256 limit = effRounds + 1;

        uint256 dOff;
        uint256 aOff;
        for (uint256 i = 1; i < limit; ++i) {
            dOff = _loadSparseDblStepCalldataToPtr(pD0, dblSparse, dOff);
            _lineDoubleSparsePtrTo(outEll0Ptr, outEll1Ptr, pT0, pD0, pD1, pD2, pPx, pPy, pScratchFq2);

            int8 bit = _decodeLoopMem(loop, i);
            if (bit == 0) continue;

            aOff = _loadSparseAddStepCalldataToPtr(pA0, addSparse, aOff);
            _lineAddSparsePtrTo(
                outEll0Ptr,
                outEll1Ptr,
                pT0,
                pT1,
                pA0,
                pA1,
                pL1Coeff,
                bit == 1 ? pQyOverTwist : pQyOverTwistNeg,
                pPy,
                pScratchFq2
            );
        }

        if (ATE_IS_LOOP_COUNT_NEG && limit == loop.length) {
            aOff = _loadSparseAddStepCalldataToPtr(pA0, addSparse, aOff);
            _lineAddSparsePtrTo(outEll0Ptr, outEll1Ptr, pT0, pT1, pA0, pA1, pL1Coeff, pQyOverTwist, pPy, pScratchFq2);
        }
    }

    /// @notice Формирует подготовленные данные `_sparsePreparedLineEvalOnlyBoundedMemTo`, которые затем переиспользуются в цикле Миллера.
    function _sparsePreparedLineEvalOnlyBoundedMemTo(
        uint256 outEll0Ptr,
        uint256 outEll1Ptr,
        G1Affine memory p,
        bytes memory dblSparse,
        bytes memory addSparse,
        uint256 rounds
    ) private pure {
        require(dblSparse.length == FIXED_DBL_SPARSE_BYTES, "bad dbl sparse");
        require(addSparse.length == FIXED_ADD_SPARSE_BYTES, "bad add sparse");
        bytes memory loop = ATE_LOOP_ENC;
        (uint256 pQxOverTwist, uint256 pQyOverTwist, uint256 pQyOverTwistNeg) = _fixedQOverTwistPtrs();
        uint256 pPx = _ptrFp3(p.x);
        uint256 pPy = _ptrFp3(p.y);

        uint256 arena = _allocWords(66);
        uint256 pD0 = arena;
        uint256 pD1 = pD0 + 6 * WORD;
        uint256 pD2 = pD1 + 6 * WORD;
        uint256 pA0 = pD2 + 6 * WORD;
        uint256 pA1 = pA0 + 6 * WORD;
        uint256 pT0 = pA1 + 6 * WORD;
        uint256 pT1 = pT0 + 6 * WORD;
        uint256 pL1Coeff = pT1 + 6 * WORD;
        uint256 pScratchFq2 = pL1Coeff + 6 * WORD;

        _buildL1CoeffFromPxPtrTo(pL1Coeff, pPx, pQxOverTwist);
        assembly ("memory-safe") {
            mstore(outEll0Ptr, 0)
            mstore(add(outEll0Ptr, 0x20), 0)
            mstore(add(outEll0Ptr, 0x40), 0)
            mstore(add(outEll0Ptr, 0x60), 0)
            mstore(add(outEll0Ptr, 0x80), 0)
            mstore(add(outEll0Ptr, 0xa0), 0)
            mstore(outEll1Ptr, 0)
            mstore(add(outEll1Ptr, 0x20), 0)
            mstore(add(outEll1Ptr, 0x40), 0)
            mstore(add(outEll1Ptr, 0x60), 0)
            mstore(add(outEll1Ptr, 0x80), 0)
            mstore(add(outEll1Ptr, 0xa0), 0)
        }

        uint256 effRounds = rounds;
        uint256 maxRounds = loop.length - 1;
        if (effRounds > maxRounds) {
            effRounds = maxRounds;
        }
        uint256 limit = effRounds + 1;

        uint256 dOff;
        uint256 aOff;
        for (uint256 i = 1; i < limit; ++i) {
            dOff = _loadSparseDblStepMemoryToPtr(pD0, dblSparse, dOff);
            _lineDoubleSparsePtrTo(outEll0Ptr, outEll1Ptr, pT0, pD0, pD1, pD2, pPx, pPy, pScratchFq2);

            int8 bit = _decodeLoopMem(loop, i);
            if (bit == 0) continue;

            aOff = _loadSparseAddStepMemoryToPtr(pA0, addSparse, aOff);
            _lineAddSparsePtrTo(
                outEll0Ptr,
                outEll1Ptr,
                pT0,
                pT1,
                pA0,
                pA1,
                pL1Coeff,
                bit == 1 ? pQyOverTwist : pQyOverTwistNeg,
                pPy,
                pScratchFq2
            );
        }

        if (ATE_IS_LOOP_COUNT_NEG && limit == loop.length) {
            aOff = _loadSparseAddStepMemoryToPtr(pA0, addSparse, aOff);
            _lineAddSparsePtrTo(outEll0Ptr, outEll1Ptr, pT0, pT1, pA0, pA1, pL1Coeff, pQyOverTwist, pPy, pScratchFq2);
        }
    }

    /// @notice Формирует подготовленные данные `sparsePreparedLineEvalOnly`, которые затем переиспользуются в цикле Миллера.
    function sparsePreparedLineEvalOnly(
        G1Affine memory p,
        bytes calldata dblSparse,
        bytes calldata addSparse
    ) internal pure returns (MNT4ExtensionFinal.Fq2 memory ell0, MNT4ExtensionFinal.Fq2 memory ell1) {
        return sparsePreparedLineEvalOnlyBounded(p, dblSparse, addSparse, type(uint256).max);
    }

    /// @notice Формирует подготовленные данные `sparsePreparedLineEvalOnlyMem`, которые затем переиспользуются в цикле Миллера.
    function sparsePreparedLineEvalOnlyMem(
        G1Affine memory p,
        bytes memory dblSparse,
        bytes memory addSparse
    ) internal pure returns (MNT4ExtensionFinal.Fq2 memory ell0, MNT4ExtensionFinal.Fq2 memory ell1) {
        return sparsePreparedLineEvalOnlyBoundedMem(p, dblSparse, addSparse, type(uint256).max);
    }

    /// @notice Формирует подготовленные данные `sparsePreparedLineEvalOnlyBounded`, которые затем переиспользуются в цикле Миллера.
    function sparsePreparedLineEvalOnlyBounded(
        G1Affine memory p,
        bytes calldata dblSparse,
        bytes calldata addSparse,
        uint256 rounds
    ) internal pure returns (MNT4ExtensionFinal.Fq2 memory ell0, MNT4ExtensionFinal.Fq2 memory ell1) {
        ell0 = _allocFq2();
        ell1 = _allocFq2();
        _sparsePreparedLineEvalOnlyBoundedTo(_ptrFq2(ell0), _ptrFq2(ell1), p, dblSparse, addSparse, rounds);
    }

    /// @notice Формирует подготовленные данные `sparsePreparedLineEvalOnlyBoundedMem`, которые затем переиспользуются в цикле Миллера.
    function sparsePreparedLineEvalOnlyBoundedMem(
        G1Affine memory p,
        bytes memory dblSparse,
        bytes memory addSparse,
        uint256 rounds
    ) internal pure returns (MNT4ExtensionFinal.Fq2 memory ell0, MNT4ExtensionFinal.Fq2 memory ell1) {
        ell0 = _allocFq2();
        ell1 = _allocFq2();
        _sparsePreparedLineEvalOnlyBoundedMemTo(_ptrFq2(ell0), _ptrFq2(ell1), p, dblSparse, addSparse, rounds);
    }

    /// @notice Формирует подготовленные данные `sparsePreparedLineEvalOnlyBoundedMemWord`, которые затем переиспользуются в цикле Миллера.
    function sparsePreparedLineEvalOnlyBoundedMemWord(
        G1Affine memory p,
        bytes memory dblSparse,
        bytes memory addSparse,
        uint256 rounds
    ) internal pure returns (uint256 ell0x0, uint256 ell1x0) {
        uint256 pEll0 = _allocWords(6);
        uint256 pEll1 = _allocWords(6);
        _sparsePreparedLineEvalOnlyBoundedMemTo(pEll0, pEll1, p, dblSparse, addSparse, rounds);
        assembly ("memory-safe") {
            ell0x0 := mload(pEll0)
            ell1x0 := mload(pEll1)
        }
    }

    /// @notice Формирует подготовленные данные `_sparsePreparedMulByLineOnlyBoundedTo`, которые затем переиспользуются в цикле Миллера.
    function _sparsePreparedMulByLineOnlyBoundedTo(
        uint256 outFPtr,
        bytes calldata dblSparse,
        uint256 rounds
    ) private pure {
        require(dblSparse.length == FIXED_DBL_SPARSE_BYTES, "bad dbl sparse");
        bytes memory loop = ATE_LOOP_ENC;

        _setFq4OnePtr(outFPtr);

        uint256 arena = _allocWords(132);
        uint256 pTmp = arena;
        uint256 pL0 = pTmp + 12 * WORD;
        uint256 pL1 = pL0 + 6 * WORD;
        uint256 pScratchSqr = pL1 + 6 * WORD;
        uint256 pScratchMulByLine = pScratchSqr + 54 * WORD;

        _loadFq2BytesCalldataToPtr(pL0, dblSparse, 0);
        _loadFq2BytesCalldataToPtr(pL1, dblSparse, FQ2_BYTES);

        uint256 effRounds = rounds;
        uint256 maxRounds = loop.length - 1;
        if (effRounds > maxRounds) {
            effRounds = maxRounds;
        }
        uint256 limit = effRounds + 1;

        for (uint256 i = 1; i < limit; ++i) {
            MNT4Extension.fq4SqrTo(pTmp, outFPtr, pScratchSqr);
            _fq4MulByLinePtrTo(outFPtr, pTmp, pL0, pL1, pScratchMulByLine);

            int8 bit = _decodeLoopMem(loop, i);
            if (bit != 0) {
                _fq4MulByLinePtrTo(pTmp, outFPtr, pL0, pL1, pScratchMulByLine);
                _copyFq4Ptr(outFPtr, pTmp);
            }
        }

        if (ATE_IS_LOOP_COUNT_NEG && limit == loop.length) {
            _fq4MulByLinePtrTo(pTmp, outFPtr, pL0, pL1, pScratchMulByLine);
            _copyFq4Ptr(outFPtr, pTmp);
        }
    }

    /// @notice Формирует подготовленные данные `_sparsePreparedMulByLineOnlyBoundedMemTo`, которые затем переиспользуются в цикле Миллера.
    function _sparsePreparedMulByLineOnlyBoundedMemTo(
        uint256 outFPtr,
        bytes memory dblSparse,
        uint256 rounds
    ) private pure {
        require(dblSparse.length == FIXED_DBL_SPARSE_BYTES, "bad dbl sparse");
        bytes memory loop = ATE_LOOP_ENC;

        _setFq4OnePtr(outFPtr);

        uint256 arena = _allocWords(132);
        uint256 pTmp = arena;
        uint256 pL0 = pTmp + 12 * WORD;
        uint256 pL1 = pL0 + 6 * WORD;
        uint256 pScratchSqr = pL1 + 6 * WORD;
        uint256 pScratchMulByLine = pScratchSqr + 54 * WORD;

        _loadFq2BytesMemoryToPtr(pL0, dblSparse, 0);
        _loadFq2BytesMemoryToPtr(pL1, dblSparse, FQ2_BYTES);

        uint256 effRounds = rounds;
        uint256 maxRounds = loop.length - 1;
        if (effRounds > maxRounds) {
            effRounds = maxRounds;
        }
        uint256 limit = effRounds + 1;

        for (uint256 i = 1; i < limit; ++i) {
            MNT4Extension.fq4SqrTo(pTmp, outFPtr, pScratchSqr);
            _fq4MulByLinePtrTo(outFPtr, pTmp, pL0, pL1, pScratchMulByLine);

            int8 bit = _decodeLoopMem(loop, i);
            if (bit != 0) {
                _fq4MulByLinePtrTo(pTmp, outFPtr, pL0, pL1, pScratchMulByLine);
                _copyFq4Ptr(outFPtr, pTmp);
            }
        }

        if (ATE_IS_LOOP_COUNT_NEG && limit == loop.length) {
            _fq4MulByLinePtrTo(pTmp, outFPtr, pL0, pL1, pScratchMulByLine);
            _copyFq4Ptr(outFPtr, pTmp);
        }
    }

    /// @notice Формирует подготовленные данные `sparsePreparedMulByLineOnly`, которые затем переиспользуются в цикле Миллера.
    function sparsePreparedMulByLineOnly(
        bytes calldata dblSparse
    ) internal pure returns (MNT4ExtensionFinal.Fq4 memory f) {
        return sparsePreparedMulByLineOnlyBounded(dblSparse, type(uint256).max);
    }

    /// @notice Формирует подготовленные данные `sparsePreparedMulByLineOnlyMem`, которые затем переиспользуются в цикле Миллера.
    function sparsePreparedMulByLineOnlyMem(
        bytes memory dblSparse
    ) internal pure returns (MNT4ExtensionFinal.Fq4 memory f) {
        return sparsePreparedMulByLineOnlyBoundedMem(dblSparse, type(uint256).max);
    }

    /// @notice Формирует подготовленные данные `sparsePreparedMulByLineOnlyBounded`, которые затем переиспользуются в цикле Миллера.
    function sparsePreparedMulByLineOnlyBounded(
        bytes calldata dblSparse,
        uint256 rounds
    ) internal pure returns (MNT4ExtensionFinal.Fq4 memory f) {
        f = _allocFq4();
        _sparsePreparedMulByLineOnlyBoundedTo(_ptrFq4(f), dblSparse, rounds);
    }

    /// @notice Формирует подготовленные данные `sparsePreparedMulByLineOnlyBoundedMem`, которые затем переиспользуются в цикле Миллера.
    function sparsePreparedMulByLineOnlyBoundedMem(
        bytes memory dblSparse,
        uint256 rounds
    ) internal pure returns (MNT4ExtensionFinal.Fq4 memory f) {
        f = _allocFq4();
        _sparsePreparedMulByLineOnlyBoundedMemTo(_ptrFq4(f), dblSparse, rounds);
    }

    /// @notice Формирует подготовленные данные `sparsePreparedMulByLineOnlyBoundedMemWord`, которые затем переиспользуются в цикле Миллера.
    function sparsePreparedMulByLineOnlyBoundedMemWord(
        bytes memory dblSparse,
        uint256 rounds
    ) internal pure returns (uint256 out0) {
        uint256 pOut = _allocWords(12);
        _sparsePreparedMulByLineOnlyBoundedMemTo(pOut, dblSparse, rounds);
        assembly ("memory-safe") { out0 := mload(pOut) }
    }

    /// @notice Выполняет или проверяет этап финальной экспоненты `_finalExpFirstChunk` после цикла Миллера.
    function _finalExpFirstChunk(
        MNT4ExtensionFinal.Fq4 memory elt,
        MNT4ExtensionFinal.Fq4 memory eltInv
    ) private pure returns (MNT4ExtensionFinal.Fq4 memory) {
        return MNT4ExtensionFinal.fq4Mul(_fq4Conjugate(elt), eltInv);
    }

    /// @notice Выполняет или проверяет этап финальной экспоненты `_finalExpFirstChunkPtrTo` после цикла Миллера.
    function _finalExpFirstChunkPtrTo(
        uint256 outPtr,
        uint256 eltPtr,
        uint256 eltInvPtr
    ) private pure {
        uint256 pConj = _allocWords(12);
        // c0 = elt.c0
        assembly ("memory-safe") {
            mstore(pConj, mload(eltPtr))
            mstore(add(pConj, 0x20), mload(add(eltPtr, 0x20)))
            mstore(add(pConj, 0x40), mload(add(eltPtr, 0x40)))
            mstore(add(pConj, 0x60), mload(add(eltPtr, 0x60)))
            mstore(add(pConj, 0x80), mload(add(eltPtr, 0x80)))
            mstore(add(pConj, 0xa0), mload(add(eltPtr, 0xa0)))
        }
        // c1 = -elt.c1
        MNT4Extension.fq2NegTo(pConj + 6 * WORD, eltPtr + 6 * WORD);

        uint256 pScratch = _allocWords(54);
        MNT4Extension.fq4MulTo(outPtr, pConj, eltInvPtr, pScratch);
    }

    /// @notice Выполняет внутреннюю операцию `_expW0PtrTo`; параметры и результат используют представление текущей библиотеки.
    function _expW0PtrTo(uint256 pR, uint256 pX) private pure {
        _expW0BitPtrTo(pR, pX);
    }

    /// @notice Выполняет внутреннюю операцию `_w0AbsBit`; параметры и результат используют представление текущей библиотеки.
    function _w0AbsBit(uint256 bitIndex) private pure returns (bool) {
        if (bitIndex < 256) {
            return ((W0ABS_0 >> bitIndex) & 1) != 0;
        }
        return ((W0ABS_1 >> (bitIndex - 256)) & 1) != 0;
    }

    /// @notice Выполняет внутреннюю операцию `_expW0BitPtrTo`; параметры и результат используют представление текущей библиотеки.
    function _expW0BitPtrTo(uint256 pR, uint256 pX) private pure {
        uint256 pTmp = _allocWords(12);
        uint256 pScratchSqr = _allocWords(54);
        uint256 pScratchMul = _allocWords(54);
        bool found;

        for (uint256 pos = 256 + W0ABS_1_BITS; pos > 0; --pos) {
            bool bit = _w0AbsBit(pos - 1);
            if (found) {
                _fq4CyclotomicSquarePtrTo(pTmp, pR, pScratchSqr);
                _copyFq4Ptr(pR, pTmp);
            }
            if (bit) {
                if (!found) {
                    _copyFq4Ptr(pR, pX);
                    found = true;
                } else {
                    _fq4CyclotomicMulPtrTo(pTmp, pR, pX, pScratchMul);
                    _copyFq4Ptr(pR, pTmp);
                }
            }
        }

        if (!found) {
            _setFq4OnePtr(pR);
        }
    }

    /// @notice Выполняет внутреннюю операцию `_expW0`; параметры и результат используют представление текущей библиотеки.
    function _expW0(
        MNT4ExtensionFinal.Fq4 memory x
    ) private pure returns (MNT4ExtensionFinal.Fq4 memory r) {
        r = _allocFq4();
        _expW0PtrTo(_ptrFq4(r), _ptrFq4(x));
    }

    /// @notice Выполняет или проверяет этап финальной экспоненты `_finalExpLastChunk` после цикла Миллера.
    function _finalExpLastChunk(
        MNT4ExtensionFinal.Fq4 memory elt,
        MNT4ExtensionFinal.Fq4 memory eltInv
    ) private pure returns (MNT4ExtensionFinal.Fq4 memory) {
        MNT4ExtensionFinal.Fq4 memory w1 = _fq4Frobenius1(elt);
        MNT4ExtensionFinal.Fq4 memory w0 = W0_IS_NEG ? _expW0(eltInv) : _expW0(elt);
        return MNT4ExtensionFinal.fq4Mul(w1, w0);
    }

    /// @notice Выполняет или проверяет этап финальной экспоненты `_finalExpLastChunkPtrTo` после цикла Миллера.
    function _finalExpLastChunkPtrTo(
        uint256 outPtr,
        uint256 eltPtr,
        uint256 eltInvPtr
    ) private pure {
        uint256 pW1 = _allocWords(12);
        _fq4Frobenius1PtrTo(pW1, eltPtr);

        uint256 pW0 = _allocWords(12);
        if (W0_IS_NEG) {
            _expW0PtrTo(pW0, eltInvPtr);
        } else {
            _expW0PtrTo(pW0, eltPtr);
        }

        uint256 pScratch = _allocWords(54);
        _fq4CyclotomicMulPtrTo(outPtr, pW1, pW0, pScratch);
    }

    /// @notice Выполняет этап цикла Миллера `_finalExponentiationFromMillerPtrTo`; результат является элементом поля расширения до финальной экспоненты.
    function _finalExponentiationFromMillerPtrTo(
        uint256 outPtr,
        uint256 valuePtr,
        bool millerNeedsInverse
    ) private pure {
        uint256 pValueNorm = _allocWords(12);
        _copyFq4Ptr(pValueNorm, valuePtr);
        _normalizeFq4Ptr(pValueNorm);

        uint256 pValueInv = _fq4InvToNewPtr(pValueNorm);
        uint256 pFirst = _allocWords(12);
        _finalExpFirstChunkPtrTo(pFirst, pValueNorm, pValueInv);

        if (millerNeedsInverse) {
            MNT4Extension.fq2NegTo(pFirst + 6 * WORD, pFirst + 6 * WORD);
        }

        uint256 pFirstInv = _allocWords(12);
        _fq4ConjugatePtrTo(pFirstInv, pFirst);
        _finalExpLastChunkPtrTo(outPtr, pFirst, pFirstInv);
    }

    /// @notice Выполняет этап цикла Миллера `finalExponentiationFromMiller`; результат является элементом поля расширения до финальной экспоненты.
    function finalExponentiationFromMiller(
        MNT4ExtensionFinal.Fq4 memory value,
        bool millerNeedsInverse
    ) internal pure returns (MNT4ExtensionFinal.Fq4 memory) {
        MNT4ExtensionFinal.Fq4 memory valueInv = MNT4ExtensionFinal.fq4Inv(value);
        MNT4ExtensionFinal.Fq4 memory first = _finalExpFirstChunk(value, valueInv);
        if (millerNeedsInverse) {
            first = _fq4Conjugate(first);
        }
        MNT4ExtensionFinal.Fq4 memory firstInv = _fq4Conjugate(first);
        return _finalExpLastChunk(first, firstInv);
    }

    /// @notice Выполняет внутреннюю операцию `_fixedQGenerator`; параметры и результат используют представление текущей библиотеки.
    function _fixedQGenerator() private pure returns (G2Affine memory q) {
        q.x.c0[0] = G2_X_C0_0; q.x.c0[1] = G2_X_C0_1; q.x.c0[2] = G2_X_C0_2;
        q.x.c1[0] = G2_X_C1_0; q.x.c1[1] = G2_X_C1_1; q.x.c1[2] = G2_X_C1_2;
        q.y.c0[0] = G2_Y_C0_0; q.y.c0[1] = G2_Y_C0_1; q.y.c0[2] = G2_Y_C0_2;
        q.y.c1[0] = G2_Y_C1_0; q.y.c1[1] = G2_Y_C1_1; q.y.c1[2] = G2_Y_C1_2;
    }

    /// @notice Формирует подготовленные данные `tatePairingFixedQPreparedSparse`, которые затем переиспользуются в цикле Миллера.
    function tatePairingFixedQPreparedSparse(
        G1Affine memory p,
        bytes calldata dblSparse,
        bytes calldata addSparse
    ) internal pure returns (MNT4ExtensionFinal.Fq4 memory) {
        MNT4ExtensionFinal.Fq4 memory m = millerLoopFixedQPreparedSparseBlobNoInv(p, dblSparse, addSparse);
        return finalExponentiationFromMiller(m, ATE_IS_LOOP_COUNT_NEG);
    }

    /// @notice Формирует подготовленные данные `tatePairingFixedQPreparedSparseDigest`, которые затем переиспользуются в цикле Миллера.
    function tatePairingFixedQPreparedSparseDigest(
        G1Affine memory p,
        bytes calldata dblSparse,
        bytes calldata addSparse
    ) internal pure returns (bytes32 digest) {
        MNT4ExtensionFinal.Fq4 memory m = millerLoopFixedQPreparedSparseBlobNoInv(p, dblSparse, addSparse);
        uint256 pOut = _allocWords(12);
        _finalExponentiationFromMillerPtrTo(pOut, _ptrFq4(m), ATE_IS_LOOP_COUNT_NEG);
        _normalizeFq4PtrStrong(pOut);
        assembly ("memory-safe") { digest := keccak256(pOut, 0x180) }
    }

    /// @notice Формирует подготовленные данные `tatePairingFixedQPreparedSparseMem`, которые затем переиспользуются в цикле Миллера.
    function tatePairingFixedQPreparedSparseMem(
        G1Affine memory p,
        bytes memory dblSparse,
        bytes memory addSparse
    ) internal pure returns (MNT4ExtensionFinal.Fq4 memory out) {
        uint256 pM = _allocWords(12);
        _millerLoopFixedQPreparedSparseBlobNoInvMemTo(pM, p, dblSparse, addSparse);
        out = _allocFq4();
        _finalExponentiationFromMillerPtrTo(_ptrFq4(out), pM, ATE_IS_LOOP_COUNT_NEG);
    }

    /// @notice Формирует подготовленные данные `tatePairingFixedQPreparedSparseMemWord`, которые затем переиспользуются в цикле Миллера.
    function tatePairingFixedQPreparedSparseMemWord(
        G1Affine memory p,
        bytes memory dblSparse,
        bytes memory addSparse
    ) internal pure returns (uint256 out0) {
        uint256 pM = _allocWords(12);
        _millerLoopFixedQPreparedSparseBlobNoInvMemTo(pM, p, dblSparse, addSparse);
        uint256 pOut = _allocWords(12);
        _finalExponentiationFromMillerPtrTo(pOut, pM, ATE_IS_LOOP_COUNT_NEG);
        assembly ("memory-safe") { out0 := mload(pOut) }
    }

    /// @notice Формирует подготовленные данные `tatePairingFixedQPreparedSparseMemDigest`, которые затем переиспользуются в цикле Миллера.
    function tatePairingFixedQPreparedSparseMemDigest(
        G1Affine memory p,
        bytes memory dblSparse,
        bytes memory addSparse
    ) internal pure returns (bytes32 digest) {
        uint256 pM = _allocWords(12);
        _millerLoopFixedQPreparedSparseBlobNoInvMemTo(pM, p, dblSparse, addSparse);
        uint256 pOut = _allocWords(12);
        _finalExponentiationFromMillerPtrTo(pOut, pM, ATE_IS_LOOP_COUNT_NEG);
        _normalizeFq4PtrStrong(pOut);
        assembly ("memory-safe") { digest := keccak256(pOut, 0x180) }
    }

    /// @notice Формирует подготовленные данные `tatePairingFixedQPreparedSparseCodeShardsMem`, которые затем переиспользуются в цикле Миллера.
    function tatePairingFixedQPreparedSparseCodeShardsMem(
        G1Affine memory p,
        address[] memory dblShards,
        address[] memory addShards
    ) internal view returns (MNT4ExtensionFinal.Fq4 memory out) {
        uint256 pM = _allocWords(12);
        _millerLoopFixedQPreparedSparseCodeShardsNoInvMemTo(pM, p, dblShards, addShards);
        out = _allocFq4();
        _finalExponentiationFromMillerPtrTo(_ptrFq4(out), pM, ATE_IS_LOOP_COUNT_NEG);
    }

    /// @notice Формирует подготовленные данные `tatePairingFixedQPreparedSparseCodeShardsMemWord`, которые затем переиспользуются в цикле Миллера.
    function tatePairingFixedQPreparedSparseCodeShardsMemWord(
        G1Affine memory p,
        address[] memory dblShards,
        address[] memory addShards
    ) internal view returns (uint256 out0) {
        uint256 pM = _allocWords(12);
        _millerLoopFixedQPreparedSparseCodeShardsNoInvMemTo(pM, p, dblShards, addShards);
        uint256 pOut = _allocWords(12);
        _finalExponentiationFromMillerPtrTo(pOut, pM, ATE_IS_LOOP_COUNT_NEG);
        assembly ("memory-safe") { out0 := mload(pOut) }
    }

    /// @notice Формирует подготовленные данные `tatePairingFixedQPreparedSparseCodeShardsMemDigest`, которые затем переиспользуются в цикле Миллера.
    function tatePairingFixedQPreparedSparseCodeShardsMemDigest(
        G1Affine memory p,
        address[] memory dblShards,
        address[] memory addShards
    ) internal view returns (bytes32 digest) {
        uint256 pM = _allocWords(12);
        _millerLoopFixedQPreparedSparseCodeShardsNoInvMemTo(pM, p, dblShards, addShards);
        uint256 pOut = _allocWords(12);
        _finalExponentiationFromMillerPtrTo(pOut, pM, ATE_IS_LOOP_COUNT_NEG);
        _normalizeFq4PtrStrong(pOut);
        assembly ("memory-safe") { digest := keccak256(pOut, 0x180) }
    }

    /// @notice Формирует подготовленные данные `tateMultiPairingFixedQPreparedSparse`, которые затем переиспользуются в цикле Миллера.
    function tateMultiPairingFixedQPreparedSparse(
        G1Affine[] calldata points,
        bytes calldata dblSparse,
        bytes calldata addSparse
    ) internal pure returns (MNT4ExtensionFinal.Fq4 memory) {
        MNT4ExtensionFinal.Fq4 memory m = multiMillerLoopFixedQPreparedSparseBlobNoInv(points, dblSparse, addSparse);
        return finalExponentiationFromMiller(m, ATE_IS_LOOP_COUNT_NEG);
    }

    /// @notice Формирует подготовленные данные `tateMultiPairingFixedQPreparedSparseDigest`, которые затем переиспользуются в цикле Миллера.
    function tateMultiPairingFixedQPreparedSparseDigest(
        G1Affine[] calldata points,
        bytes calldata dblSparse,
        bytes calldata addSparse
    ) internal pure returns (bytes32 digest) {
        MNT4ExtensionFinal.Fq4 memory m = multiMillerLoopFixedQPreparedSparseBlobNoInv(points, dblSparse, addSparse);
        uint256 pOut = _allocWords(12);
        _finalExponentiationFromMillerPtrTo(pOut, _ptrFq4(m), ATE_IS_LOOP_COUNT_NEG);
        _normalizeFq4PtrStrong(pOut);
        assembly ("memory-safe") { digest := keccak256(pOut, 0x180) }
    }

    /// @notice Формирует подготовленные данные `tateMultiPairingFixedQPreparedSparseSinglesProductDigest`, которые затем переиспользуются в цикле Миллера.
    function tateMultiPairingFixedQPreparedSparseSinglesProductDigest(
        G1Affine[] calldata points,
        bytes calldata dblSparse,
        bytes calldata addSparse
    ) internal pure returns (bytes32 digest) {
        require(points.length > 0, "no points");
        G1Affine[] memory pointsMem = new G1Affine[](points.length);
        for (uint256 i = 0; i < points.length; ++i) {
            pointsMem[i] = points[i];
        }
        bytes memory dblMem = dblSparse;
        bytes memory addMem = addSparse;
        MNT4ExtensionFinal.Fq4 memory out = tateMultiPairingFixedQPreparedSparseSinglesProductMem(pointsMem, dblMem, addMem);
        uint256 pOut = _ptrFq4(out);
        _normalizeFq4PtrStrong(pOut);
        assembly ("memory-safe") { digest := keccak256(pOut, 0x180) }
    }

    /// @notice Формирует подготовленные данные `tateMultiPairingFixedQPreparedSparseMem`, которые затем переиспользуются в цикле Миллера.
    function tateMultiPairingFixedQPreparedSparseMem(
        G1Affine[] memory points,
        bytes memory dblSparse,
        bytes memory addSparse
    ) internal pure returns (MNT4ExtensionFinal.Fq4 memory out) {
        uint256 pM = _allocWords(12);
        _multiMillerLoopFixedQPreparedSparseBlobNoInvMemTo(pM, points, dblSparse, addSparse);
        out = _allocFq4();
        _finalExponentiationFromMillerPtrTo(_ptrFq4(out), pM, ATE_IS_LOOP_COUNT_NEG);
    }

    /// @notice Формирует подготовленные данные `tateMultiPairingFixedQPreparedSparseMemWord`, которые затем переиспользуются в цикле Миллера.
    function tateMultiPairingFixedQPreparedSparseMemWord(
        G1Affine[] memory points,
        bytes memory dblSparse,
        bytes memory addSparse
    ) internal pure returns (uint256 out0) {
        uint256 pM = _allocWords(12);
        _multiMillerLoopFixedQPreparedSparseBlobNoInvMemTo(pM, points, dblSparse, addSparse);
        uint256 pOut = _allocWords(12);
        _finalExponentiationFromMillerPtrTo(pOut, pM, ATE_IS_LOOP_COUNT_NEG);
        assembly ("memory-safe") { out0 := mload(pOut) }
    }

    /// @notice Формирует подготовленные данные `tateMultiPairingFixedQPreparedSparseMemDigest`, которые затем переиспользуются в цикле Миллера.
    function tateMultiPairingFixedQPreparedSparseMemDigest(
        G1Affine[] memory points,
        bytes memory dblSparse,
        bytes memory addSparse
    ) internal pure returns (bytes32 digest) {
        uint256 pM = _allocWords(12);
        _multiMillerLoopFixedQPreparedSparseBlobNoInvMemTo(pM, points, dblSparse, addSparse);
        uint256 pOut = _allocWords(12);
        _finalExponentiationFromMillerPtrTo(pOut, pM, ATE_IS_LOOP_COUNT_NEG);
        _normalizeFq4PtrStrong(pOut);
        assembly ("memory-safe") { digest := keccak256(pOut, 0x180) }
    }

    /// @notice Формирует подготовленные данные `tateMultiPairingFixedQPreparedSparseCodeShardsMem`, которые затем переиспользуются в цикле Миллера.
    function tateMultiPairingFixedQPreparedSparseCodeShardsMem(
        G1Affine[] memory points,
        address[] memory dblShards,
        address[] memory addShards
    ) internal view returns (MNT4ExtensionFinal.Fq4 memory out) {
        uint256 pM = _allocWords(12);
        _multiMillerLoopFixedQPreparedSparseCodeShardsNoInvMemTo(pM, points, dblShards, addShards);
        out = _allocFq4();
        _finalExponentiationFromMillerPtrTo(_ptrFq4(out), pM, ATE_IS_LOOP_COUNT_NEG);
    }

    /// @notice Формирует подготовленные данные `tateMultiPairingFixedQPreparedSparseCodeShardsMemWord`, которые затем переиспользуются в цикле Миллера.
    function tateMultiPairingFixedQPreparedSparseCodeShardsMemWord(
        G1Affine[] memory points,
        address[] memory dblShards,
        address[] memory addShards
    ) internal view returns (uint256 out0) {
        uint256 pM = _allocWords(12);
        _multiMillerLoopFixedQPreparedSparseCodeShardsNoInvMemTo(pM, points, dblShards, addShards);
        uint256 pOut = _allocWords(12);
        _finalExponentiationFromMillerPtrTo(pOut, pM, ATE_IS_LOOP_COUNT_NEG);
        assembly ("memory-safe") { out0 := mload(pOut) }
    }

    /// @notice Формирует подготовленные данные `tateMultiPairingFixedQPreparedSparseCodeShardsMemDigest`, которые затем переиспользуются в цикле Миллера.
    function tateMultiPairingFixedQPreparedSparseCodeShardsMemDigest(
        G1Affine[] memory points,
        address[] memory dblShards,
        address[] memory addShards
    ) internal view returns (bytes32 digest) {
        uint256 pM = _allocWords(12);
        _multiMillerLoopFixedQPreparedSparseCodeShardsNoInvMemTo(pM, points, dblShards, addShards);
        uint256 pOut = _allocWords(12);
        _finalExponentiationFromMillerPtrTo(pOut, pM, ATE_IS_LOOP_COUNT_NEG);
        _normalizeFq4PtrStrong(pOut);
        assembly ("memory-safe") { digest := keccak256(pOut, 0x180) }
    }

    /// @notice Формирует подготовленные данные `tateMultiPairingFixedQPreparedSparseSinglesProductMem`, которые затем переиспользуются в цикле Миллера.
    function tateMultiPairingFixedQPreparedSparseSinglesProductMem(
        G1Affine[] memory points,
        bytes memory dblSparse,
        bytes memory addSparse
    ) internal pure returns (MNT4ExtensionFinal.Fq4 memory out) {
        // Совместимое имя: общий цикл Миллера и одна финальная экспонента.
        return tateMultiPairingFixedQPreparedSparseMem(points, dblSparse, addSparse);
    }

    /// @notice Формирует подготовленные данные `tateMultiPairingFixedQPreparedSparseSinglesProductMemDigest`, которые затем переиспользуются в цикле Миллера.
    function tateMultiPairingFixedQPreparedSparseSinglesProductMemDigest(
        G1Affine[] memory points,
        bytes memory dblSparse,
        bytes memory addSparse
    ) internal pure returns (bytes32 digest) {
        MNT4ExtensionFinal.Fq4 memory out = tateMultiPairingFixedQPreparedSparseSinglesProductMem(points, dblSparse, addSparse);
        uint256 pOut = _ptrFq4(out);
        _normalizeFq4PtrStrong(pOut);
        assembly ("memory-safe") { digest := keccak256(pOut, 0x180) }
    }

    /// @notice Выполняет операцию сопряжения `tatePairingFixedQOnchainMem` в режиме, отраженном в названии функции.
    function tatePairingFixedQOnchainMem(
        G1Affine memory p
    ) internal pure returns (MNT4ExtensionFinal.Fq4 memory out) {
        uint256 pM = _allocWords(12);
        _millerLoopFixedQOnchainNoInvMemTo(pM, p);
        out = _allocFq4();
        _finalExponentiationFromMillerPtrTo(_ptrFq4(out), pM, ATE_IS_LOOP_COUNT_NEG);
    }

    /// @notice Выполняет операцию сопряжения `tatePairingFixedQOnchainMemWord` в режиме, отраженном в названии функции.
    function tatePairingFixedQOnchainMemWord(
        G1Affine memory p
    ) internal pure returns (uint256 out0) {
        uint256 pM = _allocWords(12);
        _millerLoopFixedQOnchainNoInvMemTo(pM, p);
        uint256 pOut = _allocWords(12);
        _finalExponentiationFromMillerPtrTo(pOut, pM, ATE_IS_LOOP_COUNT_NEG);
        assembly ("memory-safe") { out0 := mload(pOut) }
    }

    /// @notice Выполняет операцию сопряжения `tatePairingFixedQOnchainMemDigest` в режиме, отраженном в названии функции.
    function tatePairingFixedQOnchainMemDigest(
        G1Affine memory p
    ) internal pure returns (bytes32 digest) {
        uint256 pM = _allocWords(12);
        _millerLoopFixedQOnchainNoInvMemTo(pM, p);
        uint256 pOut = _allocWords(12);
        _finalExponentiationFromMillerPtrTo(pOut, pM, ATE_IS_LOOP_COUNT_NEG);
        _normalizeFq4PtrStrong(pOut);
        assembly ("memory-safe") { digest := keccak256(pOut, 0x180) }
    }

    /// @notice Выполняет операцию сопряжения `tateMultiPairingFixedQOnchainMem` в режиме, отраженном в названии функции.
    function tateMultiPairingFixedQOnchainMem(
        G1Affine[] memory points
    ) internal pure returns (MNT4ExtensionFinal.Fq4 memory out) {
        uint256 pM = _allocWords(12);
        _multiMillerLoopFixedQOnchainNoInvMemTo(pM, points);
        out = _allocFq4();
        _finalExponentiationFromMillerPtrTo(_ptrFq4(out), pM, ATE_IS_LOOP_COUNT_NEG);
    }

    /// @notice Выполняет операцию сопряжения `tateMultiPairingFixedQOnchainMemWord` в режиме, отраженном в названии функции.
    function tateMultiPairingFixedQOnchainMemWord(
        G1Affine[] memory points
    ) internal pure returns (uint256 out0) {
        uint256 pM = _allocWords(12);
        _multiMillerLoopFixedQOnchainNoInvMemTo(pM, points);
        uint256 pOut = _allocWords(12);
        _finalExponentiationFromMillerPtrTo(pOut, pM, ATE_IS_LOOP_COUNT_NEG);
        assembly ("memory-safe") { out0 := mload(pOut) }
    }

    /// @notice Выполняет операцию сопряжения `tateMultiPairingFixedQOnchainMemDigest` в режиме, отраженном в названии функции.
    function tateMultiPairingFixedQOnchainMemDigest(
        G1Affine[] memory points
    ) internal pure returns (bytes32 digest) {
        uint256 pM = _allocWords(12);
        _multiMillerLoopFixedQOnchainNoInvMemTo(pM, points);
        uint256 pOut = _allocWords(12);
        _finalExponentiationFromMillerPtrTo(pOut, pM, ATE_IS_LOOP_COUNT_NEG);
        _normalizeFq4PtrStrong(pOut);
        assembly ("memory-safe") { digest := keccak256(pOut, 0x180) }
    }

    /// @notice Выполняет операцию сопряжения `tateMultiPairingFixedQOnchainSinglesProductMem` в режиме, отраженном в названии функции.
    function tateMultiPairingFixedQOnchainSinglesProductMem(
        G1Affine[] memory points
    ) internal pure returns (MNT4ExtensionFinal.Fq4 memory out) {
        // Совместимое имя: общий цикл Миллера и одна финальная экспонента.
        return tateMultiPairingFixedQOnchainMem(points);
    }

    /// @notice Выполняет операцию сопряжения `tateMultiPairingFixedQOnchainSinglesProductMemDigest` в режиме, отраженном в названии функции.
    function tateMultiPairingFixedQOnchainSinglesProductMemDigest(
        G1Affine[] memory points
    ) internal pure returns (bytes32 digest) {
        MNT4ExtensionFinal.Fq4 memory out = tateMultiPairingFixedQOnchainSinglesProductMem(points);
        uint256 pOut = _ptrFq4(out);
        _normalizeFq4PtrStrong(pOut);
        assembly ("memory-safe") { digest := keccak256(pOut, 0x180) }
    }

    /// @notice Выполняет операцию сопряжения `tatePairingParametricQOnchainMemDigest` в режиме, отраженном в названии функции.
    function tatePairingParametricQOnchainMemDigest(
        G1Affine memory p,
        G2Affine memory q
    ) internal pure returns (bytes32 digest) {
        G1Affine[] memory one = new G1Affine[](1);
        one[0] = p;
        return tateMultiPairingParametricQOnchainMemDigest(one, q);
    }

    /// @notice Выполняет операцию сопряжения `tateMultiPairingParametricQOnchainMemDigest` в режиме, отраженном в названии функции.
    function tateMultiPairingParametricQOnchainMemDigest(
        G1Affine[] memory points,
        G2Affine memory q
    ) internal pure returns (bytes32 digest) {
        uint256 pM = _allocWords(12);
        _multiMillerLoopParametricQOnchainNoInvMemTo(pM, points, q);
        uint256 pOut = _allocWords(12);
        _finalExponentiationFromMillerPtrTo(pOut, pM, ATE_IS_LOOP_COUNT_NEG);
        _normalizeFq4PtrStrong(pOut);
        assembly ("memory-safe") { digest := keccak256(pOut, 0x180) }
    }

    /// @notice Выполняет операцию сопряжения `tateMultiPairingParametricQOnchainSinglesProductMemDigest` в режиме, отраженном в названии функции.
    function tateMultiPairingParametricQOnchainSinglesProductMemDigest(
        G1Affine[] memory points,
        G2Affine memory q
    ) internal pure returns (bytes32 digest) {
        return tateMultiPairingParametricQOnchainMemDigest(points, q);
    }

}
