extends GdUnitTestSuite

const SCENE := "res://scenes/network_arcade_menu.tscn"
const LOBBY := "res://scenes/network_lobby.tscn"
var _episode := 1
var _campaign := false
var _modes := PackedInt32Array()


func before_test() -> void:
	_episode = Game.episode
	_campaign = Game.campaign_active
	_modes = Game.campaign_modes.duplicate()
	NetworkSession.stop()


func after_test() -> void:
	for child in Effects.game_viewport.get_children():
		child.queue_free()
		Effects.game_viewport.remove_child(child)
	await get_tree().process_frame
	await get_tree().process_frame
	NetworkSession.stop()
	Game.episode = _episode
	Game.campaign_active = _campaign
	Game.campaign_modes = _modes


func after() -> void:
	Music.release_streams()
	Sfx.release_streams()
	await get_tree().process_frame
	await get_tree().process_frame


func _wait(condition: Callable) -> void:
	var deadline := Time.get_ticks_msec() + 4000
	while not condition.call() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	assert_bool(condition.call()).is_true()


func _open() -> Node:
	assert_int(NetworkSession.host()).is_equal(OK)
	NetworkSession.selected_episode = 3
	NetworkSession.selected_difficulty = 4
	assert_bool(NetworkSession.begin_arcade_menu()).is_true()
	var menu: Node = Game.goto_scene(SCENE)
	await _wait(func(): return menu.idle)
	return menu


func test_original_menu_records_start_without_launching_or_mutating_campaign() -> void:
	var menu := await _open()
	var peer: ENetMultiplayerPeer = NetworkSession.lobby.peer
	assert_int(menu.get("_arcade_menu")).is_equal(9)
	for row in [1, 2, 3]:
		assert_bool(menu.menus.current().items[row].unavailable).is_true()
	menu.handle_action(TyrianControls.DOWN)
	assert_int(menu.get("_arcade_sel")).is_equal(6)
	menu.handle_action(TyrianControls.UP)
	assert_int(menu.get("_arcade_sel")).is_equal(2)
	menu.set("_phone_touch", true)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = Vector2(200, 42)
	event.pressed = true
	menu.handle_mouse(event)
	assert_bool(NetworkSession.start_requested).is_false()
	event.pressed = false
	menu.handle_mouse(event)
	await _wait(
		func(): return Effects.current_game_scene().scene_file_path == LOBBY and Effects.current_game_scene().idle
	)
	assert_bool(NetworkSession.start_requested).is_true()
	assert_object(NetworkSession.lobby.peer).is_same(peer)
	assert_int(Game.episode).is_equal(_episode)
	assert_bool(Game.campaign_active).is_equal(_campaign)
	assert_array(Array(Game.campaign_modes)).is_equal(Array(_modes))


func test_fixed_rows_and_cancelled_touch_do_not_change_devices_or_request_start() -> void:
	var menu := await _open()
	menu.set("_phone_touch", true)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = Vector2(200, 42)
	event.pressed = true
	menu.handle_mouse(event)
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(10, 10)
	menu.handle_mouse(motion)
	event.pressed = false
	menu.handle_mouse(event)
	assert_bool(NetworkSession.start_requested).is_false()
	for row in [3, 4, 5]:
		menu.set("_arcade_sel", row)
		menu._arcade_function()
	assert_array(Array(Game.campaign_modes)).is_equal(Array(_modes))
	assert_str(Effects.current_game_scene().scene_file_path).is_equal(SCENE)
	Game.goto_scene(Game.SCENE_TITLE)
	await get_tree().process_frame
	assert_bool(NetworkSession.lobby.peer == null).is_true()
	assert_bool(NetworkSession.selecting_arcade).is_false()


func test_quit_confirmation_and_translated_labels() -> void:
	for language in ["en", "de", "es", "fr", "it", "pt"]:
		(
			assert_int(TyrianText.width("%s 2" % TyrianText.L("net_phone", language), TyrianScreen.NORMAL_FONT))
			. is_less_equal(122)
		)
		(
			assert_int(TyrianText.width(TyrianText.L("net_start_selected", language), TyrianScreen.SMALL_FONT))
			. is_less_equal(288)
		)
	var menu := await _open()
	menu.set("_arcade_sel", 6)
	menu._arcade_function()
	await _wait(func(): return menu.modal_active)
	menu.handle_action(TyrianControls.BACK)
	await _wait(func(): return not menu.modal_active and menu.idle)
	assert_bool(NetworkSession.lobby.hosting).is_true()
	menu._arcade_function()
	await _wait(func(): return menu.modal_active)
	# Original quit box: Y confirms directly, without changing local campaign.
	var event := InputEventKey.new()
	event.keycode = KEY_Y
	event.physical_keycode = KEY_Y
	event.pressed = true
	menu.handle_event(event)
	await _wait(func(): return Effects.current_game_scene().scene_file_path == Game.SCENE_TITLE)
	assert_bool(NetworkSession.lobby.peer == null).is_true()
	assert_bool(Game.campaign_active).is_equal(_campaign)
