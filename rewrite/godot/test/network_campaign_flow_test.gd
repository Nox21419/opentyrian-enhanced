extends GdUnitTestSuite

const Session := preload("res://scripts/network_session.gd")
const Fixture := preload("res://test/fixtures/network_setup.gd")
var _nodes: Array[Node] = []
var _paths: Array[String] = []
var _current: Node
var _rate := 35


class Backend:
	extends Node
	signal changed
	var stopped := false
	var sequence := 0
	var kind := "shop"
	var proposals := []
	var loaded := false
	var committed := false
	var adopted := false
	var begins := 0
	var load_requests := 0
	var metadata := {}

	func configuration() -> Dictionary:
		return Fixture.configuration()

	func running() -> bool:
		return not stopped

	func completion_agreed() -> bool:
		return true

	func result_committed_phase() -> int:
		return 3

	func continuation_sequence() -> int:
		return sequence

	func propose_continuation(value: int) -> bool:
		proposals.append(value)
		changed.emit()
		return true

	func prepare_continuation(_value: int) -> bool:
		begins += 1
		changed.emit()
		return true

	func committed_continuation(value: int) -> Dictionary:
		return {
			"sequence": value,
			"kind": kind if value == 1 else "level",
			"script": metadata.duplicate(true),
			"earned": {"cash": 1200, "cash2": 2400}
		}

	func prepare_next_level(_value: int, seed: String) -> bool:
		load_requests += 1
		return seed.length() == 16

	func next_level_loaded() -> bool:
		return loaded

	func next_level_load_committed() -> bool:
		return committed

	func commit_next_level_load() -> bool:
		committed = true
		changed.emit()
		return true

	func adopt_next_level() -> bool:
		adopted = committed
		changed.emit()
		return adopted

	func stop() -> void:
		stopped = true


class View:
	extends Node
	var detached := false
	var controller: Node
	var use_entry_fade := false
	var _touch_pause := false
	var _handoff := false

	func disable_network_input() -> void:
		pass

	func _detach() -> void:
		detached = true

	func bind(connection: Node) -> bool:
		return connection.adopted


func before_test() -> void:
	_rate = Engine.physics_ticks_per_second
	_paths.clear()
	_current = null


func after_test() -> void:
	for node in _nodes:
		if is_instance_valid(node):
			node.free()
	_nodes.clear()
	Engine.physics_ticks_per_second = _rate
	await get_tree().process_frame


func _change(path: String, prepare: Callable) -> Node:
	_paths.append(path)
	var view := View.new()
	view.scene_file_path = path
	_nodes.push_front(view)
	if prepare.is_valid() and not prepare.call(view):
		return null
	_current = view
	return view


func _session(hosting: bool) -> Node:
	var session := Session.new()
	add_child(session)
	_nodes.append(session)
	session.set_process(false)  # Drive deferred states explicitly in this fixture.
	session.platform_name = func(): return "Android"
	session.scene_change = _change
	session.current_scene = func(): return _current
	session.lobby.hosting = hosting
	var backend := Backend.new()
	add_child(backend)
	session.backend = backend
	_nodes.append(backend)
	var view := View.new()
	_nodes.push_front(view)
	_current = view
	session.set("_player_scene", view)
	return session


func _drive(session: Node) -> void:
	session._advance_progress(session.backend.get_instance_id(), session.get("_progress_generation"))


func test_host_routes_original_arcade_then_loads_and_replaces_without_stopping_backend() -> void:
	var session := _session(true)
	var backend: Node = session.backend
	var old: Node = _current
	assert_bool(session.continue_player(old)).is_true()
	_drive(session)
	_drive(session)
	assert_array(backend.proposals).is_equal([1])
	backend.sequence = 1
	_drive(session)
	assert_bool(old.detached).is_true()
	assert_str(_paths.back()).is_equal(Session.ARCADE_SCENE)
	assert_bool(session.selecting_arcade).is_true()
	assert_bool(backend.stopped).is_false()
	assert_str(session.continuation_cash(0)).is_equal("1200")
	assert_bool(session.can_ready()).is_false()
	assert_bool(session.can_start()).is_false()
	assert_bool(session.start_continuation_from_arcade()).is_true()
	_drive(session)
	_drive(session)
	assert_array(backend.proposals).is_equal([1, 2])
	backend.sequence = 2
	_drive(session)
	_drive(session)
	assert_int(backend.load_requests).is_equal(1)
	_drive(session)
	assert_int(backend.load_requests).is_equal(1)
	backend.loaded = true
	_drive(session)
	_drive(session)
	assert_str(_paths.back()).is_equal(Session.PLAYER_SCENE)
	assert_bool(session.continuing).is_false()
	assert_bool(backend.adopted).is_true()
	assert_bool(backend.stopped).is_false()
	assert_str(session.last_player_exit).is_equal("continued")
	assert_bool(_current.use_entry_fade).is_true()
	# An intentional old-view exit must not stop the new scene's backend.
	session.player_scene_exited(old)
	assert_bool(backend.stopped).is_false()


