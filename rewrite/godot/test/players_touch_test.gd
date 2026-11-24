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


func _open_players(mobile := true) -> Node:
	NG.flow = NG.Flow.NEW_GAME
	var screen: Node = Game.goto_scene(Game.SCENE_NEW_GAME)
	for _frame in 3000:
		if screen.idle and not screen.get("_busy"):
			break
		await get_tree().process_frame
	screen.set("_touch_players", mobile)
	# Isolate Players behavior; Episode adaptation has its own suite.
	screen.set("_touch_episode", false)
	await screen._open_gameplay()
	return screen


func _button(screen: Node, row: int, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = Vector2(22, 50 + row * 18)
	event.pressed = pressed
	screen.handle_mouse(event)


func test_wide_touch_target_activates_only_on_release() -> void:
	var screen := await _open_players()
	_button(screen, NG.MODE_FULL, true)
	assert_str(screen.current_screen).is_equal("gameplay")
	assert_bool(screen.get("_busy")).is_false()
	_button(screen, NG.MODE_FULL, false)
	await get_tree().create_timer(0.5).timeout
	assert_str(screen.current_screen).is_equal("episode")
	# Episode retains the original text-width targets and five choices.
	assert_int(screen.menus.current().items.size()).is_equal(5)
	assert_int(screen.menus.row_at(screen.menus.current(), Vector2i(160, 64))).is_equal(-1)


func test_drag_off_cancels_choice() -> void:
	var screen := await _open_players()
	_button(screen, NG.MODE_FULL, true)
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(0, 0)
	motion.relative = Vector2(-22, -50)
	screen.handle_mouse(motion)
	_button(screen, NG.MODE_FULL, false)
	assert_str(screen.current_screen).is_equal("gameplay")
	assert_bool(screen.get("_busy")).is_false()


func test_mobile_local_two_player_choices_cannot_start() -> void:
	var screen := await _open_players()
	for row in [NG.MODE_2P_ARCADE, NG.MODE_2P_ENDLESS]:
		assert_bool(screen._gameplay_disabled(row)).is_true()
		_button(screen, row, true)
		_button(screen, row, false)
		assert_str(screen.current_screen).is_equal("gameplay")
		assert_bool(screen.get("_busy")).is_false()
		# A keyboard/controller confirm must obey the same restriction.
		screen.menus.current().sel = row
		screen.handle_action(TyrianControls.ACCEPT)
		assert_str(screen.current_screen).is_equal("gameplay")
		assert_bool(screen.get("_busy")).is_false()


func test_back_entry_returns_to_title() -> void:
	var screen := await _open_players()
	assert_int(screen.menus.current().items.size()).is_equal(8)
	_button(screen, 7, true)
	_button(screen, 7, false)
	await get_tree().create_timer(0.6).timeout
	assert_str(Effects.current_game_scene().scene_file_path).is_equal(Game.SCENE_TITLE)


func test_desktop_keeps_two_player_and_original_targets() -> void:
	var screen := await _open_players(false)
	assert_int(screen.menus.current().items.size()).is_equal(7)
	assert_bool(screen._gameplay_disabled(NG.MODE_2P_ARCADE)).is_false()
	assert_bool(screen._gameplay_disabled(NG.MODE_2P_ENDLESS)).is_false()
	assert_int(screen.menus.row_at(screen.menus.current(), Vector2i(22, 55))).is_equal(-1)
	screen.menus.current().sel = NG.MODE_2P_ARCADE
	screen.handle_action(TyrianControls.ACCEPT)
	await get_tree().create_timer(0.5).timeout
	assert_str(screen.current_screen).is_equal("episode")
	assert_int(screen.mode).is_equal(NG.MODE_2P_ARCADE)
