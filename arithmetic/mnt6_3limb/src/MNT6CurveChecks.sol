// SPDX-License-Identifier: MIT
pragma solidity 0.8.33;

import {MNT6PairingTypes} from "./MNT6PairingTypes.sol";
import {MNT6Fp} from "./MNT6Fp.sol";
import {MNT6Fq3} from "./MNT6Fq3.sol";

/// @notice Проверки принадлежности аффинных точек групп G1 и G2 кривой MNT6-753.
library MNT6CurveChecks {
    /// @notice Проверяет корректность представления или принадлежность кривой: `isOnG1`.
    function isOnG1(MNT6PairingTypes.G1Point memory p) internal pure returns (bool) {
        if (!MNT6Fp.isValid(p.x) || !MNT6Fp.isValid(p.y)) return false;
        MNT6PairingTypes.Fp memory y2 = MNT6Fp.sqr(p.y);
        MNT6PairingTypes.Fp memory x3 = MNT6Fp.mul(MNT6Fp.sqr(p.x), p.x);
        MNT6PairingTypes.Fp memory ax = MNT6Fp.mul(MNT6Fp.mulBy11(MNT6Fp.one()), p.x);
        return MNT6Fp.eq(y2, MNT6Fp.add(MNT6Fp.add(x3, ax), _g1CoeffB()));
    }

    /// @notice Проверяет корректность представления или принадлежность кривой: `isOnG2`.
    function isOnG2(MNT6PairingTypes.G2Point memory p) internal pure returns (bool) {
        if (!_fq3Valid(p.x) || !_fq3Valid(p.y)) return false;
        MNT6PairingTypes.Fq3 memory y2 = MNT6Fq3.sqr(p.y);
        MNT6PairingTypes.Fq3 memory x3 = MNT6Fq3.mul(MNT6Fq3.sqr(p.x), p.x);
        MNT6PairingTypes.Fq3 memory ax = MNT6Fq3.mul(_g2CoeffA(), p.x);
        return MNT6Fq3.eq(y2, MNT6Fq3.add(MNT6Fq3.add(x3, ax), _g2CoeffB()));
    }

    /// @notice Выполняет внутреннюю операцию `_fq3Valid`; параметры и результат используют представление текущей библиотеки.
    function _fq3Valid(MNT6PairingTypes.Fq3 memory x) private pure returns (bool) {
        return MNT6Fp.isValid(x.c0) && MNT6Fp.isValid(x.c1) && MNT6Fp.isValid(x.c2);
    }

    /// @notice Выполняет внутреннюю операцию `_g1CoeffB`; параметры и результат используют представление текущей библиотеки.
    function _g1CoeffB() private pure returns (MNT6PairingTypes.Fp memory r) {
        r = MNT6PairingTypes.Fp(
            0x00010804126ecf16f83fa70b67d17c009175a8b5ef915920fa9ac2fe4bd09711,
            0x47d8f3de65c79d1d14385d51ca5422fb2f8aca277da9258d57007df447700e3e,
            0x6fe8b22127f7f0971ff8d652bcdd2b90b08f89f10deb6f437a85e23c6984298a
        );
    }

    /// @notice Выполняет внутреннюю операцию `_g2CoeffA`; параметры и результат используют представление текущей библиотеки.
    function _g2CoeffA() private pure returns (MNT6PairingTypes.Fq3 memory r) {
        r.c2 = MNT6Fp.mulBy11(MNT6Fp.one());
    }

    /// @notice Выполняет внутреннюю операцию `_g2CoeffB`; параметры и результат используют представление текущей библиотеки.
    function _g2CoeffB() private pure returns (MNT6PairingTypes.Fq3 memory r) {
        r.c0 = MNT6PairingTypes.Fp(
            0x0000bb87b9524d9649ecccabdcaf81f3f034b3ef25e0b4da8c56eb14b6676b0b,
            0xe66023aaebce2eee43852569e97bb318dc6c86bdb42aa36f437eaa061b09b766,
            0x73bfcea77c0ff6a1571c2b24a37ed1abbe6756d13b566a072d93ef4b08adc8e8
        );
    }
}
