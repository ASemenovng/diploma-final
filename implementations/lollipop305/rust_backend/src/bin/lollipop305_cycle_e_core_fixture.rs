use lollipop305_backend::cycle_pairing::build_cycle_e_miller_core_fixture;
use lollipop305_backend::field::{Fp, Fp4};
use lollipop305_backend::params::modulus_p;
use num_bigint::BigUint;
use num_traits::One;

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
    for limb in mont_limbs(&x.c0.c0) { push_word(out, &limb); }
    for limb in mont_limbs(&x.c0.c1) { push_word(out, &limb); }
    for limb in mont_limbs(&x.c1.c0) { push_word(out, &limb); }
    for limb in mont_limbs(&x.c1.c1) { push_word(out, &limb); }
}

fn main() {
    let fixture = build_cycle_e_miller_core_fixture().expect("cycle E Miller core fixture");
    let mut hex = String::from("0x");
    push_word(&mut hex, &BigUint::from(fixture.steps.len()));
    for step in &fixture.steps {
        push_word(&mut hex, &BigUint::from(if step.is_double { 1u8 } else { 0u8 }));
        push_fp4(&mut hex, &step.line_value);
    }
    push_fp4(&mut hex, &fixture.core);
    println!("{hex}");
    eprintln!("steps={}", fixture.steps.len());
}
