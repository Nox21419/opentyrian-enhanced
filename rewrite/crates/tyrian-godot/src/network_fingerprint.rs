//! Read-only, bounded byte manifests shared by the native build and runtime.
use sha2::{Digest, Sha256};
use std::collections::BTreeMap;
use std::io::Read;
use std::path::Path;

const MAX_FILES: usize = 4096;
const MAX_BYTES: u64 = 512 * 1024 * 1024;
const MAX_DEPTH: usize = 32;
const MAX_VISITS: usize = 8192;

#[derive(Default)]
pub struct Manifest {
    entries: BTreeMap<String, String>,
    bytes: u64,
    visits: usize,
}

impl Manifest {
    pub fn add_bytes(&mut self, name: &str, bytes: &[u8]) -> Result<(), String> {
        if !safe_name(name)
            || self.entries.contains_key(name)
            || self.entries.len() >= MAX_FILES
            || bytes.len() as u64 > MAX_BYTES - self.bytes
        {
            return Err("invalid_or_oversized_manifest_entry".into());
        }
        self.bytes += bytes.len() as u64;
        self.entries.insert(name.into(), format!("{:x}", Sha256::digest(bytes)));
        Ok(())
    }

    pub fn add_file(&mut self, name: &str, path: &Path) -> Result<(), String> {
        if !safe_name(name) || self.entries.contains_key(name) || self.entries.len() >= MAX_FILES {
            return Err("invalid_or_duplicate_manifest_entry".into());
        }
        let metadata = std::fs::symlink_metadata(path).map_err(|_| "content_unreadable")?;
        if !metadata.is_file() || metadata.file_type().is_symlink() {
            return Err("regular_content_file_required".into());
        }
        let mut file = std::fs::File::open(path).map_err(|_| "content_unreadable")?;
        let opened = file.metadata().map_err(|_| "content_unreadable")?;
        if !opened.is_file() || opened.len() != metadata.len() || opened.len() > MAX_BYTES - self.bytes {
            return Err("content_limit_or_change".into());
        }
        let mut hash = Sha256::new();
        let mut buffer = [0; 65536];
        let mut read = 0u64;
        loop {
            let count = file.read(&mut buffer).map_err(|_| "content_unreadable")?;
            if count == 0 {
                break;
            }
            read += count as u64;
            if read > opened.len() {
                return Err("content_changed_during_hash".into());
            }
            hash.update(&buffer[..count]);
        }
        if read != opened.len() {
            return Err("content_changed_during_hash".into());
        }
        self.bytes += read;
        self.entries.insert(name.into(), format!("{:x}", hash.finalize()));
        Ok(())
    }

    pub fn add_tree(&mut self, namespace: &str, root: &Path) -> Result<(), String> {
        self.walk(namespace, root, 0)
    }

    fn walk(&mut self, namespace: &str, root: &Path, depth: usize) -> Result<(), String> {
        if depth > MAX_DEPTH || !safe_name(namespace) {
            return Err("content_tree_limit".into());
        }
        let meta = std::fs::symlink_metadata(root).map_err(|_| "content_unreadable")?;
        if !meta.is_dir() || meta.file_type().is_symlink() {
            return Err("content_directory_required".into());
        }
        for entry in std::fs::read_dir(root).map_err(|_| "content_unreadable")? {
            self.visits += 1;
            if self.visits > MAX_VISITS {
                return Err("content_tree_limit".into());
            }
            let entry = entry.map_err(|_| "content_unreadable")?;
            let name = entry.file_name().into_string().map_err(|_| "non_utf8_content_name")?;
            let qualified = format!("{namespace}/{name}");
            let kind = entry.file_type().map_err(|_| "content_unreadable")?;
            if kind.is_dir() {
                self.walk(&qualified, &entry.path(), depth + 1)?;
            } else {
                self.add_file(&qualified, &entry.path())?;
            }
        }
        Ok(())
    }

