extends GdUnitTestSuite

const Player := preload("res://scripts/network_player.gd")
const Result := preload("res://scripts/network_level_result.gd")
const Fixture := preload("res://test/fixtures/network_setup.gd")
const FinishedSimulation := preload("res://test/network_level_result_test.gd").FinishedSimulation
var _nodes: Array[Node] = []


class Backend:
	extends Node
	signal changed
	var native: Node
	var result: RefCounted
	var role := 1
	var matched := false
	var phase := 0
	var captures: Array = []
	var ready_stages: Array[int] = []
	var requests: Array[int] = []
	var stopped := false

	func simulation_for_view() -> Node:
		return null if stopped else native

	func configuration() -> Dictionary:
		return Fixture.configuration()

	func player_for_view() -> int:
		return role

	func inputs_quiesced() -> bool:
		return not captures.is_empty()

	func note_level_result(tick: int, title: String, elapsed: int) -> bool:
		captures.append([tick, title, elapsed])
		changed.emit()
		return true

	func completion_agreed() -> bool:
		return matched and not stopped

	func diagnostic_digest() -> String:
		return native.network_diagnostic_digest()

	func result_for_view() -> RefCounted:
		return result

	func result_elapsed_seconds() -> int:
		return 125

	func result_committed_phase() -> int:
		return phase

	func mark_result_screen_ready(stage: int) -> bool:
		ready_stages.append(stage)
		changed.emit()
		return true

	func request_result_advance(stage: int) -> bool:
		requests.append(stage)
		return role == 1

	func commit(stage: int) -> void:
		phase = stage
		changed.emit()

	func stop() -> void:
		stopped = true
		changed.emit()


class Owner:
	extends Node
	var reasons: Array[String] = []

	func leave_player(view: Node, reason: String) -> void:
		reasons.append(reason)
		view.backend.stop()

	func player_scene_exited(_view: Node) -> void:
		pass


class EndedFixtureView:
	extends "res://scripts/network_player.gd"

	func _ready() -> void:
		set_physics_process(false)


func after_test() -> void:
	for node in _nodes:
		if is_instance_valid(node):
			node.free()
	_nodes.clear()
	Music.release_streams()
	Sfx.release_streams()
	await get_tree().process_frame
	await get_tree().process_frame


func _wait(condition: Callable) -> bool:
	var deadline := Time.get_ticks_msec() + 12000
	while not condition.call() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	assert_bool(condition.call()).is_true()
	return condition.call()


func _shot(screen: Node, role: int, stage: String) -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--network-player-completion-shots="):
			var dir := arg.trim_prefix("--network-player-completion-shots=")
			assert_int(screen.vga.image(0).save_png(dir.path_join("network-live-%s-%d.png" % [stage, role]))).is_equal(
				OK
			)


## Controlled successful-result fixture over a real native renderer. This does
## not claim a naturally won level or replace the real ENet completion suite.
func _view(role: int, alive := true) -> Node:
	var native: Node = ClassDB.instantiate("TyrianSim")
	_nodes.append(native)
	var mods: RefCounted = ClassDB.instantiate("TyrianMods")
	mods.load(Game.data_dir, PackedStringArray())
	native.set_mods(mods)
	assert_bool(native.prepare_network_level(Game.data_dir, Fixture.configuration())).is_true()
	var backend := Backend.new()
	_nodes.push_front(backend)
	backend.native = native
	backend.role = role
	var snapshot := FinishedSimulation.new()
	snapshot.digest = native.network_diagnostic_digest()
	snapshot.cash = [1200, 2400]
	snapshot.values.any_player_alive = alive
	snapshot.values.all_players_alive = alive
	snapshot.values["credits_start"] = 1100
	backend.result = Result.new()
	add_child(backend)
	var owner := Owner.new()
	add_child(owner)
	_nodes.push_front(owner)
	var view := Player.new()
	assert_bool(view.bind(backend)).is_true()
	view.set("_touch_pause", true)
	view.controller = owner
	add_child(view)
	_nodes.push_front(view)
	view.set_physics_process(false)
	view.set("_level_started_ms", Time.get_ticks_msec() - 125000)
	snapshot.digest = native.network_diagnostic_digest()  # After initial observer queues are presented.
	assert_bool(backend.result.capture(snapshot, Fixture.configuration(), "TYRIAN", 47)).is_true()
	snapshot.free()
	return view


