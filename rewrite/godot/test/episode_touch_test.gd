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


func _open_episode(mobile := true) -> Node:
	NG.flow = NG.Flow.NEW_GAME
	var screen: Node = Game.goto_scene(Game.SCENE_NEW_GAME)
	for _frame in 3000:
		if screen.idle and not screen.get("_busy"):
			break
		await get_tree().process_frame
	screen.set("_touch_episode", mobile)
	await screen._open_episode()
	return screen


func _button(screen: Node, p: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = p
	event.pressed = pressed
	screen.handle_mouse(event)


func test_wide_target_selects_episode_on_release() -> void:
	var screen := await _open_episode()
	_button(screen, Vector2(300, 84), true)
	assert_str(screen.current_screen).is_equal("episode")
	assert_bool(screen.get("_busy")).is_false()
	_button(screen, Vector2(300, 84), false)
	await get_tree().create_timer(0.5).timeout
	assert_str(screen.current_screen).is_equal("difficulty")
	assert_int(screen.episode).is_equal(2)
	assert_int(screen.menus.current().items.size()).is_equal(3)
	assert_int(screen.menus.row_at(screen.menus.current(), Vector2i(300, 58))).is_equal(-1)


func test_drag_to_another_row_cancels() -> void:
	var screen := await _open_episode()
	_button(screen, Vector2(300, 54), true)
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(300, 84)
	motion.relative = Vector2(0, 30)
	screen.handle_mouse(motion)
	_button(screen, Vector2(300, 84), false)
	assert_str(screen.current_screen).is_equal("episode")
	assert_bool(screen.get("_busy")).is_false()


func test_back_returns_to_title() -> void:
	var screen := await _open_episode()
	_button(screen, Vector2(160, 190), true)
	_button(screen, Vector2(160, 190), false)
	await get_tree().create_timer(0.6).timeout
	assert_str(Effects.current_game_scene().scene_file_path).is_equal(Game.SCENE_TITLE)


func test_final_episode_and_back_have_separate_targets() -> void:
	var screen := await _open_episode()
	var menu: Dictionary = screen.menus.current()
	assert_int(menu.items.size()).is_equal(6)
	assert_int(screen.menus.row_at(menu, Vector2i(300, 183))).is_equal(4)
	assert_int(screen.menus.row_at(menu, Vector2i(300, 184))).is_equal(5)
	assert_int(screen.menus.row_at(menu, Vector2i(300, 199))).is_equal(5)
	assert_int(screen.menus.row_at(menu, Vector2i(300, 200))).is_equal(-1)


func test_desktop_keeps_five_choices_and_text_targets() -> void:
	var screen := await _open_episode(false)
	var menu: Dictionary = screen.menus.current()
	assert_int(menu.items.size()).is_equal(5)
	assert_int(screen.menus.row_at(menu, Vector2i(22, 54))).is_equal(0)
	assert_int(screen.menus.row_at(menu, Vector2i(4, 54))).is_equal(-1)
	assert_int(screen.menus.row_at(menu, Vector2i(160, 64))).is_equal(-1)
