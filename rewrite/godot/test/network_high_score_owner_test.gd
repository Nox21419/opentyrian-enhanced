extends "res://test/network_episode_high_scores_test.gd"

const Owner := preload("res://scripts/network_high_score_connection.gd")
const Scores := preload("res://scripts/high_scores.gd")
const ScoreWire := preload("res://scripts/network_high_score_wire.gd")


class Transport:
	extends Node
	var packets := []

	func send_packet(packet: PackedByteArray) -> Error:
		packets.append(packet)
		return OK


func test_owner_save_conflict_does_not_publish_table_or_mutate_guest_profile() -> void:
	var old_path := Scores.SCORES_PATH
	var old_memory := Scores.t2k_high_scores.duplicate(true)
	Scores.SCORES_PATH = "user://network-owner-conflict.json"
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Scores.SCORES_PATH))
	var source := _ending_context(1)
	source[1].stats.cash = 1000000
	source[1].erase("digest")
	source[1]["digest"] = StoryData.digest(source[1])
	source[2].source_result = source[1].digest
	source[2].earned = source[1].stats.duplicate(true)
	source[2].digest = Cursor.proposal_digest(source[2])
	var host := Owner.new()
	var guest := Owner.new()
	for player in [1, 2]:
		var owner: RefCounted = host if player == 1 else guest
		(
			assert_bool(
				owner.begin(
					{"session": "ab".repeat(16), "epoch": 1, "tick": 10, "player": player, "decision": 1},
					source[0],
					source[1],
					source[2],
					source[3]
				)
			)
			. is_true()
		)
	var transport := Transport.new()
	assert_bool(host.settle(transport)).is_true()
	assert_bool(guest.receive(ScoreWire.decode(transport.packets.pop_front(), 1))).is_true()
	assert_object(guest.profile).is_null()
	assert_array(Scores.t2k_high_scores).is_equal(old_memory)
	assert_bool(FileAccess.file_exists(Scores.SCORES_PATH)).is_false()
	host.flow.ready(1, Time.get_ticks_msec())
	guest.flow.ready(1, Time.get_ticks_msec())
	assert_bool(host.settle(transport)).is_true()
	assert_bool(guest.receive(ScoreWire.decode(transport.packets.pop_front(), 1))).is_true()
	assert_bool(guest.settle(transport)).is_true()
	assert_bool(host.receive(ScoreWire.decode(transport.packets.pop_front(), 2))).is_true()
	var file := FileAccess.open(Scores.SCORES_PATH, FileAccess.WRITE)
	file.store_string("external edit")
	file.close()
	assert_bool(host.flow.submit("HOST", false, Time.get_ticks_msec())).is_true()
	assert_bool(host.settle(transport)).is_false()
	assert_str(host.error).is_equal("changed_profile_file")
	assert_array(transport.packets).is_empty()
	assert_str(guest.flow.snapshot().phase).is_equal("name")
	assert_str(FileAccess.get_file_as_string(Scores.SCORES_PATH)).is_equal("external edit")
	assert_array(Scores.t2k_high_scores).is_equal(old_memory)
	transport.free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Scores.SCORES_PATH))
	Scores.SCORES_PATH = old_path
	Scores.t2k_high_scores = old_memory
