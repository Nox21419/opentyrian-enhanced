extends GdUnitTestSuite

const Setup := preload("res://test/fixtures/network_setup.gd")
const Cursor := preload("res://scripts/network_campaign_cursor.gd")
const Next := preload("res://scripts/network_next_level.gd")
const Config := preload("res://scripts/network_configuration.gd")
const Preparation := preload("res://scripts/network_preparation.gd")
const StoryData := preload("res://scripts/network_story_script.gd")


func test_story_receipt_accounts_for_original_script_and_rejects_changed_context() -> void:
	var proposal := _proposal()
	proposal.script["screens"] = [
		{"directive": "]W 010", "text": PackedStringArray(["WARNING"])},
		{"directive": "]@", "text": PackedStringArray()}
	]
	proposal["digest"] = Cursor.proposal_digest(proposal)
	var descriptor := StoryData.prepare(proposal.script, proposal.digest, {}, "cd".repeat(32))
	var context := StoryData.final_context(proposal.script, descriptor.context)
	assert_bool(context.warning_red).is_true()
	assert_bool(context.use_last_bank).is_true()
	var receipt := StoryData.receipt(descriptor, context)
	assert_bool(StoryData.valid_receipt(receipt, proposal.script, proposal.digest)).is_true()
	assert_dict(Next.build(Setup.configuration(), proposal, "1234567890abcdef")).is_empty()
	var request := Next.build(Setup.configuration(), proposal, "1234567890abcdef", {"script": receipt})
	assert_bool(Next.valid_request(request)).is_true()
	assert_dict(request.script).is_equal(proposal.script)
	for field in ["source", "presentation", "background", "pages", "context", "initial"]:
		var changed := receipt.duplicate(true)
		match field:
			"pages":
				changed.pages += 1
			"context":
				changed.context.warning_red = false
			"initial":
				changed.initial.use_last_bank = true
			_:
				changed[field] = "ab".repeat(32)
		changed.erase("digest")
		changed["digest"] = StoryData.digest(changed)
		assert_dict(Next.build(Setup.configuration(), proposal, "1234567890abcdef", {"script": changed})).is_empty()
	(
		assert_dict(
			Next.build(Setup.configuration(), proposal, "1234567890abcdef", {"script": receipt, "entry": receipt})
		)
		. is_empty()
	)
	proposal.script["autosave"] = true
	proposal["digest"] = Cursor.proposal_digest(proposal)
	assert_dict(Next.build(Setup.configuration(), proposal, "1234567890abcdef", {"script": receipt})).is_empty()


func test_entry_receipt_is_bound_to_the_parent_decision() -> void:
	var proposal := _proposal()
	proposal["sequence"] = 2
	proposal["parent"] = "ab".repeat(32)
	proposal["entry"] = {"stop": "shop", "screens": [{"directive": "]W 00[", "text": PackedStringArray(["ENTRY"])}]}
	proposal["digest"] = Cursor.proposal_digest(proposal)
	var descriptor := StoryData.prepare(proposal.entry, proposal.parent, {}, "cd".repeat(32))
	var receipt := StoryData.receipt(descriptor, StoryData.final_context(proposal.entry, descriptor.context))
	var request := Next.build(Setup.configuration(), proposal, "1234567890abcdef", {"entry": receipt})
	assert_bool(Next.valid_request(request)).is_true()
	proposal.parent = "ef".repeat(32)
	proposal["digest"] = Cursor.proposal_digest(proposal)
	assert_dict(Next.build(Setup.configuration(), proposal, "1234567890abcdef", {"entry": receipt})).is_empty()


func after() -> void:
	Music.release_streams()
	Sfx.release_streams()
	await get_tree().process_frame
	await get_tree().process_frame


func _native() -> Node:
	var sim: Node = ClassDB.instantiate("TyrianSim")
	Mods.attach(sim)
	return sim


func _config() -> Dictionary:
	var config := Setup.configuration()
	config.difficulty = 4
	config.cash1 = "ffffffffffffffff"
	config.cash2 = "0000010000000000"
	config.loadout1[4] = 0
	config.loadout2[2] = 0
	return config


