extends "res://test/network_episode_end_connection_test.gd"


func test_both_peers_derive_same_hint_without_advancing_or_changing_native_rng() -> void:
	var pair := await _terminal_pair(true)
	if pair.is_empty():
		return
	var peers: Array = pair[0]
	var old := [peers[0].simulation_for_view(), peers[1].simulation_for_view()]
	var tick: int = peers[0].ticks_executed()
	var digest: String = peers[0].diagnostic_digest()
	for peer in peers:
		assert_dict(peer.episode_hint_for_view()).is_empty()
		peer.set("_campaign_cursor", EndingCandidate.new())
	assert_bool(peers[0].propose_continuation()).is_true()
	await _wait_decision(func(): return peers[0].continuation_sequence() == 1 and peers[1].continuation_sequence() == 1)
	var hint: Dictionary = peers[0].episode_hint_for_view()
	assert_dict(hint).is_not_empty()
	assert_dict(peers[1].episode_hint_for_view()).is_equal(hint)
	hint.text.append("MUTATED COPY")
	for i in 2:
		assert_bool(peers[i].episode_hint_for_view().text == hint.text).is_false()
		assert_dict(peers[i].episode_hint_for_view(2)).is_empty()
		assert_bool(peers[i].episode_end_plan().effects.applied).is_false()
		assert_object(peers[i].simulation_for_view()).is_same(old[i])
		assert_int(peers[i].ticks_executed()).is_equal(tick)
		assert_str(peers[i].diagnostic_digest()).is_equal(digest)
		assert_int(peers[i].result_committed_phase()).is_equal(3)