func test_both_roles_wait_for_results_and_display_original_screens_then_wait_for_peer_fade() -> void:
	for role in [1, 2]:
		var view := _view(role)
		var backend: Node = view.backend
		var digest: String = backend.diagnostic_digest()
		view._begin_completion()
		view._begin_completion()
		assert_int(backend.captures.size()).is_equal(1)
		assert_int(backend.captures[0][2]).is_equal(125 if role == 1 else 0)
		assert_object(view.get("_debrief")).is_null()
		assert_bool(view.is_physics_processing()).is_false()
		assert_bool(view.get("_network_input_enabled")).is_true()  # Focus-loss guard stays armed.
		backend.matched = true
		backend.changed.emit()
		var screen: Node = view.get("_debrief")
		assert_object(screen).is_not_null()
		if screen == null:
			assert_array(view.controller.reasons).is_empty()
			return
		assert_bool(screen.get("_frozen")).is_true()
		assert_str(backend.diagnostic_digest()).is_equal(digest)
		if not await _wait(func(): return screen.idle):
			return
		assert_array(backend.ready_stages).is_equal([1])
		_shot(screen, role, "summary")
		backend.commit(1)
		if not await _wait(func(): return screen.stats_shown):
			return
		_shot(screen, role, "statistics")
		screen.handle_action(TyrianControls.ACCEPT)
		assert_array(backend.requests).is_equal([2] if role == 1 else [])
		assert_array(view.controller.reasons).is_empty()
		backend.commit(2)
		if not await _wait(func(): return backend.ready_stages.has(3)):
			return
		assert_array(view.controller.reasons).is_empty()
		assert_array(backend.requests).is_equal([2, 3] if role == 1 else [])
		assert_str(backend.diagnostic_digest()).is_equal(digest)
		backend.commit(3)
		assert_array(view.controller.reasons).is_equal(["first_level_complete"])
		assert_bool(backend.stopped).is_true()
		assert_object(view.sim).is_null()
		view.free()
		await get_tree().process_frame


func test_all_dead_result_exits_after_agreement_without_opening_successful_debrief() -> void:
	var view := _view(1, false)
	view._begin_completion()
	assert_array(view.controller.reasons).is_empty()
	view.backend.matched = true
	view.backend.changed.emit()
	assert_array(view.controller.reasons).is_equal(["game_over"])
	assert_object(view.get("_debrief")).is_null()


func test_focus_loss_during_result_wait_stops_backend_and_detaches_borrowed_native() -> void:
	var view := _view(2)
	view._begin_completion()
	view._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert_bool(view.backend.stopped).is_true()
	assert_object(view.sim).is_null()
	assert_bool(view.visible).is_false()


func test_changed_final_native_state_refuses_debrief_binding() -> void:
	var view := _view(1)
	view._begin_completion()
	# Fixture changes the agreed record, never the running native simulation.
	view.backend.result.set("_record", {"core": "ff".repeat(32)})
	view.backend.matched = true
	view.backend.changed.emit()
	assert_array(view.controller.reasons).is_equal(["changed_final_state"])
	assert_object(view.get("_debrief")).is_null()


func test_physics_completion_routes_final_presented_tick_once_without_restarting_clock() -> void:
	var native := FinishedSimulation.new()
	_nodes.append(native)
	var backend := Backend.new()
	backend.native = native
	add_child(backend)
	_nodes.push_front(backend)
	var owner := Owner.new()
	add_child(owner)
	_nodes.push_front(owner)
	var view := EndedFixtureView.new()
	view.backend = backend
	view.sim = native
	view.controller = owner
	view.player = 1
	view.set("_presentation_ready", true)
	view.set("_presented_tick", 47)
	view.set("_network_level_name", "TYRIAN")
	view.set("_level_started_ms", Time.get_ticks_msec() - 125000)
	backend.changed.connect(view._backend_changed)
	add_child(view)
	_nodes.push_front(view)
	view._physics_process(0.01)
	view._physics_process(0.01)
	assert_array(backend.captures).is_equal([[47, "TYRIAN", 125]])
	assert_bool(view.get("_network_clock_enabled")).is_false()
	assert_array(owner.reasons).is_empty()
