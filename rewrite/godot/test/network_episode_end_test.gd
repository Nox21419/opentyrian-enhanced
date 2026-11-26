## Inherits Game/save mutation sentinels and native result fixtures.
extends "res://test/network_campaign_cursor_test.gd"

const Ending := preload("res://scripts/network_episode_end.gd")
const Next := preload("res://scripts/network_next_level.gd")
const StoryData := preload("res://scripts/network_story_script.gd")


func _ending_context(ep: int) -> Array:
	var oracle: RefCounted = ClassDB.instantiate("TyrianCampaign")
	oracle.load(Game.data_dir)
	var section := 0
	for value in range(1, 256):
		if oracle.run_script(ep, value, 2, 11, true, 0, true, 0).get("stop") == "episode_end":
			section = value
			break
	assert_int(section).is_greater(0)
	var config := _config(ep)
	var record := _record(config, {"bonus_level": true, "next_level": section}, [-1, -9223372036854775807 - 1])
	var cursor := Cursor.new(Game.data_dir)
	assert_bool(cursor.begin(config)).is_true()
	return [config, record, cursor.completed(record), {"initial_episode": ep, "repeated": false}]


func test_native_five_episode_plans_keep_original_script_cash_and_pending_effects() -> void:
	for ep in range(1, 6):
		var source := _ending_context(ep)
		var plan := Ending.build(source[0], source[1], source[2], source[3])
		assert_dict(plan).is_not_empty()
		assert_bool(Ending.valid(plan, source[0], source[1], source[2], source[3])).is_true()
		assert_dict(plan.script).is_equal(source[2].script)
		assert_array(plan.cash).is_equal(["ffffffffffffffff", "8000000000000000"])
		assert_bool(plan.effects.applied).is_false()
		assert_bool(plan.effects.high_score_check).is_true()
		assert_bool(plan.effects.hint_context_required).is_true()
		assert_bool(plan.effects.hint_random_choice_required).is_true()
		assert_bool(plan.effects.super_carrot_random_choice_required).is_equal(plan.script.jump_back_to_episode1)
		assert_bool(plan.presentation.has("credits")).is_equal(plan.script.jump_back_to_episode1 and ep > 2)
		assert_int(plan.effects.next_section).is_equal(1)
		assert_dict(Next.build(source[0], source[2], "1234567890abcdef")).is_empty()
		plan.script.screens.clear()
		assert_dict(Ending.build(source[0], source[1], source[2], source[3]).script).is_equal(source[2].script)


func test_history_and_lineage_are_explicit_and_tampered_plans_are_rejected() -> void:
	var source := _ending_context(2)
	for history in [{"initial_episode": 1, "repeated": false}, {"initial_episode": 2, "repeated": true}]:
		assert_bool(Ending.build(source[0], source[1], source[2], history).effects.high_score_check).is_false()
	assert_dict(Ending.build(source[0], source[1], source[2], {"initial_episode": 2})).is_empty()
	var plan := Ending.build(source[0], source[1], source[2], source[3])
	plan.effects.applied = true
	plan.erase("digest")
	plan["digest"] = StoryData.digest(plan)
	assert_bool(Ending.valid(plan, source[0], source[1], source[2], source[3])).is_false()
	for field in ["source_result", "source_configuration", "episode", "earned", "script"]:
		var changed: Dictionary = source[2].duplicate(true)
		match field:
			"episode":
				changed.episode = 1
			"earned":
				changed.earned.cash = 0
			"script":
				changed.script.next_episode = 0
			_:
				changed[field] = "ff".repeat(32)
		changed["digest"] = Cursor.proposal_digest(changed)
		assert_dict(Ending.build(source[0], source[1], changed, source[3])).is_empty()


func test_planning_does_not_draw_random_choices_or_omit_autosave() -> void:
	var source := _ending_context(5)
	seed(18723)
	var expected := randi()
	seed(18723)
	var plan := Ending.build(source[0], source[1], source[2], source[3])
	assert_int(randi()).is_equal(expected)
	assert_dict(plan).is_not_empty()
	source[2].script.autosave = true
	source[2].digest = Cursor.proposal_digest(source[2])
	plan = Ending.build(source[0], source[1], source[2], source[3])
	assert_bool(plan.effects.autosave_pending).is_true()
	assert_bool(plan.effects.applied).is_false()


func test_malformed_native_effects_are_refused_even_with_recomputed_hashes() -> void:
	var source := _ending_context(1)
	for mode in ["hints", "hint_type", "line", "directive", "mini", "wrap", "autosave", "sequence"]:
		var changed: Dictionary = source[2].duplicate(true)
		match mode:
			"hints":
				changed.script.hint_blocks.resize(10)
			"hint_type":
				changed.script.hint_blocks = ["text"]
			"line":
				changed.script.hint_blocks = [PackedStringArray(["x".repeat(2049)])]
			"directive":
				changed.script.screens = [{"directive": "]?", "text": PackedStringArray()}]
			"mini":
				changed.script["mini_game"] = {}
			"wrap":
				changed.script.jump_back_to_episode1 = true
			"autosave":
				changed.script.autosave = 1
			"sequence":
				changed.sequence = true
		changed.digest = Cursor.proposal_digest(changed)
		assert_dict(Ending.build(source[0], source[1], changed, source[3])).is_empty()
	var record: Dictionary = source[1].duplicate(true)
	record.tick = 0xffffffff
	record.erase("digest")
	record["digest"] = StoryData.digest(record)
	var proposal: Dictionary = source[2].duplicate(true)
	proposal.source_result = record.digest
	proposal.digest = Cursor.proposal_digest(proposal)
	assert_dict(Ending.build(source[0], record, proposal, source[3])).is_not_empty()
