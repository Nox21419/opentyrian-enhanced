extends GdUnitTestSuite

var _saved_dir := ""
var _dir := ""


func before() -> void:
	_saved_dir = Game.saves_dir
	Game.saves_dir = "user://save_name_touch_test"
	_dir = ProjectSettings.globalize_path(Game.saves_dir)
	DirAccess.make_dir_recursive_absolute(_dir)
	for file in DirAccess.get_files_at(_dir):
		DirAccess.remove_absolute(_dir.path_join(file))


func after() -> void:
	Game.saves_dir = _saved_dir
	Game.campaign_active = false
	DirAccess.remove_absolute(_dir)
	Music.release_streams()
	Sfx.release_streams()


func after_test() -> void:
	for child in Effects.game_viewport.get_children():
		child.queue_free()
		Effects.game_viewport.remove_child(child)
	await get_tree().process_frame
	for file in DirAccess.get_files_at(_dir):
		DirAccess.remove_absolute(_dir.path_join(file))
	TyrianMouse.buttons = 0
	TyrianMouse.inactive = true


func _wait(condition: Callable) -> void:
	var deadline := Time.get_ticks_msec() + 4000
	while not condition.call() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	assert_bool(condition.call()).is_true()


func _button(screen: Node, p: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = p
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	screen.handle_mouse(event)


func _tap(screen: Node, p: Vector2) -> void:
	_button(screen, p, true)
	_button(screen, p, false)


func _open(mobile := true, initial := "") -> Node:
	EndlessSession.stop()
	Game.modes = PackedInt32Array()
	Game.campaign_active = true
	Game.episode = 1
	Game.main_level = 4
	Game.initial_difficulty = 2
	Game.difficulty = 2
	Game.loadout = PackedInt32Array([1, 1, 1, 0, 1, 4, 2, 0, 0, 0, 24680])
	if not initial.is_empty():
		assert_bool(Game.save_campaign(1, initial)).is_true()
	var screen: Node = Game.goto_scene(Game.SCENE_SAVE_MENU)
	await get_tree().process_frame
	await get_tree().process_frame
	screen.set("_touch_options", true)
	screen.set("_mobile_name_keyboard", mobile)
	screen._open_options()
	_tap(screen, Vector2(220, 58))
	_tap(screen, Vector2(220, 42))
	await _wait(func(): return screen._typing)
	return screen


func _text(screen: Node, text: String) -> void:
	for character in text:
		var event := InputEventKey.new()
		event.unicode = character.unicode_at(0)
		event.pressed = true
		screen.handle_event(event)
	await _wait(func(): return screen._pending.is_empty())


func test_name_field_release_opens_keyboard_and_drag_off_cancels() -> void:
	var screen := await _open()
	_button(screen, Vector2(120, 90), true)
	assert_bool(screen._name_keyboard_requested).is_false()
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(120, 110)
	screen.handle_mouse(motion)
	_button(screen, Vector2(120, 90), false)
	assert_bool(screen._name_keyboard_requested).is_false()
	_tap(screen, Vector2(120, 90))
	assert_bool(screen._name_keyboard_requested).is_true()
	_tap(screen, Vector2(200, 136))
	await _wait(func(): return not screen._typing)
	assert_bool(screen._name_keyboard_requested).is_false()
	assert_bool(FileAccess.file_exists(_dir.path_join("slot_01.json"))).is_false()


func test_mobile_text_backspace_limit_and_saved_name() -> void:
	var screen := await _open()
	_tap(screen, Vector2(120, 90))
	await _text(screen, "phone")
	assert_str(screen._name_text).is_equal("PHONE")
	var backspace := InputEventKey.new()
	backspace.keycode = KEY_BACKSPACE
	backspace.pressed = true
	screen.handle_event(backspace)
	await _wait(func(): return screen._pending.is_empty())
	assert_str(screen._name_text).is_equal("PHON")
	await _text(screen, "e1234567890123456789")
	assert_str(screen._name_text).is_equal("PHONE123456789")
	var done := InputEventKey.new()
	done.keycode = KEY_ENTER
	done.pressed = true
	screen.handle_event(done)
	await _wait(func(): return screen.modal_active)
	assert_bool(screen._name_keyboard_requested).is_false()
	_tap(screen, Vector2(100, 136))
	await _wait(func(): return not screen.modal_active)
	var file := FileAccess.open(_dir.path_join("slot_01.json"), FileAccess.READ)
	assert_object(file).is_not_null()
	if file != null:
		var saved: Dictionary = JSON.parse_string(file.get_as_text())
		assert_str(saved.name).is_equal("PHONE123456789")


func test_cancel_keeps_original_save_and_desktop_field_does_not_open_keyboard() -> void:
	var screen := await _open(false, "ORIGINAL")
	var original := FileAccess.get_file_as_bytes(_dir.path_join("slot_01.json"))
	_tap(screen, Vector2(120, 90))
	assert_bool(screen._name_keyboard_requested).is_false()
	await _text(screen, "X")
	assert_str(screen._name_text).is_equal("ORIGINALX")
	_tap(screen, Vector2(200, 136))
	await _wait(func(): return not screen._typing)
	assert_array(Array(FileAccess.get_file_as_bytes(_dir.path_join("slot_01.json")))).is_equal(Array(original))


func test_scene_exit_closes_keyboard_request() -> void:
	var screen := await _open()
	_tap(screen, Vector2(120, 90))
	assert_bool(screen._name_keyboard_requested).is_true()
	Effects.game_viewport.remove_child(screen)
	assert_bool(screen._name_keyboard_requested).is_false()
	screen.queue_free()
	await get_tree().process_frame


func test_keyboard_shifts_only_modal_and_shifted_no_cancels() -> void:
	var screen := await _open()
	_tap(screen, Vector2(120, 90))
	screen.set_process(false)  # Supply the keyboard height without a platform IME.
	var image_size: Vector2 = Effects._screen.size
	var image_position: Vector2 = Effects._screen_base
	var before: PackedByteArray = screen.vga.indices(0).slice(0, 320 * 50)
	screen._update_name_keyboard_layout(500)
	await _wait(func(): return not screen._name_redraw)
	assert_int(screen._name_modal_offset).is_equal(-50)
	assert_str(screen._touch_target(Vector2i(120, 39))).is_equal("name:keyboard")
	assert_str(screen._touch_target(Vector2i(200, 86))).is_equal("name:no")
	assert_str(screen._touch_target(Vector2i(200, 136))).is_empty()
	assert_array(Array(screen.vga.indices(0).slice(0, 320 * 50))).is_not_equal(Array(before))
	assert_vector(Effects._screen.size).is_equal(image_size)
	assert_vector(Effects._screen_base).is_equal(image_position)
	screen._update_name_keyboard_layout(0)
	await _wait(func(): return not screen._name_redraw)
	assert_int(screen._name_modal_offset).is_equal(0)
	assert_str(screen._touch_target(Vector2i(200, 136))).is_equal("name:no")
	screen._update_name_keyboard_layout(500)
	_button(screen, Vector2(200, 86), true)
	assert_bool(screen._pending.is_empty()).is_true()
	_button(screen, Vector2(200, 86), false)
	await _wait(func(): return not screen._typing)
	assert_int(screen._name_modal_offset).is_equal(0)
	assert_bool(FileAccess.file_exists(_dir.path_join("slot_01.json"))).is_false()
