## "Side modes" screen (block 5): choice of the mode, mutators and
## anomalies, then level launch with TyrianSim.set_modes (ADR 0050).
##
## The rules of each mode are in tyrian-sim (src/modes.rs and the functions
## it cites); this screen only sets the parameters that the C code
## sets in its menus (title_screen.c:newGame / newSuperArcadeGame,
## menus.c:timedBattleSelect, mutators_menu.c, anomalies_ui.c).
##
## Navigation: shared menu engine (MenuEngine, ADR 0121) — PICKER row
## for the mode, then one TOGGLE row per mutator and per anomaly; the drawing
## (node-based screen with TyrianText, with no 8-bit equivalent in the C code) is provided by
## the `render` option.
extends Node2D

## Name, [two_player, galaga, one_player_action, super_arcade, super_tyrian, timed],
## episode, level (]L[), difficulty, equipment (order of set_loadout).
## Starting values taken from the C golden masters (rewrite/golden/mode-*.gm):
const MODES := [
	["gd_modes_two_players", [1, 0, 0, 0, 0, 0], 1, 9, 2, [1, 1, 1, 0, 1, 4, 2, 0, 0, 0, 0]],
	["gd_modes_arcade", [0, 0, 1, 0, 0, 0], 1, 9, 2, [8, 1, 1, 0, 1, 4, 2, 0, 0, 0, 0]],
	["gd_modes_super_arcade", [0, 0, 1, 1, 0, 0], 1, 15, 3, [3, 9, 1, 0, 1, 4, 2, 0, 0, 7, 0]],
	["gd_modes_galaga", [0, 1, 1, 0, 1, 0], 1, 18, 2, [13, 39, 3, 0, 1, 4, 2, 0, 0, 0, 0]],
	["gd_modes_timed_1", [0, 0, 1, 0, 0, 1], 1, 5, 2, [8, 1, 1, 0, 1, 4, 2, 0, 0, 0, 0]],
	["gd_modes_timed_2", [0, 0, 1, 0, 0, 2], 5, 3, 2, [8, 1, 1, 0, 1, 4, 2, 0, 0, 0, 0]],
	# Destruct mini-game (destruct.c): DESTRUCT code at the C title; here
	# too, like the other hidden modes. No level: its own scene.
	["sa_destruct_name", [], 0, 0, 0, []],
]
## Index of Destruct in MODES (mutators and anomalies have no effect).
const MODE_DESTRUCT := 6
## tyrian-sim bits: modes::MUT_* (order of replay.c).
const MUTATORS := ["mut_fast_enemies", "mut_armored", "mut_bullet_hell", "mut_glass_cannon",
	"mut_no_powerups", "mut_one_life", "mut_mirror", "mut_risk_reward"]
## tyrian-sim bits: modes::ANOM_* (order of AnomalyEffect).
const ANOMALIES := ["anom_glass_hull_name", "anom_bullet_storm_name", "anom_twin_cannons_name",
	"anom_hardened_name", "anom_slow_hands_name", "anom_eyes_closed_name", "anom_combo_lock_name",
	"anom_frost_hands_name", "anom_heavy_iron_name"]

var _touch_modes := OS.get_name() == "Android"
var _touch_release := TouchRelease.new()
var _leaving := false

var mode_index := 0
var menus := MenuEngine.new(self)
## Backdrop and 8-bit framebuffer of the screen (TyrianScreen.menu_backdrop).
var screen: TyrianScreen


func _ready() -> void:
	# Rewrite's cursor (screen absent from the 8-bit C code).
	add_child(MouseCursor.new())
	screen = TyrianScreen.menu_backdrop(self)
	menus.open("gd_modes_title", _items(), {
		"render": _redraw,
		"adjust_sfx": -1,
		# Mouse (screen specific to the rewrite): row under the pointer.
		"hit": _hit_row,
		"on_back": func() -> void: Game.goto_scene(Game.SCENE_TITLE),
		"shortcuts": {
			TyrianControls.ACCEPT: start,
			# Space: like Right (next mode, or box checked / unchecked).
			TyrianControls.SELECT: func() -> bool:
				menus.adjust_horizontal(menus.current().items[menus.selection()], 1, -1)
				return true,
		},
	})


