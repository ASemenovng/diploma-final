use lollipop305_backend::extension_curve::AffinePointFp4;
use lollipop305_backend::miller::ate_loop_scalar;
use lollipop305_backend::pairing::{final_exponent, miller_trace_full_fp4};
use lollipop305_backend::params::{modulus_p, order_r};
use lollipop305_backend::twist::{sample_g1_generator, sample_g2_generator, untwist_to_fp4};

fn frobenius_p_point(p: &AffinePointFp4) -> AffinePointFp4 {
    if p.is_infinity() {
        return AffinePointFp4::infinity();
    }
    let q = modulus_p();
    AffinePointFp4 {
        x: p.x.pow(&q),
        y: p.y.pow(&q),
        infinity: false,
    }
}

fn main() {
    let p = sample_g1_generator().expect("P");
    let q_tw = sample_g2_generator().expect("Q twist");
    let p4 = AffinePointFp4::from_fp_point(&p);
    let q4 = untwist_to_fp4(&q_tw);
    println!(
        "P on {}, Q on {}, rP {}, rQ {}",
        p4.is_on_stick_curve(),
        q4.is_on_stick_curve(),
        p4.scalar_mul(&order_r()).unwrap().is_infinity(),
        q4.scalar_mul(&order_r()).unwrap().is_infinity()
    );
    println!("ate scalar {}", ate_loop_scalar());
    println!(
        "ate scalar Q infinity {}",
        q4.scalar_mul(&ate_loop_scalar()).unwrap().is_infinity()
    );
    let p_mod_r = modulus_p() % order_r();
    let q_frob = frobenius_p_point(&q4);
    let q_pmul = q4.scalar_mul(&p_mod_r).expect("[p]Q");
    println!("Q frob==[p]Q {}", q_frob == q_pmul);

    match miller_trace_full_fp4(&p4, &q4, &ate_loop_scalar()) {
        Some(trace) => {
            println!("ate final_t infinity {}", trace.final_t.is_infinity());
            let ate_y = final_exponent(&trace.accumulator);
            println!(
                "ate is_one {} pow_r {}",
                ate_y.is_one(),
                ate_y.pow(&order_r()).is_one()
            );
            println!("ate_y {:?}", ate_y);
        }
        None => println!("ate trace failed"),
    }

    match miller_trace_full_fp4(&q4, &p4, &order_r()) {
        Some(trace) => {
            println!(
                "tate f_r,P(Q) final_t infinity {}",
                trace.final_t.is_infinity()
            );
            let y = final_exponent(&trace.accumulator);
            println!(
                "tate f_r,P(Q) is_one {} pow_r {}",
                y.is_one(),
                y.pow(&order_r()).is_one()
            );
            println!("tate_y_qp {:?}", y);
        }
        None => println!("tate f_r,P(Q) trace failed"),
    }

    match miller_trace_full_fp4(&p4, &q4, &order_r()) {
        Some(trace) => {
            println!(
                "tate f_r,Q(P) final_t infinity {}",
                trace.final_t.is_infinity()
            );
            let y = final_exponent(&trace.accumulator);
            println!(
                "tate f_r,Q(P) is_one {} pow_r {}",
                y.is_one(),
                y.pow(&order_r()).is_one()
            );
            println!("tate_y_pq {:?}", y);
        }
        None => println!("tate f_r,Q(P) trace failed"),
    }
}
