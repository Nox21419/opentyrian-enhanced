## Reuse the native ENet pair/terminal presentation harness. Controlled shop
## candidates below exercise decision 2 without claiming a naturally won level.
extends "res://test/network_completion_connection_test.gd"

const CursorBuilder := preload("res://scripts/network_campaign_cursor.gd")


class CountedConnection:
	extends "res://scripts/network_gameplay_connection.gd"
	var verification_calls := 0

	func _verify_continuation_state() -> bool:
		verification_calls += 1
		return super._verify_continuation_state()


func _new_connection() -> Node:
	return CountedConnection.new()


class ShopCandidateFixture:
	extends RefCounted
	var error := ""
	var variant := 0
	var _proposal := {}

	func completed(record: Dictionary) -> Dictionary:
		if _proposal.is_empty():
			_proposal = {
				"sequence": 1,
				"source_result": record.digest,
				"source_configuration": record.config,
				"kind": "shop",
				"earned": record.stats.duplicate(true),
				"requires_loader_adaptation": true,
				"difficulty_rule_review_required": true,
				"script": {"stop": "shop", "section": 4, "map": PackedInt32Array([1, 5, 2, 6])},
				"fixture_route": variant
			}
			_proposal["digest"] = CursorBuilder.proposal_digest(_proposal)
		return _proposal.duplicate(true)

	func preview_arcade_start(parent: String) -> Dictionary:
		if _proposal.is_empty() or _proposal.digest != parent:
			error = "invalid_fixture_parent"
			return {}
		var preview := _proposal.duplicate(true)
		preview.erase("digest")
		preview["parent"] = parent
		preview["action"] = "arcade_start"
		preview.sequence = 2
		preview.kind = "level"
		preview["entry"] = preview.script.duplicate(true)
		preview.script = {"stop": "level", "section": 6, "lvl_file_num": 1}
		preview["digest"] = CursorBuilder.proposal_digest(preview)
		return preview


func _wait_decision(condition: Callable) -> void:
	var deadline := Time.get_ticks_msec() + 30000
	while not condition.call() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	assert_bool(condition.call()).is_true()


func _terminal_pair(resume := false) -> Array:
	var pair := await _pair()
	var peers: Array = pair[0]
	var views: Array = pair[1]
	assert_bool(peers[0].prepare_continuation()).is_false()
	assert_bool(peers[1].propose_continuation()).is_false()
	if resume:
		var entry_deadline := Time.get_ticks_msec() + 10000
		while peers[0].ticks_executed() < 8 or peers[1].ticks_executed() < 8:
			if not peers[0].running() or not peers[1].running() or Time.get_ticks_msec() >= entry_deadline:
				(
					assert_bool(false)
					. override_failure_message(
						"Pair failed before pause entry: %s / %s" % [peers[0].error, peers[1].error]
					)
					. is_true()
				)
				return []
			await _step(peers, views, 8)
		assert_bool(peers[1].request_pause()).is_true()
		var deadline := Time.get_ticks_msec() + 10000
		while not (peers[0].pause_confirmed() and peers[1].pause_confirmed()) and Time.get_ticks_msec() < deadline:
			await _step(peers, views)
		assert_bool(peers[0].request_resume()).is_true()
		await _wait(func(): return not peers[0].inputs_quiesced() and not peers[1].inputs_quiesced())
	if not await _finish(peers, views):
		return []
	var tick: int = peers[0].ticks_executed()
	assert_bool(peers[0].note_level_result(tick, "TYRIAN", 125)).is_true()
	assert_bool(peers[1].note_level_result(tick, "TYRIAN", 0)).is_true()
	await _wait(func(): return peers[0].completion_agreed() and peers[1].completion_agreed())
	assert_bool(peers[0].prepare_continuation()).is_false()  # No proposal before both fades.
	for stage in [1, 2, 3]:
		for peer in peers:
			assert_bool(peer.mark_result_screen_ready(stage)).is_true()
		assert_bool(peers[0].request_result_advance(stage)).is_true()
		await _wait(
			func(): return peers[0].result_committed_phase() == stage and peers[1].result_committed_phase() == stage
		)
	return pair


