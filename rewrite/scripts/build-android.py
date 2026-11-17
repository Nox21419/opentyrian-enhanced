#!/usr/bin/env python3
"""Build the ARM64 Android proof of concept using already imported host assets.

No Gradle project, touch controls, HD assets or shipped mods. Use --bundle-only
to rebuild the deterministic native-data ZIP without a compiler or Android SDK.
"""

import argparse
import hashlib
import json
import os
import shutil
import struct
import subprocess
import sys
import zipfile
from pathlib import Path

REWRITE = Path(__file__).resolve().parents[1]
REPO = REWRITE.parent
PROJECT = REWRITE / "godot"
TARGET = "aarch64-linux-android"
NDK_VERSION = "29.0.14206865"  # Godot 4.7.2 platform/android/java/app/config.gradle
PATTERNS = (
    "tyrian[1-5].lvl",
    "levels[1-5].dat",
    "tyrian.hdt",
    "tyrian.shp",
    "tyrianc.shp",
    "tyrian.pic",
    "palette.dat",
    "newsh?.shp",
    "shapes?.dat",
    "sprite_manifest.json",
    "demo.[1-5]",
    "cubetxt[1-5].dat",
    "tyrend.anm",
    "tyrian.cdt",
    "estsc.shp",
    "tshp2.pcx",
    "soundfont.sf2",
    "midi/[0-9][0-9]-*.mid",
    "locales/locale_*.txt",
)
NOTICES = """Code: see COPYING (GPL). Tyrian data is separate from the code.
Tyrian 2000 data: freeware since 2004, not covered by the code's GPL.
No written data licence is held here; this package is not redistribution clearance.
Imported images, sounds and music derive from that data. Check rights before redistribution.
MIDI: third-party transcriptions (karlsitretro.com) of Alexander Brandon and Andreas Molnar's music;
third-party licence NOT INCLUDED, rights not verified.
SoundFont: TimGM6mb, Tim Brechbill and David Bolton, GPL v2 (see licenses/).
Synthesizer: rustysynth, Nobuaki Tanaka, MIT (see licenses/); midly, Unlicense.
Sharp pixel-art shader: libretro/glsl-shaders, Hyllian (MIT), Zenju (GPL v3).
Godot: MIT, https://godotengine.org/license/ (includes engine third-party notices).
No HD assets or example mod packs in this proof of concept.
See docs/asset-rights.md in the source repository.
"""


def bundle_files(repo: Path) -> dict[str, bytes]:
    """Same runtime allowlist as package.sh; never recursively copy data/."""
    data = repo / "data"
    result = {}
    for pattern in PATTERNS:
        for path in sorted(data.glob(pattern)):
            if path.is_symlink() or any(parent.is_symlink() for parent in path.parents):
                raise ValueError(f"Data symlink refused: {path}")
            if path.is_file():
                result["data/" + path.relative_to(data).as_posix()] = path.read_bytes()
    for required in ("tyrian.hdt", "tyrian.shp", "tyrian.pic", "palette.dat", "demo.1", "tyrian1.lvl"):
        if "data/" + required not in result:
            raise ValueError(f"Missing required runtime data: {required}")
    for name, path in {
        "COPYING": repo / "COPYING",
        "licenses/rustysynth-LICENSE.txt": repo / "rewrite/licenses/rustysynth-LICENSE.txt",
        "licenses/TimGM6mb-LICENSE.txt": repo / "rewrite/licenses/TimGM6mb-LICENSE.txt",
    }.items():
        result[name] = path.read_bytes()
    result["DATA-NOTICES.txt"] = NOTICES.encode()
    return result


def write_bundle(repo: Path, destination: Path) -> None:
    files = bundle_files(repo)
    manifest = {"version": 1, "files": {name: hashlib.sha256(body).hexdigest() for name, body in sorted(files.items())}}
    files["manifest.json"] = json.dumps(manifest, sort_keys=True, separators=(",", ":")).encode()
    destination.parent.mkdir(parents=True, exist_ok=True)
    temp = destination.with_suffix(".tmp")
    with zipfile.ZipFile(temp, "w", compression=zipfile.ZIP_DEFLATED) as archive:
        for name, body in sorted(files.items()):
            entry = zipfile.ZipInfo(name, (2026, 1, 1, 0, 0, 0))
            entry.compress_type = zipfile.ZIP_DEFLATED
            archive.writestr(entry, body)
    temp.replace(destination)
    print(f"Native-data bundle: {destination} ({len(files) - 1} files)", flush=True)


