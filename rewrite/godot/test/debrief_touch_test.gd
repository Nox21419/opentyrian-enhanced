extends GdUnitTestSuite


func after() -> void:
	Music.release_streams()
	Sfx.release_streams()


func before_test() -> void:
	EndlessSession.stop()
	Game.modes = PackedInt32Array()
	Game.episode = 1
	Game.campaign_active = true
	Game.level_name = "TYRIAN"
	Game.next_level = 4
	Game.main_level = 3
	Game.debrief = {
		"level_name": "TYRIAN",
		"cash": 12371,
		"enemy_killed": 108,
		"total_enemy": 374,
		"cube_max": 0,
		"all_players_alive": true,
		"damage_by_bay": PackedInt32Array([626, 0, 111, 125, 0]),
		"damage_taken": 222,
		"damage_blocked": 202,
		"credits_start": 10000
	}


func after_test() -> void:
	Game.campaign_active = false
	Game.debrief = {}
	for child in Effects.game_viewport.get_children():
		child.queue_free()
		Effects.game_viewport.remove_child(child)
	await get_tree().process_frame
	TyrianMouse.buttons = 0
	TyrianMouse.inactive = true


func _wait(condition: Callable) -> bool:
	var deadline := Time.get_ticks_msec() + 20000
	while not condition.call() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	return condition.call()


func _open(mobile := true) -> Node:
	var screen: Node = Game.goto_scene(Game.SCENE_DEBRIEF)
	screen.set("_touch_stats", mobile)
	assert_bool(await _wait(func(): return screen.idle)).is_true()
	screen._input_seen = true
	assert_bool(await _wait(func(): return screen.stats_shown)).is_true()
	return screen


func _button(screen: Node, p: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = p
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	screen.handle_mouse(event)


func test_footer_release_continues_campaign_and_drag_off_cancels() -> void:
	var screen := await _open()
	assert_array(screen._stats_lines).contains([["ls_credits", "+2371"]])
	_button(screen, Vector2(100, 100), true)
	_button(screen, Vector2(100, 100), false)
	assert_str(screen._stats_action).is_empty()
	_button(screen, Vector2(160, 185), false)
	assert_str(screen._stats_action).is_empty()
	_button(screen, Vector2(160, 185), true)
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(160, 175)
	screen.handle_mouse(motion)
	motion.position = Vector2(160, 185)
	screen.handle_mouse(motion)
	_button(screen, Vector2(160, 185), false)
	assert_str(screen._stats_action).is_empty()
	_button(screen, Vector2(20, 185), true)
	assert_str(screen._stats_action).is_empty()
	_button(screen, Vector2(20, 185), false)
	assert_str(screen._stats_action).is_equal(TyrianControls.ACCEPT)
	assert_bool(TyrianMouse.any_button_down()).is_false()
	assert_bool(await _wait(_at_next_shop)).is_true()


func test_desktop_ignores_footer_click_and_retains_keyboard_exit() -> void:
	var screen := await _open(false)
	_button(screen, Vector2(160, 185), true)
	_button(screen, Vector2(160, 185), false)
	assert_str(screen._stats_action).is_empty()
	screen.handle_action(TyrianControls.ACCEPT)
	assert_bool(await _wait(_at_next_shop)).is_true()


func test_continue_label_fits_all_languages() -> void:
	for language in ["en", "de", "es", "fr", "it", "pt"]:
		var label := TyrianText.L("ls_continue", language)
		assert_str(label).is_not_equal("ls_continue")
		assert_int(TyrianText.width(label, TyrianScreen.SMALL_FONT)).is_less_equal(288)


func _at_next_shop() -> bool:
	return Effects.current_game_scene().scene_file_path == Game.SCENE_SHOP and Game.shop_section == 4
