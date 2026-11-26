extends GdUnitTestSuite

const View := preload("res://scripts/network_story_view.gd")
const Story := preload("res://scripts/story_screens.gd")
const SOURCE := "abababababababababababababababababababababababababababababababab"
var _nodes: Array[Node] = []
var _ready_pages := [{}, {}]
var _requests := {}
var _frames := [{}, {}]
var _old_red := false
var _old_bank := false
var _old_script := {}


class Fast:
	extends "res://scripts/network_story_view.gd"

	func fade_palette(_steps: int, first := 0, last := 255, _surf := VGA_SCREEN) -> void:
		vga.set_palette(first, last)

	func wait_units(_units: int) -> void:
		if is_inside_tree():
			await get_tree().process_frame


class Reference:
	extends "res://scripts/story_screens.gd"

	func _run() -> void:
		pass

	func fade_palette(_steps: int, first := 0, last := 255, _surf := VGA_SCREEN) -> void:
		vga.set_palette(first, last)

	func _wait_text_completion(_finish: bool) -> void:
		pass


class Cancel:
	extends "res://scripts/network_story_view.gd"

	func fade_black(_steps: int, _surf := VGA_SCREEN) -> void:
		await get_tree().process_frame


func before_test() -> void:
	_old_red = Story.warning_red
	_old_bank = Story.use_last_bank
	_old_script = Game.story_script.duplicate(true)
	_ready_pages = [{}, {}]
	_frames = [{}, {}]
	_requests.clear()


func after_test() -> void:
	for node in _nodes:
		if is_instance_valid(node):
			node.free()
	_nodes.clear()
	Story.warning_red = _old_red
	Story.use_last_bank = _old_bank
	assert_dict(Game.story_script).is_equal(_old_script)
	Music.release_streams()
	Sfx.release_streams()
	await get_tree().process_frame
	await get_tree().process_frame


func _script() -> Dictionary:
	return {
		"stop": "level",
		"screens":
		[
			{"directive": "]P 1[", "text": PackedStringArray()},
			{"directive": "]@[", "text": PackedStringArray()},
			{"directive": "]W 00[", "text": PackedStringArray(["NETWORK STORY"])}
		]
	}


func _wait(condition: Callable) -> void:
	var deadline := Time.get_ticks_msec() + 5000
	while not condition.call() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	assert_bool(condition.call()).is_true()


func _ready_page(page: int, digest: String, role: int, view: Node) -> void:
	_ready_pages[role - 1][page] = digest
	_frames[role - 1][page] = view.vga.indices(0)
	_settle(page)


func _request(page: int, digest: String) -> void:
	_requests[page] = digest
	_settle(page)


func _settle(page: int) -> void:
	if not _requests.has(page) or not _ready_pages[0].has(page) or not _ready_pages[1].has(page):
		return
	assert_str(_ready_pages[0][page]).is_equal(_ready_pages[1][page])
	for node in _nodes:
		if is_instance_valid(node) and node is Fast:
			assert_bool(node.commit_page(page, _requests[page])).is_true()


func test_original_host_frames_match_and_guest_cannot_advance_either_peer() -> void:
	var script := _script()
	var reference := Reference.new()
	_nodes.append(reference)
	add_child(reference)
	Story.use_last_bank = false
	for screen: Dictionary in script.screens:
		await reference._screen(screen.directive, screen.text)
	var expected: PackedByteArray = reference.vga.indices(0)
	Story.warning_red = true
	Story.use_last_bank = false
	# The in-process VGA surface is global. Compare one renderer at a time;
	# concurrent phone fixtures below exercise ownership, not surface isolation.
	var standalone := Fast.new()
	_nodes.append(standalone)
	var own_frame := []
	assert_bool(standalone.bind_script(script, SOURCE, 1)).is_true()
	standalone.page_ready.connect(
		func(page: int, digest: String):
			if page < 3:
				standalone.commit_page(page, digest)
			else:
				own_frame.append(standalone.vga.indices(0))
	)
	add_child(standalone)
	await _wait(func(): return not own_frame.is_empty())
	assert_bool(own_frame[0] == expected).is_true()
	assert_bool(standalone.commit_page(3, standalone.page_digest(3))).is_true()
	await _wait(func(): return not standalone.get("_active"))
	var finished_roles := []
	var pair := []
	for role in [1, 2]:
		var view := Fast.new()
		_nodes.append(view)
		assert_bool(view.bind_script(script, SOURCE, role)).is_true()
		view.page_ready.connect(_ready_page.bind(role, view))
		view.advance_requested.connect(_request)
		view.finished.connect(func(_source: String): finished_roles.append(role))
		view.set("_touch_name", true)
		pair.append(view)
		add_child(view)
	await _wait(func(): return _ready_pages[0].has(3) and _ready_pages[1].has(3))
	assert_bool(Story.warning_red).is_true()
	assert_bool(Story.use_last_bank).is_false()
	var event := InputEventKey.new()
	event.pressed = true
	event.physical_keycode = KEY_SPACE
	pair[1]._input(event)
	await get_tree().process_frame
	assert_bool(_requests.has(3)).is_false()
	assert_array(finished_roles).is_empty()
	pair[0]._input(event)
	await _wait(func(): return finished_roles.size() == 2)
	assert_bool(pair[0].commit_page(3, pair[0].page_digest(3))).is_true()
	assert_bool(pair[0].context_state().use_last_bank).is_true()
	assert_bool(pair[1].context_state().use_last_bank).is_true()


