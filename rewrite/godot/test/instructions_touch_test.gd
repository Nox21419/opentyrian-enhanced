extends GdUnitTestSuite

const SCENE := "res://scenes/instructions.tscn"
const HELP := preload("res://scripts/instructions.gd")


func before() -> void:
	EndlessSession.stop()
	Game.campaign_active = false


func after() -> void:
	Music.release_streams()
	Sfx.release_streams()


func after_test() -> void:
	for child in Effects.game_viewport.get_children():
		child.queue_free()
		Effects.game_viewport.remove_child(child)
	await get_tree().process_frame
	TyrianMouse.buttons = 0
	TyrianMouse.inactive = true
	TyrianText.language = "en"


func _open(mobile := true) -> Node:
	var screen: Node = Game.goto_scene(SCENE)
	screen.set("_touch_help", mobile)
	for _frame in 1000:
		await get_tree().process_frame
		if screen.idle and not screen._busy:
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


func test_every_topic_waits_for_release_and_back_returns_to_topics() -> void:
	var screen := await _open()
	for row in 5:
		var p := Vector2(18, 62 + row * 20)
		_button(screen, p, true)
		assert_int(screen.page).is_equal(0)
		_button(screen, p, false)
		assert_int(screen.page).is_equal(HELP.TOPIC_START[row + 1])
		_button(screen, Vector2(160, 194), true)
		assert_int(screen.page).is_greater(0)
		_button(screen, Vector2(160, 194), false)
		assert_int(screen.page).is_equal(0)
	assert_bool(TyrianMouse.any_button_down()).is_false()


func test_all_pages_arrows_boundaries_and_drag_cancellation() -> void:
	var screen := await _open()
	_tap(screen, Vector2(300, 62))
	for page in range(1, HELP.MAX_PAGE + 1):
		assert_int(screen.page).is_equal(page)
		_button(screen, Vector2(212, 194), true)
		assert_int(screen.page).is_equal(page)
		_button(screen, Vector2(212, 194), false)
	assert_int(screen.page).is_equal(0)  # Beyond the last page returns to topics.
	_tap(screen, Vector2(18, 62))
	_tap(screen, Vector2(108, 194))
	assert_int(screen.page).is_equal(0)  # Before the first page returns to topics.
	_button(screen, Vector2(18, 62), true)
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(310, 62)
	screen.handle_mouse(motion)
	_button(screen, Vector2(18, 62), false)
	assert_int(screen.page).is_equal(0)
	_tap(screen, Vector2(18, 62))
	_button(screen, Vector2(212, 194), true)
	motion.position = Vector2(212, 160)
	screen.handle_mouse(motion)
	_button(screen, Vector2(212, 194), false)
	assert_int(screen.page).is_equal(1)
	_tap(screen, Vector2(250, 100))
	assert_int(screen.page).is_equal(1)  # Reading the page does not turn it.


func test_exit_topic_returns_to_title_on_release() -> void:
	var screen := await _open()
	_button(screen, Vector2(300, 162), true)
	assert_bool(screen.idle).is_true()
	_button(screen, Vector2(300, 162), false)
	for _frame in 1000:
		await get_tree().process_frame
		if Effects.current_game_scene().scene_file_path == Game.SCENE_TITLE:
			break
	assert_str(Effects.current_game_scene().scene_file_path).is_equal(Game.SCENE_TITLE)


func test_embedded_help_supports_pages_and_emits_closed() -> void:
	var screen: Node = load(SCENE).instantiate()
	screen.embedded = true
	screen.start_topic = 2
	screen.set("_touch_help", true)
	var closed := [false]
	screen.closed.connect(func() -> void: closed[0] = true)
	Effects.game_viewport.add_child(screen)
	for _frame in 1000:
		await get_tree().process_frame
		if screen.idle and not screen._busy:
			break
	assert_int(screen.page).is_equal(1)
	_tap(screen, Vector2(212, 194))
	assert_int(screen.page).is_equal(2)
	_tap(screen, Vector2(160, 194))
	assert_int(screen.page).is_equal(0)
	_tap(screen, Vector2(300, 162))
	for _frame in 1000:
		await get_tree().process_frame
		if closed[0]:
			break
	assert_bool(closed[0]).is_true()


func test_desktop_retains_half_page_clicks_and_mobile_footer_fits_locales() -> void:
	var screen := await _open(false)
	screen.handle_action(TyrianControls.ACCEPT)
	assert_int(screen.page).is_equal(1)
	_button(screen, Vector2(250, 100), true)
	assert_int(screen.page).is_equal(2)
	_button(screen, Vector2(250, 100), false)
	for language in ["en", "fr", "de", "es", "it", "pt"]:
		assert_int(TyrianText.width(TyrianText.L("gd_back", language), TyrianScreen.SMALL_FONT)).is_less_equal(56)
	screen.set("_touch_help", true)
	screen._draw_page()
	var pixels: PackedByteArray = screen.vga.indices(TyrianScreen.VGA_SCREEN)
	for x in [108, 212]:
		var visible := false
		for y in range(192, 200):
			for column in range(x - 5, x + 6):
				visible = visible or pixels[y * 320 + column] == 252
		assert_bool(visible).is_true()
