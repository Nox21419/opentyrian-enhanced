# Android ARM64 proof of concept

This target is for the Samsung Galaxy A35 and other ARM64 Android devices.
It uses the existing Compatibility renderer, Original graphics and landscape
orientation. By default, **hold one finger on the playfield to steer and fire**;
drag to move the target, and lift to stop firing. Setup > Controls can instead
enable tilt steering, with held playfield touch used only for firing. Both
styles use the existing movement rules and normal ship bounds. Extra fingers
can operate the Android weapon controls while the steering finger stays held;
pause or focus loss cancels held input. The title screen has
an Android-only two-column layout of the original gold menu text, including
a visible Side Modes entry with the same lettering.
The Players screen keeps its original single-column text, adds Back and wider
touch areas, and greys out/disables its local two-player entries. The network
entry opens the [connection-only LAN lobby](network-coop.md); while hosting,
Choose Episode reuses the original Episode, Difficulty and two-player Arcade
Game Menu screens. Start records host intent and returns to the same live lobby;
it does not launch gameplay. Episode/Difficulty and the host-operated Arcade
menu are approved. Its original Options screen now enables host-local audio
volume with unsupported save/load/device rows dimmed; Options is approved.
The shared lobby now validates the selected configuration and accepts Ready on
both phones, then host Start; this Ready screen is approved. Start prepares
the backend at tick zero. The approved player-view direction keeps the full
original two-player HUD on both phones; the detached presentation checkpoint is
implemented and awaits review, with player-menu/input handoff still unimplemented.
Episode Select keeps its original five labels and placement, adds Back and
wider touch areas, and activates a choice on release. Difficulty Select uses
the same release-to-select adaptation with Back to Episode or Timed Battle.
Timed Battle retains its three original battle labels with wider release targets
and Back to the title.
The shop root Game Menu also activates on release within wider column targets.
Data, Upgrade Ship, Options and Next Level and their child screens activate
on release using their original targets.
Setup, Graphics, Sound, Gameplay, Mutators and picker popups also activate on
release, with wider invisible row targets. Jukebox uses its existing text for
touch controls. Setup's Joystick entry is grey and unavailable on Android. Controls replaces
Key Bindings; see Android tilt controls below. Mods toggles a pack when a tap is released on its row.
High Scores keeps its original arrows with wider touch targets and adds a
small Back label; both activate on release and cancel when dragged off.
Replays uses its original rows and scroll indicators as release-activated
touch targets, with Back available even when the folder is empty.
Load Game keeps its original save rows and Exit to Main Menu, with wider
release-activated targets and the two-player page control greyed out.
Instructions has wider topic targets and visible previous/next chevrons and
Back on every help page, including the embedded shop help.
Achievements retains its original list and detail panel, with release-activated
rows, category arrows, paging arrows and Back.
Side Modes keeps its two modifier columns, with wider release-activated targets,
mode arrows, Start Level and Back; Two Players is grey and cannot launch.
End-of-level Statistics replaces its footer hint with Continue; a release over
the wide footer target advances, while dragging off cancels.
The top-left corner has an `II` Pause icon; its menu and Quit confirmation
activate on release and cancel when dragged off.
Save Game keeps its original name box; tapping the name field opens the Android
keyboard while preserving its uppercase, 14-character naming rules.
Other menus still use their existing pointer/click behavior. In-level Android
weapon controls sit just above the bottom-left message bar: the left manual
sidekick icon, Mode, and the right manual sidekick icon. The score is right-aligned
at the top-right of the play area. No HD art
ships. The five example mod packs are bundled, extracted and read by the mod
loader (after the player's own mods folder), disabled as on desktop until the
player enables them in Setup → Mods.
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
path: input is clamped to ±30, contributing up to 8 logical pixels per tick
per axis, with the existing ship inertia adding up to 4 more. The input
contribution alone is 280 pixels per second at normal 35 Hz pacing. This accepted input adaptation is not blanket
approval for other gameplay changes.

The maintainer separately approved network-only per-player touch/mouse input
routing on 2026-11-24, preserving existing movement/linking rules and co-op
weapon ownership. The opt-in Rust/bridge API is being validated; it is not yet
connected to Android gameplay. Local play keeps the shared input path. See the
[full co-op plan and input audit](network-coop.md#approved-player-input-adaptation-and-audit-stage-3).

On Android, permanent Auto-fire is locked off: normal fire comes from the
held steering finger, continues while that finger is stationary, and stops on
release or cancellation. Sidekick/Mode/Special touches do not hold normal fire.
Equipped specials activate exclusively through the separate Special control;
playfield presses, sidekick buttons and directional combinations do not activate
specials on Android. This input change was expressly requested by the maintainer.
Bullet Time is locked off, and Rumble locked off until mobile haptics are implemented.
Settings application enforces these values, including when loading older
profiles. Their Gameplay rows and values are grey and navigation skips them.
The simulation's firing cadence, damage and movement rules are unchanged.
Desktop retains its saved choices and editable rows.

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
The enabled network-identity export plugin stamps the current client sources
inside the APK export; the runtime bundle also includes the hashing dependency
notices. These support later compatibility negotiation, not playable co-op yet.
Debug signing is for personal testing; release signing/distribution is separate.

`Game._ready()` extracts the bundle before its first native campaign/profile
load. Files go to `user://bundled/runtime-v1/`, and `GamePaths` resolves native
data there. The bundle holds the `data/` allowlist, notices and licenses, and
`mods/<pack>/`: each `rewrite/mods` folder with a `mod.json`, selected as
`package.sh` selects them (`_retired/` excluded, links refused). Every startup verifies file hashes, reuses intact files and repairs
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
The Android preset now uses normal seasonal Christmas activation. In December,
the original Yes/No prompt appears at startup and supports touch. The initial
proof-of-concept `--no-xmas` override was removed after adapting that prompt.

## Validation

### Bundled mod packs

All five packs may be enabled together in Setup → Mods. Check that each tap
changes its saved enabled flag, Back reloads the packs, and a cold relaunch keeps
the choices. Mod ships and weapon icons must appear in Upgrade Ship; purchases
must change the owned mark and cash by price minus trade-in. Weapon previews
draw the packs' animated PNG projectiles inside the original preview frame,
leaving the power/mode interface clear. Check the same ship and gun in a level.
`test/shop_mod_preview_test.gd` checks all 18 shipped weapons' preview animation
frames and textures, plus the frame/power-panel mask. Run it alongside the mod
ship-pose, shot-texture, touch-toggle and shop-child touch suites.

On 2026-11-23, the A35's installed bundle matched all 220 source mod files;
all five touch toggles wrote their enabled flags. Zica Ember and Zica Thermal
Lance were purchased with the expected cash changes, and rendered in gameplay.
The investigation found and fixed invisible mod shots in the shop preview's
original-sheet rendering path. After an APK update without uninstalling, the
five enabled choices persisted; Zica Thermal Lance, Spore Burst, Acid Spitter
and Flame Lance preview projectiles were visually verified on the A35. The
related five Godot suites passed 20 tests, including all 18 weapons' preview
frames and all 70 ship poses. This does not prove every weapon/power-level
combination in live Android gameplay. The Linux package journey/smoke gate was
unavailable on this Windows host because WSL was not installed.

A subsequent full shop audit on the same A35 checked all 18 mod weapons at
every power from 1 through 11 (198 cases), with three phone captures per case.
A separate slot-10 test save supplied 10,000,000 credits and the original
Gravitron Pulse-Wave generator. Front and rear guns were tested separately,
with the opposite bay and both sidekicks empty. The existing JourneyState
logger verified the mounted weapon and power before/after each capture set;
the temporary test APK changed only startup arguments and the normal APK was
restored afterward. All 594 phone images were visually reviewed with the saved
Sharp filter enabled; no additional preview defects were found. On the host,
180 preview steps for every case matched a separate evaluation of the pack
JSON's counts, cadence, spawn positions, acceleration, circular motion,
lifetimes and animation. The original saves and mod preferences remained
byte-identical. These are shop-preview checks: the target-free demonstration
does not verify homing against enemies, collision, damage, piercing or freezing.

### Title touch menu (first menu adaptation)

Only Android rearranges the original title lettering into two columns with
20-pixel touch rows. It uses the same gold font, outlines and selection
highlight, without a button overlay. Desktop retains the original title
drawing and mouse, keyboard and gamepad paths. Touch uses the existing title
actions and activates on release; dragging off a row cancels activation. Child
screens are not adapted by this change; in particular, opening Achievements or
Replays does not yet make those screens touch navigable.

On the phone, check each title entry, Side Modes, Quit → No, and Quit → Yes.
Check that pressing then dragging off an entry cancels activation, returning
from a child screen restores the text layout, and a tap opens only one screen.
Do not count the title as phone-verified until those checks run on the device.

`test/title_touch_test.gd` covers press/release routing, transition guards,
Quit cancellation, Side Modes access and the unchanged desktop layout.
Run it alongside `title_row_reset_test.gd`, `mouse_menus_test.gd` and
`controls_test.gd` for the existing desktop input regression coverage.

### Players touch menu (second menu adaptation)

New Game → Players retains the original background, gold lettering and
selection highlight in a single column. Android uses eight 18-pixel rows
(including the localized Back entry), starting at y = 46, with invisible
touch targets from x = 16 to 304. A choice activates on release in the same
row; dragging off cancels it. Back returns to the title through the existing
cancel action.

On this Android screen, 2 Player Arcade and 2 Player Endless are grey and
unavailable, as is Modem/Network Game. Touch, keyboard and controller confirms
all enforce the restriction. Nearby-device multiplayer is not implemented.
Desktop retains its original layout and working two-player choices. This
change does not adapt other routes to side modes. Timed Battle is adapted below.
Episode and Difficulty Select have their own adaptations below.

On the phone, check that a tap beside the lettering selects the correct row,
dragging away cancels, the grey entries cannot start a game, a one-player
choice opens the expected next screen, and Back returns to the title.
`test/players_touch_test.gd` checks these action results and desktop co-op
availability; run it with `new_game_test.gd` and `ui_audit_fixes_test.gd`.

### Episode touch menu (third menu adaptation)

Android keeps the original background, gold lettering, highlight and the five
episode labels at x = 20, y = 50 + 30 × row. Invisible touch areas span
x = 16 to 304. Back is centered at y = 185, below the fifth episode, with its
own non-overlapping target from y = 184 to 200. A choice activates on release
in the same row; dragging off cancels it. Back returns to the title, preserving
the existing cancel destination. Episode availability checks remain unchanged.
Desktop retains the original five rows and text-width click areas.

On the phone, check every episode, a tap beside the text, dragging across rows,
the fifth episode versus Back, and Back returning to the title. `test/episode_touch_test.gd` checks episode selection,
drag cancellation, Back, boundary targets and the unchanged desktop layout.

### Difficulty touch menu (fourth menu adaptation)

Android retains the original difficulty labels and positions (y = 54 + 24 ×
row), the gold lettering and the default Normal selection. Invisible targets
span x = 16 to 304; release in the pressed row confirms and dragging off
cancels. A small gold Back entry at y = 190 follows the existing cancel action
to Episode Select, or Timed Battle for that mode. Desktop remains unchanged.

All six difficulties (Easy, Normal, Hard, Impossible, Suicide and Lord of
Game) are always visible on Android. Back uses the original small font at
y = 190 so the sixth label can stay at y = 174 without overlap. Its touch
area starts at y = 188. Normal remains selected by default. Desktop still
starts with three choices and retains Shift+G, Shift+] and LORD unlocks.
The difficulty values and game rules are unchanged.

On the phone, check all six choices, drag cancellation, and Back. Automated
coverage in `test/difficulty_touch_test.gd` verifies the higher difficulty
values, both Back destinations, target boundaries and desktop geometry.
Run it with the Episode, Players and existing New Game suites.

### Secrets in Android Setup

Setup > Secrets provides touch access to the original title-code games:

- **Super Arcade**: all nine named ships, followed by the existing episode,
  difficulty and ship introduction screens. The original equipment, including
  Nort-Ship Z's Quicksilver companions, and difficulty increment are preserved.
- **Super Tyrian**: Lord of Game or Suicide, followed by the existing
  introduction and episode choice. Suicide replaces the need to hold Scroll
  Lock; both choices retain Stalker 21.126 and Atomic RailGun.
- **Destruct**: opens the existing mini-game, also available through Side Modes.
  Its live-round touch controls are described below.

The Secrets entry is Android-only. It uses Setup's original fonts, palette,
menu engine, wide invisible targets and activation on release. Ship names
show their original title codes in the help strip. Done returns through the
menu stack; cancelling a secret game's episode choice returns to Setup with
Secrets selected. Title keyboard codes on desktop are unchanged. Special-move
sequences (twiddles) and developer cheats are not changed or exposed here.
`test/secrets_touch_test.gd` checks touch navigation, drag cancellation, all
nine starting loadouts, both Super Tyrian difficulties, Destruct entry,
cancellation and desktop scope.

### Shop root Game Menu (fifth menu adaptation)

Android retains the original shop artwork, lettering, row positions and
right-hand menu column. The six root entries use invisible targets from
x = 164 to 312: Data through Start Level occupy y = 36 to 116 in 16-pixel
rows; Quit Game occupies y = 132 to 150. The gap and footer are not targets.
Touch highlights on press and activates on release in the same row; dragging
off cancels. Quit still opens the existing confirmation box.

The root policy preserves desktop mouse, keyboard and controller paths and
all native purchasing/equipment rules. Root touch forwards the existing shop
commands. The child-screen policy below extends release activation separately;
Ship Specs retains its existing interaction.

On the phone, check all six entries, drag cancellation, taps on the gap/footer,
and Quit → No. Check that entering a submenu does not immediately activate
another item. `test/shop_root_touch_test.gd` covers entry destinations,
confirmation, cancelled taps, unchanged equipment/cash, desktop mouse-on-press
and the original Upgrade Ship interaction. Run it alongside the shop rows,
purchase-hover and mouse menu suites.

### Shop menus and child screens: release activation

On Android, Data, Upgrade Ship, Options and Next Level now activate taps on
release over the same target and cancel after the pointer is dragged off it.
This also applies to their child screens: cube reader Exit, item purchases,
weapon-power arrows, save/load slots, name-entry and save-confirmation buttons,
and keyboard/gamepad/mouse settings. The original positions, labels, hit areas,
prices, volume increments and action handlers are unchanged. Desktop keeps its
existing mouse-on-press behavior.

Cube text scrolling remains a held interaction, not a release activation.
The empty Data screen still returns on a tap anywhere, now on release. Purchase
rows use the existing native click path at release, including its affordability
checks; pressing alone does not purchase an item. The shared `TouchRelease`
helper delays the click without adding widgets or changing the menu engine.

On the phone, test opening and leaving each submenu, cancelling a purchase
by dragging off, buying on release, power arrows, volume bars, slot selection,
name/confirmation cancellation and settings capture. Verify that cube scrolling
still responds while held. Automated coverage is in
`test/shop_children_touch_test.gd` and `test/options_touch_release_test.gd`,
alongside the existing shop/configuration/mouse/save suites.

### Shop item lists: touch scrolling and persistent Done

Android item categories show four original item rows with Done fixed below them.
The original gold navigation arrows (`newsh1.shp` sprites 275/277, also matching
the High Scores page arrows) replace the tiny scroll triangles on Android. Their
visible artwork is 21×16 logical pixels, with 38×24 (up) and 38×28 (down) touch
areas clear of the item rows and Done. They accept taps on release and move the
window one item without changing selection, equipment or cash. They stop at either end;
dragging off cancels. Only visible item rows accept purchases. Done accepts the
current selection through the existing native purchase path and returns to
Upgrade Ship. Desktop retains its five-row scrolling list and input behavior.
`shop_children_touch_test.gd` covers scrolling bounds, selection preservation,
cancellation, scrolled purchases and leaving through Done.

On 2026-11-23, the updated APK was installed over the existing A35 app.
With all five packs enabled, phone taps reached both ends of the Front Gun
list, extra boundary taps did not wrap, and dragging off an arrow cancelled.
Scrolling kept the selected gun and cash unchanged. Buying Arc Caster from
the bottom, choosing Done and reopening kept its owned mark and the expected
9,990,500 credits (10,000,000 minus 10,000 plus the 500 trade-in).
The existing QA save was loaded without overwriting it. No script errors or
Android crash messages were found during this check. The exported Linux
journey/smoke gate remains unavailable on this host without WSL.

The gold-arrow APK was also installed and checked on the A35 on 2026-11-23.
Both arrows were visible without covering item text or Done. Taps near the
expanded target edges scrolled, dragging off cancelled, boundary taps did not
wrap, and Done returned to Upgrade Ship with the Pulse-Cannon and 10,000,000
credits unchanged. The QA save was not overwritten; the shop was left open.
No script errors or app crash messages appeared in the process log.

### Mobile Options: external-device settings unavailable

In the shop's Options menu, Android retains the Joystick, Keyboard and Mouse
labels in their original positions but draws them grey and disables them.
Touch cannot open them, and keyboard/controller navigation skips them. Mobile
controls will use the dedicated touch interface; this change does not rewrite
saved bindings or add a touch-control settings screen. Desktop retains the
three working device-configuration menus.

The child settings handlers remain present for desktop use. On the phone,
check that tapping these grey entries does nothing and that Load, Save,
Music, Sound and Done still work. `options_touch_release_test.gd` checks mobile
availability and that all three desktop menus still open.

### Rear Gun mode hint

On Android, a rear gun with multiple modes keeps a localized `[Tap] Rear weapon
mode` hint visible in the original preview panel. Releasing on the hint cycles
the mode through the existing `/` command; dragging off cancels. Power and
prices sit just above the hint, using the original lettering and colors.
Single-mode guns have no mode target. Desktop retains its alternating `/` hint
and existing keyboard behavior. `shop_children_touch_test.gd` checks matching
mode indicators, cancellation, unchanged equipment/cash and localized widths.

### Manual sidekick preview

On Android, Left Sidekick and Right Sidekick show the selected sidekick's
original item icon at the bottom-left of the ship preview when that sidekick
requires manual fire (limited ammo or a nonzero charging power requirement).
Release on the icon fires that menu's side only; dragging off cancels. Empty
slots and automatic sidekicks have no fire icon. Manual sidekicks wait for a
tap in the Android preview; automatic sidekicks continue their demonstration.
The Android preview also draws special projectile sprites such as Plasma
Storm using the original blended OPTION_SHAPES artwork.
The preview owns a separate world, so firing never consumes gameplay ammo or
changes equipment or cash. Desktop keeps its original automatic demonstration.
The preview unit test and `shop_children_touch_test.gd` cover these paths.

### Setup and child screens

Gameplay keeps Freeze Frames, Damage Numbers, Combos, Language and Mutators
available: their existing settings paths have no desktop-only input dependency.
On Android, Bullet Time is locked Off, Auto-fire Off, and Rumble Off. Rumble
currently targets connected gamepad motors, not the phone's vibrator.
`setup_touch_test.gd` checks disabled rows, navigation, old-profile overrides,
effective runtime settings and desktop behavior. The existing Gameplay suites
verify the remaining settings.

Android Setup retains the original fonts, artwork, positions and row spacing.
Rows in Setup, Graphics, Sound, Gameplay and Mutators accept touches from
x = 16 to 304, with a separate 15-pixel-high target per visible row. Pressing
highlights; release in the same row activates; dragging off cancels. Volume
bars keep their existing value mapping. Settings still apply and save through
the original handlers. Picker popups confirm on release; tapping outside the
popup cancels without changing the value.

Graphics' Display row also stays visible in grey and cannot be opened on
Android: its desktop Windowed/monitor chooser does not match Android's
immersive display. Scaler, Scaling Mode, CRT, available sprite modes, Visual
Effects and Explosion Style remain enabled. Desktop retains the Display chooser.

Joystick remains visible in grey but cannot be opened; Controls replaces
Key Bindings with the tilt settings described below
on Android; navigation skips them. Mods opens (see Mods touch toggles). Desktop retains those entries and its
existing mouse-on-press behavior, row targets and picker handling.

Jukebox's existing text becomes touch targets without new widgets: tap the
left/right halves of the track/title area for previous/next, the playback
status to stop/restart (or play the selected effect), and Shuffle to toggle it.
The existing command hints at the bottom are also tappable, including effects,
in-game music, hide text and quit. In effects mode the track/title area changes
the effect. Tap anywhere to restore hidden text; tap the header to exit. Each
action activates on release and cancels when dragged off. Desktop keeps its
existing keyboard/gamepad commands and click-to-exit behavior.

`test/setup_touch_test.gd` covers release activation, cancellation, unavailable
entries, settings persistence, volume, popups and desktop input. Jukebox touch
and six-language command targets are covered by `test/jukebox_test.gd`; run
these alongside the existing Setup and mouse-menu suites.

### High Scores

Android keeps the original score tables, episode headings, arrows and footer.
The previous-page target spans x = 64..106, the next-page target x = 213..247,
and Back x = 252..307; all occupy y = 174..199. The small localized Back label
is centered at (280, 182), beside the original footer without covering it.
Only visible arrows are active: touch does not wrap past the first or last
page. Release in the original target activates; dragging off cancels.
Desktop retains its original arrow-on-press, keyboard/gamepad and right-click
exit behavior. Scores and persistence are unchanged.

`test/highscores_touch_test.gd` covers all nine pages, boundary targets,
cancellation, Back, unchanged scores, localized label widths and desktop
clicks. Run it with the existing high-score and mouse-menu suites.

### Replays browser

Android keeps the original eight-row replay list, filenames, header summaries,
selection colors and scroll indicators. Pressing a row highlights it; releasing
in the same row opens it through the existing replay validation/loading path.
Dragging off cancels playback. Row targets span x = 16..277 and y = 28..187,
in separate 20-pixel rows. Only displayed rows are targets.

The existing up/down indicators have targets at x = 278..307, y = 22..43
and 170..187 respectively. Tapping one moves the list window up/down by up
to eight rows, without wrapping. Back uses x = 252..307, y = 188..199 with
the existing localized tiny-font label centered at (280, 192). It replaces
the keyboard-only footer hint on Android and also appears on the empty screen.
Invalid/empty-file messages keep their original validation and timeout.
Desktop retains keyboard/gamepad navigation and ignores mouse clicks as before.
Replay files, recording and playback simulation are unchanged.

`test/replays_touch_test.gd` verifies release-to-play of the selected replay,
drag cancellation, scroll limits, empty-screen Back, refusal messages and
unchanged desktop pointer behavior. Run it alongside recording, playback
and mouse-menu suites; report any existing playback parity failure separately.

### Load Game

Android retains the original eleven one-player save slots and Exit to Main
Menu row, fonts, columns, spacing and selection colors. Row targets span
x = 8..311, y = 28..183, in separate 13-pixel bands. Press highlights a row;
release in that same row loads it through the existing campaign-save path.
Dragging off cancels. Empty and unreadable saves retain their refusal behavior.
The original Exit row also activates on release.

The two-player page arrow and its hint are grey on Android. Touch and
keyboard/controller page switching are disabled there, consistent with mobile
two-player mode being unavailable. The arrow area is excluded from the wide
Exit target. Desktop retains both pages and its existing input behavior.
No saved files or campaign rules are changed by the adaptation.

`test/load_touch_test.gd` covers loading a real save and its cash, cancellation
without modifying that save, row geometry, unavailable paging, refusal paths,
Exit and desktop paging. Run it alongside the save and mouse-menu suites.

### Instructions and Help

Android retains every original topic and all eleven help pages, including
their help text, artwork, fonts and page counters. Topics use wider targets
from x = 16..303 in separate 20-pixel bands starting at y = 58. Pressing
highlights a topic; releasing on the same topic opens it; dragging off cancels.
The existing Exit topic returns to the title (or closes embedded shop help).

Each help page has small gold palette chevrons centered at x = 108 and 212,
and a localized tiny-font Back label at x = 160, in the existing bottom strip.
Touch targets are x = 88..127 for Previous, 132..187 for Back and 192..231
for Next, all y = 188..199. Actions activate on release and cancel when dragged
off. The page body is not a navigation target on Android. Back returns to the
topic list; Previous before page 1 and Next after page 11 also return there,
following the original page flow. The same adaptation covers help embedded
in the shop. Desktop retains its original topic, half-page click, right-click,
keyboard and gamepad behavior.

`test/instructions_touch_test.gd` covers every topic and page, cancellation,
page limits, Exit, embedded close signaling, desktop input and visible footer
controls. Run it with the help glyph, key-help and mouse-menu suites.

### Mods touch toggles

Setup → Mods opens on Android. The screen keeps its original rows, ON/OFF/ERR
labels and colors, and the info card below the list. Pressing a mod row
highlights it and shows its card; releasing over the same row toggles it with
the original click sound. Dragging off before release cancels the toggle. Row
targets span x = 8..311 and y = 28..135 in 12-pixel rows; only shown mod rows
are targets. Open mods folder and Install a mod (.zip) are drawn grey (Setup's
unavailable style), are not targets, and keyboard/gamepad navigation skips
them: Android cannot open the app-private folder in a file manager, and the
.zip picker is unverified there. Back uses x = 252..307, y = 188..199 with the
localized label centered at (280, 192), replacing the keyboard hint. Leaving
the screen reloads mods as on desktop. Packs ship disabled; enabling one adds
its content exactly as on desktop, and with every pack off gameplay is
unchanged. With more than nine rows, only the shown window is reachable by
touch. Desktop keeps the keyboard-only screen, its action rows and its hint.

`test/mods_touch_test.gd` covers release toggling, drag-off cancellation,
the grey action rows, the Back target and the unchanged desktop behavior.

### Bootstrap and packaging

```powershell
python -m unittest discover -s rewrite/scripts -p test_build_android.py
godot --headless --path rewrite/godot -s res://addons/gdUnit4/bin/GdUnitCmdTool.gd -a res://test/android_data_test.gd -a res://test/game_paths_test.gd --ignoreHeadlessMode -rd res://../../build/android-gdunit
```

The gdUnit suite checks first extraction, cache reuse, repair, changed bundles,
save preservation and unsafe names. `game_paths_test.gd` also checks Android's
player-directory policy. These checks and an APK export cannot substitute for
running on the A35. The repository's Linux exported-package journey/smoke gate
in [testing.md](testing.md) still applies before a push or build handoff.


### Achievements touch navigation

Android retains the original achievement rows, status boxes, selection bar,
localized category heading and selected achievement details. Tap a row to select
its details on release. The two small gold chevrons beside the category heading
cycle through all six categories; category changes reset selection to the top.
Up/down chevrons in the right margin page the selection by fourteen rows and
appear only when more rows exist in that direction. The existing centered list
window remains in use. Back replaces the keyboard-only footer hint on Android.
Every touch action requires release over its original target; moving off cancels
it, even when returning before release. Desktop keyboard, gamepad, mouse-wheel
and ignored-click behavior are unchanged. Achievement tracking rules are unchanged.

`test/achievements_touch_test.gd` checks selection, cancellation, all categories,
paging boundaries, Back and desktop input. Existing sorting, sound and mouse
parity suites also cover the unchanged desktop behavior.


### Side Modes touch navigation

Android retains the existing mode row, modifier columns, lettering, palette and
background. Small gold chevrons switch modes: the left arrow selects the previous
mode; the mode text and right arrow select the next. Mutator and anomaly rows use
wider, disjoint touch areas while retaining their original nine-pixel spacing.
Start Level and Back replace the keyboard hints at the bottom. All touch actions
activate on release over the original target; dragging off cancels the action.

Two Players remains visible in grey, with Start Level grey and unavailable while
it is selected. Android also refuses that launch through keyboard/gamepad Accept.
The remaining modes use their original launch parameters, and mutators retain
the existing settings persistence. Desktop input and two-player launch remain
available. This pass adapts the Side Modes selection screen, not Destruct's own
menus or gameplay controls.

`test/modes_touch_test.gd` covers every modifier, mode cycling, release/cancel,
mobile two-player refusal, Galaga launch flags, Destruct routing, Back, desktop
two-player launch and localized control widths. Existing menu and mode suites
check desktop navigation, saved mutators and a 300-tick Galaga run.


### End-of-level Statistics touch footer

Android keeps the original Statistics layout, values, font, color and footer
position (y = 182). Its footer reads Continue in the selected language, with an
invisible touch area spanning x = 16..303 and y = 176..199. Only a press and release
inside that area continue to the existing campaign/Endless flow. Dragging off
cancels, even when returning before release; tapping the statistics body does
nothing. A release carried over from the preceding debrief cannot dismiss the
screen. Desktop retains its original hint and keyboard/gamepad confirmation.
The preceding debrief animation and game rules are unchanged.

`test/debrief_touch_test.gd` checks release activation, cancellation, body taps,
campaign continuation, desktop behavior and localized label widths. Existing
debrief suites check statistics values, keyboard/gamepad exits, timed bonuses,
two-player results and early scene replacement.


### Top-left Pause icon, pause menu and Quit confirmation

Android places `II` at (2, 2) in the top-left corner as a Pause icon, using
the same original font as the main-menu items and a dark outline. The bars
have two extra pixels of separation rather than a full text space. Its touch area is x = 0..55,
y = 0..15. Presses starting there belong to Pause instead of flight. The icon opens
the existing pause menu on release, cancels when dragged off or on focus loss,
and tracks its own finger so it cannot steer the ship. Opening Pause clears held
flight input. No simulation ticks run while the existing pause menu is open.
The icon is absent on desktop and during demos/replays.

The pause menu keeps its original artwork, six rows, values and sounds. Android
uses disjoint 20-pixel-high touch rows spanning x = 8..217. Music/Sound labels
still toggle mute, their bars still set volume, Visual Effects and Game Speed
still cycle through their existing choices, and Return resumes. These actions
activate on release; dragging from a volume label to its bar also cancels.
Quit's original Yes/No box uses release activation and drag-off cancellation.
No resumes the game and Yes follows the original quit path. Settings retain
the existing save-on-close behavior. Desktop mouse, keyboard and gamepad paths
are unchanged. This adaptation does not change simulation timing or speed rules.

`test/pause_touch_test.gd` checks the top-left gesture, separate flight finger,
cancellation and focus loss, frozen simulation state, settings and persistence,
Return, both Quit answers, icon width and desktop icon absence.
Existing pause-menu, pause, visual-effects and touch-flight suites check the
other input paths and gameplay input preservation.


### Save Game name entry with the Android keyboard

Android retains the original name box, blinking cursor, fonts, palette and Yes/No
buttons. Release a tap over the name field (x = 60..254, y = 82..103) to open the
phone keyboard, prefilled with the current name and its cursor at the end.
Dragging off cancels the keyboard request. Text and backspace use the existing
name editor: names remain uppercase, limited to fourteen characters, with the
existing supported-character checks. Android logical Backspace/Delete and Enter
are handled even when the soft keyboard supplies no physical scancode.

Yes or the keyboard's Done action proceeds to the existing save confirmation;
No cancels without changing the slot. The keyboard is dismissed when leaving
name entry or the screen. Desktop text entry and bindings are unchanged. This
pass covers Save Game only; Endless high-score name entry is covered below.
Campaign/Timed Battle high-score name entry is covered below.

The integration uses Godot's [virtual keyboard API](https://docs.godotengine.org/en/4.6/classes/class_displayserver.html#class-displayserver-method-virtual-keyboard-show)
and the existing key-event path; the [Android text wrapper in Godot 4.7.2](https://github.com/godotengine/godot/blob/4.7.2-stable/platform/android/java/lib/src/main/java/org/godotengine/godot/input/GodotTextInputWrapper.java)
forwards inserted characters, backspaces and Done as key events.
`test/save_name_touch_test.gd` checks field release/cancellation, logical-key
editing, length limits, saved names, untouched cancelled saves, desktop behavior
and keyboard cleanup on scene exit. Existing Options and save suites check the
surrounding navigation, confirmation and persistence paths.

While the Android keyboard is visible, only the original name modal moves up
fifty game pixels, aligning its artwork with the top of the screen. Its font,
size and artwork stay unchanged, and the background remains full size. The
field and Yes/No touch areas move by the same offset. Hiding the keyboard
restores the original modal position; leaving name entry clears the offset.
Desktop uses the original drawing and input geometry throughout.
`test/save_name_touch_test.gd` also verifies the shifted drawing and touch
areas, restoration, unchanged screen size and cancellation from the moved No
button without writing a save.

### Timed Battle selection touch navigation

Android keeps all three original battle labels at y = 54 + 24 × row, with
invisible targets spanning x = 16..303 and 24 pixels per row (starting two
pixels above each label). Back uses the original gold menu font at (160, 185),
with its target spanning x = 16..303, y = 184..199, and returns to the title.
Choices activate on release over the pressed row; dragging off cancels even
if the finger returns. Selecting a battle opens Difficulty with the original
episode and battle selection. Desktop retains its three rows, text-only mouse
targets and keyboard/gamepad navigation. `test/timed_touch_test.gd` checks these
routes, cancellation, boundaries and desktop behavior.

### Endless Resume / New Game touch choices

Android replaces the resume prompt's keyboard hint with localized Resume and
New Game labels, retaining its original small font, palette bank 14, brightness
4, shaded text and y = 130 footer. The title, wave/score and deck stay unchanged.
Resume is centered at x = 86 and New Game at x = 234. Their disjoint targets are
x = 16..155 and 164..303, y = 126..149. A release over the pressed choice
activates; moving off cancels, including when returning. Body taps do nothing.
Resume follows the existing Enter path; New Game follows Escape. Desktop mouse,
keyboard and gamepad behavior and anomaly-card input are unchanged.
`test/endless_resume_touch_test.gd` checks both results, cancellation, boundaries
and desktop input; `test/endless_prompt_test.gd` retains the original route checks.

### Endless results touch footers

Android keeps the summary and leaderboard artwork, text, score columns and
palette. Continue replaces the summary keyboard hint at y = 188; its target
is x = 16..303, y = 176..199. The leaderboard replaces its keyboard hints with
Retry, New Game and Back centered at x = 60, 160 and 260, y = 188, using the
original small shaded font. Their targets span x = 16..103, 112..207 and
216..303, y = 176..199. Release activates; dragging off or across choices
cancels. Taps on the table/body do nothing. Retry and New Game both follow the
existing fresh-run path (Enter/R); Back returns to the title (Escape).
Desktop mouse, keyboard and gamepad behavior is unchanged. High-score name
entry is adapted separately below.
`test/endless_results_touch_test.gd` covers footer actions, cancellation,
transition guards, summary continuation and desktop/name-entry click behavior.

On the A35, summary Continue opened the leaderboard, Retry and New Game each
launched a fresh run, and Back returned to the title. Body taps and drag-off
cancelled; holding Retry left the leaderboard visible until release. Test
leaderboard entries were removed afterward and the original player profile,
settings and campaign saves were verified byte-for-byte against their backup.

### Endless high-score name entry on Android

Tap and release the original shaded name field to open the Android keyboard.
Confirm and Skip replace the keyboard hint using the original small shaded font
and palette (bank 14, brightness 2), centered at x = 100 and 220, y = 140.
The original uppercase ASCII/glyph checks and fifteen-character limit remain.
Confirm/Done requires a nonempty name. Skip follows Escape and records PLAYER,
including if text was entered; it does not discard the qualifying score.

While the keyboard is visible, the original title, wave/score, prompt, field and
actions move to y = 2, 25, 45, 60 and 85. Fonts, artwork and screen scale stay
unchanged. The field target is x = 60..260, y = 95..115 normally (55..75 raised).
Confirm/Skip targets are x = 40..155 / 164..279, y = 136..159 normally and
82..93 raised. Every touch requires release over its original target; dragging
off cancels. Keyboard dismissal restores the original layout; confirming,
skipping or leaving the screen hides it. Desktop editing/bindings are unchanged.
`test/endless_name_touch_test.gd` checks field gestures, empty confirmation,
uppercasing, length, logical Backspace/Done, raised targets and cleanup; results
and existing Endless suites cover the surrounding flow.

Android processes IME deletions and inserted characters in order, including
Samsung predictive-keyboard replacement batches. This preserves the original
editor's naming rules while preventing duplicated prefixes from lost deletions.

A35 phone checks verified Samsung keyboard entry/backspace (PHONE → PHON),
Confirm saving PHON, keyboard Done saving P, and Skip recording PLAYER after
text entry. Hiding the keyboard restored the normal layout; the raised prompt
remained above the keyboard. Test scores/run data were removed and the original
profile, settings and campaign saves restored and verified byte-for-byte.

### Campaign and Timed Battle high-score name entry

On Android, releasing a tap over the original name field (x = 60..254,
y = 82..103) opens the native keyboard prefilled with the current name. The
original modal artwork, fonts, palette and blinking cursor stay in use. Android
draws the original Yes/No lettering from Save Game into the existing button
boxes (the desktop high-score screen leaves those boxes unlabelled). While the keyboard is visible, the modal and all of its text/targets
move up 50 pixels, putting its top at y = 0. The two headings above the modal
are temporarily hidden to avoid overlap; dismissing the keyboard restores them
and the original modal placement. The full screen is never resized.

Yes/Done confirms; No follows the original cancel path. All touch actions
activate on release and cancel when dragged off. The editor retains its ordered
input queue (including Samsung IME replacement batches), uppercase ASCII/glyph
checks, 28-character limit and acceptance of an empty name. Campaign and Timed
Battle keep their original, different cancellation/persistence rules; this pass
does not change score qualification, ranking or recorded values. Desktop mouse,
keyboard and gamepad behavior remains unchanged. The keyboard is hidden on
completion or scene exit. `test/story_name_touch_test.gd` checks both entry
variants, touch cancellation, keyboard editing, shifted targets and desktop
clicks; `test/story_test.gd` checks full campaign/Timed Battle persistence flows.

A35 checks used a temporary end-of-episode campaign save: Samsung typing and
Backspace produced PHON, Yes recorded PHON at the expected score, No declined
the entry, drag-off cancelled, and keyboard dismissal restored the headings
and modal placement. Temporary save/score files were removed, and the original
profile, saves and settings restored and verified byte-for-byte.

### Destruct intro and mode menu touch navigation

Android retains Destruct's original intro artwork and small-font title. Its
two existing footer lines become Continue (y = 180) and Back (y = 190), in the
original palette/brightness. Their targets span x = 16..303, y = 174..187 and
188..199. Continue opens mode selection; Back returns to the title.

Mode selection keeps its original centered labels at y = 82 + 12 × row,
palette bank 12 and selection brightness. Invisible row targets span
x = 16..303, y = 80 + 12 × row through the next 11 pixels. A pressed row uses
the existing selection highlight. Back is added at y = 190 with a target
spanning x = 16..303, y = 180..199. It returns to the title, including through
keyboard navigation. Custom remains available only when destruct.cfg enables
it. Every touch activates on release over the pressed target and cancels when
dragged off. Fade transitions, the intro title and blank areas ignore taps.

Desktop mouse remains ignored and keyboard/gamepad navigation stays unchanged.
The intro/menu pass does not adapt Destruct's round controls or help, change its
CPU/Human setup or alter its simulation. Access is available through Side Modes → Destruct → Start Level, as well as
the existing title DESTRUCT secret code; no title entry was added. `test/destruct_touch_test.gd`
checks intro actions, all five modes, cancellation, Back and desktop behavior;
existing Destruct suites exercise rounds and gamepad/key input.

A35 checks verified intro Continue/Back, mode-menu Back, ignored body taps,
drag-off cancellation, press highlighting and release launching Heli Assault.
The phone was left at mode selection. The test-created destruct.cfg was removed
and the original player files verified byte-for-byte. Round touch controls remain separate work; the existing Side Modes route is
already touch accessible.

### Destruct pause text touch target

On Android, tap and release the existing centered PAUSED text to resume the
round. The font, palette, position (y = 90), frozen backdrop and original
music-volume behavior are unchanged. Its invisible target is 20 pixels high
(y = 84..103), centered at x = 160, with width equal to the localized text
plus 16 pixels of padding (minimum 64 pixels). Dragging off cancels even if
the finger returns; other areas ignore touches. Desktop still ignores mouse
input and resumes from its existing keyboard/gamepad path. This does not add
a way to open pause by touch or change Destruct help/gameplay controls.
`test/destruct_pause_touch_test.gd` verifies release/cancel behavior, target
boundaries, unchanged simulation state/tick count while held, music volume
restoration and desktop keyboard behavior.

A35 checks opened pause with an injected P key, then verified ignored body taps,
drag-off-and-return cancellation, a held press leaving the frozen frame
unchanged, and release resuming the round. The phone was left paused again for
maintainer testing. The test-created destruct.cfg was removed and the original
player files verified byte-for-byte.

### Destruct Help and remaining-screen audit

Android Help adds Back in the existing small font and footer palette (bank 3,
brightness 4), right-aligned at x = 304, y = 190. It preserves every original
help row and the Backspace hint. Its invisible target is x = 252..307,
y = 184..199. Release over the pressed target returns to the frozen round;
dragging off cancels even if the finger returns. Tapping the help body or the
pause-text position does nothing. The target is unavailable during fades, and
the gesture is cancelled on entry/exit. Desktop keyboard/gamepad dismissal and
ignored mouse behavior stay unchanged.

The screen-flow audit found four Destruct interfaces: intro, mode selection
(including optional Custom), pause and Help. All now have Android touch actions.
There are no separate result/confirmation/settings menus: rounds reload through
the existing flow, and destruct.cfg remains file configuration. Side Modes
already provides a touch route into Destruct. The later live-round touch pass
below adds access to Pause, Help and mode selection without a keyboard, while
preserving CPU/Human defaults, simulation pacing and RNG behavior.

`test/destruct_help_touch_test.gd` verifies Back release/cancel, frozen simulation
state and tick count, help/body boundaries and desktop keyboard dismissal.
The Destruct intro/mode, pause and round-key suites cover the other interfaces.

Phone verification on the A35 confirmed the touch route through Side Modes,
Help body/drag-off/held gestures leaving the screen unchanged, and Back release
resuming the round. The original player files were verified byte-for-byte after
testing. All 15 cases across the Help, intro/mode, pause and round-key suites
passed with no errors, failures or orphans; formatting and lint checks passed.
The exported Linux journey/smoke gate remains unavailable without WSL/Linux.

### Christmas prompt touch choices

Android keeps the original Yes/No lettering, positions, highlight and snowflakes.
Only the invisible targets grow: Yes covers x = 96..159, No x = 160..223,
both at y = 112..143. A press selects the original highlight; release over the
same choice confirms. Moving off cancels even after returning, and body taps,
unpaired releases and input during the initial fade do nothing. Desktop retains
its original hover, click, right-click cancel and keyboard/gamepad behavior.
The seasonal activation rules and Christmas assets are unchanged.

All 18 cases in `test/christmas_test.gd` passed with no failures, errors or
orphans, including Android release/cancel and the existing desktop checks.
GDScript formatting, lint and `git diff --check` passed. The exported Linux
journey/smoke gate remains unavailable without WSL/Linux.

The Android APK built successfully and was installed on the A35. The seasonal
prompt was not exercised on the phone outside December; release/cancel behavior
was verified by the automated suite without changing the phone date.

## Deferred phone testing

- [ ] Christmas prompt: install the APK with the seasonal override removed
  (installation was deferred by the maintainer). Verify the prompt appears on
  a December cold launch, or use a temporary test build that opens the prompt
  directly without changing the phone date. Test Yes and No separately, held
  touches, dragging off and returning, and taps outside the choices. Confirm
  Yes enables Christmas art/audio, No keeps normal assets, and both return to
  the title. Verify normal startup outside December. Automated tests passed;
  these on-device checks are still outstanding.

### Campaign story and intermission touch input

Android preserves the original story/intermission artwork, text, hints and
layout. A left-button touch anywhere inside the 320×200 game image now counts
on release, rather than press. Movement more than eight logical pixels from
the initial press, or leaving the image, cancels the gesture permanently even
if the finger returns. Small finger jitter is tolerated. Unpaired releases do
nothing. Existing input-reset boundaries also discard pending gestures so a
held touch cannot carry across pages or from text reveal into the next wait.

This applies to the story screen's existing any-button paths, including text
reveal, animation skips, episode-end pages, credits and the score table. It
retains their existing timing and skip behavior, changing only when Android
pointer input is accepted. Name entry keeps its separate keyboard/Yes/No touch
handling. Desktop mouse, keyboard and gamepad paths are unchanged.

`test/story_page_touch_test.gd` checks held/released taps advancing actual page
waits, drag cancellation, input resets, name-entry isolation and desktop mouse/
Android keyboard behavior. The existing story and name-entry suites cover
campaign transitions and high-score entry.

All 15 cases across story-page touch, story-name touch and campaign story suites
passed with no errors, failures or orphans. Formatting, lint and diff checks
passed, and the Android APK built successfully. ADB had no connected device,
so installation and on-device verification remain outstanding. The exported
Linux journey/smoke gate remains unavailable without WSL/Linux.

### In-game Help touch dismissal

Android's two in-game Help panels (normally opened with F1) keep all existing
artwork, text and footer hints. A touch anywhere within the 320×200 image
advances panel one or closes panel two on release. Moving more than eight
logical pixels from the initial press, or leaving the image, cancels even if
the finger returns; small jitter is tolerated. Unpaired releases do nothing.
Changing panels through another input also cancels the pending gesture. Mouse
events are consumed while Help is open so they cannot reach the frozen level.
Keyboard/gamepad behavior and desktop mouse press activation are unchanged.
This pass does not add a touch control for opening Help.

`test/in_game_help_touch_test.gd` exercises both real Help panels over a running
level, verifying frozen tick/state while held, one panel per release, drag/offscreen
cancellation, unpaired releases, keyboard/gamepad input and the desktop click
path. Closing Help must resume simulation ticks.

All 13 cases across the in-game Help touch and existing pause suites passed
with no errors, failures or orphans. Formatting, lint and diff checks passed.
The Android APK built successfully and was installed on the A35; on-device
Help gesture verification remains pending. The exported Linux journey/smoke
gate remains unavailable without WSL/Linux.

### Android pause-menu Help entry

Android adds Help between Game Speed and Return, using the existing menu font,
palette, selection behavior and release/cancel touch handling. The shaded
background extends down by one 20-pixel row (bottom y = 157); Help is at y = 100,
Return at y = 120 and Quit at y = 140. Other rows keep their original positions.
The same seven rows have full-height invisible touch targets.

Help temporarily hides the pause menu and disables its input while showing the
two existing Help panels. Closing Help restores the same pause menu with Help
selected. The simulation remains frozen throughout and resumes only after
Return. Pause settings retain their values and save through the existing close
path. The six translated Help labels use `ig_help`. Desktop keeps its original
six rows and F1 behavior.

The pause-touch suite checks the complete pause → Help → pause → Return flow,
including frozen ticks/state, release/cancel, retained selection and desktop row
preservation. Existing Help and pause-menu suites cover panel navigation,
settings, Quit and F1.

All 24 cases across pause-touch, Help-touch and pause-menu suites passed with
no errors, failures or orphans. GDScript formatting/lint, strict locale key and
format checks, locale glyph/width checks and diff checks passed. The Android
APK built successfully and was installed on the A35. The touch-only flow has
not yet been verified on the phone. The exported Linux journey/smoke gate
remains unavailable without WSL/Linux.

Phone testing found that Help overwrote the shared VGA_SCREEN2 buffer used for
the pause background. The pause menu now retains its shaded background indices
while Help is open and restores them before redrawing. The regression test
compares the complete restored background byte-for-byte; all eight pause-touch
cases passed after this correction.

On-device retesting confirmed held/cancelled gestures on both Help panels,
the restored pause background, a stable paused image, and Return resuming play.
The corrected APK was installed and left paused on the A35; original player
files were verified byte-for-byte after testing.

### Destruct live-round pause menu

Android adds the same top-left `II` icon (normal menu font, two pixels between
bars) as the main game, with a 56×20 invisible release/cancel target. It appears
only during live rounds. The icon is a separate presentation node: it never
writes into Destruct's native VGA/terrain canvas.

Releasing the icon requests a pause at the next existing tick boundary, before
another native tick. The compact menu shades x = 56..263, y = 70..140 and draws
Resume, Help and Exit to Mode Selection centered at y = 80, 100 and 120 using
Destruct's tiny font, palette bank 12 and selected brightness 4. Its row targets
are x = 56..263, y = 76..135. Dragging off cancels even after returning.
Help opens the existing Help screen; Back returns to this menu, still frozen.
Resume restores the complete saved VGA image before native processing resumes.
Exit uses the existing STATE_INIT route to mode selection without another tick.
Music is halved while paused and restored on leaving the menu. Desktop keeps
its existing P/F1/Escape input and gains no icon or menu.

The Destruct Help touch suite also verifies this round-menu flow, frozen native
state/ticks, restored menu image after Help, Resume, Exit without a tick,
drag cancellation and desktop icon absence. No native simulation code, CPU
settings, movement, damage, collisions or RNG behavior changes.

All 18 Destruct cases passed with no errors, failures or orphans. Formatting,
lint, strict locale, glyph, width and diff checks passed. The Android APK built
successfully and was installed on the A35. The exported Linux journey/smoke
gate remains unavailable without WSL/Linux.

A35 phone testing confirmed the touch-only route through Side Modes, icon
release opening the round menu, held/drag-off cancellation, Help returning to
a stable frozen menu, Resume restarting play, and Exit returning to mode
selection. The game was left in the new pause menu. Original player files were
verified byte-for-byte, and the test-created destruct.cfg was removed.

### Opt-in Endless anomaly-card picker

The dormant `--endless-anomalies` picker keeps its original cards, layout,
fonts, palette, selection frame and mandatory choice. Android highlights a
card when pressed and confirms only on release over that same card. Leaving
its rectangle (including entering a gap or another card) cancels even after
returning. Outside taps, right clicks, unpaired releases and touches during
fades do nothing. Keyboard/gamepad navigation cancels any pending touch;
the original keyboard choice and no-cancel rules remain. Desktop retains hover
and press activation. Normal Endless play still does not enable this picker.
No card draw, deck, effect, score, RNG or simulation behavior changes.

All 12 cases across `endless_pick_touch_test.gd`, `endless_prompt_test.gd` and
`endless_resume_touch_test.gd` passed without errors, failures or orphans.
Formatting, lint and diff checks passed. The exported Linux journey/smoke gate
remains unavailable without WSL/Linux.

- [ ] Deferred phone test: use a temporary test launch/build with
  `--endless-anomalies` to verify each card, hold/release, gap/cross-card/drag-back
  cancellation, and the selected card being applied. Keep the regular Android
  build's default behavior unchanged after testing.

The Android APK built successfully and was installed on the A35. Anomalies remain
disabled by default; on-device picker verification is deferred as listed above.


### Gameplay weapon touch controls

Android interactive levels use the approved compact row just above the bottom
message bar. Original shop sidekick artwork is scaled to 65%, with the original
normal menu font for Mode. Available controls retain the order left sidekick,
Mode, right sidekick and pack against the playfield's left edge without gaps.
Their invisible, non-overlapping touch areas retain widths of 18, 30 and 22
logical pixels respectively, at y 162–184. Hidden controls reserve no space. The bottom
bar remains available for level, combo and system messages. The original score
font and colors are retained, right-aligned four pixels from the playfield's
right edge at y 3; desktop retains its original score position.

A sidekick icon is shown when the equipped sidekick has a weapon port and uses
manual ammunition or charging, matching the shop preview's visibility rule.
Automatic sidekicks and empty slots have no icon or reserved touch interception.
Mode appears only when the equipped rear weapon has multiple patterns, or when
Super Arcade can switch between two different specials. It is absent for an
empty rear slot, a single-pattern weapon and identical Super Arcade specials.
Artwork, labels and touch targets move together. Equipment changes cancel held
and pending button gestures so a moved control cannot inherit a press.
When a special is equipped, the original gold-font **Special** label appears
above this row, with a separate x 0–70, y 140–162 touch area. If all three row
controls are hidden, Special moves down to y 162–184 instead, with its label
and touch target moving together; its width stays 70 pixels. It dims using the
simulation's original ready/recharging marker. Taps during cooldown are ignored
rather than queued. This fourth control uses the same release/cancellation rules.

Each control activates only on release of a finger whose initial press was on
that same control. Dragging off cancels permanently, including if the finger
returns. A finger already steering can drag over and release on any control
without activating it or interrupting steering. Separate fingers can operate
controls while the original finger continues steering.

A release supplies one tick of mode/sidekick or dedicated special input.
Repeated taps have a released tick between pulses so each mode-switch edge is
visible to the simulation. Firing cooldowns, ammunition, charging, weapon modes,
movement, simulation timing and RNG remain owned by the simulation.
The Android special input replaces normal-fire, Super Arcade sidekick and hidden
directional-combo activation, without interrupting regular fire. The original
special effects, costs and cooldown checks are reused. Desktop retains its
original activation paths. Recordings using dedicated input use replay v5;
desktop recordings remain v4 and older replay behavior is preserved.
Pausing, Help, focus loss and leaving the level discard pending button input.
Controls are absent from desktop, demos and replay playback.

Special-alone placement follow-up (2026-11-23): all 23 weapon, level weapon and
steering tests passed without errors, failures or orphans. This includes firing
from the lowered target, steering through the vacated upper area and cancelling
held touches when Special moves between rows. Both placements were checked in
host captures; GDScript lint/format and `git diff --check` passed. No APK or phone
verification was performed for this follow-up.

Compact-row follow-up (2026-11-23): all 34 cases across the weapon, level weapon,
steering and pause touch suites passed without errors, failures or orphans.
Coverage includes all eight row visibility combinations, unchanged target widths,
release actions at shifted positions, empty trailing space allowing steering,
layout-change cancellation, empty/single-pattern rear weapons and Super Arcade
with distinct/identical specials. Six host captures were inspected (all controls,
Mode/right, left/right, right only, Mode only and no bottom-row controls).
The host DLL build, Rust formatting, GDScript lint/format and `git diff --check`
passed. APK packaging and phone verification remain outstanding.

Special-control validation (2026-11-23): all 29 cases across the weapon, level
weapon, steering and pause touch suites passed on Windows Godot, with no errors,
failures or orphans. Four dedicated-input Rust tests passed, including
all-original-special effect comparisons and v5 recording/playback with v4 input
compatibility. All 24 existing special golden recordings passed strict parity
(129,730 ticks). Host DLL build/check, GDScript lint/format, Rust formatting and
`git diff --check` passed; ready and dimmed controls were visually inspected in
host captures. This update has not been packaged or verified on the phone.
The full Rust run encountered existing Destruct config/Windows newline and
two host-libm comparison failures; the other 122 unit tests passed (one ignored).
Strict Clippy also encounters existing warnings with the installed Rust 1.100.

`touch_weapons_test.gd` covers all four release gestures, drag-off/return,
cross-control cancellation, steering across targets, simultaneous fingers,
cancelled events, hidden controls and repeated taps. `level_touch_weapons_test.gd`
verifies actual rear-mode changes, separate left/right ammunition consumption,
exclusive special activation while steering and dimming during cooldown,
automatic versus charged sidekick visibility, pause cleanup and Android versus
desktop score placement. The existing flight and pause touch suites also run.


The initial three-control validation's 22 cases across these four suites passed without errors, failures or
orphans. Host and Android native builds, APK signing/alignment validation,
GDScript lint/format, Rust formatting and `git diff --check` passed. The updated
APK was installed on the A35. Phone checks confirmed the compact row and score
placement, mode switching and separate sidekick ammo consumption only on
release. Drag-off/return cancelled all three controls; steering through the row
changed neither mode nor ammo (normal ammo refill continued). All five original
player files were restored and verified byte-for-byte after the temporary test
loadout. The game was left paused with that loadout in memory for inspection.

The exported Linux package journey/smoke gate remains unavailable because this
host has no WSL/Linux installation. Strict Clippy is blocked by existing
warnings in `tyrian-sim`; `--no-deps` also identifies the pre-existing
`mem_replace_with_default` warning at `tyrian-godot/src/shop.rs:518` under the
installed Rust 1.100 toolchain. Those unrelated sources were not changed.


### Gameplay pause utilities

Android Pause adds More... below Quit, retaining the existing Help, Return,
volume, effects and speed rows. More opens Achievements, Statistics, Quick Save,
Quick Load, Replay and Display / Capture, with Back returning to the same pause
selection. Display / Capture contains DPS Counter, Damage Numbers, Gamma cycle
and Screenshot. All rows use the original menu engine/font and disjoint
20-pixel release-activated targets; dragging off cancels. Desktop retains its
six-row pause menu and existing shortcuts. Bullet time has no touch action.

Achievements and Statistics reuse the existing in-level tables over a frozen
level. Achievements has previous/next category, up/down selection and Back
footer targets. Statistics has Back. Neither view changes the running HUD's
overlay selection, and the simulation remains stopped through all pages.
Quick Save/Load retain campaign restrictions and original save semantics;
Quick Load uses the existing Yes/No box with No selected initially. No returns
to More while paused; Yes follows the existing campaign quick-load path.
Replay retains F10 behavior: arm/cancel recording for the next level, or stop
and save an active recording. Status text confirms actions or reports failure.
DPS, damage numbers and gamma use the existing handlers; screenshot uses the
existing numbered BMP writer. Movement, weapons, Help and mute keep their
existing touch paths.

`test/pause_touch_test.gd` covers page routing, release/cancel, category and
scroll changes, restored parent selection, frozen tick/state hashes, actual
quick-save files, both quick-load answers, campaign restrictions, replay arming,
DPS/damage/gamma changes and saved settings. Native rendering is needed to
verify successful screenshot capture; headless verifies its failure message.

Validation (2026-11-23): 45 headless cases across pause-touch, level-hotkeys,
pause-menu and level-touch-weapons passed. The final pause-touch suite passed
13 cases with native Windows rendering, including numbered BMP creation and
stopping a recording to a file readable by replay playback. The five captured
pause/view pages were visually reviewed; GDScript lint/format, strict locale,
glyph/width and diff checks passed. Android device verification is pending;
no APK was built or installed in this pass. The exported Linux journey/smoke
gate could not run because WSL/Linux is not installed on this host.

## Android tilt controls

Setup > Controls replaces the unavailable Android Key Bindings entry. Tilt
Controls defaults to Off, retaining held-finger destination steering. When On,
tilt steers without touching; holding a finger on the playfield fires, and
release/cancellation stops normal fire. Weapon controls retain their separate
functions. Desktop input, demos, tools and replay playback do not read sensors.

Each playable level captures its own neutral orientation. If the gravity sensor
is not ready, movement waits and the first valid reading establishes neutral.
Pause > Controls provides the same tilt toggle and sensitivity settings while
keeping gameplay paused. Changes save immediately to the same `setup.cfg` used
by pre-game Setup. Enabling tilt mid-level captures the current holding angle
as neutral (or waits for the first valid reading). The submenu also provides
Reset Tilt Neutral and Back. Reset captures the current orientation and keeps
the game paused; its row is disabled while tilt is off. A failed capture plays the existing
rejection sound and retains any previous neutral. Neutral is not saved between
levels. Pause/focus loss still cancels held fire.

Tilt Sensitivity is saved in `setup.cfg`, from 1 to 10 (default 5). A 2-degree
dead zone suppresses drift, and readings are smoothed before conversion to
integer mouse input. Sensitivity 1 has half its initial response, reaching full
input at 66 degrees; sensitivity 10 retains its original response and reaches
full input at 8 degrees. Full-input tilt angles are spaced evenly
between those endpoints, reducing every intermediate setting too. The existing
simulation mouse clamp, inertia, bounds, timing, collisions, weapon cadence and RNG rules remain intact.
Godot's gravity sensor is enabled in `project.godot`; Godot already rotates
Android readings to match the display, so no second landscape rotation is added.
See [Godot Input](https://docs.godotengine.org/en/stable/classes/class_input.html#class-input-method-get-gravity)
and the [4.7.2 Android sensor rotation](https://github.com/godotengine/godot/blob/4.7.2-stable/platform/android/java/lib/src/main/java/org/godotengine/godot/input/GodotInputHandler.java#L744-L787).

Godot tests cover calibration, delayed/invalid readings, upright orientation,
dead zone, directions, sensitivity, native movement limits including inertia,
independent fire, level-start capture, touch-only firing while tilting, paused
recalibration, drag cancellation and desktop/demo/replay scope. Physical phone
axis direction, comfort, sensor noise and focus/resume testing remain pending;
no Android device was connected during this implementation.

Pause Controls follow-up: `pause_touch_test.gd` checks release/cancel gestures,
immediate config-file persistence, sensitivity changes through touch and menu
keys, calibration when enabling tilt, disabled reset while off, Back restoring
the parent selection, and unchanged paused tick/state hashes. The shared
pre-game rows remain covered by `setup_touch_test.gd`. Phone verification of
the new Pause > Controls submenu is recorded below.

A35 validation (2026-11-24): 26 device checks passed using real Android touch
injection and the opt-in JourneyState logger. They covered submenu routing,
held-release behavior, drag-off/return cancellation, both toggle states, all
ten sensitivity values and wraparound, immediate `setup.cfg` writes, neutral
capture against live gravity, disabled reset, Back selection restoration,
resume, cold-restart persistence and shared pre-game Controls settings. Tick
and state hash remained identical through the paused edit sequence. On/off,
reset and pre-game screenshots were inspected. This tests the actual handset's
sensor readings, but does not replace physical steering/comfort testing.

The logger now exposes the paused tick/state hash and tilt calibration/neutral
readout only when `--journey-state` is explicitly enabled. A temporary test APK
supplied that flag; the normal APK was rebuilt without it. All seven original
player files (including all three campaign saves) were restored and verified by
SHA-256 before restoring the normal build. The Linux exported-package gate
remains unavailable because WSL/Linux is absent on this Windows host.


### Destruct live-round touch controls

Android has two compact banks of the original bitmap lettering at the bottom
of the round, one per player. Each bank has Left, Right, Up and Down above
W-, Vehicle, Fire and W+. Hold directions and Fire; release Vehicle or W-/W+
to switch once. Directions retain the original vehicle-specific meaning:
Left/Right adjusts turret angle or helicopter movement; Up/Down changes shot
power, helicopter vertical movement or a jumper's jump. W- and W+ select the
previous and next weapon. The selected weapon remains visible in the original
HUD. Computer-controlled sides have dimmed lettering; the default opponent
and configured human/computer choices are unchanged.

Each control has a 40-by-22 logical-pixel hit area. Multiple fingers can hold
directions and Fire together, including on both sides. A finger owns only its
initial control; dragging off cancels until release, even when it returns.
Switches activate on release and repeated taps are queued for separate native
ticks. Android mouse emulation is ignored to prevent duplicate actions.
Pause, Help, round transitions, focus loss and scene exit clear touch input.
Focus loss requests Pause; returning to the app requires Resume.

The existing top-left Pause entry now also exposes New Map and each side's
Human/Computer toggle, alongside Resume, Help and Exit to Mode Selection.
The round remains frozen while these choices are open. New Map uses the same
round reload as Backspace, preserving scores and human/computer choices.
Touch text lives outside the simulation framebuffer so it cannot affect
terrain, collisions or future round generation. No Rust simulation rules or
Destruct's original approximately 14.4 ms tick interval were changed. Desktop
keeps its existing keyboard and gamepad paths without the touch controls.

`test/destruct_gameplay_touch_test.gd` covers simultaneous fingers, held fire,
release-only switches, cancellation, queued taps, live shots, frozen pause,
human/computer toggles, Help, New Map, focus loss and desktop scope. Its
five-mode test compares touch against the keyboard command stream and a
separate native instance for 480 ticks, including exact framebuffer and
selected-vehicle state. Run it with the existing Destruct intro, pause, Help,
round-key and screen-flow suites. These checks do not replace phone playtesting
or the exported Linux journey/smoke gate in [testing.md](testing.md).


Validation on 2026-11-24: 58 distinct cases passed across the six Destruct
suites plus shared controls, display settings and touch-flight suites, with
no errors or orphans. The final eight-case gameplay suite was rerun after
the phone font correction. GDScript formatting/lint, strict locale consistency,
glyph/width checks, hard-coded text checks and `git diff --check` passed.
The Android helper built, aligned and signed the debug APK, and an update
installed successfully on the A35. Phone captures verified the visible
control banks, vehicle/weapon HUD changes, Pause/Help, New Map producing new
terrain while retaining scores, Human/Computer selection and Home/resume
returning to Pause. Automated tests cover simultaneous fingers; actual
simultaneous fingers and prolonged play in every mode still need hands-on
phone testing. All seven pre-existing player files remained byte-identical;
the test-created destruct.cfg was removed. The phone was left paused.
The exported Linux package gate was unavailable because WSL is not installed.
