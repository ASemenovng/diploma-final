fn main() {
    let fixture = mnt6_article640_backend::build_fixture();
    println!("{}", serde_json::to_string_pretty(&fixture).unwrap());
}
