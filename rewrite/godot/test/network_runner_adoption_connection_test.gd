## Reuse the load fixture and terminal harness; no live menu/scene automation.
extends "res://test/network_level_load_connection_test.gd"


func test_adoption_refuses_borrowed_views_and_stages_early_next_epoch_ready() -> void:
	var pair := await _terminal_pair(true)
	if pair.is_empty():
		return
	var peers: Array = pair[0]
	var views: Array = pair[1]
	var originals := [peers[0].simulation_for_view(), peers[1].simulation_for_view()]
	for peer in peers:
		peer.set("_campaign_cursor", LevelCandidateFixture.new())
	assert_bool(peers[0].propose_continuation()).is_true()
	await _wait_decision(func(): return peers[0].continuation_sequence() == 1 and peers[1].continuation_sequence() == 1)
	assert_bool(peers[0].adopt_next_level()).is_false()
	assert_bool(peers[0].prepare_next_level(1, "1234567890abcdef")).is_true()
	await _wait_decision(func(): return peers[0].next_level_loaded() and peers[1].next_level_loaded())
	assert_bool(peers[0].commit_next_level_load()).is_true()
	await _wait_decision(func(): return peers[1].next_level_load_committed())
	for peer in peers:
		assert_bool(peer.adopt_next_level()).is_false()
	var request: Dictionary = peers[0].next_level_request()
	views[0]._detach()
	assert_bool(peers[0].adopt_next_level()).is_true()
	assert_bool(is_instance_valid(originals[0])).is_false()
	assert_bool(is_instance_valid(originals[1])).is_true()
	assert_int(peers[0].ticks_executed()).is_equal(0)
	assert_int(peers[0].get("_pause").epoch).is_equal(3)
	assert_bool(peers[0].advance()).is_false()
	assert_bool(peers[0].capture_local(Policy.neutral_frame(1, request.configuration))).is_false()
	# Host Ready arrives while the guest still owns its ended level.
	var first := View.new()
	assert_bool(first.bind(peers[0])).is_true()
	add_child(first)
	_nodes.push_front(first)
	assert_str(first.get("_network_level_name")).is_equal("ASTEROID1")
	assert_bool(peers[0].mark_view_ready()).is_true()
	await _wait(func(): return peers[1].get("_pending_view_ready"))
	assert_bool(peers[1].views_ready()).is_true()  # Still the old view barrier.
	views[1]._detach()
	assert_bool(peers[1].adopt_next_level()).is_true()
	assert_bool(is_instance_valid(originals[1])).is_false()
	var second := View.new()
	assert_bool(second.bind(peers[1])).is_true()
	add_child(second)
	_nodes.push_front(second)
	assert_bool(peers[1].views_ready()).is_false()
	assert_bool(peers[1].mark_view_ready()).is_true()
	await _wait(func(): return peers[0].views_ready() and peers[1].views_ready())
	var current_views := [first, second]
	var stepping_deadline := Time.get_ticks_msec() + 10000
	while (
		(peers[0].ticks_executed() < 35 or peers[1].ticks_executed() < 35) and Time.get_ticks_msec() < stepping_deadline
	):
		await _step(peers, current_views, 35)
	assert_int(peers[0].ticks_executed()).is_equal(35)
	assert_int(peers[1].ticks_executed()).is_equal(35)
	assert_str(peers[0].diagnostic_digest()).is_equal(peers[1].diagnostic_digest())
	assert_bool(peers[1].request_pause()).is_true()
	var deadline := Time.get_ticks_msec() + 10000
	while not (peers[0].pause_confirmed() and peers[1].pause_confirmed()) and Time.get_ticks_msec() < deadline:
		await _step(peers, current_views)
	assert_bool(peers[0].pause_confirmed()).is_true()
	assert_bool(peers[1].pause_confirmed()).is_true()
	assert_bool(peers[0].request_resume()).is_true()
	await _wait(func(): return not peers[0].inputs_quiesced() and not peers[1].inputs_quiesced())
	assert_int(peers[0].get("_pause").epoch).is_equal(4)
	assert_int(peers[1].get("_pause").epoch).is_equal(4)
	var before: String = peers[1].diagnostic_digest()
	# A delayed old-epoch result must be discarded even after the new barrier.
	peers[1]._receive_input(
		Wire.encode(
			{
				"kind": Wire.Kind.LEVEL_RESULT,
				"session": "94".repeat(16),
				"epoch": 2,
				"player": 1,
				"tick": 100,
				"sequence": 0,
				"digest": "ff".repeat(32),
				"elapsed": 0
			}
		)
	)
	assert_str(peers[1].diagnostic_digest()).is_equal(before)
	assert_bool(peers[1].running()).is_true()
