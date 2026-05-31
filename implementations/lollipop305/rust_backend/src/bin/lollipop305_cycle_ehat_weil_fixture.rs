use lollipop305_backend::cycle_pairing::{build_cycle_ehat_weil_fixture, CycleEhatLineStep};
use lollipop305_backend::field_q::{Fq, Fq6};
use lollipop305_backend::params::modulus_q;
use num_bigint::BigUint;
use num_traits::One;

fn mont_limbs(x: &Fq) -> [BigUint; 2] {
    let q = modulus_q();
    let r = BigUint::one() << 512usize;
    let mont = (x.value() * (r % &q)) % q;
    let mask = (BigUint::one() << 256usize) - BigUint::one();
    [(&mont & &mask), (mont >> 256usize)]
}

fn push_word(out: &mut String, x: &BigUint) {
    out.push_str(&format!("{:064x}", x));
}

fn push_fq6(out: &mut String, x: &Fq6) {
    for limb in mont_limbs(&x.c0.c0) { push_word(out, &limb); }
    for limb in mont_limbs(&x.c0.c1) { push_word(out, &limb); }
    for limb in mont_limbs(&x.c1.c0) { push_word(out, &limb); }
    for limb in mont_limbs(&x.c1.c1) { push_word(out, &limb); }
    for limb in mont_limbs(&x.c2.c0) { push_word(out, &limb); }
    for limb in mont_limbs(&x.c2.c1) { push_word(out, &limb); }
}

fn push_trace(out: &mut String, steps: &[CycleEhatLineStep]) {
    push_word(out, &BigUint::from(steps.len()));
    for step in steps {
        push_word(out, &BigUint::from(if step.is_double { 1u8 } else { 0u8 }));
        push_fq6(out, &step.line_value);
    }
}

fn main() {
    let fixture = build_cycle_ehat_weil_fixture().expect("Ehat Weil fixture");
    let mut hex = String::from("0x");
    push_trace(&mut hex, &fixture.f_p_q_steps);
    push_trace(&mut hex, &fixture.f_neg_p_q_steps);
    push_trace(&mut hex, &fixture.f_q_p_steps);
    push_trace(&mut hex, &fixture.f_q_neg_p_steps);
    push_fq6(&mut hex, &fixture.lhs);
    push_fq6(&mut hex, &fixture.rhs);
    println!("{hex}");
    eprintln!("steps fP_Q={} fNegP_Q={} fQ_P={} fQ_NegP={}",
        fixture.f_p_q_steps.len(), fixture.f_neg_p_q_steps.len(), fixture.f_q_p_steps.len(), fixture.f_q_neg_p_steps.len());
}
