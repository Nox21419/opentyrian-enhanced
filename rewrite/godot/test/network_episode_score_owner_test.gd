extends "res://test/network_story_owner_test.gd"

const EndingOwner := preload("res://scripts/network_episode_score_owner.gd")


class EndingBackend:
	extends Backend

	func committed_continuation(_decision: int) -> Dictionary:
		return {"digest": SOURCE, "kind": "episode_end", "script": {"stop": "episode_end"}}

	func prepare_episode_score(_decision: int, background: String) -> bool:
		prepared += 1
		var score := {
			"stop": "shop",
			"screens": [{"directive": "]M", "text": PackedStringArray(["ENDING"])}],
			"episode_score":
			{"ending": SOURCE, "hint": SOURCE, "cash": ["0000000000000001", "0000000000000002"], "mutators": 0}
		}
		descriptor = StoryData.prepare(score, SOURCE, {}, background)
		return true


class FastEnding:
	extends "res://scripts/network_episode_score_owner.gd"

	func _wait_with_warning(_units: int) -> void:
		await get_tree().process_frame


func test_ending_owner_prepares_score_waits_for_both_and_back_can_leave_held_finish() -> void:
	for role in [1, 2]:
		var backend := EndingBackend.new()
		backend.role = role
		_nodes.append(backend)
		add_child(backend)
		var owner := FastEnding.new()
		_nodes.push_front(owner)
		assert_bool(owner.bind(backend, 1)).is_true()
		var completed := []
		var failed := []
		owner.completed.connect(func(): completed.append(true))
		owner.failed.connect(func(reason: String): failed.append(reason))
		add_child(owner)
		await _wait_for(func(): return owner.get("_page_ready"))
		assert_int(backend.prepared).is_equal(1)
		backend.committed = 1
		backend.changed.emit()
		await _wait_for(func(): return backend.local_done)
		assert_array(completed).is_empty()
		backend.done = true
		backend.changed.emit()
		assert_int(completed.size()).is_equal(1)
		owner._input(TyrianControls.key_event(KEY_ESCAPE))
		owner._input(TyrianControls.key_event(KEY_ESCAPE))
		assert_array(failed).is_equal(["left_ending"])
		owner.release()


func test_ending_entry_cancellation_does_not_prepare_or_own_backend() -> void:
	var backend := EndingBackend.new()
	_nodes.append(backend)
	add_child(backend)
	var owner := EndingOwner.new()
	_nodes.push_front(owner)
	assert_bool(owner.bind(backend, 1)).is_true()
	add_child(owner)
	await get_tree().process_frame
	owner.release()
	await get_tree().create_timer(0.3).timeout
	assert_int(backend.prepared).is_equal(0)
	assert_bool(backend.running()).is_true()
