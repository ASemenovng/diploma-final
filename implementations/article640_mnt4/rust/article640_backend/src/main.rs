use std::{env, fs, path::PathBuf};
fn main() {
    let out_dir = env::args().nth(1).map(PathBuf::from).unwrap_or_else(|| PathBuf::from("fixtures"));
    fs::create_dir_all(&out_dir).expect("create output dir");
    let artifact = article640_backend::build_artifact();
    fs::write(out_dir.join("article640_direct_fixture.json"), serde_json::to_string_pretty(&artifact).unwrap()).unwrap();
    fs::write(out_dir.join("article640_direct.words.hex"), article640_backend::write_words_fixture(&artifact)).unwrap();
    let hot = article640_backend::build_hot_artifact();
    fs::write(out_dir.join("article640_hot_fixture.json"), serde_json::to_string_pretty(&hot).unwrap()).unwrap();
    fs::write(out_dir.join("article640_hot.words.hex"), article640_backend::write_hot_words_fixture(&hot)).unwrap();
    let quotient = article640_backend::build_quotient_artifact(&artifact);
    fs::write(out_dir.join("article640_quotient_fixture.json"), serde_json::to_string_pretty(&quotient).unwrap()).unwrap();
    fs::write(out_dir.join("article640_quotient.words.hex"), article640_backend::write_quotient_words_fixture(&quotient)).unwrap();
    let relation = article640_backend::build_relation_artifact(&artifact);
    fs::write(out_dir.join("article640_relation_fixture.json"), serde_json::to_string_pretty(&relation).unwrap()).unwrap();
    fs::write(out_dir.join("article640_relation.words.hex"), article640_backend::write_relation_words_fixture(&relation)).unwrap();
    println!("wrote {}", out_dir.display());
    println!("commitment_q {}", artifact.commitment_q);
    println!("commitment_s {}", artifact.commitment_s);
    println!("steps {} arkworks_equation_holds {}", artifact.line_count, artifact.arkworks_equation_holds);
    println!("hot_residue_relation_holds {}", hot.rust_residue_relation_holds);
    println!("hot_miller_digest {}", hot.hot_miller_digest);
    println!("quotient_trace {}", quotient.trace_commitment);
    println!("quotient_transcript {}", quotient.transcript_challenge);
    println!("relation_challenge {} {} {}", relation.challenge.d2, relation.challenge.d1, relation.challenge.d0);
}
