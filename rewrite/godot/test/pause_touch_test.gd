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
	_button(menu, Vector2(15, 121), true)
	assert_object(level._pause_menu).is_not_null()
	_button(menu, Vector2(15, 121), false)
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
	_tap(menu, Vector2(30, 121))
	var cfg := ConfigFile.new()
	assert_int(cfg.load(SETUP.SETTINGS_PATH)).is_equal(OK)
	assert_bool(bool(cfg.get_value("setup", "music_disabled"))).is_equal(not muted)


func test_quit_confirmation_requires_release_and_no_resumes() -> void:
	var level := await _level()
	var menu := _menu(level)
	_button(menu, Vector2(30, 141), true)
	assert_bool(menu.modal_active).is_false()
	_button(menu, Vector2(30, 141), false)
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
	_tap(menu, Vector2(30, 141))
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


func test_help_release_and_cancel_return_to_same_frozen_pause_menu() -> void:
	var level := await _level()
	var menu := _menu(level)
	assert_int(menu.menus.current().items.size()).is_equal(9)
	assert_str(menu.menus.current().items[4].label).is_equal("ig_help")
	var background: PackedByteArray = menu.vga.indices(menu.VGA_SCREEN2)
	var tick: int = level.sim.tick()
	var state: int = level.sim.state_hash()
	_button(menu, Vector2(30, 101), true)
	assert_object(level._help_screen).is_null()
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(280, 170)
	menu.mouse_event(motion)
	_button(menu, Vector2(30, 101), false)
	assert_object(level._help_screen).is_null()
	_tap(menu, Vector2(30, 101))
	var help: Node = level._help_screen
	assert_object(help).is_not_null()
	assert_bool(menu.visible).is_false()
	assert_bool(menu.is_processing_unhandled_input()).is_false()
	help._touch_menus = true
	for _frame in 5:
		await get_tree().physics_frame
	assert_int(level.sim.tick()).is_equal(tick)
	assert_int(level.sim.state_hash()).is_equal(state)
	for _panel in 2:
		var event := InputEventMouseButton.new()
		event.position = Vector2(140, 100)
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = true
		help._unhandled_input(event)
		event.pressed = false
		help._unhandled_input(event)
	assert_object(level._help_screen).is_null()
	assert_object(level._pause_menu).is_same(menu)
	assert_bool(menu.visible).is_true()
	assert_that(menu.vga.indices(menu.VGA_SCREEN2)).is_equal(background)
	assert_bool(menu.is_processing_unhandled_input()).is_true()
	assert_int(menu.menus.current().sel).is_equal(4)
	for _frame in 5:
		await get_tree().physics_frame
	assert_int(level.sim.tick()).is_equal(tick)
	assert_int(level.sim.state_hash()).is_equal(state)
	_tap(menu, Vector2(30, 121))
	for _frame in 5:
		await get_tree().physics_frame
	assert_int(level.sim.tick()).is_greater(tick)


func test_desktop_pause_has_original_six_rows() -> void:
	var level := await _level()
	level._touch_pause = false
	level.open_pause_menu()
	var items: Array = level._pause_menu.menus.current().items
	assert_int(items.size()).is_equal(6)
	assert_str(items[4].label).is_equal("ig_return")
	assert_str(items[5].label).is_equal("ig_quit")


func test_more_views_navigate_cancel_and_keep_simulation_frozen() -> void:
	var level := await _level()
	var menu := _menu(level)
	menu.vga.image(0).save_png("res://../../build/android-pause.png")
	var tick: int = level.sim.tick()
	var state: int = level.sim.state_hash()
	_button(menu, Vector2(30, 161), true)
	assert_int(menu.menus.stack.size()).is_equal(1)
	_button(menu, Vector2(30, 161), false)
	assert_int(menu.menus.stack.size()).is_equal(2)
	menu.vga.image(0).save_png("res://../../build/android-pause-more.png")
	_tap(menu, Vector2(30, 21))
	assert_str(menu.actions.viewer).is_equal("achievements")
	menu.vga.image(0).save_png("res://../../build/android-pause-achievements.png")
	var image: PackedByteArray = menu.vga.indices(0)
	_tap(menu, Vector2(275, 190))
	assert_int(menu.actions.tables.category).is_equal(1)
	assert_that(menu.vga.indices(0)).is_not_equal(image)
	_tap(menu, Vector2(20, 190))
	assert_int(menu.actions.tables.category).is_equal(0)
	_tap(menu, Vector2(220, 190))
	assert_int(menu.actions.tables.cursor).is_equal(1)
	_button(menu, Vector2(220, 190), true)
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(150, 100)
	menu.mouse_event(motion)
	motion.position = Vector2(220, 190)
	menu.mouse_event(motion)
	_button(menu, Vector2(220, 190), false)
	assert_int(menu.actions.tables.cursor).is_equal(1)
	_tap(menu, Vector2(65, 190))
	assert_int(menu.actions.tables.cursor).is_equal(0)
	_tap(menu, Vector2(130, 190))
	assert_str(menu.actions.viewer).is_empty()
	_tap(menu, Vector2(30, 41))
	assert_str(menu.actions.viewer).is_equal("stats")
	menu.vga.image(0).save_png("res://../../build/android-pause-statistics.png")
	for _frame in 5:
		await get_tree().physics_frame
	assert_int(level.sim.tick()).is_equal(tick)
	assert_int(level.sim.state_hash()).is_equal(state)
	_tap(menu, Vector2(130, 190))
	_tap(menu, Vector2(30, 141))
	assert_int(menu.menus.stack.size()).is_equal(1)
	assert_int(menu.menus.current().sel).is_equal(7)


