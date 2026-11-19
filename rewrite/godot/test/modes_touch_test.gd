extends GdUnitTestSuite

const SetupScreen := preload("res://scripts/setup.gd")
var _mutators := 0
var _anomalies := 0


func before_test() -> void:
	EndlessSession.stop()
	_mutators = Game.mutators
	_anomalies = Game.anomalies
	Game.mutators = 0
	Game.anomalies = 0


func after_test() -> void:
	SetupScreen._set_mutators(_mutators)
	Game.anomalies = _anomalies
	Game.modes = PackedInt32Array()
	Game.campaign_active = false
	for child in Effects.game_viewport.get_children():
		child.queue_free()
		Effects.game_viewport.remove_child(child)
	await get_tree().process_frame
	TyrianMouse.buttons = 0
	TyrianMouse.inactive = true


func _open(mobile := true) -> Node:
	var menu: Node = Game.goto_scene(Game.SCENE_MODES)
	menu.set("_touch_modes", mobile)
	menu.menus.draw()
	return menu


func _button(menu: Node, p: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = p
	event.pressed = pressed
	event.button_index = MOUSE_BUTTON_LEFT
	menu.handle_mouse(event)


func _tap(menu: Node, p: Vector2) -> void:
	_button(menu, p, true)
	_button(menu, p, false)


func test_every_modifier_activates_on_release_and_mutators_persist() -> void:
	var menu := _open()
	for i in menu.MUTATORS.size():
		var p := Vector2(10, 40 + i * 9)
		var before_mask := Game.mutators
		_button(menu, p, true)
		assert_int(Game.mutators).is_equal(before_mask)
		_button(menu, p, false)
		assert_int(Game.mutators).is_equal(before_mask ^ (1 << i))
		assert_int(int(SetupScreen.settings.mutators)).is_equal(Game.mutators)
	for i in menu.ANOMALIES.size():
		var p := Vector2(310, 40 + i * 9)
		var before_mask := Game.anomalies
		_button(menu, p, true)
		assert_int(Game.anomalies).is_equal(before_mask)
		_button(menu, p, false)
		assert_int(Game.anomalies).is_equal(before_mask ^ (1 << i))
	assert_bool(TyrianMouse.any_button_down()).is_false()


func test_modes_cycle_and_two_players_cannot_start_on_mobile() -> void:
	var menu := _open()
	assert_str(menu._touch_target(Vector2i(88, 182))).is_empty()
	menu.start()
	menu.handle_action(TyrianControls.ACCEPT)
	assert_str(Effects.current_game_scene().scene_file_path).is_equal(Game.SCENE_MODES)
	_button(menu, Vector2(306, 27), true)
	assert_int(menu.mode_index).is_equal(0)
	_button(menu, Vector2(306, 27), false)
	assert_int(menu.mode_index).is_equal(1)
	for i in range(2, menu.MODES.size()):
		_tap(menu, Vector2(306, 27))
		assert_int(menu.mode_index).is_equal(i)
	_tap(menu, Vector2(306, 27))
	assert_int(menu.mode_index).is_equal(0)
	_tap(menu, Vector2(10, 27))
	assert_int(menu.mode_index).is_equal(menu.MODE_DESTRUCT)


func test_drag_off_and_return_cancels_every_touch_action() -> void:
	var menu := _open()
	menu.mode_index = 1
	for p in [
		Vector2(10, 27), Vector2(306, 27), Vector2(50, 40), Vector2(200, 40), Vector2(88, 182), Vector2(240, 182)
	]:
		_button(menu, p, true)
		var motion := InputEventMouseMotion.new()
		motion.position = Vector2(319, 160)
		menu.handle_mouse(motion)
		motion.position = p
		menu.handle_mouse(motion)
		_button(menu, p, false)
		assert_int(menu.mode_index).is_equal(1)
		assert_int(Game.mutators).is_equal(0)
		assert_int(Game.anomalies).is_equal(0)
		assert_str(Effects.current_game_scene().scene_file_path).is_equal(Game.SCENE_MODES)


func test_start_launches_selected_mode_with_existing_flags() -> void:
	var menu := _open()
	menu.mode_index = 3
	Game.mutators = 2
	Game.anomalies = 4
	_button(menu, Vector2(88, 182), true)
	assert_str(Effects.current_game_scene().scene_file_path).is_equal(Game.SCENE_MODES)
	_button(menu, Vector2(88, 182), false)
	await get_tree().process_frame
	assert_str(Effects.current_game_scene().scene_file_path).is_equal(Game.SCENE_LEVEL)
	assert_int(Game.episode).is_equal(1)
	assert_int(Game.lvl_file_num).is_equal(18)
	assert_array(Array(Game.modes)).is_equal([0, 1, 1, 0, 1, 0, 2, 4, 0, 0])


func test_back_and_desktop_press_behavior() -> void:
	var menu := _open(false)
	_button(menu, Vector2(100, 27), true)
	assert_int(menu.mode_index).is_equal(1)
	_button(menu, Vector2(100, 27), false)
	menu.handle_action(TyrianControls.LEFT)
	assert_int(menu.mode_index).is_equal(0)
	menu.set("_touch_modes", true)
	_button(menu, Vector2(240, 182), true)
	assert_str(Effects.current_game_scene().scene_file_path).is_equal(Game.SCENE_MODES)
	_button(menu, Vector2(240, 182), false)
	await get_tree().process_frame
	assert_str(Effects.current_game_scene().scene_file_path).is_equal(Game.SCENE_TITLE)


func test_destruct_uses_its_existing_scene() -> void:
	var menu := _open()
	menu.mode_index = menu.MODE_DESTRUCT
	_tap(menu, Vector2(88, 182))
	await get_tree().process_frame
	assert_str(Effects.current_game_scene().scene_file_path).is_equal(Game.SCENE_DESTRUCT)


func test_desktop_two_players_still_launches() -> void:
	var menu := _open(false)
	menu.start()
	await get_tree().process_frame
	assert_str(Effects.current_game_scene().scene_file_path).is_equal(Game.SCENE_LEVEL)
	assert_int(Game.modes[0]).is_equal(1)


func test_localized_touch_labels_fit_their_regions() -> void:
	var menu := _open()
	var saved_language := TyrianText.language
	for language in ["en", "de", "es", "fr", "it", "pt"]:
		TyrianText.language = language
		assert_int(TyrianText.width(TyrianText.L("shop_start_level"), TyrianScreen.SMALL_FONT)).is_less_equal(145)
		assert_int(TyrianText.width(TyrianText.L("gd_back"), TyrianScreen.SMALL_FONT)).is_less_equal(128)
		for mode in menu.MODES:
			var label: String = TyrianText.L("gd_modes_mode") % TyrianText.L(mode[0])
			label = label.replace("<", " ").replace(">", " ")
			assert_int(TyrianText.width(label, TyrianScreen.SMALL_FONT)).is_less_equal(280)
	TyrianText.language = saved_language
