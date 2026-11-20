extends GdUnitTestSuite

const DESTRUCT := preload("res://scripts/destruct.gd")
var _saved_config := ""


func before() -> void:
	_saved_config = DESTRUCT.CONFIG_FILE
	DESTRUCT.CONFIG_FILE = "user://destruct_pause_touch_test.cfg"


func after_test() -> void:
	for child in Effects.game_viewport.get_children():
		child.queue_free()
		Effects.game_viewport.remove_child(child)
	await get_tree().process_frame
	await get_tree().process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(DESTRUCT.CONFIG_FILE))


func after() -> void:
	DESTRUCT.CONFIG_FILE = _saved_config
	Music.release_streams()
	Sfx.release_streams()


func _phase(screen: Node, expected: String) -> void:
	var deadline := Time.get_ticks_msec() + 6000
	while is_instance_valid(screen) and screen.phase != expected and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	assert_str(screen.phase).is_equal(expected)


func _open(mobile := true) -> Node:
	var screen: Node = load("res://scenes/destruct.tscn").instantiate()
	screen.set("_touch_menus", mobile)
	Effects.game_viewport.add_child(screen)
	await _phase(screen, "intro")
	return screen


func _button(screen: Node, point: Vector2, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	screen.handle_mouse(event)


func _tap(screen: Node, point: Vector2) -> void:
	_button(screen, point, true)
	_button(screen, point, false)


func _paused(mobile := true) -> Node:
	var screen := await _open(mobile)
	screen.handle_event(TyrianControls.key_event(KEY_ENTER))
	await _phase(screen, "menu")
	screen.handle_event(TyrianControls.key_event(KEY_ENTER))
	await _phase(screen, "play")
	screen.handle_event(TyrianControls.key_event(KEY_P))
	await _phase(screen, "wait")
	assert_bool(screen.get("_pause_touch_active")).is_true()
	return screen


func test_release_resumes_and_restores_music_without_ticks_while_held() -> void:
	var volume := Music.music_volume
	var screen := await _paused()
	var tick: int = screen.get("_tick")
	var state: PackedInt32Array = screen.game.state()
	assert_int(Music.music_volume).is_equal(volume / 2)
	_button(screen, Vector2(160, 94), true)
	await get_tree().create_timer(0.15).timeout
	assert_str(screen.phase).is_equal("wait")
	assert_int(screen.get("_tick")).is_equal(tick)
	assert_that(screen.game.state()).is_equal(state)
	_button(screen, Vector2(160, 94), false)
	await _phase(screen, "play")
	assert_bool(screen.get("_pause_touch_active")).is_false()
	assert_int(Music.music_volume).is_equal(volume)


func test_drag_off_and_return_cancels_and_body_does_nothing() -> void:
	var screen := await _paused()
	_button(screen, Vector2(160, 94), true)
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2.ZERO
	screen.handle_mouse(motion)
	motion.position = Vector2(160, 94)
	screen.handle_mouse(motion)
	_button(screen, Vector2(160, 94), false)
	_tap(screen, Vector2(100, 150))
	await get_tree().process_frame
	assert_str(screen.phase).is_equal("wait")
	_tap(screen, Vector2(160, 94))
	await _phase(screen, "play")


func test_target_is_limited_to_existing_pause_label() -> void:
	var screen := await _paused()
	assert_str(screen._touch_target(Vector2i(160, 84))).is_equal("resume")
	assert_str(screen._touch_target(Vector2i(160, 103))).is_equal("resume")
	assert_str(screen._touch_target(Vector2i(160, 104))).is_empty()
	assert_str(screen._touch_target(Vector2i(160, 83))).is_empty()
	assert_str(screen._touch_target(Vector2i(16, 94))).is_empty()
	screen.handle_event(TyrianControls.key_event(KEY_ENTER))
	await _phase(screen, "play")


func test_desktop_keeps_mouse_ignored_and_keyboard_resume() -> void:
	var volume := Music.music_volume
	var screen := await _paused(false)
	_tap(screen, Vector2(160, 94))
	await get_tree().process_frame
	assert_str(screen.phase).is_equal("wait")
	screen.handle_event(TyrianControls.key_event(KEY_ENTER))
	await _phase(screen, "play")
	assert_int(Music.music_volume).is_equal(volume)
