# Setup options: decision per option

## Frontend fidelity

Before implementing or building a change that affects the frontend, present
a few concrete design directions with their tradeoffs and a recommendation.
Wait for the maintainer to choose a direction before implementing or building
it, including when the frontend change follows from a broader request.
Read-only investigation can happen before presenting the options.

Frontend changes should stay as faithful to the original Tyrian 2000 as
possible, including its lettering, colors, artwork, outlines, selection
highlights, sounds and navigation behavior. Prefer adapting the original
interface's placement, size and hit areas to replacing it with generic widgets
or covering it with a second interface. This applies to all frontend screens,
not just Setup, and to every platform.

For Android, adapt one menu screen at a time for maintainer testing and keep
desktop mouse, keyboard and gamepad behavior intact. The accepted title-menu
adaptation repositions the original gold text into two columns and expands
the invisible touch areas; the replacement button overlay was rejected.
See [Android title-menu validation](android-build.md#title-touch-menu-first-menu-adaptation).

The accepted two-phone networking direction reuses Players > Modem/Network Game
with Host Game, Join Game and Back in the original style. The first screen is a
connection-only LAN test, visually approved. The original host Episode screen
now leads to the original Difficulty screen, then the host-operated original
Arcade Game Menu. Those screens are approved. Its original Options screen now
enables host-local Music/Sound volume and Done, with unsupported save/load/device
rows dimmed; this Options screen is approved. Start records intent and returns
to the lobby; playable co-op remains pending.
See [network co-op](network-coop.md).

## Option behavior and persistence

On Android, Controls replaces Key Bindings with tilt settings. Joystick remains
grey and unavailable; Mods toggles a pack on tap release (docs/android-build.md). The available Setup menus and their children use wider invisible
touch targets. Graphics' desktop Display chooser is also grey and unavailable
on Android; the remaining Graphics choices stay enabled. The menus
activate on release, cancelling when dragged off. Jukebox
uses its existing text as touch controls. Desktop behavior is unchanged; see
[Android Setup navigation](android-build.md#setup-and-child-screens).

Android Setup also includes **Secrets** for all nine Super Arcade ships,
Super Tyrian on Lord of Game or Suicide, and Destruct. These launch the original
mode flows; they do not save a setting or alter gameplay rules. Android's
Difficulty Select always shows all six difficulties. Desktop retains the
original hidden difficulty unlocks and title codes. See
[Android Secrets](android-build.md#secrets-in-android-setup).

Android Gameplay locks Bullet Time Off, Auto-fire Off and Rumble Off, with
grey, unavailable rows. Settings application enforces those values even for
older saved profiles. Normal fire lasts only while the steering finger is held,
including while stationary, and stops on release or cancellation;
Rumble only supports gamepad motors at present. Freeze Frames, Damage Numbers,
Combos, Language and Mutators stay available. Desktop retains editable values.

Rule (card t_401e6b69, point 4): an option displayed by the Setup menu acts on the game and is
saved, or it is not displayed. No dummy options.

Storage: `user://setup.cfg`, section `[setup]` (the `setup.cfg` file of the personal files,
see docs/PLAYER-GUIDE.md §6). Each change is applied immediately and saved; the
file is read back at launch (`setup.gd:load_settings`, called by `Game._ready`). Automatic
proof: `rewrite/godot/test/setup_options_test.gd` (round trip write → defaults → reload
for each wired option, plus the applied effect; the exact list of displayed lines is
verified) and, for the graphics options, `rewrite/godot/test/setup_graphics_test.gd` (real keyboard
events in Setup > Graphics, shader parameters and window stretching verified,
`display.cfg` / `setup.cfg` persistence).

Second settings file: the graphics options that have no equivalent in `setup.cfg`
(the C version stores them in the "video" section of its JSON) are saved in `user://display.cfg`,
section `[display]` — the same file as the Display screen (F10): `art_mode`, `crt_mode`, `scaler`,
`scaling_mode` (bullet time is no longer there: it is a level state, never saved, and an old `bullet_time` key is removed when read). `visual_fx` stays in `setup.cfg` (section `[setup]`).

| Menu | Option (locale key) | Decision | Effect / reason | Proof |
|---|---|---|---|---|
| Setup | Graphics | kept | submenu | `test_setup_screen_lists_only_wired_options` |
| Setup | Sound | kept | submenu | same |
| Setup | Gameplay | kept | submenu | same |
| Setup | Key Bindings (`setup_keybindings`) | **wired** | opens the Controls screen (F9); Esc goes back to Setup. The "enhanced" / menu / game key lines, which displayed values with no way to capture them, are removed | same |
| Setup | Joystick (`setup_joystick`) | **restored** (sound work package) | between Key Bindings and Mods like `setup_menu.c`; opens the Gamepad screen (`joystick_menu.gd`, port of `joystick_menu.c`): gamepad (player 1 / player 2, name of the connected gamepad), **Analog** (`analog_N`), **Sensitivity** and **Threshold** 0..10 (`sensitivity_N`, `threshold_N`: `joystick_axis_reduce` / `joystick_axis_threshold` in `TyrianControls.read_analog`), ten assignments with two slots each (capture of a button or of an axis pushed two thirds of the way, second capture = removal, `joystick_assign_toggle`), **Reset**. Everything in `controls.cfg` (section `[joystick]`, `*_axes`, `pause_buttons`, `menu_buttons`). Differences: the settings exist even without a connected gamepad (the C version displayed "no gamepad"); Analog off by default like the C version (a controls.cfg that enables it keeps it, ADR 0051) | `joystick_settings_test.gd` |
| Setup | Mods | already active | mod manager (`mods.cfg`) | `menus_test.gd` |
| Setup | Jukebox (`setup_jukebox`) | **wired** | Jukebox screen (jukebox.gd, starfield starlib.c ported to Rust: starlib.rs) | `test_setup_screen_lists_only_wired_options`, `jukebox_test.gd` |
| Graphics | Display (`gfx_display`) | **wired** | 0 = window, n = fullscreen on screen n (`DisplayServer`); key `display` | `test_display_persisted` (read back; fullscreen has no effect in headless) |
| Graphics | Scaler (`gfx_scaler`) | **wired** | the nine entries of `video_scale.c:scalers[]` (None, 2x, Scale2x, hq2x, 3x, Scale3x, hq3x, 4x, hq4x), key `[display] scaler`. None/2x/3x/4x = nearest neighbor; Scale2x/Scale3x ported from the C version (`video_scale.c`, shader `post.gdshader`); hq2x/hq3x/hq4x = closest equivalent, the xBRZ freescale filter already in use (see docs/divergences.md). The scaler factor also sets the window size in windowed mode (`video.c:init_scaler`) and the CRT scanline step (`shader.c`) | `test_scaler_applied_and_persisted` |
| Graphics | Scaling Mode (`gfx_scaling_mode`) | **wired** | the six modes of `video.c:scaling_mode_names[]` (Center, Integer, Fit 8:5, Fit 4:3, Fit 16:9, Fill) ported to the window stretching (`Window.content_scale_mode/aspect/size/stretch`, `Effects._apply_scale`), key `[display] scaling_mode` | `test_scaling_mode_applied_and_persisted` |
| Graphics | CRT (`gfx_crt`) | **wired** | the six modes of `video.h:CrtMode` (off, scanlines, crt plus, crt premium, aperture, soft) in `post.gdshader`, parameters from `shader.c:shader_render` (intensity, curvature, halo, aberration, mask, vignette); key `[display] crt_mode`; the old boolean `[display] crt` migrates to "crt plus" | `test_crt_six_modes_applied_and_persisted`, `test_legacy_crt_bool_migrates` |
| Graphics | Sprites (`gfx_sprites`) | **wired** | `graphics_menu.c:SpriteMode`: Original / Remastered / Upscaled (xBRZ). Same setting as the Display screen (F10) — a single source of truth, `[display] art_mode`: Remastered = HD (AI), Upscaled (xBRZ) = Sharp pixel art. The HD line is only offered if `upscaled/` is present (`graphics_menu.c:sprite_set`) | `test_sprites_drive_art_mode` |
| Graphics | Visual FX (`gfx_visual_fx`) | **wired** | C presets Off / Basic / Extended -> `visual_fx.c:preset_table`: `config.c:processorType` 1 / 3 / 4 (with the C version's particles, shakes and advanced lighting); key `[setup] visual_fx`, read by the simulation when the level loads (`TyrianSim.set_processor_type`) | `test_visual_fx_drives_processor_type` |
| Graphics | Explosions (`gfx_exfx`) | **wired** | `explosion_style` 0 Classic / 1 Retro+ (default) / 2 Modern: particles from particles.c ported (tyrian-godot `fx_render.rs`, own generator), RGBA layer; Modern also removes the 4 corner sprites of `JE_setupExplosionLarge` (simulation, never under golden master) | `setup_gameplay_fx_test.gd`: `test_explosion_style_by_keyboard_persisted`, `test_explosion_styles_particles` |
| Sound | Music (`snd_music`) | **wired** | volume `music_volume` (`Music.user_volume`, next level included); Enter mutes / unmutes (`music_disabled`, `Music.muted`) | `test_music_volume_and_mute_persisted_and_applied` |
| Sound | Sound FX (`snd_sfx`) | **wired** | volume `fx_volume` (`Sfx.volume`, gain of the 8 channels); Enter mutes / unmutes (`samples_disabled`, `Sfx.enabled`) | `test_sfx_volume_mute_pitch_persisted_and_applied` |
| Sound | SFX Pitch Variation (`snd_sfx_pitch`) | **wired** | ±5 % pitch per effect (`nortsong.c:random_pitch_step`), `Sfx.pitch_variation` | same |
| Sound | Stereo (`snd_stereo`) | **restored** | `stereo_enabled`: panning of each effect according to its position on screen (`loudness.h:screen_x_to_pan`, gains from `loudness.c:audioCallback`), `TyrianSfxPan` effect on the bus of each of the 8 channels; positions read from the simulation's effect queue (`tyrian-sim/src/sound.rs`, `soundQueueX`, rendering only). Off: centered effects and MIDI folded down to mono (`AudioEffectPanner` + mono `TyrianSfxPan` mix) like the C version | `setup_sound_test.gd:test_stereo_pans_effects_by_screen_position` |
| Sound | SFX Impact Scaling (`snd_sfx_impact`) | **restored** | `sfx_impact_scaling`: `soundQueueDmg` (exposed by the simulation) gives 0.80× / 0.65× pitch and the raised volume level of `JE_flushSoundQueue` for big enemies and bosses | `setup_sound_test.gd:test_impact_scaling_follows_damage` |
| Sound | Music Engine (`snd_music_engine`) | **wired**, three choices from the C version | `music_engine`: 0 **Classic** (DOSBox offline render, `assets/imported/music`), 1 **Authentic** (Nuked OPL3 offline render from the C version, `assets/imported/music_nuked`, same `tools/music-render` tool with `MUSIC_BACKEND=nuked`), 2 **Enhanced** (MIDI, `data/midi`, `soundfont.sf2`, ADR 0130), **default of a new profile** like the published C version (`loudness.c:40-45`). `Music.set_engine` restarts the current track; fallback to Classic if a Nuked render is missing, fallback to OPL if MIDI / SoundFont are missing. **Migration**: a `setup.cfg` without `[format] music_engine` (old numbering 0 OPL, 1 MIDI) is converted (1 → 2) on load | `setup_sound_test.gd` (Authentic loaded, stream different from Classic, migration), `music_engine_test.gd` |
| Sound | Music Widen (`snd_music_widen`) | **restored** | `music_pseudo_stereo`: `TyrianPseudoStereo` effect on the OPL music bus (`MusicOpl`), same algorithm as `loudness.c:ps_widen` (delay `rate / 1700` frames, crossed 2/3 – 1/3 mix), no effect on MIDI like the C version | `setup_sound_test.gd:test_music_widen_makes_left_and_right_differ` (left/right difference measured on the output) |
| Gameplay | Bullet Time (`gp_bullet_time`) | **wired** | `Effects.bullet_time_allowed`: Left Shift (trigger, side mouse button) has no effect when disabled | `test_bullet_time_persisted_and_applied` |
| Gameplay | Freeze Frames (`gp_freeze_frames`) | **wired** | `hitstop_enabled` (true by default like save_json.c): enemies frozen for 2–3 ticks (hitstop.c), cascade of 5 explosions on the defeated boss, slow motion and flash; never under golden master / replay / tools | `test_gameplay_rows_by_keyboard_persisted`, `test_freeze_frames_freeze_enemies` |
| Gameplay | Damage Numbers (`gp_damage_numbers`) | **wired** | `damage_numbers_enabled` + `colored_damage_numbers` (off / on / colored, default colored), drawn in game_screen (damagenumbers.c); F7 toggles in level | `test_damage_numbers_shown_with_color`, `test_f7_toggles_damage_numbers` |
| Gameplay | Combos (`gp_combo`) | **wired** | `Game.combos_enabled` → `TyrianSim.set_combos` (Endless); in the campaign, money stays that of the original, with no multiplier (divergences.md no. 29) | `test_combo_persisted_and_applied`, `campaign_money_test.gd` |
| Gameplay | Auto-Fire (`gp_auto_fire`) | **wired** | permanent fire for both players (`player_movement.c`: `button[0] \|\| auto_fire_enabled`), `Game.read_input_mask*` | `test_auto_fire_persisted_and_applied` |
| Gameplay | Language (`gp_language`) | already active, **now saved** | `TyrianText.language`; read back at launch | `test_language_persisted_and_applied` |
| Gameplay | Rumble (`gp_rumble`) | **wired** | `rumble_enabled`: `Input.start_joy_vibration` on each gamepad, same events and intensities as rumble.c (kill 0.2/100 ms, ≥ 500 pts 0.6/200 ms, hit 0.8/300 ms, death 1.0/500 ms) | `test_rumble_calls_vibration` |
| Gameplay | Mutators (`gp_mutators`) | **wired** | mutators_menu.c submenu (8 toggles + Reset All) on `Game.mutators` (same variable as the modes screen), key `mutators`, applied to every game (C globals mut_*) | `test_mutators_submenu_applied_to_sim` |

The Setup and Sound screens deliberately differ from the retired C menus.
Their current UI sequences (`setup`, `graphics`, `sound`, `gameplay`) use reviewed
Godot fingerprints in `rewrite/golden/ui/`. Only regenerate affected references
after an intentional change and visual review; restoration of the sound options
is already implemented, not pending reference work.

Joystick has its own Gamepad screen, covered by `joystick_settings_test.gd`;
Key Bindings opens the Controls screen, covered by `controls_test.gd`. The
`SEQUENCES` array in `rewrite/scripts/ui_regression.sh` owns the current sequence
list and reference classification, including instructions, pause/help, mouse
and Destruct. Read [the UI reference guide](../rewrite/golden/ui/README.md)
before updating fingerprints. The GitHub workflow runs only on manual dispatch;
local validation requirements are in [testing.md](testing.md).

Pause menu options (in-level menu, `mainint.c:JE_inGameSetup`):

| Menu | Option (locale key) | Decision | Effect / reason | Proof |
|---|---|---|---|---|
| Pause menu | Music Vol. / Sound Vol. (`ig_music_vol`, `ig_sfx_vol`) | **wired** | same keys as Setup > Sound (`music_volume`, `fx_volume`, `music_disabled`, `samples_disabled`); Left/Right ±12, Enter mutes; saved when the menu closes (save_json_save) | `pause_menu_test.gd:test_volume_rows_apply_and_save` |
| Pause menu | Game Speed (`ig_game_speed`) | **wired** | key `game_speed` (1..5, 4 = Normal, save_json.c "game_speed"); ticks per second of the level (`game_speed.gd`); `--speed=1..6` forces it without saving it | `pause_menu_test.gd:test_game_speed_rows_set_ticks_per_second`, `test_speed_override` |

## Android tilt controls

Android Setup > Controls replaces Key Bindings, with Tilt Controls (Off by
default) and saved Tilt Sensitivity (1–10, default 5). Enabled tilt steers the
ship while held playfield touch fires. Each level captures neutral; Pause >
Controls offers the same toggle and sensitivity while paused, saving changes
immediately. Enabling tilt captures a new neutral. Reset Tilt Neutral is inside
Controls and disabled while tilt is off. The nine-row Android pause menu moves
up eight logical pixels to keep Controls visible. Desktop retains its layout.
Sensor details, gameplay preservation and QA status are in [Android tilt controls](android-build.md#android-tilt-controls).
