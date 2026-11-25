extends GdUnitTestSuite

const Cursor := preload("res://scripts/network_campaign_cursor.gd")
const Result := preload("res://scripts/network_level_result.gd")
const Rules := preload("res://scripts/network_initial_configuration.gd")
const Fixture := preload("res://test/fixtures/network_setup.gd")
const FinishedSimulation := preload("res://test/network_level_result_test.gd").FinishedSimulation
var _game_before := PackedByteArray()
var _saves_before := {}


class ScriptReader:
	extends RefCounted
	var response := {}
	var calls: Array = []

	func adjust_difficulty(_previous: int, _initial: int, _score: int) -> int:
		return 4

	func adjust_network_two_player_difficulty(_previous: int, _initial: int, _cash1: String, _cash2: String) -> int:
		return 4

	func run_script(
		ep: int, section: int, difficulty: int, ship: int, alive: bool, cubes: int, two: bool, timed: int
	) -> Dictionary:
		calls.append([ep, section, difficulty, ship, alive, cubes, two, timed])
		return response.duplicate(true)


func before_test() -> void:
	_game_before = _game_state()
	assert_bool(_game_before.is_empty()).is_false()
	DirAccess.make_dir_recursive_absolute("user://saves")
	var sentinel := FileAccess.open("user://saves/cursor-sentinel.txt", FileAccess.WRITE)
	sentinel.store_string("must remain unchanged")
	sentinel.close()
	_saves_before = _save_state()
	assert_bool(_saves_before.has("cursor-sentinel.txt")).is_true()


func after_test() -> void:
	assert_bool(_game_state() == _game_before).is_true()
	assert_dict(_save_state()).is_equal(_saves_before)


func after() -> void:
	Music.release_streams()
	Sfx.release_streams()
	await get_tree().process_frame
	await get_tree().process_frame


func _game_state() -> PackedByteArray:
	var state := {}
	for key in [
		"episode",
		"lvl_file_num",
		"level_name",
		"loadout",
		"modes",
		"campaign_modes",
		"campaign_modes_extra",
		"campaign_active",
		"campaign_carry",
		"difficulty",
		"initial_difficulty",
		"debrief",
		"last_level_name",
		"next_level",
		"main_level"
	]:
		state[key] = Game.get(key)
	return Result.canonical_bytes(state)


func _save_state() -> Dictionary:
	var state := {}
	for file in DirAccess.get_files_at("user://saves"):
		state[file] = FileAccess.get_sha256("user://saves".path_join(file))
	return state


func _config(episode := 1, difficulty := 2) -> Dictionary:
	var config := Fixture.configuration()
	config.episode = episode
	config.initial_difficulty = difficulty
	config.difficulty = difficulty + 1
	config.level_file = Rules.new(Game.data_dir).first_level(episode, difficulty).lvl_file_num
	return config


func _record(config: Dictionary, overrides := {}, cash := [1200, 2400]) -> Dictionary:
	var native := FinishedSimulation.new()
	native.cash = cash.duplicate()
	native.values.merge(
		{
			"cube_max": 0,
			"total_score": 20000,
			"bonus_level": false,
			"next_level": 0,
			"all_players_alive": true,
			"any_player_alive": true,
			"lives": 2
		},
		true
	)
	native.values.merge(overrides, true)
	var result := Result.new()
	assert_bool(result.capture(native, config, "TYRIAN", 47)).is_true()
	native.free()
	return result.record()


