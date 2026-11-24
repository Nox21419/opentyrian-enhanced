extends GdUnitTestSuite

const SETUP := preload("res://scripts/setup.gd")
const LocalOptions := preload("res://scripts/save_menu.gd")
const ARCADE := "res://scenes/network_arcade_menu.tscn"
const OPTIONS := "res://scenes/network_options.tscn"
var _settings := {}
var _game := {}
var _entry := 0


func before_test() -> void:
	_settings = SETUP.settings.duplicate(true)
	_game = {
		"episode": Game.episode,
		"campaign_active": Game.campaign_active,
		"loadout": Game.loadout.duplicate(),
		"shop_menu_rows": Game.shop_menu_rows.duplicate(true),
		"shop_resume_sel": Game.shop_resume_sel,
		"campaign_modes": Game.campaign_modes.duplicate(),
	}
	_entry = LocalOptions.entry_row
	NetworkSession.stop()


func after_test() -> void:
	for child in Effects.game_viewport.get_children():
		child.queue_free()
		Effects.game_viewport.remove_child(child)
	await get_tree().process_frame
	await get_tree().process_frame
	NetworkSession.stop()
	for key in _game:
		Game.set(key, _game[key])
	LocalOptions.entry_row = _entry
	SETUP.settings = _settings
	SETUP.apply_settings()
	SETUP.save_settings()
	TyrianMouse.inactive = true


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
	var arcade: Node = Game.goto_scene(ARCADE)
	await _wait(func(): return arcade.idle)
	arcade.set("_arcade_sel", 5)
	arcade._arcade_function()
	await _wait(
		func(): return Effects.current_game_scene().scene_file_path == OPTIONS and Effects.current_game_scene().idle
	)
	return Effects.current_game_scene()


func _button(screen: Node, p: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = p
	event.pressed = pressed
	screen.handle_mouse(event)


func test_original_options_blocks_save_load_and_devices_and_preserves_local_campaign() -> void:
	LocalOptions.entry_row = 3
	var options := await _open()
	var peer: ENetMultiplayerPeer = NetworkSession.lobby.peer
	assert_int(options.menus.current().items.size()).is_equal(8)
	assert_int(options.menus.selection()).is_equal(2)
	for row in [0, 1, 4, 5, 6]:
		assert_bool(options.menus.current().items[row].unavailable).is_true()
	options.handle_action(TyrianControls.DOWN)
	assert_int(options.menus.selection()).is_equal(3)
	options.handle_action(TyrianControls.DOWN)
	assert_int(options.menus.selection()).is_equal(7)
	options.handle_action(TyrianControls.ACCEPT)
	await _wait(
		func(): return Effects.current_game_scene().scene_file_path == ARCADE and Effects.current_game_scene().idle
	)
	assert_int(Effects.current_game_scene().get("_arcade_sel")).is_equal(5)
	assert_object(NetworkSession.lobby.peer).is_same(peer)
	for key in _game:
		assert_bool(Game.get(key) == _game[key]).override_failure_message(key).is_true()
	assert_int(LocalOptions.entry_row).is_equal(3)
	Effects.current_game_scene()._arcade_function()
	await _wait(
		func(): return Effects.current_game_scene().scene_file_path == OPTIONS and Effects.current_game_scene().idle
	)
	assert_int(Effects.current_game_scene().menus.selection()).is_equal(7)


func test_touch_volume_waits_for_release_and_writes_host_audio_preferences() -> void:
	var options := await _open()
	options.set("_touch_options", true)
	var before := int(SETUP.settings.music_volume)
	var point := Vector2(245 if before != 72 else 261, 74)
	var expected := 72 if before != 72 else 120
	_button(options, point, true)
	assert_int(int(SETUP.settings.music_volume)).is_equal(before)
	_button(options, point, false)
	assert_int(int(SETUP.settings.music_volume)).is_equal(expected)
	assert_int(Music.user_volume).is_equal(expected)
	var config := ConfigFile.new()
	assert_int(config.load(SETUP.SETTINGS_PATH)).is_equal(OK)
	assert_int(int(config.get_value("setup", "music_volume"))).is_equal(expected)
	options.handle_action(TyrianControls.DOWN)
	assert_int(options.menus.selection()).is_equal(3)
	var sound_before := int(SETUP.settings.fx_volume)
	var direction := TyrianControls.RIGHT if sound_before < 244 else TyrianControls.LEFT
	var sound_expected := sound_before + 12 if sound_before < 244 else sound_before - 12
	options.handle_action(direction)
	assert_int(Sfx.volume).is_equal(sound_expected)
	assert_int(config.load(SETUP.SETTINGS_PATH)).is_equal(OK)
	assert_int(int(config.get_value("setup", "fx_volume"))).is_equal(sound_expected)
	options.handle_action(TyrianControls.BACK)
	await _wait(
		func(): return Effects.current_game_scene().scene_file_path == ARCADE and Effects.current_game_scene().idle
	)
	assert_int(int(SETUP.settings.music_volume)).is_equal(expected)


func test_unexpected_exit_and_lost_host_cannot_retain_session_or_options_state() -> void:
	await _open()
	Game.goto_scene(Game.SCENE_TITLE)
	await get_tree().process_frame
	assert_bool(NetworkSession.lobby.peer == null).is_true()
	assert_bool(NetworkSession.selecting_options).is_false()
	var options := await _open()
	NetworkSession.lobby.close()
	options.handle_action(TyrianControls.BACK)
	await _wait(func(): return Effects.current_game_scene().scene_file_path == "res://scenes/network_lobby.tscn")
	assert_bool(NetworkSession.selecting_options).is_false()
	assert_int(NetworkSession.selected_episode).is_equal(0)
