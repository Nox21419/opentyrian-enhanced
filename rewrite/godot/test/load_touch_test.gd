extends GdUnitTestSuite

const SCENE := "res://scenes/load_screen.tscn"
var _saved_dir := ""
var _dir := ""


func before() -> void:
	EndlessSession.stop()
	_saved_dir = Game.saves_dir
	Game.saves_dir = "user://load_touch_test"
	_dir = ProjectSettings.globalize_path(Game.saves_dir)
	DirAccess.make_dir_recursive_absolute(_dir)


func after() -> void:
	Game.saves_dir = _saved_dir
	DirAccess.remove_absolute(_dir)
	Music.release_streams()
	Sfx.release_streams()


func after_test() -> void:
	for child in Effects.game_viewport.get_children():
		child.queue_free()
		Effects.game_viewport.remove_child(child)
	await get_tree().process_frame
	for file in DirAccess.get_files_at(_dir):
		DirAccess.remove_absolute(_dir.path_join(file))
	Game.campaign_active = false
	TyrianMouse.buttons = 0
	TyrianMouse.inactive = true


func _open(saved := false, mobile := true) -> Node:
	Game.modes = PackedInt32Array()
	Game.modes_extra = []
	Game.campaign_active = false
	if saved:
		Game.episode = 1
		Game.initial_difficulty = 2
		Game.difficulty = 2
		Game.level_name = "TYRIAN"
		Game.main_level = 4
		Game.loadout = PackedInt32Array([1, 1, 1, 0, 1, 4, 2, 0, 0, 0, 24680])
		assert_bool(Game.save_campaign(1, "TOUCH", 4)).is_true()
	var screen: Node = Game.goto_scene(SCENE)
	screen.set("_touch_load", mobile)
	for _frame in 1000:
		await get_tree().process_frame
		if screen.idle:
			break
	assert_bool(screen.idle).is_true()
	return screen


func _button(screen: Node, p: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = p
	event.pressed = pressed
	event.button_index = MOUSE_BUTTON_LEFT
	screen.handle_mouse(event)


func _tap(screen: Node, p: Vector2) -> void:
	_button(screen, p, true)
	_button(screen, p, false)


func test_saved_slot_loads_on_release_and_drag_off_cancels() -> void:
	var screen := await _open(true)
	var saved := FileAccess.get_file_as_string(_dir.path_join("slot_01.json"))
	_button(screen, Vector2(8, 31), true)
	assert_bool(screen.idle).is_true()
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(319, 31)
	screen.handle_mouse(motion)
	_button(screen, Vector2(8, 31), false)
	assert_str(Effects.current_game_scene().scene_file_path).is_equal(SCENE)
	assert_str(FileAccess.get_file_as_string(_dir.path_join("slot_01.json"))).is_equal(saved)
	Game.loadout[10] = 0
	_button(screen, Vector2(310, 31), true)
	assert_bool(screen.idle).is_true()
	_button(screen, Vector2(310, 31), false)
	for _frame in 2000:
		await get_tree().process_frame
		if Effects.current_game_scene().scene_file_path == Game.SCENE_SHOP:
			break
	assert_str(Effects.current_game_scene().scene_file_path).is_equal(Game.SCENE_SHOP)
	assert_int(Game.loadout[10]).is_equal(24680)
	assert_bool(TyrianMouse.any_button_down()).is_false()


func test_mobile_page_controls_are_unavailable_and_rows_keep_original_order() -> void:
	var screen := await _open()
	for row in 12:
		assert_int(screen._touch_row(Vector2i(8, 30 + row * 13))).is_equal(row)
	assert_int(screen._touch_row(Vector2i(220, 180))).is_equal(-1)
	_tap(screen, Vector2(220, 185))
	screen.handle_action(TyrianControls.RIGHT)
	screen.handle_action(TyrianControls.LEFT)
	assert_int(screen.players_index).is_equal(0)
	assert_str(Effects.current_game_scene().scene_file_path).is_equal(SCENE)


func test_empty_and_unreadable_slots_do_not_load() -> void:
	var screen := await _open()
	_tap(screen, Vector2(160, 31))
	assert_bool(screen.idle).is_true()
	screen._slots[1] = {"error": "test unreadable save"}
	_tap(screen, Vector2(160, 44))
	assert_bool(screen.idle).is_true()
	assert_str(Effects.current_game_scene().scene_file_path).is_equal(SCENE)


func test_existing_exit_row_waits_for_release() -> void:
	var screen := await _open()
	_button(screen, Vector2(160, 175), true)
	assert_bool(screen.idle).is_true()
	_button(screen, Vector2(160, 175), false)
	for _frame in 1000:
		await get_tree().process_frame
		if Effects.current_game_scene().scene_file_path == Game.SCENE_TITLE:
			break
	assert_str(Effects.current_game_scene().scene_file_path).is_equal(Game.SCENE_TITLE)


func test_desktop_keeps_two_player_paging_on_press() -> void:
	var screen := await _open(false, false)
	_button(screen, Vector2(220, 185), true)
	assert_int(screen.players_index).is_equal(1)
	_button(screen, Vector2(220, 185), false)
	screen.handle_action(TyrianControls.LEFT)
	assert_int(screen.players_index).is_equal(0)