func test_real_retry_proposal_agrees_after_fades_in_current_epoch_and_checks_agreed_record() -> void:
	var pair := await _terminal_pair(true)
	if pair.is_empty():
		return
	var peers: Array = pair[0]
	var originals := [peers[0].simulation_for_view(), peers[1].simulation_for_view()]
	var digest: String = peers[0].diagnostic_digest()
	assert_object(peers[1].get("_campaign_cursor")).is_null()
	assert_bool(peers[0].propose_continuation()).is_true()
	await _wait_decision(func(): return peers[0].continuation_sequence() == 1 and peers[1].continuation_sequence() == 1)
	var proposal: Dictionary = peers[0].committed_continuation()
	assert_dict(proposal).is_equal(peers[1].committed_continuation())
	assert_str(proposal.kind).is_equal("retry_required")
	assert_bool(proposal.requires_loader_adaptation).is_true()
	assert_int(peers[0].get("_continuation").epoch).is_equal(2)
	assert_int(peers[1].get("_continuation").epoch).is_equal(2)
	var cash: int = proposal.earned.cash
	proposal.earned.cash += 100
	assert_int(peers[0].committed_continuation().earned.cash).is_equal(cash)
	assert_bool(peers[0].propose_continuation()).is_true()
	for i in 2:
		assert_str(peers[i].diagnostic_digest()).is_equal(digest)
		assert_object(peers[i].simulation_for_view()).is_same(originals[i])
		assert_bool(peers[i].advance()).is_false()
	# A valid old-epoch packet must not alter the current decision.
	peers[1]._receive_input(
		Wire.encode(
			{
				"kind": Wire.Kind.CONTINUATION,
				"session": "94".repeat(16),
				"epoch": 1,
				"player": 1,
				"tick": peers[0].ticks_executed(),
				"sequence": 1,
				"digest": "ff".repeat(32)
			}
		)
	)
	assert_bool(peers[1].running()).is_true()
	# Detect even a locally corrupted result object after the original agreement.
	var changed: Dictionary = peers[0].result_for_view().record()
	changed.digest = "ff".repeat(32)
	peers[0].get("_level_result").set("_record", changed)
	assert_bool(peers[0].prepare_continuation()).is_false()
	assert_str(peers[0].error).is_equal("changed_continuation_result")
	await _wait(func(): return not peers[1].running())
	assert_dict(peers[0].committed_continuation()).is_empty()
	assert_object(pair[1][1].sim).is_null()


func test_controlled_shop_and_arcade_decisions_preserve_parent_and_native_state_over_enet() -> void:
	var pair := await _terminal_pair()
	if pair.is_empty():
		return
	var peers: Array = pair[0]
	for peer in peers:
		peer.set("_campaign_cursor", ShopCandidateFixture.new())
	var digest: String = peers[0].diagnostic_digest()
	assert_bool(peers[0].propose_continuation(2)).is_false()
	assert_bool(peers[0].propose_continuation(1)).is_true()
	await _wait_decision(func(): return peers[0].continuation_sequence() == 1 and peers[1].continuation_sequence() == 1)
	var parent: String = peers[0].committed_continuation(1).digest
	assert_bool(peers[0].propose_continuation(2)).is_true()
	await _wait_decision(func(): return peers[0].continuation_sequence() == 2 and peers[1].continuation_sequence() == 2)
	var preview: Dictionary = peers[0].committed_continuation(2)
	assert_dict(preview).is_equal(peers[1].committed_continuation(2))
	assert_str(preview.parent).is_equal(parent)
	assert_str(preview.action).is_equal("arcade_start")
	assert_bool(preview.requires_loader_adaptation).is_true()
	assert_bool(preview.difficulty_rule_review_required).is_true()
	var verifications: int = peers[1].verification_calls
	for duplicate in 4:
		peers[1]._receive_input(
			Wire.encode(
				{
					"kind": Wire.Kind.CONTINUATION_COMMIT,
					"session": "94".repeat(16),
					"epoch": 1,
					"player": 1,
					"tick": peers[1].ticks_executed(),
					"sequence": 2,
					"digest": preview.digest
				}
			)
		)
	assert_int(peers[1].verification_calls).is_equal(verifications)
	assert_int(peers[1].continuation_sequence()).is_equal(2)
	for peer in peers:
		assert_str(peer.diagnostic_digest()).is_equal(digest)
	peers[1].stop()
	await _wait(func(): return not peers[0].running())
	assert_dict(peers[0].committed_continuation(2)).is_empty()


func test_different_locally_derived_candidates_fail_closed_over_enet() -> void:
	var pair := await _terminal_pair()
	if pair.is_empty():
		return
	var peers: Array = pair[0]
	for i in 2:
		var cursor := ShopCandidateFixture.new()
		cursor.variant = i
		peers[i].set("_campaign_cursor", cursor)
	assert_bool(peers[0].propose_continuation()).is_true()
	await _wait_decision(func(): return not peers[0].running() and not peers[1].running())
	assert_str(peers[1].error).is_equal("continuation_proposal_mismatch")
	assert_dict(peers[0].committed_continuation()).is_empty()
