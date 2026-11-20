extends GdUnitTestSuite

const DESTRUCT := preload("res://scripts/destruct.gd")
var _saved_config := ""


func before() -> void:
	_saved_config = DESTRUCT.CONFIG_FILE
	DESTRUCT.CONFIG_FILE = "user://destruct_touch_test.cfg"


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


func test_intro_continue_requires_release_and_drag_off_cancels() -> void:
	var screen := await _open()
	_button(screen, Vector2(160, 180), true)
	assert_str(screen.phase).is_equal("intro")
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2.ZERO
	screen.handle_mouse(motion)
	_button(screen, Vector2(160, 180), false)
	await get_tree().process_frame
	assert_str(screen.phase).is_equal("intro")
	_tap(screen, Vector2(160, 90))
	assert_str(screen.phase).is_equal("intro")
	_tap(screen, Vector2(160, 180))
	await _phase(screen, "menu")
	assert_int(screen.menus.current().items.size()).is_equal(6)


func test_intro_back_returns_to_title() -> void:
	var screen := await _open()
	_tap(screen, Vector2(160, 194))
	await get_tree().create_timer(0.7).timeout
	assert_str(Effects.current_game_scene().scene_file_path).is_equal(Game.SCENE_TITLE)


func test_each_original_mode_starts_only_on_release() -> void:
	for row in 5:
		var screen := await _open()
		_tap(screen, Vector2(160, 180))
		await _phase(screen, "menu")
		var point := Vector2(300, 84 + row * 12)
		_button(screen, point, true)
		assert_int(screen.menus.selection()).is_equal(row)
		assert_str(screen.phase).is_equal("menu")
		_button(screen, point, false)
		await _phase(screen, "play")
		assert_int(screen.get("_mode_result")).is_equal(row)
		await after_test()


func test_mode_drag_off_and_back() -> void:
	var screen := await _open()
	_tap(screen, Vector2(160, 180))
	await _phase(screen, "menu")
	_button(screen, Vector2(300, 84), true)
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(300, 100)
	screen.handle_mouse(motion)
	_button(screen, Vector2(300, 84), false)
	assert_int(screen.get("_mode_result")).is_equal(-2)
	_tap(screen, Vector2(300, 190))
	await get_tree().create_timer(0.7).timeout
	assert_str(Effects.current_game_scene().scene_file_path).is_equal(Game.SCENE_TITLE)


func test_desktop_ignores_touch_and_keeps_original_rows() -> void:
	var screen := await _open(false)
	_tap(screen, Vector2(160, 180))
	assert_str(screen.phase).is_equal("intro")
	screen.handle_event(TyrianControls.key_event(KEY_ENTER))
	await _phase(screen, "menu")
	assert_int(screen.menus.current().items.size()).is_equal(5)
	_tap(screen, Vector2(160, 84))
	assert_int(screen.get("_mode_result")).is_equal(-2)
	screen.handle_event(TyrianControls.key_event(KEY_ESCAPE))
	await get_tree().create_timer(0.7).timeout


func test_custom_mode_keeps_separate_back_row() -> void:
	var config := FileAccess.open(DESTRUCT.CONFIG_FILE, FileAccess.WRITE)
	config.store_string('section "destruct custom"\r\nitem enable yes\r\n')
	config.close()
	var screen := await _open()
	_tap(screen, Vector2(160, 180))
	await _phase(screen, "menu")
	assert_int(screen.menus.current().items.size()).is_equal(7)
	assert_str(screen._touch_target(Vector2i(300, 144))).is_equal("mode:5")
	screen.handle_event(TyrianControls.key_event(KEY_UP))
	assert_int(screen.menus.selection()).is_equal(6)
	_tap(screen, Vector2(300, 144))
	await _phase(screen, "play")
	assert_int(screen.get("_mode_result")).is_equal(5)
