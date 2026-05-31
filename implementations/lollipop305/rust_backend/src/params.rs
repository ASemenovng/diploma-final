use num_bigint::{BigInt, BigUint, Sign};
use num_traits::One;

fn dec(s: &str) -> BigUint {
    BigUint::parse_bytes(s.as_bytes(), 10).expect("valid decimal constant")
}

pub fn x_parameter() -> BigUint {
    dec("8004046504391788107635887004283725454478544674")
}

pub fn modulus_p() -> BigUint {
    dec("64064760444466402482617092084437280876782408929523650941985296571943203113725143542535221603")
}

pub fn modulus_q() -> BigUint {
    dec("64064760444466402482617092084437280876782408937527697446377084679579090118008868997013766277")
}

pub fn order_r() -> BigUint {
    dec("265533234376483119496574875659819072867998144101")
}

pub fn order_r_hat() -> BigUint {
    dec("265533234376483119496575739829042558313583244851")
}

pub fn cofactor_h() -> BigUint {
    dec("241268331607910700786843106086978860074363930")
}

pub fn stick_curve_a() -> BigUint {
    dec("11875228336988574493882712067711066361723405878662955689469453989104183434229646197784790728")
}

pub fn stick_curve_b() -> BigUint {
    dec("44530775641606776770556944911003809865281631340093296710155954546346967839351469608314023792")
}

pub fn p_hex() -> String {
    format!("0x{}", modulus_p().to_str_radix(16))
}
pub fn q_hex() -> String {
    format!("0x{}", modulus_q().to_str_radix(16))
}
pub fn r_hex() -> String {
    format!("0x{}", order_r().to_str_radix(16))
}

pub fn check_relations() -> bool {
    let x = x_parameter();
    let p = modulus_p();
    let q = modulus_q();
    let r = order_r();
    p == &x * &x - &x + BigUint::one()
        && q == &x * &x + BigUint::one()
        && p.modpow(&BigUint::from(4u8), &r) == BigUint::one()
        && p.modpow(&BigUint::from(1u8), &r) != BigUint::one()
        && p.modpow(&BigUint::from(2u8), &r) != BigUint::one()
}

pub fn group_order_e_fp() -> BigUint {
    cofactor_h() * order_r()
}

pub fn trace_e_fp() -> BigUint {
    modulus_p() + BigUint::one() - group_order_e_fp()
}

pub fn group_order_e_fp4() -> BigUint {
    let p_u = modulus_p();
    let p = BigInt::from_biguint(Sign::Plus, p_u.clone());
    let t = BigInt::from_biguint(Sign::Plus, trace_e_fp());
    let s0 = BigInt::from(2u8);
    let s1 = t.clone();
    let s2 = &t * &s1 - &p * &s0;
    let s3 = &t * &s2 - &p * &s1;
    let s4 = &t * &s3 - &p * &s2;
    let n4 = BigInt::from_biguint(Sign::Plus, p_u.pow(4) + BigUint::one()) - s4;
    n4.to_biguint().expect("#E(Fp4) is positive")
}

pub fn cofactor_e_fp4_r() -> BigUint {
    group_order_e_fp4() / order_r()
}


pub fn n_q() -> BigUint {
    let x = x_parameter();
    &x * &x - BigUint::from(2u8) * &x + BigUint::from(2u8)
}

pub fn n_p() -> BigUint {
    let x = x_parameter();
    &x * &x + &x + BigUint::one()
}

pub fn cycle_e_order() -> BigUint {
    modulus_p().pow(2) + BigUint::one()
}

pub fn cycle_ehat_order() -> BigUint {
    let q = modulus_q();
    q.pow(2) - &q + BigUint::one()
}

pub fn supersingular_cycle_e_cofactor_q() -> BigUint {
    cycle_e_order() / modulus_q()
}

pub fn supersingular_cycle_ehat_cofactor_p() -> BigUint {
    cycle_ehat_order() / modulus_p()
}
