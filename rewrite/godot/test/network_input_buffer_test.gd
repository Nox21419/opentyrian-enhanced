extends GdUnitTestSuite

const Buffer := preload("res://scripts/network_input_buffer.gd")
const Wire := preload("res://scripts/network_protocol.gd")
const SESSION := "00112233445566778899aabbccddeeff"


func _remote(tick: int, mask := 16) -> Dictionary:
	var frame: Dictionary = Wire.neutral_frame()
	frame.mask = mask
	return {
		"kind": Wire.Kind.INPUT,
		"session": SESSION,
		"epoch": 1,
		"player": 2,
		"tick": tick,
		"sequence": 0,
		"frame": frame
	}


func test_waits_for_complete_pairs_and_consumes_ticks_in_order() -> void:
	var buffer := Buffer.new()
	assert_int(buffer.configure(SESSION, 1, 1, 0)).is_equal(OK)
	buffer.capture_local(Wire.neutral_frame())
	assert_int(buffer.receive(_remote(1, 32))).is_equal(Buffer.Result.ACCEPTED)
	assert_bool(buffer.ready()).is_false()
	assert_dict(buffer.take_tick()).is_empty()
	assert_int(buffer.next_tick).is_equal(0)
	assert_int(buffer.receive(_remote(0, 16))).is_equal(Buffer.Result.ACCEPTED)
	var tick: Dictionary = buffer.take_tick()
	assert_int(tick.tick).is_equal(0)
	assert_int(tick.inputs[1].mask).is_equal(16)
	assert_dict(buffer.take_tick()).is_empty()
	buffer.capture_local(Wire.neutral_frame())
	tick = buffer.take_tick()
	assert_int(tick.tick).is_equal(1)
	assert_int(tick.inputs[1].mask).is_equal(32)
	assert_int(buffer.pending_frame_count()).is_equal(0)


func test_delay_prefills_only_neutral_startup_ticks_and_samples_once() -> void:
	var buffer := Buffer.new()
	assert_int(buffer.configure(SESSION, 1, 1, 2)).is_equal(OK)
	assert_int(buffer.local_input_tick()).is_equal(2)
	assert_bool(buffer.needs_local_input()).is_true()
	var frame: Dictionary = Wire.neutral_frame()
	frame.mask = 16
	var first: Dictionary = buffer.capture_local(frame)
	assert_int(first.tick).is_equal(2)
	assert_bool(buffer.needs_local_input()).is_false()
	frame.mask = 32
	assert_dict(buffer.capture_local(frame)).is_equal(first)
	assert_int(buffer.receive(_remote(2))).is_equal(Buffer.Result.ACCEPTED)
	for expected in 2:
		var tick: Dictionary = buffer.take_tick()
		assert_int(tick.tick).is_equal(expected)
		assert_dict(tick.inputs[0]).is_equal(Wire.neutral_frame())
		assert_dict(tick.inputs[1]).is_equal(Wire.neutral_frame())
	var delayed: Dictionary = buffer.take_tick()
	assert_int(delayed.tick).is_equal(2)
	assert_int(delayed.inputs[0].mask).is_equal(16)
	assert_int(delayed.inputs[1].mask).is_equal(16)


func test_identical_duplicates_are_idempotent_but_conflicts_stop_consumption() -> void:
	var buffer := Buffer.new()
	buffer.configure(SESSION, 1, 1, 0)
	buffer.capture_local(Wire.neutral_frame())
	assert_int(buffer.receive(_remote(0))).is_equal(Buffer.Result.ACCEPTED)
	assert_int(buffer.receive(_remote(0))).is_equal(Buffer.Result.DUPLICATE)
	assert_int(buffer.receive(_remote(0, 32))).is_equal(Buffer.Result.CONFLICT)
	assert_bool(buffer.failed).is_true()
	assert_dict(buffer.take_tick()).is_empty()
	assert_int(buffer.receive(_remote(1))).is_equal(Buffer.Result.STOPPED)
	assert_dict(buffer.capture_local(Wire.neutral_frame())).is_empty()
	assert_int(buffer.configure(SESSION, 2, 1, 0)).is_equal(OK)
	assert_bool(buffer.failed).is_false()


func test_consumed_duplicates_use_history_and_external_mutation_cannot_change_it() -> void:
	var buffer := Buffer.new()
	buffer.configure(SESSION, 1, 1, 0)
	var local: Dictionary = Wire.neutral_frame()
	local.mouse_dx = 30
	var packet: Dictionary = buffer.capture_local(local)
	local.mouse_dx = -30
	packet.frame.mouse_dx = 999
	assert_int(buffer.capture_local(local).frame.mouse_dx).is_equal(30)
	var remote := _remote(0)
	buffer.receive(remote)
	remote.frame.mask = 32
	var tick: Dictionary = buffer.take_tick()
	assert_int(tick.inputs[1].mask).is_equal(16)
	tick.inputs[1].mask = 128
	assert_int(buffer.receive(_remote(0))).is_equal(Buffer.Result.DUPLICATE)
	assert_int(buffer.receive(_remote(0, 64))).is_equal(Buffer.Result.CONFLICT)


