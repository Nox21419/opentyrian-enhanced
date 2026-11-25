extends GdUnitTestSuite

const Connection := preload("res://scripts/network_gameplay_connection.gd")
const Fixture := preload("res://test/fixtures/network_setup.gd")
const Wire := preload("res://scripts/network_protocol.gd")
const View := preload("res://scripts/network_level.gd")
var _nodes: Array[Node] = []


func after_test() -> void:
	for node in _nodes:
		node.free()
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
	var node := Connection.new()
	add_child(node)
	_nodes.append(node)
	return node


func _pair() -> Array:
	var host := _node()
	var guest := _node()
	assert_int(host.host(Game.data_dir, PackedStringArray(), {}, 1, 27737)).is_equal(OK)
	assert_int(guest.join("127.0.0.1", Game.data_dir, PackedStringArray(), {}, 1, 27737)).is_equal(OK)
	await _wait(func(): return host.compatible() and guest.compatible())
	assert_bool(host.start()).is_false()
	assert_bool(host.confirm_ready()).is_false()
	assert_object(host.simulation_for_view()).is_null()
	assert_int(guest.player_for_view()).is_equal(0)
	assert_bool(host.propose(Fixture.configuration(), "61".repeat(16), 1)).is_true()
	await _wait(func(): return host.agreed() and guest.agreed())
	assert_bool(host.compare_preview()).is_true()
	assert_bool(guest.compare_preview()).is_true()
	await _wait(func(): return host.preview_matched() and guest.preview_matched())
	assert_bool(host.start()).is_false()
	assert_bool(host.confirm_ready()).is_true()
	assert_bool(host.confirm_ready()).is_true()
	assert_bool(host.start()).is_false()
	assert_bool(guest.confirm_ready()).is_true()
	await _wait(
		func():
			return (
				host.get("_connection").startup.get("_remote_ready")
				and guest.get("_connection").startup.get("_remote_ready")
			)
	)
	assert_bool(guest.start()).is_false()
	assert_bool(host.start()).is_true()
	await _wait(func(): return host.running() and guest.running())
	return [host, guest]


func test_original_two_player_views_borrow_tick_zero_without_changing_campaign() -> void:
	var saved := {}
	for key in ["episode", "lvl_file_num", "level_name", "loadout", "level_start_ms", "campaign_active", "modes"]:
		saved[key] = Game.get(key)
	var peers := await _pair()
	var views: Array[Node] = []
	for i in 2:
		var native: Node = peers[i].simulation_for_view()
		var view := View.new()
		assert_bool(view.bind(peers[i])).is_true()
		assert_bool(view.bind(peers[i])).is_false()
		assert_bool(view.present_network_tick()).is_false()
		assert_int(view.player).is_equal(i + 1)
		add_child(view)
		views.append(view)
		assert_object(view.sim).is_same(native)
		assert_object(native.get_parent()).is_null()
		assert_int(native.tick()).is_equal(0)
		assert_bool(view.is_physics_processing()).is_false()
		assert_object(view.get("_hud_vga")).is_not_null()
		assert_int(native.hud_state()[HudRenderer.TWO_PLAYER]).is_equal(1)
		view.step_sim(Game.MASK_FIRE)
		view.advance(10, func(_tick: int): return Game.MASK_FIRE)
		assert_int(native.tick()).is_equal(0)
		assert_bool(view.present_network_tick()).is_false()
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--network-view-shots="):
				var dir := arg.trim_prefix("--network-view-shots=")
				DirAccess.make_dir_recursive_absolute(dir)
				var image: Image = view.get("_hud_vga").vga.image(0)
				assert_int(image.save_png(dir.path_join("network-hud-%d.png" % (i + 1)))).is_equal(OK)
	await get_tree().physics_frame
	for i in 2:
		assert_int(peers[i].ticks_executed()).is_equal(0)
		assert_int(peers[i].simulation_for_view().tick()).is_equal(0)
	for key in saved:
		assert_bool(Game.get(key) == saved[key]).override_failure_message(key).is_true()
	# Freeing a view never frees its borrowed native node.
	var native: Node = peers[0].simulation_for_view()
	views[0].free()
	assert_bool(is_instance_valid(native)).is_true()
	assert_bool(peers[0].running()).is_true()
	# Stopping the other owner invalidates and hides its still-alive view.
	peers[1].stop()
	assert_object(views[1].sim).is_null()
	assert_bool(views[1].visible).is_false()
	assert_bool(views[1].present_network_tick()).is_false()
	views[1].free()


