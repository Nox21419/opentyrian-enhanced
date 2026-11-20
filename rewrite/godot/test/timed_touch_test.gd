extends GdUnitTestSuite

const NG := preload("res://scripts/new_game.gd")


func after() -> void:
	Music.release_streams()
	Sfx.release_streams()


func after_test() -> void:
	for child in Effects.game_viewport.get_children():
		child.queue_free()
		Effects.game_viewport.remove_child(child)
	await get_tree().process_frame
	await get_tree().process_frame
	TyrianMouse.inactive = true


func _open_timed(mobile := true) -> Node:
	NG.flow = NG.Flow.NEW_GAME
	var screen: Node = Game.goto_scene(Game.SCENE_NEW_GAME)
	for _frame in 3000:
		if screen.idle and not screen.get("_busy"):
			break
		await get_tree().process_frame
	screen.set("_touch_timed", mobile)
	screen.mode = NG.MODE_TIMED
	await screen._open_timed()
	return screen


func _button(screen: Node, p: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = p
	event.pressed = pressed
	screen.handle_mouse(event)


func test_each_battle_activates_only_on_release() -> void:
	for row in 3:
		var screen := await _open_timed()
		var point := Vector2(300, 54 + row * 24)
		_button(screen, point, true)
		assert_str(screen.current_screen).is_equal("timed")
		assert_bool(screen.get("_busy")).is_false()
		_button(screen, point, false)
		await get_tree().create_timer(0.6).timeout
		assert_str(screen.current_screen).is_equal("difficulty")
		assert_int(screen.time_battle).is_equal(row + 1)
		assert_int(screen.episode).is_equal(1 if row == 0 else 5)


func test_drag_off_and_return_cancels() -> void:
	var screen := await _open_timed()
	for point in [Vector2(300, 54), Vector2(160, 190)]:
		_button(screen, point, true)
		var motion := InputEventMouseMotion.new()
		motion.position = Vector2(0, 0)
		screen.handle_mouse(motion)
		motion.position = point
		screen.handle_mouse(motion)
		_button(screen, point, false)
		assert_bool(screen.get("_busy")).is_false()
		assert_str(screen.current_screen).is_equal("timed")


func test_back_returns_to_title() -> void:
	var screen := await _open_timed()
	_button(screen, Vector2(300, 190), true)
	assert_bool(screen.get("_busy")).is_false()
	_button(screen, Vector2(300, 190), false)
	await get_tree().create_timer(0.7).timeout
	assert_str(Effects.current_game_scene().scene_file_path).is_equal(Game.SCENE_TITLE)


func test_touch_boundaries_and_keyboard() -> void:
	var screen := await _open_timed()
	var menu: Dictionary = screen.menus.current()
	for pair in [
		[Vector2i(16, 52), 0],
		[Vector2i(303, 75), 0],
		[Vector2i(300, 76), 1],
		[Vector2i(300, 100), 2],
		[Vector2i(300, 124), -1],
		[Vector2i(300, 183), -1],
		[Vector2i(300, 184), 3],
		[Vector2i(304, 190), -1]
	]:
		assert_int(screen.menus.row_at(menu, pair[0])).is_equal(pair[1])
	screen.handle_action(TyrianControls.UP)
	assert_int(screen.menus.selection()).is_equal(3)


func test_desktop_keeps_original_targets_and_keyboard() -> void:
	var screen := await _open_timed(false)
	var menu: Dictionary = screen.menus.current()
	assert_int(menu.items.size()).is_equal(3)
	assert_int(screen.menus.row_at(menu, Vector2i(300, 54))).is_equal(-1)
	assert_int(screen.menus.row_at(menu, Vector2i(160, 54))).is_equal(0)
	assert_int(screen.menus.row_at(menu, Vector2i(160, 190))).is_equal(-1)
	screen.handle_action(TyrianControls.DOWN)
	screen.handle_action(TyrianControls.ACCEPT)
	await get_tree().create_timer(0.6).timeout
	assert_str(screen.current_screen).is_equal("difficulty")
	assert_int(screen.time_battle).is_equal(2)
	assert_int(screen.episode).is_equal(5)
