extends GdUnitTestSuite


class Prompt:
	extends "res://scripts/endless_prompt.gd"

	func _run() -> void:
		pass


func after() -> void:
	Music.release_streams()
	Sfx.release_streams()


func _open(mobile := true) -> Node:
	var screen: Node = auto_free(Prompt.new())
	screen.set("_touch_resume", mobile)
	get_tree().root.add_child(screen)
	screen.resume_prompt({"levels_completed": 3, "score": 12345})
	for _frame in 3000:
		if screen.idle:
			break
		await get_tree().process_frame
	return screen


func _button(screen: Node, p: Vector2, pressed: bool, button := MOUSE_BUTTON_LEFT) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.position = p
	event.pressed = pressed
	screen.handle_mouse(event)


func test_both_choices_return_original_results_on_release() -> void:
	for pair in [[Vector2(86, 135), true], [Vector2(234, 135), false]]:
		var screen := await _open()
		_button(screen, pair[0], true)
		await get_tree().process_frame
		assert_that(screen.result).is_null()
		_button(screen, pair[0], false)
		await get_tree().process_frame
		assert_that(screen.result).is_equal(pair[1])
		await get_tree().create_timer(0.4).timeout


func test_drag_off_return_cross_choice_and_body_cancel() -> void:
	var screen := await _open()
	for destination in [Vector2(0, 0), Vector2(234, 135)]:
		_button(screen, Vector2(86, 135), true)
		var motion := InputEventMouseMotion.new()
		motion.position = destination
		screen.handle_mouse(motion)
		_button(screen, Vector2(86, 135), false)
		await get_tree().process_frame
		assert_that(screen.result).is_null()
	_button(screen, Vector2(160, 100), true)
	_button(screen, Vector2(160, 100), false)
	_button(screen, Vector2(234, 135), true, MOUSE_BUTTON_RIGHT)
	await get_tree().process_frame
	assert_that(screen.result).is_null()
	_button(screen, Vector2(234, 135), true)
	_button(screen, Vector2(234, 135), false)
	await get_tree().process_frame
	assert_that(screen.result).is_equal(false)
	await get_tree().create_timer(0.4).timeout


func test_desktop_retains_click_anywhere_and_right_click() -> void:
	for pair in [[MOUSE_BUTTON_LEFT, true], [MOUSE_BUTTON_RIGHT, false]]:
		var screen := await _open(false)
		_button(screen, Vector2(0, 0), true, pair[0])
		await get_tree().process_frame
		assert_that(screen.result).is_equal(pair[1])
		await get_tree().create_timer(0.4).timeout


func test_android_keyboard_and_boundaries() -> void:
	for pair in [[KEY_ENTER, true], [KEY_ESCAPE, false]]:
		var screen := await _open()
		assert_str(screen._resume_target(Vector2i(155, 126))).is_equal("resume")
		assert_str(screen._resume_target(Vector2i(156, 130))).is_empty()
		assert_str(screen._resume_target(Vector2i(164, 149))).is_equal("new")
		assert_str(screen._resume_target(Vector2i(304, 130))).is_empty()
		assert_str(screen._resume_target(Vector2i(86, 150))).is_empty()
		screen._unhandled_input(TyrianControls.key_event(pair[0]))
		await get_tree().process_frame
		assert_that(screen.result).is_equal(pair[1])
		await get_tree().create_timer(0.4).timeout
