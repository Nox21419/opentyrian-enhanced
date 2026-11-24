extends GdUnitTestSuite

const DESTRUCT := preload("res://scripts/destruct.gd")
const TOUCH := preload("res://scripts/destruct_touch.gd")
var _saved_config := ""


func before() -> void:
	_saved_config = DESTRUCT.CONFIG_FILE
	DESTRUCT.CONFIG_FILE = "user://destruct_gameplay_touch_test.cfg"


func after_test() -> void:
	for child in Effects.game_viewport.get_children():
		child.queue_free()
		Effects.game_viewport.remove_child(child)
	await get_tree().process_frame
	await get_tree().process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(DESTRUCT.CONFIG_FILE))


func after() -> void:
	DESTRUCT.CONFIG_FILE = _saved_config
	Music.release_streams()
	Sfx.release_streams()


func _finger(control: Node, index: int, target: int, pressed: bool, canceled := false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = TOUCH.target_rect(target).get_center()
	event.pressed = pressed
	event.canceled = canceled
	control.feed(event)


func _controls() -> Node:
	var control: Node = auto_free(TOUCH.new())
	add_child(control)
	control.update_state(true, false, false)
	return control


func test_multitouch_holds_and_release_edges_for_both_players() -> void:
	var control := _controls()
	for target in 16:
		_finger(control, target, target, true)
	var held: PackedInt32Array = control.read_moves()
	for player in 2:
		for command in 8:
			assert_int(held[player * 8 + command]).is_equal(0 if command in [4, 6, 7] else 1)
	for target in 16:
		_finger(control, target, target, false)
	var taps: PackedInt32Array = control.read_moves()
	for player in 2:
		for command in 8:
			assert_int(taps[player * 8 + command]).is_equal(1 if command in [4, 6, 7] else 0)
	assert_that(control.read_moves()).is_equal(PackedInt32Array([0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]))


func test_drag_off_cancel_and_focus_reset_do_not_rearm() -> void:
	var control := _controls()
	_finger(control, 0, 6, true)
	assert_int(control.read_moves()[5]).is_equal(1)
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = Vector2(160, 100)
	control.feed(drag)
	drag.position = TOUCH.target_rect(6).get_center()
	control.feed(drag)
	assert_int(control.read_moves()[5]).is_equal(0)
	_finger(control, 0, 6, false)
	_finger(control, 1, 5, true)
	_finger(control, 1, 5, false, true)
	assert_int(control.read_moves()[4]).is_equal(0)
	_finger(control, 2, 5, true)
	_finger(control, 2, 5, false)
	control.update_state(false, false, false)
	control.update_state(true, false, false)
	assert_int(control.read_moves()[4]).is_equal(0)


func test_two_fingers_on_fire_release_independently_and_taps_queue() -> void:
	var control := _controls()
	_finger(control, 1, 6, true)
	_finger(control, 2, 6, true)
	_finger(control, 1, 6, false)
	assert_int(control.read_moves()[5]).is_equal(1)
	_finger(control, 2, 6, false)
	assert_int(control.read_moves()[5]).is_equal(0)
	for i in 2:
		_finger(control, i, 5, true)
		_finger(control, i, 5, false)
	assert_int(control.read_moves()[4]).is_equal(1)
	assert_int(control.read_moves()[4]).is_equal(1)
	assert_int(control.read_moves()[4]).is_equal(0)


func _phase(screen: Node, expected: String) -> void:
	var deadline := Time.get_ticks_msec() + 6000
	while is_instance_valid(screen) and screen.phase != expected and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	assert_str(screen.phase).is_equal(expected)


func _open(mobile := true) -> Node:
	var screen: Node = load("res://scenes/destruct.tscn").instantiate()
	screen.set("_touch_menus", mobile)
	Effects.game_viewport.add_child(screen)
	await _phase(screen, "intro")
	screen.handle_event(TyrianControls.key_event(KEY_ENTER))
	await _phase(screen, "menu")
	screen.handle_event(TyrianControls.key_event(KEY_ENTER))
	await _phase(screen, "play")
	return screen


func _screen_touch(screen: Node, index: int, point: Vector2, down: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = point
	event.pressed = down
	screen._input(event)


func _tap(screen: Node, point: Vector2) -> void:
	_screen_touch(screen, 4, point, true)
	_screen_touch(screen, 4, point, false)


func test_live_fire_pause_cpu_toggles_help_and_new_map() -> void:
	var screen := await _open()
	_screen_touch(screen, 0, TOUCH.target_rect(6).get_center(), true)
	var deadline := Time.get_ticks_msec() + 2000
	while screen.game.state()[4] == 0 and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	assert_int(screen.game.state()[4]).is_greater(0)
	_tap(screen, Vector2(20, 10))
	await _phase(screen, "round_pause")
	assert_int(screen._touch_controls.read_moves()[5]).is_equal(0)
	var tick: int = screen._tick
	var state: PackedInt32Array = screen.game.state()
	var cpu_left: bool = screen.game.is_cpu(0)
	var cpu_right: bool = screen.game.is_cpu(1)
	_tap(screen, Vector2(160, 162))
	await get_tree().process_frame
	assert_bool(screen.game.is_cpu(0)).is_equal(not cpu_left)
	_tap(screen, Vector2(160, 182))
	await get_tree().process_frame
	assert_bool(screen.game.is_cpu(1)).is_equal(not cpu_right)
	assert_int(screen._tick).is_equal(tick)
	assert_that(screen.game.state()).is_equal(state)
	_tap(screen, Vector2(160, 102))
	await _phase(screen, "wait")
	_tap(screen, Vector2(280, 192))
	await _phase(screen, "round_pause")
	_tap(screen, Vector2(160, 142))
	await _phase(screen, "play")
	assert_int(screen.game.state()[4]).is_equal(0)
	assert_bool(screen.game.is_cpu(0)).is_equal(not cpu_left)
	_screen_touch(screen, 0, TOUCH.target_rect(6).get_center(), false)
	assert_int(screen._touch_controls.read_moves()[5]).is_equal(0)
	# Focus loss freezes via the existing pause flow and clears input.
	screen._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	await _phase(screen, "round_pause")
	_tap(screen, Vector2(160, 122))
	await _phase(screen, "menu")


func test_desktop_has_no_controls_and_ignores_raw_touch() -> void:
	var screen := await _open(false)
	assert_object(screen._touch_controls).is_null()
	_screen_touch(screen, 0, TOUCH.target_rect(6).get_center(), true)
	assert_int(screen._read_moves()[5]).is_equal(0)


## The same command stream must produce identical native frames/state in all
## five modes, including helicopters, jumpers and all weapon/vehicle switches.
func test_touch_matches_keyboard_in_all_native_modes() -> void:
	var screen: Node = auto_free(DESTRUCT.new())
	var control := _controls()
	screen._touch_controls = control
	for mode in 5:
		var native: RefCounted = ClassDB.instantiate("TyrianDestruct")
		var reference: RefCounted = ClassDB.instantiate("TyrianDestruct")
		var reference_vga: RefCounted = ClassDB.instantiate("TyrianVga")
		native.load_config(PackedByteArray(), 1234, 0)
		reference.load_config(PackedByteArray(), 1234, 0)
		DESTRUCT.install_actions(native.key_config())
		screen.vga.load_pic(0, 11, false)
		reference_vga.load_pic(0, 11, false)
		native.start_round(screen.vga, mode)
		reference.start_round(reference_vga, mode)
		for player in 2:
			if native.is_cpu(player):
				native.toggle_cpu(player)
				reference.toggle_cpu(player)
		for tick in 96:
			var target: int = (tick / 12) % 8
			var command: int = TOUCH.COMMANDS[target]
			var switch_action: bool = command in [4, 6, 7]
			var pressed: bool = tick % 12 == 0
			var released: bool = tick % 12 == 6
			for player in 2:
				if pressed or released:
					_finger(control, player, player * 8 + target, pressed)
					var events := InputMap.action_get_events(DESTRUCT.action_name(player, command))
					var key: InputEventKey = events[0].duplicate()
					key.pressed = released if switch_action else pressed
					# Switch taps are emitted on release, once, just like a key press.
					screen.handle_event(key)
			native.tick_draw(screen.vga)
			reference.tick_draw(reference_vga)
			var moves: PackedInt32Array = control.read_moves()
			screen._touch_controls = null
			var keyboard: PackedInt32Array = screen._read_moves()
			screen._touch_controls = control
			assert_that(moves).is_equal(keyboard)
			var expected := PackedInt32Array()
			expected.resize(16)
			if (switch_action and released) or (not switch_action and tick % 12 < 6):
				for player in 2:
					expected[player * 8 + command] = 1
			assert_that(moves).is_equal(expected)
			native.tick_input(moves)
			reference.tick_input(expected)
			assert_that(native.state()).is_equal(reference.state())
			for player in 2:
				assert_that(native.selected_unit(player)).is_equal(reference.selected_unit(player))
			assert_bool(screen.vga.indices(0) == reference_vga.indices(0)).is_true()
		control.reset()
		screen._keys.clear()


func test_scaled_raw_touch_routes_once_and_emulated_mouse_is_ignored() -> void:
	var screen := await _open()
	var saved_size: Vector2 = Effects._screen.size
	var saved_base: Vector2 = Effects._screen_base
	Effects._screen.size = Vector2(320, 240)
	Effects._screen_base = Vector2(10, 20)
	var event := InputEventScreenTouch.new()
	event.index = 1
	event.position = TOUCH.target_rect(6).get_center() * Vector2(1, 1.2) + Effects._screen_base
	event.pressed = true
	Effects._unhandled_input(event)
	assert_int(screen._read_moves()[5]).is_equal(1)
	event.pressed = false
	Effects._unhandled_input(event)
	assert_int(screen._read_moves()[5]).is_equal(0)
	Effects._screen.size = saved_size
	Effects._screen_base = saved_base
	var mouse := InputEventMouseButton.new()
	mouse.device = InputEvent.DEVICE_ID_EMULATION
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.position = Vector2(20, 10)
	for down in [true, false]:
		mouse.pressed = down
		screen.handle_mouse(mouse)
	assert_bool(screen._round_pause_requested).is_false()


func test_translated_control_labels_fit_their_targets() -> void:
	for lang in ["en", "de", "es", "fr", "it", "pt"]:
		for key in ["left_dir", "right_dir", "up", "down", "vehicle", "fire"]:
			var text := TyrianText.L("destruct_touch_" + key, lang)
			assert_float(TyrianText.measure(text, TyrianText.FontKind.NORMAL) * 0.65).is_less_equal(38.0)
		for side in ["left", "right"]:
			for mode in ["human", "cpu"]:
				var text := TyrianText.L("destruct_touch_" + side, lang) % TyrianText.L("destruct_touch_" + mode, lang)
				assert_int(TyrianText.measure(text, TyrianText.FontKind.SMALL)).is_less_equal(208)
	TyrianText.L("gd_resume")
