extends GdUnitTestSuite


class Pages:
	extends "res://scripts/story_screens.gd"
	var page := 0

	func _run() -> void:
		await _wait_any_button()
		page = 1
		await _wait_any_button()
		page = 2


func _button(screen: Node, p: Vector2, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = p
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	screen._input(event)


func _motion(screen: Node, p: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = p
	screen._input(event)


func _open() -> Node:
	var screen := Pages.new()
	screen._touch_name = true
	get_tree().root.add_child(screen)
	await get_tree().process_frame
	return screen


func _close(screen: Node) -> void:
	screen.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


func test_release_advances_one_page_and_hold_does_not() -> void:
	var screen := await _open()
	_button(screen, Vector2(140, 100), true)
	await get_tree().process_frame
	assert_int(screen.page).is_equal(0)
	_motion(screen, Vector2(143, 102))
	_button(screen, Vector2(143, 102), false)
	await get_tree().process_frame
	assert_int(screen.page).is_equal(1)
	await get_tree().process_frame
	assert_int(screen.page).is_equal(1)
	_button(screen, Vector2(280, 180), true)
	_button(screen, Vector2(280, 180), false)
	await get_tree().process_frame
	assert_int(screen.page).is_equal(2)
	await _close(screen)


func test_drag_return_and_offscreen_release_cancel() -> void:
	var screen := await _open()
	for destination in [Vector2(170, 100), Vector2(-1, 100)]:
		_button(screen, Vector2(140, 100), true)
		_motion(screen, destination)
		_motion(screen, Vector2(140, 100))
		_button(screen, Vector2(140, 100), false)
		await get_tree().process_frame
		assert_int(screen.page).is_equal(0)
	_button(screen, Vector2(140, 100), true)
	_button(screen, Vector2(170, 100), false)
	await get_tree().process_frame
	assert_int(screen.page).is_equal(0)
	await _close(screen)


func test_phase_reset_unpaired_release_and_name_entry_do_not_advance() -> void:
	var screen := await _open()
	_button(screen, Vector2(140, 100), false)
	_button(screen, Vector2(140, 100), true)
	screen._reset_story_input()
	_button(screen, Vector2(140, 100), false)
	await get_tree().process_frame
	assert_int(screen.page).is_equal(0)
	screen.name_entry = true
	_button(screen, Vector2(140, 100), true)
	_button(screen, Vector2(140, 100), false)
	screen.name_entry = false
	await get_tree().process_frame
	assert_int(screen.page).is_equal(0)
	await _close(screen)


func test_desktop_mouse_and_android_keyboard_keep_press_behavior() -> void:
	var screen := await _open()
	screen._touch_name = false
	_button(screen, Vector2(140, 100), true)
	await get_tree().process_frame
	assert_int(screen.page).is_equal(1)
	screen._touch_name = true
	var key := InputEventKey.new()
	key.keycode = KEY_SPACE
	key.pressed = true
	screen._input(key)
	await get_tree().process_frame
	assert_int(screen.page).is_equal(2)
	await _close(screen)
