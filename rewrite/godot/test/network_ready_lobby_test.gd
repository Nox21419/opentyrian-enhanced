extends GdUnitTestSuite

const Gameplay := preload("res://scripts/network_gameplay_connection.gd")
const Fixture := preload("res://test/fixtures/network_setup.gd")
const Rules := preload("res://scripts/network_initial_configuration.gd")
const View := preload("res://scripts/network_level.gd")
const Clock := preload("res://scripts/network_tick_clock.gd")
const LOBBY := "res://scenes/network_lobby.tscn"
const PLAYER := "res://scenes/network_player.tscn"
var _guest: Node
var _game := {}
var _platform: Callable
var _rate: int


func before_test() -> void:
	_game = {}
	for key in ["episode", "lvl_file_num", "level_name", "campaign_active", "loadout", "modes", "level_start_ms"]:
		_game[key] = Game.get(key)
	NetworkSession.stop()
	_platform = NetworkSession.platform_name
	NetworkSession.platform_name = func(): return "Android"
	_rate = Engine.physics_ticks_per_second


func after_test() -> void:
	NetworkSession.stop()
	NetworkSession.platform_name = _platform
	Engine.physics_ticks_per_second = _rate
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


func test_host_menu_intent_negotiates_ready_then_hands_off_without_changing_local_campaign() -> void:
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
	await _play_player_and_leave(1, false)
	for key in _game:
		assert_bool(Game.get(key) == _game[key]).override_failure_message(key).is_true()
	assert_bool(NetworkSession.lobby.peer == null).is_true()
	await _wait(func(): return not _guest.running())
	assert_str(Effects.current_game_scene()._row_label(0)).is_equal(TyrianText.L("net_host"))


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
	config.game_speed = 5
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
	await _play_player_and_leave(2, true)
	assert_int(Game.episode).is_equal(_game.episode)


func _record_tick(tick: int, peer: Node, view: Node, digests: Dictionary) -> void:
	digests[tick] = peer.diagnostic_digest()
	if tick == 60:
		view.set_physics_process(false)


func _play_player_and_leave(role: int, focus_loss: bool) -> void:
	await _wait(func(): return Effects.current_game_scene().scene_file_path == PLAYER)
	var view := Effects.current_game_scene()
	assert_int(view.player).is_equal(role)
	var local: Node = NetworkSession.backend
	assert_int(Engine.physics_ticks_per_second).is_equal(Clock.ticks_per_second(local.configuration().game_speed))
	assert_int(local.ticks_executed()).is_equal(0)
	assert_bool(view.entry_pending()).is_true()
	await _wait(
		func(): return not is_instance_valid(NetworkSession.backend) or bool(NetworkSession.backend.get("_view_local"))
	)
	assert_bool(is_instance_valid(local)).override_failure_message(NetworkSession.last_player_exit).is_true()
	if not is_instance_valid(local):
		return
	assert_bool(local.views_ready()).is_false()
	assert_int(local.ticks_executed()).is_equal(0)
	for _frame in 4:
		await get_tree().physics_frame
	assert_int(local.ticks_executed()).is_equal(0)
	var remote: Node = auto_free(View.new())
	assert_bool(remote.bind(_guest)).is_true()
	remote.set("_touch_pause", true)
	add_child(remote)
	assert_bool(remote.enable_network_input()).is_true()
	var digests: Array[Dictionary] = [{}, {}]
	view.network_tick_presented.connect(_record_tick.bind(local, view, digests[0]))
	remote.network_tick_presented.connect(_record_tick.bind(_guest, remote, digests[1]))
	for screen in [view, remote]:
		var touch := InputEventScreenTouch.new()
		touch.index = 0
		touch.position = Vector2(90 if screen.player == 1 else 200, 110)
		touch.pressed = true
		screen._input(touch)
	assert_bool(_guest.mark_view_ready()).is_true()
	assert_bool(remote.enable_network_clock()).is_true()
	await _wait(func(): return digests[0].size() == 60 and digests[1].size() == 60)
	assert_dict(digests[0]).is_equal(digests[1])
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--network-player-shots="):
			var dir := arg.trim_prefix("--network-player-shots=")
			DirAccess.make_dir_recursive_absolute(dir)
			var hud: HudRenderer = view.get("_hud_vga")
			var image: Image = hud.vga.image(0)
			var playfield: Image = view.sim.playfield_background(Game.data_dir, hud.vga.palette_bytes())
			playfield.convert(image.get_format())
			image.blit_rect(playfield, Rect2i(0, 0, 264, 184), Vector2i.ZERO)
			assert_int(image.save_png(dir.path_join("network-player-%d.png" % role))).is_equal(OK)
	if focus_loss:
		view._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	else:
		var back := InputEventAction.new()
		back.action = "tyrian_level_exit"
		back.pressed = true
		view._unhandled_input(back)
	await _wait(func(): return Effects.current_game_scene().scene_file_path == LOBBY)
	assert_object(NetworkSession.backend).is_null()
	assert_int(Engine.physics_ticks_per_second).is_equal(_rate)


func test_cancelled_session_cannot_run_a_stale_player_handoff() -> void:
	var lobby: Node = Game.goto_scene(LOBBY)
	await _wait(func(): return lobby.idle)
	assert_int(NetworkSession.host()).is_equal(OK)
	var old_id: int = NetworkSession.backend.get_instance_id()
	NetworkSession.stop()
	NetworkSession._open_player(old_id)
	assert_object(Effects.current_game_scene()).is_same(lobby)
	assert_int(Engine.physics_ticks_per_second).is_equal(_rate)


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
			"connection_test",
			"setup_failed",
			"content_mismatch"
		]:
			assert_int(TyrianText.width(TyrianText.L("net_" + key, language), TyrianScreen.SMALL_FONT)).is_less_equal(
				288
			)
