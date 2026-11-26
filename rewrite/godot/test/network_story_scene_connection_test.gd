## Real original story owners, session drivers, ENet and fresh native adoption.
## The successful route is controlled after natural terminal completion.
extends "res://test/network_campaign_scene_connection_test.gd"


func test_both_story_decisions_finish_before_shop_and_fresh_level_adoption() -> void:
	var pair := await _terminal_pair()
	if pair.is_empty():
		return
	var peers: Array = pair[0]
	var old_nodes := [peers[0].simulation_for_view(), peers[1].simulation_for_view()]
	var drivers := []
	var scenes := []
	for i in 2:
		var route := ShopRoute.new()
		route.include_story = true
		peers[i].set("_campaign_cursor", route)
		var driver := SessionDriver.new()
		add_child(driver)
		_nodes.append(driver)
		driver.backend = peers[i]
		driver.lobby.hosting = i == 0
		driver.platform_name = func(): return "Android"
		driver.set("_player_scene", pair[1][i])
		var fixture := Scenes.new()
		fixture.current = pair[1][i]
		fixture.parent = self
		fixture.track = _track_scene
		driver.current_scene = fixture.read
		driver.scene_change = fixture.change
		peers[i].changed.connect(driver._backend_changed)
		drivers.append(driver)
		scenes.append(fixture)
	for i in 2:
		assert_bool(drivers[i].continue_player(pair[1][i])).is_true()
	await _advance_story(scenes, peers, 1)
	await _wait_decision(
		func(): return drivers[0].selecting_arcade and scenes[1].current.scene_file_path == SessionDriver.LOBBY_SCENE
	)
	assert_str(scenes[0].current.scene_file_path).is_equal(SessionDriver.ARCADE_SCENE)
	for i in 2:
		assert_bool(peers[i].story_complete(1)).is_true()
		assert_bool(is_instance_valid(old_nodes[i])).is_true()
	assert_bool(drivers[0].start_continuation_from_arcade()).is_true()
	drivers[0]._move_progress_scene(SessionDriver.LOBBY_SCENE)
	await _advance_story(scenes, peers, 2)
	await _wait_decision(func(): return not drivers[0].continuing and not drivers[1].continuing)
	for i in 2:
		assert_str(drivers[i].last_player_exit).is_equal("continued")
		assert_str(scenes[i].current.scene_file_path).is_equal(SessionDriver.PLAYER_SCENE)
		assert_bool(is_instance_valid(old_nodes[i])).is_false()
		assert_int(peers[i].ticks_executed()).is_equal(0)
		assert_int(scenes[i].paths.count(SessionDriver.STORY_SCENE)).is_equal(2)
		assert_bool(peers[i].mark_view_ready()).is_true()
	await _wait(func(): return peers[0].views_ready() and peers[1].views_ready())
	var deadline := Time.get_ticks_msec() + 10000
	while (peers[0].ticks_executed() < 35 or peers[1].ticks_executed() < 35) and Time.get_ticks_msec() < deadline:
		await _step(peers, [scenes[0].current, scenes[1].current], 35)
	assert_int(peers[0].ticks_executed()).is_equal(35)
	assert_int(peers[1].ticks_executed()).is_equal(35)
	assert_str(peers[0].diagnostic_digest()).is_equal(peers[1].diagnostic_digest())


func _advance_story(scenes: Array, peers: Array, decision: int) -> void:
	await _wait_decision(
		func():
			return (
				scenes[0].current.scene_file_path == SessionDriver.STORY_SCENE
				and scenes[1].current.scene_file_path == SessionDriver.STORY_SCENE
				and scenes[0].current.get("_page_ready")
				and scenes[1].current.get("_page_ready")
			)
	)
	assert_bool(peers[0].story_complete(decision)).is_false()
	assert_bool(peers[1].story_complete(decision)).is_false()
	var guest: Node = scenes[1].current
	var host: Node = scenes[0].current
	var key := InputEventKey.new()
	key.keycode = KEY_SPACE
	key.pressed = true
	guest._input(key)
	await get_tree().process_frame
	assert_int(peers[0].story_committed_page(decision)).is_equal(0)
	host._input(key)
	await _wait_decision(func(): return peers[0].story_complete(decision) and peers[1].story_complete(decision))