func test_rendered_peers_present_each_backend_tick_once_and_keep_matching_state() -> void:
	var peers := await _pair()
	var views: Array[Node] = []
	for peer in peers:
		var view := View.new()
		assert_bool(view.bind(peer)).is_true()
		add_child(view)
		views.append(view)
	var digests: Array[Dictionary] = [{}, {}]
	for _clock in 1000:
		for i in 2:
			if peers[i].ticks_executed() >= 12:
				continue
			if peers[i].needs_local_input():
				assert_bool(peers[i].capture_local(Wire.neutral_frame())).is_true()
			if peers[i].advance():
				assert_bool(views[i].present_network_tick()).is_true()
				assert_bool(views[i].present_network_tick()).is_false()
				digests[i][peers[i].ticks_executed()] = peers[i].diagnostic_digest()
		if peers[0].ticks_executed() == 12 and peers[1].ticks_executed() == 12:
			break
		await get_tree().process_frame
	assert_int(digests[0].size()).is_equal(12)
	assert_dict(digests[0]).is_equal(digests[1])
	for view in views:
		view.free()


func test_real_enet_inputs_advance_identical_native_simulations_after_explicit_start() -> void:
	var episode: int = Game.episode
	var active: bool = Game.campaign_active
	var peers := await _pair()
	var digests: Array[Dictionary] = [{}, {}]
	for _clock in 2000:
		for i in 2:
			if peers[i].ticks_executed() < 60 and peers[i].needs_local_input():
				var frame := Wire.neutral_frame()
				frame.mouse_mask = 16
				frame.mouse_dx = -8 if i == 0 else 8
				frame.new_key = peers[i].ticks_executed() == 20
				assert_bool(peers[i].capture_local(frame)).is_true()
			if peers[i].ticks_executed() < 60 and peers[i].advance():
				digests[i][peers[i].ticks_executed()] = peers[i].diagnostic_digest()
			assert_str(peers[i].error).is_empty()
		if peers[0].ticks_executed() == 60 and peers[1].ticks_executed() == 60:
			break
		await get_tree().process_frame
	assert_int(peers[0].ticks_executed()).is_equal(60)
	assert_int(peers[1].ticks_executed()).is_equal(60)
	assert_dict(digests[0]).is_equal(digests[1])
	assert_int(Game.episode).is_equal(episode)
	assert_bool(Game.campaign_active).is_equal(active)
	var context: RefCounted = peers[0].get("_preparation")
	var native: Node = context.get("_preview")
	peers[1].stop()
	await _wait(func(): return not peers[0].running())
	assert_bool(is_instance_valid(native)).is_false()
	assert_str(peers[0].diagnostic_digest()).is_empty()


func test_malformed_gameplay_input_closes_and_frees_both_session_simulations() -> void:
	var peers := await _pair()
	var context: RefCounted = peers[0].get("_preparation")
	var native: Node = context.get("_preview")
	var frame := Wire.neutral_frame()
	frame.mouse_dx = Wire.MAX_I32
	var packet := Wire.encode(
		{
			"kind": Wire.Kind.INPUT,
			"session": "61".repeat(16),
			"epoch": 1,
			"player": 2,
			"tick": 3,
			"sequence": 0,
			"frame": frame
		}
	)
	assert_int(peers[1].get("_connection").transport.send_packet(packet)).is_equal(OK)
	await _wait(func(): return not peers[0].running() and not peers[1].running())
	assert_str(peers[0].error).is_equal("invalid_remote_input")
	assert_bool(is_instance_valid(native)).is_false()
	assert_bool(peers[0].get("_connection").transport.peer == null).is_true()