## Row 0: mode; then one toggle per bit of Game.mutators and Game.anomalies.
func _items() -> Array:
	var items := [MenuEngine.item("gd_modes_mode", "", MenuEngine.Kind.PICKER, {
		"get": func() -> int: return mode_index,
		"set": func(i: int) -> void: mode_index = i,
		"count": MODES.size(),
	})]
	for i in MUTATORS.size():
		items.append(MenuEngine.item(MUTATORS[i], "", MenuEngine.Kind.TOGGLE, {
			"get": func() -> bool: return Game.mutators & (1 << i) != 0,
			# B-18: the toggle is the C's saved global -> written to setup.cfg.
			"set": func(_v: bool) -> void: preload("res://scripts/setup.gd")._set_mutators(Game.mutators ^ (1 << i)),
		}))
	for i in ANOMALIES.size():
		items.append(MenuEngine.item(ANOMALIES[i], "", MenuEngine.Kind.TOGGLE, {
			"get": func() -> bool: return Game.anomalies & (1 << i) != 0,
			"set": func(_v: bool) -> void: Game.anomalies ^= 1 << i,
		}))
	return items


## Selected row (0 = mode).
func row() -> int:
	return menus.selection()


## Drawing in the 8-bit framebuffer on image 2 and its palette, with the C
## colors: title like menu_tree.c:run_menu (draw_font_hv_shadow 15, -4, shadow 2);
## rows in small font like mod_manager.c:1549 (JE_textShade 15, 4 on the
## chosen row, 2 otherwise, FULL_SHADE); help JE_textShade(15, 4, PART_SHADE).
## Screen specific to the rewrite (two columns).
func _redraw() -> void:
	if screen == null:
		return
	screen.begin_menu_frame()
	var r := row()
	TyrianText.draw_font_hv_shadow(screen, 160, 4, TyrianText.L("gd_modes_title"), TyrianScreen.NORMAL_FONT,
			TyrianScreen.CENTERED, 15, -4, false, 2)
	var mode_text := TyrianText.L("gd_modes_mode") % TyrianText.L(MODES[mode_index][0])
	if _touch_modes:
		mode_text = mode_text.replace("<", " ").replace(">", " ")
	_row_text(mode_text, 20, 24, r == 0, _touch_modes and mode_index == 0)
	if _touch_modes:
		_draw_touch_arrow(10, -1)
		_draw_touch_arrow(306, 1)
	for i in MUTATORS.size():
		var on: bool = Game.mutators & (1 << i) != 0
		_row_text("[%s] %s" % ["x" if on else " ", TyrianText.L(MUTATORS[i])], 20, 38 + i * 9, r == 1 + i)
	for i in ANOMALIES.size():
		var on: bool = Game.anomalies & (1 << i) != 0
		_row_text(
			"[%s] %s" % ["x" if on else " ", TyrianText.L(ANOMALIES[i])], 170, 38 + i * 9, r == 1 + MUTATORS.size() + i
		)
	if _touch_modes:
		TyrianText.draw_font_hv_shadow(screen, 88, 180, TyrianText.L("shop_start_level"), TyrianScreen.SMALL_FONT,
			TyrianScreen.CENTERED, 10 if mode_index == 0 else 15, 4, false, 2)
		TyrianText.draw_font_hv_shadow(screen, 240, 180, TyrianText.L("gd_back"), TyrianScreen.SMALL_FONT,
			TyrianScreen.CENTERED, 15, 4, false, 2)
	else:
		TyrianText.text_shade(screen, 20, 176, TyrianText.L("gd_modes_keys"), 15, 4, TyrianText.PART_SHADE)
		TyrianText.text_shade(screen, 20, 186, TyrianText.L("gd_modes_keys2"), 15, 4, TyrianText.PART_SHADE)
	screen.present()