func test_secondary_actions_change_real_state_and_replay_arm() -> void:
	var level := await _level()
	var menu := _menu(level)
	_tap(menu, Vector2(30, 161))
	ReplayRecording.armed = false
	_tap(menu, Vector2(30, 101))
	assert_bool(ReplayRecording.armed).is_true()
	assert_str(menu.actions.status).is_equal(TyrianText.L("msg_replay_armed"))
	_tap(menu, Vector2(30, 101))
	assert_bool(ReplayRecording.armed).is_false()
	_tap(menu, Vector2(30, 121))
	var dps: bool = level.hotkeys.overlays.dps_active
	menu.vga.image(0).save_png("res://../../build/android-pause-secondary.png")
	_tap(menu, Vector2(30, 21))
	assert_bool(level.hotkeys.overlays.dps_active).is_equal(not dps)
	var damage: bool = SETUP.settings.damage_numbers_enabled
	_tap(menu, Vector2(30, 41))
	assert_bool(SETUP.settings.damage_numbers_enabled).is_equal(not damage)
	var gamma: int = DisplaySettings.gamma()
	_tap(menu, Vector2(30, 61))
	assert_int(DisplaySettings.gamma()).is_equal((gamma + 1) % 4)
	var screenshots: int = level.sim.ach_counter("screenshots_taken")
	_tap(menu, Vector2(30, 81))
	if DisplayServer.get_name() == "headless":
		assert_str(menu.actions.status).is_equal(TyrianText.L("msg_screenshot_fail"))
	else:
		assert_int(level.sim.ach_counter("screenshots_taken")).is_equal(screenshots + 1)
		var path := UserData.path("screenshot_%04d.bmp" % (LevelHotkeys._screenshot_next - 1))
		assert_bool(FileAccess.file_exists(path)).is_true()
	_tap(menu, Vector2(30, 101))
	_tap(menu, Vector2(30, 141))
	_tap(menu, Vector2(30, 121))
	var cfg := ConfigFile.new()
	assert_int(cfg.load(SETUP.SETTINGS_PATH)).is_equal(OK)
	assert_bool(bool(cfg.get_value("setup", "damage_numbers_enabled"))).is_equal(not damage)


func test_paused_quick_save_and_touch_load_no_then_yes() -> void:
	var level := await _level()
	Game.campaign_active = true
	Game.last_level_section = 1
	var menu := _menu(level)
	var tick: int = level.sim.tick()
	_tap(menu, Vector2(30, 161))
	_tap(menu, Vector2(30, 61))
	var slot = Game.campaign_slots()[LevelHotkeys.QUICK_SLOT_ONE_PLAYER - 1]
	assert_object(slot).is_not_null()
	assert_str(str(slot.get("name", ""))).is_equal(TyrianText.L("save_quick_save"))
	assert_bool(FileAccess.file_exists(UserData.path("saves/slot_11.json"))).is_true()
	_tap(menu, Vector2(30, 81))
	for _frame in 5:
		await get_tree().process_frame
	assert_bool(menu.modal_active).is_true()
	_button(menu, Vector2(190, 135), true)
	assert_bool(menu.modal_active).is_true()
	_button(menu, Vector2(190, 135), false)
	for _frame in 15:
		await get_tree().process_frame
	assert_bool(menu.modal_active).is_false()
	assert_object(level._pause_menu).is_same(menu)
	assert_int(level.sim.tick()).is_equal(tick)
	_tap(menu, Vector2(30, 81))
	for _frame in 5:
		await get_tree().process_frame
	assert_bool(menu.modal_active).is_true()
	_tap(menu, Vector2(95, 135))
	for _frame in 30:
		await get_tree().process_frame
	assert_bool(is_instance_valid(level)).is_false()


