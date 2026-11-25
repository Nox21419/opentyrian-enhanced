extends GdUnitTestSuite

const Connection := preload("res://scripts/network_gameplay_connection.gd")
const View := preload("res://scripts/network_level.gd")
const Policy := preload("res://scripts/network_touch_inputs.gd")
const Wire := preload("res://scripts/network_protocol.gd")
const Fixture := preload("res://test/fixtures/network_setup.gd")
var _nodes: Array[Node] = []


func after_test() -> void:
	for node in _nodes:
		if is_instance_valid(node):
			node.free()
	_nodes.clear()
	Music.release_streams()
	Sfx.release_streams()
	await get_tree().process_frame
	await get_tree().process_frame


func _wait(condition: Callable) -> void:
	var deadline := Time.get_ticks_msec() + 10000
	while not condition.call() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	assert_bool(condition.call()).is_true()


func _pair() -> Array:
	var peers := [Connection.new(), Connection.new()]
	for peer in peers:
		add_child(peer)
		_nodes.append(peer)
	assert_int(peers[0].host(Game.data_dir, PackedStringArray(), {}, 1, 27745)).is_equal(OK)
	assert_int(peers[1].join("127.0.0.1", Game.data_dir, PackedStringArray(), {}, 1, 27745)).is_equal(OK)
	await _wait(func(): return peers[0].compatible() and peers[1].compatible())
	assert_bool(peers[0].propose(Fixture.configuration(), "94".repeat(16), 1)).is_true()
	await _wait(func(): return peers[0].agreed() and peers[1].agreed())
	for peer in peers:
		assert_bool(peer.compare_preview()).is_true()
	await _wait(func(): return peers[0].preview_matched() and peers[1].preview_matched())
	for peer in peers:
		assert_bool(peer.confirm_ready()).is_true()
	await _wait(func(): return peers[0].readiness().remote and peers[1].readiness().remote)
	assert_bool(peers[0].start()).is_true()
	await _wait(func(): return peers[0].running() and peers[1].running())
	var views: Array[Node] = []
	for peer in peers:
		var view := View.new()
		assert_bool(view.bind(peer)).is_true()
		add_child(view)
		_nodes.push_front(view)  # Views must detach before their native owners free.
		views.append(view)
		assert_bool(peer.mark_view_ready()).is_true()
	await _wait(func(): return peers[0].views_ready() and peers[1].views_ready())
	return [peers, views]


func _step(peers: Array, views: Array, limit := Wire.MAX_TICK, hold_guest_at_host_end := false) -> void:
	for i in 2:
		if i == 1 and hold_guest_at_host_end and peers[0].simulation_for_view().level_ended():
			continue
		if peers[i].ticks_executed() >= limit:
			continue
		if peers[i].pause_boundary_reached():
			assert_bool(peers[i].note_pause_boundary()).is_true()
			continue
		if peers[i].needs_local_input():
			var frame := Policy.neutral_frame(i + 1, Fixture.configuration())
			# Original GAME OVER waits for a key. Acknowledge through the same
			# delayed input protocol, never by mutating/forcing native level end.
			frame.new_key = views[i]._game_over_shown()
			assert_bool(peers[i].capture_local(frame)).is_true()
		if peers[i].advance():
			assert_bool(views[i].present_network_tick()).is_true()
	await get_tree().process_frame


func _finish(peers: Array, views: Array, early_host_report := false) -> bool:
	var deadline := Time.get_ticks_msec() + 60000
	var reported := false
	while Time.get_ticks_msec() < deadline:
		if early_host_report and not reported and peers[0].simulation_for_view().level_ended():
			assert_int(peers[1].ticks_executed()).is_less(peers[0].ticks_executed())
			assert_bool(peers[0].note_level_result(peers[0].ticks_executed(), "TYRIAN", 125)).is_true()
			await _wait(func(): return peers[1].get("_completion").active())
			assert_bool(peers[1].get("_completion").local_reached()).is_false()
			reported = true
		if peers[0].simulation_for_view().level_ended() and peers[1].simulation_for_view().level_ended():
			break
		await _step(peers, views, Wire.MAX_TICK, early_host_report and not reported)
	var ended: bool = peers[0].simulation_for_view().level_ended() and peers[1].simulation_for_view().level_ended()
	(
		assert_bool(ended)
		. override_failure_message(
			"No natural end at ticks %s / %s" % [peers[0].ticks_executed(), peers[1].ticks_executed()]
		)
		. is_true()
	)
	if not ended:
		return false
	assert_int(peers[0].ticks_executed()).is_equal(peers[1].ticks_executed())
	assert_str(peers[0].diagnostic_digest()).is_equal(peers[1].diagnostic_digest())
	return true


