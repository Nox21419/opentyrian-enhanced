extends GdUnitTestSuite


class Prompt:
	extends "res://scripts/endless_prompt.gd"

	func _run() -> void:
		pass


func after() -> void:
	Music.release_streams()
	Sfx.release_streams()


func _open(mobile := true) -> Node:
	var screen := Prompt.new()
	screen._touch_resume = mobile
	get_tree().root.add_child(screen)
	screen.pick(PackedInt32Array([0, 1, 2]))
	for _frame in 3000:
		if screen.idle:
			break
		await get_tree().process_frame
	assert_bool(screen.idle).is_true()
	return screen


func _close(screen: Node) -> void:
	screen.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame


func _button(screen: Node, point: Vector2, down: bool, button := MOUSE_BUTTON_LEFT) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = button
	event.pressed = down
	screen.handle_mouse(event)


func test_each_card_highlights_on_press_and_confirms_only_on_release() -> void:
	for index in 3:
		var screen := await _open()
		var point := Vector2(58 + index * 102, 100)
		_button(screen, point, true)
		await get_tree().process_frame
		await get_tree().process_frame
		assert_int(screen._pick_cursor).is_equal(index)
		assert_that(screen.result).is_null()
		_button(screen, point, false)
		await get_tree().process_frame
		assert_that(screen.result).is_equal(index)
		await _close(screen)


func test_drag_out_cross_card_gap_and_return_cancel() -> void:
	var screen := await _open()
	for destination in [Vector2.ZERO, Vector2(109, 100), Vector2(160, 100)]:
		_button(screen, Vector2(58, 100), true)
		var motion := InputEventMouseMotion.new()
		motion.position = destination
		screen.handle_mouse(motion)
		motion.position = Vector2(58, 100)
		screen.handle_mouse(motion)
		_button(screen, Vector2(58, 100), false)
		await get_tree().process_frame
		assert_that(screen.result).is_null()
	_button(screen, Vector2(58, 100), false)
	_button(screen, Vector2(160, 180), true)
	_button(screen, Vector2(160, 180), false)
	_button(screen, Vector2(58, 100), true, MOUSE_BUTTON_RIGHT)
	await get_tree().process_frame
	assert_that(screen.result).is_null()
	await _close(screen)


func test_fade_and_keyboard_navigation_cancel_pending_touch() -> void:
	var screen := await _open()
	screen.idle = false
	_button(screen, Vector2(58, 100), true)
	screen.idle = true
	_button(screen, Vector2(58, 100), false)
	await get_tree().process_frame
	assert_that(screen.result).is_null()
	_button(screen, Vector2(58, 100), true)
	screen._unhandled_input(TyrianControls.key_event(KEY_RIGHT))
	await get_tree().process_frame
	_button(screen, Vector2(58, 100), false)
	await get_tree().process_frame
	assert_that(screen.result).is_null()
	assert_int(screen._pick_cursor).is_equal(1)
	screen._unhandled_input(TyrianControls.key_event(KEY_ESCAPE))
	await get_tree().process_frame
	assert_that(screen.result).is_null()
	screen._unhandled_input(TyrianControls.key_event(KEY_ENTER))
	await get_tree().process_frame
	assert_that(screen.result).is_equal(1)
	await _close(screen)


func test_desktop_keeps_press_activation() -> void:
	var screen := await _open(false)
	_button(screen, Vector2(262, 100), true)
	await get_tree().process_frame
	assert_that(screen.result).is_equal(2)
	await _close(screen)
