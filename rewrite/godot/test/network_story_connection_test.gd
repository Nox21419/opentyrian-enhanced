## Real ENet/native terminal harness with a controlled story-stop candidate.
## This is page protocol coverage, not live campaign/story scene routing.
extends "res://test/network_continuation_connection_test.gd"

const StoryView := preload("res://scripts/network_story_view.gd")
const StoryData := preload("res://scripts/network_story_script.gd")


class StoryCandidate:
	extends RefCounted
	var error := ""
	var _proposal := {}

	func completed(record: Dictionary) -> Dictionary:
		if _proposal.is_empty():
			_proposal = {
				"format_version": 1,
				"sequence": 1,
				"source_result": record.digest,
				"source_configuration": record.config,
				"kind": "level",
				"episode": 1,
				"initial_difficulty": 2,
				"network_difficulty": 3,
				"earned": record.stats.duplicate(true),
				"requires_loader_adaptation": true,
				"difficulty_rule_review_required": false,
				"script":
				{
					"stop": "level",
					"lvl_file_num": 9,
					"next_level": 4,
					"level_name": "TYRIAN",
					"bonus": false,
					"normal_bonus": false,
					"screens":
					[
						{"directive": "]W 00[", "text": PackedStringArray(["FIRST"])},
						{"directive": "]W 00[", "text": PackedStringArray(["SECOND"])}
					]
				}
			}
			_proposal["digest"] = CursorBuilder.proposal_digest(_proposal)
		return _proposal.duplicate(true)


func _story_pair(resume := false) -> Array:
	var pair := await _terminal_pair(resume)
	if pair.is_empty():
		return []
	for peer in pair[0]:
		peer.set("_campaign_cursor", StoryCandidate.new())
	assert_bool(pair[0][0].propose_continuation()).is_true()
	await _wait_decision(
		func(): return pair[0][0].continuation_sequence() == 1 and pair[0][1].continuation_sequence() == 1
	)
	return pair


func test_staggered_story_preparation_and_page_commits_preserve_native_and_require_both_finishes() -> void:
	var pair := await _story_pair(true)
	if pair.is_empty():
		return
	var peers: Array = pair[0]
	var originals := [peers[0].simulation_for_view(), peers[1].simulation_for_view()]
	var before: String = peers[0].diagnostic_digest()
	var tick: int = peers[0].ticks_executed()
	var background := "cd".repeat(32)
	assert_bool(peers[0].prepare_story(1, "")).is_false()
	assert_bool(peers[0].prepare_story(1, background)).is_true()
	var descriptor: Dictionary = peers[0].story_for_view(1)
	assert_bool(peers[0].mark_story_ready(1, 1, descriptor.pages[0])).is_true()
	assert_bool(peers[0].request_story_advance(1, 1, descriptor.pages[0])).is_true()
	assert_int(peers[0].story_committed_page(1)).is_equal(0)
	await _wait_decision(func(): return peers[1].get("_story_early").has(1))
	var seen_at: int = peers[1].get("_story_early")[1].time
	var verifications: int = peers[1].verification_calls
	var host_pages: RefCounted = peers[0].get("_story_pages")[1]
	for duplicate in 3:
		peers[1]._receive_input(Wire.encode(host_pages._message(Wire.Kind.STORY_READY, 1, descriptor.pages[0])))
	assert_int(peers[1].verification_calls).is_equal(verifications)
	assert_int(peers[1].get("_story_early")[1].time).is_equal(seen_at)
	assert_bool(peers[1].prepare_story(1, background)).is_true()
	assert_dict(peers[1].story_for_view(1)).is_equal(descriptor)
	var view := StoryView.new()
	_nodes.push_front(view)
	(
		assert_bool(
			view.bind_script(descriptor.script, descriptor.source, 1, descriptor.context, descriptor.background)
		)
		. is_true()
	)
	assert_dict(view.presentation_descriptor()).is_equal(descriptor)
	assert_bool(peers[1].request_story_advance(1, 1, descriptor.pages[0])).is_false()
	assert_bool(peers[0].propose_continuation(2)).is_false()
	assert_bool(peers[0].prepare_next_level(1, "12".repeat(8))).is_false()
	assert_bool(peers[1].mark_story_ready(1, 1, descriptor.pages[0])).is_true()
	await _wait_decision(func(): return peers[0].story_committed_page(1) == 1 and peers[1].story_committed_page(1) == 1)
	for peer in peers:
		assert_bool(peer.mark_story_ready(1, 2, descriptor.pages[1])).is_true()
	assert_bool(peers[0].request_story_advance(1, 2, descriptor.pages[1])).is_true()
	await _wait_decision(func(): return peers[0].story_committed_page(1) == 2 and peers[1].story_committed_page(1) == 2)
	var context := {"warning_red": false, "use_last_bank": false}
	assert_bool(peers[0].mark_story_finished(1, context)).is_true()
	assert_bool(peers[0].story_complete(1)).is_false()
	assert_bool(peers[1].mark_story_finished(1, context)).is_true()
	await _wait_decision(func(): return peers[0].story_complete(1) and peers[1].story_complete(1))
	assert_dict(peers[0].story_receipt(1)).is_equal(peers[1].story_receipt(1))
	var receipt: Dictionary = peers[1].story_receipt(1)
	receipt.context.warning_red = true
	assert_bool(peers[1].story_context().warning_red).is_false()
	assert_bool(peers[0].prepare_story(1, background)).is_true()
	for i in 2:
		assert_object(peers[i].simulation_for_view()).is_same(originals[i])
		assert_int(peers[i].ticks_executed()).is_equal(tick)
		assert_str(peers[i].diagnostic_digest()).is_equal(before)
		assert_bool(peers[i].advance()).is_false()
	assert_bool(peers[0].prepare_next_level(1, "12".repeat(8))).is_true()
	await _wait_decision(func(): return peers[0].next_level_loaded() and peers[1].next_level_loaded())
	for peer in peers:
		assert_str(peer.error).is_empty()
		assert_dict(peer.story_receipt(1)).is_not_empty()


func test_different_independently_prepared_entry_frames_fail_before_page_advance() -> void:
	var pair := await _story_pair()
	if pair.is_empty():
		return
	var peers: Array = pair[0]
	assert_bool(peers[0].prepare_story(1, "ab".repeat(32))).is_true()
	assert_bool(peers[1].prepare_story(1, "cd".repeat(32))).is_true()
	var descriptor: Dictionary = peers[0].story_for_view(1)
	assert_bool(peers[0].mark_story_ready(1, 1, descriptor.pages[0])).is_true()
	await _wait_decision(func(): return not peers[0].running() and not peers[1].running())
	assert_str(peers[1].error).is_equal("story_page_mismatch")
	assert_dict(peers[0].story_for_view(1)).is_empty()
	assert_dict(peers[1].story_receipt(1)).is_empty()
