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


func _open_difficulty(mobile := true) -> Node:
	NG.flow = NG.Flow.NEW_GAME
	var screen: Node = Game.goto_scene(Game.SCENE_NEW_GAME)
	for _frame in 3000:
		if screen.idle and not screen.get("_busy"):
			break
		await get_tree().process_frame
	screen.set("_touch_difficulty", mobile)
	screen.mode = NG.MODE_FULL
	await screen._open_difficulty()
	return screen


func _button(screen: Node, p: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = p
	event.pressed = pressed
	screen.handle_mouse(event)


func test_release_starts_selected_difficulty() -> void:
	var screen := await _open_difficulty()
	_button(screen, Vector2(300, 106), true)
	assert_bool(screen.get("_busy")).is_false()
	assert_str(screen.current_screen).is_equal("difficulty")
	_button(screen, Vector2(300, 106), false)
	await get_tree().create_timer(0.6).timeout
	assert_int(Game.initial_difficulty).is_equal(3)
	assert_str(Effects.current_game_scene().scene_file_path).is_equal(Game.SCENE_SHOP)
	Game.campaign_active = false


func test_back_returns_to_episode_or_timed_choice() -> void:
	for mode in [NG.MODE_FULL, NG.MODE_TIMED]:
		var screen := await _open_difficulty()
		screen.mode = mode
		await screen._open_difficulty()
		_button(screen, Vector2(160, 190), true)
		_button(screen, Vector2(160, 190), false)
		await get_tree().create_timer(0.6).timeout
		assert_str(screen.current_screen).is_equal("timed" if mode == NG.MODE_TIMED else "episode")


func test_drag_off_cancels_start() -> void:
	var screen := await _open_difficulty()
	_button(screen, Vector2(300, 58), true)
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(0, 0)
	motion.relative = Vector2(-300, -58)
	screen.handle_mouse(motion)
	_button(screen, Vector2(300, 58), false)
	assert_bool(screen.get("_busy")).is_false()
	assert_str(screen.current_screen).is_equal("difficulty")


func test_mobile_always_shows_all_difficulties_and_back_targets() -> void:
	var screen := await _open_difficulty()
	assert_int(screen.difficulty_count).is_equal(6)
	assert_int(screen.menus.selection()).is_equal(1)
	assert_int(screen.menus.current().items.size()).is_equal(7)
	var menu: Dictionary = screen.menus.current()
	assert_int(screen.menus.row_at(menu, Vector2i(300, 187))).is_equal(5)
	assert_int(screen.menus.row_at(menu, Vector2i(300, 188))).is_equal(6)
	assert_int(screen.menus.row_at(menu, Vector2i(300, 200))).is_equal(-1)
	await screen._open_difficulty()
	assert_int(screen.difficulty_count).is_equal(6)


func test_mobile_hidden_difficulties_start_with_original_values() -> void:
	for row in [3, 4, 5]:
		var screen := await _open_difficulty()
		var p := Vector2(300, 58 + row * 24)
		_button(screen, p, true)
		assert_bool(screen.get("_busy")).is_false()
		_button(screen, p, false)
		await get_tree().create_timer(0.6).timeout
		assert_int(Game.initial_difficulty).is_equal(NG.DIFFICULTY_LEVELS[row])
		assert_str(Effects.current_game_scene().scene_file_path).is_equal(Game.SCENE_SHOP)
		Game.campaign_active = false


func test_desktop_retains_three_choices_and_original_hit_areas() -> void:
	var screen := await _open_difficulty(false)
	var menu: Dictionary = screen.menus.current()
	assert_int(menu.items.size()).is_equal(3)
	assert_int(screen.menus.selection()).is_equal(1)
	assert_int(screen.menus.row_at(menu, Vector2i(160, 58))).is_equal(0)
	assert_int(screen.menus.row_at(menu, Vector2i(300, 58))).is_equal(-1)