func _proposal() -> Dictionary:
	var config := _config()
	var proposal := {
		"format_version": 1,
		"sequence": 1,
		"kind": "level",
		"source_configuration": Config.digest(Setup.configuration()),
		"source_result": "ab".repeat(32),
		"episode": 1,
		"initial_difficulty": 2,
		"network_difficulty": 4,
		"difficulty_rule_review_required": false,
		"script": {"stop": "level", "lvl_file_num": 9, "bonus": false, "normal_bonus": false},
		"earned":
		{
			"cash": -1,
			"cash2": 1099511627776,
			"loadout": PackedInt32Array(config.loadout1 + [0]),
			"loadout2": PackedInt32Array(config.loadout2 + [0]),
			"carry": PackedInt32Array([3, 4, 5, 6, 1, 3, 2])
		}
	}
	proposal["digest"] = Cursor.proposal_digest(proposal)
	return proposal


func test_detached_request_keeps_lineage_and_strict_startup_policy() -> void:
	var proposal := _proposal()
	var request := Next.build(Setup.configuration(), proposal, "1234567890abcdef")
	assert_dict(request).is_not_empty()
	assert_bool(Config.valid(request.configuration)).is_false()
	assert_bool(Next.valid_configuration(request.configuration)).is_true()
	assert_str(request.configuration.cash1).is_equal("ffffffffffffffff")
	assert_str(request.source_proposal).is_equal(proposal.digest)
	assert_int(request.configuration.loadout1[4]).is_equal(0)
	var sim := _native()
	(
		assert_bool(
			sim.prepare_network_continuation(Game.data_dir, request.configuration, request.carry, request.bonus_level)
		)
		. is_true()
	)
	assert_int(sim.player_dict(0).cash).is_equal(-1)
	sim.free()
	request.carry[0] = 99
	assert_int(proposal.earned.carry[0]).is_equal(3)
	for changed in ["hash", "shop", "story", "autosave", "mini", "context", "difficulty", "parent"]:
		var bad := proposal.duplicate(true)
		match changed:
			"shop":
				bad.kind = "shop"
			"story":
				bad.script["screens"] = [{"directive": "]P"}]
			"autosave":
				bad.script["autosave"] = true
			"mini":
				bad.script["mini_game"] = 1
			"context":
				bad.source_configuration = "00".repeat(32)
			"difficulty":
				bad.network_difficulty = 2
			"parent":
				bad.sequence = 2
		bad.digest = Cursor.proposal_digest(bad)
		if changed == "hash":
			bad.earned.cash = 123
		assert_dict(Next.build(Setup.configuration(), bad, "1234567890abcdef")).is_empty()


func test_carried_state_is_exact_and_fresh_node_guard_preserves_old_simulation() -> void:
	var config := _config()
	var carry := PackedInt32Array([-1, 4, 5, 6, 1, 3, 2])
	var sim := _native()
	assert_bool(sim.prepare_network_continuation(Game.data_dir, config, carry, true)).is_true()
	assert_int(sim.tick()).is_equal(0)
	assert_int(sim.player_dict(0).cash).is_equal(-1)
	assert_int(sim.player_dict(1).cash).is_equal(1099511627776)
	assert_array(Array(sim.campaign_carry())).is_equal(Array(carry))
	var stats: Dictionary = sim.level_stats()
	assert_int(stats.loadout[4]).is_equal(0)
	assert_int(stats.loadout2[2]).is_equal(0)
	var before: String = sim.network_diagnostic_digest()
	assert_bool(sim.prepare_network_continuation(Game.data_dir, config, carry, true)).is_false()
	assert_bool(sim.prepare_network_level(Game.data_dir, Setup.configuration())).is_false()
	assert_str(sim.network_diagnostic_digest()).is_equal(before)
	sim.free()


func test_two_loaded_peers_match_and_do_not_mutate_existing_initial_preview() -> void:
	var old := _native()
	assert_bool(old.prepare_network_level(Game.data_dir, Setup.configuration())).is_true()
	var old_digest: String = old.network_diagnostic_digest()
	var first := _native()
	var second := _native()
	var carry := PackedInt32Array([3, 4, 5, 6, 1, 2, 1])
	for sim in [first, second]:
		assert_bool(sim.prepare_network_continuation(Game.data_dir, _config(), carry, false)).is_true()
		assert_bool(sim.start_network_presentation()).is_true()
	assert_str(first.network_diagnostic_digest()).is_equal(second.network_diagnostic_digest())
	for tick in 80:
		for sim in [first, second]:
			sim.set_player_mice(16, 3 if tick % 2 == 0 else -3, 0, 16, 0, 2)
			sim.step(0, 0)
		assert_str(first.network_diagnostic_digest()).is_equal(second.network_diagnostic_digest())
	assert_str(old.network_diagnostic_digest()).is_equal(old_digest)
	first.free()
	second.free()
	old.free()


