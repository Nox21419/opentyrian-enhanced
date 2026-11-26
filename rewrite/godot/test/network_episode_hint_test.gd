## Native ending fixtures plus Game/save sentinels inherited from ending tests.
extends "res://test/network_episode_end_test.gd"

const Hint := preload("res://scripts/network_episode_hint.gd")
const SESSION := "12121212121212121212121212121212"


func test_hint_group_stays_session_owned_across_native_episode_plans() -> void:
	var owned_context := Hint.context(SESSION)
	assert_int(owned_context.group).is_between(1, 3)
	for ep in range(1, 6):
		var source := _ending_context(ep)
		var hint := Hint.build(source[0], source[1], source[2], source[3], SESSION)
		assert_dict(hint).is_not_empty()
		assert_dict(hint.context).is_equal(owned_context)
		assert_int(hint.variant).is_between(0, 2)
		assert_int(hint.requested_block).is_equal(owned_context.group + hint.variant * 3)
		assert_bool(Hint.valid(hint, source[0], source[1], source[2], source[3], SESSION)).is_true()
		assert_str(hint.source_plan).is_equal(Ending.build(source[0], source[1], source[2], source[3]).digest)
		var block: int = hint.selected_block
		if block > 0:
			assert_bool(hint.text == source[2].script.hint_blocks[block - 1]).is_true()
	assert_dict(Hint.context("bad-session")).is_empty()


func test_all_original_block_combinations_and_missing_block_fallback_keep_raw_text() -> void:
	var blocks := []
	for i in 9:
		blocks.append(PackedStringArray(["BLOCK %d" % (i + 1), "  RAW TEXT  "]))
	for group in range(1, 4):
		for variant in range(3):
			var selection := Hint.select_block(blocks, group, variant)
			assert_int(selection.block).is_equal(group + variant * 3)
			assert_bool(selection.text == blocks[selection.block - 1]).is_true()
	assert_int(Hint.select_block(blocks.slice(0, 2), 3, 2).block).is_equal(1)
	assert_bool(Hint.select_block([], 1, 0).text.is_empty()).is_true()
	assert_int(Hint.select_block([], 1, 0).block).is_equal(0)
	for pair in [[0, 0], [4, 0], [1, -1], [1, 3]]:
		assert_dict(Hint.select_block(blocks, pair[0], pair[1])).is_empty()
	assert_dict(Hint.select_block(["bad"], 1, 0)).is_empty()
	var selection := Hint.select_block(blocks, 1, 0)
	selection.text.append("CHANGED")
	assert_int(blocks[0].size()).is_equal(2)


func test_changed_session_source_history_or_descriptor_cannot_reuse_hint_and_no_rng_draw_occurs() -> void:
	var source := _ending_context(1)
	seed(26481)
	var expected := randi()
	seed(26481)
	var hint := Hint.build(source[0], source[1], source[2], source[3], SESSION)
	assert_int(randi()).is_equal(expected)
	assert_bool(Hint.valid(hint, source[0], source[1], source[2], source[3], "34".repeat(16))).is_false()
	(
		assert_bool(
			Hint.valid(hint, source[0], source[1], source[2], {"initial_episode": 1, "repeated": true}, SESSION)
		)
		. is_false()
	)
	for field in ["variant", "requested_block", "selected_block", "text", "context", "source_plan"]:
		var changed := hint.duplicate(true)
		match field:
			"variant":
				changed.variant = (changed.variant + 1) % 3
			"requested_block", "selected_block":
				changed[field] += 1
			"text":
				changed.text.append("CHANGED")
			"context":
				changed.context.group = changed.context.group % 3 + 1
			_:
				changed[field] = "ff".repeat(32)
		changed.erase("digest")
		changed["digest"] = StoryData.digest(changed)
		assert_bool(Hint.valid(changed, source[0], source[1], source[2], source[3], SESSION)).is_false()
	source[2].script.hint_blocks[0].append("NEW SOURCE")
	source[2].digest = Cursor.proposal_digest(source[2])
	assert_bool(Hint.valid(hint, source[0], source[1], source[2], source[3], SESSION)).is_false()
