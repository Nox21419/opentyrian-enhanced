extends GdUnitTestSuite

const NG := preload("res://scripts/new_game.gd")
const SCREEN := "res://scenes/network_lobby.tscn"


func after() -> void:
	Music.release_streams()
	Sfx.release_streams()


func after_test() -> void:
	for child in Effects.game_viewport.get_children():
		child.queue_free()
		Effects.game_viewport.remove_child(child)
	await get_tree().process_frame
	await get_tree().process_frame
	TyrianMouse.inactive = true


func _wait(condition: Callable) -> void:
	var deadline := Time.get_ticks_msec() + 4000
	while not condition.call() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	assert_bool(condition.call()).is_true()


func _open() -> Node:
	var screen: Node = Game.goto_scene(SCREEN)
	await _wait(func(): return screen.idle)
	screen.set("_touch", true)
	return screen


func _button(screen: Node, row: int, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = Vector2(20, 87 + 22 * row)
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	screen.handle_mouse(event)


func test_players_network_entry_opens_lobby() -> void:
	NG.flow = NG.Flow.NEW_GAME
	var players: Node = Game.goto_scene(Game.SCENE_NEW_GAME)
	await _wait(func(): return players.idle and not players.get("_busy"))
	players.set("_touch_players", true)
	assert_bool(players._gameplay_disabled(NG.MODE_NETWORK)).is_false()
	players.menus.current().sel = NG.MODE_NETWORK
	players.handle_action(TyrianControls.ACCEPT)
	await _wait(func(): return Effects.current_game_scene().scene_file_path == SCREEN)
	var lobby: Node = Effects.current_game_scene()
	await _wait(func(): return lobby.idle)
	assert_int(lobby.menus.current().items.size()).is_equal(3)
	assert_str(lobby.session.status_key).is_equal("net_idle")


func test_host_release_opens_socket_and_second_tap_closes_it() -> void:
	var screen := await _open()
	_button(screen, 0, true)
	assert_bool(screen.session.peer == null).is_true()
	_button(screen, 0, false)
	assert_bool(screen.session.hosting).is_true()
	assert_str(screen.session.status_key).is_equal("net_waiting")
	_button(screen, 0, true)
	_button(screen, 0, false)
	assert_bool(screen.session.peer == null).is_true()
	assert_str(screen.session.status_key).is_equal("net_idle")


func test_drag_off_does_not_host() -> void:
	var screen := await _open()
	_button(screen, 0, true)
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2.ZERO
	screen.handle_mouse(motion)
	_button(screen, 0, false)
	assert_bool(screen.session.peer == null).is_true()


func test_join_validates_address_and_cancel_does_not_connect() -> void:
	var screen := await _open()
	_button(screen, 1, true)
	_button(screen, 1, false)
	assert_bool(screen.get("_typing")).is_true()
	screen.handle_action(TyrianControls.ACCEPT)
	assert_str(screen.session.status_key).is_equal("net_bad_address")
	_button(screen, 1, true)
	_button(screen, 1, false)
	for character in "127.0.0.1":
		var event := InputEventKey.new()
		event.pressed = true
		event.unicode = character.unicode_at(0)
		screen.handle_event(event)
	assert_str(screen.get("_address")).is_equal("127.0.0.1")
	screen.handle_action(TyrianControls.BACK)
	assert_bool(screen.get("_typing")).is_false()
	assert_str(screen.get("_address")).is_empty()
	assert_bool(screen.session.peer == null).is_true()


func test_back_closes_host_and_returns_to_players() -> void:
	var screen := await _open()
	screen._activate(0)
	assert_bool(screen.session.hosting).is_true()
	var session: Node = screen.session
	screen.handle_action(TyrianControls.BACK)
	assert_bool(session.peer == null).is_true()
	await _wait(func(): return Effects.current_game_scene().scene_file_path == Game.SCENE_NEW_GAME)


func test_desktop_keeps_original_text_targets() -> void:
	var screen := await _open()
	screen.set("_touch", false)
	assert_int(screen._hit(Vector2i(20, 87))).is_equal(-1)
	assert_int(screen._hit(Vector2i(160, 87))).is_equal(0)
	screen.handle_action(TyrianControls.ACCEPT)
	assert_bool(screen.session.hosting).is_true()


func test_translated_labels_fit_original_fonts() -> void:
	var keys := ["host", "join", "stop_host", "disconnect", "choose_episode"]
	var details := [
		"lan_only",
		"idle",
		"waiting",
		"connecting",
		"connected",
		"disconnected",
		"host_failed",
		"join_failed",
		"bad_address",
		"timeout",
		"incompatible",
		"enter_address",
		"connection_test"
	]
	for language in ["en", "de", "es", "fr", "it", "pt"]:
		assert_int(TyrianText.width(TyrianText.L("net_title", language), TyrianScreen.LARGE_FONT)).is_less_equal(288)
		for key in keys:
			assert_int(TyrianText.width(TyrianText.L("net_" + key, language), TyrianScreen.NORMAL_FONT)).is_less_equal(
				288
			)
		for key in details:
			assert_int(TyrianText.width(TyrianText.L("net_" + key, language), TyrianScreen.SMALL_FONT)).is_less_equal(
				288
			)