func test_binding_and_commits_reject_unsupported_effects_types_and_page_skips() -> void:
	for bad in [
		{"stop": "episode_end", "screens": []},
		{"stop": "level", "autosave": true, "screens": []},
		{"stop": "level", "screens": [{"directive": "]Z[", "text": PackedStringArray()}]},
		{"stop": "level", "screens": [{"directive": "]W 00[", "text": ["wrong array type"]}]}
	]:
		var view := Fast.new()
		_nodes.append(view)
		assert_bool(view.bind_script(bad, SOURCE, 1)).is_false()
	var view := Fast.new()
	_nodes.append(view)
	var script := _script()
	assert_bool(view.bind_script(script, SOURCE, 3)).is_false()
	assert_bool(view.bind_script(script, SOURCE, 1)).is_true()
	var digest := view.page_digest(1)
	script.screens[0].directive = "]P 2["
	assert_str(view.page_digest(1)).is_equal(digest)
	assert_bool(view.commit_page(2, view.page_digest(2))).is_false()
	assert_str(view.error).is_equal("premature_story_commit")


func test_removed_story_cannot_clear_replacement_frame_after_a_fade() -> void:
	var view := Cancel.new()
	_nodes.append(view)
	(
		assert_bool(
			view.bind_script(
				{"stop": "level", "screens": [{"directive": "]C[", "text": PackedStringArray()}]}, SOURCE, 1
			)
		)
		. is_true()
	)
	add_child(view)
	await get_tree().process_frame
	remove_child(view)
	var replacement := PackedByteArray()
	replacement.resize(320 * 200)
	replacement.fill(39)
	view.vga.set_indices(0, replacement)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_bool(view.vga.indices(0) == replacement).is_true()


func test_real_network_fade_stops_modifying_replacement_pixels_and_palette() -> void:
	var view := View.new()
	_nodes.append(view)
	(
		assert_bool(
			view.bind_script(
				{"stop": "level", "screens": [{"directive": "]C[", "text": PackedStringArray()}]}, SOURCE, 1
			)
		)
		. is_true()
	)
	add_child(view)
	await get_tree().process_frame
	remove_child(view)
	view.vga.load_pic(0, 2, false)
	view.vga.set_palette(0, 255)
	var expected: PackedByteArray = view.vga.indices(0)
	var colors: PackedByteArray = view.vga.image(0).get_data()
	await get_tree().create_timer(0.1).timeout
	assert_bool(view.vga.indices(0) == expected).is_true()
	assert_bool(view.vga.image(0).get_data() == colors).is_true()


func test_native_two_player_story_script_binds_without_applying_local_campaign_effects() -> void:
	var campaign: RefCounted = ClassDB.instantiate("TyrianCampaign")
	campaign.load(Game.data_dir)
	var found := false
	for section in range(1, 256):
		var script: Dictionary = campaign.run_script(1, section, 2, 11, true, 0, true, 0)
		if (
			script.get("stop") in ["level", "shop"]
			and not script.get("screens", []).is_empty()
			and not script.get("autosave", false)
		):
			var view := View.new()
			_nodes.append(view)
			assert_bool(view.bind_script(script, SOURCE, 1)).is_true()
			found = true
			break
	assert_bool(found).is_true()