func test_guest_waits_then_adopts_only_after_host_decisions_and_commit() -> void:
	var session := _session(false)
	var backend: Node = session.backend
	assert_bool(session.continue_player(_current)).is_true()
	_drive(session)
	assert_int(backend.begins).is_equal(1)
	backend.sequence = 1
	_drive(session)
	assert_str(_paths.back()).is_equal(Session.LOBBY_SCENE)
	assert_bool(session.selecting_arcade).is_false()
	assert_bool(session.start_continuation_from_arcade()).is_false()
	backend.sequence = 2
	_drive(session)
	_drive(session)
	assert_int(backend.load_requests).is_equal(0)
	assert_bool(backend.adopted).is_false()
	backend.committed = true
	_drive(session)
	assert_bool(backend.adopted).is_true()
	assert_str(_paths.back()).is_equal(Session.PLAYER_SCENE)


func test_unsupported_effects_and_stale_generations_cannot_revive_scenes() -> void:
	var session := _session(true)
	var backend: Node = session.backend
	assert_bool(session.continue_player(_current)).is_true()
	var generation: int = session.get("_progress_generation")
	var backend_id := backend.get_instance_id()
	_drive(session)
	backend.sequence = 1
	backend.metadata = {"autosave": true}
	_drive(session)
	assert_bool(is_instance_valid(backend)).is_false()
	assert_str(session.last_player_exit).is_equal("unsupported_continuation_route")
	var count := _paths.size()
	session._advance_progress(backend_id, generation)
	assert_int(_paths.size()).is_equal(count)


func test_unsigned_cash_text_and_original_rate_restore_survive_multiple_levels() -> void:
	var session := _session(true)
	session.set("_progress_candidate", {"earned": {"cash": -1, "cash2": -9223372036854775807 - 1}})
	assert_str(session.continuation_cash(0)).is_equal("18446744073709551615")
	assert_str(session.continuation_cash(1)).is_equal("9223372036854775808")
	var first := View.new()
	_nodes.push_front(first)
	session.backend.adopted = true
	Engine.physics_ticks_per_second = 60
	assert_bool(session._prepare_player(first)).is_true()
	var second := View.new()
	_nodes.push_front(second)
	assert_bool(session._prepare_player(second)).is_true()
	session.stop()
	assert_int(Engine.physics_ticks_per_second).is_equal(60)


func test_scene_exit_cleanup_is_deferred_and_bound_to_the_exited_backend() -> void:
	var session := _session(true)
	var original: Node = session.backend
	var original_id := original.get_instance_id()
	session.player_scene_exited(_current)
	assert_bool(is_instance_valid(original)).is_true()
	var replacement := Backend.new()
	add_child(replacement)
	_nodes.append(replacement)
	session.backend = replacement
	session._stop_after_player_exit(original_id)
	await get_tree().process_frame
	assert_bool(is_instance_valid(replacement)).is_true()
	assert_bool(replacement.stopped).is_false()


func test_focus_loss_during_interlude_cancels_pending_scene_work() -> void:
	var session := _session(false)
	assert_bool(session.continue_player(_current)).is_true()
	session._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	await get_tree().process_frame
	assert_bool(session.continuing).is_false()
	assert_object(session.backend).is_null()
	assert_str(session.last_player_exit).is_equal("continuation_focus_lost")
	assert_str(_paths.back()).is_equal(Session.LOBBY_SCENE)