    pub fn digest(&self) -> String {
        let mut hash = Sha256::new();
        for (name, digest) in &self.entries {
            hash.update(name.as_bytes());
            hash.update([0]);
            hash.update(digest.as_bytes());
            hash.update(b"\n");
        }
        format!("{:x}", hash.finalize())
    }
}

fn safe_name(name: &str) -> bool {
    !name.is_empty()
        && !name.contains(['\\', ':', '\0', '\r', '\n'])
        && name.split('/').all(|part| !part.is_empty() && part != "." && part != "..")
}

/// The runtime package allowlist, not repository docs/catalogs or player files.
pub fn runtime_data_file(name: &str) -> bool {
    if name.starts_with("locales/locale_") && name.ends_with(".txt") && name.matches('/').count() == 1 {
        return true;
    }
    if let Some(midi) = name.strip_prefix("midi/") {
        return midi.len() > 7
            && midi.as_bytes()[..2].iter().all(u8::is_ascii_digit)
            && midi.as_bytes()[2] == b'-'
            && midi.ends_with(".mid")
            && !midi.contains('/');
    }
    if name.contains('/') {
        return false;
    }
    if [
        "tyrian.hdt",
        "tyrian.shp",
        "tyrianc.shp",
        "tyrian.pic",
        "palette.dat",
        "sprite_manifest.json",
        "tyrend.anm",
        "tyrian.cdt",
        "estsc.shp",
        "tshp2.pcx",
        "soundfont.sf2",
    ]
    .contains(&name)
    {
        return true;
    }
    for episode in 1..=5 {
        if [
            format!("tyrian{episode}.lvl"),
            format!("levels{episode}.dat"),
            format!("demo.{episode}"),
            format!("cubetxt{episode}.dat"),
        ]
        .iter()
        .any(|s| s == name)
        {
            return true;
        }
    }
    (name.len() == 10 && name.starts_with("newsh") && name.ends_with(".shp"))
        || (name.len() == 11 && name.starts_with("shapes") && name.ends_with(".dat"))
}

