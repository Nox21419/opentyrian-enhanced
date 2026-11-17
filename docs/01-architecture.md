# Architecture of the Godot 4 + Rust engine

Updated from the repository on 2026-11-17. Historical C source citations refer to
tag `c-final`; the C engine is no longer in this checkout (ADR 0132).

## 1. Toolchain and dependencies

| Component | Version | Repository source |
|---|---|---|
| Godot | **4.7.2 stable**, standard build | build scripts and export templates |
| godot-rust / gdext (crate `godot`) | **0.5.5**, feature `api-4-7` | `rewrite/Cargo.toml` and `Cargo.lock` |
| Rust | **≥ 1.94** | workspace `rust-version`; use the build guide for setup |
| `png` | 0.18 | workspace manifest/lockfile |
| `serde` / `serde_json` | 1.0 | workspace manifest/lockfile |
| `clap` | 4.6 | workspace manifest/lockfile |
| `anyhow` | 1.0 | workspace manifest/lockfile |

The simulation core depends on the local `tyrian-formats` crate, with no Godot
dependency, hardware floating-point gameplay arithmetic or randomness crate.

## 2. Directory layout

The maintained engine lives under `rewrite/`; original game data stays in root
`data/`. The workspace has nine crates. The retired C engine can be checked out
separately at `c-final`; only its frozen OPL rendering sources remain in
`rewrite/tools/music-render/c/`.

```
rewrite/
  Cargo.toml                  workspace Cargo
  crates/
    tyrian-formats/           byte-exact reading/writing of the original formats (lib)
    tyrian-sim/               deterministic simulation core, no Godot (lib)
    tyrian-render/            palettized 8-bit surfaces, blitters and fonts
    tyrian-mods/              mod loading, validation and catalogs
    tyrian-import/            CLI: data/ → Godot resources (PNG + JSON)
    tyrian-golden/            CLI: replays a C golden master in the Rust core and compares
    tyrian-godot/             GDExtension (cdylib): gdext bridge Godot ↔ tyrian-sim
    tyrian-robustness/        seeded stress/reproducibility tests
    tyrian-dodge-bot/         unassisted driver and difficulty benchmark
  godot/                      Godot 4.7 project (rendering, UI, audio, level editor)
    project.godot
    tyrian.gdextension
    scenes/  scripts/  shaders/  editor/  assets/imported/ (generated, git-ignored)
  golden/                     reference replays produced by the instrumented C version
  scripts/                    builds, packages, tests, captures and HD pipeline
```

## 3. Simulation core (`tyrian-sim`)

- **Cadence**: one `step` = one tick of the original game, i.e. ≈ 34.8 Hz at Normal speed (`config.c:JE_setNewGameSpeed`, `speed = 0x4300`, `frameCountMax = 2`). Godot calls `step` from `_physics_process` with `physics_ticks_per_second = 35`; bullet time slows the **calling clock**, never the logic (ADR 0003).
- **Arithmetic**: integers only. C floating-point calculations (Link Gun, orbiting sidekicks, firing directions, difficulty multipliers) are reproduced with software IEEE-754 arithmetic and exact rational rounding in `f32ops.rs` and `fmath.rs` (ADR 0003), rather than replaced by approximate tables. Known differences are recorded in `docs/divergences.md`.
- **RNG**: hand-written xoshiro256**, same algorithm as `src/rng.c`, so that the C draws can be reproduced; explicit seed. Visual effects never touch it (Godot has its own cosmetic randomness).
- **API**:
  - `Sim::new(LevelSetup) -> Sim` (level data, loadout, seed and options)
  - `Sim::step(&mut self, inputs: [PlayerInput; 2])`
  - `Sim::state(&self) -> &SimState` (read-only for Godot)
  - `Sim::snapshot() -> Vec<u8>` (canonical serialization for hashing/tests)
  - `Sim::state_hash() -> u64` (FNV-1a 64 over a canonical serialization) and `Sim::frame_record()`, which exposes the same fields as the C golden master, for a field-by-field comparison.
- **Per-tick order**: reproduces that of `tyrian2.c:JE_main` (`level_loop`): events → scroll → ground enemies → random spawn → sky/top enemies → player shots → player collision → player movement → enemy shots → explosions.

## 4. Godot layer

