## Controlled ending route with real session drivers, owners, ENet and native state.
extends "res://test/network_episode_score_connection_test.gd"

const SessionDriver := preload("res://scripts/network_session.gd")
const SceneFixtures := preload("res://test/network_campaign_scene_connection_test.gd")


class FastEnding:
	extends "res://scripts/network_episode_score_owner.gd"

	func _wait_with_warning(_units: int) -> void:
		await get_tree().process_frame


class EndingScenes:
	extends SceneFixtures.Scenes

	func change(path: String, prepare: Callable) -> Node:
		if path != SessionDriver.ENDING_SCENE:
			return super.change(path, prepare)
		paths.append(path)
		var scene := FastEnding.new()
		scene.scene_file_path = path
		if prepare.is_valid() and not prepare.call(scene):
			scene.free()
			return null
		if is_instance_valid(current) and current.get_parent() != null:
			current.get_parent().remove_child(current)
			current.queue_free()
		current = scene
		track.call(scene)
		parent.add_child(scene)
		return scene


func _track_ending(scene: Node) -> void:
	_nodes.push_front(scene)


func test_live_ending_owners_hold_agreed_black_checkpoint_and_both_leave_cleanly() -> void:
	var pair := await _terminal_pair(true)
	if pair.is_empty():
		return
	var peers: Array = pair[0]
	var old := [peers[0].simulation_for_view(), peers[1].simulation_for_view()]
	var tick: int = peers[0].ticks_executed()
	var diagnostic: String = peers[0].diagnostic_digest()
	var drivers := []
	var scenes := []
	for i in 2:
		peers[i].set("_campaign_cursor", ScoreCandidate.new())
		var driver := SessionDriver.new()
		add_child(driver)
		_nodes.append(driver)
		driver.backend = peers[i]
		driver.lobby.hosting = i == 0
		driver.platform_name = func(): return "Android"
		driver.set("_player_scene", pair[1][i])
		var fixture := EndingScenes.new()
		fixture.current = pair[1][i]
		fixture.parent = self
		fixture.track = _track_ending
		driver.current_scene = fixture.read
		driver.scene_change = fixture.change
		peers[i].changed.connect(driver._backend_changed)
		drivers.append(driver)
		scenes.append(fixture)
	for i in 2:
		assert_bool(drivers[i].continue_player(pair[1][i])).is_true()
	for page in [1, 2]:
		await _wait_decision(
			func():
				return (
					scenes[0].current.scene_file_path == SessionDriver.ENDING_SCENE
					and scenes[1].current.scene_file_path == SessionDriver.ENDING_SCENE
					and scenes[0].current.get("_page") == page
					and scenes[1].current.get("_page") == page
					and scenes[0].current.get("_page_ready")
					and scenes[1].current.get("_page_ready")
				)
		)
		assert_dict(scenes[0].current.presentation_descriptor()).is_equal(scenes[1].current.presentation_descriptor())
		assert_bool(drivers[0].ending_checkpoint()).is_false()
		scenes[1].current._input(TyrianControls.key_event(KEY_SPACE))
		await get_tree().process_frame
		assert_int(peers[0].story_committed_page(1)).is_equal(page - 1)
		scenes[0].current._input(TyrianControls.key_event(KEY_SPACE))
		await _wait_decision(
			func(): return peers[0].story_committed_page(1) == page and peers[1].story_committed_page(1) == page
		)
	await _wait_decision(func(): return drivers[0].ending_checkpoint() and drivers[1].ending_checkpoint())
	for i in 2:
		assert_bool(peers[i].running()).is_true()
		assert_object(peers[i].simulation_for_view()).is_same(old[i])
		assert_int(peers[i].ticks_executed()).is_equal(tick)
		assert_str(peers[i].diagnostic_digest()).is_equal(diagnostic)
		assert_dict(peers[i].next_level_request()).is_empty()
		assert_bool(peers[i].episode_end_plan().effects.applied).is_false()
		assert_str(scenes[i].current.scene_file_path).is_equal(SessionDriver.ENDING_SCENE)
		assert_bool(scenes[i].current.get("_released")).is_false()
		assert_int(scenes[i].paths.count(SessionDriver.ENDING_SCENE)).is_equal(1)
	# Back on the guest leaves the checkpoint; disconnect cleanup returns the host.
	scenes[1].current._input(TyrianControls.key_event(KEY_ESCAPE))
	await _wait_decision(func(): return not drivers[0].continuing and not drivers[1].continuing)
	for i in 2:
		assert_object(drivers[i].backend).is_null()
		assert_str(scenes[i].current.scene_file_path).is_equal(SessionDriver.LOBBY_SCENE)
		assert_bool(is_instance_valid(old[i])).is_false()
	assert_str(drivers[1].last_player_exit).is_equal("left_ending")
