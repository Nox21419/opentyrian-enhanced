extends GdUnitTestSuite

const NG := preload("res://scripts/new_game.gd")
const LOBBY := "res://scenes/network_lobby.tscn"
var _original_episode := 1
var _original_campaign := false


func before_test() -> void:
	_original_episode = Game.episode
	_original_campaign = Game.campaign_active
	Game.campaign_active = false
	NetworkSession.stop()


func after_test() -> void:
	for child in Effects.game_viewport.get_children():
		child.queue_free()
		Effects.game_viewport.remove_child(child)
	await get_tree().process_frame
	await get_tree().process_frame
	NetworkSession.stop()
	NG.flow = NG.Flow.NEW_GAME
	Game.episode = _original_episode
	Game.campaign_active = _original_campaign
	TyrianMouse.inactive = true


func after() -> void:
	Music.release_streams()
	Sfx.release_streams()


func _wait(condition: Callable) -> void:
	var deadline := Time.get_ticks_msec() + 4000
	while not condition.call() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	assert_bool(condition.call()).is_true()


func _host_lobby() -> Node:
	var lobby: Node = Game.goto_scene(LOBBY)
	await _wait(func(): return lobby.idle)
	lobby._activate(0)
	assert_bool(lobby.session.hosting).is_true()
	assert_str(lobby._row_label(1)).is_equal(TyrianText.L("net_choose_episode"))
	return lobby


func _open_episode(lobby: Node) -> Node:
	lobby._activate(1)
	await _wait(
		func():
			return (
				Effects.current_game_scene().scene_file_path == Game.SCENE_NEW_GAME
				and Effects.current_game_scene().idle
				and not Effects.current_game_scene().get("_busy")
			)
	)
	var episode: Node = Effects.current_game_scene()
	assert_str(episode.current_screen).is_equal("episode")
	assert_int(NG.flow).is_equal(NG.Flow.NEW_GAME)
	return episode


func test_episode_choice_returns_to_same_host_connection_without_starting_game() -> void:
	var lobby := await _host_lobby()
	var transport_id: int = lobby.session.get_instance_id()
	var peer: ENetMultiplayerPeer = lobby.session.peer
	var original: int = Game.episode
	var episode := await _open_episode(lobby)
	episode.set("_touch_episode", true)
	await episode._open_episode()
	var event := InputEventMouseButton.new()
	event.position = Vector2(25, 112)
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	episode.handle_mouse(event)
	assert_int(NetworkSession.selected_episode).is_equal(0)
	event.pressed = false
	episode.handle_mouse(event)
	await _wait(
		func(): return Effects.current_game_scene().scene_file_path == LOBBY and Effects.current_game_scene().idle
	)
	lobby = Effects.current_game_scene()
	assert_int(NetworkSession.selected_episode).is_equal(3)
	assert_int(lobby.session.get_instance_id()).is_equal(transport_id)
	assert_object(lobby.session.peer).is_same(peer)
	assert_bool(lobby.session.hosting).is_true()
	assert_int(Game.episode).is_equal(original)
	assert_bool(Game.campaign_active).is_false()
	# The selected row is restored on reopening this one host screen.
	episode = await _open_episode(lobby)
	assert_int(episode.menus.selection()).is_equal(2)


func test_back_preserves_host_but_leaving_lobby_releases_it_and_clears_selection() -> void:
	var lobby := await _host_lobby()
	var episode := await _open_episode(lobby)
	episode.handle_action(TyrianControls.BACK)
	await _wait(
		func(): return Effects.current_game_scene().scene_file_path == LOBBY and Effects.current_game_scene().idle
	)
	lobby = Effects.current_game_scene()
	assert_bool(lobby.session.hosting).is_true()
	assert_int(NetworkSession.selected_episode).is_equal(0)
	lobby.handle_action(TyrianControls.BACK)
	assert_bool(NetworkSession.lobby.peer == null).is_true()
	await _wait(func(): return Effects.current_game_scene().scene_file_path == Game.SCENE_NEW_GAME)


func test_unexpected_scene_exit_cannot_leave_a_host_socket_running() -> void:
	var lobby := await _host_lobby()
	await _open_episode(lobby)
	Game.goto_scene(Game.SCENE_TITLE)
	await get_tree().process_frame
	assert_bool(NetworkSession.lobby.peer == null).is_true()
	assert_bool(NetworkSession.selecting_episode).is_false()
