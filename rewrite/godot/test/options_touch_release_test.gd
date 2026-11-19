extends GdUnitTestSuite

const SETUP := preload("res://scripts/setup.gd")
var _saved_dir := ""
var _settings: Dictionary


func before() -> void:
	_saved_dir = Game.saves_dir
	Game.saves_dir = "user://options_release_test"
	_settings = SETUP.settings.duplicate(true)
	TyrianControls.install()


func after() -> void:
	Game.saves_dir = _saved_dir
	SETUP.settings = _settings
	SETUP.apply_settings()
	SETUP.save_settings()
	Music.release_streams()
	Sfx.release_streams()
	Game.campaign_active = false


func after_test() -> void:
	for child in Effects.game_viewport.get_children():
		child.queue_free()
		Effects.game_viewport.remove_child(child)
	await get_tree().process_frame
	await get_tree().process_frame
	Game.shop_menu_rows = {}


func _open_options() -> Node:
	Game.loadout = PackedInt32Array([1, 1, 1, 0, 1, 4, 2, 0, 0, 0, 40000])
	Game.campaign_active = true
	Game.episode = 1
	var screen: Node = Game.goto_scene(Game.SCENE_SAVE_MENU)
	await get_tree().process_frame
	await get_tree().process_frame
	screen.set("_touch_options", true)
	# Existing capture tests exercise the child handlers independently of availability.
	screen.set("_mobile_controls_disabled", false)
	screen._open_options()
	return screen


func _button(screen: Node, p: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = p
	event.pressed = pressed
	screen.handle_mouse(event)


func _tap(screen: Node, p: Vector2) -> void:
	_button(screen, p, true)
	_button(screen, p, false)


func _wait(condition: Callable) -> void:
	var until := Time.get_ticks_msec() + 3000
	while not condition.call() and Time.get_ticks_msec() < until:
		await get_tree().process_frame


func test_options_and_mouse_setting_wait_for_release() -> void:
	var screen := await _open_options()
	_button(screen, Vector2(220, 138), true)
	assert_int(screen.menus.stack.size()).is_equal(1)
	_button(screen, Vector2(220, 138), false)
	assert_int(screen.menus.stack.size()).is_equal(2)
	var before := int(SETUP.settings.mouse_buttons[0])
	_button(screen, Vector2(220, 42), true)
	assert_int(int(SETUP.settings.mouse_buttons[0])).is_equal(before)
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(100, 42)
	motion.relative = Vector2(-120, 0)
	screen.handle_mouse(motion)
	_button(screen, Vector2(220, 42), false)
	assert_int(int(SETUP.settings.mouse_buttons[0])).is_equal(before)
	_tap(screen, Vector2(220, 42))
	assert_int(int(SETUP.settings.mouse_buttons[0])).is_equal(before % 5 + 1)
	assert_bool(TyrianMouse.any_button_down()).is_false()


func test_volume_bar_keeps_geometry_and_waits_for_release() -> void:
	var screen := await _open_options()
	SETUP.settings.music_volume = 0
	_button(screen, Vector2(310, 74), true)
	assert_int(int(SETUP.settings.music_volume)).is_equal(0)
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(400, 74)
	motion.relative = Vector2(90, 0)
	screen.handle_mouse(motion)
	_button(screen, Vector2(310, 74), false)
	assert_int(int(SETUP.settings.music_volume)).is_equal(0)
	_tap(screen, Vector2(310, 74))
	assert_int(int(SETUP.settings.music_volume)).is_greater(0)


func test_keyboard_capture_starts_and_cancels_on_release() -> void:
	var screen := await _open_options()
	_tap(screen, Vector2(220, 122))
	_button(screen, Vector2(220, 42), true)
	assert_bool(screen.get("_capturing")).is_false()
	_button(screen, Vector2(220, 42), false)
	await _wait(func() -> bool: return screen.get("_capturing"))
	assert_bool(screen.get("_capturing")).is_true()
	_button(screen, Vector2(220, 42), true)
	assert_bool(screen.get("_capture_event") == null).is_true()
	_button(screen, Vector2(220, 42), false)
	await _wait(func() -> bool: return not screen.get("_capturing"))
	assert_bool(screen.get("_capturing")).is_false()


func test_save_slot_name_and_confirmation_wait_for_release() -> void:
	var screen := await _open_options()
	_button(screen, Vector2(220, 58), true)
	assert_int(screen.menus.stack.size()).is_equal(1)
	_button(screen, Vector2(220, 58), false)
	assert_int(screen.menus.stack.size()).is_equal(2)
	_button(screen, Vector2(220, 42), true)
	assert_bool(screen.get("_typing")).is_false()
	_button(screen, Vector2(220, 42), false)
	await _wait(func() -> bool: return screen.get("_typing"))
	assert_bool(screen.get("_typing")).is_true()
	_button(screen, Vector2(100, 136), true)
	assert_bool(screen.get("_pending").is_empty()).is_true()
	_button(screen, Vector2(100, 136), false)
	await _wait(func() -> bool: return screen.modal_active)
	assert_bool(screen.modal_active).is_true()
	_button(screen, Vector2(200, 136), true)
	assert_bool(screen.get("_modal_key") == null).is_true()
	_button(screen, Vector2(200, 136), false)
	await _wait(func() -> bool: return not screen.modal_active)
	assert_bool(screen.modal_active).is_false()
	assert_bool(FileAccess.file_exists(Game.saves_dir.path_join("slot_01.json"))).is_false()


func test_mobile_control_entries_are_unavailable_for_touch_and_keys() -> void:
	var screen := await _open_options()
	screen.set("_mobile_controls_disabled", true)
	screen._open_options()
	for row in [4, 5, 6]:
		assert_bool(screen.menus.current().items[row].get("unavailable", false)).is_true()
		_tap(screen, Vector2(220, 42 + row * 16))
		assert_int(screen.menus.stack.size()).is_equal(1)
		screen.menus.current().sel = row
		screen.handle_action(TyrianControls.ACCEPT)
		assert_int(screen.menus.stack.size()).is_equal(1)
	screen.menus.current().sel = 3
	screen.handle_action(TyrianControls.DOWN)
	assert_int(screen.menus.selection()).is_equal(7)


func test_desktop_retains_all_three_control_menus() -> void:
	for row in [4, 5, 6]:
		var screen := await _open_options()
		assert_bool(screen.menus.current().items[row].get("unavailable", false)).is_false()
		_tap(screen, Vector2(220, 42 + row * 16))
		assert_int(screen.menus.stack.size()).is_equal(2)