func test_natural_final_result_and_screen_controls_after_pause_resume_use_current_epoch() -> void:
	var pair := await _pair()
	var peers: Array = pair[0]
	var views: Array = pair[1]
	while peers[0].ticks_executed() < 8 or peers[1].ticks_executed() < 8:
		await _step(peers, views, 8)
	assert_bool(peers[1].request_pause()).is_true()
	var deadline := Time.get_ticks_msec() + 10000
	while not (peers[0].pause_confirmed() and peers[1].pause_confirmed()) and Time.get_ticks_msec() < deadline:
		await _step(peers, views)
	assert_bool(peers[0].pause_confirmed() and peers[1].pause_confirmed()).is_true()
	assert_bool(peers[0].request_resume()).is_true()
	await _wait(func(): return not peers[0].inputs_quiesced() and not peers[1].inputs_quiesced())
	if not await _finish(peers, views, true):
		return
	var tick: int = peers[0].ticks_executed()
	var digest: String = peers[0].diagnostic_digest()
	assert_bool(peers[0].note_level_result(tick, "TYRIAN", 125)).is_true()
	assert_bool(peers[1].note_level_result(tick, "TYRIAN", 0)).is_true()
	await _wait(func(): return peers[0].completion_agreed() and peers[1].completion_agreed())
	assert_int(peers[0].get("_completion").epoch).is_equal(2)
	assert_int(peers[1].get("_completion").epoch).is_equal(2)
	for peer in peers:
		assert_int(peer.result_elapsed_seconds()).is_equal(125)
		assert_bool(peer.advance()).is_false()
		assert_bool(peer.needs_local_input()).is_false()
		assert_bool(peer.request_pause()).is_false()
		assert_str(peer.diagnostic_digest()).is_equal(digest)
	assert_str(peers[0].result_for_view().record().digest).is_equal(peers[1].result_for_view().record().digest)
	# Valid stale completion traffic from the pre-pause epoch is ignored.
	peers[1]._receive_input(
		Wire.encode(
			{
				"kind": Wire.Kind.LEVEL_RESULT,
				"session": "94".repeat(16),
				"epoch": 1,
				"player": 1,
				"tick": tick,
				"sequence": 0,
				"digest": "ab".repeat(32),
				"elapsed": 0
			}
		)
	)
	assert_str(peers[1].error).is_empty()
	for stage in [1, 2]:
		assert_bool(peers[0].mark_result_screen_ready(stage)).is_true()
		assert_bool(peers[0].request_result_advance(stage)).is_true()
		assert_bool(peers[1].request_result_advance(stage)).is_false()
		assert_int(peers[0].result_committed_phase()).is_equal(stage - 1)
		assert_bool(peers[1].mark_result_screen_ready(stage)).is_true()
		await _wait(
			func(): return peers[0].result_committed_phase() == stage and peers[1].result_committed_phase() == stage
		)
		for peer in peers:
			assert_int(peer.ticks_executed()).is_equal(tick)
			assert_str(peer.diagnostic_digest()).is_equal(digest)
	peers[1].stop()
	await _wait(func(): return not peers[0].running())
	assert_object(peers[0].result_for_view()).is_null()
	assert_object(views[0].sim).is_null()


func test_different_final_result_records_fail_closed_over_enet() -> void:
	var pair := await _pair()
	var peers: Array = pair[0]
	if not await _finish(peers, pair[1]):
		return
	var tick: int = peers[0].ticks_executed()
	assert_bool(peers[0].note_level_result(tick, "TYRIAN", 20)).is_true()
	assert_bool(peers[1].note_level_result(tick, "OTHER", 0)).is_true()
	await _wait(func(): return not peers[0].running() and not peers[1].running())
	assert_bool(peers[0].completion_agreed()).is_false()
	assert_bool(peers[1].completion_agreed()).is_false()
	assert_object(peers[0].result_for_view()).is_null()
