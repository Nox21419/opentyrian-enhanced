# Android ARM64 proof of concept

This target is for the Samsung Galaxy A35 and other ARM64 Android devices.
It uses the existing Compatibility renderer, Original graphics and landscape
orientation. During a level, **hold one finger on the playfield to steer and fire**;
drag to move the target, and lift to stop firing. The ship approaches the finger
at the existing movement speed and stays inside its normal bounds. Extra fingers
are ignored; pause or focus loss cancels the held input. Menu touch continues to
use the existing pointer/click behavior. Dedicated touch buttons for sidekicks,
weapon switching and pause are not implemented. No HD art or example mods ship.
Without input, leave the title idle for 30 seconds after the intro
to see the built-in recorded gameplay demo. This is an experimental target,
not a claim of phone performance or full Android support.

## Gameplay preservation

While getting the game working on Android, **do not modify game mechanics from
the original Tyrian 2000**. Platform integration and touch controls must preserve
gameplay rules, movement speed limits, simulation timing, collisions, damage,
balance and gameplay RNG behavior. Existing intentional divergences do not
authorize additional mechanics changes for the Android port.

If there is uncertainty about whether a proposed change affects game mechanics,
investigate the original behavior and the affected code first. Present the
findings, likely gameplay effects and any remaining uncertainty to the user,
and obtain their express approval **before implementing the change**.

The user has accepted the current single-finger destination-following control:
the ship continues toward a held finger, using the existing simulation mouse
path and its limit of 8 logical game pixels per tick per axis (280 pixels per
second at normal 35 Hz pacing). This accepted input adaptation is not blanket
approval for other gameplay changes.

## Host preparation

1. Install Rust (minimum 1.94), Python 3.11+, Godot **4.7.2 standard** and its
   matching Android export templates. Keep a host GDExtension installed too:
   Godot's import/export runs on the host, so the ARM64 library alone is insufficient.
2. Run the normal [desktop build/import](build.md) on your host. This produces
   the imported sprites, sounds, both offline OPL soundtracks and level scenes.
   Android does not run the importer, C music renderer or ffmpeg. The helper
   deliberately fails if the generated resources are absent.
   The offline renderer defines `SDL_MAIN_HANDLED` so MinGW can build its
   ordinary console entry point on Windows without linking SDL's main wrapper.
3. Install Android SDK platform-tools, `platforms;android-36`,
   `build-tools;36.1.0` and `ndk;29.0.14206865`. These match
   [Godot 4.7.2's Android configuration](https://github.com/godotengine/godot/blob/4.7.2-stable/platform/android/java/app/config.gradle).
   Configure **Editor Settings → Export → Android** with the SDK and Java SDK
   locations (JDK 17 is the documented baseline). Godot must also have a debug
   keystore; let the editor create it, or use its documented `keytool` command.
   This target uses the prebuilt APK template, without a Gradle project.
4. Install the Rust target:

   ```powershell
   rustup target add aarch64-linux-android
   ```

## Build

From the repository root (PowerShell example; the same Python helper supports Linux/macOS):

```powershell
$env:ANDROID_HOME = "$env:LOCALAPPDATA\Android\Sdk"
python rewrite/scripts/build-android.py --godot C:\path\Godot_v4.7.2-stable_win64_console.exe
```

`--sdk`, `--ndk`, and `--output` override paths; `GODOT`, `ANDROID_HOME`
(`ANDROID_SDK_ROOT` fallback), `ANDROID_NDK_HOME`, and `CARGO_TARGET_DIR` are
honored. Use `--bundle-only` to generate only the native-data ZIP.
The helper re-signs the APK after storing assets without outer ZIP compression.
It uses Godot's standard debug keystore location; `--debug-keystore` and
`--debug-key-alias` override it. `TYRIAN_ANDROID_KEYSTORE_PASSWORD` defaults to
`android`. Java must be available through `JAVA_HOME` or PATH for `apksigner`.

The helper selects runtime data explicitly (the desktop package's allowlist),
adds notices/licenses and a SHA-256 manifest, and writes the deterministic,
ignored `rewrite/godot/assets/android/runtime.zip`. It builds and strips
`bin/android/arm64/libtyrian_godot.so`, imports resources, exports the
**Android ARM64** debug preset and checks native-library packaging and 16 KiB
APK alignment. Rust ELF link flags explicitly request 16 KiB alignment.
Android's compressed-asset seeking caused minutes of black-screen startup on
the A35. The helper stores APK assets uncompressed, then realigns and re-signs
them; bootstrap also stages the native-data ZIP into a loose private file before
ZIPReader seeks. A regression test covers asset storage and stale-signature removal.
The default artifact is `build/android/OpenTyrian2000-Enhanced.apk`.
Debug signing is for personal testing; release signing/distribution is separate.

`Game._ready()` extracts the bundle before its first native campaign/profile
load. Files go to `user://bundled/runtime-v1/`, and `GamePaths` resolves native
data there. Every startup verifies file hashes, reuses intact files and repairs
missing/corrupt/changed files via temporary writes and renames. Nothing recursively
deletes the cache, saves or settings. Player files and user mods use Android's
app-private `user://`; no shared-storage permission is requested. Uninstalling
the app removes these files, as with other Android apps.

## Install and check on the phone

Enable Developer options and USB debugging, connect USB and accept the phone's
authorization dialog. From a terminal with SDK platform-tools on PATH:

```powershell
adb devices -l
adb shell getprop ro.build.version.release
adb shell getprop ro.product.cpu.abilist
adb shell getconf PAGE_SIZE
adb install -r build/android/OpenTyrian2000-Enhanced.apk
adb shell monkey -p com.nox21419.opentyrian.enhanced 1
adb logcat -s godot AndroidRuntime
```

Confirm the title, then gameplay after the idle timeout, moving enemies and shots,
music/SFX, stable pacing, landscape rotation and letterboxing. Test Home → resume,
screen off/on, cold relaunch, and an APK update without uninstalling. Save/settings
interaction beyond pointer-accessible menus may need a keyboard/controller. Record the
actual Android version, ABI and page size rather than assuming what “newest” means.
The proof-of-concept preset passes `--no-xmas` so the December Christmas prompt
cannot interrupt the idle route while no keyboard/controller is available.

## Validation

```powershell
python -m unittest discover -s rewrite/scripts -p test_build_android.py
godot --headless --path rewrite/godot -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://test/android_data_test.gd -a res://test/game_paths_test.gd --ignoreHeadlessMode -rd res://../../build/android-gdunit
```

The gdUnit suite checks first extraction, cache reuse, repair, changed bundles,
save preservation and unsafe names. `game_paths_test.gd` also checks Android's
player-directory policy. These checks and an APK export cannot substitute for
running on the A35. The repository's Linux exported-package journey/smoke gate
in [testing.md](testing.md) still applies before a push or build handoff.
