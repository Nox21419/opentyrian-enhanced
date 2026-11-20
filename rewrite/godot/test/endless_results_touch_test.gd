extends GdUnitTestSuite


class Results:
	extends "res://scripts/endless_end.gd"

	func _run() -> void:
		pass


func after() -> void:
	Music.release_streams()
	Sfx.release_streams()


func _screen(stage: String, mobile := true) -> Node:
	var screen: Node = auto_free(Results.new())
	screen.set("_touch_results", mobile)
	get_tree().root.add_child(screen)
	screen.set("_results_screen", stage)
	screen.idle = true
	return screen


func _button(screen: Node, point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed

	if screen.get("_touch_results") and not str(screen.get("_results_screen")).is_empty():
		screen._unhandled_input(event)
	else:
		screen.handle_mouse(event)


func test_footer_choices_dispatch_original_actions_on_release() -> void:
	for pair in [[60, TyrianControls.RETRY], [160, TyrianControls.ACCEPT], [260, TyrianControls.BACK]]:
		var screen := _screen("board")
		_button(screen, Vector2(pair[0], 190), true)
		assert_str(screen.get("_key")).is_empty()
		_button(screen, Vector2(pair[0], 190), false)
		assert_str(screen.get("_key")).is_equal(pair[1])


func test_drag_off_return_and_cross_choice_cancel() -> void:
	for x in [60, 160, 260]:
		var screen := _screen("board")
		_button(screen, Vector2(x, 190), true)
		var motion := InputEventMouseMotion.new()
		motion.position = Vector2(0, 0)
		screen._unhandled_input(motion)
		_button(screen, Vector2(x, 190), false)
		assert_str(screen.get("_key")).is_empty()
		_button(screen, Vector2(x, 190), true)
		_button(screen, Vector2(260 if x != 260 else 60, 190), false)
		assert_str(screen.get("_key")).is_empty()


func test_body_and_transition_taps_do_nothing() -> void:
	var screen := _screen("board")
	_button(screen, Vector2(160, 100), true)
	_button(screen, Vector2(160, 100), false)
	assert_str(screen.get("_key")).is_empty()
	screen.idle = false
	_button(screen, Vector2(60, 190), true)
	screen.idle = true
	_button(screen, Vector2(60, 190), false)
	assert_str(screen.get("_key")).is_empty()
	assert_str(screen._results_target(Vector2i(104, 190))).is_empty()
	assert_str(screen._results_target(Vector2i(215, 190))).is_empty()


func test_summary_continue_advances_original_wait() -> void:
	var screen := _screen("")
	screen.idle = false
	screen._summary(123)
	for _frame in 3000:
		if screen.idle:
			break
		await get_tree().process_frame
	_button(screen, Vector2(300, 190), true)
	assert_bool(screen.idle).is_true()
	_button(screen, Vector2(300, 190), false)
	await get_tree().create_timer(0.5).timeout
	assert_str(screen.get("_results_screen")).is_empty()


func test_desktop_and_name_entry_keep_existing_clicks() -> void:
	for pair in [["board", false], ["", true]]:
		var screen := _screen(pair[0], pair[1])
		_button(screen, Vector2(0, 0), true)
		assert_str(screen.get("_key")).is_equal(TyrianControls.ACCEPT)