func test_real_episode_and_difficulty_routes_match_existing_campaign_calls() -> void:
	var oracle: RefCounted = ClassDB.instantiate("TyrianCampaign")
	oracle.load(Game.data_dir)
	for ep in range(1, 6):
		for difficulty in [1, 2, 3, 4, 6, 8]:
			var config := _config(ep, difficulty)
			var cursor := Cursor.new(Game.data_dir)
			assert_bool(cursor.begin(config)).is_true()
			var record := _record(config)
			var proposal := cursor.completed(record)
			assert_dict(proposal).is_not_empty()
			if proposal.is_empty():
				assert_str(cursor.error).is_empty()
				return
			var level := Rules.new(Game.data_dir).first_level(ep, difficulty)
			var expected: Dictionary = oracle.run_script(ep, level.next_level, difficulty, 11, true, 0, true, 0)
			assert_dict(proposal.script).is_equal(expected)
			assert_int(proposal.local_difficulty).is_equal(oracle.adjust_difficulty(difficulty + 1, difficulty, 20000))
			assert_str(proposal.kind).is_equal(expected.stop)
			assert_int(proposal.next_section).is_equal(level.next_level)
			assert_int(proposal.sequence).is_equal(1)
			assert_bool(proposal.requires_loader_adaptation).is_true()
			assert_bool(proposal.difficulty_rule_review_required).is_false()
			assert_int(proposal.network_difficulty).is_equal(difficulty + 1)
			assert_dict(proposal.earned).is_equal(record.stats)


func test_warp_survivor_context_and_exact_two_player_state_are_preserved() -> void:
	var config := _config()
	var record := _record(
		config,
		{"bonus_level": true, "next_level": 41, "all_players_alive": false, "any_player_alive": true},
		[-1, 4294967296]
	)
	var cursor := Cursor.new(Game.data_dir)
	assert_bool(cursor.begin(config)).is_true()
	var proposal := cursor.completed(record)
	assert_int(proposal.next_section).is_equal(41)
	assert_int(proposal.earned.cash).is_equal(-1)
	assert_int(proposal.earned.cash2).is_equal(4294967296)
	assert_array(Array(proposal.earned.carry)).is_equal([3, 4, 5, 6, 1, 2, 7])
	assert_array(Array(proposal.earned.loadout2)).is_equal(Array(record.stats.loadout2))
	var oracle: RefCounted = ClassDB.instantiate("TyrianCampaign")
	oracle.load(Game.data_dir)
	assert_dict(proposal.script).is_equal(oracle.run_script(1, 41, 2, 11, false, 0, true, 0))
	proposal.earned.loadout2[4] = 99
	assert_int(cursor.completed(record).earned.loadout2[4]).is_equal(3)


func test_approved_network_rule_uses_both_cash_counters_instead_of_local_score() -> void:
	var config := _config()
	var cursor := Cursor.new(Game.data_dir)
	assert_bool(cursor.begin(config)).is_true()
	var proposal := cursor.completed(_record(config, {}, [31250, 31250]))
	assert_int(proposal.local_difficulty).is_equal(3)
	assert_int(proposal.network_difficulty).is_equal(4)
	assert_bool(proposal.difficulty_rule_review_required).is_false()
	assert_bool(proposal.requires_loader_adaptation).is_true()


func test_normal_death_proposes_retry_without_success_adjustment_and_bonus_exit_continues() -> void:
	var config := _config()
	var record := _record(config, {"all_players_alive": false, "any_player_alive": false, "total_score": 999999999})
	var cursor := Cursor.new(Game.data_dir)
	assert_bool(cursor.begin(config)).is_true()
	var proposal := cursor.completed(record)
	assert_str(proposal.kind).is_equal("retry_required")
	assert_dict(proposal.script).is_empty()
	assert_int(proposal.local_difficulty).is_equal(3)
	assert_bool(proposal.difficulty_rule_review_required).is_false()
	assert_dict(proposal.retry_checkpoint.configuration).is_equal(config)
	assert_int(proposal.retry_checkpoint.section).is_greater(0)
	cursor = Cursor.new(Game.data_dir)
	assert_bool(cursor.begin(config)).is_true()
	# A later bonus-level context fixture; current initial levels are unchanged.
	cursor.get("_level")["normal_bonus"] = true
	assert_str(cursor.completed(record).kind).is_not_equal("retry_required")


