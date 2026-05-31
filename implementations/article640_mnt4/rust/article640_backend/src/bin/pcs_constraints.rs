use ark_bn254::Fr as Bn254Fr;
use ark_mnt4_753::{Fq as Mnt4Fq, Fq2 as Mnt4Fq2, Fq4 as Mnt4Fq4};
use ark_r1cs_std::alloc::AllocVar;
use ark_r1cs_std::eq::EqGadget;
use ark_r1cs_std::fields::emulated_fp::EmulatedFpVar;
use ark_relations::r1cs::ConstraintSystem;

fn constraints_for_fq_mul() -> usize {
    let cs = ConstraintSystem::<Bn254Fr>::new_ref();
    let a = Mnt4Fq::from(3u64);
    let b = Mnt4Fq::from(5u64);
    let c = a * b;
    let av = EmulatedFpVar::<Mnt4Fq, Bn254Fr>::new_witness(cs.clone(), || Ok(a)).unwrap();
    let bv = EmulatedFpVar::<Mnt4Fq, Bn254Fr>::new_witness(cs.clone(), || Ok(b)).unwrap();
    let cv = EmulatedFpVar::<Mnt4Fq, Bn254Fr>::new_input(cs.clone(), || Ok(c)).unwrap();
    let prod = &av * &bv;
    prod.enforce_equal(&cv).unwrap();
    assert!(cs.is_satisfied().unwrap());
    cs.num_constraints()
}

fn constraints_for_fq2_mul() -> usize {
    let cs = ConstraintSystem::<Bn254Fr>::new_ref();
    let a = Mnt4Fq2::new(Mnt4Fq::from(3u64), Mnt4Fq::from(7u64));
    let b = Mnt4Fq2::new(Mnt4Fq::from(5u64), Mnt4Fq::from(11u64));
    let c = a * b;
    let a0 = EmulatedFpVar::<Mnt4Fq, Bn254Fr>::new_witness(cs.clone(), || Ok(a.c0)).unwrap();
    let a1 = EmulatedFpVar::<Mnt4Fq, Bn254Fr>::new_witness(cs.clone(), || Ok(a.c1)).unwrap();
    let b0 = EmulatedFpVar::<Mnt4Fq, Bn254Fr>::new_witness(cs.clone(), || Ok(b.c0)).unwrap();
    let b1 = EmulatedFpVar::<Mnt4Fq, Bn254Fr>::new_witness(cs.clone(), || Ok(b.c1)).unwrap();
    let c0 = EmulatedFpVar::<Mnt4Fq, Bn254Fr>::new_input(cs.clone(), || Ok(c.c0)).unwrap();
    let c1 = EmulatedFpVar::<Mnt4Fq, Bn254Fr>::new_input(cs.clone(), || Ok(c.c1)).unwrap();
    // Karatsuba-style Fq2 multiplication for u^2=13.
    let v0 = &a0 * &b0;
    let v1 = &a1 * &b1;
    let v2 = (&a0 + &a1) * (&b0 + &b1);
    let nr = EmulatedFpVar::<Mnt4Fq, Bn254Fr>::Constant(Mnt4Fq::from(13u64));
    let r0 = v0.clone() + v1.clone() * nr;
    let r1 = v2 - v0 - v1;
    r0.enforce_equal(&c0).unwrap();
    r1.enforce_equal(&c1).unwrap();
    assert!(cs.is_satisfied().unwrap());
    cs.num_constraints()
}

fn constraints_for_fq4_mul() -> usize {
    let cs = ConstraintSystem::<Bn254Fr>::new_ref();
    let a = Mnt4Fq4::new(
        Mnt4Fq2::new(Mnt4Fq::from(3u64), Mnt4Fq::from(7u64)),
        Mnt4Fq2::new(Mnt4Fq::from(13u64), Mnt4Fq::from(17u64)),
    );
    let b = Mnt4Fq4::new(
        Mnt4Fq2::new(Mnt4Fq::from(5u64), Mnt4Fq::from(11u64)),
        Mnt4Fq2::new(Mnt4Fq::from(19u64), Mnt4Fq::from(23u64)),
    );
    let c = a * b;
    // Conservative composition from measured Fq2/Fq relation: Fq4 Karatsuba uses three Fq2 multiplications.
    let fq2 = constraints_for_fq2_mul();
    let fq = constraints_for_fq_mul();
    let estimate = 3 * fq2 + 8 * fq; // additions/range carries are already present in non-native vars; keep explicit overhead conservative.
    let _ = (cs, c);
    estimate
}

fn main() {
    let fq_mul = constraints_for_fq_mul();
    let fq2_mul = constraints_for_fq2_mul();
    let fq4_mul_model = constraints_for_fq4_mul();
    let article640_miller_steps = 499usize;
    let sparse_line_fq4_like_muls_per_step = 2usize;
    let approximate_miller_constraints = article640_miller_steps * sparse_line_fq4_like_muls_per_step * fq4_mul_model;
    println!("article640_pcs_constraints_report");
    println!("mnt4_fq_mul_in_bn254_constraints={}", fq_mul);
    println!("mnt4_fq2_mul_in_bn254_constraints={}", fq2_mul);
    println!("mnt4_fq4_mul_model_in_bn254_constraints={}", fq4_mul_model);
    println!("article640_miller_steps={}", article640_miller_steps);
    println!("approx_sparse_miller_constraints={}", approximate_miller_constraints);
}
