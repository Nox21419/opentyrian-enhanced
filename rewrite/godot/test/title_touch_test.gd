extends GdUnitTestSuite

const TitleScreen := preload("res://scripts/title.gd")


func after_test() -> void:
	for child in Effects.game_viewport.get_children():
		child.queue_free()
		Effects.game_viewport.remove_child(child)
	await get_tree().process_frame
	await get_tree().process_frame
	TitleScreen.selected = 0
	TyrianMouse.inactive = true


func _open_title() -> Node:
	TitleScreen.intro_shown = true
	TitleScreen.move_tyrian_logo_up = false
	var title: Node = Game.goto_scene(Game.SCENE_TITLE)
	for _frame in 3000:
		if title.idle and not title.get("_busy") and not title.menus.stack.is_empty():
			break
		await get_tree().process_frame
	return title


func test_desktop_keeps_original_menu() -> void:
	if OS.get_name() == "Android":
		return
	var title := await _open_title()
	assert_bool(title.get("_touch_layout")).is_false()
	assert_int(title.menus.current().items.size()).is_equal(9)
	title.handle_action(TyrianControls.DOWN)
	assert_int(title.menus.selection()).is_equal(1)


func _open_touch_title() -> Node:
	var title := await _open_title()
	title.set("_touch_layout", true)
	if title.menus.current().items.size() == 9:
		title._items.append(MenuEngine.item(TyrianText.L("gd_modes_title"), "", MenuEngine.Kind.ACTION))
	title.menus.current().options.title_position = title._title_position
	await title._restart()
	title._redraw_selection()
	return title


func _button(title: Node, row: int, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = Vector2(title._title_position(row)) + Vector2(0, 4)
	event.pressed = pressed
	title.handle_mouse(event)


func test_touch_release_opens_selected_screen_once() -> void:
	var title := await _open_touch_title()
	_button(title, TitleScreen.SETUP, true)
	assert_bool(title.get("_busy")).is_false()
	assert_int(title.menus.selection()).is_equal(TitleScreen.SETUP)
	_button(title, TitleScreen.SETUP, false)
	assert_bool(title.get("_busy")).is_true()
	_button(title, TitleScreen.NEW_GAME, true)
	_button(title, TitleScreen.NEW_GAME, false)
	await get_tree().create_timer(0.5).timeout
	assert_str(Effects.game_viewport.get_child(0).scene_file_path).is_equal(Game.SCENE_SETUP)


func test_drag_off_cancels_activation() -> void:
	var title := await _open_touch_title()
	_button(title, TitleScreen.SETUP, true)
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(0, 0)
	motion.relative = Vector2(-80, -132)
	title.handle_mouse(motion)
	_button(title, TitleScreen.SETUP, false)
	assert_bool(title.get("_busy")).is_false()
	assert_str(title.scene_file_path).is_equal(Game.SCENE_TITLE)


func test_touch_quit_cancel_restores_menu() -> void:
	var title := await _open_touch_title()
	_button(title, TitleScreen.QUIT, true)
	_button(title, TitleScreen.QUIT, false)
	assert_bool(title.modal_active).is_true()
	title.modal_input(TyrianControls.NO)
	await get_tree().create_timer(1.0).timeout
	assert_bool(title.modal_active).is_false()
	assert_bool(title.idle).is_true()


func test_side_modes_has_touch_entry() -> void:
	var title := await _open_touch_title()
	_button(title, 9, true)
	_button(title, 9, false)
	await get_tree().process_frame
	assert_str(Effects.game_viewport.get_child(0).scene_file_path).is_equal(Game.SCENE_MODES)


func test_each_touch_target_matches_drawn_row() -> void:
	var title := await _open_touch_title()
	for row in 10:
		var position: Vector2i = title._title_position(row)
		assert_int(title._touch_row(position)).is_equal(row)
		assert_int(title._touch_row(position + Vector2i(-70, 10))).is_equal(row)
		assert_int(title._touch_row(position + Vector2i(70, 10))).is_equal(row)
	assert_int(title._touch_row(Vector2i(160, 195))).is_equal(-1)