pub fn content_digest(data: &Path, mods: &BTreeMap<String, std::path::PathBuf>) -> Result<String, String> {
    let mut manifest = Manifest::default();
    manifest.add_bytes("manifest/runtime-version", b"1")?;
    for required in ["tyrian1.lvl", "levels1.dat", "tyrian.hdt"] {
        if !data.join(required).is_file() {
            return Err("missing_original_content".into());
        }
    }
    for folder in ["", "locales", "midi"] {
        let root = data.join(folder);
        if !folder.is_empty() && !root.exists() {
            continue;
        }
        let meta = std::fs::symlink_metadata(&root).map_err(|_| "content_unreadable")?;
        if !meta.is_dir() || meta.file_type().is_symlink() {
            return Err("content_directory_required".into());
        }
        for entry in std::fs::read_dir(&root).map_err(|_| "content_unreadable")? {
            manifest.visits += 1;
            if manifest.visits > MAX_VISITS {
                return Err("content_tree_limit".into());
            }
            let entry = entry.map_err(|_| "content_unreadable")?;
            let file = entry.file_name().into_string().map_err(|_| "non_utf8_content_name")?;
            let name = if folder.is_empty() { file } else { format!("{folder}/{file}") };
            if runtime_data_file(&name) {
                manifest.add_file(&format!("data/{name}"), &entry.path())?;
            }
        }
    }
    for (folder, path) in mods {
        if folder.contains('/') || !safe_name(folder) {
            return Err("invalid_mod_identity".into());
        }
        manifest.add_tree(&format!("mods/{folder}"), path)?;
    }
    Ok(manifest.digest())
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::path::PathBuf;
    use std::sync::atomic::{AtomicU64, Ordering};

    struct Fixture(PathBuf);
    impl Fixture {
        fn new() -> Self {
            static SERIAL: AtomicU64 = AtomicU64::new(0);
            let root = std::env::temp_dir().join(format!(
                "tyrian-network-{}-{}",
                std::process::id(),
                SERIAL.fetch_add(1, Ordering::Relaxed)
            ));
            std::fs::create_dir(&root).expect("isolated fixture");
            Self(root)
        }
        fn write(&self, name: &str, bytes: &[u8]) {
            let path = self.0.join(name);
            std::fs::create_dir_all(path.parent().unwrap()).unwrap();
            std::fs::write(path, bytes).unwrap();
        }
        fn data(&self) -> PathBuf {
            for name in ["tyrian1.lvl", "levels1.dat", "tyrian.hdt"] {
                self.write(&format!("data/{name}"), b"fixture");
            }
            self.0.join("data")
        }
    }
    impl Drop for Fixture {
        fn drop(&mut self) {
            std::fs::remove_dir_all(&self.0).expect("remove own isolated fixture");
        }
    }

    #[test]
    fn fingerprints_are_order_and_checkout_location_independent_but_byte_sensitive() {
        let (a, b) = (Fixture::new(), Fixture::new());
        for f in [&a, &b] {
            f.write("a", b"one");
            f.write("b", b"two");
        }
        let (mut x, mut y) = (Manifest::default(), Manifest::default());
        x.add_file("a", &a.0.join("a")).unwrap();
        x.add_file("b", &a.0.join("b")).unwrap();
        y.add_file("b", &b.0.join("b")).unwrap();
        y.add_file("a", &b.0.join("a")).unwrap();
        assert_eq!(x.digest(), y.digest());
        b.write("b", b"TWO");
        let mut z = Manifest::default();
        z.add_file("a", &b.0.join("a")).unwrap();
        z.add_file("b", &b.0.join("b")).unwrap();
        assert_ne!(x.digest(), z.digest());
    }

    #[test]
    fn manifest_rejects_ambiguous_names_duplicates_nonfiles_and_excess_entries() {
        let mut manifest = Manifest::default();
        for name in ["", "a\nb", "a\0b", "../a", "a/../b", "a\\b", "/a", "a//b", "c:a"] {
            assert!(manifest.add_bytes(name, b"x").is_err(), "{name:?}");
        }
        manifest.add_bytes("a", b"x").unwrap();
        assert!(manifest.add_bytes("a", b"y").is_err());
        let f = Fixture::new();
        assert!(manifest.add_file("directory", &f.0).is_err());
        for i in 1..MAX_FILES {
            manifest.add_bytes(&format!("file{i}"), b"").unwrap();
        }
        assert!(manifest.add_bytes("too-many", b"").is_err());
    }

    #[test]
    fn runtime_allowlist_matches_packaged_data_and_ignores_repo_catalogs() {
        for file in
            ["tyrian1.lvl", "levels5.dat", "newsh'.shp", "shapesx.dat", "midi/01-track.mid", "locales/locale_fr.txt"]
        {
            assert!(runtime_data_file(file), "{file}");
        }
        for file in ["doc/tyrian.hdt.txt", "reference/codex.html", "setup.cfg", "data/tyrian1.lvl", "midi/not-midi.mid"]
        {
            assert!(!runtime_data_file(file), "{file}");
        }
    }

    #[test]
    fn effective_mod_bytes_and_identity_change_content_but_unused_folders_do_not() {
        let f = Fixture::new();
        let data = f.data();
        let original = content_digest(&data, &BTreeMap::new()).unwrap();
        f.write("data/reference/catalog.html", b"not runtime content");
        f.write("disabled/mod.json", b"disabled");
        assert_eq!(original, content_digest(&data, &BTreeMap::new()).unwrap());
        f.write("enabled/mod.json", b"enabled");
        let mods = BTreeMap::from([("pack".into(), f.0.join("enabled"))]);
        let enabled = content_digest(&data, &mods).unwrap();
        assert_ne!(original, enabled);
        f.write("enabled/mod.json", b"ENABLED");
        assert_ne!(enabled, content_digest(&data, &mods).unwrap());
        assert!(content_digest(&f.0.join("missing"), &mods).is_err());
    }
}
