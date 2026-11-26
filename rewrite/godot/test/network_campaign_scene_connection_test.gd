## Controlled successful-route fixture after natural terminal completion.
## Real session drivers/ENet/native nodes; interlude scenes are fixture nodes.
extends "res://test/network_runner_adoption_connection_test.gd"

const SessionDriver := preload("res://scripts/network_session.gd")


class ShopRoute:
	extends RefCounted
	var error := ""
	var include_story := false
	var _proposal := {}
	var _campaign: RefCounted = ClassDB.instantiate("TyrianCampaign")

	func _init() -> void:
		_campaign.load(Game.data_dir)

	func completed(record: Dictionary) -> Dictionary:
		if _proposal.is_empty():
			_proposal = {
				"format_version": 1,
				"sequence": 1,
				"kind": "shop",
				"episode": 1,
				"initial_difficulty": 2,
				"network_difficulty": 3,
				"source_result": record.digest,
				"source_configuration": record.config,
				"earned": record.stats.duplicate(true),
				"requires_loader_adaptation": true,
				"difficulty_rule_review_required": false,
				"script": _campaign.run_script(1, 4, 2, 11, false, 0, true, 0)
			}
			if include_story:
				_proposal.script["screens"] = [{"directive": "]W 00[", "text": PackedStringArray(["BEFORE SHOP"])}]
			_proposal["digest"] = CursorBuilder.proposal_digest(_proposal)
		return _proposal.duplicate(true)

	func preview_arcade_start(parent: String) -> Dictionary:
		var proposal := _proposal.duplicate(true)
		var map: PackedInt32Array = proposal.script.map
		proposal["entry"] = proposal.script.duplicate(true)
		proposal.script = _campaign.run_script(1, map[map.size() - 1], 2, 11, false, 0, true, 0)
		proposal.kind = proposal.script.stop
		proposal.sequence = 2
		proposal["parent"] = parent
		proposal["action"] = "arcade_start"
		if include_story:
			proposal.script["screens"] = [{"directive": "]W 00[", "text": PackedStringArray(["AFTER SHOP"])}]
		proposal.digest = CursorBuilder.proposal_digest(proposal)
		return proposal


class Interlude:
	extends Node
	var _handoff := false


class FreshPlayer:
	extends "res://scripts/network_player.gd"

	func _ready() -> void:
		super._ready()
		set_physics_process(false)  # This test drives exact tick/presentation pairs.


class Scenes:
	extends RefCounted
	var current: Node
	var parent: Node
	var track: Callable
	var paths: Array[String] = []

	func read() -> Node:
		return current

	func change(path: String, prepare: Callable) -> Node:
		paths.append(path)
		var scene: Node
		if path == SessionDriver.PLAYER_SCENE:
			scene = FreshPlayer.new()
		elif path == SessionDriver.STORY_SCENE:
			scene = load("res://scripts/network_story_owner.gd").new()
		else:
			scene = Interlude.new()
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


func _track_scene(scene: Node) -> void:
	_nodes.push_front(scene)


func test_session_drivers_cross_original_shop_route_and_replace_both_player_scenes() -> void:
	var pair := await _terminal_pair()
	if pair.is_empty():
		return
	var peers: Array = pair[0]
	var old_nodes := [peers[0].simulation_for_view(), peers[1].simulation_for_view()]
	var drivers := []
	var scenes := []
	for i in 2:
		peers[i].set("_campaign_cursor", ShopRoute.new())
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
	# Production enters this owner only for a surviving result. This controlled
	# route bypasses that UI condition to test transport/scene lifetime, not wins.
	for i in 2:
		assert_bool(drivers[i].continue_player(pair[1][i])).is_true()
	await _wait_decision(func(): return drivers[0].selecting_arcade and scenes[1].paths.has(SessionDriver.LOBBY_SCENE))
	assert_str(scenes[0].paths.back()).is_equal(SessionDriver.ARCADE_SCENE)
	for native in old_nodes:
		assert_bool(is_instance_valid(native)).is_true()
	assert_bool(drivers[0].start_continuation_from_arcade()).is_true()
	# The original Arcade Start returns the host to its existing lobby.
	drivers[0]._move_progress_scene(SessionDriver.LOBBY_SCENE)
	await _wait_decision(func(): return not drivers[0].continuing and not drivers[1].continuing)
	for i in 2:
		assert_str(drivers[i].last_player_exit).is_equal("continued")
		assert_str(scenes[i].paths.back()).is_equal(SessionDriver.PLAYER_SCENE)
		assert_bool(is_instance_valid(old_nodes[i])).is_false()
		assert_int(peers[i].ticks_executed()).is_equal(0)
		assert_str(scenes[i].current.get("_network_level_name")).is_not_empty()
		assert_bool(peers[i].mark_view_ready()).is_true()
	await _wait(func(): return peers[0].views_ready() and peers[1].views_ready())
	var deadline := Time.get_ticks_msec() + 10000
	while (peers[0].ticks_executed() < 35 or peers[1].ticks_executed() < 35) and Time.get_ticks_msec() < deadline:
		await _step(peers, [scenes[0].current, scenes[1].current], 35)
	assert_int(peers[0].ticks_executed()).is_equal(35)
	assert_int(peers[1].ticks_executed()).is_equal(35)
	assert_str(peers[0].diagnostic_digest()).is_equal(peers[1].diagnostic_digest())
