extends GdUnitTestSuite

const View := preload("res://scripts/network_debrief.gd")
const Result := preload("res://scripts/network_level_result.gd")
const Fixture := preload("res://test/fixtures/network_setup.gd")
const FinishedSimulation := preload("res://test/network_level_result_test.gd").FinishedSimulation
var _saved := {}


class FastView:
	extends "res://scripts/network_debrief.gd"

	func wait_units(_units: int) -> void:
		if is_inside_tree():
			await get_tree().process_frame


class CancelView:
	extends "res://scripts/network_debrief.gd"
	var fades := 0
	var completions := 0

	func wait_units(_units: int) -> void:
		if is_inside_tree():
			await get_tree().process_frame

	func fade_black(_steps: int, _surf := VGA_SCREEN) -> void:
		fades += 1

	func _finish_debrief() -> void:
		completions += 1


class FadeOnlyView:
	extends "res://scripts/network_debrief.gd"

	func _ready() -> void:
		pass


func before_test() -> void:
	for key in [
		"debrief", "debrief_frozen", "episode", "campaign_active", "loadout", "campaign_carry", "level_start_ms"
	]:
		_saved[key] = Game.get(key)
	Game.debrief = {"sentinel": "local campaign"}
	Game.debrief_frozen = true
	Game.episode = 5
	Game.campaign_active = false


func after_test() -> void:
	for key in _saved:
		Game.set(key, _saved[key])
	_saved.clear()
	Music.release_streams()
	Sfx.release_streams()
	await get_tree().process_frame


func _wait(predicate: Callable) -> bool:
	var deadline := Time.get_ticks_msec() + 10000
	while not predicate.call() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	return predicate.call()


func _result() -> RefCounted:
	var native: Node = auto_free(FinishedSimulation.new())
	# Normal visible scores, unlike the full-width boundary-data fixture.
	native.cash = [1200, 2400]
	native.values["damage_by_bay"] = PackedInt32Array([80, 20, 0, 0, 0])
	native.values["damage_taken"] = 50
	native.values["damage_blocked"] = 30
	native.values["credits_start"] = 1100
	var result := Result.new()
	assert_bool(result.capture(native, Fixture.configuration(), "TYRIAN", 47)).is_true()
	return result


func _open(role: int) -> Node:
	var view: Node = auto_free(FastView.new())
	assert_bool(view.bind(_result(), Fixture.configuration(), role, 125)).is_true()
	view.set("_touch_stats", true)
	add_child(view)
	assert_bool(await _wait(func(): return view.idle and view.get("_stage") == 1)).is_true()
	return view


func test_both_roles_render_original_two_player_summary_and_wait_for_commits() -> void:
	for role in [1, 2]:
		var view := await _open(role)
		assert_str(view._continue_prompt(false)).is_equal(TyrianText.L("net_wait_host" if role == 2 else "ls_continue"))
		assert_array(view.glow_log).contains(
			["%s 1200" % TyrianText.L("miscText_40"), "%s 2400" % TyrianText.L("miscText_41")]
		)
		assert_array(view.cube_xs).is_empty()
		assert_bool(view.commit_phase(2)).is_false()
		assert_bool(view.commit_phase(1)).is_true()
		assert_bool(view.commit_phase(1)).is_true()
		assert_bool(await _wait(func(): return view.stats_shown)).is_true()
		for arg in OS.get_cmdline_user_args():
			if arg.begins_with("--network-debrief-shots="):
				var dir := arg.trim_prefix("--network-debrief-shots=")
				assert_int(view.vga.image(0).save_png(dir.path_join("network-statistics-%d.png" % role))).is_equal(OK)
		assert_array(view.get("_stats_lines")).contains([["ls_enemies", "12 / 17  (70%)"], ["ls_time", "2:05"]])
		var requests: Array[int] = []
		var done := [false]
		view.advance_requested.connect(func(stage: int): requests.append(stage))
		view.finished.connect(func(): done[0] = true)
		var touch := InputEventMouseButton.new()
		touch.button_index = MOUSE_BUTTON_LEFT
		touch.position = Vector2(160, 182)
		touch.pressed = true
		view.handle_mouse(touch)
		assert_array(requests).is_empty()
		touch.pressed = false
		view.handle_mouse(touch)
		assert_array(requests).is_equal([2] if role == 1 else [])
		view.handle_action(TyrianControls.ACCEPT)
		view.handle_action(TyrianControls.ACCEPT)
		assert_array(requests).is_equal([2] if role == 1 else [])
		assert_bool(view.stats_shown).is_true()
		assert_bool(done[0]).is_false()
		assert_bool(view.commit_phase(2)).is_true()
		assert_bool(await _wait(func(): return done[0])).is_true()
		assert_dict(Game.debrief).is_equal({"sentinel": "local campaign"})
		assert_bool(Game.debrief_frozen).is_true()
		assert_int(Game.episode).is_equal(5)
		assert_bool(Game.campaign_active).is_false()
		view.queue_free()
		await get_tree().process_frame


func test_binding_rejects_wrong_config_role_and_all_dead_without_mutating_local_campaign() -> void:
	var view: Node = auto_free(View.new())
	var result := _result()
	var config := Fixture.configuration()
	config.seed = "0000000000000001"
	assert_bool(view.bind(result, config, 1, 0)).is_false()
	assert_bool(view.bind(result, Fixture.configuration(), 3, 0)).is_false()
	var native: Node = auto_free(FinishedSimulation.new())
	native.values.any_player_alive = false
	assert_bool(result.capture(native, Fixture.configuration(), "TYRIAN", 47)).is_true()
	assert_bool(view.bind(result, Fixture.configuration(), 1, 0)).is_false()
	assert_dict(Game.debrief).is_equal({"sentinel": "local campaign"})


func test_guest_wait_prompt_fits_original_summary_and_statistics_in_all_languages() -> void:
	for language in ["en", "de", "es", "fr", "it", "pt"]:
		var label := TyrianText.L("net_wait_host", language)
		assert_str(label).is_not_equal("net_wait_host")
		assert_int(TyrianText.width(label, TyrianScreen.SMALL_FONT)).is_less_equal(288)
		assert_int(TyrianText.width(label, TyrianScreen.NORMAL_FONT)).is_less_equal(304)


func test_removed_statistics_screen_does_not_start_a_late_fade_or_completion() -> void:
	var view: Node = auto_free(CancelView.new())
	assert_bool(view.bind(_result(), Fixture.configuration(), 1, 125)).is_true()
	add_child(view)
	assert_bool(await _wait(func(): return view.idle)).is_true()
	assert_bool(view.commit_phase(1)).is_true()
	assert_bool(await _wait(func(): return view.stats_shown)).is_true()
	remove_child(view)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_int(view.fades).is_equal(0)
	assert_int(view.completions).is_equal(0)


func test_removal_during_fade_preserves_replacement_screen_palette() -> void:
	var view: Node = auto_free(FadeOnlyView.new())
	assert_bool(view.bind(_result(), Fixture.configuration(), 1, 125)).is_true()
	add_child(view)
	var replacement: Array[PackedByteArray] = []
	view.presented.connect(
		func(_surface: int):
			remove_child(view)
			view.vga.set_colors(Color.MAGENTA, 0, 255)
			replacement.append(view.vga.palette_bytes()),
		CONNECT_ONE_SHOT
	)
	await view.fade_black(15)
	assert_int(replacement.size()).is_equal(1)
	assert_bool(view.vga.palette_bytes() == replacement[0]).is_true()
