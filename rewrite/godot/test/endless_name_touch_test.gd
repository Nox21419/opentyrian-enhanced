extends GdUnitTestSuite


class NameScreen:
	extends "res://scripts/endless_end.gd"
	var answer: Variant = null

	func _run() -> void:
		answer = await _prompt_name(12345)


func after() -> void:
	Music.release_streams()
	Sfx.release_streams()


func _open(mobile := true) -> Node:
	var screen: Node = auto_free(NameScreen.new())
	screen.set("_touch_results", mobile)
	get_tree().root.add_child(screen)
	for _frame in 3000:
		if screen.idle:
			break
		await get_tree().process_frame
	return screen


func _button(screen: Node, p: Vector2, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = p
	event.pressed = down
	event.button_index = MOUSE_BUTTON_LEFT
	screen._unhandled_input(event)


func _tap(screen: Node, p: Vector2) -> void:
	_button(screen, p, true)
	_button(screen, p, false)


func _text(screen: Node, value: String) -> void:
	for letter in value:
		var event := InputEventKey.new()
		event.pressed = true
		event.unicode = letter.unicode_at(0)
		screen._unhandled_key_input(event)
	await get_tree().create_timer(0.08).timeout


func test_field_release_drag_cancel_and_skip() -> void:
	var screen := await _open()
	_button(screen, Vector2(160, 100), true)
	assert_bool(screen.get("_name_keyboard_requested")).is_false()
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2.ZERO
	screen._unhandled_input(motion)
	_button(screen, Vector2(160, 100), false)
	assert_bool(screen.get("_name_keyboard_requested")).is_false()
	_tap(screen, Vector2(160, 100))
	assert_bool(screen.get("_name_keyboard_requested")).is_true()
	_tap(screen, Vector2(220, 145))
	await get_tree().create_timer(0.5).timeout
	assert_that(screen.answer).is_equal("PLAYER")
	assert_bool(screen.get("_name_keyboard_requested")).is_false()


func test_uppercase_limit_logical_backspace_and_done() -> void:
	var screen := await _open()
	await _text(screen, "abcdefghijklmnopq")
	assert_str(screen.get("_name_text")).is_equal("ABCDEFGHIJKLMNO")
	var key := InputEventKey.new()
	key.pressed = true
	key.keycode = KEY_BACKSPACE
	screen._unhandled_key_input(key)
	await get_tree().create_timer(0.08).timeout
	assert_str(screen.get("_name_text")).is_equal("ABCDEFGHIJKLMN")
	key.keycode = KEY_ENTER
	screen._unhandled_key_input(key)
	await get_tree().create_timer(0.5).timeout
	assert_that(screen.answer).is_equal("ABCDEFGHIJKLMN")


func test_empty_confirm_stays_and_raised_confirm_works() -> void:
	var screen := await _open()
	_tap(screen, Vector2(100, 145))
	await get_tree().create_timer(0.08).timeout
	assert_that(screen.answer).is_null()
	screen.set_process(false)
	_tap(screen, Vector2(160, 100))
	screen._update_name_keyboard_layout(500)
	await get_tree().create_timer(0.08).timeout
	assert_bool(screen.get("_name_raised")).is_true()
	assert_str(screen._name_target(Vector2i(160, 60))).is_equal("keyboard")
	assert_str(screen._name_target(Vector2i(100, 85))).is_equal("confirm")
	assert_str(screen._name_target(Vector2i(220, 85))).is_equal("skip")
	assert_str(screen._name_target(Vector2i(100, 145))).is_empty()
	var heading: PackedByteArray = screen.vga.indices(0).slice(0, 320 * 55)
	await _text(screen, "phone")
	assert_that(screen.vga.indices(0).slice(0, 320 * 55)).is_equal(heading)
	_tap(screen, Vector2(100, 85))
	await get_tree().create_timer(0.5).timeout
	assert_that(screen.answer).is_equal("PHONE")
	assert_bool(screen.get("_name_raised")).is_false()


func test_desktop_keyboard_and_exit_cleanup() -> void:
	var screen := await _open(false)
	await _text(screen, "pc")
	_tap(screen, Vector2(160, 100))
	assert_bool(screen.get("_name_keyboard_requested")).is_false()
	screen._unhandled_key_input(TyrianControls.key_event(KEY_ENTER))
	await get_tree().create_timer(0.5).timeout
	assert_that(screen.answer).is_equal("PC")
	var mobile := await _open()
	_tap(mobile, Vector2(160, 100))
	mobile._exit_tree()
	assert_bool(mobile.get("_name_keyboard_requested")).is_false()
	_tap(mobile, Vector2(220, 145))
	await get_tree().create_timer(0.5).timeout


func test_ime_replacement_deletions_stay_ordered() -> void:
	var screen := await _open()
	await _text(screen, "p")
	var key := InputEventKey.new()
	key.pressed = true
	key.keycode = KEY_BACKSPACE
	screen._unhandled_key_input(key)
	await _text(screen, "ph")
	screen._unhandled_key_input(key)
	screen._unhandled_key_input(key)
	await _text(screen, "pho")
	assert_str(screen.get("_name_text")).is_equal("PHO")
	_tap(screen, Vector2(100, 145))
	await get_tree().create_timer(0.5).timeout
	assert_that(screen.answer).is_equal("PHO")
