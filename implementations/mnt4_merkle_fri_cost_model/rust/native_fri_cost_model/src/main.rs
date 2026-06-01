use std::{env, fs, path::Path};

use native_fri_cost_model::{
    model::{
        experimental_deep_sensitivity, optimize_strict_profile, sensitivity_grid, ModelAssumptions,
    },
    report::{render_json, render_markdown},
};

fn main() {
    let assumptions = ModelAssumptions::default();
    let strict = optimize_strict_profile(&assumptions);
    let deep = experimental_deep_sensitivity(&assumptions, &strict.schedule);
    let sensitivity = sensitivity_grid(&assumptions, &strict.schedule);
    let args: Vec<_> = env::args().collect();
    let json_path = args
        .get(1)
        .map(String::as_str)
        .unwrap_or("../../artifacts/native-field-cost-model/report.json");
    let markdown_path = args
        .get(2)
        .map(String::as_str)
        .unwrap_or("../../docs/N1_NATIVE_FIELD_COST_MODEL_RESULTS_RU.md");

    write_file(
        json_path,
        &render_json(&assumptions, &strict, &deep, &sensitivity),
    );
    write_file(
        markdown_path,
        &render_markdown(&assumptions, &strict, &deep, &sensitivity),
    );
    println!("strict expected gas: {}", strict.expected.total_gas);
    println!("strict lower bound gas: {}", strict.lower_bound.total_gas);
    println!(
        "stop/go Article640: {}",
        if strict.stop_go.beats_article640_fixed_shards {
            "GO"
        } else {
            "NO-GO"
        }
    );
}

fn write_file(path: &str, contents: &str) {
    let path = Path::new(path);
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent).expect("create report directory");
    }
    fs::write(path, contents).expect("write report");
}
