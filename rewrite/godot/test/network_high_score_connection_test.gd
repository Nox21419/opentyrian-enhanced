extends "res://test/network_episode_score_connection_test.gd"

const Scores := preload("res://scripts/high_scores.gd")
var _saved_score_path := ""
var _saved_score_memory := []


class ShootingConnection:
	extends CountedConnection

	func capture_local(frame: Dictionary) -> bool:
		var firing := frame.duplicate()
		firing.mouse_mask |= Game.MASK_FIRE
		return super.capture_local(firing)


func _new_connection() -> Node:
	return ShootingConnection.new()


func before_test() -> void:
	_saved_score_path = Scores.SCORES_PATH
	_saved_score_memory = Scores.t2k_high_scores.duplicate(true)
	Scores.SCORES_PATH = "user://network-live-high-scores.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Scores.SCORES_PATH))


func after_test() -> void:
	await super.after_test()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Scores.SCORES_PATH))
	Scores.SCORES_PATH = _saved_score_path
	Scores.t2k_high_scores = _saved_score_memory


func test_live_high_score_no_qualification_agrees_without_profile_write() -> void:
	var bank := Scores.default_high_scores()
	for rows in bank:
		for row in rows:
			row.score = 2147483647
	Scores.t2k_high_scores = bank
	Scores.save_scores()
	var original := FileAccess.get_file_as_string(Scores.SCORES_PATH)
	var peers := await _completed_score_pair()
	if peers.is_empty():
		return
	var core: String = peers[0].diagnostic_digest()
	assert_bool(peers[1].prepare_high_scores(1)).is_true()
	assert_bool(peers[1].high_score_action("edit", 1, "INVALID")).is_false()
	assert_bool(peers[0].prepare_high_scores(1)).is_true()
	await _wait_decision(func(): return not peers[1].high_scores_for_view().is_empty())
	assert_bool(peers[1].prepare_high_scores(1)).is_true()
	assert_dict(peers[0].high_scores_for_view()).is_equal(peers[1].high_scores_for_view())
	assert_str(peers[0].high_scores_for_view().phase).is_equal("done")
	for peer in peers:
		assert_bool(peer.high_score_action("ready", 1)).is_true()
	await _wait_decision(
		func():
			return (
				peers[0].get("_high_scores").flow.get("_remote_ready")
				and peers[1].get("_high_scores").flow.get("_remote_ready")
			)
	)
	for peer in peers:
		assert_bool(peer.high_score_action("finish", 1)).is_true()
	await _wait_decision(func(): return peers[0].high_scores_complete() and peers[1].high_scores_complete())
	assert_str(FileAccess.get_file_as_string(Scores.SCORES_PATH)).is_equal(original)
	for peer in peers:
		assert_str(peer.diagnostic_digest()).is_equal(core)
		assert_bool(peer.prepare_high_scores(1)).is_true()
		assert_bool(peer.high_scores_complete()).is_true()
		assert_str(peer.error).is_empty()
	assert_object(peers[1].get("_high_scores").profile).is_null()


func test_live_host_names_and_save_wait_for_guest_view_and_preserve_other_tables() -> void:
	var bank := Scores.default_high_scores()
	for row in bank[11]:
		row.score = 0
	Scores.t2k_high_scores = bank
	Scores.save_scores()
	var original := FileAccess.get_file_as_string(Scores.SCORES_PATH)
	var peers := await _completed_score_pair()
	if peers.is_empty():
		return
	var core: String = peers[0].diagnostic_digest()
	assert_bool(peers[0].prepare_high_scores(1)).is_true()
	assert_bool(peers[0].high_score_action("ready", 1)).is_true()
	assert_bool(peers[0].high_score_action("edit", 1, "HOST ENTERED P2")).is_true()
	await _wait_decision(func(): return peers[1].high_scores_for_view().get("text") == "HOST ENTERED P2")
	assert_object(peers[1].get("_high_scores").profile).is_null()
	assert_bool(peers[0].high_score_action("submit", 1, "HOST ENTERED P2")).is_true()
	assert_str(FileAccess.get_file_as_string(Scores.SCORES_PATH)).is_equal(original)
	assert_bool(peers[1].prepare_high_scores(1)).is_true()
	assert_bool(peers[1].high_score_action("submit", 1, "GUEST")).is_false()
	var names := ["HOST ENTERED P2", "HOST ENTERED NEXT"]
	var name_index := 0
	while peers[0].high_scores_for_view().phase != "done":
		var stage: Dictionary = peers[0].high_scores_for_view()
		assert_bool(peers[0].high_score_action("ready", stage.serial)).is_true()
		assert_bool(peers[1].high_score_action("ready", stage.serial)).is_true()
		if stage.phase == "name":
			assert_bool(peers[0].high_score_action("submit", stage.serial, names[name_index])).is_true()
			name_index += 1
		else:
			assert_bool(peers[0].high_score_action("advance", stage.serial)).is_true()
		await _wait_decision(
			func():
				return (
					peers[0].high_scores_for_view().serial > stage.serial
					and peers[1].high_scores_for_view().serial > stage.serial
				)
		)
	assert_int(name_index).is_equal(2)
	var written: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Scores.SCORES_PATH))
	assert_str(written.tables[11][0].name).is_equal(names[0])
	assert_str(written.tables[11][1].name).is_equal(names[1])
	# Compare primitive fields, allowing the writer's exact decimal encoding.
	for i in 3:
		assert_int(int(written.tables[10][i].score)).is_equal(bank[10][i].score)
		assert_str(written.tables[10][i].name).is_equal(bank[10][i].name)
	for peer in peers:
		assert_str(peer.diagnostic_digest()).is_equal(core)
		assert_bool(peer.high_score_action("ready", 5)).is_true()
	await _wait_decision(
		func():
			return (
				peers[0].get("_high_scores").flow.get("_remote_ready")
				and peers[1].get("_high_scores").flow.get("_remote_ready")
			)
	)
	for peer in peers:
		assert_bool(peer.high_score_action("finish", 5)).is_true()
	await _wait_decision(func(): return peers[0].high_scores_complete() and peers[1].high_scores_complete())
