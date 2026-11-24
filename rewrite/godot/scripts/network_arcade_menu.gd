## Approved host-operated original Arcade menu; no active campaign mutation.
extends "res://scripts/shop.gd"

const Rules := preload("res://scripts/network_initial_configuration.gd")

var _phone_touch := OS.get_name() == "Android"
var _phone_pressed := -1


func _ready() -> void:
	if not NetworkSession.selecting_arcade or not NetworkSession.lobby.hosting:
		Game.goto_scene.call_deferred("res://scenes/network_lobby.tscn")
		return
	_arcade_menu = 9
	_arcade_sel = NetworkSession.arcade_row
	var rules := Rules.new(Game.data_dir)
	var preview := rules.first_level(NetworkSession.selected_episode, NetworkSession.selected_difficulty)
	if preview.is_empty():
		NetworkSession.stop()
		Game.goto_scene.call_deferred("res://scenes/network_lobby.tscn")
		return
	Music.play_song(Music.shop_song(NetworkSession.selected_episode, int(preview.entry.section)))
	_state = {"menu": 9, "sel": 2, "loadout": PackedInt32Array([11, 1, 1, 0, 1, 4, 2, 0, 0, 0, 0]), "cash": 0}
	vga.load_pic(VGA_SCREEN, 1, true)
	_background = vga.indices(VGA_SCREEN)
	_render()


func _render() -> void:
	idle = false
	_render_arcade()


func _arcade_item_metadata(row: int) -> Dictionary:
	return {"unavailable": row in [1, 2]}


func _decorate_arcade() -> void:
	for i in 2:
		vga.text_shade(
			VGA_SCREEN, 25, 50 + 10 * i, "%s 0" % TyrianText.L("miscText_%d" % (40 + i)), 15, 0, TyrianText.FULL_SHADE
		)
		vga.dstring(VGA_SCREEN, 186, 70 + i * 32, "%s %d" % [TyrianText.L("net_phone"), i + 1], NORMAL_FONT)
	vga.text_shade(VGA_SCREEN, 10, 187, TyrianText.L("net_connection_test"), 14, 1, 2)


func _arcade_action(action: StringName) -> void:
	if action in [TyrianControls.LEFT, TyrianControls.RIGHT]:
		return
	if action in [TyrianControls.UP, TyrianControls.DOWN]:
		var rows := [2, 5, 6]
		var direction := -1 if action == TyrianControls.UP else 1
		_arcade_sel = rows[posmod(rows.find(_arcade_sel) + direction, rows.size())]
		_state.sel = _arcade_sel
		Sfx.play(Sfx.CURSOR)
		_render()
		return
	super._arcade_action(action)


func _arcade_function() -> void:
	if _arcade_sel == 2:
		NetworkSession.finish_arcade_menu()
		Game.goto_scene("res://scenes/network_lobby.tscn")
	elif _arcade_sel == 6:
		_quit_request()
	elif _arcade_sel == 5 and NetworkSession.begin_options():
		Game.goto_scene("res://scenes/network_options.tscn")
	else:
		Sfx.play(Sfx.SPRING)


func _quit_request() -> void:
	idle = false
	if await quit_request_msg(TyrianText.L("miscText_28"), TyrianText.L("miscText_30")):
		NetworkSession.stop()
		Game.goto_scene(Game.SCENE_TITLE)
	else:
		_render()


func handle_event(event: InputEvent) -> void:
	# Help is a separate review step; preserve shared navigation.
	if TyrianControls.global_pressed(event, TyrianControls.HELP):
		return
	super.handle_event(event)


func handle_mouse(event: InputEvent) -> void:
	if not _phone_touch or modal_active:
		if (
			not modal_active
			and event is InputEventMouse
			and _arcade_row_2p_at(Vector2i(event.position.floor()), 6) in [1, 2]
		):
			return
		super.handle_mouse(event)
		return
	if not idle:
		return
	var p := Vector2i(event.position.floor())
	var row := _arcade_row_2p_at(p, 6)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_phone_pressed = row
		elif row >= 0 and row == _phone_pressed:
			_phone_pressed = -1
			if row in [0, 3, 4]:
				_arcade_sel = row + 2
				Sfx.play(Sfx.CLICK)
				_arcade_function()
		else:
			_phone_pressed = -1
	elif event is InputEventMouseMotion and row != _phone_pressed:
		_phone_pressed = -1


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		_phone_pressed = -1


func _exit_tree() -> void:
	if NetworkSession.selecting_arcade:
		NetworkSession.stop()
