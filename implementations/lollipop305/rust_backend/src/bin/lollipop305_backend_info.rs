fn main() {
    let fixture = lollipop305_backend::fixture::build_smoke_fixture();
    println!("{}", serde_json::to_string_pretty(&fixture).expect("json"));
}