def run(*args: str, env: dict | None = None, godot: bool = False) -> None:
    print("+", *args, flush=True)
    result = subprocess.run(args, cwd=REWRITE, env=env, capture_output=True, text=True, errors="replace", check=False)
    print(result.stdout, end="", flush=True)
    print(result.stderr, end="", file=sys.stderr, flush=True)
    result.check_returncode()
    if godot and any(
        "SCRIPT ERROR:" in line or line.startswith("ERROR:") for line in (result.stdout + result.stderr).splitlines()
    ):
        raise ValueError("Godot reported errors despite a zero exit code")


def check_elf(data: bytes) -> None:
    """Reject a wrong ABI or a native LOAD segment incompatible with 16 KiB pages."""
    if len(data) < 64 or data[:6] != b"\x7fELF\x02\x01" or struct.unpack_from("<H", data, 18)[0] != 183:
        raise ValueError("Expected a little-endian ARM64 ELF library")
    offset = struct.unpack_from("<Q", data, 32)[0]
    size, count = struct.unpack_from("<HH", data, 54)
    if size < 56 or not count or offset + size * count > len(data):
        raise ValueError("Invalid ELF program headers")
    loads = 0
    for index in range(count):
        start = offset + size * index
        if struct.unpack_from("<I", data, start)[0] == 1:
            loads += 1
            if struct.unpack_from("<Q", data, start + 48)[0] < 16384:
                raise ValueError("ELF LOAD alignment is smaller than 16 KiB")
    if not loads:
        raise ValueError("ELF has no LOAD segments")


def store_assets(source: Path, destination: Path) -> None:
    """Android's compressed AssetManager seeks re-inflate from the beginning.

    Vorbis resource streams and nested ZIPs seek often; store APK assets directly.
    Repacking invalidates the export signature, so align and sign again afterwards.
    """
    with zipfile.ZipFile(source) as original, zipfile.ZipFile(destination, "w") as output:
        for entry in original.infolist():
            if entry.filename.startswith("META-INF/") and (
                entry.filename.endswith((".SF", ".RSA", ".DSA", ".EC")) or entry.filename == "META-INF/MANIFEST.MF"
            ):
                continue
            body = original.read(entry)
            if entry.filename.startswith("assets/"):
                entry.compress_type = zipfile.ZIP_STORED
            output.writestr(entry, body)


