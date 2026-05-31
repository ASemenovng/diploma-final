use lollipop305_backend::field::{Fp, Fp2};
fn main() {
    let u = Fp2::new(Fp::zero(), Fp::one());
    println!("u square {} sqrt {:?}", u.legendre_is_square(), u.sqrt());
    for a in 0..8u64 {
        for b in 0..8u64 {
            if a == 0 && b == 0 {
                continue;
            }
            let x = Fp2::new(Fp::from(a), Fp::from(b));
            if !x.legendre_is_square() {
                println!("first nonsquare {}+{}u", a, b);
                return;
            }
        }
    }
}
