extends GdUnitTestSuite

const Gameplay := preload("res://scripts/network_gameplay_connection.gd")
const Fixture := preload("res://test/fixtures/network_setup.gd")
const Rules := preload("res://scripts/network_initial_configuration.gd")
const LOBBY := "res://scenes/network_lobby.tscn"
var _guest: Node
var _game := {}


func before_test() -> void:
	_game = {"episode": Game.episode, "campaign_active": Game.campaign_active, "loadout": Game.loadout.duplicate()}
	NetworkSession.stop()


func after_test() -> void:
	NetworkSession.stop()
	if is_instance_valid(_guest):
		_guest.free()
	_guest = null
	for child in Effects.game_viewport.get_children():
		child.queue_free()
		Effects.game_viewport.remove_child(child)
	await get_tree().process_frame
	await get_tree().process_frame
	for key in _game:
		Game.set(key, _game[key])
	TyrianMouse.inactive = true


func after() -> void:
	Music.release_streams()
	Sfx.release_streams()
	await get_tree().process_frame
	await get_tree().process_frame


func _wait(condition: Callable) -> void:
	var deadline := Time.get_ticks_msec() + 12000
	while not condition.call() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	assert_bool(condition.call()).is_true()


func _shot(lobby: Node, name: String) -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--ready-lobby-shots="):
			var dir := arg.trim_prefix("--ready-lobby-shots=")
			DirAccess.make_dir_recursive_absolute(dir)
			var img: Image = lobby.vga.image(0)
			assert_int(img.save_png(dir.path_join(name + ".png"))).is_equal(OK)


func test_host_menu_intent_negotiates_later_episode_and_explicit_ready_without_starting_local_game() -> void:
	var lobby: Node = Game.goto_scene(LOBBY)
	await _wait(func(): return lobby.idle)
	lobby._activate(0)
	var peer: ENetMultiplayerPeer = NetworkSession.lobby.peer
	_guest = Gameplay.new()
	add_child(_guest)
	assert_int(_guest.join("127.0.0.1", Game.data_dir, Mods.dirs(), {}, 1)).is_equal(OK)
	await _wait(func(): return NetworkSession.backend.compatible() and _guest.compatible())
	assert_bool(NetworkSession.begin_episode_selection()).is_true()
	NetworkSession.choose_episode(3)
	NetworkSession.finish_difficulty_selection(4)
	assert_bool(NetworkSession.begin_arcade_menu()).is_true()
	NetworkSession.finish_arcade_menu()
	await _wait(func(): return _guest.agreed())
	assert_int(_guest.configuration().episode).is_equal(3)
	assert_int(_guest.configuration().initial_difficulty).is_equal(4)
	assert_bool(NetworkSession.begin_episode_selection()).is_false()
	assert_bool(_guest.compare_preview()).is_true()
	await _wait(func(): return NetworkSession.can_ready() and _guest.preview_matched())
	assert_object(NetworkSession.lobby.peer).is_same(peer)
	assert_str(lobby._row_label(0)).is_equal(TyrianText.L("net_ready"))
	assert_bool(NetworkSession.can_start()).is_false()
	_shot(lobby, "network-lobby-ready")
	lobby.set("_touch", true)
	var event := InputEventMouseButton.new()
	event.position = Vector2(160, 90)
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	lobby.handle_mouse(event)
	assert_bool(NetworkSession.local_ready()).is_false()
	event.pressed = false
	lobby.handle_mouse(event)
	assert_bool(NetworkSession.local_ready()).is_true()
	assert_bool(NetworkSession.can_start()).is_false()
	assert_str(lobby._row_label(0)).is_equal(TyrianText.L("net_start"))
	assert_bool(_guest.confirm_ready()).is_true()
	await _wait(func(): return NetworkSession.can_start())
	_shot(lobby, "network-lobby-start")
	lobby._activate(0)
	await _wait(func(): return NetworkSession.backend.running() and _guest.running())
	assert_str(NetworkSession.status_key()).is_equal("net_session_prepared")
	assert_int(NetworkSession.backend.ticks_executed()).is_equal(0)
	assert_str(Effects.current_game_scene().scene_file_path).is_equal(LOBBY)
	for key in _game:
		assert_bool(Game.get(key) == _game[key]).override_failure_message(key).is_true()
	lobby._activate(1)
	assert_bool(NetworkSession.lobby.peer == null).is_true()
	await _wait(func(): return not _guest.running())
	assert_str(lobby._row_label(0)).is_equal(TyrianText.L("net_host"))


func test_guest_lobby_receives_host_choices_and_never_exposes_host_start() -> void:
	_guest = Gameplay.new()
	add_child(_guest)
	assert_int(_guest.host(Game.data_dir, Mods.dirs(), {}, 1)).is_equal(OK)
	var lobby: Node = Game.goto_scene(LOBBY)
	await _wait(func(): return lobby.idle)
	assert_int(NetworkSession.join("127.0.0.1")).is_equal(OK)
	await _wait(func(): return NetworkSession.backend.compatible() and _guest.compatible())
	var config := Fixture.configuration()
	config.episode = 4
	config.level_file = Rules.new(Game.data_dir).first_level(4, 2).lvl_file_num
	assert_bool(_guest.propose(config, "81".repeat(16), 1)).is_true()
	await _wait(func(): return _guest.agreed())
	assert_bool(_guest.compare_preview()).is_true()
	await _wait(func(): return NetworkSession.can_ready() and _guest.preview_matched())
	assert_int(NetworkSession.selected_episode).is_equal(4)
	assert_int(NetworkSession.selected_difficulty).is_equal(2)
	assert_bool(NetworkSession.lobby.hosting).is_false()
	lobby._activate(0)
	assert_bool(_guest.confirm_ready()).is_true()
	await _wait(func(): return _guest.readiness().remote)
	assert_bool(NetworkSession.can_start()).is_false()
	assert_str(lobby._row_label(0)).is_equal(TyrianText.L("net_ready"))
	_shot(lobby, "network-lobby-guest")
	assert_bool(_guest.start()).is_true()
	await _wait(func(): return NetworkSession.backend.running())
	assert_int(Game.episode).is_equal(_game.episode)


func test_ready_labels_and_statuses_fit_original_fonts_in_all_languages() -> void:
	for language in ["en", "de", "es", "fr", "it", "pt"]:
		for key in ["ready", "start", "cancel"]:
			assert_int(TyrianText.width(TyrianText.L("net_" + key, language), TyrianScreen.NORMAL_FONT)).is_less_equal(
				288
			)
		for key in [
			"checking",
			"wait_host",
			"preparing",
			"ready_wait",
			"ready_prompt",
			"wait_start",
			"session_prepared",
			"setup_failed",
			"content_mismatch"
		]:
			assert_int(TyrianText.width(TyrianText.L("net_" + key, language), TyrianScreen.SMALL_FONT)).is_less_equal(
				288
			)
