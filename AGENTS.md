# Master repository context and documentation map

Reviewed 2026-11-17 against commit `516f2bb` and the documentation corrections in the working tree. This is the entry point for agents
working in this repository. Read this file first, then load the documents for
the task below. Keep detailed specifications in their source documents rather
than copying them into this file.

## Commit authorization

- **NEVER commit without the user's express direction to do so.** Completing
  work, passing checks, or being asked to fix or prepare changes does not
  authorize a commit.
- Each direction to commit authorizes **one commit only**. Once that commit
  is made, the authorization is spent; it does not carry forward to later
  changes or the rest of the session. Obtain fresh express direction before
  making any additional commit, including an amend.

## Frontend fidelity

- Before implementing or building any requested change that affects the
  frontend, present a few concrete design directions, explain the relevant
  tradeoffs and recommend one. Wait for the user to choose the direction before
  implementing or building it. This also applies when a frontend change is a
  consequence of a broader request. Read-only investigation may proceed first.
- Keep frontend changes as faithful to the original Tyrian 2000 as possible
  on every platform. Preserve its fonts, palette, artwork, outlines, selection
  highlights, sounds and navigation behavior wherever practical.
- For touch or other platform adaptations, first reposition or resize the
  original interface and its hit areas. Avoid replacing it with generic widgets
  or drawing a second interface over it when the original can be adapted.
- Keep platform-specific adaptations scoped to that platform and preserve
  existing desktop mouse, keyboard and gamepad functionality. Work on one menu
  screen at a time so the maintainer can test each change before the next.