func test_quick_actions_outside_campaign_report_restriction() -> void:
	var level := await _level()
	var menu := _menu(level)
	_tap(menu, Vector2(30, 161))
	_tap(menu, Vector2(30, 61))
	assert_str(menu.actions.status).is_equal(TyrianText.L("msg_quick_campaign_only"))

	_tap(menu, Vector2(30, 81))
	for _frame in 5:
		await get_tree().process_frame
	assert_bool(menu.modal_active).is_false()
	assert_str(menu.actions.status).is_equal(TyrianText.L("msg_quick_campaign_only"))


func test_paused_replay_stop_writes_playable_recording() -> void:
	ReplayRecording.armed = true
	Game.loadout = PackedInt32Array(Game.NEW_GAME_LOADOUT)
	Game.start_cur_loc = 0
	var level := await _level()
	assert_bool(level.sim.is_recording()).is_true()
	var menu := _menu(level)
	var tick: int = level.sim.tick()
	_tap(menu, Vector2(30, 161))
	_tap(menu, Vector2(30, 101))
	assert_bool(level.sim.is_recording()).is_false()
	assert_str(level.last_recording_path).is_not_empty()
	assert_bool(FileAccess.file_exists(level.last_recording_path)).is_true()
	assert_str(menu.actions.status).is_equal(TyrianText.L("ig_replay_saved"))
	var playback: Node = ClassDB.instantiate("TyrianSim")
	add_child(playback)
	assert_bool(playback.load_replay(Game.data_dir, level.last_recording_path)).is_true()
	playback.queue_free()
	assert_int(level.sim.tick()).is_equal(tick)
	ReplayRecording.armed = false


func test_tilt_reset_uses_release_cancels_drag_and_keeps_simulation_frozen() -> void:
	SETUP.settings.tilt_controls_enabled = true
	Input.set_gravity(Vector3(0, 0, -9.8))
	var level := await _level()
	assert_bool(level.reset_tilt_neutral()).is_true()
	var menu := _menu(level)
	assert_int(menu.menus.current().items.size()).is_equal(9)
	assert_int(MenuEngine.tree_geometry(menu.menus.current()).max_vis).is_greater_equal(9)
	assert_int(menu.menus.hittest_row(20, 181)).is_equal(8)
	assert_str(menu.menus.current().items[8].label).is_equal("mobile_controls")
	_tap(menu, Vector2(20, 181))
	assert_str(menu.menus.current().items[2].label).is_equal("tilt_reset")
	var tick: int = level.sim.tick()
	var state: int = level.sim.state_hash()
	Input.set_gravity(Vector3(3, -2, -9))
	_button(menu, Vector2(20, 61), true)
	assert_vector(level._tilt_flight.neutral).is_equal(Vector3(0, 0, -1))
	var drag := InputEventMouseMotion.new()
	drag.position = Vector2(300, 190)
	menu.mouse_event(drag)
	_button(menu, Vector2(20, 61), false)
	assert_vector(level._tilt_flight.neutral).is_equal(Vector3(0, 0, -1))
	_tap(menu, Vector2(20, 61))
	assert_vector(level._tilt_flight.neutral).is_equal(Vector3(3, -2, -9).normalized())
	assert_object(level._pause_menu).is_not_null()
	for frame in 5:
		await get_tree().physics_frame
	assert_int(level.sim.tick()).is_equal(tick)
	assert_int(level.sim.state_hash()).is_equal(state)
	assert_bool(level._touch_flight.active()).is_false()
	Input.set_gravity(Vector3.ZERO)


