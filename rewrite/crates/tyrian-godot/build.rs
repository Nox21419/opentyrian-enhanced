#[path = "src/network_fingerprint.rs"]
#[allow(dead_code)] // Runtime content helpers share this module, but are not build inputs themselves.
mod network_fingerprint;

use std::path::PathBuf;

fn main() {
    let root = PathBuf::from(std::env::var_os("CARGO_MANIFEST_DIR").expect("manifest dir"))
        .parent()
        .expect("crates")
        .parent()
        .expect("workspace")
        .to_path_buf();
    let mut manifest = network_fingerprint::Manifest::default();
    let rustc = std::env::var_os("RUSTC").expect("rustc path");
    let version = std::process::Command::new(rustc).arg("--version").output().expect("rustc version");
    assert!(version.status.success(), "rustc version failed");
    manifest.add_bytes("build/rustc-version", &version.stdout).expect("toolchain identity");
    let flags = std::env::var("CARGO_ENCODED_RUSTFLAGS").unwrap_or_default();
    manifest.add_bytes("build/rustflags", flags.as_bytes()).expect("compiler flags");
    println!("cargo:rerun-if-env-changed=CARGO_ENCODED_RUSTFLAGS");
    for name in ["Cargo.toml", "Cargo.lock"] {
        let path = root.join(name);
        println!("cargo:rerun-if-changed={}", path.display());
        manifest.add_file(name, &path).expect("workspace build input");
    }
    // All local native crates: root-relative source names, with neither timestamps
    // nor mutable Git HEAD. Explicit compiler flags above remain significant.
    let mut crates = std::fs::read_dir(root.join("crates"))
        .expect("workspace crates")
        .map(|entry| entry.expect("crate directory").path())
        .filter(|p| p.is_dir() && p.join("Cargo.toml").is_file())
        .collect::<Vec<_>>();
    crates.sort();
    for path in crates {
        let name = path.file_name().expect("crate name").to_str().expect("UTF-8 crate name");
        for file in ["Cargo.toml", "build.rs"] {
            if path.join(file).is_file() {
                println!("cargo:rerun-if-changed={}", path.join(file).display());
                manifest.add_file(&format!("crates/{name}/{file}"), &path.join(file)).expect("crate build input");
            }
        }
        println!("cargo:rerun-if-changed={}", path.join("src").display());
        manifest.add_tree(&format!("crates/{name}/src"), &path.join("src")).expect("crate source input");
    }
    println!("cargo:rustc-env=TYRIAN_NETWORK_BUILD_ID={}", manifest.digest());
}