func _row_text(s: String, x: int, y: int, selected: bool, unavailable := false) -> void:
	if unavailable:
		TyrianText.draw_font_hv_shadow(screen, x, y, s, TyrianScreen.SMALL_FONT,
			TyrianScreen.LEFT, 10, 4, false, 2)
	else:
		TyrianText.text_shade(screen, x, y, s, 15, 4 if selected else 2, TyrianText.FULL_SHADE)


func _draw_touch_arrow(x: int, direction: int) -> void:
	for shadow in [true, false]:
		var offset := 1 if shadow else 0
		var color := 0 if shadow else 252
		for row_y in 7:
			for thickness in 2:
				var px := x + direction * (1 - absi(3 - row_y)) + offset + thickness
				screen.vga.set_pixel(TyrianScreen.VGA_SCREEN, px, 24 + row_y + offset, color)


## Sets the chosen mode in Game then launches the level.
func start() -> void:
	if _leaving or (_touch_modes and mode_index == 0):
		return
	_leaving = true
	_touch_release.cancel()
	if mode_index == MODE_DESTRUCT:
		Sfx.play(Sfx.SELECT)
		Game.goto_scene(Game.SCENE_DESTRUCT)
		return
	var m: Array = MODES[mode_index]
	var flags: Array = m[1]
	Game.modes = PackedInt32Array(flags + [Game.mutators, Game.anomalies, 0, 0])
	Game.difficulty = m[4]
	Game.loadout = PackedInt32Array(m[5])
	Game.start_level_at(m[2], m[3], 0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouse:
		handle_mouse(event)
		return
	var action := TyrianControls.menu_action(event)
	if action != &"":
		handle_action(action)


func handle_mouse(event: InputEvent) -> void:
	if not _touch_modes:
		menus.handle_mouse(event)
		return
	TyrianMouse.note(event)
	if _leaving or not event is InputEventMouse:
		_touch_release.cancel()
		return
	var p := Vector2i(event.position.floor())
	var target := _touch_target(p)
	if _touch_release.feed(event, target) == null:
		return
	match target:
		"back":
			_leaving = true
			menus.back()
		"start":
			start()
		"previous", "next":
			menus.current().sel = 0
			menus.adjust_horizontal(menus.current().items[0], -1 if target == "previous" else 1, -1)
			menus.draw()
		_:
			menus.click(menus.current(), int(target.trim_prefix("row:")), p)


func _touch_target(p: Vector2i) -> String:
	if Rect2i(16, 170, 145, 30).has_point(p) and mode_index != 0:
		return "start"
	if Rect2i(176, 170, 128, 30).has_point(p):
		return "back"
	if Rect2i(0, 20, 320, 17).has_point(p):
		return "previous" if p.x < 20 else "next"
	var i := _hit_row(p)
	return "row:%d" % i if i > 0 else ""


## Row under point `p`: the mode row (y 24..37), then one toggle per
## mutator (left column) and per anomaly (right column).
func _hit_row(p: Vector2i) -> int:
	if _touch_modes:
		if Rect2i(0, 20, 320, 17).has_point(p):
			return 0
		if p.y < 37:
			return -1
		var touch_row := (p.y - 37) / 9
		if p.x >= 8 and p.x < 165 and touch_row < MUTATORS.size():
			return 1 + touch_row
		if p.x >= 165 and p.x < 313 and touch_row < ANOMALIES.size():
			return 1 + MUTATORS.size() + touch_row
		return -1
	if p.y >= 24 and p.y < 37 and p.x >= 20 and p.x < 300:
		return 0
	if p.y < 38:
		return -1
	var i := (p.y - 38) / 9
	if i < 0:
		return -1
	if p.x >= 20 and p.x < 165 and i < MUTATORS.size():
		return 1 + i
	if p.x >= 170 and p.x < 305 and i < ANOMALIES.size():
		return 1 + MUTATORS.size() + i
	return -1


## Menu action (shared InputMap, ADR 0120), handled by the shared engine.
func handle_action(action: StringName) -> void:
	_touch_release.cancel()
	if not _leaving:
		menus.handle_action(action)
