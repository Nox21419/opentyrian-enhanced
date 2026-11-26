## Controlled ending candidate after native terminal completion, no live ending.
extends "res://test/network_continuation_connection_test.gd"

const Next := preload("res://scripts/network_next_level.gd")


class EndingCandidate:
	extends RefCounted
	var error := ""
	var _proposal := {}

	func completed(record: Dictionary) -> Dictionary:
		if _proposal.is_empty():
			var campaign: RefCounted = ClassDB.instantiate("TyrianCampaign")
			campaign.load(Game.data_dir)
			var ending := {}
			for section in range(1, 256):
				var value: Dictionary = campaign.run_script(1, section, 2, 11, true, 0, true, 0)
				if value.get("stop") == "episode_end":
					ending = value
					break
			_proposal = {
				"format_version": 1,
				"sequence": 1,
				"kind": "episode_end",
				"episode": 1,
				"initial_difficulty": 2,
				"source_configuration": record.config,
				"source_result": record.digest,
				"earned": record.stats.duplicate(true),
				"requires_loader_adaptation": true,
				"difficulty_rule_review_required": false,
				"script": ending
			}
			_proposal["digest"] = CursorBuilder.proposal_digest(_proposal)
		return _proposal.duplicate(true)


func test_ending_ledger_requires_committed_decision_and_preserves_native_ownership() -> void:
	var pair := await _terminal_pair(true)
	if pair.is_empty():
		return
	var peers: Array = pair[0]
	var old := [peers[0].simulation_for_view(), peers[1].simulation_for_view()]
	var tick: int = peers[0].ticks_executed()
	var digest: String = peers[0].diagnostic_digest()
	for peer in peers:
		assert_dict(peer.episode_end_plan()).is_empty()
		peer.set("_campaign_cursor", EndingCandidate.new())
	assert_bool(peers[0].propose_continuation()).is_true()
	await _wait_decision(func(): return peers[0].continuation_sequence() == 1 and peers[1].continuation_sequence() == 1)
	var plan: Dictionary = peers[0].episode_end_plan()
	assert_dict(plan).is_not_empty()
	assert_dict(peers[1].episode_end_plan()).is_equal(plan)
	plan.effects.applied = true
	for i in 2:
		assert_bool(peers[i].episode_end_plan().effects.applied).is_false()
		assert_dict(peers[i].episode_end_plan(2)).is_empty()
		assert_object(peers[i].simulation_for_view()).is_same(old[i])
		assert_int(peers[i].ticks_executed()).is_equal(tick)
		assert_str(peers[i].diagnostic_digest()).is_equal(digest)
		(
			assert_dict(Next.build(peers[i].configuration(), peers[i].committed_continuation(), "1234567890abcdef"))
			. is_empty()
		)