func test_original_arcade_start_keeps_entry_effects_and_uses_last_map_or_next_section() -> void:
	for map in [PackedInt32Array([2, 8, 3, 11]), PackedInt32Array()]:
		var config := _config()
		var cursor := Cursor.new(Game.data_dir)
		assert_bool(cursor.begin(config)).is_true()
		var reader := ScriptReader.new()
		reader.response = {
			"stop": "shop",
			"section": 40,
			"map": map,
			"autosave": true,
			"screens": [{"directive": "]P", "text": PackedStringArray(["Retain this story page"])}]
		}
		cursor.set("_campaign", reader)
		var proposal := cursor.completed(_record(config))
		assert_dict(proposal).is_not_empty()
		var entry := reader.response.duplicate(true)
		reader.response = {"stop": "level", "section": 41, "lvl_file_num": 9, "next_level": 42}
		var preview := cursor.preview_arcade_start(proposal.digest)
		assert_int(preview.next_section).is_equal(11 if not map.is_empty() else 41)
		assert_dict(preview.entry).is_equal(entry)
		assert_bool(preview.entry.autosave).is_true()
		assert_str(preview.parent).is_equal(proposal.digest)
		assert_int(preview.sequence).is_equal(2)
		assert_int(reader.calls.back()[1]).is_equal(preview.next_section)
		assert_dict(cursor.preview_arcade_start(proposal.digest)).is_equal(preview)


func test_context_hash_mutation_conflicts_and_unsupported_stops_are_rejected() -> void:
	var config := _config()
	var cursor := Cursor.new(Game.data_dir)
	assert_bool(cursor.begin(config)).is_true()
	var record := _record(config)
	var proposal := cursor.completed(record)
	assert_dict(cursor.completed(record)).is_equal(proposal)
	record.stats.cash += 1
	assert_dict(cursor.completed(record)).is_empty()
	assert_str(cursor.error).is_equal("invalid_campaign_result")
	cursor = Cursor.new(Game.data_dir)
	assert_bool(cursor.begin(config)).is_true()
	cursor.completed(_record(config))
	assert_dict(cursor.completed(_record(config, {}, [1201, 2400]))).is_empty()
	assert_str(cursor.error).is_equal("conflicting_campaign_result")
	cursor = Cursor.new(Game.data_dir)
	assert_bool(cursor.begin(config)).is_true()
	var other := config.duplicate(true)
	other.seed = "0000000000000001"
	assert_dict(cursor.completed(_record(other))).is_empty()
	cursor = Cursor.new(Game.data_dir)
	assert_bool(cursor.begin(config)).is_true()
	var reader := ScriptReader.new()
	reader.response = {"stop": "unknown"}
	cursor.set("_campaign", reader)
	assert_dict(cursor.completed(_record(config))).is_empty()
	assert_str(cursor.error).is_equal("unsupported_campaign_stop")


func test_native_raw_cube_counter_and_ending_directives_are_preserved() -> void:
	var oracle: RefCounted = ClassDB.instantiate("TyrianCampaign")
	oracle.load(Game.data_dir)
	for ep in range(1, 6):
		var end_section := 0
		var expected := {}
		for section in range(1, 256):
			var script: Dictionary = oracle.run_script(ep, section, 2, 11, true, 255, true, 0)
			if script.get("stop") == "episode_end":
				end_section = section
				expected = script
				break
		assert_int(end_section).is_greater(0)
		if end_section == 0:
			return
		var config := _config(ep)
		var cursor := Cursor.new(Game.data_dir)
		assert_bool(cursor.begin(config)).is_true()
		var record := _record(config, {"bonus_level": true, "next_level": end_section, "cube_max": 255})
		var proposal := cursor.completed(record)
		assert_dict(proposal).is_not_empty()
		if proposal.is_empty():
			assert_str(cursor.error).is_empty()
			return
		assert_str(proposal.kind).is_equal("episode_end")
		assert_int(proposal.earned.cube_max).is_equal(255)
		assert_dict(proposal.script).is_equal(expected)


func test_semantically_invalid_but_correctly_hashed_records_are_rejected() -> void:
	var config := _config()
	for overrides in [
		{"all_players_alive": true, "any_player_alive": false},
		{"cube_max": 256},
		{"lives": -1},
		{"next_level": -1},
		{"loadout2": PackedInt32Array([1, 2])}
	]:
		var cursor := Cursor.new(Game.data_dir)
		assert_bool(cursor.begin(config)).is_true()
		assert_dict(cursor.completed(_record(config, overrides))).is_empty()
		assert_str(cursor.error).is_equal("invalid_campaign_result")
