extends GdUnitTestSuite

const Preview := preload("res://scripts/network_preview_connection.gd")
const Fixture := preload("res://test/fixtures/network_setup.gd")
const Rules := preload("res://scripts/network_initial_configuration.gd")
const Lobby := preload("res://scripts/lan_lobby.gd")
var _nodes: Array[Node] = []


func after_test() -> void:
	for index in range(_nodes.size() - 1, -1, -1):
		_nodes[index].free()
	_nodes.clear()
	await get_tree().process_frame
	await get_tree().process_frame


func after() -> void:
	Music.release_streams()
	Sfx.release_streams()
	await get_tree().process_frame
	await get_tree().process_frame


func _wait(condition: Callable) -> void:
	var deadline := Time.get_ticks_msec() + 5000
	while not condition.call() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	assert_bool(condition.call()).is_true()


func _node() -> Node:
	var node := Preview.new()
	add_child(node)
	_nodes.append(node)
	return node


func _pair() -> Array:
	var host := _node()
	var guest := _node()
	assert_int(host.host(Game.data_dir, PackedStringArray(), {}, 1, 27736)).is_equal(OK)
	assert_int(guest.join("127.0.0.1", Game.data_dir, PackedStringArray(), {}, 1, 27736)).is_equal(OK)
	await _wait(func(): return host.compatible() and guest.compatible())
	return [host, guest]


func _config() -> Dictionary:
	var config := Fixture.configuration()
	var rules := Rules.new(Game.data_dir)
	config.level_file = rules.first_level(1, 2).lvl_file_num
	return config


func test_real_connections_compare_actual_previews_but_preserve_shop_and_game_state() -> void:
	var episode: int = Game.episode
	var active: bool = Game.campaign_active
	var peers := await _pair()
	assert_bool(peers[0].compare_preview()).is_false()
	assert_bool(peers[0].propose(_config(), "37".repeat(16), 1)).is_true()
	await _wait(func(): return peers[0].agreed() and peers[1].agreed())
	assert_bool(peers[0].compare_preview()).is_true()
	assert_bool(peers[1].compare_preview()).is_true()
	await _wait(func(): return peers[0].preview_matched() and peers[1].preview_matched())
	assert_str(peers[0].preview_digest()).is_equal(peers[1].preview_digest())
	assert_int(peers[0].preview_digest().length()).is_equal(64)
	assert_str(peers[0].entry().stop).is_equal("shop")
	assert_bool(peers[0].has_method("confirm_ready")).is_false()
	assert_bool(peers[0].has_method("start")).is_false()
	assert_int(Game.episode).is_equal(episode)
	assert_bool(Game.campaign_active).is_equal(active)
	var guest_context: RefCounted = peers[1].get("_preparation")
	var guest_preview: Node = guest_context.get("_preview")
	peers[1].stop()
	assert_bool(is_instance_valid(guest_preview)).is_false()
	await _wait(func(): return not peers[0].error.is_empty())
	assert_str(peers[0].preview_digest()).is_empty()
	assert_bool(peers[0].get("_connection").transport.peer == null).is_true()


func test_invalid_initial_proposal_closes_transport_and_releases_context() -> void:
	var peers := await _pair()
	var config := _config()
	config.cash2 = "0000000000000001"
	assert_bool(peers[0].propose(config, "38".repeat(16), 1)).is_false()
	await _wait(func(): return not peers[0].error.is_empty() and not peers[1].error.is_empty())
	assert_bool(peers[0].get("_connection").transport.peer == null).is_true()
	assert_bool(peers[1].get("_connection").transport.peer == null).is_true()
	assert_bool(peers[0].get("_preparation").identity().is_empty()).is_true()


func test_changed_preview_and_node_exit_release_native_nodes_and_socket() -> void:
	var peers := await _pair()
	assert_bool(peers[0].propose(_config(), "39".repeat(16), 1)).is_true()
	await _wait(func(): return peers[0].agreed() and peers[1].agreed())
	assert_bool(peers[0].compare_preview()).is_true()
	var context: RefCounted = peers[0].get("_preparation")
	var native: Node = context.get("_preview")
	native.step(0, 0)
	assert_bool(peers[0].compare_preview()).is_false()
	assert_str(peers[0].error).is_equal("preview_state_changed")
	assert_bool(is_instance_valid(native)).is_false()
	peers[1].get_parent().remove_child(peers[1])
	assert_bool(peers[1].get("_connection").transport.peer == null).is_true()


func test_cancel_from_state_callback_cannot_report_a_successful_proposal() -> void:
	var peers := await _pair()
	peers[0].changed.connect(
		func():
			var startup: RefCounted = peers[0].get("_connection").startup
			if startup != null and startup.phase == 2:
				peers[0].stop()
	)
	assert_bool(peers[0].propose(_config(), "40".repeat(16), 1)).is_false()
	assert_bool(peers[0].get("_connection").transport.peer == null).is_true()


func test_persistent_lobby_peer_is_adopted_and_guest_accepts_later_episode_choice() -> void:
	var host_lobby := Lobby.new()
	var guest_lobby := Lobby.new()
	add_child(host_lobby)
	add_child(guest_lobby)
	_nodes.append_array([host_lobby, guest_lobby])
	assert_int(host_lobby.host(27736)).is_equal(OK)
	var peer: ENetMultiplayerPeer = host_lobby.peer
	var parent: Node = host_lobby.get_parent()
	var host := _node()
	var guest := _node()
	assert_int(host.adopt_lobby(host_lobby, Game.data_dir, PackedStringArray(), {}, 1)).is_equal(OK)
	assert_object(host_lobby.peer).is_same(peer)
	assert_object(host_lobby.get_parent()).is_same(parent)
	assert_int(guest.adopt_lobby(guest_lobby, Game.data_dir, PackedStringArray(), {}, 1)).is_equal(OK)
	assert_int(guest_lobby.join("127.0.0.1", 27736)).is_equal(OK)
	await _wait(func(): return host.compatible() and guest.compatible())
	var config := _config()
	config.episode = 3
	config.level_file = Rules.new(Game.data_dir).first_level(3, 2).lvl_file_num
	assert_bool(host.propose(config, "41".repeat(16), 1)).is_true()
	await _wait(func(): return host.agreed() and guest.agreed())
	assert_int(guest.get("_preparation").configuration().episode).is_equal(3)
	assert_bool(host.compare_preview()).is_true()
	assert_bool(guest.compare_preview()).is_true()
	await _wait(func(): return host.preview_matched() and guest.preview_matched())
	assert_str(host.preview_digest()).is_equal(guest.preview_digest())
	host.stop()
	assert_bool(is_instance_valid(host_lobby)).is_true()
	assert_bool(host_lobby.peer == null).is_true()
