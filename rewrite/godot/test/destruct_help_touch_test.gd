extends GdUnitTestSuite

const DESTRUCT := preload("res://scripts/destruct.gd")
var _saved_config := ""


func before() -> void:
	_saved_config = DESTRUCT.CONFIG_FILE
	DESTRUCT.CONFIG_FILE = "user://destruct_help_touch_test.cfg"


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


func _help(mobile := true) -> Node:
	var screen := await _open(mobile)
	screen.handle_event(TyrianControls.key_event(KEY_ENTER))
	await _phase(screen, "menu")
	screen.handle_event(TyrianControls.key_event(KEY_ENTER))
	await _phase(screen, "play")
	screen.handle_event(TyrianControls.key_event(KEY_F1))
	await _phase(screen, "wait")
	assert_bool(screen.get("_help_touch_active")).is_true()
	return screen


func _resumed(screen: Node, tick: int) -> void:
	var deadline := Time.get_ticks_msec() + 6000
	while int(screen.get("_tick")) == tick and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	assert_str(screen.phase).is_equal("play")
	assert_int(screen.get("_tick")).is_greater(tick)
	assert_bool(screen.get("_help_touch_active")).is_false()


func test_back_requires_release_and_round_stays_frozen_while_held() -> void:
	var screen := await _help()
	var tick: int = screen.get("_tick")
	var state: PackedInt32Array = screen.game.state()
	_button(screen, Vector2(280, 194), true)
	await get_tree().create_timer(0.1).timeout
	assert_str(screen.phase).is_equal("wait")
	assert_int(screen.get("_tick")).is_equal(tick)
	assert_that(screen.game.state()).is_equal(state)
	_button(screen, Vector2(280, 194), false)
	await _resumed(screen, tick)


func test_drag_off_return_body_and_pause_text_area_do_not_close_help() -> void:
	var screen := await _help()
	var tick: int = screen.get("_tick")
	_button(screen, Vector2(280, 194), true)
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2.ZERO
	screen.handle_mouse(motion)
	motion.position = Vector2(280, 194)
	screen.handle_mouse(motion)
	_button(screen, Vector2(280, 194), false)
	_tap(screen, Vector2(160, 94))
	_tap(screen, Vector2(30, 190))
	await get_tree().process_frame
	assert_str(screen.phase).is_equal("wait")
	assert_str(screen._touch_target(Vector2i(252, 184))).is_equal("back")
	assert_str(screen._touch_target(Vector2i(308, 194))).is_empty()
	assert_str(screen._touch_target(Vector2i(280, 183))).is_empty()
	_tap(screen, Vector2(280, 194))
	await _resumed(screen, tick)


func test_desktop_keeps_mouse_ignored_and_keyboard_closes_help() -> void:
	var screen := await _help(false)
	var tick: int = screen.get("_tick")
	_tap(screen, Vector2(280, 194))
	await get_tree().process_frame
	assert_str(screen.phase).is_equal("wait")
	screen.handle_event(TyrianControls.key_event(KEY_ENTER))
	await _resumed(screen, tick)
