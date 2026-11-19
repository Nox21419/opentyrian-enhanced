extends GdUnitTestSuite

const SCENE := "res://scenes/replays_screen.tscn"
var _dir := ""


func before() -> void:
	EndlessSession.stop()
	Game.modes = PackedInt32Array()
	Game.campaign_active = false
	_dir = ProjectSettings.globalize_path("user://replays_touch_test")
	DirAccess.make_dir_recursive_absolute(_dir)
	Capture._options["replay-dir"] = _dir


func after() -> void:
	Capture._options.erase("replay-dir")
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
	Game.replay_file = ""
	TyrianMouse.buttons = 0
	TyrianMouse.inactive = true


func _open(count: int, mobile := true) -> Node:
	for i in count:
		var name := "e2-first-sweep" if i == 1 else "e1-tyrian-sweep"
		var source := ProjectSettings.globalize_path("res://../golden/replays/" + name + ".rep")
		assert_int(DirAccess.copy_absolute(source, _dir.path_join("touch_%02d.rep" % i))).is_equal(OK)
	var screen: Node = Game.goto_scene(SCENE)
	screen.set("_touch_replays", mobile)
	for _frame in 1000:
		await get_tree().process_frame
		if screen.idle:
			break
	assert_bool(screen.idle).is_true()
	assert_int(screen._names.size()).is_equal(count)
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


func test_touch_row_starts_correct_replay_only_on_release() -> void:
	var screen := await _open(3)
	var expected_episode: int = screen._headers[1][0]
	_button(screen, Vector2(18, 52), true)
	assert_str(Effects.current_game_scene().scene_file_path).is_equal(SCENE)
	assert_str(Game.replay_file).is_equal("")
	_button(screen, Vector2(18, 52), false)
	await get_tree().process_frame
	assert_str(Game.replay_file).is_empty()  # Consumed by the level loader.
	assert_str(Effects.current_game_scene().scene_file_path).is_equal(Game.SCENE_LEVEL)
	assert_bool(Effects.current_game_scene().replaying).is_true()
	assert_int(Game.episode).is_equal(expected_episode)
	assert_bool(TyrianMouse.any_button_down()).is_false()


func test_scroll_indicators_move_window_on_release_and_drag_off_cancels() -> void:
	var screen := await _open(12)
	_button(screen, Vector2(290, 179), true)
	assert_int(screen.menus.current().top).is_equal(0)
	_button(screen, Vector2(290, 179), false)
	assert_int(screen.menus.current().top).is_equal(4)
	assert_str(screen._touch_target(Vector2i(290, 179))).is_empty()
	_tap(screen, Vector2(290, 31))
	assert_int(screen.menus.current().top).is_equal(0)
	assert_str(screen._touch_target(Vector2i(290, 31))).is_empty()
	_button(screen, Vector2(100, 35), true)
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(310, 35)
	screen.handle_mouse(motion)
	_button(screen, Vector2(100, 35), false)
	assert_str(Effects.current_game_scene().scene_file_path).is_equal(SCENE)
	assert_str(Game.replay_file).is_equal("")


func test_empty_screen_back_waits_for_release_and_returns_to_title() -> void:
	var screen := await _open(0)
	_button(screen, Vector2(280, 194), true)
	assert_str(Effects.current_game_scene().scene_file_path).is_equal(SCENE)
	_button(screen, Vector2(280, 194), false)
	await get_tree().process_frame
	assert_str(Effects.current_game_scene().scene_file_path).is_equal(Game.SCENE_TITLE)


func test_refused_replay_stays_in_browser_and_desktop_still_ignores_mouse() -> void:
	var screen := await _open(1, false)
	_tap(screen, Vector2(100, 35))
	assert_str(Effects.current_game_scene().scene_file_path).is_equal(SCENE)
	screen.set("_touch_replays", true)
	DirAccess.remove_absolute(_dir.path_join(screen._names[0] + ".rep"))
	_tap(screen, Vector2(100, 35))
	assert_str(Effects.current_game_scene().scene_file_path).is_equal(SCENE)
	assert_str(screen._status).is_equal(TyrianText.L("replay_invalid"))
	assert_int(screen._status_until).is_greater(int(Time.get_ticks_msec()))
