use lollipop305_backend::cycle_pairing::{build_cycle_ehat_ate_residue_fixture, CycleEhatPreparedLine};
use lollipop305_backend::field_q::{Fq, Fq2, Fq6};
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

fn push_fq2(out: &mut String, x: &Fq2) {
    for limb in mont_limbs(&x.c0) {
        push_word(out, &limb);
    }
    for limb in mont_limbs(&x.c1) {
        push_word(out, &limb);
    }
}

fn push_fq6(out: &mut String, x: &Fq6) {
    push_fq2(out, &x.c0);
    push_fq2(out, &x.c1);
    push_fq2(out, &x.c2);
}

fn push_line(out: &mut String, line: &CycleEhatPreparedLine) {
    push_word(out, &BigUint::from(if line.is_double { 1u8 } else { 0u8 }));
    push_fq2(out, &line.x_coeff_w);
    push_fq2(out, &line.const_coeff);
    push_fq2(out, &line.c_vert);
}

fn main() {
    let fixture = build_cycle_ehat_ate_residue_fixture().expect("Ehat Ate/residue fixture");
    let mut hex = String::from("0x");
    push_word(&mut hex, &BigUint::from(fixture.lines.len()));
    for line in &fixture.lines {
        push_line(&mut hex, line);
    }
    push_fq2(&mut hex, &fixture.px);
    push_fq2(&mut hex, &fixture.py);
    push_fq6(&mut hex, &fixture.c);
    push_fq6(&mut hex, &fixture.f_num);
    push_fq6(&mut hex, &fixture.f_den);
    println!("{hex}");
    eprintln!(
        "lines={} c_to_p={} residue={}",
        fixture.lines.len(),
        fixture.c_to_p_equals_f,
        fixture.residue_check
    );
}
