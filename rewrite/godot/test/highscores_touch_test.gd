extends GdUnitTestSuite

const HS := preload("res://scripts/high_scores.gd")
var _scores: Array


func before() -> void:
	EndlessSession.stop()
	Game.campaign_active = false
	_scores = HS.t2k_high_scores.duplicate(true)


func after() -> void:
	HS.t2k_high_scores = _scores
	Music.release_streams()
	Sfx.release_streams()


func after_test() -> void:
	for child in Effects.game_viewport.get_children():
		child.queue_free()
		Effects.game_viewport.remove_child(child)
	await get_tree().process_frame
	TyrianMouse.buttons = 0
	TyrianMouse.inactive = true


func _open(mobile := true) -> Node:
	var screen: Node = Game.goto_scene("res://scenes/high_scores.tscn")
	screen.set("_touch_scores", mobile)
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


func test_pages_activate_on_release_and_preserve_scores() -> void:
	var screen := await _open()
	var before := HS.t2k_high_scores.duplicate(true)
	for page in range(1, HS.PAGE_COUNT):
		_button(screen, Vector2(245, 176), true)
		assert_int(screen.episode_index).is_equal(page - 1)
		_button(screen, Vector2(245, 176), false)
		assert_int(screen.episode_index).is_equal(page)
	_tap(screen, Vector2(245, 176))
	assert_int(screen.episode_index).is_equal(HS.ENDLESS_PAGE)
	for page in range(HS.ENDLESS_PAGE - 1, -1, -1):
		_tap(screen, Vector2(66, 176))
		assert_int(screen.episode_index).is_equal(page)
	_tap(screen, Vector2(66, 176))
	assert_int(screen.episode_index).is_equal(0)
	assert_array(HS.t2k_high_scores).is_equal(before)
	assert_bool(TyrianMouse.any_button_down()).is_false()


func test_dragging_off_cancels_and_back_returns_to_title() -> void:
	var screen := await _open()
	_button(screen, Vector2(230, 185), true)
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(230, 160)
	screen.handle_mouse(motion)
	_button(screen, Vector2(230, 185), false)
	assert_int(screen.episode_index).is_equal(0)
	_button(screen, Vector2(280, 185), true)
	assert_bool(screen.idle).is_true()
	_button(screen, Vector2(280, 185), false)
	for _frame in 1000:
		await get_tree().process_frame
		if Effects.current_game_scene().scene_file_path == Game.SCENE_TITLE:
			break
	assert_str(Effects.current_game_scene().scene_file_path).is_equal(Game.SCENE_TITLE)


func test_desktop_retains_arrow_on_press_and_back_label_fits_locales() -> void:
	var screen := await _open(false)
	_button(screen, Vector2(220, 185), true)
	assert_int(screen.episode_index).is_equal(1)
	_button(screen, Vector2(220, 185), false)
	for language in ["en", "fr", "de", "es", "it", "pt"]:
		assert_int(TyrianText.width(TyrianText.L("gd_back", language), TyrianScreen.SMALL_FONT)).is_less_equal(56)
