extends "res://test/network_episode_end_test.gd"

const Transaction := preload("res://scripts/network_episode_high_scores.gd")
const Profile := preload("res://scripts/network_high_score_profile.gd")
const Config := preload("res://scripts/network_configuration.gd")


func _rows() -> Array:
	return [
		{"score": 300, "name": "AAA", "difficulty": 1},
		{"score": 200, "name": "BBB", "difficulty": 2},
		{"score": 100, "name": "CCC", "difficulty": 3}
	]


func _transaction(cash := [1200, 2400], muts := 0) -> RefCounted:
	var source := _ending_context(1)
	source[0].mutators = muts
	var record: Dictionary = source[1].duplicate(true)
	record.config = Config.digest(source[0])
	record.stats.cash = cash[0]
	record.stats.cash2 = cash[1]
	record.erase("digest")
	record["digest"] = StoryData.digest(record)
	var proposal: Dictionary = source[2].duplicate(true)
	proposal.source_configuration = record.config
	proposal.source_result = record.digest
	proposal.earned = record.stats.duplicate(true)
	proposal.digest = Cursor.proposal_digest(proposal)
	var model := Transaction.new()
	assert_bool(model.begin(source[0], record, proposal, source[3], _rows())).is_true()
	return model


func test_original_player_order_qualification_multiplier_and_name_marking() -> void:
	var model := _transaction()
	assert_int(model.table).is_equal(11)
	assert_int(model.entry().player).is_equal(1)
	var first: Dictionary = model.submit("GUEST", false, model.entry().digest)
	assert_str(first.after[0].name).is_equal("GUEST")
	assert_int(model.entry().player).is_equal(0)
	model.submit("HOST", false, model.entry().digest)
	assert_bool(model.complete()).is_true()
	assert_array(model.rows().map(func(row: Dictionary): return row.name)).is_equal(["GUEST", "HOST", "AAA"])
	model = _transaction([1000, 1000], 0x81)
	assert_int(model.entry().player).is_equal(0)
	assert_int(model.entry().score).is_equal(1250)
	first = model.submit("ABCDEFGHIJKLMNOPQRSTUVWXYZZZ", false, model.entry().digest)
	assert_str(first.after[0].name).is_equal("ABCDEFGHIJKLMNOPQRSTUVWXYZ *")


func test_cancel_matches_original_shift_and_duplicate_submission_is_idempotent() -> void:
	var model := _transaction([1000, 0])
	var entry: Dictionary = model.entry()
	var result: Dictionary = model.submit("", true, entry.digest)
	assert_array(model.rows().map(func(row: Dictionary): return row.name)).is_equal(["AAA", "AAA", "BBB"])
	assert_dict(model.submit("", true, entry.digest)).is_equal(result)
	assert_dict(model.submit("CHANGED", false, entry.digest)).is_empty()
	assert_bool(model.complete()).is_true()
	model = _transaction([100, 99])
	assert_bool(model.complete()).is_true()


func test_host_profile_owner_replaces_only_target_table_and_preserves_exact_scores() -> void:
	var model := _transaction([1000, 0])
	var bank := []
	for i in 20:
		bank.append(_rows())
	var path := "user://network-score-owner.json"
	var sentinel := FileAccess.open(path, FileAccess.WRITE)
	sentinel.store_string("previous file")
	sentinel.close()
	var profile := Profile.new()
	assert_bool(profile.begin(2, path, bank, 11, model.source)).is_false()
	assert_str(FileAccess.get_file_as_string(path)).is_equal("previous file")
	profile = Profile.new()
	assert_bool(profile.begin(1, path, bank, 11, model.source)).is_true()
	var result: Dictionary = model.submit("HOST", false, model.entry().digest)
	assert_bool(profile.apply(result)).is_true()
	var written := FileAccess.get_file_as_string(path)
	assert_bool(profile.apply(result)).is_true()
	assert_str(FileAccess.get_file_as_string(path)).is_equal(written)
	var saved: Dictionary = JSON.parse_string(written)
	assert_str(saved.tables[11][0].name).is_equal("HOST")
	assert_str(saved.tables[10][0].name).is_equal("AAA")
	assert_str(saved.tables[11][0].score).is_equal("1000")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_profile_conflict_and_write_failure_cannot_apply_a_transaction() -> void:
	var model := _transaction([1000, 0])
	var bank := []
	for i in 20:
		bank.append(_rows())
	var path := "user://network-score-conflict.json"
	var profile := Profile.new()
	assert_bool(profile.begin(1, path, bank, 11, model.source)).is_true()
	var external := FileAccess.open(path, FileAccess.WRITE)
	external.store_string("external change")
	external.close()
	assert_bool(profile.apply(model.submit("HOST", false, model.entry().digest))).is_false()
	assert_str(profile.error).is_equal("changed_profile_file")
	assert_str(FileAccess.get_file_as_string(path)).is_equal("external change")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