func test_old_epoch_wrong_role_and_far_future_packets_do_not_allocate() -> void:
	var buffer := Buffer.new()
	buffer.configure(SESSION, 1, 1, 0)
	var packet := _remote(0)
	packet.epoch = 2
	assert_int(buffer.receive(packet)).is_equal(Buffer.Result.WRONG_SESSION)
	packet = _remote(0)
	packet.session = "ff".repeat(16)
	assert_int(buffer.receive(packet)).is_equal(Buffer.Result.WRONG_SESSION)
	packet = _remote(0)
	packet.player = 1
	assert_int(buffer.receive(packet)).is_equal(Buffer.Result.INVALID)
	assert_int(buffer.receive(_remote(Buffer.MAX_AHEAD))).is_equal(Buffer.Result.TOO_FAR)
	assert_int(buffer.pending_frame_count()).is_equal(0)
	assert_int(buffer.receive(_remote(Buffer.MAX_AHEAD - 1))).is_equal(Buffer.Result.ACCEPTED)
	assert_int(buffer.pending_frame_count()).is_equal(1)


func test_unconfigured_reset_and_invalid_configuration_cannot_run() -> void:
	var buffer := Buffer.new()
	assert_bool(buffer.needs_local_input()).is_false()
	assert_dict(buffer.capture_local(Wire.neutral_frame())).is_empty()
	assert_int(buffer.receive(_remote(0))).is_equal(Buffer.Result.STOPPED)
	for values in [
		[SESSION, 0, 1, 0],
		["invalid", 1, 1, 0],
		[SESSION, 1, 3, 0],
		[SESSION, 1, 1, -1],
		[SESSION, 1, 1, Buffer.MAX_DELAY + 1]
	]:
		buffer.configure(SESSION, 1, 1, 2)
		assert_int(buffer.configure(values[0], values[1], values[2], values[3])).is_equal(ERR_INVALID_PARAMETER)
		assert_int(buffer.pending_frame_count()).is_equal(0)
		assert_bool(buffer.ready()).is_false()
	buffer.configure(SESSION, 1, 1, 2)
	buffer.reset()
	assert_int(buffer.pending_frame_count()).is_equal(0)
	assert_int(buffer.history_tick_count()).is_equal(0)
	assert_int(buffer.next_tick).is_equal(0)


## Exercise the real codec between two independent buffers with delay, jitter,
## reordering, duplicates and a deliberately dropped first send plus retry.
func test_two_peers_converge_under_adverse_delivery_with_bounded_memory() -> void:
	var peers := [Buffer.new(), Buffer.new()]
	for player in 2:
		peers[player].configure(SESSION, 1, player + 1, 3)
	var deliveries: Array[Dictionary] = []
	var outputs: Array[Dictionary] = [{}, {}]
	for clock in 6000:
		for player in 2:
			var buffer = peers[player]
			if buffer.next_tick >= 500 or not buffer.needs_local_input():
				continue
			var frame: Dictionary = Wire.neutral_frame()
			frame.mask = (buffer.local_input_tick() * 7 + player * 16) & 0xff
			frame.mouse_dx = buffer.local_input_tick() % 61 - 30
			frame.new_key = buffer.local_input_tick() % 17 == 0
			var message: Dictionary = buffer.capture_local(frame)
			var lag: int = (message.tick * 3 + player) % 7
			# A dropped first send is retried later with identical bytes.
			if message.tick % 7 == 0:
				lag += 9
			var delivery := {"at": clock + lag, "player": player + 1, "data": Wire.encode(message)}
			deliveries.append(delivery)
			if message.tick % 5 == 0:
				var duplicate := delivery.duplicate(true)
				duplicate.at += 2
				deliveries.append(duplicate)
		for i in range(deliveries.size() - 1, -1, -1):
			var delivery: Dictionary = deliveries[i]
			if delivery.at > clock:
				continue
			var receiver: int = 2 - delivery.player
			var message: Dictionary = Wire.decode(delivery.data, SESSION, 1, delivery.player)
			var result: int = peers[receiver].receive(message)
			assert_bool(result in [Buffer.Result.ACCEPTED, Buffer.Result.DUPLICATE, Buffer.Result.STALE]).is_true()
			deliveries.remove_at(i)
		for player in 2:
			if peers[player].next_tick >= 500:
				continue
			var tick: Dictionary = peers[player].take_tick()
			if not tick.is_empty():
				outputs[player][tick.tick] = tick.inputs
			assert_int(peers[player].pending_frame_count()).is_less_equal(2 * Buffer.MAX_AHEAD)
			assert_int(peers[player].history_tick_count()).is_less_equal(Buffer.HISTORY_TICKS)
		if peers[0].next_tick == 500 and peers[1].next_tick == 500:
			break
	assert_int(peers[0].next_tick).is_equal(500)
	assert_int(peers[1].next_tick).is_equal(500)
	assert_dict(outputs[0]).is_equal(outputs[1])
	assert_int(peers[0].receive(_remote(0))).is_equal(Buffer.Result.STALE)
	assert_bool(peers[0].failed).is_false()
