# Android feasibility investigation

Implementation follow-up: the ARM64 preset, native-data bootstrap, app-private
player paths and build helper are now in the working tree. See
[Android build instructions](android-build.md). Findings below record the
pre-implementation investigation. The A35 now runs the title and automatic demo
with working audio; full performance and lifecycle validation remain outstanding.

Investigated 2026-11-17 against `8ddde4f`. Target: the user's Samsung Galaxy A35,
running their newest available Android update, without a gamepad. Touch-control
design is outside this investigation. The initial assessment preceded the
implementation; the follow-up now has an APK installed and running on that phone.

## Conclusion

**Proceed with a small Android proof of concept.** There is no obvious need to
rewrite the simulation or renderer. Godot supports Android exports, Rust supports
Android native libraries, and godot-rust documents the ARM64 GDExtension export
path. The implementation follow-up adds the Android binary build, export preset
and data-storage bootstrap needed to use that support.

Samsung lists the Galaxy A35 with Exynos 1380; its Cortex-A78/A55 CPU and Mali-G68
GPU make ARM64 the sensible first target. Running Original graphics with optional
effects reduced is a reasonable starting point, **not a measured performance
guarantee**. See [Samsung's device list](https://semiconductor.samsung.com/processor/showcase/smartphone/)
and [Exynos 1380 specifications](https://semiconductor.samsung.com/processor/mobile-processor/exynos-1380/).
The exact installed Android/API version, ABI and page size still need to be read
from the phone; “newest Android” is not an exact device build identifier.

## Findings from this repository

| Area | Evidence | Assessment |
|---|---|---|
| Engine | `rewrite/godot/project.godot` uses Godot 4.7, GDScript, Compatibility rendering, a 320×200 logical viewport and 35 Hz simulation | Suitable starting architecture for Android; retain the existing renderer initially |
| Rust core | `tyrian-sim` depends on local formats code; inspected engine crates have no obvious mandatory Windows-only system library or x86 assembly dependency | ARM64 cross-compilation looks plausible, but has not been attempted |
| Native extension | `tyrian-godot` is a `cdylib`; `tyrian.gdextension` declares only Linux/Windows x86_64 and universal macOS | Build Android ARM64 `.so` and add matching `android.debug.arm64` / `android.release.arm64` entries |
| Export | `export_presets.cfg` has Windows, Linux and macOS presets only | Add an Android APK preset, matching engine templates, landscape orientation and ARM64 architecture |
| Raw game assets | `Game._default_data_dir()` and `GamePaths.shipped_dir_for()` assume desktop executable-adjacent data or macOS bundle resources | Existing lookup is unsuitable for APK-contained game data |
| Native file reads | `tyrian-render/src/assets.rs`, `tyrian-godot/src/lib.rs`, `shop.rs`, `campaign.rs`, `midi.rs` and `tyrian-mods` use `std::fs` / native paths | A `res://data` string or a globalized APK resource path is not a loose directory that these readers can consume |
| Generated resources | `TyrianAssets` uses Godot resource/FileAccess loading under `res://assets/imported` | Keep imported resources in the exported project; generate them on the host before export |
| Player files | `UserData` has a writable-folder fallback, but explicitly selects app storage only for editor/macOS | Explicitly choose Android `user://` for saves/settings; avoid the unnecessary executable-directory write probe |
| Audio | OPL is rendered offline on the host; MIDI uses rustysynth in Rust and Godot audio | No need to run SDL/ffmpeg/C music-render tools on the phone; actual playback still needs testing |
| No controller | `title.gd` automatically starts a recorded demo after 30 seconds without input | A title-to-gameplay demo can prove loading, simulation, rendering and audio without touch controls or a gamepad |

The native-data folder is the largest code integration issue: both the title's
VGA assets and gameplay use the native readers. A successful APK export alone
would not prove the game can display its title or load a level.

## Smallest useful proof of concept

1. **Prepare the matching host tools.** Use Godot 4.7.2 and its Android export
   templates, Rust meeting this workspace's minimum, the Android ARM64 Rust
   target, a compatible Android NDK and the SDK/JDK required by that Godot
   version. Keep the locked crate versions for the first attempt.
2. **Generate normal game resources on the PC.** Run the importer, Godot import
   pass and level-scene generation. OPL renders also need host tooling or
   already-generated assets. A first silent visual experiment is possible, but
   not the eventual audio acceptance test.
3. **Cross-build the extension.** Build `tyrian-godot` for
   `aarch64-linux-android` with the NDK linker; place its library in a separate
   Android/ARM64 folder under `godot/bin` and register it in `.gdextension`.
   The desktop Linux `.so` cannot be reused. Follow the
   [godot-rust Android guide](https://godot-rust.github.io/book/toolchain/export-android.html),
   checking its example NDK version against the actual Godot release rather
   than copying its old example literally.
4. **Stage raw assets inside the APK, then extract them on first launch.** A
   generated ZIP plus a manifest is a simple option. Read it through Godot and
   extract the runtime allowlist into a versioned directory under `user://`.
   Set `Game.data_dir` to that directory's native absolute path **before** the
   first Rust campaign/VGA/mod load. A bootstrap in the title scene is too late:
   `Game._ready()` already accesses the campaign. Do not treat
   `ProjectSettings.globalize_path("res://...")` as archive extraction.
5. **Use private app storage explicitly.** Route player files to `user://` on
   Android. Keep packaged data separate from saves; validate the extraction
   manifest/version, reject partial extraction and reuse valid data on the next
   start. Do not overwrite player files during app/data updates. Godot documents
   [resource and writable user paths](https://docs.godotengine.org/en/stable/tutorials/io/data_paths.html).
6. **Start with a lite APK.** Original art, no HD archive, no shipped mods for
   the first test. Mods are disabled by default; do not assume APK paths can be
   passed to the native mod loader either. HD and optional packs can follow
   after the base title/demo succeeds. Keep the required raw data, imported
   resources and applicable notices.
7. **Install a debug APK and let the demo run.** Sideload to the A35, capture
   `adb logcat`, wait for title inactivity to start the demo, observe scrolling,
   ships, enemies, shots and sound, then relaunch. No Play Store publication or
   release signing setup is needed for this first debug-device experiment.

The data allowlist patterned after `package.sh:copy_data` contains 128 files
totaling **18,401,346 bytes (17.5 MiB)** in this checkout, including locales,
MIDI and SoundFont. This is not an APK-size estimate: it excludes the engine,
native library, generated imports, OPL renders and HD assets. There is no reason
to copy `data/reference/` and its galleries into the Android package.

For audio, retain `assets/imported/music/music.json`: `Music._load()` checks
its song table even when Enhanced/MIDI is selected. Including only the `.mid`
files and SoundFont will not provide working music with the current code.

## Build/device details still to verify

- Godot's current stable Android export documentation recommends JDK 17 and
  lists SDK/NDK packages. Pin the versions for **4.7.2**, not whichever happen
  to be installed. The standard Windows build script also expects bash, gcc,
  SDL2, ffmpeg and Python for generating OPL music; Android export does not
  eliminate that host-side asset preparation step. See
  [Godot Android export setup](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html).
- Use an ARM64 library and export only the ABI being tested. The simulation's
  emulation of historical x86 arithmetic is implemented in software; comments
  about the original GCC x86 behavior do not alone imply an x86 CPU requirement.
  Android Rust targets support `std`; see the
  [Rust platform documentation](https://doc.rust-lang.org/rustc/platform-support/android.html).
- Check native-library ELF and APK alignment for 16 KiB pages rather than
  assuming a modern Android phone uses 4 KiB pages. Android documents r28+
  alignment defaults and checking prebuilt libraries; validate both the Godot
  template and this Rust extension. See
  [Android native page-size support](https://developer.android.com/guide/practices/page-sizes).
- Mobile shader/driver behavior, CPU-side image composition/upload costs,
  sound buffering, focus/background pause and cold-start extraction remain
  device tests. Disable HD and CRT initially; add them only after a baseline.
- Without touch controls/gamepad, automatic demo playback is the first goal.
  Interactive ship control is not claimed. Basic tap-to-mouse menu behavior may
  work, but this investigation has not verified it.

## Initial local investigation results and limits

Read-only/source checks found:

- Android Studio SDK is present under `%LOCALAPPDATA%/Android/Sdk`, with adb,
  command-line tools, build-tools 36.0.0 and platform `android-37.0`.
- `JAVA_HOME` points at Android Studio's bundled Java, which reports 25.0.3.
  This is not the recommended JDK 17 baseline; build compatibility is untested.
- No NDK folder was found under that SDK. `cargo`, `rustc`, `rustup` and `godot`
  were not available on PATH; no rustup executable was found in the standard
  user `.cargo/bin` location. This is a tooling discovery result, not proof
  that no copy exists elsewhere on disk.
- WSL reports it is not installed. The generated Godot assets/native binaries
  are also absent from their normal project folders in this checkout.
- `adb devices -l` completed successfully but listed **no connected devices**.
  No phone settings, apps or files were changed.

At the end of that initial assessment, no tools had been installed, no extension
compiled, no APK exported and no performance measured. The conclusion was **technically feasible with modest
platform integration**, not “already Android-ready” or “tested on the A35.”

## Implementation validation (2026-11-17)

- Installed host Rust/Godot tools, the matching Android templates and NDK
  29.0.14206865; the ARM64 release GDExtension cross-compiled successfully.
- Generated host sprites, sounds, level scenes and both 41-track OPL soundtracks.
- Three Python tests passed (allowlist/hash manifest, ELF ABI/alignment, seekable APK asset storage).
  Eleven Godot bootstrap/path tests passed with zero failures/errors/orphans.
- The real 132-file bundle extracted and was reused without rewrites. Native
  readers loaded palettes/shapes/pictures, all five campaigns and all five demos;
  each demo advanced 350 simulation ticks on the Windows host.
- Godot exported and debug-signed `build/android/OpenTyrian2000-Enhanced.apk`.
  The helper verified the included ARM64 library, runtime ZIP, all packaged ARM64
  ELF LOAD alignments and APK 16 KiB alignment. This is build evidence, not a
  demonstration of the Android loader or rendering on the phone.
- Initial device discovery listed no device; it was subsequently connected for
  the phone validation below. The required Linux
  exported-package journey/smoke gate was unavailable because WSL is absent;
  it has not been claimed as passing. No commit or push was made.

## A35 phone validation (2026-11-17)

- Samsung SM-A356W: Android 16 / API 36, ARM64, 4096-byte pages, Mali-G68.
- Installed and updated the debug APK with `adb install -r` (no uninstall).
- Found minutes of black-screen startup from repeated decompression during
  Android compressed-asset seeks. A five-second simpleperf sample attributed
  about 99% of the game thread's sampled work to compressed-asset seeking/inflate.
  Storing APK assets without outer compression and staging the native ZIP before
  ZIPReader seeks resolved it. APK is realigned, re-signed and signature-verified.
- Cache reuse completed about 3 seconds after engine startup; a fresh 132-file
  extraction completed about 5 seconds after launch. These are log observations,
  not a full startup/frame-time benchmark.
- Observed the landscape title and the automatic gameplay demo, including terrain,
  ship, enemies, projectiles and explosions. The user confirmed working audio.
- A short Home/foreground round trip returned to a rendered title in the same
  process. Fresh extraction was tested by moving aside only the generated cache,
  then removing that temporary backup after successful regeneration.
- Still unverified: sustained frame pacing, a full campaign, lock/unlock,
  long background periods/process death, interactive save/settings persistence,
  and touch controls. Startup logs contain a Godot warning about the missing
  `xr/shaders/enabled` setting; no game-script/native crash was observed in this run.

## Acceptance checks for the implementation

Touch follow-up: `TouchFlight` now translates one held finger into absolute
steering plus continuous fire through the existing simulation mouse input.
The level receives correctly mapped touch coordinates and Android no longer
captures the pointer for relative mouse movement. Emulated mouse events do not
double-apply gameplay input; menu pointer/click handling is retained. Five focused
touch tests and ten display regression tests pass, including movement and firing
in the native simulation. On 2026-11-18 the follow-up APK was installed on the
SM-A356W without uninstalling the app. Android touchscreen swipe/hold gestures
in a live Endless level moved the ship left/right and vertically while firing;
screenshots captured the ship and projectiles at the changed locations. Menu
navigation still worked, and no new script/native error was seen in the app log.
The user also confirmed that holding/dragging a physical finger moves the ship
while firing. Other combat touch buttons remain
unimplemented; the earlier initial proof-of-concept validation above predates this change.
The additional DPI/demo regressions pass. The older mouse-speed suite reports
two failed assertions in one case on this Windows host: it expects twelve raw
pixels but Windows pointer gain reduces them to six. A comparison against the
committed pre-touch level produces the same six-pixel result after resetting the
gain accumulator; physical mouse behavior is unchanged. The Linux journey/smoke
gate remains unavailable without WSL.

- ARM64 library links, is packaged and loads; no unresolved native classes or
  GDScript parse errors in the device log.
- First install extracts all required data before native reads; second launch
  reuses it; app updates preserve the player's settings/saves.
- Title appears correctly in landscape, then a complete built-in demo runs
  without a controller, missing assets, crashes or sustained timing problems.
- Sound effects and MIDI or OPL music work; missing optional HD/mod folders do
  not prevent launch.
- Home/background/foreground and lock/unlock do not leave a black screen,
  runaway audio or an unrecoverable pause. Test on the actual A35, not solely
  an emulator.

Likely implementation files: `project.godot`, `export_presets.cfg`,
`tyrian.gdextension`, `scripts/game.gd`, `game_paths.gd`, `user_data.gd`, an
Android bootstrap/data manifest, a host build/package script, and focused path/
bootstrap tests. Most gameplay code should remain untouched. Keep desktop paths
and export behavior covered while adding Android.
