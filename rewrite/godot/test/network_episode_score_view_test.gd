extends "res://test/network_story_view_test.gd"

const Score := preload("res://scripts/network_episode_score.gd")
const ScoreView := preload("res://scripts/network_episode_score_view.gd")
const StoryData := preload("res://scripts/network_story_script.gd")


class ScoreFast:
	extends "res://scripts/network_episode_score_view.gd"

	func _wait_with_warning(_units: int) -> void:
		await get_tree().process_frame

	func wait_units(_units: int) -> void:
		if is_inside_tree():
			await get_tree().process_frame


class ScoreReference:
	extends "res://scripts/story_screens.gd"

	func _wait_with_warning(_units: int) -> void:
		await get_tree().process_frame

	func _run() -> void:
		pass

	func _wait_text_completion(_finish: bool) -> void:
		pass

	func wait_units(_units: int) -> void:
		await get_tree().process_frame


func _score_script() -> Dictionary:
	return {
		"stop": "shop",
		"screens": [{"directive": "]M", "text": PackedStringArray(["ORIGINAL HINT"])}],
		"episode_score":
		{"ending": SOURCE, "hint": SOURCE, "cash": ["00000000000004b0", "0000000000000960"], "mutators": 0}
	}


func test_score_lines_use_original_labels_notice_limits_and_exact_unsigned_cash() -> void:
	var script := _score_script()
	var lines := Score.lines(script)
	assert_str(lines[0]).is_equal("%s 1200" % TyrianText.L("miscText_48"))
	assert_str(lines[1]).is_equal("%s 2400" % TyrianText.L("miscText_49"))
	assert_str(lines[2]).is_empty()
	assert_str(lines[3]).is_equal("ORIGINAL HINT")
	assert_str(Score.decimal("ffffffffffffffff")).is_equal("18446744073709551615")
	assert_str(Score.decimal("8000000000000000")).is_equal("9223372036854775808")
	script.episode_score.mutators = 1
	assert_str(Score.lines(script)[2]).is_equal(Story.mutator_notice(1))
	for i in 20:
		script.screens[0].text.append("LINE %d" % i)
	assert_int(Score.lines(script).size()).is_equal(14)
	var rejected := ScoreView.new()
	_nodes.append(rejected)
	assert_bool(rejected.bind_script({"stop": "shop", "screens": []}, SOURCE, 1)).is_false()


func test_original_score_frames_match_in_normal_and_red_context_before_host_commit() -> void:
	for red in [false, true]:
		var script := _score_script()
		var reference := ScoreReference.new()
		_nodes.append(reference)
		add_child(reference)
		reference.vga.clear(0, 0)
		reference.vga.load_palette(0)
		reference.vga.set_palette(0, 255)
		Story.warning_red = red
		reference.set("_frame_count_max", 4)
		await reference._display_text(Score.lines(script))
		var expected: PackedByteArray = reference.vga.indices(0)
		var view := ScoreFast.new()
		_nodes.push_front(view)
		view.vga.clear(0, 0)
		view.vga.load_palette(0)
		view.vga.set_palette(0, 255)
		var descriptor := StoryData.prepare(script, SOURCE, {"warning_red": red}, "cd".repeat(32))
		assert_bool(view.bind_score(descriptor, 1)).is_true()
		add_child(view)
		await _wait(func(): return view.get("_page_ready"))
		assert_bool(view.vga.indices(0) == expected).is_true()
		assert_bool(view.context_state().warning_red).is_equal(red)
		assert_bool(view.commit_page(1, view.page_digest(1))).is_true()
		await _wait(func(): return not view.get("_active"))


func test_removal_during_final_score_fade_preserves_replacement_frame() -> void:
	var view := ScoreFast.new()
	_nodes.push_front(view)
	assert_bool(view.bind_score(StoryData.prepare(_score_script(), SOURCE, {}, "cd".repeat(32)), 1)).is_true()
	add_child(view)
	await _wait(func(): return view.get("_page_ready"))
	assert_bool(view.commit_page(1, view.page_digest(1))).is_true()
	await get_tree().process_frame
	remove_child(view)
	view.vga.clear(0, 17)
	view.vga.load_palette(0)
	view.vga.set_palette(0, 255)
	var indices: PackedByteArray = view.vga.indices(0)
	var palette: PackedByteArray = view.vga.palette_bytes()
	await get_tree().create_timer(0.3).timeout
	assert_bool(view.vga.indices(0) == indices).is_true()
	assert_bool(view.vga.palette_bytes() == palette).is_true()
