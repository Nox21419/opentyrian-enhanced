# Tests: the gate before every push

The maintainer found within two minutes of play that you could neither buy a weapon
in the shop nor see the chosen option in the pause menu, even though all the
checks passed. Those checks compared images (a hovered line lights up = pass) and replayed golden masters that never go through
the menus. Nothing verified that a player action has its effect.

Rule: **every push to `master`, and every build handed to the maintainer, first passes
the player journeys (all PASS) then `player-smoke.sh`**, locally
(WSL/Linux), on the exported Linux package.

```bash
rewrite/scripts/package.sh --only=linux          # or --build on the next command
rewrite/scripts/player-journeys.sh --core        # before every push: about 2 min 40 s
rewrite/scripts/player-journeys.sh               # full set, before a version is handed to the maintainer
rewrite/scripts/player-smoke.sh                  # images, golden masters, lint.sh; requires the run above
```

`rewrite/scripts/lint.sh` (called by `player-smoke.sh`, or on its own) checks
the formatting and warnings of all the maintained code, without rewriting anything:
cargo fmt and clippy `-D warnings` (Rust), gdlint, gdformat and Godot's
"unused" warnings treated as errors (GDScript), ruff (Python), shellcheck,
PSScriptAnalyzer (PowerShell, if `pwsh` is installed).
Configuration: `rewrite/rustfmt.toml`, `rewrite/godot/gdlintrc`,
`rewrite/godot/gdformatrc`, `ruff.toml`, `rewrite/scripts/PSScriptAnalyzerSettings.psd1`.
Tools: `uv tool install ruff==0.17.0`, `uv tool install gdtoolkit==4.5.0`,
`apt install shellcheck`, PowerShell 7 then `Install-Module PSScriptAnalyzer`.

Two games run at the same time (two Xvfb screens, never more). The core
(`--core`) plays nine lightened journeys at 1280x684; the full set plays all the
journeys in full, and the core also at 1920x1080.

`player-smoke.sh` fails (`player-journeys` check) if `player-journeys.sh`
did not pass everything on the same git head (commit and uncommitted
changes): the file `build/player-journeys.pass` proves it.

## Windows shutdown crash investigation (2026-11-26)

The intermittent `0xC0000005` reproduces on ordinary headless startup/quit, not
only in network tests. A fresh DbgEng capture reaches Godot's extension-instance
destruction with a freed (`0xfeeefeeefeeefeee`) class callback. Object IDs tie the
fault to the native SFX audio bus effect resource: AudioServer retains bus effects
past the autoload owners and extension-class teardown. Removing visual/static
caches did not fix it. A temporary probe that removes audio bus effects before
engine teardown exited cleanly in ten independent processes.

Implementation/validation plan: explicitly track the effects installed by Music
and Sfx and remove only those exact resources when their autoload exits, while
extension classes still exist. Stop channel/music streams first; let AudioServer
synchronize effect-instance destruction, then release owned resource references.
Keep `release_streams()` usable for its existing tests/runtime callers without
removing bus effects; effect removal belongs only to exit. Preserve playback,
mixing, settings and simulation/RNG behavior during play. Handle reordered or
renamed buses, repeated cleanup, enabled/disabled effects and unrelated effects.

Add lifecycle tests proving owned effects and their native instances disappear
before owner destruction, including real Music/Sfx owners, while foreign effects
remain. Add a short independent-process shutdown probe and repeat normal startup,
probe and previously crashing gdUnit/network journeys, checking actual OS process
codes and logs rather than only test summaries. Keep baseline failure and fixed
run counts in the final evidence. No package handover is part of this source fix.

### Fix and regression command

Music now records the exact effects it installs; Sfx already owns its channel
pan effects. On owner exit, streams stop and `audio_bus_lifetime.gd` removes those
effects from every bus before releasing their references. Matching by resource
identity preserves unrelated effects and handles renamed/reordered buses. Normal
stream release and live settings toggles do not remove effects. No native rebuild,
simulation change or runtime audio-processing change is involved.

Run the Windows process-level regression from the repository root:

```powershell
python rewrite/scripts/shutdown-check.py --godot build/toolchain/godot/Godot_v4.7.2-stable_win64_console.exe --runs 3
```

This runs three fresh processes **per mode**: ordinary startup/quit, an idle VGA
probe, and active widened OPL/SFX playback followed by the player's existing
`Game.quit_cleanly()` stream-drain path. It invokes the actual executable rather
than its console launcher, isolates each APPDATA profile under `build/`, records
logs, bounds each process and fails on nonzero OS exit, script errors, leaked
objects/resources or an incomplete probe. `SHUTDOWN_PROBE_READY` alone is never a
pass. Active playback deliberately uses the existing drain path: directly
calling SceneTree.quit while WAV/OGG audio is playing still produces the previously
documented built-in playback-resource warnings, separate from this native bus
effect lifetime defect.

