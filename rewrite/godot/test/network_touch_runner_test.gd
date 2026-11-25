extends GdUnitTestSuite

const Runner := preload("res://scripts/network_touch_runner.gd")
const Policy := preload("res://scripts/network_touch_inputs.gd")
const Wire := preload("res://scripts/network_protocol.gd")
const Buffer := preload("res://scripts/network_input_buffer.gd")
const Fixture := preload("res://test/fixtures/network_setup.gd")
const SESSION := "57575757575757575757575757575757"


func after() -> void:
	Music.release_streams()
	Sfx.release_streams()
	await get_tree().process_frame
	await get_tree().process_frame


func _sim(config: Dictionary) -> Node:
	var sim: Node = auto_free(ClassDB.instantiate("TyrianSim"))
	var mods: RefCounted = ClassDB.instantiate("TyrianMods")
	mods.load(Game.data_dir, PackedStringArray())
	sim.set_mods(mods)
	assert_bool(sim.prepare_network_level(Game.data_dir, config)).is_true()
	return sim


func _packet(frame: Dictionary, player := 2, tick := 0, epoch := 1) -> PackedByteArray:
	return Wire.encode(
		{
			"kind": Wire.Kind.INPUT,
			"session": SESSION,
			"epoch": epoch,
			"player": player,
			"tick": tick,
			"sequence": 0,
			"frame": frame
		}
	)


func _frame(player: int, tick: int) -> Dictionary:
	var frame := Wire.neutral_frame()
	frame.mask = 0x300 if player == 1 and tick % 47 == 0 else 0
	frame.mouse_mask = 16 if tick % 13 < 10 else 0
	frame.mouse_dx = (tick * 7 + player) % 61 - 30
	frame.mouse_dy = (tick * 11 + player) % 61 - 30
	frame.new_key = tick % 43 == 0
	return frame


func test_input_epoch_resume_keeps_native_state_and_matches_cleared_android_reference() -> void:
	var config := Fixture.configuration()
	config.loadout1[9] = 1  # Equipped special: neutral must retain the Android flag.
	var native := _sim(config)
	var reference := _sim(config)
	var runner := Runner.new()
	assert_bool(runner.activate(native, config, SESSION, 1, 1)).is_true()
	var pending: Array[Dictionary] = [{}, {}]
	var epoch := 1
	for tick in 100:
		if tick == 60:
			runner.capture_local(_frame(1, tick))
			var digest: String = native.network_diagnostic_digest()
			assert_bool(runner.resume_inputs(2, tick)).is_true()
			assert_str(native.network_diagnostic_digest()).is_equal(digest)
			assert_int(native.tick()).is_equal(tick)
			assert_int(runner.receive(_packet(_frame(2, tick), 2, tick + 3, 1))).is_equal(Buffer.Result.WRONG_SESSION)
			epoch = 2
		for player in [1, 2]:
			var frame := Policy.neutral_frame(player, config)
			if tick < 60 or tick >= 70:
				frame.mouse_mask = Game.MASK_FIRE
				frame.mouse_dx = -8 if player == 1 else 8
			pending[player - 1][tick + 3] = frame
			if player == 1:
				assert_bool(not runner.capture_local(frame).is_empty()).is_true()
			else:
				assert_int(runner.receive(_packet(frame, 2, tick + 3, epoch))).is_equal(Buffer.Result.ACCEPTED)
		assert_bool(runner.advance()).is_true()
		var frames := [Wire.neutral_frame(), Wire.neutral_frame()]
		for player in [1, 2]:
			if tick >= 60 and tick < 63:
				frames[player - 1] = Policy.neutral_frame(player, config)
			elif tick >= 3:
				frames[player - 1] = pending[player - 1][tick]
		reference.set_player_mice(
			frames[0].mouse_mask, frames[0].mouse_dx, 0, frames[1].mouse_mask, frames[1].mouse_dx, 0
		)
		reference.set_analog(0, 0, 0, 0)
		reference.set_new_key(false)
		reference.step(frames[0].mask, frames[1].mask)
		assert_str(native.network_diagnostic_digest()).is_equal(reference.network_diagnostic_digest())


func test_touch_policy_rejects_unbounded_axes_and_special_ownership_violations() -> void:
	var config := Fixture.configuration()
	for player in [1, 2]:
		assert_bool(Policy.valid(_frame(player, 0), player, config)).is_true()
	for pair in [["mouse_dx", 31], ["mouse_dy", -31], ["analog_x", 1], ["analog_y", -1], ["mask", 0x200]]:
		var frame := Wire.neutral_frame()
		frame[pair[0]] = pair[1]
		assert_bool(Policy.valid(frame, 1, config)).is_false()
	var special := Wire.neutral_frame()
	special.mask = 0x300
	assert_bool(Policy.valid(special, 2, config)).is_false()
	config.dedicated_special = false
	assert_bool(Policy.valid(special, 1, config)).is_false()
	config.devices = [1, 2]
	assert_bool(Policy.supports(config)).is_false()


