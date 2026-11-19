# Android ARM64 proof of concept

This target is for the Samsung Galaxy A35 and other ARM64 Android devices.
It uses the existing Compatibility renderer, Original graphics and landscape
orientation. During a level, **hold one finger on the playfield to steer and fire**;
drag to move the target, and lift to stop firing. The ship approaches the finger
at the existing movement speed and stays inside its normal bounds. Extra fingers
are ignored; pause or focus loss cancels the held input. The title screen has
an Android-only two-column layout of the original gold menu text, including
a visible Side Modes entry with the same lettering.
The Players screen keeps its original single-column text, adds Back and wider
touch areas, and greys out/disables its two-player and network entries.
Episode Select keeps its original five labels and placement, adds Back and
wider touch areas, and activates a choice on release. Difficulty Select uses
the same release-to-select adaptation with Back to Episode or Timed Battle.
The shop root Game Menu also activates on release within wider column targets.
Data, Upgrade Ship, Options and Next Level and their child screens activate
on release using their original targets.
Setup, Graphics, Sound, Gameplay, Mutators and picker popups also activate on
release, with wider invisible row targets. Jukebox uses its existing text for
touch controls. Setup's Key Bindings, Joystick and Mods entries are grey and
unavailable on Android.
High Scores keeps its original arrows with wider touch targets and adds a
small Back label; both activate on release and cancel when dragged off.
Replays uses its original rows and scroll indicators as release-activated
touch targets, with Back available even when the folder is empty.
Load Game keeps its original save rows and Exit to Main Menu, with wider
release-activated targets and the two-player page control greyed out.
Instructions has wider topic targets and visible previous/next chevrons and
Back on every help page, including the embedded shop help.
Other menus still use their existing pointer/click behavior. Dedicated touch buttons for sidekicks,
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

The maintainer also requested the existing Auto-fire option locked on for
Android (continuous normal fire, including with no finger held), Bullet Time
locked off, and Rumble locked off until mobile haptics are implemented.
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
change does not adapt Timed Battle or other routes to side modes.
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
cancels. A gold Back entry at y = 185 follows the existing cancel action to
Episode Select, or Timed Battle for that mode. Desktop remains unchanged.

The original keyboard secrets still reveal the higher difficulties. When all
six are visible, Back uses the original small font at y = 190 so the sixth
label can stay at y = 174 without overlap. Its touch area starts at y = 188.
Unlocking a difficulty while Back is selected keeps Back selected. This adds
no touch shortcut for the secrets and does not change difficulty rules.

On the phone, check Easy/Normal/Hard, drag cancellation, and Back. Automated
coverage in `test/difficulty_touch_test.gd` verifies the chosen difficulty,
both Back destinations, secret unlocks and target boundaries, and desktop
geometry. Run it with the Episode, Players and existing New Game suites.

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
On Android, Bullet Time is locked Off, Auto-fire On, and Rumble Off. Rumble
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

Key Bindings, Joystick and Mods remain visible in grey but cannot be opened
on Android; navigation skips them. Desktop retains those entries and its
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