func test_native_rejects_invalid_carry_catalog_types_and_difficulty_without_installing() -> void:
	var sim := _native()
	var valid_carry := PackedInt32Array([0, 0, 0, 0, 0, 101, 0])
	for carry in [
		PackedInt32Array(), PackedInt32Array([0, 0, 0, 0, 2, 0, 0]), PackedInt32Array([0, 0, 0, 0, 0, 256, 0])
	]:
		assert_bool(sim.prepare_network_continuation(Game.data_dir, _config(), carry, false)).is_false()
	for pair in [
		["difficulty", 2],
		["difficulty", 4.0],
		["cash1", "FFFFFFFFFFFFFFFF"],
		["level_file", 65535],
		["devices", [1, 0]],
		["unknown", true]
	]:
		var config := _config()
		config[pair[0]] = pair[1]
		assert_bool(sim.prepare_network_continuation(Game.data_dir, config, valid_carry, false)).is_false()
	for pair in [["loadout1", 2, 0], ["loadout2", 4, 12], ["loadout1", 0, 255]]:
		var config := _config()
		config[pair[0]][pair[1]] = pair[2]
		assert_bool(sim.prepare_network_continuation(Game.data_dir, config, valid_carry, false)).is_false()
	assert_str(sim.network_diagnostic_digest()).is_empty()
	assert_bool(sim.prepare_network_level(Game.data_dir, _config())).is_false()
	assert_bool(sim.prepare_network_level(Game.data_dir, Setup.configuration())).is_true()
	sim.free()


func test_native_two_player_threshold_and_unsigned_cash_encoding() -> void:
	var campaign: RefCounted = ClassDB.instantiate("TyrianCampaign")
	assert_str(Cursor.unsigned_cash(-1)).is_equal("ffffffffffffffff")
	assert_str(Cursor.unsigned_cash(4294967296)).is_equal("0000000100000000")
	assert_int(campaign.adjust_difficulty(3, 2, 62500)).is_equal(3)
	assert_int(campaign.adjust_network_two_player_difficulty(3, 2, "0000000000007a12", "0000000000007a12")).is_equal(4)
	assert_int(campaign.adjust_network_two_player_difficulty(3, 2, "ffffffffffffffff", "0000000000000001")).is_equal(3)
	assert_int(campaign.adjust_network_two_player_difficulty(3, 2, "ffffffffffffffff", "0000000000000000")).is_equal(3)
	assert_int(campaign.adjust_network_two_player_difficulty(2, 2, "0000000000000000", "0000000000000000")).is_equal(-1)


func test_owned_forks_preserve_old_node_and_release_only_their_own_previews() -> void:
	var original := Preparation.new()
	assert_bool(original.capture(Game.data_dir, PackedStringArray(), {}, 1)).is_true()
	assert_bool(original.validate(Setup.configuration())).is_true()
	assert_bool(original.prepare_preview()).is_true()
	var old: Node = original.get("_preview")
	var before: String = old.network_diagnostic_digest()
	var first := original.fork_continuation(_proposal(), "1234567890abcdef")
	var second := original.fork_continuation(_proposal(), "1234567890abcdef")
	assert_object(first).is_not_null()
	assert_object(second).is_not_null()
	if first == null or second == null:
		original.clear()
		return
	assert_str(first.preview_digest()).is_equal(second.preview_digest())
	assert_dict(first.identity()).is_equal(original.identity())
	assert_bool(first.verify_preview()).is_true()
	assert_bool(first.prepare_preview()).is_true()
	assert_bool(first.validate(Setup.configuration())).is_false()
	var request: Dictionary = first.continuation_request()
	request.carry[0] = 99
	assert_int(first.continuation_request().carry[0]).is_equal(3)
	var new_node: Node = first.get("_preview")
	var other_node: Node = second.get("_preview")
	assert_bool(new_node != old and new_node != other_node).is_true()
	first.clear()
	assert_bool(is_instance_valid(new_node)).is_false()
	assert_bool(is_instance_valid(other_node)).is_true()
	assert_str(old.network_diagnostic_digest()).is_equal(before)
	var bad := _proposal()
	bad.kind = "shop"
	bad.digest = Cursor.proposal_digest(bad)
	assert_object(original.fork_continuation(bad, "1234567890abcdef")).is_null()
	assert_str(old.network_diagnostic_digest()).is_equal(before)
	other_node.step(0, 0)
	assert_bool(second.verify_preview()).is_false()
	assert_bool(is_instance_valid(other_node)).is_false()
	assert_str(old.network_diagnostic_digest()).is_equal(before)
	original.clear()
	assert_bool(is_instance_valid(old)).is_false()
