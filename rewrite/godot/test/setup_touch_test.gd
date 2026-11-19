extends GdUnitTestSuite

const SetupScreen := preload("res://scripts/setup.gd")


func before_test() -> void:
	EndlessSession.stop()
	Game.campaign_active = false
	SetupScreen.reset_settings()
	SetupScreen.apply_settings()
	Music.release_streams()


func after_test() -> void:
	for child in Effects.game_viewport.get_children():
		child.queue_free()
		Effects.game_viewport.remove_child(child)
	await get_tree().process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SetupScreen.SETTINGS_PATH))
	SetupScreen.reset_settings()
	SetupScreen.apply_settings()
	Music.release_streams()
	Sfx.release_streams()
	Game.mutators = 0
	TyrianMouse.inactive = true
	TyrianMouse.buttons = 0


func _open(mobile := true) -> Node:
	var setup: Node = Game.goto_scene(Game.SCENE_SETUP)
	setup.set("_touch_setup", mobile)
	setup.set("_mobile_options_disabled", mobile)
	for _frame in 1000:
		await get_tree().process_frame
		if setup.idle and not setup._busy:
			break
	assert_bool(setup.idle).is_true()
	return setup


func _button(screen: Node, p: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = p
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	screen.handle_mouse(event)


func _tap(screen: Node, p: Vector2) -> void:
	_button(screen, p, true)
	_button(screen, p, false)


func _row(row: int, x := 18) -> Vector2:
	return Vector2(x, 40 + row * 15)


func test_root_wide_targets_release_and_drag_cancel() -> void:
	var setup := await _open()
	_button(setup, _row(0), true)
	assert_int(setup.menus.stack.size()).is_equal(1)
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(310, 40)
	setup.handle_mouse(motion)
	_button(setup, _row(0), false)
	assert_int(setup.menus.stack.size()).is_equal(1)
	_tap(setup, _row(0))
	assert_str(setup.menus.current().header).is_equal("gfx_header")
	_tap(setup, _row(7, 300))
	assert_int(setup.menus.stack.size()).is_equal(1)
	assert_bool(TyrianMouse.any_button_down()).is_false()


func test_mobile_control_and_mod_rows_are_disabled_and_skipped() -> void:
	var setup := await _open()
	for row in [3, 4, 5]:
		var item: Dictionary = setup.menus.current().items[row]
		assert_bool(MenuEngine.selectable(item)).is_false()
		_tap(setup, _row(row, 160))
		setup.menus.activate(item)
		assert_int(setup.menus.stack.size()).is_equal(1)
		assert_str(Effects.current_game_scene().scene_file_path).is_equal(Game.SCENE_SETUP)
	setup.menus.current().sel = 2
	setup.handle_action(TyrianControls.DOWN)
	assert_int(setup.menus.selection()).is_equal(6)


func test_gameplay_and_mutator_changes_wait_for_release_and_save() -> void:
	var setup := await _open()
	_tap(setup, _row(2))
	var before: bool = SetupScreen.settings.bullet_time_enabled
	_button(setup, _row(0, 300), true)
	assert_bool(SetupScreen.settings.bullet_time_enabled).is_equal(before)
	_button(setup, _row(0, 300), false)
	assert_bool(SetupScreen.settings.bullet_time_enabled).is_equal(not before)
	var config := ConfigFile.new()
	assert_int(config.load(SetupScreen.SETTINGS_PATH)).is_equal(OK)
	assert_bool(config.get_value("setup", "bullet_time_enabled")).is_equal(not before)
	_tap(setup, _row(7))
	assert_str(setup.menus.current().header).is_equal("mut_header")
	_button(setup, _row(0), true)
	assert_int(Game.mutators).is_equal(0)
	_button(setup, _row(0), false)
	assert_int(Game.mutators).is_equal(1)
	_tap(setup, _row(8))
	assert_int(Game.mutators).is_equal(0)
	_tap(setup, _row(9))
	assert_str(setup.menus.current().header).is_equal("gp_header")


func test_graphics_popup_release_and_outside_cancel() -> void:
	var setup := await _open()
	_tap(setup, _row(0))
	_button(setup, _row(1), true)
	assert_bool(setup.menus.popup_open()).is_false()
	_button(setup, _row(1), false)
	assert_bool(setup.menus.popup_open()).is_true()
	var popup: Dictionary = setup.menus._popup
	var before: int = popup.it.get.call()
	var selected := (before + 1) % int(popup.it.count)
	var p := Vector2(popup.x + 10, popup.y + 4 + selected * 15)
	_button(setup, p, true)
	assert_int(int(popup.it.get.call())).is_equal(before)
	_button(setup, p, false)
	assert_bool(setup.menus.popup_open()).is_false()
	assert_int(int(popup.it.get.call())).is_equal(selected)
	_tap(setup, _row(1))
	_button(setup, Vector2(18, 20), true)
	assert_bool(setup.menus.popup_open()).is_true()
	_button(setup, Vector2(18, 20), false)
	assert_bool(setup.menus.popup_open()).is_false()
	assert_int(int(popup.it.get.call())).is_equal(selected)


func test_sound_volume_bar_and_mute_wait_for_release() -> void:
	var setup := await _open()
	_tap(setup, _row(1))
	var before: int = SetupScreen.settings.music_volume
	_button(setup, _row(0, 227), true)
	assert_int(SetupScreen.settings.music_volume).is_equal(before)
	_button(setup, _row(0, 227), false)
	assert_int(SetupScreen.settings.music_volume).is_equal(47 * 255 / 95)
	var muted: bool = SetupScreen.settings.music_disabled
	_button(setup, _row(0), true)
	assert_bool(SetupScreen.settings.music_disabled).is_equal(muted)
	_button(setup, _row(0), false)
	assert_bool(SetupScreen.settings.music_disabled).is_equal(not muted)


func test_desktop_keeps_press_activation_and_enabled_entries() -> void:
	var setup := await _open(false)
	for row in [3, 4, 5]:
		assert_bool(MenuEngine.selectable(setup.menus.current().items[row])).is_true()
	_button(setup, _row(0, 160), true)
	assert_str(setup.menus.current().header).is_equal("gfx_header")
	_button(setup, _row(0, 160), false)
	assert_bool(MenuEngine.selectable(setup.menus.current().items[0])).is_true()
	_button(setup, _row(0, 160), true)
	assert_bool(setup.menus.popup_open()).is_true()
	_button(setup, _row(0, 160), false)


func test_mobile_graphics_display_is_disabled_and_other_options_remain_available() -> void:
	var setup := await _open()
	_tap(setup, _row(0))
	var display: Dictionary = setup.menus.current().items[0]
	var before: int = SetupScreen.settings.display
	assert_bool(MenuEngine.selectable(display)).is_false()
	assert_int(setup.menus.selection()).is_equal(1)
	_tap(setup, _row(0, 160))
	setup.menus.activate(display)
	assert_bool(setup.menus.popup_open()).is_false()
	assert_int(SetupScreen.settings.display).is_equal(before)
	for row in range(1, setup.menus.current().items.size()):
		assert_bool(MenuEngine.selectable(setup.menus.current().items[row])).is_true()
	setup.handle_action(TyrianControls.UP)
	assert_int(setup.menus.selection()).is_equal(7)