def default_keystore() -> Path:
    if sys.platform == "win32":
        base = Path(os.environ["APPDATA"]) / "Godot"
    elif sys.platform == "darwin":
        base = Path.home() / "Library/Application Support/Godot"
    else:
        base = Path(os.environ.get("XDG_DATA_HOME", Path.home() / ".local/share")) / "godot"
    return base / "keystores/debug.keystore"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default=os.environ.get("GODOT", "godot"))
    parser.add_argument("--sdk", type=Path, default=os.environ.get("ANDROID_HOME", os.environ.get("ANDROID_SDK_ROOT")))
    parser.add_argument("--ndk", type=Path, default=os.environ.get("ANDROID_NDK_HOME"))
    parser.add_argument("--output", type=Path, default=REPO / "build/android/OpenTyrian2000-Enhanced.apk")
    parser.add_argument("--bundle-only", action="store_true")
    parser.add_argument("--debug-keystore", type=Path, default=default_keystore())
    parser.add_argument("--debug-key-alias", default="androiddebugkey")
    options = parser.parse_args()
    write_bundle(REPO, PROJECT / "assets/android/runtime.zip")
    if options.bundle_only:
        return
    sdk = options.sdk
    if sdk is None:
        raise ValueError("Set ANDROID_HOME or --sdk to the Android SDK directory")
    ndk = options.ndk or sdk / "ndk" / NDK_VERSION
    host = {"win32": "windows-x86_64", "linux": "linux-x86_64", "darwin": "darwin-x86_64"}[sys.platform]
    tools = ndk / "toolchains/llvm/prebuilt" / host / "bin"
    linker = tools / ("aarch64-linux-android24-clang.cmd" if os.name == "nt" else "aarch64-linux-android24-clang")
    if not linker.is_file():
        raise ValueError(f"Missing NDK linker: {linker}; install ndk;{NDK_VERSION}")
    for required in ("assets/imported/palettes.json", "levels/ep1_01.tscn"):
        if not (PROJECT / required).is_file():
            raise ValueError(
                f"Missing host-generated {required}; run the desktop build/import first (docs/android-build.md)"
            )
    for engine in ("music", "music_nuked"):
        metadata = PROJECT / "assets/imported" / engine / "music.json"
        if not metadata.is_file():
            raise ValueError(f"Missing {metadata}; render both OPL soundtracks during the host build")
        songs = json.loads(metadata.read_text(encoding="utf-8"))["songs"]
        if len(songs) != 41 or any(not (metadata.parent / song["file"]).is_file() for song in songs):
            raise ValueError(f"Incomplete soundtrack: {metadata}")
    env = os.environ.copy()
    env["CARGO_TARGET_AARCH64_LINUX_ANDROID_LINKER"] = str(linker)
    # Explicitly preserve 16 KiB ELF compatibility even if toolchain defaults change.
    flags_key = "CARGO_TARGET_AARCH64_LINUX_ANDROID_RUSTFLAGS"
    env[flags_key] = (
        env.get(flags_key, "") + " -C link-arg=-Wl,-z,max-page-size=16384 -C link-arg=-Wl,-z,common-page-size=16384"
    )
    run("cargo", "build", "--locked", "--release", "--target", TARGET, "-p", "tyrian-godot", env=env)
    target_dir = Path(env.get("CARGO_TARGET_DIR", REWRITE / "target"))
    if not target_dir.is_absolute():
        target_dir = REWRITE / target_dir
    native = PROJECT / "bin/android/arm64/libtyrian_godot.so"
    native.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(target_dir / TARGET / "release/libtyrian_godot.so", native)
    strip = tools / ("llvm-strip.exe" if os.name == "nt" else "llvm-strip")
    run(str(strip), "--strip-unneeded", str(native))
    check_elf(native.read_bytes())
    run(options.godot, "--headless", "--path", str(PROJECT), "--import", godot=True)
    output = options.output.resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    pending = output.with_suffix(".building.apk")
    pending.unlink(missing_ok=True)
    run(
        options.godot, "--headless", "--path", str(PROJECT), "--export-debug", "Android ARM64", str(pending), godot=True
    )
    with zipfile.ZipFile(pending) as apk:
        if "lib/arm64-v8a/libtyrian_godot.so" not in apk.namelist():
            raise ValueError("APK is missing the ARM64 GDExtension")
        if not any(name.endswith("runtime.zip") for name in apk.namelist()):
            raise ValueError("APK is missing the native-data bundle")
        for name in apk.namelist():
            if name.startswith("lib/arm64-v8a/") and name.endswith(".so"):
                check_elf(apk.read(name))
    zipalign = sdk / "build-tools/36.1.0" / ("zipalign.exe" if os.name == "nt" else "zipalign")
    stored = output.with_suffix(".stored.apk")
    aligned = output.with_suffix(".aligned.apk")
    store_assets(pending, stored)
    run(str(zipalign), "-f", "-P", "16", "4", str(stored), str(aligned))
    signer = sdk / "build-tools/36.1.0" / ("apksigner.bat" if os.name == "nt" else "apksigner")
    env["TYRIAN_ANDROID_KEYSTORE_PASSWORD"] = env.get("TYRIAN_ANDROID_KEYSTORE_PASSWORD", "android")
    run(
        str(signer),
        "sign",
        "--ks",
        str(options.debug_keystore),
        "--ks-key-alias",
        options.debug_key_alias,
        "--ks-pass",
        "env:TYRIAN_ANDROID_KEYSTORE_PASSWORD",
        "--out",
        str(pending),
        str(aligned),
        env=env,
    )
    run(str(signer), "verify", str(pending), env=env)
    run(str(zipalign), "-c", "-P", "16", "4", str(pending))
    pending.replace(output)
    signature = Path(str(pending) + ".idsig")
    final_signature = Path(str(output) + ".idsig")
    if signature.is_file():
        signature.replace(final_signature)
    else:
        final_signature.unlink(missing_ok=True)
    stored.unlink()
    aligned.unlink()
    print(f"Android debug APK ready: {output}")


if __name__ == "__main__":
    try:
        main()
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        sys.exit(str(error))
