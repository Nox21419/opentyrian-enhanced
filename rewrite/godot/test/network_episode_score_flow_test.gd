extends "res://test/network_campaign_flow_test.gd"


func _ending_session() -> Node:
	var session := _session(true)
	assert_bool(session.continue_player(_current)).is_true()
	_drive(session)
	session.backend.kind = "episode_end"
	session.backend.metadata = {"stop": "episode_end", "screens": []}
	session.backend.sequence = 1
	_drive(session)
	assert_str(_current.scene_file_path).is_equal(Session.ENDING_SCENE)
	return session


func test_live_ending_holds_owner_and_backend_after_both_finishes_without_loading() -> void:
	var session := _ending_session()
	var owner: Node = _current
	owner.completed.emit()
	_drive(session)
	assert_bool(session.ending_checkpoint()).is_false()
	session.backend.story_done = true
	_drive(session)
	assert_bool(session.ending_checkpoint()).is_true()
	assert_bool(owner.released).is_false()
	assert_bool(session.backend.running()).is_true()
	assert_bool(session.backend.adopted).is_false()
	assert_int(session.backend.load_requests).is_equal(0)
	assert_bool(session.can_ready()).is_false()
	assert_bool(session.can_start()).is_false()
	assert_str(session.last_player_exit).is_equal("episode_score_agreed")
	_drive(session)
	assert_object(_current).is_same(owner)


func test_ending_checkpoint_leave_and_stale_callbacks_use_deferred_cleanup() -> void:
	var session := _ending_session()
	var owner: Node = _current
	owner.completed.emit()
	session.backend.story_done = true
	_drive(session)
	owner.failed.emit("left_ending")
	assert_bool(is_instance_valid(session.backend)).is_true()
	await get_tree().process_frame
	assert_bool(owner.released).is_true()
	assert_object(session.backend).is_null()
	assert_str(_current.scene_file_path).is_equal(Session.LOBBY_SCENE)
	var count := _paths.size()
	owner.completed.emit()
	owner.failed.emit("late")
	await get_tree().process_frame
	assert_int(_paths.size()).is_equal(count)


func test_focus_loss_and_external_replacement_release_ending_owner() -> void:
	var session := _ending_session()
	var owner: Node = _current
	session._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	await get_tree().process_frame
	assert_bool(owner.released).is_true()
	assert_object(session.backend).is_null()
	session = _ending_session()
	owner = _current
	_change("res://scenes/title.tscn", Callable())
	_drive(session)
	assert_bool(owner.released).is_true()
	assert_object(session.backend).is_null()
	assert_str(_current.scene_file_path).is_equal("res://scenes/title.tscn")


func test_host_arcade_start_can_route_second_decision_to_the_ending_owner() -> void:
	var session := _session(true)
	assert_bool(session.continue_player(_current)).is_true()
	_drive(session)
	session.backend.sequence = 1
	_drive(session)
	assert_str(_current.scene_file_path).is_equal(Session.ARCADE_SCENE)
	assert_bool(session.start_continuation_from_arcade()).is_true()
	_drive(session)
	session.backend.second_kind = "episode_end"
	session.backend.metadata = {"stop": "episode_end", "screens": []}
	session.backend.sequence = 2
	_drive(session)
	assert_str(_current.scene_file_path).is_equal(Session.ENDING_SCENE)
	assert_int(session.get("_story_sequence")).is_equal(2)
	assert_int(session.backend.load_requests).is_equal(0)