func test_tilt_level_start_movement_without_finger_and_desktop_replay_scope() -> void:
	SETUP.settings.tilt_controls_enabled = true
	Input.set_gravity(Vector3(0, 0, -9.8))
	Game.episode = 1
	Game.lvl_file_num = 9
	Game.start_cur_loc = 0
	Game.loadout = PackedInt32Array(Game.NEW_GAME_LOADOUT)
	for child in Effects.game_viewport.get_children():
		child.queue_free()
		Effects.game_viewport.remove_child(child)
	var level: Node = Effects.instantiate_scene(Game.SCENE_LEVEL)
	level._touch_pause = true
	Effects.game_viewport.add_child(level)
	assert_bool(level._tilt_flight.calibrated).is_true()
	assert_vector(level._tilt_flight.neutral).is_equal(Vector3(0, 0, -1))
	for frame in 60:
		await get_tree().physics_frame
	var before: PackedInt32Array = level.sim.player(0)
	Input.set_gravity(Vector3(4, 0, -9))
	for frame in 5:
		await get_tree().physics_frame
	var after: PackedInt32Array = level.sim.player(0)
	assert_int(after[0]).is_greater(before[0])
	assert_bool(level._touch_flight.active()).is_false()
	assert_int(level._touch_flight.fire_mask()).is_equal(0)
	assert_int(level._trace_mouse.x).is_greater(0)
	assert_bool(level.reset_tilt_neutral()).is_true()
	_touch(level, 0, Vector2(40, 50), true)
	for frame in 5:
		await get_tree().physics_frame
	assert_vector(level._trace_mouse).is_equal(Vector2i.ZERO)
	assert_int(level._touch_flight.fire_mask()).is_equal(Game.MASK_FIRE)
	_touch(level, 0, Vector2(40, 50), false)
	assert_int(level._touch_flight.fire_mask()).is_equal(0)
	level._touch_pause = false
	assert_bool(level.tilt_enabled()).is_false()
	level._touch_pause = true
	level.replaying = true
	assert_bool(level.tilt_enabled()).is_false()
	level.replaying = false
	level.demo = true
	assert_bool(level.tilt_enabled()).is_false()
	level.demo = false
	level.interactive = false
	assert_bool(level.tilt_enabled()).is_false()
	Input.set_gravity(Vector3.ZERO)


func test_pause_controls_toggle_calibrates_and_settings_persist_while_frozen() -> void:
	Input.set_gravity(Vector3(0, 0, -9.8))
	var level := await _level()
	var menu := _menu(level)
	var tick: int = level.sim.tick()
	var state: int = level.sim.state_hash()
	_button(menu, Vector2(20, 181), true)
	assert_int(menu.menus.stack.size()).is_equal(1)
	_button(menu, Vector2(20, 181), false)
	assert_int(menu.menus.stack.size()).is_equal(2)
	assert_bool(MenuEngine.selectable(menu.menus.current().items[2])).is_false()
	for y in [21, 41]:
		_button(menu, Vector2(20, y), true)
		var motion := InputEventMouseMotion.new()
		motion.position = Vector2(310, 190)
		menu.mouse_event(motion)
		_button(menu, Vector2(20, y), false)
	assert_bool(SETUP.settings.tilt_controls_enabled).is_false()
	assert_int(SETUP.settings.tilt_sensitivity).is_equal(5)
	Input.set_gravity(Vector3(2, -3, -9))
	_button(menu, Vector2(20, 21), true)
	assert_bool(SETUP.settings.tilt_controls_enabled).is_false()
	_button(menu, Vector2(20, 21), false)
	assert_bool(SETUP.settings.tilt_controls_enabled).is_true()
	assert_vector(level._tilt_flight.neutral).is_equal(Vector3(2, -3, -9).normalized())
	assert_bool(MenuEngine.selectable(menu.menus.current().items[2])).is_true()
	_tap(menu, Vector2(20, 41))
	assert_int(SETUP.settings.tilt_sensitivity).is_equal(6)
	var cfg := ConfigFile.new()
	assert_int(cfg.load(SETUP.SETTINGS_PATH)).is_equal(OK)
	assert_bool(cfg.get_value("setup", "tilt_controls_enabled")).is_true()
	assert_int(cfg.get_value("setup", "tilt_sensitivity")).is_equal(6)
	menu.handle_action(TyrianControls.LEFT)
	assert_int(SETUP.settings.tilt_sensitivity).is_equal(5)
	_tap(menu, Vector2(20, 21))
	assert_bool(SETUP.settings.tilt_controls_enabled).is_false()
	assert_bool(MenuEngine.selectable(menu.menus.current().items[2])).is_false()
	for frame in 5:
		await get_tree().physics_frame
	assert_int(level.sim.tick()).is_equal(tick)
	assert_int(level.sim.state_hash()).is_equal(state)
	_tap(menu, Vector2(20, 81))
	assert_int(menu.menus.stack.size()).is_equal(1)
	assert_int(menu.menus.selection()).is_equal(8)
	Input.set_gravity(Vector3.ZERO)