- Godot **reads** the state (`SimState`) on every render frame and owns none of it. The `TyrianSim` node (GDExtension) exposes `load_level`, `step`, `get_player`, `get_enemies` (PackedInt32Array), `get_shots`, `get_scroll`, `state_hash`.
- Rendering: Original-mode playfield composition uses palette indices through `tyrian-godot/src/playfield.rs` and `PlayfieldBackground`; menus and HUD use `TyrianVga`/`TyrianScreen` and `tyrian-render` (ADR 0020). Godot nodes, pooled sprites and projectile MultiMeshes supply the other rendering paths and overlays. Logical coordinates remain 320×200; scaling and CRT options apply at presentation time.
- HD (AI): whole background maps are upscaled offline and streamed as WebP strips; sprites and interface images use ×4 assets, with sharp text rendering. It changes presentation, not simulation. See the build guide and the later addenda of ADR 0100.
- Level editor: the Godot editor itself. Each imported level becomes a `.tscn` scene (3 `TileMapLayer`) plus a `LevelEvents` resource (`.tres`, custom resource `LevelEventResource`). A plugin button launches the game at a given scroll position (ADR 0005).
- Compatibility rendering (`gl_compatibility`) by default: works under Xvfb/Mesa for captures, and on any GPU.

## 5. Import (`tyrian-formats` + `tyrian-import`)

- `tyrian-formats` reads and rewrites the supported original formats described in `docs/formats-spec.md`. Areas the C code does not read (tails, residual bytes, unused table entries) are kept as-is. Tests require `read → write` to be identical byte for byte on covered fixtures; the crate README lists unsupported and external resources.
- `tyrian-import` produces, in `rewrite/godot/assets/imported/`: PNG tile atlases (per `shapesX.dat` × palette), PNG sprite sheets, `levels/epN_lvlM.json` (layers, `mapSh`, events, enemies), `items.json` (HDT tables), sounds as WAV. A headless Godot pass (`editor/build_levels.gd`) turns the JSON files into `.tscn` scenes + `.tres` resources.

## 6. Audio strategy (ADR 0004)

- **Effects**: `tyrian.snd` / `voices.snd` converted to WAV (signed 8-bit 11,025 Hz PCM → unsigned 8-bit WAV), played by `AudioStreamPlayer`.
- **Music**: Setup > Sound offers Classic (offline DOSBox OPL), Authentic (offline Nuked OPL3) and Enhanced (MIDI through rustysynth and `data/soundfont.sf2`). Enhanced is the default for a new profile; saved choices are retained/migrated. The OPL tool uses frozen sources under `rewrite/tools/music-render/c/`. Missing MIDI/SoundFont or Authentic renders fall back to OPL/Classic. See `setup-options.md`, ADR 0130 and `asset-rights.md`.

## 7. Build

- Linux/WSL (reference, used for all tests and captures): `rewrite/scripts/build-linux.sh` → `cargo build --release` then copy `libtyrian_godot.so` into `godot/bin/`.
- Windows: `rewrite/scripts/build-windows.ps1` (`cargo build --release --target x86_64-pc-windows-msvc`, or cross-compilation from WSL to `x86_64-pc-windows-gnu` with mingw-w64). See `docs/build.md`.

## 8. ADRs

- [0001](adr/0001-oracle-master.md) — original C oracle selection (historical).
- [0002](adr/0002-workspace-layout.md) — code under `rewrite/`; current members are in `rewrite/Cargo.toml`.
- [0003](adr/0003-fixed-tick-35hz.md) — fixed step at the original tick (≈ 34.8 Hz), integers only, xoshiro256** RNG reproduced.
- [0004](adr/0004-audio.md) — SFX converted to WAV and OPL music rendered offline; MIDI exclusion superseded by 0130.
- [0130](adr/0130-midi-music-rustysynth.md) — optional MIDI music (rustysynth + SoundFont), per-track OPL fallback.
- [0005](adr/0005-level-editor.md) — the Godot editor as level editor (generated TileMapLayer scenes).
- [0006](adr/0006-golden-master-format.md) — golden master by inputs + field-by-field state record.
- [0132](adr/0132-removal-of-the-c-version.md) — C removal, `c-final`, frozen parity references.

The complete documentation and decision index is in [AGENTS.md](../AGENTS.md).
