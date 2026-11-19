extends GdUnitTestSuite

const SCENE := "res://scenes/achievements_screen.tscn"


func after_test() -> void:
	for child in Effects.game_viewport.get_children():
		child.queue_free()
		Effects.game_viewport.remove_child(child)
	await get_tree().process_frame
	TyrianMouse.buttons = 0
	TyrianMouse.inactive = true


func _open(mobile := true) -> Node:
	var screen: Node = Game.goto_scene(SCENE)
	screen.set("_touch_achievements", mobile)
	for _frame in 1000:
		await get_tree().process_frame
		if screen.idle:
			break
	assert_bool(screen.idle).is_true()
	return screen


func _button(screen: Node, p: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = p
	event.pressed = pressed
	event.button_index = MOUSE_BUTTON_LEFT
	screen.handle_mouse(event)


func _tap(screen: Node, p: Vector2) -> void:
	_button(screen, p, true)
	_button(screen, p, false)


func test_row_details_wait_for_release_and_drag_off_cancels() -> void:
	var screen := await _open()
	_button(screen, Vector2(80, 42), true)
	assert_int(screen.cursor).is_equal(0)
	_button(screen, Vector2(80, 42), false)
	assert_int(screen.cursor).is_equal(2)
	assert_int(screen.menus.current().items[screen.cursor].id).is_equal(screen._filtered[2])
	_button(screen, Vector2(80, 60), true)
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(319, 170)
	screen.handle_mouse(motion)
	_button(screen, Vector2(80, 60), false)
	assert_int(screen.cursor).is_equal(2)
	assert_bool(TyrianMouse.any_button_down()).is_false()


func test_all_categories_and_paging_boundaries() -> void:
	var screen := await _open()
	_button(screen, Vector2(306, 12), true)
	assert_int(screen.category).is_equal(0)
	_button(screen, Vector2(306, 12), false)
	assert_int(screen.category).is_equal(1)
	for category in range(2, 6):
		_tap(screen, Vector2(306, 12))
		assert_int(screen.category).is_equal(category)
		for id in screen._filtered:
			assert_int(screen.ACHIEVEMENTS[id][2]).is_equal(category)
	_tap(screen, Vector2(306, 12))
	assert_int(screen.category).is_equal(0)
	_tap(screen, Vector2(275, 12))
	assert_int(screen.category).is_equal(5)
	_tap(screen, Vector2(306, 12))
	assert_str(screen._touch_target(Vector2i(295, 32))).is_empty()
	_button(screen, Vector2(295, 138), true)
	assert_int(screen.cursor).is_equal(0)
	_button(screen, Vector2(295, 138), false)
	assert_int(screen.cursor).is_equal(14)
	assert_int(screen.menus.current().top).is_greater(0)
	var top: int = screen.menus.current().top
	_tap(screen, Vector2(80, 24))
	assert_int(screen.cursor).is_equal(top)
	for _page in 15:
		_tap(screen, Vector2(295, 138))
	assert_str(screen._touch_target(Vector2i(295, 138))).is_empty()
	for _page in 15:
		_tap(screen, Vector2(295, 32))
	assert_int(screen.menus.current().top).is_equal(0)
	_tap(screen, Vector2(80, 24))
	assert_int(screen.cursor).is_equal(0)


func test_back_release_and_desktop_inputs_preserved() -> void:
	var screen := await _open(false)
	_tap(screen, Vector2(80, 42))
	_tap(screen, Vector2(306, 12))
	_tap(screen, Vector2(280, 194))
	assert_int(screen.cursor).is_equal(0)
	assert_int(screen.category).is_equal(0)
	screen.handle_action(TyrianControls.DOWN)
	assert_int(screen.cursor).is_equal(1)
	screen.handle_action(TyrianControls.RIGHT)
	assert_int(screen.category).is_equal(1)
	screen.set("_touch_achievements", true)
	_button(screen, Vector2(280, 194), true)
	assert_str(Effects.current_game_scene().scene_file_path).is_equal(SCENE)
	_button(screen, Vector2(280, 194), false)
	await get_tree().process_frame
	assert_str(Effects.current_game_scene().scene_file_path).is_equal(Game.SCENE_TITLE)


func test_dragging_off_category_page_and_back_cancels() -> void:
	var screen := await _open()
	for p in [Vector2(275, 12), Vector2(306, 12), Vector2(295, 138), Vector2(280, 194)]:
		_button(screen, p, true)
		var motion := InputEventMouseMotion.new()
		motion.position = Vector2(319, 170)
		screen.handle_mouse(motion)
		motion.position = p
		screen.handle_mouse(motion)
		_button(screen, p, false)
		assert_int(screen.category).is_equal(0)
		assert_int(screen.cursor).is_equal(0)
		assert_str(Effects.current_game_scene().scene_file_path).is_equal(SCENE)
