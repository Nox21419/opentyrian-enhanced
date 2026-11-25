## Inherits the terminal ENet harness. This controlled level-stop candidate tests
## native loading/transport, not a naturally won campaign or live scene adoption.
extends "res://test/network_continuation_connection_test.gd"


class LevelCandidateFixture:
	extends RefCounted
	var error := ""
	var _proposal := {}

	func completed(record: Dictionary) -> Dictionary:
		if _proposal.is_empty():
			var campaign: RefCounted = ClassDB.instantiate("TyrianCampaign")
			_proposal = {
				"format_version": 1,
				"sequence": 1,
				"source_result": record.digest,
				"source_configuration": record.config,
				"kind": "level",
				"episode": 1,
				"initial_difficulty": 2,
				"network_difficulty":
				campaign.adjust_network_two_player_difficulty(
					3,
					2,
					CursorBuilder.unsigned_cash(record.stats.cash),
					CursorBuilder.unsigned_cash(record.stats.cash2)
				),
				"earned": record.stats.duplicate(true),
				"requires_loader_adaptation": true,
				"difficulty_rule_review_required": false,
				"script": {"stop": "level", "section": 6, "lvl_file_num": 1, "bonus": false, "normal_bonus": false}
			}
			_proposal["digest"] = CursorBuilder.proposal_digest(_proposal)
		return _proposal.duplicate(true)


func test_load_barrier_over_enet_keeps_old_views_until_explicit_future_adoption() -> void:
	var pair := await _terminal_pair(true)
	if pair.is_empty():
		return
	var peers: Array = pair[0]
	var old_nodes := [peers[0].simulation_for_view(), peers[1].simulation_for_view()]
	var old_digest: String = peers[0].diagnostic_digest()
	var old_tick: int = peers[0].ticks_executed()
	for peer in peers:
		peer.set("_campaign_cursor", LevelCandidateFixture.new())
	assert_bool(peers[0].prepare_next_level(1, "1234567890abcdef")).is_false()
	assert_bool(peers[0].propose_continuation()).is_true()
	await _wait_decision(func(): return peers[0].continuation_sequence() == 1 and peers[1].continuation_sequence() == 1)
	assert_bool(peers[1].prepare_next_level(1, "1234567890abcdef")).is_false()
	assert_bool(peers[0].commit_next_level_load()).is_false()
	assert_bool(peers[0].prepare_next_level(1, "1234567890abcdef")).is_true()
	await _wait_decision(func(): return peers[0].next_level_loaded() and peers[1].next_level_loaded())
	assert_dict(peers[0].next_level_request()).is_equal(peers[1].next_level_request())
	var pending_nodes := []
	for i in 2:
		var context: RefCounted = peers[i].get("_pending_preparation")
		var native: Node = context.get("_preview")
		pending_nodes.append(native)
		assert_int(native.tick()).is_equal(0)
		assert_int(peers[i].get("_level_load").next_epoch).is_equal(3)
		assert_int(peers[i].ticks_executed()).is_equal(old_tick)
		assert_object(peers[i].simulation_for_view()).is_same(old_nodes[i])
		assert_str(peers[i].diagnostic_digest()).is_equal(old_digest)
		assert_bool(peers[i].advance()).is_false()
		assert_bool(peers[i].next_level_load_committed()).is_false()
	assert_bool(peers[0].commit_next_level_load()).is_true()
	await _wait_decision(func(): return peers[1].next_level_load_committed())
	var request: Dictionary = peers[1].next_level_request()
	request.carry[0] = 999
	assert_int(peers[1].next_level_request().carry[0]).is_not_equal(999)
	var verifications: int = peers[1].verification_calls
	var load: RefCounted = peers[0].get("_level_load")
	for duplicate in 3:
		peers[1]._receive_input(Wire.encode(load._message(Wire.Kind.LOAD_ACTIVATE, load.get("_local"))))
	assert_int(peers[1].verification_calls).is_equal(verifications)
	assert_bool(peers[1].next_level_load_committed()).is_true()
	# Stale seed from before pause/resume cannot replace the agreed load.
	var stale: Dictionary = load._message(Wire.Kind.LOAD_SEED, "ffffffffffffffff")
	stale.epoch = 1
	peers[1]._receive_input(Wire.encode(stale))
	assert_str(peers[1].next_level_request().configuration.seed).is_equal("1234567890abcdef")
	assert_str(peers[1].diagnostic_digest()).is_equal(old_digest)
	# Every explicit activation rechecks the pending preview. Mutation fails
	# closed and releases it instead of authorizing a changed tick-zero state.
	pending_nodes[0].step(0, 0)
	assert_bool(peers[0].commit_next_level_load()).is_false()
	assert_str(peers[0].error).is_equal("preview_state_changed")
	await _wait_decision(func(): return not peers[1].running())
	for i in 2:
		assert_bool(is_instance_valid(pending_nodes[i])).is_false()
		assert_dict(peers[i].next_level_request()).is_empty()
		assert_object(pair[1][i].sim).is_null()
