extends "res://test/network_episode_end_connection_test.gd"

const ScoreView := preload("res://scripts/network_episode_score_view.gd")
var _score_connections := []


func after_test() -> void:
	for connection in _score_connections:
		if is_instance_valid(connection.peer) and connection.peer.changed.is_connected(connection.callback):
			connection.peer.changed.disconnect(connection.callback)
	_score_connections.clear()
	await super.after_test()


class FastScore:
	extends "res://scripts/network_episode_score_view.gd"

	func _wait_with_warning(_units: int) -> void:
		await get_tree().process_frame


class ScoreCandidate:
	extends EndingCandidate

	func completed(record: Dictionary) -> Dictionary:
		var proposal := super.completed(record)
		# Controlled pre-ending directives exercise inherited context and pages.
		proposal.script.screens = [{"directive": "]W 010", "text": PackedStringArray(["ENDING"])}]
		proposal.digest = CursorBuilder.proposal_digest(proposal)
		return proposal


func test_original_score_views_agree_pages_and_both_finishes_without_ending_effects() -> void:
	var pair := await _terminal_pair(true)
	if pair.is_empty():
		return
	var peers: Array = pair[0]
	var tick: int = peers[0].ticks_executed()
	var diagnostic: String = peers[0].diagnostic_digest()
	for peer in peers:
		peer.set("_campaign_cursor", ScoreCandidate.new())
	assert_bool(peers[0].propose_continuation()).is_true()
	await _wait_decision(func(): return peers[0].continuation_sequence() == 1 and peers[1].continuation_sequence() == 1)
	var views := []
	var finished := []
	for i in 2:
		assert_bool(peers[i].prepare_story(1, "cd".repeat(32))).is_false()
		assert_bool(peers[i].prepare_episode_score(1, "cd".repeat(32))).is_true()
		var view := FastScore.new()
		_nodes.push_front(view)
		assert_bool(view.bind_score(peers[i].story_for_view(1), i + 1)).is_true()
		view.page_ready.connect(func(page: int, digest: String): peers[i].mark_story_ready(1, page, digest))
		view.advance_requested.connect(func(page: int, digest: String): peers[i].request_story_advance(1, page, digest))
		view.finished.connect(
			func(_source: String):
				finished.append(i)
				peers[i].mark_story_finished(1, view.context_state())
		)
		var sync := func():
			if (
				is_instance_valid(view)
				and view.get("_active")
				and view.get("_page_ready")
				and peers[i].story_committed_page(1) >= view.get("_page")
			):
				view.commit_page(view.get("_page"), view.page_digest(view.get("_page")))
		peers[i].changed.connect(sync)
		_score_connections.append({"peer": peers[i], "callback": sync})
		views.append(view)
		add_child(view)
		if i == 0:
			await _wait_decision(func(): return peers[1].get("_story_early").has(1))
	assert_dict(views[0].presentation_descriptor()).is_equal(views[1].presentation_descriptor())
	for page in [1, 2]:
		await _wait_decision(
			func():
				return (
					views[0].get("_page") == page
					and views[1].get("_page") == page
					and views[0].get("_page_ready")
					and views[1].get("_page_ready")
				)
		)
		var key := InputEventKey.new()
		key.physical_keycode = KEY_SPACE
		key.pressed = true
		views[1]._input(key)
		await get_tree().process_frame
		assert_int(peers[0].story_committed_page(1)).is_equal(page - 1)
		views[0]._input(key)
		await _wait_decision(
			func(): return peers[0].story_committed_page(1) == page and peers[1].story_committed_page(1) == page
		)
	await _wait_decision(
		func(): return finished.size() == 2 and peers[0].story_complete(1) and peers[1].story_complete(1)
	)
	for peer in peers:
		assert_bool(peer.prepare_episode_score(1, "cd".repeat(32))).is_true()
		assert_str(peer.error).is_empty()
		assert_int(peer.ticks_executed()).is_equal(tick)
		assert_str(peer.diagnostic_digest()).is_equal(diagnostic)
		assert_bool(peer.story_context().warning_red).is_true()
		assert_int(peer.result_committed_phase()).is_equal(3)
		assert_dict(Next.build(peer.configuration(), peer.committed_continuation(), "1234567890abcdef")).is_empty()