Evidence on Windows with the same Godot 4.7.2 and native DLL:

- Before the fix, ordinary `--quit-after 2` crashed in 1 of 5 processes. Two fresh
  debugger captures identified the Sfx0 `TyrianStereoGain` resource (ObjectID
  `0x80000018c90006a0`) reaching a freed extension-class callback; the old crash
  dump faults at the same destruction path. Clearing visual caches did not fix it.
- After the fix, 12 ordinary startup/quit processes, 12 final idle/active probes
  and all 6 checker processes (`--runs 2`) exited 0 with no script errors or
  shutdown leaks: 30 clean repetitions. The initial abrupt-active probe confirmed
  the separate WAV/OGG drain warnings and was corrected to use the player's path.
- All 14 lifecycle, SFX-gain, music-widen, mute/freeze and music-engine cases passed
  with process exit 0. Lifecycle tests prove native resources **and instances**
  disappear before owner destruction and preserve foreign effects. Missing-MIDI/
  SoundFont fallback warnings in the music-engine suite are intentional fixtures.
- Both previously crashing ENet scene journeys (shop/story/adoption and held
  ending-score/leave) passed together and exited 0. Separate host/guest processes
  also exited 0 without script errors, executing 120 matching per-tick diagnostic
  hashes and matching configuration digests. The host alone had two local warmups.
  The development peer probe now defers frontend-dependent script loading until
  autoload globals exist; its earlier compile errors are not counted as evidence.

The dump reader, downloaded DbgEng binaries and exploratory probes remain ignored
under `build/`; no machine-wide debugger or crash-reporting settings were changed.
These are source/Windows lifecycle checks, not APK or exported-package validation.

## What a journey verifies

Each journey is played like a player: real keys and real X clicks
(xdotool, mouse moved in small steps), once with the keyboard only and once
with the mouse only, 1280x684 window (game ×3 letterboxed) then 1920x1080 for
the core. After each action, the effect is read back in the game itself:

- the `JourneyState` autoload (`rewrite/godot/tools/journey_state.gd`), active
  only with `--journey-state=<file>`, writes four times per second the
  scene, the open menu (chosen line, clickable areas), the shop (selected
  item, owned, money, lines marked on screen), the equipment, the level
  (pause, pause menu, F3/F4/F6 overlays, armor), the settings;
- the files written by the game: `saves/slot_NN.json`, `setup.cfg`,
  `endless_leaderboard.json`, F12 captures.

A PASS always rests on an effect: money = money − price + trade-in, equipment
slot changed, equipment mark on the right line of the image,
option changed then kept when reopening and after restart, save read back
identically. An image alone never makes a PASS.

| Journey | Core | Content (full set; the core keeps the essentials) |
|---|:-:|---|
| shop | yes | new game (Normal with keyboard, Hard with mouse), purchase in each category, sale of the rear gun, Ship Specs, data cube (core: front gun and left sidekick) |
| shop-easy | | same journey in Easy |
| pause | yes | 20 s of play, each pause option and each value, speed applied on resume, settings saved, F2-F12, Quit box No then Yes (core: one value per option, without F2-F12) |
| finish-level | | purchase, level finished (Ctrl+Shift+N, `--devmode`), debriefing, next shop: equipment and money kept |
| save-load | yes | purchase, Options > Save Game, name entered, back to the title, Load Game: same money, equipment, section |
| title | yes | each title entry, Setup (Graphics, Sound, Gameplay: value changed and kept; Jukebox, Mods, Keyboard), Quit, restart: settings kept (core: Setup > Gameplay, Quit, restart) |
| arcade-1p, arcade-2p | | Arcade Game Menu: each line, Options, Start Level, Quit |
| endless | | 25 s of Endless, Quit, name, summary, leaderboard: final score recorded |
| maintainer-profile | yes | copy of the maintainer's actual user folder (`--profile`): his save loads, the shop buys (core: with keyboard) |

Results: `build/player-journeys/report.md` (table, each FAIL with its
capture), `steps.jsonl`, `shots/`.

## Adding a journey

A function `journey_<name>(g, rep, mode)` in
`rewrite/scripts/player_journeys.py`, registered in `JOURNEYS`. Each action
is followed by a `rep.check(action, expected, observed, condition)` whose
condition reads the state (`g.state()`) or a game file. If the effect to verify
is not in the state, add it to `journey_state.gd` (read-only).
