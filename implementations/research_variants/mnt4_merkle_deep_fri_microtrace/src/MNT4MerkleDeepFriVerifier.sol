// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {MNT4DeepFriField as FF} from "./MNT4DeepFriField.sol";
import {MNT4DeepFriMerkle as Merkle} from "./MNT4DeepFriMerkle.sol";
import {MNT4DeepFriTranscript as Transcript} from "./MNT4DeepFriTranscript.sol";

/// @notice Экспериментальный on-chain verifier пошаговой MNT4-753 микротрассы через Merkle/DEEP-FRI.
/// @dev Контракт проверяет уравнение e(P,Q) * e(-R,S) = 1 для двух фиксированных точек Q,S,
///      зафиксированных косвенно через ROOT_FIXED и CONFIG_DIGEST. Он не выполняет цикл Миллера:
///      вместо этого проверяется AIR-доказательство корректности 1500 микроопераций residue-рекурсии.
///      Профили предназначены для воспроизводимого gas-эксперимента; production-стойкость требует
///      отдельного криптографического аудита security_report.json.
contract MNT4MerkleDeepFriVerifier {
    // Реальная микротрасса дополняется нулями до 2048 строк. Затем каждый
    // столбец продолжается на LDE-домен размером 32768 = 2048 * 16.
    uint256 private constant TRACE_SIZE = 2048;
    uint256 private constant LDE_SIZE = 32768;
    uint256 private constant BLOWUP = 16;

    // Число столбцов в трех таблицах, которые связываются Merkle-корнями:
    // фиксированное расписание операций, изменяемая трасса и quotient.
    uint256 private constant FIXED_COLUMNS = 17;
    uint256 private constant TRACE_COLUMNS = 4;
    uint256 private constant QUOTIENT_COLUMNS = 2;

    // После семи опубликованных FRI-слоев остается многочлен степени < 8.
    // Его восемь коэффициентов передаются напрямую в заголовке proof.
    uint256 private constant FRI_LEVELS = 7;
    uint256 private constant FINAL_COEFFICIENTS = 8;

    // Канонический элемент 753-битного поля занимает три 32-байтовых слова.
    uint256 private constant FQ_BYTES = 96;

    // CONFIG_DIGEST связывает формат proof и фиксированные параметры схемы.
    // ROOT_FIXED коммитится к подготовленным линиям для неизменных Q и S.
    bytes32 public immutable CONFIG_DIGEST;
    bytes32 public immutable ROOT_FIXED;

    // Генераторы доменов хранятся в Montgomery-представлении и используются
    // только для восстановления точек открытия и FRI-folding.
    FF.Fp private OMEGA;
    FF.Fp private ETA;
    FF.Fp private GAMMA;

    /// @notice Каноническое внешнее представление элемента Fq: слова идут от старшего к младшему.
    struct Fq {
        uint256 d2;
        uint256 d1;
        uint256 d0;
    }

    struct Fq4 {
        Fq a0;
        Fq a1;
        Fq a2;
        Fq a3;
    }

    struct G1Point {
        Fq x;
        Fq y;
    }

    /// @dev Первая часть бинарного proof. Содержит корни закоммиченных таблиц,
    ///      значения вне домена и коэффициенты последнего FRI-многочлена.
    struct Header {
        uint8 profile;
        uint8 queryCount;
        bytes32 rootTrace;
        bytes32 rootQuotient;
        bytes32 rootDeep;
        bytes32[7] rootFri;
        FF.Fp[] ood;
        FF.Fp[8] finalCoefficients;
        bytes oodRaw;
        bytes finalRaw;
        uint256 cursor;
    }

    /// @dev Обратные элементы, которые Rust-бэкенд передает для одной точки
    ///      запроса. Контракт не доверяет им и проверяет каждое произведение.
    struct Helper {
        FF.Fp xInv;
        FF.Fp xMinusZInv;
        FF.Fp xMinusOmegaZInv;
        FF.Fp negXMinusZInv;
        FF.Fp negXMinusOmegaZInv;
    }

    /// @dev Fiat--Shamir испытания, детерминированно полученные из public input
    ///      и Merkle-корней. Пользователь не может выбирать их после коммитмента.
    struct Challenges {
        FF.Fp beta;
        FF.Fp z;
        FF.Fp alpha;
        FF.Fp[8] rho;
        bytes32 querySeed;
    }

    constructor(bytes32 configDigest, bytes32 rootFixed, Fq memory omega, Fq memory eta, Fq memory gamma) {
        CONFIG_DIGEST = configDigest;
        ROOT_FIXED = rootFixed;
        OMEGA = _mont(omega);
        ETA = _mont(eta);
        GAMMA = _mont(gamma);
    }

    /// @notice Безопасная внешняя оболочка: любой некорректный proof превращается в `false`, а не в revert.
    function verifyEquationMicrotrace(G1Point calldata p, G1Point calldata r, Fq4 calldata c, Fq4 calldata cInv, bytes calldata proof)
        external
        view
        returns (bool)
    {
        try this.verifyEquationMicrotraceStrict(p, r, c, cInv, proof) returns (bool ok) {
            return ok;
        } catch {
            return false;
        }
    }

    /// @notice Строгая реализация verifier-а. Вызывается только оболочкой через self-staticcall.
    function verifyEquationMicrotraceStrict(
        G1Point calldata pCanonical,
        G1Point calldata rCanonical,
        Fq4 calldata cCanonical,
        Fq4 calldata cInvCanonical,
        bytes calldata proof
    ) external view returns (bool) {
        require(msg.sender == address(this), "self only");
        FF.Fp memory px = _mont(pCanonical.x);
        FF.Fp memory py = _mont(pCanonical.y);
        FF.Fp memory rx = _mont(rCanonical.x);
        FF.Fp memory ry = _mont(rCanonical.y);
        require(_onCurve(px, py) && _onCurve(rx, ry), "G1 curve check");
        FF.Fp4 memory c = _mont4(cCanonical);
        FF.Fp4 memory cInv = _mont4(cInvCanonical);
        require(FF.fp4Equal(FF.fp4Mul(c, cInv), FF.fp4One()), "bad c inverse");

        // Этап 1. Разобрать заголовок и восстановить непредсказуемые испытания
        // из transcript. Затем проверить quotient-отношение вне LDE-домена.
        Header memory header = _parseHeader(proof);
        require(header.profile == 1 || header.profile == 2, "bad profile");
        require(header.queryCount == (header.profile == 1 ? 32 : 128), "bad query count");
        (Challenges memory ch, uint256[] memory queries) =
            _deriveChallenges(header, pCanonical, rCanonical, cCanonical, cInvCanonical);
        require(_checkOod(header.ood, px, py, rx, ry, c, cInv, ch.beta, ch.z), "bad OOD quotient");

        // Этап 2. Прочитать вспомогательные обратные элементы и компактные
        // Merkle-multiproof для трассы, фиксированной таблицы и FRI-слоев.
        uint256 cursor = header.cursor;
        Helper[] memory helpers = new Helper[](queries.length);
        for (uint256 i; i < helpers.length; ++i) {
            (helpers[i], cursor) = _parseHelper(proof, cursor);
        }
        uint256[] memory basePositions = _basePositions(queries);
        Merkle.Section memory traceSection;
        Merkle.Section memory fixedSection;
        Merkle.Section memory quotientSection;
        Merkle.Section memory deepSection;
        (traceSection, cursor) = _parseSection(proof, cursor, basePositions, 4 * FQ_BYTES, true);
        (fixedSection, cursor) = _parseSection(proof, cursor, basePositions, 17 * FQ_BYTES, true);
        (quotientSection, cursor) = _parseSection(proof, cursor, basePositions, 2 * FQ_BYTES, true);
        (deepSection, cursor) = _parseSection(proof, cursor, basePositions, FQ_BYTES, false);
        Merkle.Section[] memory friSections = new Merkle.Section[](FRI_LEVELS);
        for (uint256 level = 1; level <= FRI_LEVELS; ++level) {
            uint256[] memory positions = _friPositions(queries, level);
            (friSections[level - 1], cursor) = _parseSection(proof, cursor, positions, FQ_BYTES, true);
        }
        require(cursor == proof.length, "proof tail");

        // Этап 3. Проверить, что раскрытые строки действительно принадлежат
        // таблицам, к которым prover зафиксировал Merkle-корни.
        require(Merkle.verify(0x01, header.rootTrace, LDE_SIZE, traceSection), "trace Merkle");
        require(Merkle.verify(0x02, ROOT_FIXED, LDE_SIZE, fixedSection), "fixed Merkle");
        require(Merkle.verify(0x03, header.rootQuotient, LDE_SIZE, quotientSection), "quotient Merkle");
        for (uint256 level; level < FRI_LEVELS; ++level) {
            require(Merkle.verify(uint8(0x11 + level), header.rootFri[level], LDE_SIZE >> (level + 1), friSections[level]), "FRI Merkle");
        }

        // Этап 4. Пересчитать DEEP-значения в выбранных точках, проверить
        // последовательные FRI-folding переходы и связать их с rootDeep.
        deepSection.payloads = _verifyQueries(
            queries, helpers, traceSection, fixedSection, quotientSection, friSections, header, ch
        );
        require(Merkle.verify(0x04, header.rootDeep, LDE_SIZE, deepSection), "deep Merkle");
        return true;
    }

    function _deriveChallenges(Header memory header, G1Point calldata p, G1Point calldata r, Fq4 calldata c, Fq4 calldata cInv)
        private
        view
        returns (Challenges memory ch, uint256[] memory queries)
    {
        // Порядок absorb/challenge обязан байт-в-байт совпадать с Rust backend.
        // Любая перестановка корней изменила бы все последующие запросы.
        Transcript.State memory transcript = Transcript.init();
        Transcript.absorb(transcript, "public", _publicBytes(header.profile, p, r, c, cInv));
        Transcript.absorb(transcript, "trace-root", abi.encodePacked(header.rootTrace));
        ch.beta = _digestFp(Transcript.challenge(transcript, "beta", 0));
        Transcript.absorb(transcript, "quotient-root", abi.encodePacked(header.rootQuotient));
        ch.z = _challengeOutside(transcript, "z");
        Transcript.absorb(transcript, "ood", header.oodRaw);
        ch.alpha = _digestFp(Transcript.challenge(transcript, "alpha", 0));
        Transcript.absorb(transcript, "deep-root", abi.encodePacked(header.rootDeep));
        for (uint256 round; round < 8; ++round) {
            ch.rho[round] = _digestFp(Transcript.challenge(transcript, string.concat("rho-", _digit(round)), 0));
            if (round < 7) {
                Transcript.absorb(transcript, string.concat("fri-root-", _digit(round + 1)), abi.encodePacked(header.rootFri[round]));
            }
        }
        Transcript.absorb(transcript, "fri-final", header.finalRaw);
        ch.querySeed = Transcript.challenge(transcript, "query-seed", 0);
        queries = _queries(ch.querySeed, header.queryCount);
    }

    function _checkOod(
        FF.Fp[] memory ood,
        FF.Fp memory px,
        FF.Fp memory py,
        FF.Fp memory rx,
        FF.Fp memory ry,
        FF.Fp4 memory c,
        FF.Fp4 memory cInv,
        FF.Fp memory beta,
        FF.Fp memory z
    ) private pure returns (bool) {
        // Проверяется полиномиальное тождество
        // quotient(z) * (z^TRACE_SIZE - 1) = AIR_numerator(z).
        // Точка z выводится из transcript и лежит вне исходного домена.
        FF.Fp[] memory traceZ = _sliceFp(ood, 0, 4);
        FF.Fp[] memory traceNext = _sliceFp(ood, 4, 4);
        FF.Fp[] memory fixedZ = _sliceFp(ood, 8, 17);
        FF.Fp memory numerator = _airNumerator(traceZ, traceNext, fixedZ, px, py, rx, ry, c, cInv, beta);
        FF.Fp memory zN = FF.powSmall(z, TRACE_SIZE);
        FF.Fp memory quotient = FF.add(ood[25], FF.mul(zN, ood[26]));
        return FF.equal(FF.mul(quotient, FF.sub(zN, FF.one())), numerator);
    }

    function _verifyQueries(
        uint256[] memory queries,
        Helper[] memory helpers,
        Merkle.Section memory traceSection,
        Merkle.Section memory fixedSection,
        Merkle.Section memory quotientSection,
        Merkle.Section[] memory friSections,
        Header memory header,
        Challenges memory ch
    ) private view returns (bytes[] memory deepPayloads) {
        // Для каждой Fiat--Shamir позиции проверяются раскрытия x и -x,
        // DEEP-композиция и цепочка FRI-folding до последнего многочлена.
        deepPayloads = new bytes[](traceSection.positions.length);
        for (uint256 i; i < queries.length; ++i) {
            FF.Fp memory x = FF.mul(GAMMA, FF.powSmall(ETA, queries[i]));
            _validateHelper(helpers[i], x, ch.z);
            uint256 plusExponent = queries[i];
            uint256 minusExponent = queries[i] + LDE_SIZE / 2;
            FF.Fp memory plus = _openedDeep(plusExponent, helpers[i].xMinusZInv, helpers[i].xMinusOmegaZInv, traceSection, fixedSection, quotientSection, header.ood, ch.alpha);
            FF.Fp memory minus = _openedDeep(minusExponent, helpers[i].negXMinusZInv, helpers[i].negXMinusOmegaZInv, traceSection, fixedSection, quotientSection, header.ood, ch.alpha);
            deepPayloads[_findPosition(traceSection.positions, _physical(plusExponent, LDE_SIZE))] = FF.toBytes(plus);
            deepPayloads[_findPosition(traceSection.positions, _physical(minusExponent, LDE_SIZE))] = FF.toBytes(minus);
            FF.Fp memory folded = _fold(plus, minus, helpers[i].xInv, ch.rho[0]);
            for (uint256 level = 1; level <= 7; ++level) {
                uint256 width = LDE_SIZE >> level;
                uint256 exponent = queries[i] % width;
                FF.Fp memory first = _openedFri(friSections[level - 1], exponent, width);
                FF.Fp memory second = _openedFri(friSections[level - 1], (exponent + width / 2) % width, width);
                FF.Fp memory positive = exponent < width / 2 ? first : second;
                FF.Fp memory negative = exponent < width / 2 ? second : first;
                require(FF.equal(folded, exponent < width / 2 ? positive : negative), "FRI link");
                FF.Fp memory xInv = FF.powSmall(helpers[i].xInv, 1 << level);
                if (exponent >= width / 2) xInv = FF.neg(xInv);
                folded = _fold(positive, negative, xInv, ch.rho[level]);
            }
            FF.Fp memory finalX = FF.powSmall(x, 256);
            require(FF.equal(folded, _evaluateFinal(header.finalCoefficients, finalX)), "FRI final");
        }
    }

    function _openedDeep(
        uint256 exponent,
        FF.Fp memory invZ,
        FF.Fp memory invOmegaZ,
        Merkle.Section memory traceSection,
        Merkle.Section memory fixedSection,
        Merkle.Section memory quotientSection,
        FF.Fp[] memory ood,
        FF.Fp memory alpha
    ) private pure returns (FF.Fp memory out) {
        uint256 position = _physical(exponent, LDE_SIZE);
        FF.Fp[] memory traceRow = _decodeRow(traceSection, position, 4);
        FF.Fp[] memory fixedRow = _decodeRow(fixedSection, position, 17);
        FF.Fp[] memory quotientRow = _decodeRow(quotientSection, position, 2);
        FF.Fp memory power = FF.one();
        for (uint256 i; i < 4; ++i) {
            out = FF.add(out, FF.mul(power, FF.mul(FF.sub(traceRow[i], ood[i]), invZ)));
            power = FF.mul(power, alpha);
        }
        for (uint256 i; i < 17; ++i) {
            out = FF.add(out, FF.mul(power, FF.mul(FF.sub(fixedRow[i], ood[8 + i]), invZ)));
            power = FF.mul(power, alpha);
        }
        for (uint256 i; i < 2; ++i) {
            out = FF.add(out, FF.mul(power, FF.mul(FF.sub(quotientRow[i], ood[25 + i]), invZ)));
            power = FF.mul(power, alpha);
        }
        for (uint256 i; i < 4; ++i) {
            out = FF.add(out, FF.mul(power, FF.mul(FF.sub(traceRow[i], ood[4 + i]), invOmegaZ)));
            power = FF.mul(power, alpha);
        }
    }

    function _airNumerator(
        FF.Fp[] memory current,
        FF.Fp[] memory next,
        FF.Fp[] memory fixedRow,
        FF.Fp memory px,
        FF.Fp memory py,
        FF.Fp memory rx,
        FF.Fp memory ry,
        FF.Fp4 memory c,
        FF.Fp4 memory cInv,
        FF.Fp memory beta
    ) private pure returns (FF.Fp memory out) {
        // fixedRow[0..8] выбирает одну допустимую микрооперацию residue-трассы:
        // квадрат, умножения на линии, c, c^-1, Frobenius(c^-1) или no-op.
        // Бета агрегирует координатные равенства в одно полевое выражение.
        FF.Fp4 memory state = _fp4(current);
        FF.Fp4[9] memory expected;
        expected[0] = FF.fp4Sqr(state);
        expected[1] = FF.fp4Mul(state, _line(fixedRow, false, px, py));
        expected[2] = FF.fp4Mul(state, _line(fixedRow, false, rx, FF.neg(ry)));
        expected[3] = FF.fp4Mul(state, _line(fixedRow, true, px, py));
        expected[4] = FF.fp4Mul(state, _line(fixedRow, true, rx, FF.neg(ry)));
        expected[5] = FF.fp4Mul(state, c);
        expected[6] = FF.fp4Mul(state, cInv);
        expected[7] = FF.fp4Mul(state, FF.fp4Frobenius(cInv));
        expected[8] = state;
        FF.Fp memory power = FF.one();
        for (uint256 op; op < 9; ++op) {
            FF.Fp[] memory candidate = _fp4Array(expected[op]);
            for (uint256 coordinate; coordinate < 4; ++coordinate) {
                out = FF.add(out, FF.mul(power, FF.mul(fixedRow[op], FF.sub(candidate[coordinate], next[coordinate]))));
                power = FF.mul(power, beta);
            }
        }
        FF.Fp[] memory cInvArray = _fp4Array(cInv);
        for (uint256 coordinate; coordinate < 4; ++coordinate) {
            out = FF.add(out, FF.mul(power, FF.mul(fixedRow[9], FF.sub(current[coordinate], cInvArray[coordinate]))));
            power = FF.mul(power, beta);
        }
        for (uint256 coordinate; coordinate < 4; ++coordinate) {
            FF.Fp memory target = coordinate == 0 ? FF.one() : FF.zero();
            out = FF.add(out, FF.mul(power, FF.mul(fixedRow[10], FF.sub(current[coordinate], target))));
            power = FF.mul(power, beta);
        }
    }

    function _line(FF.Fp[] memory row, bool addition, FF.Fp memory x, FF.Fp memory y)
        private
        pure
        returns (FF.Fp4 memory out)
    {
        if (addition) {
            out.a0 = FF.mul(row[11], y);
            out.a1 = FF.mul(row[12], y);
            out.a2 = FF.add(row[13], FF.mul(row[15], x));
            out.a3 = FF.add(row[14], FF.mul(row[16], x));
        } else {
            out.a0 = FF.add(row[11], FF.mul(row[13], x));
            out.a1 = FF.add(row[12], FF.mul(row[14], x));
            out.a2 = FF.mul(row[15], y);
            out.a3 = FF.mul(row[16], y);
        }
    }

    function _validateHelper(Helper memory helper, FF.Fp memory x, FF.Fp memory z) private view {
        FF.Fp memory omegaZ = FF.mul(OMEGA, z);
        require(FF.equal(FF.mul(x, helper.xInv), FF.one()), "x inverse");
        require(FF.equal(FF.mul(FF.sub(x, z), helper.xMinusZInv), FF.one()), "x-z inverse");
        require(FF.equal(FF.mul(FF.sub(x, omegaZ), helper.xMinusOmegaZInv), FF.one()), "x-omega*z inverse");
        require(FF.equal(FF.mul(FF.sub(FF.neg(x), z), helper.negXMinusZInv), FF.one()), "-x-z inverse");
        require(FF.equal(FF.mul(FF.sub(FF.neg(x), omegaZ), helper.negXMinusOmegaZInv), FF.one()), "-x-omega*z inverse");
    }

    function _fold(FF.Fp memory positive, FF.Fp memory negative, FF.Fp memory xInv, FF.Fp memory rho)
        private
        pure
        returns (FF.Fp memory)
    {
        // 1/2 вычисляется как (q+1)/2 в обычном поле; каноническое значение переводится в Montgomery один раз.
        FF.Fp memory twoInv = FF.fromCanonicalWords(
            0xe26316c9620888114811777166d6dbfccba82dc7d7f6af5bf47cb64bec39,
            0x83fedc92f45076c6cce8926cd0ad7bced88bf3bb790c02cedc0786d2e5a9bf1c,
            0x342d6674bb392a5231c40838cd6212f871ceaa29166e88cfaf4831ef122f4001
        );
        return FF.add(FF.mul(FF.add(positive, negative), twoInv), FF.mul(rho, FF.mul(FF.mul(FF.sub(positive, negative), twoInv), xInv)));
    }

    function _evaluateFinal(FF.Fp[8] memory coefficients, FF.Fp memory x) private pure returns (FF.Fp memory out) {
        for (uint256 i = 8; i != 0; --i) out = FF.add(FF.mul(out, x), coefficients[i - 1]);
    }

    function _parseHeader(bytes calldata proof) private pure returns (Header memory header) {
        // Бинарный формат фиксирован Rust-сериализатором: magic, version,
        // профиль, размеры доменов, Merkle-корни, OOD bundle, final polynomial.
        require(proof.length >= 3696, "short proof");
        require(_u32(proof, 0) == 0x4d344446, "bad magic");
        require(_u16(proof, 4) == 1, "bad version");
        header.profile = uint8(proof[6]);
        header.queryCount = uint8(proof[7]);
        require(_u32(proof, 8) == LDE_SIZE && _u32(proof, 12) == TRACE_SIZE, "bad domain");
        uint256 cursor = 16;
        header.rootTrace = _bytes32(proof, cursor); cursor += 32;
        header.rootQuotient = _bytes32(proof, cursor); cursor += 32;
        header.rootDeep = _bytes32(proof, cursor); cursor += 32;
        for (uint256 i; i < 7; ++i) { header.rootFri[i] = _bytes32(proof, cursor); cursor += 32; }
        uint256 oodStart = cursor;
        header.ood = new FF.Fp[](27);
        for (uint256 i; i < 27; ++i) { header.ood[i] = FF.fromBytes(proof, cursor); cursor += FQ_BYTES; }
        header.oodRaw = proof[oodStart:cursor];
        uint256 finalStart = cursor;
        for (uint256 i; i < 8; ++i) { header.finalCoefficients[i] = FF.fromBytes(proof, cursor); cursor += FQ_BYTES; }
        header.finalRaw = proof[finalStart:cursor];
        header.cursor = cursor;
    }

    function _parseHelper(bytes calldata proof, uint256 cursor) private pure returns (Helper memory helper, uint256 next) {
        helper.xInv = FF.fromBytes(proof, cursor); cursor += FQ_BYTES;
        helper.xMinusZInv = FF.fromBytes(proof, cursor); cursor += FQ_BYTES;
        helper.xMinusOmegaZInv = FF.fromBytes(proof, cursor); cursor += FQ_BYTES;
        helper.negXMinusZInv = FF.fromBytes(proof, cursor); cursor += FQ_BYTES;
        helper.negXMinusOmegaZInv = FF.fromBytes(proof, cursor); cursor += FQ_BYTES;
        next = cursor;
    }

    function _parseSection(bytes calldata proof, uint256 cursor, uint256[] memory positions, uint256 payloadBytes, bool withPayloads)
        private
        pure
        returns (Merkle.Section memory section, uint256 next)
    {
        require(_u16(proof, cursor) == positions.length, "leaf count"); cursor += 2;
        section.positions = positions;
        section.payloads = new bytes[](withPayloads ? positions.length : 0);
        if (withPayloads) {
            for (uint256 i; i < positions.length; ++i) {
                require(cursor + payloadBytes <= proof.length, "truncated leaf");
                section.payloads[i] = proof[cursor:cursor + payloadBytes];
                cursor += payloadBytes;
            }
        }
        uint256 frontierCount = _u16(proof, cursor); cursor += 2;
        section.frontier = new bytes32[](frontierCount);
        for (uint256 i; i < frontierCount; ++i) { section.frontier[i] = _bytes32(proof, cursor); cursor += 32; }
        next = cursor;
    }

    function _decodeRow(Merkle.Section memory section, uint256 position, uint256 count) private pure returns (FF.Fp[] memory row) {
        bytes memory payload = section.payloads[_findPosition(section.positions, position)];
        row = new FF.Fp[](count);
        for (uint256 i; i < count; ++i) row[i] = FF.fromMemoryBytes(payload, i * FQ_BYTES);
    }

    function _openedFri(Merkle.Section memory section, uint256 exponent, uint256 width) private pure returns (FF.Fp memory) {
        return _decodeRow(section, _physical(exponent, width), 1)[0];
    }

    function _queries(bytes32 seed, uint256 count) private pure returns (uint256[] memory out) {
        // Запросы выводятся без повторений и сразу сортируются. Благодаря этому
        // один Merkle-multiproof может дедуплицировать общие ветви дерева.
        out = new uint256[](count);
        uint256 length;
        for (uint32 counter; length < count; ++counter) {
            uint256 candidate = uint256(keccak256(abi.encodePacked(bytes1(0xD0), seed, counter))) % (LDE_SIZE / 2);
            uint256 insertion;
            while (insertion < length && out[insertion] < candidate) ++insertion;
            if (insertion < length && out[insertion] == candidate) continue;
            for (uint256 j = length; j > insertion; --j) out[j] = out[j - 1];
            out[insertion] = candidate;
            ++length;
        }
    }

    function _basePositions(uint256[] memory queries) private pure returns (uint256[] memory raw) {
        raw = new uint256[](2 * queries.length);
        for (uint256 i; i < queries.length; ++i) {
            raw[2 * i] = _physical(queries[i], LDE_SIZE);
            raw[2 * i + 1] = _physical(queries[i] + LDE_SIZE / 2, LDE_SIZE);
        }
        return _sortUnique(raw);
    }

    function _friPositions(uint256[] memory queries, uint256 level) private pure returns (uint256[] memory raw) {
        uint256 width = LDE_SIZE >> level;
        raw = new uint256[](2 * queries.length);
        for (uint256 i; i < queries.length; ++i) {
            uint256 exponent = queries[i] % width;
            raw[2 * i] = _physical(exponent, width);
            raw[2 * i + 1] = _physical((exponent + width / 2) % width, width);
        }
        return _sortUnique(raw);
    }

    function _sortUnique(uint256[] memory values) private pure returns (uint256[] memory out) {
        for (uint256 i = 1; i < values.length; ++i) {
            uint256 value = values[i];
            uint256 j = i;
            while (j != 0 && values[j - 1] > value) { values[j] = values[j - 1]; --j; }
            values[j] = value;
        }
        uint256 unique = values.length == 0 ? 0 : 1;
        for (uint256 i = 1; i < values.length; ++i) if (values[i] != values[unique - 1]) values[unique++] = values[i];
        out = new uint256[](unique);
        for (uint256 i; i < unique; ++i) out[i] = values[i];
    }

    function _physical(uint256 exponent, uint256 width) private pure returns (uint256 out) {
        // LDE-таблицы сериализованы в bit-reversed порядке, совпадающем с Rust.
        uint256 bits;
        while ((1 << bits) < width) ++bits;
        for (uint256 i; i < bits; ++i) { out = (out << 1) | (exponent & 1); exponent >>= 1; }
    }

    function _findPosition(uint256[] memory positions, uint256 needle) private pure returns (uint256) {
        for (uint256 i; i < positions.length; ++i) if (positions[i] == needle) return i;
        revert("opening missing");
    }

    function _challengeOutside(Transcript.State memory transcript, string memory label) private view returns (FF.Fp memory) {
        FF.Fp memory gammaM = FF.powSmall(GAMMA, LDE_SIZE);
        for (uint32 counter; counter != type(uint32).max; ++counter) {
            FF.Fp memory value = _digestFp(Transcript.challenge(transcript, label, counter));
            if (!FF.equal(FF.powSmall(value, TRACE_SIZE), FF.one()) && !FF.equal(FF.powSmall(value, LDE_SIZE), gammaM)) return value;
        }
        revert("challenge counter exhausted");
    }

    function _digestFp(bytes32 digest) private pure returns (FF.Fp memory) {
        return FF.fromCanonicalWords(0, 0, uint256(digest));
    }

    function _onCurve(FF.Fp memory x, FF.Fp memory y) private pure returns (bool) {
        if (FF.isZero(x) && FF.isZero(y)) return false;
        FF.Fp memory b = FF.fromCanonicalWords(
            0x1373684a8c9dcae7a016ac5d7748d3313cd8e39051c596560835df0c9e50a,
            0x5b59b882a92c78dc537e51a16703ec9855c77fc3d8bb21c8d68bb8cfb9db4b8c,
            0x8fba773111c36c8b1b4e8f1ece940ef9eaad265458e06372009c9a0491678ef4
        );
        return FF.equal(FF.sqr(y), FF.add(FF.add(FF.mul(FF.sqr(x), x), FF.mul(FF.fromUint(2), x)), b));
    }

    function _mont(Fq memory value) private pure returns (FF.Fp memory) {
        return FF.fromCanonicalWords(value.d2, value.d1, value.d0);
    }

    function _mont4(Fq4 calldata value) private pure returns (FF.Fp4 memory out) {
        out.a0 = _mont(value.a0); out.a1 = _mont(value.a1); out.a2 = _mont(value.a2); out.a3 = _mont(value.a3);
    }

    function _fp4(FF.Fp[] memory values) private pure returns (FF.Fp4 memory out) {
        out = FF.Fp4(values[0], values[1], values[2], values[3]);
    }

    function _fp4Array(FF.Fp4 memory value) private pure returns (FF.Fp[] memory out) {
        out = new FF.Fp[](4); out[0] = value.a0; out[1] = value.a1; out[2] = value.a2; out[3] = value.a3;
    }

    function _sliceFp(FF.Fp[] memory values, uint256 start, uint256 count) private pure returns (FF.Fp[] memory out) {
        out = new FF.Fp[](count); for (uint256 i; i < count; ++i) out[i] = values[start + i];
    }

    function _publicBytes(uint8 profile, G1Point calldata p, G1Point calldata r, Fq4 calldata c, Fq4 calldata cInv)
        private
        view
        returns (bytes memory)
    {
        // Эти байты входят в transcript до первого Merkle-корня. Поэтому proof
        // нельзя повторно использовать после подмены P, R, c или c^-1.
        return abi.encodePacked(
            uint16(1), profile, CONFIG_DIGEST, ROOT_FIXED,
            p.x.d2, p.x.d1, p.x.d0, p.y.d2, p.y.d1, p.y.d0,
            r.x.d2, r.x.d1, r.x.d0, r.y.d2, r.y.d1, r.y.d0,
            c.a0.d2, c.a0.d1, c.a0.d0, c.a1.d2, c.a1.d1, c.a1.d0,
            c.a2.d2, c.a2.d1, c.a2.d0, c.a3.d2, c.a3.d1, c.a3.d0,
            cInv.a0.d2, cInv.a0.d1, cInv.a0.d0, cInv.a1.d2, cInv.a1.d1, cInv.a1.d0,
            cInv.a2.d2, cInv.a2.d1, cInv.a2.d0, cInv.a3.d2, cInv.a3.d1, cInv.a3.d0
        );
    }

    function _u16(bytes calldata data, uint256 offset) private pure returns (uint16 value) {
        require(offset + 2 <= data.length, "truncated u16");
        assembly ("memory-safe") { value := shr(240, calldataload(add(data.offset, offset))) }
    }

    function _u32(bytes calldata data, uint256 offset) private pure returns (uint32 value) {
        require(offset + 4 <= data.length, "truncated u32");
        assembly ("memory-safe") { value := shr(224, calldataload(add(data.offset, offset))) }
    }

    function _bytes32(bytes calldata data, uint256 offset) private pure returns (bytes32 value) {
        require(offset + 32 <= data.length, "truncated bytes32");
        assembly ("memory-safe") { value := calldataload(add(data.offset, offset)) }
    }

    function _digit(uint256 value) private pure returns (string memory) {
        require(value < 10, "single digit");
        bytes memory out = new bytes(1); out[0] = bytes1(uint8(48 + value)); return string(out);
    }
}