func test_waits_freeze_local_input_and_step_only_after_both_frames() -> void:
	var config := Fixture.configuration()
	config.input_delay = 0
	var sim := _sim(config)
	var runner := Runner.new()
	assert_bool(runner.activate(sim, config, SESSION, 1, 1)).is_true()
	var first := runner.capture_local(_frame(1, 0))
	assert_bool(runner.needs_local_input()).is_false()
	assert_bool(runner.advance()).is_false()
	assert_int(sim.tick()).is_equal(0)
	assert_array(Array(runner.capture_local({}))).is_equal(Array(first))
	assert_int(runner.receive(_packet(_frame(2, 0)))).is_equal(Buffer.Result.ACCEPTED)
	assert_int(runner.receive(_packet(_frame(2, 0)))).is_equal(Buffer.Result.DUPLICATE)
	assert_bool(runner.advance()).is_true()
	assert_int(sim.tick()).is_equal(1)
	assert_bool(runner.advance()).is_false()
	assert_int(sim.tick()).is_equal(1)
	assert_int(runner.ticks_executed).is_equal(1)
	runner.stop()


func test_invalid_remote_input_conflict_and_external_steps_fail_without_extra_simulation() -> void:
	var config := Fixture.configuration()
	config.input_delay = 0
	for scenario in [0, 1, 2]:
		var sim := _sim(config)
		var runner := Runner.new()
		assert_bool(runner.activate(sim, config, SESSION, 1, 1)).is_true()
		runner.capture_local(Wire.neutral_frame())
		var frame := Wire.neutral_frame()
		if scenario == 0:
			frame.mouse_dx = Wire.MAX_I32
			assert_int(runner.receive(_packet(frame))).is_equal(Buffer.Result.INVALID)
		elif scenario == 1:
			runner.receive(_packet(frame))
			frame.mouse_dx = 1
			assert_int(runner.receive(_packet(frame))).is_equal(Buffer.Result.CONFLICT)
		else:
			runner.receive(_packet(frame))
			sim.step(0, 0)
		assert_bool(runner.advance()).is_false()
		assert_bool(runner.error.is_empty()).is_false()
		assert_int(sim.tick()).is_equal(1 if scenario == 2 else 0)
		runner.stop()


func test_prefill_still_requires_sampling_and_old_epochs_cannot_enter_new_run() -> void:
	var config := Fixture.configuration()
	var sim := _sim(config)
	var runner := Runner.new()
	assert_bool(runner.activate(sim, config, SESSION, 2, 1)).is_true()
	assert_bool(runner.advance()).is_false()
	assert_int(runner.receive(_packet(_frame(2, 0)))).is_equal(Buffer.Result.WRONG_SESSION)
	assert_str(runner.error).is_empty()
	runner.capture_local(_frame(1, config.input_delay))
	assert_bool(runner.advance()).is_true()
	assert_int(sim.tick()).is_equal(1)
	assert_bool(runner.needs_local_input()).is_true()
	runner.stop()


func test_native_peers_and_direct_reference_match_under_delayed_duplicated_reordered_delivery() -> void:
	var config := Fixture.configuration()
	var sims := [_sim(config), _sim(config)]
	var runners := [Runner.new(), Runner.new()]
	for i in 2:
		assert_bool(runners[i].activate(sims[i], config, SESSION, 1, i + 1)).is_true()
	var delivery: Array[Dictionary] = []
	var digests: Array[Dictionary] = [{}, {}]
	const LIMIT := 180
	for clock in 4000:
		for i in 2:
			if runners[i].ticks_executed < LIMIT and runners[i].needs_local_input():
				var tick: int = runners[i].ticks_executed + config.input_delay
				var packet: PackedByteArray = runners[i].capture_local(_frame(i + 1, tick))
				var delay: int = (tick * 7 + i) % 5
				if tick % 13 == 0:
					delay += 9  # Lost initial delivery followed by a delayed retransmission.
				delivery.append({"due": clock + delay, "target": 1 - i, "packet": packet})
				if tick % 9 == 0:
					delivery.append({"due": clock + delay + 6, "target": 1 - i, "packet": packet})
		for index in range(delivery.size() - 1, -1, -1):
			if delivery[index].due <= clock:
				var item: Dictionary = delivery.pop_at(index)
				runners[item.target].receive(item.packet)
		for i in 2:
			if runners[i].ticks_executed < LIMIT and runners[i].advance():
				digests[i][runners[i].ticks_executed] = sims[i].network_diagnostic_digest()
			assert_str(runners[i].error).is_empty()
		if runners[0].ticks_executed == LIMIT and runners[1].ticks_executed == LIMIT:
			break
	assert_int(runners[0].ticks_executed).is_equal(LIMIT)
	assert_int(runners[1].ticks_executed).is_equal(LIMIT)
	var reference := _sim(config)
	for tick in LIMIT:
		var a := Wire.neutral_frame() if tick < config.input_delay else _frame(1, tick)
		var b := Wire.neutral_frame() if tick < config.input_delay else _frame(2, tick)
		reference.set_player_mice(a.mouse_mask, a.mouse_dx, a.mouse_dy, b.mouse_mask, b.mouse_dx, b.mouse_dy)
		reference.set_analog(0, 0, 0, 0)
		reference.set_new_key(a.new_key or b.new_key)
		reference.step(a.mask, b.mask)
		var digest: String = reference.network_diagnostic_digest()
		assert_str(digests[0][tick + 1]).is_equal(digest)
		assert_str(digests[1][tick + 1]).is_equal(digest)
	for runner in runners:
		runner.stop()
