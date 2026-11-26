extends "res://test/network_continuation_load_test.gd"

const Runner := preload("res://scripts/network_touch_runner.gd")
const Policy := preload("res://scripts/network_touch_inputs.gd")
const LevelResult := preload("res://scripts/network_level_result.gd")
const Finished := preload("res://test/network_level_result_test.gd").FinishedSimulation


func _request() -> Dictionary:
	var proposal := _proposal()
	proposal.script["next_level"] = 4
	proposal.script["level_name"] = "TYRIAN"
	proposal.digest = Cursor.proposal_digest(proposal)
	return Next.build(Setup.configuration(), proposal, "1234567890abcdef")


func test_continuation_runner_requires_sealed_request_and_keeps_initial_activation_strict() -> void:
	var request := _request()
	assert_bool(Next.valid_request(request)).is_true()
	assert_bool(Policy.supports(request.configuration)).is_false()
	var natives := [_native(), _native()]
	var runners := [Runner.new(), Runner.new()]
	for i in 2:
		(
			assert_bool(
				natives[i].prepare_network_continuation(Game.data_dir, request.configuration, request.carry, false)
			)
			. is_true()
		)
		assert_bool(runners[i].activate(natives[i], request.configuration, "12".repeat(16), 3, i + 1)).is_false()
		assert_bool(runners[i].activate_continuation(natives[i], request, "12".repeat(16), 3, i + 1)).is_true()
	for tick in 80:
		var packets := []
		for i in 2:
			var frame := Policy.neutral_frame(i + 1, request.configuration)
			frame.mouse_mask = 16
			frame.mouse_dx = 3 if i == 0 else -3
			packets.append(runners[i].capture_local(frame))
		for i in 2:
			runners[i].receive(packets[1 - i])
			assert_bool(runners[i].advance()).is_true()
		assert_str(natives[0].network_diagnostic_digest()).is_equal(natives[1].network_diagnostic_digest())
	for native in natives:
		native.free()
	var invalid := request.duplicate(true)
	invalid.configuration.cash1 = "0000000000000001"
	assert_bool(Next.valid_request(invalid)).is_false()
	assert_bool(runners[0].activate_continuation(null, invalid, "12".repeat(16), 4, 1)).is_false()
	invalid = request.duplicate(true)
	invalid.bonus_level = true
	invalid.digest = Cursor.proposal_digest(invalid)
	assert_bool(Next.valid_request(invalid)).is_false()


func test_later_level_result_and_cursor_context_use_the_continuation_digest_explicitly() -> void:
	var request := _request()
	var sim := Finished.new()
	sim.values.merge({"cube_max": 0, "total_score": 20000, "lives": 2}, true)
	var result := LevelResult.new()
	assert_bool(result.capture(sim, request.configuration, "TYRIAN", 47)).is_false()
	assert_bool(result.capture(sim, request.configuration, "TYRIAN", 47, true)).is_true()
	assert_str(result.record().config).is_equal(Next.configuration_digest(request.configuration))
	var cursor := Cursor.new(Game.data_dir)
	assert_bool(cursor.begin(request.configuration)).is_false()
	cursor = Cursor.new(Game.data_dir)
	assert_bool(cursor.begin_continuation(request.configuration, request.script, request.entry)).is_true()
	var record: Dictionary = result.record()
	assert_dict(cursor.completed(record)).is_not_empty()
	sim.free()