- See [Frontend fidelity guidance](docs/setup-options.md#frontend-fidelity)
  for the accepted Android title-menu example.

## Android gameplay preservation

- While getting Android working, **do not modify game mechanics from the
  original Tyrian 2000**. Android platform and input adaptations must preserve
  gameplay rules, movement speed limits, simulation timing, collisions, damage,
  balance and gameplay RNG behavior. Existing intentional divergences are not
  permission to introduce further mechanics changes for Android.
- If a proposed change might affect game mechanics and its effect is uncertain,
  investigate the original behavior and the affected implementation first, then
  explain the findings and remaining uncertainty and **ask the user for express
  approval before implementing that change**. Do not treat an unverified
  assumption of equivalence as authorization.
- See [Android build instructions](docs/android-build.md#gameplay-preservation)
  for the accepted touch-control adaptation and the Android-specific policy.

## GitHub account

- Always use GitHub account **Nox21419** for this repository. The canonical
  remote is `https://github.com/Nox21419/opentyrian-enhanced.git`. Do not ask
  which account to use for each commit or push.
- Repository-local Git credentials use `gh auth git-credential` with username
  `Nox21419`. Reuse the stored login; request user action only if authentication
  actually fails and cannot be resolved with the existing credentials.
- The GitHub login is separate from Git commit author name/email; do not change
  the author's identity merely to match the GitHub username. The one-commit
  authorization rule above still applies.

## Reading order

1. At the start of a new task, read [README.md](README.md) for product scope and
   [docs/testing.md](docs/testing.md) for validation requirements. Check the
   working tree before editing; preserve unrelated local changes.
2. Choose the matching task row below and read its documents before changing
   that subsystem. Read relevant sections of long references, including later
   addenda, rather than rereading every document for every task.
3. Inspect the implementation, manifests and scripts named by those documents.
   Documentation contains historical snapshots; verify commands, defaults and
   claims about missing features against the current checkout.
4. Before completing work, run the checks appropriate to the change and report
   what actually ran. Before a push to `master` or handing over a game build,
   follow the exported-package gate in `docs/testing.md`.
5. When behavior or structure changes, update the affected source docs and this
   map if their routing or status changes. After context loss, start here again
   and reread the task-specific sources; this file is persistent context, not
   a claim that all source details remain in memory.

## Project facts to retain

- The maintained game is Godot 4 + Rust under `rewrite/`. The old C engine was
  removed; its reference checkout is tag `c-final` (ADR 0132). References to
  root `src/`, `Makefile`, C test commands and removed recording scripts are
  historical, not instructions to recreate them.
- `rewrite/Cargo.toml` currently lists **nine** crates: `tyrian-formats`,
  `tyrian-sim`, `tyrian-mods`, `tyrian-import`, `tyrian-golden`, `tyrian-godot`,
  `tyrian-robustness`, `tyrian-render`, and `tyrian-dodge-bot`. Historical ADR snapshots list
  five or eight. Use the manifest and lockfile for dependency versions.
- Gameplay belongs in `tyrian-sim`; Godot owns presentation, input, audio and
  editor integration. The bridge is `tyrian-godot`; palettized rendering is
  `tyrian-render`. Preserve deterministic ticks, integer/software IEEE-754
  arithmetic, and gameplay RNG consumption (ADR 0003). Normal Godot pacing is
  35 ticks/s; rendering and speed controls do not redefine a simulation step.
- Original data is in `data/`. Binary readers/writers preserve unread bytes for
  byte-exact round trips. Imported assets, native binaries, level scenes and HD
  outputs are generated; see `docs/build.md` before rebuilding or editing them.
- C golden masters prove parity only for their covered scenarios. Passing them
  does not prove menus, purchases, settings persistence or every gameplay path.
  Fix inherited defects deliberately; do not add a C-bug compatibility mode.
- Mods use the single `"format_version": 1` format, named content and strict
  validation. Do not revive C mod formats or numeric content identifiers.
- Five packs ship disabled and can be enabled together: 14 ships, 70 ship pose
  PNGs and 18 weapons. `_retired/` contains tested examples, not shipped content.
- Exported Windows/Linux player files normally live in adjacent `userdata/`,
  with a Godot user-folder fallback. Editor sessions use the Godot user folder.
  macOS uses `~/Library/Application Support/OpenTyrian2000 Enhanced/`; shipped
  resources are in the app's `Contents/Resources/`. Never assume repo-relative
  or executable-adjacent writable paths apply on every platform.

## Read these documents when doing this work

Paths in this table are relative to the repository root. ADR numbers link to
their full paths in the decision index below.

| Task / trigger | Read before editing | Read for details / verification |
|---|---|---|
| Network play, two-phone co-op, LAN or internet connections | [Network co-op plan, ledger and input audit](docs/network-coop.md), [Android build](docs/android-build.md), ADR 0003 | Host/Join, Episode, Difficulty, host-operated original Arcade Game Menu, Options and shared lobby Ready approved; original full two-player HUD chosen for both phones; detached original-HUD presentation approved; assigned touch capture tested; scoped session-effect timing approved; isolated effects and explicit clock tested; Android-only first-level player-menu handoff tested in source; no two-phone verification or APK handover; content freeze, catalog/rule checks, detached level preview and diagnostic comparison tested; original entry fade and two-view barrier implemented; synchronized host-operated original Pause menu implemented in source, guest sees PAUSED; focus/disconnect returns to lobby; original Statistics on both phones with host-only advance approved; completion/phase agreement source-tested; first-level original Statistics handoff wired in source, host advances both and final fades precede lobby exit; campaign progression and internet pending; intermittent Windows shutdown crash unresolved; `network_player_completion_test.gd`, `network_completion.gd`, `network_completion_connection_test.gd`, `network_level_result.gd`, `network_debrief.gd`, `network_pause.gd`, `network_pause_menu.gd`, `network_pause_flow_test.gd`, `network_player.gd`, `network_level.gd`, `network_tick_clock.gd`, `network_tick_clock_test.gd`, `network_touch_view_test.gd`, `network_ready_lobby_test.gd`, `network_session.gd`, `network_gameplay_connection.gd`, `network_touch_runner.gd`, `network_touch_inputs.gd`, `network_options.gd`, `network_arcade_menu.gd`, `network_preparation.gd`, `network_content_snapshot.gd`, Rust `network_load.rs`, `network_state.rs`, `network_mice.rs` and network tests; diagnostics include observer state, not a live desync detector; review one frontend screen at a time |
| First orientation or cross-cutting architecture | [Architecture](docs/01-architecture.md), ADRs 0002, 0003, 0131, 0132 | Current `rewrite/Cargo.toml`; architecture reflects the current workspace and rendering paths |
| Build, launch, imports, native DLL/.so or missing assets | [Build guide](docs/build.md) | Platform build scripts, `tyrian.gdextension`, `project.godot`, `export_presets.cfg`; ADR 0100 for HD assets |
| Android feasibility or phone build | [Android build](docs/android-build.md), [Android investigation](docs/android-feasibility.md), [Build guide](docs/build.md) | `build-android.py`, ARM64 GDExtension, private data extraction; A35 Android 16 title/demo/audio verified; uncompressed APK assets avoid slow seeks; `TouchFlight` steers/fires from one held finger; title, Players/Episode/Difficulty/Timed Battle, shop menus (including child screens), Setup and its children (including Jukebox and Mods; the five packs are bundled), High Scores, Replays, Load Game, Instructions/Help, Achievements, Side Modes, end-of-level Statistics and Pause/Quit adapted for touch; Save Game name entry opens the Android keyboard; Destruct intro/mode menu, pause text and Help footer accept touch; left-packed in-level manual sidekick/Mode touch controls (Mode hidden without alternate patterns/specials) and an equipped-only Special button above them (moves down when alone) (exclusive Android activation, dimmed during cooldown; replay v5) and top-right Android score implemented; all six difficulties shown by default and Setup > Secrets exposes the nine Super Arcade ships, both Super Tyrian difficulties and Destruct; Pause > More exposes achievements/statistics, campaign quick save/load, replay recording and secondary display/capture actions; Android Setup > Controls enables optional tilt flight with saved sensitivity, level-start neutral and Pause > Controls for shared settings/reset (A35 pause Controls checks verified); Destruct live rounds have two original-font touch banks (held directions/fire, release-to-switch vehicle/weapons), with New Map and both Human/Computer toggles in Pause; focus loss pauses and clears touch input |
| Gameplay, enemies, shots, collisions, arithmetic, RNG | [Parity](docs/parity.md), relevant entries in [Divergences](docs/divergences.md), ADRs 0003, 0006 | [Events](docs/events-spec.md) for scripts; [Robustness](docs/robustness.md); ADR 0040 for Zinglon ownership |
| Binary formats, import/export, sprite decoding, original tables | [Formats specification](docs/formats-spec.md), [formats crate README](rewrite/crates/tyrian-formats/README.md) | [Historical HDT notes](data/doc/tyrian.hdt.txt), ADR 0128 for generated original names; byte-exact round-trip tests |
| Menus, shop, mouse, overlays, UI rendering | [Setup options](docs/setup-options.md), relevant [Divergences](docs/divergences.md), ADRs 0020, 0120–0123 | [UI reference README](rewrite/golden/ui/README.md), player guide §§2–4; ADR 0110 is historical shop context |
| Controls, gamepads, shortcuts, help, Steam Deck | [Player guide §2](docs/PLAYER-GUIDE.md), ADRs 0051, 0120, 0133 | Divergences 21, 27b, 28b, 31, 33, 45, 54, 57; `controls.gd`, `level_hotkeys.gd` and Steam Deck config |
| Display, CRT, scaling, HD maps/sprites/UI | [Build guide HD section](docs/build.md), [Setup options](docs/setup-options.md), ADRs 0100, 0124 | Divergences graphics section and entries 41, 47, 55, 56, 58–60; read the later HD addenda |
| Particles, hitstop, modern explosions, damage numbers | [Setup options](docs/setup-options.md), [Divergences](docs/divergences.md) modern-explosion section and entries 7–8, 59a | ADRs 0003, 0020, 0122; separate presentation randomness from gameplay |
| Audio, OPL rendering, MIDI, sound settings | [Setup options](docs/setup-options.md), ADRs 0004, 0010, 0130 | Formats §§8,10; Divergences 23, 63; [Asset rights](docs/asset-rights.md); actual `music.gd` engine numbering |
| Campaign, saves, profile migration, data paths | ADRs 0126, 0129, [Player guide §§3.2,6](docs/PLAYER-GUIDE.md) | Divergences 22, 24–26, 37, 40, 59b; [C save fixtures](rewrite/crates/tyrian-formats/tests/saves/README.md); `game_paths.gd`, `user_data.gd`, `c_profile.gd` |
| Endless, combos, anomalies, side modes, achievements | ADRs 0050, 0071, 0072, 0091; [Player guide §3](docs/PLAYER-GUIDE.md) | [Endless reference README](rewrite/golden/endless/README.md), Divergences 5–6, 29, 34–38; anomalies are opt-in tooling, not a normal shipped menu feature |
| Replays, demos, golden master generation/comparison | ADRs 0006, 0090, 0127, 0132; [Parity](docs/parity.md) | Divergences 27a, 30, 32; `.gm` inputs, `.rep` positions and UI frame hashes are different reference types |
| Mod loader/schema, install ZIPs, item names, limits, campaign weapon/ship stock | [MODDING.md](MODDING.md), [Weapon and ship progression](docs/mod-weapon-progression.md), ADRs 0083, 0128, 0134 | ADRs 0080–0082 for rationale only; `rewrite/mods/mod.schema.json`, `original-names.json`, [pack index](rewrite/mods/README.md) |
| Create/edit a level, editor dock, launch at scroll position | [First level tutorial](docs/FIRST_LEVEL_15_MIN.md), MODDING §§7–8,12; ADRs 0005, 0082, 0126, 0128 | [Event semantics](docs/events-spec.md), [mod template](rewrite/mod_template/README.md), [level template](rewrite/mod_template/levels/README.md); editor exports the complete event list |
| Create/balance pack art, weapons, ships or shot animations | [Mod art pipeline](docs/mod-art-pipeline.md), MODDING §§5–6; the affected pack README below | ADR 0134; Python art/balance/preview helpers; inspect references and in-game captures |
| Performance or projectile batching | [Performance](docs/performance.md), ADR 0060 | Separate native GPU timings from WSL software rendering; use current bench scripts, preserve simulation behavior |
| Crashes, invalid equipment, determinism stress tests | [Robustness](docs/robustness.md), [Testing](docs/testing.md) | Reproduce bot failures by ID, use robustness profile; mod resource bounds in MODDING §9 |
| Add/change Godot tests or UI references | [Testing](docs/testing.md), ADR 0084, [UI references](rewrite/golden/ui/README.md) | Suites under `rewrite/godot/test/`, `godot-tests.sh`, `ui_regression.sh`; intentional reference updates require review |
| Localization, menu labels, fonts or translated README copy | README and the affected language README; [Setup options](docs/setup-options.md), [font QA preview](data/reference/fonts/preview.html) | `data/locales/`, locale/glyph/width/cube checks in `utils/`, `utils/c_tables.json`, `utils/locale_same_as_english.txt`; six game languages, Russian README does not imply Russian gameplay |
| Packaging, release version, notices, clean install | [Build packaging sections](docs/build.md), [package README](rewrite/packaging/README.txt), [HD pack README](rewrite/packaging/HD-PACK-README.txt), [Asset rights](docs/asset-rights.md) | [Release notes](docs/release-notes-v1.0-rc1.md), all README translations, [Testing](docs/testing.md), current workflow; package version starts in `project.godot` |
| macOS build, paths, signing, QA | Build guide macOS section, [macOS test checklist](docs/macos-test-checklist.md), player guide §§1,6 | `package.sh`, `build-macos.sh`, `test-package-macos.sh`, export presets and workflow; resolve conflicting OS minimum/release claims from actual build configuration |
| Screenshots, trailer, public feature claims | [Marketing README](marketing/README.md), [README](README.md), player guide, release notes | Capture tools and actual media; verify feature claims against implementation |
| Asset redistribution or third-party notices | [Asset rights](docs/asset-rights.md), [COPYING](COPYING), [TimGM6mb license](rewrite/licenses/TimGM6mb-LICENSE.txt), [rustysynth license](rewrite/licenses/rustysynth-LICENSE.txt) | Formats §13, package-generated `DATA-NOTICES.txt`, addon/shader source notices; do not treat game data as covered by the code license |

## Validation at the right time

For a documentation-only change, check links, coverage and `git diff --check`.
For code changes, choose the relevant Rust crate tests, gdUnit4 suites, strict
parity, UI regressions, mod checks, locale checks or robustness tests from the
task row. Read script help before assuming old command examples still work.

The existing gate in `docs/testing.md` requires these checks on the **exported
Linux package**, locally under WSL/Linux, before every push to `master`:

```bash
rewrite/scripts/package.sh --only=linux       # or use --build below
rewrite/scripts/player-journeys.sh --core
rewrite/scripts/player-smoke.sh
```

Run the full `player-journeys.sh` set before handing a build to the maintainer.
Smoke requires a successful journey run on the same HEAD **and working tree**;
it also calls `lint.sh`. A successful screenshot is not proof a purchase,
setting change or save took effect: journeys check state and written files.
Report unavailable checks explicitly rather than claiming the gate passed.
Do not run the game/package gate merely to add or edit documentation.

## Decision index: load by topic, follow supersession

All 39 ADRs are indexed here. Dates, evidence counts and unfinished-work lists
inside them describe their recording time, unless updated by an addendum.

| ADR | Read when / status note |
|---|---|
| [0001 — Oracle](docs/adr/0001-oracle-master.md) | Original C baseline selection; historical `master`, now frozen at `c-final` via 0132 |
| [0002 — Workspace](docs/adr/0002-workspace-layout.md) | Crate responsibilities; eight-crate count superseded by current nine-member manifest |
| [0003 — Fixed ticks](docs/adr/0003-fixed-tick-35hz.md) | Determinism, software float reproduction, clock and RNG boundaries |
| [0004 — Audio](docs/adr/0004-audio.md) | WAV/offline OPL rationale; MIDI exclusion superseded by 0130 |
| [0005 — Editor](docs/adr/0005-level-editor.md) | Godot scenes/TileMapLayer as editor substrate |
| [0006 — Golden masters](docs/adr/0006-golden-master-format.md) | Input/state reference format and C instrumentation provenance |
| [0010 — Music](docs/adr/0010-music.md) | Offline OPL loops, fades and simulation cue isolation; later sound options extend it |
| [0020 — VGA interface](docs/adr/0020-framebuffer-8-bit-interface.md) | Palette-index rendering, OTFR sequences, exact UI comparisons |
| [0040 — Zinglon](docs/adr/0040-zinglon-playernum-uninitialized.md) | Undefined ownership fixed, comparator exception removed |
| [0050 — Side modes](docs/adr/0050-side-modes-access.md) | Dedicated M screen; initial access gaps are historical |
| [0051 — Controls](docs/adr/0051-controls-inputmap.md) | Shared actions, devices, Steam Deck; current shortcuts/shoulders extend initial mappings |
| [0060 — Bench API](docs/adr/0060-bench-api-tyrian-sim.md) | Test-only shot capacity/injection without changing normal limits |
| [0070 — WIP evaluation](docs/adr/0070-wip-sept-2026-evaluation.md) | Historical branch/mod inventory and rejected imports; not a current pack list |
| [0071 — Endless](docs/adr/0071-endless-mode.md) | Rotation, armor, lives, saves; 0072 extends scope, E shortcut later removed |
| [0072 — Endless extensions](docs/adr/0072-endless-combos-anomalies-two-player.md) | Fixed-clock combos, anomaly deck, two players and resume choices |
| [0080 — Mod validation](docs/adr/0080-mod-format-and-validation.md) | Trust boundaries/bounds; format details superseded by 0083, 0128, 0134 |
| [0081 — Behaviors](docs/adr/0081-data-driven-behaviors.md) | Data-driven paths/tracking/turrets; old format fields superseded |
| [0082 — Creation kit](docs/adr/0082-creation-kit.md) | Template/dock/export rationale; 0083 and 0128 define current syntax |
| [0083 — Single mod format](docs/adr/0083-single-mod-format.md) | Required version, names, unknown-key errors; 0128 also names original content |
| [0084 — gdUnit4](docs/adr/0084-tests-godot-gdunit4.md) | Test framework, isolated profile, errors/orphans/no-tests must fail |
| [0090 — C replays](docs/adr/0090-c-replays-played-back.md) | Position-injection semantics; C playback is the reference, initial mode exclusions are historical |
| [0091 — Achievement clock](docs/adr/0091-achievement-clock.md) | Nominal deterministic game time versus wall time |
| [0100 — HD/packages](docs/adr/0100-hd-sprites-and-packages.md) | Read all relevant addenda: atlas experiments give way to whole maps and HD interface |
| [0110 — Shop VGA](docs/adr/0110-shop-vga-rendering.md) | Early shop rendering; incomplete-screen lists are historical |
| [0120 — Menu input](docs/adr/0120-menu-inputs-inputmap.md) | Shared actions, capture path, safe binding conflicts |
| [0121 — Menu engine](docs/adr/0121-single-menu-engine.md) | Shared models/styles/navigation; open menus in `_run`, not virtual `_draw` |
| [0122 — Interface layer](docs/adr/0122-shared-interface-layer.md) | Overlay providers and shared drawing helpers |
| [0123 — Shop engine](docs/adr/0123-shop-on-menu-engine.md) | Rust shop logic, external menu engine rendering; old remaining-work list is historical |
| [0124 — Display settings](docs/adr/0124-display-settings-single-file.md) | Unified persistence/application; later build/setup docs supersede early HD restriction |
| [0125 — Autopilot](docs/adr/0125-autopilot-outside-player-flow.md) | Assists only through explicit tools, outside ordinary player flow |
| [0126 — Level launch](docs/adr/0126-single-level-launch.md) | `Game.start_level_at`, editor request; addendum removes unused level-select screen |
| [0127 — Reference writer](docs/adr/0127-references-written-by-the-rewrite.md) | Recompute/check reference state from scenarios; 0132 limits claims of new C parity |
| [0128 — Original names](docs/adr/0128-original-content-names.md) | Named originals/events/damage, catalog generation and episode table differences |
| [0129 — Campaign saves](docs/adr/0129-native-campaign-save.md) | Versioned atomic per-slot JSON, strict reads, one-time C import |
| [0130 — MIDI](docs/adr/0130-midi-music-rustysynth.md) | rustysynth, loops, fallback; setup-options documents later three-engine numbering/default |
| [0131 — Rewrite replaces C](docs/adr/0131-the-rewrite-replaces-the-c-version.md) | Main product transition; removal schedule superseded by 0132 |
| [0132 — C removal](docs/adr/0132-removal-of-the-c-version.md) | Frozen references, `c-final`, retained OPL C code and tables; workflow triggers changed later |
| [0133 — Level shortcuts](docs/adr/0133-c-level-shortcuts.md) | In-level keys versus menu keys; Left Shift slow motion; later F8 mute in divergences 57 |
| [0134 — Pack limits](docs/adr/0134-mod-limits-for-the-shipped-packs.md) | Five simultaneous packs, ship poses, original sprite protection and shop capacities |

## Remaining documentation inventory

| Document(s) | Load when |
|---|---|
| [German](README.de.md), [Spanish](README.es.md), [French](README.fr.md), [Italian](README.it.md), [Portuguese](README.pt-BR.md), [Russian](README.ru.md) READMEs | Translating or changing public features, download instructions, controls and credits; keep aligned with English |
| [Alien ships](rewrite/mods/alien_ship_pack/README.md), [Bio ships](rewrite/mods/bio_ships_pack/README.md) | Ship prices/armor, five poses and pack-specific art recipes |
| [Alien weapons](rewrite/mods/alien_weapon_pack/README.md), [Bio weapons](rewrite/mods/bio_weapons_pack/README.md), [Elements weapons](rewrite/mods/elements_weapon_pack/README.md) | Roles, 11-level DPS/energy tables, shot frame naming and deterministic art regeneration |
| Retired [Alien Pack](rewrite/mods/_retired/alien_pack/README.md), [Alien Ships](rewrite/mods/_retired/alien_ships/README.md), [Nova Weapons](rewrite/mods/_retired/example_nova_weapons/README.md), [Behaviors](rewrite/mods/_retired/example_behaviors/README.md) | Worked examples/conversion tests only; not shipped or loaded by default |
| [Tyrian Codex](data/reference/codex.html) | Generated game/lore/equipment/bestiary/data-cube reference; inspect relevant records, validate mechanical/rights claims against current specs and data |
| [Weapons reference](data/reference/weapons_reference.html) | Generated weapon-to-shot visual catalog; embedded images/table rows are reference data, not engine/mod instructions |
| [gdUnit4 assertion guide](rewrite/godot/addons/gdUnit4/src/asserts/CLAUDE.md), [addon license](rewrite/godot/addons/gdUnit4/LICENSE) | Only when maintaining vendored assertion code or its notices; local addon guidance does not govern unrelated game code |

Review scope: repository Markdown guides/READMEs (including translations and all
ADRs), package text instructions, legacy HDT notes and license notices were read.
Generated HTML catalogs were inspected for structure and representative content;
their thousands of data records and embedded images are lookup material. Locale
strings, golden tick/frame/unlock text, formatter exclusion lists, schemas,
manifests and report HTML templates are data/configuration, not prose guides;
read relevant entries when their subsystem is touched. External wiki/web pages
linked by docs were not part of this repository review.

## Historical documentation and remaining reference limits

The 2026-11-17 correction pass updated the architecture, build/player guides,
Setup regression guidance, package instructions, release notes and mod examples.
It corrected shop purchase/hover behavior, restored Options settings, contextual
shortcuts, audio defaults, version-2/two-player save support, macOS minimums, data paths, wheel scrolling, license
notices and manual CI triggers. Historical ADRs now carry status notes where
later changes supersede their original scope or consequences.

Continue to apply these distinctions:

- **Historical ADRs:** read the current-status note and later addenda before
  treating an original decision's implementation limits as present behavior.
  In particular, ADRs 0100/0124 preserve the HD atlas experiments and temporary
  restriction; current HD uses whole maps and is offered with installed assets.
- **Reference evidence:** ADR 0127 can recompute existing scenarios, but output
  from the rewrite is not new independent C evidence. ADR 0132 requires a
  separate `c-final` checkout for new C recordings. Review intentional diffs;
  never regenerate blindly to hide a regression. Counts and image measurements
  in parity/ADR tables are dated evidence, not current coverage guarantees.
- **CI/releases:** `.github/workflows/rewrite.yml` enables only
  `workflow_dispatch`. Its release job is conditional on a `v*` tag ref during
  manual dispatch; pushes/tags alone do not start it. Check the actual workflow
  before relying on automation, and the release page before claiming which
  artifacts are available. Archive sizes in initial release notes are historical.
- **macOS:** export presets configure 10.13+ on Intel and 11+ on Apple Silicon.
  These are configured deployment targets, not proof of testing on every OS.
- **Generated/legacy references:** `data/doc/tyrian.hdt.txt` is explicitly marked
  historical; prefer `formats-spec.md` and round-trip tests. The HTML Codex and
  weapons catalog are lookup material with historical calculations/records,
  not current engine specifications. They now identify that limitation and
  point to current mechanics/mod/rights sources.
- **Missing historical material:** `docs/legacy/MODDING-c-version.md`, old C
  recording scripts and some screenshots/reports cited in ADRs are absent.
  Use `c-final`/history if needed; do not recreate removed engine files merely
  to satisfy a historical path. C source citations in format/event specs refer
  to that tag, not the current tree.

## Keeping this context useful

When adding a guide, add its trigger to the routing table or inventory. When
adding an ADR, index it and note what it supersedes. When resolving a stale
section, remove or revise the corresponding warning here. Recheck paths and
the review commit/date after a deliberate documentation audit. Keep this as
one routing file; do not turn it into another copy of every specification.
