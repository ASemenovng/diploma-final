use lollipop305_backend::extension_curve::AffinePointFp4;
use lollipop305_backend::field::{Fp, Fp4};
use lollipop305_backend::miller::ate_loop_scalar;
use lollipop305_backend::pairing::{final_exponent, final_exponent_value, PreparedLineFp4};
use lollipop305_backend::params::{modulus_p, order_r};
use lollipop305_backend::twist::{sample_g1_generator, sample_g2_generator, untwist_to_fp4};
use num_bigint::{BigInt, BigUint, Sign};
use num_traits::{One, Zero};

fn modinv(a: &BigUint, m: &BigUint) -> BigUint {
    let mut t = BigInt::zero();
    let mut new_t = BigInt::one();
    let mut r = BigInt::from_biguint(Sign::Plus, m.clone());
    let mut new_r = BigInt::from_biguint(Sign::Plus, a % m);
    while new_r != BigInt::zero() {
        let q = &r / &new_r;
        let tmp_t = t - &q * &new_t;
        t = new_t;
        new_t = tmp_t;
        let tmp_r = r - q * &new_r;
        r = new_r;
        new_r = tmp_r;
    }
    if t.sign() == Sign::Minus {
        t += BigInt::from_biguint(Sign::Plus, m.clone());
    }
    t.to_biguint().expect("positive inverse")
}

fn naf_digits_lsb(scalar: &BigUint) -> Vec<i8> {
    let mut k = scalar.clone();
    let mut out = Vec::new();
    while k > BigUint::zero() {
        if (&k & BigUint::one()) == BigUint::one() {
            let rem = (&k % BigUint::from(4u8)).to_u64_digits();
            let d = if rem.first().copied().unwrap_or(0) == 1 {
                1
            } else {
                -1
            };
            out.push(d);
            if d == 1 {
                k -= BigUint::one();
            } else {
                k += BigUint::one();
            }
        } else {
            out.push(0);
        }
        k >>= 1usize;
    }
    out
}

fn mont_limbs(x: &Fp) -> [BigUint; 2] {
    let p = modulus_p();
    let r = BigUint::one() << 512usize;
    let mont = (x.value() * (r % &p)) % p;
    let mask = (BigUint::one() << 256usize) - BigUint::one();
    [(&mont & &mask), (mont >> 256usize)]
}

fn push_word(out: &mut String, x: &BigUint) {
    out.push_str(&format!("{:064x}", x));
}

fn push_fp4(out: &mut String, x: &Fp4) {
    for limb in mont_limbs(&x.c0.c0) {
        push_word(out, &limb);
    }
    for limb in mont_limbs(&x.c0.c1) {
        push_word(out, &limb);
    }
    for limb in mont_limbs(&x.c1.c0) {
        push_word(out, &limb);
    }
    for limb in mont_limbs(&x.c1.c1) {
        push_word(out, &limb);
    }
}

fn negate_eval_point(p: &AffinePointFp4) -> AffinePointFp4 {
    p.neg()
}

fn main() {
    let p = sample_g1_generator().expect("G1");
    let p4 = AffinePointFp4::from_fp_point(&p);
    let minus_p4 = negate_eval_point(&p4);
    let q_twist = sample_g2_generator().expect("G2 twist");
    let q = untwist_to_fp4(&q_twist);
    let scalar = ate_loop_scalar();
    let naf = naf_digits_lsb(&scalar);

    let mut t = q.clone();
    let mut f = Fp4::one();
    let mut combined_lines: Vec<(bool, Fp4)> = Vec::new();

    for idx in (0..naf.len() - 1).rev() {
        let dbl = PreparedLineFp4::for_double(&t).expect("double line");
        let line = dbl.evaluate(&p4).mul(&dbl.evaluate(&minus_p4));
        f = f.square().mul(&line);
        t = t.double().expect("double point");
        combined_lines.push((true, line));

        match naf[idx] {
            1 => {
                let add = PreparedLineFp4::for_add(&t, &q).expect("add line");
                let line = add.evaluate(&p4).mul(&add.evaluate(&minus_p4));
                f = f.mul(&line);
                t = t.add(&q).expect("add point");
                combined_lines.push((false, line));
            }
            -1 => {
                let sub = PreparedLineFp4::for_sub(&t, &q).expect("sub line");
                let line = sub.evaluate(&p4).mul(&sub.evaluate(&minus_p4));
                f = f.mul(&line);
                t = t.add(&q.neg()).expect("sub point");
                combined_lines.push((false, line));
            }
            0 => {}
            _ => unreachable!(),
        }
    }

    let direct = final_exponent(&f);
    assert!(direct.is_one(), "equation final exponent must be one");

    let e = final_exponent_value();
    let r = order_r();
    let r_inv_mod_e = modinv(&r, &e);
    let c = f.pow(&r_inv_mod_e);
    assert_eq!(c.pow(&r), f, "residue witness must satisfy c^r=f");
    let c_inv = c.inverse().expect("c inverse");
    assert_eq!(c.mul(&c_inv), Fp4::one(), "c inverse");

    let mut hex = String::from("0x");
    push_word(&mut hex, &BigUint::from(combined_lines.len()));
    for (is_double, line) in &combined_lines {
        push_word(&mut hex, &BigUint::from(if *is_double { 1u8 } else { 0u8 }));
        push_fp4(&mut hex, line);
    }
    push_fp4(&mut hex, &f);
    push_fp4(&mut hex, &c);
    push_fp4(&mut hex, &c_inv);
    println!("{hex}");
    eprintln!(
        "steps={}, final_exp_is_one={}, c^r=f",
        combined_lines.len(),
        direct.is_one()
    );
}
