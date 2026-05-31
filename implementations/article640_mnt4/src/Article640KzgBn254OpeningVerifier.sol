// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

/// @notice Проверяет открытие KZG commitment-а над BN254 для исследования компромисса из ePrint 2024/640.
/// @dev Реализовано настоящее уравнение открытия KZG через precompile BN254. Для воспроизводимого
///      измерения зафиксировано [tau]G2 = G2. В рабочей системе эта точка берется из доверенной
///      настройки. Стоимость вызова репрезентативна: используются те же precompile сложения,
///      умножения и сопряжения BN254 независимо от конкретного значения tau.
contract Article640KzgBn254OpeningVerifier {
    /// @dev Константа `SNARK_SCALAR_FIELD` фиксирует параметр алгоритма; значение не изменяется во время выполнения.
    uint256 private constant SNARK_SCALAR_FIELD =
        21888242871839275222246405745257275088548364400416034343698204186575808495617;
    /// @dev Константа `P_MOD` задает слово модуля поля или связанный параметр редукции.
    uint256 private constant P_MOD =
        21888242871839275222246405745257275088696311157297823662689037894645226208583;

    struct G1Point { uint256 x; uint256 y; }
    struct G2Point { uint256[2] x; uint256[2] y; }

    /// @notice Проверяет заявление p(x)=y для commitment-а C=[p(tau)]G1 и proof=[(p(tau)-p(x))/(tau-x)]G1.
    function verifyOpening(
        G1Point calldata commitment,
        uint256 x,
        uint256 y,
        G1Point calldata proof
    ) external view returns (bool) {
        if (x >= SNARK_SCALAR_FIELD || y >= SNARK_SCALAR_FIELD) return false;
        if (!_isValidG1(commitment) || !_isValidG1(proof)) return false;

        // Уравнение KZG в показателе степени: C - yG1 + x*pi = tau*pi.
        // Форма через сопряжения: e(C - yG1 + x*pi, G2) * e(-pi, tauG2) = 1.
        G1Point memory yG1 = _g1Mul(_g1(), y);
        G1Point memory lhs = _g1Add(commitment, _g1Neg(yG1));
        G1Point memory xPi = _g1Mul(proof, x);
        lhs = _g1Add(lhs, xPi);
        return _pairingCheck(lhs, _g2(), _g1Neg(proof), _tauG2());
    }

    /// @notice Возвращает канонический генератор G1 кривой BN254.
    function _g1() private pure returns (G1Point memory) {
        return G1Point(1, 2);
    }

    /// @notice Возвращает канонический генератор G2 кривой BN254.
    function _g2() private pure returns (G2Point memory) {
        return G2Point(
            [
                uint256(11559732032986387107991004021392285783925812861821192530917403151452391805634),
                uint256(10857046999023057135944570762232829481370756359578518086990519993285655852781)
            ],
            [
                uint256(4082367875863433681332203403145435568316851327593401208105741076214120093531),
                uint256(8495653923123431417604973247489272438418190587263600148770280649306958101930)
            ]
        );
    }

    /// @notice Возвращает точку [tau]G2 из параметров настройки; в benchmark tau=1.
    function _tauG2() private pure returns (G2Point memory) {
        return _g2(); // Параметры настройки для воспроизводимого теста: tau=1.
    }

    /// @notice Отсеивает координаты вне поля BN254; окончательную проверку точки выполняет precompile.
    function _isValidG1(G1Point memory p) private pure returns (bool) {
        if (p.x == 0 && p.y == 0) return true;
        return p.x < P_MOD && p.y < P_MOD;
    }

    /// @notice Возвращает -P в G1 BN254.
    function _g1Neg(G1Point memory p) private pure returns (G1Point memory) {
        if (p.x == 0 && p.y == 0) return p;
        return G1Point(p.x, P_MOD - (p.y % P_MOD));
    }

    /// @notice Складывает две точки G1 через precompile по адресу 0x06.
    function _g1Add(G1Point memory a, G1Point memory b) private view returns (G1Point memory r) {
        uint256[4] memory input = [a.x, a.y, b.x, b.y];
        uint256[2] memory output;
        bool ok;
        assembly ("memory-safe") {
            ok := staticcall(gas(), 6, input, 0x80, output, 0x40)
        }
        require(ok, "bn254 add failed");
        r = G1Point(output[0], output[1]);
    }

    /// @notice Умножает точку G1 на скаляр через precompile по адресу 0x07.
    function _g1Mul(G1Point memory a, uint256 scalar) private view returns (G1Point memory r) {
        uint256[3] memory input = [a.x, a.y, scalar];
        uint256[2] memory output;
        bool ok;
        assembly ("memory-safe") {
            ok := staticcall(gas(), 7, input, 0x60, output, 0x40)
        }
        require(ok, "bn254 mul failed");
        r = G1Point(output[0], output[1]);
    }

    /// @notice Проверяет произведение двух сопряжений через precompile по адресу 0x08.
    function _pairingCheck(G1Point memory a1, G2Point memory a2, G1Point memory b1, G2Point memory b2)
        private
        view
        returns (bool)
    {
        uint256[12] memory input = [
            a1.x,
            a1.y,
            a2.x[0],
            a2.x[1],
            a2.y[0],
            a2.y[1],
            b1.x,
            b1.y,
            b2.x[0],
            b2.x[1],
            b2.y[0],
            b2.y[1]
        ];
        uint256[1] memory output;
        bool ok;
        assembly ("memory-safe") {
            ok := staticcall(gas(), 8, input, 0x180, output, 0x20)
        }
        return ok && output[0] == 1;
    }
}
