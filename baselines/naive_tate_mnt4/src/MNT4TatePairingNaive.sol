// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

/// @notice Намеренно наивная Solidity-реализация для оценки исходной стоимости Tate-сопряжения MNT4-753.
/// @dev В контракте нет Yul-оптимизаций, подготовленного fixed-Q кэша, разреженных умножений
///      на линии и ускорения финальной экспоненты через Frobenius и фиксированные цепочки.
///      Сохранен только минимум многословной арифметики, необходимый для математической корректности.
contract MNT4TatePairingNaive {
    /// @dev Константа `P0` задает слово модуля поля или связанный параметр редукции.
    uint256 private constant P0 = 0x685acce9767254a4638810719ac425f0e39d54522cdd119f5e9063de245e8001;
    /// @dev Константа `P1` задает слово модуля поля или связанный параметр редукции.
    uint256 private constant P1 = 0x7fdb925e8a0ed8d99d124d9a15af79db117e776f218059db80f0da5cb537e38;
    /// @dev Константа `P2` задает слово модуля поля или связанный параметр редукции.
    uint256 private constant P2 = 0x1c4c62d92c41110229022eee2cdadb7f997505b8fafed5eb7e8f96c97d873;

    /// @dev Константа `R2_0` содержит R^2 mod p и используется для перевода в Montgomery-представление.
    uint256 private constant R2_0 = 0xa896a656a0714c7da24bea56242b3507c7d9ff8e7df03c0a84717088cfd190c8;
    /// @dev Константа `R2_1` содержит R^2 mod p и используется для перевода в Montgomery-представление.
    uint256 private constant R2_1 = 0xe03c79cac4f7ef07a8c86d4604a3b5972f47839ef88d7ce880a46659ff6f3ddf;
    /// @dev Константа `R2_2` содержит R^2 mod p и используется для перевода в Montgomery-представление.
    uint256 private constant R2_2 = 0x2a33e89cb485b081f15bcbfdacaf8e4605754c3817232505daf1f4a81245;
    /// @dev Константа `MAGIC` содержит коэффициент Montgomery-редукции: отрицательное обратное к младшему слову модуля по модулю 2^256.
    uint256 private constant MAGIC = 0x4adb7a6352a3a656d9e1947eee113b7a7fd403903e304c4cf2044cfbe45e7fff;

    /// @notice Выполняет внутреннюю операцию `fpFromUint`; параметры и результат используют представление текущей библиотеки.
    function fpFromUint(uint256 x) external pure returns (uint256[3] memory r) {
        require(x < P0, "small fixture only");
        uint256[3] memory normal = [x, uint256(0), uint256(0)];
        uint256[3] memory r2 = [R2_0, R2_1, R2_2];
        return _montMul(normal, r2);
    }

    /// @notice Переводит значение из Montgomery-представления в обычное: `fpFromMontgomery`.
    function fpFromMontgomery(uint256[3] memory a) external pure returns (uint256[3] memory r) {
        return _fromMont(a);
    }

    /// @notice Выполняет умножение `fpMul`; точный уровень поля и специальный множитель отражены в названии.
    function fpMul(uint256[3] memory a, uint256[3] memory b) external pure returns (uint256[3] memory r) {
        return _montMul(a, b);
    }

    /// @notice Выполняет внутреннюю операцию `fq2FromUint`; параметры и результат используют представление текущей библиотеки.
    function fq2FromUint(uint256 a0, uint256 a1) external pure returns (uint256[6] memory r) {
        return _fq2FromUint(a0, a1);
    }

    /// @notice Переводит значение из Montgomery-представления в обычное: `fq2FromMontgomery`.
    function fq2FromMontgomery(uint256[6] memory a) external pure returns (uint256[6] memory r) {
        r = _fq2FromMont(a);
    }

    /// @notice Выполняет умножение `fq2Mul`; точный уровень поля и специальный множитель отражены в названии.
    function fq2Mul(uint256[6] memory a, uint256[6] memory b) external pure returns (uint256[6] memory r) {
        return _fq2Mul(a, b);
    }

    /// @notice Выполняет внутреннюю операцию `fq4SeedA`; параметры и результат используют представление текущей библиотеки.
    function fq4SeedA() external pure returns (uint256[12] memory r) {
        return _fq4FromUint(2, 3, 5, 7);
    }

    /// @notice Выполняет внутреннюю операцию `fq4SeedB`; параметры и результат используют представление текущей библиотеки.
    function fq4SeedB() external pure returns (uint256[12] memory r) {
        return _fq4FromUint(11, 13, 17, 19);
    }

    /// @notice Выполняет умножение `fq4Mul`; точный уровень поля и специальный множитель отражены в названии.
    function fq4Mul(uint256[12] memory a, uint256[12] memory b) external pure returns (uint256[12] memory r) {
        return _fq4Mul(a, b);
    }

    /// @notice Возводит значение в квадрат: `fq4Sqr`.
    function fq4Sqr(uint256[12] memory a) external pure returns (uint256[12] memory r) {
        return _fq4Sqr(a);
    }

    /// @notice Выполняет этап цикла Миллера `naiveMillerStep`; результат является элементом поля расширения до финальной экспоненты.
    function naiveMillerStep(uint256[12] memory f, uint256[12] memory line) external pure returns (uint256[12] memory r) {
        return _naiveMillerStep(f, line);
    }

    /// @notice Выполняет умножение `benchFq4MulOnce`; точный уровень поля и специальный множитель отражены в названии.
    function benchFq4MulOnce() external pure returns (bytes32 digest) {
        uint256[12] memory a = _fq4FromUint(2, 3, 5, 7);
        uint256[12] memory b = _fq4FromUint(11, 13, 17, 19);
        return keccak256(abi.encode(_fq4Mul(a, b)));
    }

    /// @notice Возводит значение в квадрат: `benchFq4SqrOnce`.
    function benchFq4SqrOnce() external pure returns (bytes32 digest) {
        uint256[12] memory a = _fq4FromUint(2, 3, 5, 7);
        return keccak256(abi.encode(_fq4Sqr(a)));
    }

    /// @notice Выполняет этап цикла Миллера `benchNaiveMillerSteps`; результат является элементом поля расширения до финальной экспоненты.
    function benchNaiveMillerSteps(uint256 n) external pure returns (bytes32 digest) {
        require(n <= 8, "benchmark guard");
        uint256[12] memory f = _fq4FromUint(2, 3, 5, 7);
        uint256[12] memory line = _fq4FromUint(11, 13, 17, 19);
        for (uint256 i = 0; i < n; i++) {
            f = _naiveMillerStep(f, line);
        }
        return keccak256(abi.encode(f));
    }

    /// @notice Naive binary exponentiation fragment over 16 bits.
    /// @dev The full final exponent is intentionally not executed here; it is extrapolated from this generic fragment.
    function benchNaiveFinalExponentiationChunk16() external pure returns (bytes32 digest) {
        uint256[12] memory x = _fq4FromUint(2, 3, 5, 7);
        uint256[12] memory acc = _fq4One();
        uint16 e = 0xb6db;
        for (uint256 i = 0; i < 16; i++) {
            acc = _fq4Sqr(acc);
            if (((uint256(e) >> (15 - i)) & 1) != 0) {
                acc = _fq4Mul(acc, x);
            }
        }
        return keccak256(abi.encode(acc));
    }

    /// @notice Выполняет внутреннюю операцию `_fpFromUint`; параметры и результат используют представление текущей библиотеки.
    function _fpFromUint(uint256 x) private pure returns (uint256[3] memory r) {
        require(x < P0, "small fixture only");
        uint256[3] memory normal = [x, uint256(0), uint256(0)];
        uint256[3] memory r2 = [R2_0, R2_1, R2_2];
        r = _montMul(normal, r2);
    }

    /// @notice Переводит значение из Montgomery-представления в обычное: `_fromMont`.
    function _fromMont(uint256[3] memory a) private pure returns (uint256[3] memory r) {
        uint256[3] memory one = [uint256(1), uint256(0), uint256(0)];
        r = _montMul(a, one);
    }

    /// @notice Выполняет внутреннюю операцию `_fq2FromUint`; параметры и результат используют представление текущей библиотеки.
    function _fq2FromUint(uint256 a0, uint256 a1) private pure returns (uint256[6] memory r) {
        uint256[3] memory x0 = _fpFromUint(a0);
        uint256[3] memory x1 = _fpFromUint(a1);
        _storeFp2(r, 0, x0);
        _storeFp2(r, 3, x1);
    }

    /// @notice Переводит значение из Montgomery-представления в обычное: `_fq2FromMont`.
    function _fq2FromMont(uint256[6] memory a) private pure returns (uint256[6] memory r) {
        _storeFp2(r, 0, _fromMont(_loadFp2(a, 0)));
        _storeFp2(r, 3, _fromMont(_loadFp2(a, 3)));
    }

    /// @notice Выполняет внутреннюю операцию `_fq4FromUint`; параметры и результат используют представление текущей библиотеки.
    function _fq4FromUint(uint256 a0, uint256 a1, uint256 a2, uint256 a3) private pure returns (uint256[12] memory r) {
        uint256[6] memory c0 = _fq2FromUint(a0, a1);
        uint256[6] memory c1 = _fq2FromUint(a2, a3);
        _storeFq4Fq2(r, 0, c0);
        _storeFq4Fq2(r, 6, c1);
    }

    /// @notice Возвращает единичный элемент в используемом представлении: `_fq4One`.
    function _fq4One() private pure returns (uint256[12] memory r) {
        uint256[3] memory one = _fpFromUint(1);
        r[0] = one[0];
        r[1] = one[1];
        r[2] = one[2];
    }

    /// @notice Выполняет этап цикла Миллера `_naiveMillerStep`; результат является элементом поля расширения до финальной экспоненты.
    function _naiveMillerStep(uint256[12] memory f, uint256[12] memory line) private pure returns (uint256[12] memory r) {
        r = _fq4Mul(_fq4Sqr(f), line);
    }

    // Fq2=Fq[u]/(u^2-13). Намеренно используется общая школьная формула без Karatsuba-оптимизации.
    function _fq2Mul(uint256[6] memory a, uint256[6] memory b) private pure returns (uint256[6] memory r) {
        uint256[3] memory a0 = _loadFp2(a, 0);
        uint256[3] memory a1 = _loadFp2(a, 3);
        uint256[3] memory b0 = _loadFp2(b, 0);
        uint256[3] memory b1 = _loadFp2(b, 3);

        uint256[3] memory t00 = _montMul(a0, b0);
        uint256[3] memory t01 = _montMul(a0, b1);
        uint256[3] memory t10 = _montMul(a1, b0);
        uint256[3] memory t11 = _montMul(a1, b1);
        uint256[3] memory c0 = _fpAdd(t00, _fpMulBy13Naive(t11));
        uint256[3] memory c1 = _fpAdd(t01, t10);
        _storeFp2(r, 0, c0);
        _storeFp2(r, 3, c1);
    }

    /// @notice Возводит значение в квадрат: `_fq2Sqr`.
    function _fq2Sqr(uint256[6] memory a) private pure returns (uint256[6] memory r) {
        return _fq2Mul(a, a);
    }

    /// @notice Выполняет сложение `_fq2Add` с учетом модуля или структуры текущего поля.
    function _fq2Add(uint256[6] memory a, uint256[6] memory b) private pure returns (uint256[6] memory r) {
        _storeFp2(r, 0, _fpAdd(_loadFp2(a, 0), _loadFp2(b, 0)));
        _storeFp2(r, 3, _fpAdd(_loadFp2(a, 3), _loadFp2(b, 3)));
    }

    /// @notice Выполняет вычитание `_fq2Sub` с учетом модуля или структуры текущего поля.
    function _fq2Sub(uint256[6] memory a, uint256[6] memory b) private pure returns (uint256[6] memory r) {
        _storeFp2(r, 0, _fpSub(_loadFp2(a, 0), _loadFp2(b, 0)));
        _storeFp2(r, 3, _fpSub(_loadFp2(a, 3), _loadFp2(b, 3)));
    }

    /// @notice Выполняет умножение `_fq2MulByU`; точный уровень поля и специальный множитель отражены в названии.
    function _fq2MulByU(uint256[6] memory x) private pure returns (uint256[6] memory r) {
        _storeFp2(r, 0, _fpMulBy13Naive(_loadFp2(x, 3)));
        _storeFp2(r, 3, _loadFp2(x, 0));
    }

    // Fq4=Fq2[v]/(v^2-u). Намеренно используется общее школьное умножение без разреженных формул.
    function _fq4Mul(uint256[12] memory a, uint256[12] memory b) private pure returns (uint256[12] memory r) {
        uint256[6] memory a0 = _loadFq4Fq2(a, 0);
        uint256[6] memory a1 = _loadFq4Fq2(a, 6);
        uint256[6] memory b0 = _loadFq4Fq2(b, 0);
        uint256[6] memory b1 = _loadFq4Fq2(b, 6);

        uint256[6] memory t00 = _fq2Mul(a0, b0);
        uint256[6] memory t01 = _fq2Mul(a0, b1);
        uint256[6] memory t10 = _fq2Mul(a1, b0);
        uint256[6] memory t11 = _fq2Mul(a1, b1);
        uint256[6] memory c0 = _fq2Add(t00, _fq2MulByU(t11));
        uint256[6] memory c1 = _fq2Add(t01, t10);
        _storeFq4Fq2(r, 0, c0);
        _storeFq4Fq2(r, 6, c1);
    }

    /// @notice Возводит значение в квадрат: `_fq4Sqr`.
    function _fq4Sqr(uint256[12] memory a) private pure returns (uint256[12] memory r) {
        return _fq4Mul(a, a);
    }

    /// @notice Выполняет умножение `_fpMulBy13Naive`; точный уровень поля и специальный множитель отражены в названии.
    function _fpMulBy13Naive(uint256[3] memory a) private pure returns (uint256[3] memory r) {
        uint256[3] memory thirteen = _fpFromUint(13);
        r = _montMul(a, thirteen);
    }

    /// @notice Выполняет умножение `_montMul`; точный уровень поля и специальный множитель отражены в названии.
    function _montMul(uint256[3] memory a, uint256[3] memory b) private pure returns (uint256[3] memory r) {
        uint256[6] memory t;
        uint256[3] memory p = [P0, P1, P2];
        for (uint256 i = 0; i < 3; i++) {
            for (uint256 j = 0; j < 3; j++) {
                _addMulAt(t, j, a[j], b[i]);
            }
            uint256 m;
            unchecked { m = t[0] * MAGIC; }
            for (uint256 j = 0; j < 3; j++) {
                _addMulAt(t, j, m, p[j]);
            }
            _shiftRightOneLimb(t);
        }
        r = [t[0], t[1], t[2]];
        if (_ge(r, p)) {
            r = _subRaw(r, p);
        }
    }

    /// @notice Выполняет умножение `_addMulAt`; точный уровень поля и специальный множитель отражены в названии.
    function _addMulAt(uint256[6] memory t, uint256 idx, uint256 x, uint256 y) private pure {
        (uint256 lo, uint256 hi) = _mul512(x, y);
        uint256 carry = _addAt(t, idx, lo);
        unchecked {
            uint256 highWithCarry = hi + carry;
            uint256 overflowCarry = highWithCarry < hi ? 1 : 0;
            carry = _addAt(t, idx + 1, highWithCarry) + overflowCarry;
            idx += 2;
            while (carry != 0 && idx < 6) {
                carry = _addAt(t, idx, carry);
                idx++;
            }
        }
    }

    /// @notice Выполняет умножение `_mul512`; точный уровень поля и специальный множитель отражены в названии.
    function _mul512(uint256 x, uint256 y) private pure returns (uint256 lo, uint256 hi) {
        unchecked {
            lo = x * y;
            uint256 mm = mulmod(x, y, type(uint256).max);
            hi = mm - lo;
            if (mm < lo) hi -= 1;
        }
    }

    /// @notice Выполняет сложение `_addAt` с учетом модуля или структуры текущего поля.
    function _addAt(uint256[6] memory t, uint256 idx, uint256 value) private pure returns (uint256 carry) {
        unchecked {
            uint256 old = t[idx];
            uint256 next = old + value;
            t[idx] = next;
            return next < old ? 1 : 0;
        }
    }

    /// @notice Возвращает единичный элемент в используемом представлении: `_shiftRightOneLimb`.
    function _shiftRightOneLimb(uint256[6] memory t) private pure {
        t[0] = t[1];
        t[1] = t[2];
        t[2] = t[3];
        t[3] = t[4];
        t[4] = t[5];
        t[5] = 0;
    }

    /// @notice Выполняет сложение `_fpAdd` с учетом модуля или структуры текущего поля.
    function _fpAdd(uint256[3] memory a, uint256[3] memory b) private pure returns (uint256[3] memory r) {
        unchecked {
            uint256 c;
            (r[0], c) = _addCarry(a[0], b[0], 0);
            (r[1], c) = _addCarry(a[1], b[1], c);
            (r[2], c) = _addCarry(a[2], b[2], c);
            uint256[3] memory p = [P0, P1, P2];
            if (c != 0 || _ge(r, p)) r = _subRaw(r, p);
        }
    }

    /// @notice Выполняет вычитание `_fpSub` с учетом модуля или структуры текущего поля.
    function _fpSub(uint256[3] memory a, uint256[3] memory b) private pure returns (uint256[3] memory r) {
        unchecked {
            uint256 borrow;
            (r[0], borrow) = _subBorrow(a[0], b[0], 0);
            (r[1], borrow) = _subBorrow(a[1], b[1], borrow);
            (r[2], borrow) = _subBorrow(a[2], b[2], borrow);
            if (borrow != 0) {
                uint256 carry;
                (r[0], carry) = _addCarry(r[0], P0, 0);
                (r[1], carry) = _addCarry(r[1], P1, carry);
                (r[2], carry) = _addCarry(r[2], P2, carry);
            }
        }
    }

    /// @notice Выполняет вычитание `_subRaw` с учетом модуля или структуры текущего поля.
    function _subRaw(uint256[3] memory a, uint256[3] memory b) private pure returns (uint256[3] memory r) {
        uint256 borrow;
        (r[0], borrow) = _subBorrow(a[0], b[0], 0);
        (r[1], borrow) = _subBorrow(a[1], b[1], borrow);
        (r[2], borrow) = _subBorrow(a[2], b[2], borrow);
    }

    /// @notice Выполняет сложение `_addCarry` с учетом модуля или структуры текущего поля.
    function _addCarry(uint256 x, uint256 y, uint256 carryIn) private pure returns (uint256 z, uint256 carryOut) {
        unchecked {
            uint256 s = x + y;
            uint256 c1 = s < x ? 1 : 0;
            z = s + carryIn;
            uint256 c2 = z < s ? 1 : 0;
            carryOut = c1 | c2;
        }
    }

    /// @notice Выполняет вычитание `_subBorrow` с учетом модуля или структуры текущего поля.
    function _subBorrow(uint256 x, uint256 y, uint256 borrowIn) private pure returns (uint256 z, uint256 borrowOut) {
        unchecked {
            uint256 yy = y + borrowIn;
            z = x - yy;
            borrowOut = (x < yy || yy < y) ? 1 : 0;
        }
    }

    /// @notice Выполняет внутреннюю операцию `_ge`; параметры и результат используют представление текущей библиотеки.
    function _ge(uint256[3] memory a, uint256[3] memory b) private pure returns (bool) {
        if (a[2] != b[2]) return a[2] > b[2];
        if (a[1] != b[1]) return a[1] > b[1];
        return a[0] >= b[0];
    }

    /// @notice Читает подготовленные данные из указанного источника: `_loadFp2`.
    function _loadFp2(uint256[6] memory a, uint256 off) private pure returns (uint256[3] memory r) {
        r[0] = a[off];
        r[1] = a[off + 1];
        r[2] = a[off + 2];
    }

    /// @notice Записывает подготовленное значение в целевой буфер: `_storeFp2`.
    function _storeFp2(uint256[6] memory out, uint256 off, uint256[3] memory x) private pure {
        out[off] = x[0];
        out[off + 1] = x[1];
        out[off + 2] = x[2];
    }

    /// @notice Читает подготовленные данные из указанного источника: `_loadFq4Fq2`.
    function _loadFq4Fq2(uint256[12] memory a, uint256 off) private pure returns (uint256[6] memory r) {
        for (uint256 i = 0; i < 6; i++) r[i] = a[off + i];
    }

    /// @notice Записывает подготовленное значение в целевой буфер: `_storeFq4Fq2`.
    function _storeFq4Fq2(uint256[12] memory out, uint256 off, uint256[6] memory x) private pure {
        for (uint256 i = 0; i < 6; i++) out[off + i] = x[i];
    }
}
