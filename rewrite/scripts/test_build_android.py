"""Native Android data selection/manifest checks; no Android SDK needed."""

import hashlib
import importlib.util
import json
import struct
import tempfile
import unittest
import zipfile
from pathlib import Path

SPEC = importlib.util.spec_from_file_location("build_android", Path(__file__).with_name("build-android.py"))
BUILD = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(BUILD)


class AndroidBundleTests(unittest.TestCase):
    def test_seekable_assets_are_stored_and_old_signatures_removed(self):
        with tempfile.TemporaryDirectory() as folder:
            source = Path(folder) / "source.apk"
            stored = Path(folder) / "stored.apk"
            with zipfile.ZipFile(source, "w", compression=zipfile.ZIP_DEFLATED) as archive:
                archive.writestr("assets/runtime.zip", b"seekable archive")
                archive.writestr("assets/song.oggvorbisstr", b"seekable audio")
                archive.writestr("classes.dex", b"code")
                archive.writestr("META-INF/OLD.SF", b"invalidated signature")
            BUILD.store_assets(source, stored)
            with zipfile.ZipFile(stored) as archive:
                self.assertNotIn("META-INF/OLD.SF", archive.namelist())
                self.assertEqual(archive.read("assets/runtime.zip"), b"seekable archive")
                for name in ("assets/runtime.zip", "assets/song.oggvorbisstr"):
                    self.assertEqual(archive.getinfo(name).compress_type, zipfile.ZIP_STORED)
                self.assertEqual(archive.getinfo("classes.dex").compress_type, zipfile.ZIP_DEFLATED)

    def test_rejects_wrong_abi_and_unaligned_native_library(self):
        with self.assertRaisesRegex(ValueError, "ARM64"):
            BUILD.check_elf(b"MZ" + bytes(100))
        elf = bytearray(120)
        elf[:6] = b"\x7fELF\x02\x01"
        struct.pack_into("<H", elf, 18, 183)
        struct.pack_into("<Q", elf, 32, 64)
        struct.pack_into("<HH", elf, 54, 56, 1)
        struct.pack_into("<I", elf, 64, 1)
        struct.pack_into("<Q", elf, 112, 4096)
        with self.assertRaisesRegex(ValueError, "16 KiB"):
            BUILD.check_elf(elf)
        struct.pack_into("<Q", elf, 112, 16384)
        BUILD.check_elf(elf)

    def test_allowlist_hashes_and_deterministic_output(self):
        with tempfile.TemporaryDirectory() as folder:
            first = Path(folder) / "first.zip"
            second = Path(folder) / "second.zip"
            BUILD.write_bundle(BUILD.REPO, first)
            BUILD.write_bundle(BUILD.REPO, second)
            self.assertEqual(first.read_bytes(), second.read_bytes())
            with zipfile.ZipFile(first) as archive:
                names = archive.namelist()
                self.assertIn("data/demo.1", names)
                self.assertIn("data/soundfont.sf2", names)
                self.assertIn("licenses/rustysynth-LICENSE.txt", names)
                self.assertFalse(
                    any("reference/" in name or "/mods/" in name or name.endswith(".snd") for name in names)
                )
                # Shipped packs, as package.sh selects them: folders with mod.json, never _retired/.
                packs = sorted(p.name for p in (BUILD.REPO / "rewrite/mods").iterdir() if (p / "mod.json").is_file())
                self.assertEqual(len(packs), 5)
                for pack in packs:
                    self.assertIn(f"mods/{pack}/mod.json", names)
                self.assertFalse(any(name.startswith("mods/_retired/") for name in names))
                mod_names = [name for name in names if name.startswith("mods/")]
                self.assertTrue(all(name.count("/") >= 2 for name in mod_names))
                manifest = json.loads(archive.read("manifest.json"))
                self.assertEqual(set(manifest["files"]), set(names) - {"manifest.json"})
                for name, digest in manifest["files"].items():
                    self.assertEqual(hashlib.sha256(archive.read(name)).hexdigest(), digest)


if __name__ == "__main__":
    unittest.main()
