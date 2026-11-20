extends GdUnitTestSuite


func before() -> void:
	EndlessSession.stop()
	Game.modes = PackedInt32Array()
	Game.campaign_active = false


func after_test() -> void:
	for child in Effects.game_viewport.get_children():
		child.queue_free()
		Effects.game_viewport.remove_child(child)
	Effects.overlay_screen = null
	await get_tree().process_frame
	await get_tree().process_frame


func after() -> void:
	Music.release_streams()
	Sfx.release_streams()


func _open(mobile := true) -> Node:
	Game.episode = 1
	Game.lvl_file_num = 9
	Game.start_cur_loc = 0
	Game.rng_seed = 1
	var level := Game.goto_scene(Game.SCENE_LEVEL)
	for _frame in 600:
		if level.sim != null and level.sim.tick() >= 3:
			break
		await get_tree().process_frame
	level.open_help()
	assert_object(level._help_screen).is_not_null()
	level._help_screen._touch_menus = mobile
	return level


func _button(help: Node, p: Vector2, down: bool, button := MOUSE_BUTTON_LEFT) -> void:
	var event := InputEventMouseButton.new()
	event.position = p
	event.button_index = button
	event.pressed = down
	help._unhandled_input(event)


func _motion(help: Node, p: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = p
	help._unhandled_input(event)


func test_release_advances_then_closes_and_simulation_stays_frozen() -> void:
	var level := await _open()
	var help: Node = level._help_screen
	var tick: int = level.sim.tick()
	var state: int = level.sim.state_hash()
	_button(help, Vector2(140, 100), true)
	await get_tree().create_timer(0.15).timeout
	assert_int(help._panel).is_equal(1)
	assert_int(level.sim.tick()).is_equal(tick)
	assert_int(level.sim.state_hash()).is_equal(state)
	_motion(help, Vector2(143, 102))
	_button(help, Vector2(143, 102), false)
	assert_int(help._panel).is_equal(2)
	_button(help, Vector2(143, 102), false)
	await get_tree().create_timer(0.15).timeout
	assert_object(level._help_screen).is_same(help)
	assert_int(level.sim.tick()).is_equal(tick)
	_button(help, Vector2(290, 190), true)
	assert_bool(help._closing).is_false()
	_button(help, Vector2(290, 190), false)
	await get_tree().create_timer(0.15).timeout
	assert_object(level._help_screen).is_null()
	assert_int(level.sim.tick()).is_greater(tick)


func test_drag_off_return_and_unpaired_release_cancel_on_both_panels() -> void:
	var level := await _open()
	var help: Node = level._help_screen
	for panel in [1, 2]:
		assert_int(help._panel).is_equal(panel)
		for point in [Vector2(170, 100), Vector2(-1, 100)]:
			_button(help, Vector2(140, 100), true)
			_motion(help, point)
			_motion(help, Vector2(140, 100))
			_button(help, Vector2(140, 100), false)
			assert_int(help._panel).is_equal(panel)
			assert_bool(help._closing).is_false()
		_button(help, Vector2(140, 100), true)
		_button(help, Vector2(180, 100), false)
		assert_bool(help._closing).is_false()
		_button(help, Vector2(140, 100), false)
		assert_bool(help._closing).is_false()
		if panel == 1:
			help.handle_action(&"")


func test_keyboard_panel_change_cancels_pending_touch() -> void:
	var level := await _open()
	var help: Node = level._help_screen
	_button(help, Vector2(140, 100), true)
	var key := InputEventKey.new()
	key.keycode = KEY_SPACE
	key.pressed = true
	help._unhandled_input(key)
	assert_int(help._panel).is_equal(2)
	_button(help, Vector2(140, 100), false)
	assert_bool(help._closing).is_false()
	var pad := InputEventJoypadButton.new()
	pad.pressed = true
	help._unhandled_input(pad)
	assert_bool(help._closing).is_true()


func test_desktop_mouse_still_advances_on_press() -> void:
	var level := await _open(false)
	var help: Node = level._help_screen
	_button(help, Vector2(140, 100), true)
	assert_int(help._panel).is_equal(2)
	_button(help, Vector2(140, 100), true, MOUSE_BUTTON_RIGHT)
	assert_bool(help._closing).is_true()
