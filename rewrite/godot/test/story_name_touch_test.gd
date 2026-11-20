extends GdUnitTestSuite


class NameScreen:
	extends "res://scripts/story_screens.gd"
	var answer: Dictionary = {}
	var timed := false

	func _run() -> void:
		answer = await _enter_name(12345, 0, false, timed, 0, 1.0)


func after() -> void:
	Music.release_streams()
	Sfx.release_streams()


func _open(mobile := true, timed := false) -> Node:
	var screen: Node = auto_free(NameScreen.new())
	screen.set("_touch_name", mobile)
	screen.timed = timed
	get_tree().root.add_child(screen)
	for _frame in 3000:
		if screen.get("_name_ready"):
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


func _text(screen: Node, text: String) -> void:
	for c in text:
		var event := InputEventKey.new()
		event.pressed = true
		event.unicode = c.unicode_at(0)
		screen._unhandled_input(event)
	await get_tree().create_timer(0.08).timeout


func test_keyboard_field_release_and_drag_off_cancel() -> void:
	var screen := await _open()
	_button(screen, Vector2(160, 90), true)
	assert_bool(screen.get("_name_keyboard_requested")).is_false()
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2.ZERO
	screen._unhandled_input(motion)
	_button(screen, Vector2(160, 90), false)
	assert_bool(screen.get("_name_keyboard_requested")).is_false()
	_tap(screen, Vector2(160, 90))
	assert_bool(screen.get("_name_keyboard_requested")).is_true()
	_tap(screen, Vector2(190, 136))
	await get_tree().create_timer(0.08).timeout
	assert_bool(screen.answer.cancel).is_true()
	assert_bool(screen.get("_name_keyboard_requested")).is_false()


func test_original_yes_no_and_empty_confirm_rules() -> void:
	for timed in [false, true]:
		var screen := await _open(true, timed)
		_button(screen, Vector2(100, 136), true)
		assert_bool(screen.name_entry).is_true()
		_button(screen, Vector2(100, 136), false)
		await get_tree().create_timer(0.08).timeout
		assert_that(screen.answer).is_equal({"name": "", "cancel": false})
		var cancelled := await _open(true, timed)
		await _text(cancelled, "test")
		_tap(cancelled, Vector2(190, 136))
		await get_tree().create_timer(0.08).timeout
		assert_that(cancelled.answer).is_equal({"name": "TEST", "cancel": true})


func test_ime_batches_limit_and_done() -> void:
	var screen := await _open()
	await _text(screen, "ph")
	var key := InputEventKey.new()
	key.pressed = true
	key.keycode = KEY_BACKSPACE
	screen._unhandled_input(key)
	screen._unhandled_input(key)
	await _text(screen, "phone")
	assert_str(screen.get("_name_text")).is_equal("PHONE")
	await _text(screen, "abcdefghijklmnopqrstuvwxyz123")
	assert_int(str(screen.get("_name_text")).length()).is_equal(28)
	key.keycode = KEY_ENTER
	screen._unhandled_input(key)
	await get_tree().create_timer(0.08).timeout
	assert_bool(screen.answer.cancel).is_false()
	assert_int(str(screen.answer.name).length()).is_equal(28)


func test_raised_modal_and_restoration() -> void:
	var screen := await _open()
	screen.set_process(false)
	_tap(screen, Vector2(160, 90))
	screen._update_name_keyboard_layout(500)
	await get_tree().create_timer(0.08).timeout
	assert_int(screen.get("_name_offset")).is_equal(-50)
	await _text(screen, "mobile")
	_tap(screen, Vector2(100, 86))
	await get_tree().create_timer(0.08).timeout
	assert_that(screen.answer).is_equal({"name": "MOBILE", "cancel": false})
	assert_int(screen.get("_name_offset")).is_equal(0)
	assert_bool(screen.get("_name_keyboard_requested")).is_false()


func test_drag_off_yes_and_desktop_click_path() -> void:
	var screen := await _open()
	_button(screen, Vector2(100, 136), true)
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2.ZERO
	screen._unhandled_input(motion)
	_button(screen, Vector2(100, 136), false)
	await get_tree().create_timer(0.08).timeout
	assert_bool(screen.name_entry).is_true()
	_tap(screen, Vector2(190, 136))
	await get_tree().create_timer(0.08).timeout
	var desktop := await _open(false)
	await _text(desktop, "pc")
	_button(desktop, Vector2(100, 136), true)
	await get_tree().create_timer(0.08).timeout
	assert_that(desktop.answer).is_equal({"name": "PC", "cancel": false})
	assert_bool(desktop.get("_name_keyboard_requested")).is_false()
