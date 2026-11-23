## Android pause utilities. Every action uses the existing level handler;
## the owning pause menu keeps simulation ticks stopped throughout.
extends RefCounted

const Kind := MenuEngine.Kind
var host: Node
var viewer := ""
var status := ""
var tables := LevelOverlays.new()
var background := PackedByteArray()


func _init(menu: Node) -> void:
	host = menu


func open_more() -> void:
	_open(
		[
			_action("kb_achievements", _view.bind("achievements")),
			_action("kb_stats", _view.bind("stats")),
			_action("kb_quick_save", _save),
			_action("kb_quick_load", _load_request),
			_action("kb_replay", _record),
			_action("ig_secondary", open_secondary),
			MenuEngine.item("gd_back", "", Kind.BACK),
		]
	)


func open_secondary() -> void:
	_open(
		[
			_action("kb_dps", _dps),
			_action("kb_damage_numbers", _damage),
			_action("mk_gamma", _gamma),
			_action("kb_screenshot", _screenshot),
			MenuEngine.item("gd_back", "", Kind.BACK),
		]
	)


func _action(label: String, callback: Callable) -> Dictionary:
	return MenuEngine.item(label, "", Kind.ACTION, {"action": callback})


func _open(items: Array) -> void:
	status = ""
	host._touch_release.cancel()
	(
		host
		. menus
		. open(
			"",
			items,
			{
				"x": 10,
				"y_start": 20,
				"step": 20,
				"row_width": 290,
				"no_shadow": true,
				"background": _background,
				"decorate": _decorate,
				"utilities": true,
				"hover": false,
			}
		)
	)


func _background() -> void:
	host.vga.set_indices(0, background)
	for pass_number in 2:
		host.vga.bar_shade(0, 3, 4, 303, 183)


func _text(x: int, y: int, text: String) -> void:
	TyrianText.text_shade(host, x, y, text, 15, 4, TyrianText.FULL_SHADE)


func _decorate() -> void:
	if not status.is_empty():
		_text(10, 186, status)


func _view(kind: String) -> void:
	viewer = kind
	host._touch_release.cancel()
	host.menus.open("", [MenuEngine.item("gd_back", "", Kind.BACK)], {"render": _draw_view})


func _draw_view() -> void:
	_background()
	tables.draw_frozen(
		host.vga, host.level.sim.ach_stats(), host.level.sim.ach_unlocked_flags(), viewer == "achievements"
	)
	if viewer == "achievements":
		_arrow(Vector2i(24, 192), Vector2i.LEFT)
		_arrow(Vector2i(72, 192), Vector2i.UP)
		_text(111, 188, TyrianText.L("gd_back"))
		_arrow(Vector2i(232, 192), Vector2i.DOWN)
		_arrow(Vector2i(280, 192), Vector2i.RIGHT)
	else:
		_text(111, 188, TyrianText.L("gd_back"))


## Same palette arrow and outline as the Android achievements screen.
func _arrow(center: Vector2i, direction: Vector2i) -> void:
	for shadow in [true, false]:
		var offset := Vector2i.ONE if shadow else Vector2i.ZERO
		var color := 0 if shadow else 252
		for row in 7:
			for thickness in 2:
				var p := center + direction * (1 - absi(3 - row) + thickness)
				p += Vector2i(-direction.y, direction.x) * (row - 3) + offset
				host.vga.set_pixel(0, p.x, p.y, color)


func target_at(p: Vector2i) -> String:
	if viewer.is_empty():
		return ""
	if p.y < 184 or p.y >= 200 or p.x < 0 or p.x >= 304:
		return ""
	if viewer == "stats":
		return "close"
	if p.x < 48:
		return "previous"
	if p.x < 96:
		return "up"
	if p.x < 208:
		return "close"
	return "down" if p.x < 256 else "next"


func activate_view(target: String) -> void:
	match target:
		"close":
			viewer = ""
			host.menus.back()
			return
		"previous":
			tables.change_category(-1)
		"next":
			tables.change_category(1)
		"up":
			tables.scroll(-1)
		"down":
			tables.scroll(1)
	host.menus.draw()


func handle_action(action: StringName) -> bool:
	if viewer.is_empty():
		return false
	match action:
		TyrianControls.BACK, TyrianControls.ACCEPT:
			activate_view("close")
		TyrianControls.LEFT:
			activate_view("previous")
		TyrianControls.RIGHT:
			activate_view("next")
		TyrianControls.UP:
			activate_view("up")
		TyrianControls.DOWN:
			activate_view("down")
	return true


func _save() -> void:
	var hotkeys: LevelHotkeys = host.level.hotkeys
	if not hotkeys._quick_allowed():
		status = TyrianText.L("msg_quick_campaign_only")
	else:
		status = TyrianText.L("msg_quick_saved" if hotkeys.quick_save() else "save_failed")


func _load_request() -> void:
	_load.call_deferred()


func _load() -> void:
	var hotkeys: LevelHotkeys = host.level.hotkeys
	if not hotkeys._quick_allowed():
		status = TyrianText.L("msg_quick_campaign_only")
		host.menus.draw()
		return
	hotkeys.quick_load_press()
	if not hotkeys.quick_load_pending:
		status = TyrianText.L("msg_quick_load_none")
		host.menus.draw()
		return
	hotkeys.quick_load_pending = false
	host.level.hud_pin_message("")
	host._touch_release.cancel()
	var yes: bool = await host.quit_request_msg(TyrianText.L("kb_quick_load"), TyrianText.L("ig_load_confirm"))
	host._touch_release.cancel()
	if yes:
		host.SETUP.save_settings()
		host.level.quick_load_confirmed()
	else:
		status = TyrianText.L("msg_cancelled")
		host.menus.draw()


func _record() -> void:
	var before: String = host.level.last_recording_path
	var recording: bool = host.level.sim.is_recording()
	host.level.toggle_recording()
	if recording:
		status = TyrianText.L("ig_replay_saved" if host.level.last_recording_path != before else "save_failed")
	else:
		status = TyrianText.L("msg_replay_armed" if ReplayRecording.armed else "msg_replay_disarmed")


func _dps() -> void:
	host.level.hotkeys.overlays.toggle_dps()
	status = (
		TyrianText.L("kb_dps") + " " + TyrianText.L("mods_on" if host.level.hotkeys.overlays.dps_active else "mods_off")
	)


func _damage() -> void:
	host.SETUP.toggle_damage_numbers()
	status = TyrianText.L(
		"msg_damage_numbers_on" if host.SETUP.settings.damage_numbers_enabled else "msg_damage_numbers_off"
	)


func _gamma() -> void:
	host.level.hotkeys.cycle_gamma()
	status = TyrianText.L("mk_gamma") + ": %d" % DisplaySettings.gamma()


func _screenshot() -> void:
	var number: int = host.level.hotkeys.take_screenshot()
	status = (
		TyrianText.L("msg_screenshot_saved").replace("%u", str(number - 1))
		if number > 0
		else TyrianText.L("msg_screenshot_fail")
	)
