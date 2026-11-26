extends GdUnitTestSuite

const Owner := preload("res://scripts/network_story_owner.gd")
const StoryData := preload("res://scripts/network_story_script.gd")
const SOURCE := "abababababababababababababababababababababababababababababababab"
var _nodes: Array[Node] = []


class Backend:
	extends Node
	signal changed
	var role := 1
	var alive := true
	var done := false
	var local_done := false
	var committed := 0
	var descriptor := {}
	var prepared := 0
	var story := {"stop": "level", "screens": [{"directive": "]W 00[", "text": PackedStringArray(["TEST"])}]}

	func running() -> bool:
		return alive

	func committed_continuation(_decision: int) -> Dictionary:
		return {"digest": SOURCE, "kind": "level", "script": story}

	func player_for_view() -> int:
		return role

	func prepare_story(_decision: int, background: String) -> bool:
		prepared += 1
		descriptor = StoryData.prepare(story, SOURCE, {}, background)
		return not descriptor.is_empty()

	func story_for_view(_decision: int) -> Dictionary:
		return descriptor.duplicate(true)

	func mark_story_ready(_decision: int, _page: int, _digest: String) -> bool:
		return true

	func request_story_advance(_decision: int, page: int, _digest: String) -> bool:
		committed = page
		changed.emit()
		return true

	func story_committed_page(_decision: int) -> int:
		return committed

	func mark_story_finished(_decision: int, _context: Dictionary) -> bool:
		local_done = true
		return true

	func story_complete(_decision: int) -> bool:
		return done


func after_test() -> void:
	for node in _nodes:
		if is_instance_valid(node):
			node.free()
	_nodes.clear()
	Music.release_streams()
	Sfx.release_streams()
	await get_tree().process_frame
	await get_tree().process_frame


func _wait_for(condition: Callable) -> void:
	var deadline := Time.get_ticks_msec() + 5000
	while not condition.call() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	assert_bool(condition.call()).is_true()


func _owner(role := 1) -> Array:
	var backend := Backend.new()
	backend.role = role
	_nodes.append(backend)
	add_child(backend)
	var view := Owner.new()
	_nodes.push_front(view)
	assert_bool(view.bind(backend, 1)).is_true()
	add_child(view)
	return [backend, view]


func test_local_finish_waits_for_both_and_release_disconnects_callbacks() -> void:
	var pair := _owner()
	var backend: Node = pair[0]
	var view: Node = pair[1]
	var completions := []
	view.completed.connect(func(): completions.append(true))
	await _wait_for(func(): return view.get("_page_ready"))
	assert_int(backend.prepared).is_equal(1)
	var key := InputEventKey.new()
	key.keycode = KEY_SPACE
	key.pressed = true
	view._input(key)
	await _wait_for(func(): return backend.local_done)
	assert_array(completions).is_empty()
	backend.done = true
	backend.changed.emit()
	assert_int(completions.size()).is_equal(1)
	backend.changed.emit()
	assert_int(completions.size()).is_equal(1)
	view.release()
	assert_bool(backend.changed.is_connected(view._sync)).is_false()
	view.page_ready.emit(1, "stale")
	view.advance_requested.emit(1, "stale")
	view.finished.emit(SOURCE)
	assert_int(completions.size()).is_equal(1)


func test_release_during_entry_fade_cancels_preparation_and_preserves_replacement() -> void:
	var pair := _owner()
	var view: Node = pair[1]
	await get_tree().process_frame
	view.release()
	view.vga.clear(0, 17)
	view.vga.load_palette(0)
	view.vga.set_palette(0, 255)
	var indices: PackedByteArray = view.vga.indices(0)
	var palette: PackedByteArray = view.vga.palette_bytes()
	await get_tree().create_timer(0.4).timeout
	assert_int(pair[0].prepared).is_equal(0)
	assert_bool(view.vga.indices(0) == indices).is_true()
	assert_bool(view.vga.palette_bytes() == palette).is_true()


func test_guest_back_and_disconnect_report_once_without_owning_backend() -> void:
	for disconnect in [false, true]:
		var pair := _owner(2)
		var failures := []
		pair[1].failed.connect(func(reason: String): failures.append(reason))
		if disconnect:
			pair[0].alive = false
			pair[0].changed.emit()
		else:
			var key := InputEventKey.new()
			key.keycode = KEY_ESCAPE
			key.physical_keycode = KEY_ESCAPE
			key.pressed = true
			pair[1]._input(key)
		assert_int(failures.size()).is_equal(1)
		pair[0].changed.emit()
		assert_int(failures.size()).is_equal(1)
		pair[1].release()
		assert_bool(is_instance_valid(pair[0])).is_true()
