extends GdUnitTestSuite

const SETUP := preload("res://scripts/setup.gd")
var _settings: Dictionary


func before() -> void:
	_settings = SETUP.settings.duplicate(true)


func after() -> void:
	SETUP.settings = _settings
	SETUP.apply_settings()
	SETUP.save_settings()
	preload("res://scripts/game_speed.gd").restore()
	Music.release_streams()
	Sfx.release_streams()


func before_test() -> void:
	EndlessSession.stop()
	Game.modes = PackedInt32Array()
	Game.campaign_active = false
	SETUP.reset_settings()
	SETUP.apply_settings()


func after_test() -> void:
	for child in Effects.game_viewport.get_children():
		child.queue_free()
		Effects.game_viewport.remove_child(child)
	await get_tree().process_frame
	TyrianMouse.buttons = 0
	TyrianMouse.inactive = true


func _level() -> Node:
	Game.episode = 1
	Game.lvl_file_num = 9
	var level: Node = Game.goto_scene(Game.SCENE_LEVEL)
	level.set("_touch_pause", true)
	level._build_touch_pause_label()
	for _frame in 60:
		await get_tree().physics_frame
	return level


func _touch(level: Node, index: int, p: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = p
	event.pressed = pressed
	level._input(event)


func _button(menu: Node, p: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = p
	event.global_position = p
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	menu.mouse_event(event)


func _tap(menu: Node, p: Vector2) -> void:
	_button(menu, p, true)
	_button(menu, p, false)


func _menu(level: Node) -> Node:
	_touch(level, 1, Vector2(20, 8), true)
	_touch(level, 1, Vector2(20, 8), false)
	assert_object(level._pause_menu).is_not_null()
	level._pause_menu.set("_touch_pause", true)
	return level._pause_menu


func test_top_left_label_release_freezes_and_return_resumes() -> void:
	var level := await _level()
	assert_bool(level._touch_pause_label.visible).is_true()
	_touch(level, 0, Vector2(100, 100), true)
	_touch(level, 1, Vector2(20, 8), true)
	assert_object(level._pause_menu).is_null()
	assert_bool(level._touch_flight.active()).is_true()
	_touch(level, 1, Vector2(20, 8), false)
	var menu: Node = level._pause_menu
	menu.set("_touch_pause", true)
	assert_bool(level._touch_flight.active()).is_false()
	assert_bool(level._touch_pause_label.visible).is_false()
	var tick: int = level.sim.tick()
	var state: int = level.sim.state_hash()
	for _frame in 5:
		await get_tree().physics_frame
	assert_int(level.sim.tick()).is_equal(tick)
	assert_int(level.sim.state_hash()).is_equal(state)
	_button(menu, Vector2(15, 101), true)
	assert_object(level._pause_menu).is_not_null()
	_button(menu, Vector2(15, 101), false)
	assert_object(level._pause_menu).is_null()
	assert_bool(level._touch_pause_label.visible).is_true()
	assert_bool(level._touch_flight.active()).is_false()


func test_label_drag_off_return_and_focus_loss_cancel() -> void:
	var level := await _level()
	_touch(level, 1, Vector2(20, 8), true)
	var motion := InputEventScreenDrag.new()
	motion.index = 1
	motion.position = Vector2(250, 120)
	level._input(motion)
	motion.position = Vector2(20, 8)
	level._input(motion)
	_touch(level, 1, Vector2(20, 8), false)
	assert_object(level._pause_menu).is_null()
	assert_bool(level._touch_flight.active()).is_false()
	_touch(level, 1, Vector2(20, 8), true)
	level._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	_touch(level, 1, Vector2(20, 8), false)
	assert_object(level._pause_menu).is_null()


func test_settings_wait_for_release_cancel_and_save_on_close() -> void:
	var level := await _level()
	var menu := _menu(level)
	var muted: bool = SETUP.settings.music_disabled
	_button(menu, Vector2(30, 21), true)
	assert_bool(SETUP.settings.music_disabled).is_equal(muted)
	_button(menu, Vector2(30, 21), false)
	assert_bool(SETUP.settings.music_disabled).is_equal(not muted)
	_button(menu, Vector2(30, 21), true)
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(160, 21)
	menu.mouse_event(motion)
	_button(menu, Vector2(30, 21), false)
	assert_bool(SETUP.settings.music_disabled).is_equal(not muted)
	_tap(menu, Vector2(160, 21))
	assert_int(int(SETUP.settings.music_volume)).is_between(100, 150)
	var fx: bool = SETUP.settings.samples_disabled
	_tap(menu, Vector2(30, 41))
	assert_bool(SETUP.settings.samples_disabled).is_equal(not fx)
	var vfx := int(SETUP.settings.visual_fx)
	_tap(menu, Vector2(30, 61))
	assert_int(int(SETUP.settings.visual_fx)).is_equal((vfx + 1) % 3)
	var speed := int(SETUP.settings.game_speed)
	_tap(menu, Vector2(30, 81))
	assert_int(int(SETUP.settings.game_speed)).is_equal(speed + 1 if speed < 5 else 1)
	_tap(menu, Vector2(30, 101))
	var cfg := ConfigFile.new()
	assert_int(cfg.load(SETUP.SETTINGS_PATH)).is_equal(OK)
	assert_bool(bool(cfg.get_value("setup", "music_disabled"))).is_equal(not muted)


func test_quit_confirmation_requires_release_and_no_resumes() -> void:
	var level := await _level()
	var menu := _menu(level)
	_button(menu, Vector2(30, 121), true)
	assert_bool(menu.modal_active).is_false()
	_button(menu, Vector2(30, 121), false)
	await get_tree().process_frame
	assert_bool(menu.modal_active).is_true()
	_button(menu, Vector2(90, 135), true)
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(200, 135)
	menu.mouse_event(motion)
	_button(menu, Vector2(90, 135), false)
	assert_object(level._pause_menu).is_not_null()
	_button(menu, Vector2(200, 135), true)
	assert_object(level._pause_menu).is_not_null()
	_button(menu, Vector2(200, 135), false)
	for _frame in 10:
		await get_tree().process_frame
	assert_object(level._pause_menu).is_null()


func test_quit_yes_returns_to_title() -> void:
	var level := await _level()
	var menu := _menu(level)
	_tap(menu, Vector2(30, 121))
	await get_tree().process_frame
	_tap(menu, Vector2(90, 135))
	for _frame in 120:
		await get_tree().process_frame
		if Effects.current_game_scene().scene_file_path == Game.SCENE_TITLE:
			break
	assert_str(Effects.current_game_scene().scene_file_path).is_equal(Game.SCENE_TITLE)


func test_pause_icon_fits_target_and_desktop_has_no_label() -> void:
	assert_int(TyrianText.measure("II", TyrianText.FontKind.NORMAL) + 2).is_less_equal(56)
	Game.episode = 1
	Game.lvl_file_num = 9
	var level: Node = Game.goto_scene(Game.SCENE_LEVEL)
	assert_bool(level._touch_pause).is_false()
	assert_object(level._touch_pause_label).is_null()
