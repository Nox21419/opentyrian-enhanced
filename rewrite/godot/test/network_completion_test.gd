extends GdUnitTestSuite

const Completion := preload("res://scripts/network_completion.gd")
const Wire := preload("res://scripts/network_protocol.gd")
const SESSION := "01010101010101010101010101010101"
const DIGEST := "abababababababababababababababababababababababababababababababab"


func _message(player := 1, kind := Wire.Kind.LEVEL_RESULT, stage := 0) -> Dictionary:
	var message := {
		"kind": kind, "session": SESSION, "epoch": 2, "player": player, "tick": 100, "sequence": stage, "digest": DIGEST
	}
	if kind == Wire.Kind.LEVEL_RESULT:
		message.elapsed = 125 if player == 1 else 0
	return message


func _pair() -> Array:
	var pair := [Completion.new(), Completion.new()]
	for i in 2:
		assert_bool(pair[i].configure(SESSION, 2, i + 1, 3)).is_true()
	return pair


func _deliver(sender: RefCounted, receiver: RefCounted, tick := 100, now := 5) -> Array:
	var messages: Array = sender.take_messages()
	for message in messages:
		var decoded := Wire.decode(Wire.encode(message), SESSION, 2, message.player)
		assert_dict(decoded).is_equal(message)
		assert_bool(receiver.receive(decoded, tick, now)).is_true()
	return messages


func _agree(pair: Array) -> void:
	assert_bool(pair[0].reached(100, DIGEST, 125, 1)).is_true()
	assert_bool(pair[1].reached(100, DIGEST, 0, 1)).is_true()
	_deliver(pair[0], pair[1])
	_deliver(pair[1], pair[0])
	assert_bool(pair[0].agreed() and pair[1].agreed()).is_true()


func test_completion_wire_fixture_and_strict_lengths_roles_elapsed_and_phases() -> void:
	var message := _message()
	var fixture := "4f54324e01000701" + SESSION + "020000006400000000000000" + DIGEST + "7d000000"
	assert_str(Wire.encode(message).hex_encode()).is_equal(fixture)
	assert_dict(Wire.decode(fixture.hex_decode(), SESSION, 2, 1)).is_equal(message)
	for kind in [Wire.Kind.LEVEL_READY, Wire.Kind.LEVEL_ADVANCE]:
		for stage in [1, 2]:
			message = _message(1, kind, stage)
			assert_dict(Wire.decode(Wire.encode(message), SESSION, 2, 1)).is_equal(message)
	var packet := fixture.hex_decode()
	for length in packet.size():
		assert_dict(Wire.decode(packet.slice(0, length), SESSION, 2, 1)).is_empty()
	packet.append(0)
	assert_dict(Wire.decode(packet, SESSION, 2, 1)).is_empty()
	for change in [["elapsed", -1], ["elapsed", 1.5], ["tick", 0], ["sequence", 1]]:
		message = _message()
		message[change[0]] = change[1]
		assert_bool(Wire.encode(message).is_empty()).is_true()
	message = _message(2)
	message.elapsed = 1
	assert_bool(Wire.encode(message).is_empty()).is_true()
	assert_bool(Wire.encode(_message(2, Wire.Kind.LEVEL_ADVANCE, 1)).is_empty()).is_true()
	assert_bool(Wire.encode(_message(1, Wire.Kind.LEVEL_READY, 3)).is_empty()).is_true()
	assert_bool(Wire.encode(_message(1, Wire.Kind.LEVEL_READY, 0)).is_empty()).is_true()


func test_result_agreement_and_host_waiting_for_both_screen_readiness() -> void:
	var pair := _pair()
	_agree(pair)
	for peer in pair:
		assert_int(peer.elapsed_seconds()).is_equal(125)
		assert_bool(peer.may_advance(100)).is_false()
		peer.poll(1000000)  # Deliberate human wait has no agreement timeout.
		assert_str(peer.error).is_empty()
	for stage in [1, 2]:
		assert_bool(pair[1].request_advance(stage, 1000000)).is_false()
		assert_bool(pair[0].screen_ready(stage)).is_true()
		_deliver(pair[0], pair[1])
		assert_bool(pair[0].request_advance(stage, 1000000)).is_true()
		assert_bool(pair[0].request_advance(stage, 1000001)).is_true()
		assert_int(pair[0].committed_phase()).is_equal(stage - 1)
		assert_bool(pair[1].screen_ready(stage)).is_true()
		_deliver(pair[1], pair[0])
		var commits := _deliver(pair[0], pair[1])
		assert_int(commits.size()).is_equal(1)
		assert_bool(pair[1].receive(commits[0], 100, 1000002)).is_true()
		assert_bool(pair[0].screen_ready(stage)).is_true()
		assert_array(pair[0].take_messages()).is_empty()
		assert_int(pair[0].committed_phase()).is_equal(stage)
		assert_int(pair[1].committed_phase()).is_equal(stage)


func test_early_result_allows_only_bounded_remaining_ticks_and_duplicates_are_idempotent() -> void:
	var pair := _pair()
	assert_bool(pair[1].receive(_message(), 96, 1)).is_true()
	assert_bool(pair[1].active()).is_true()
	assert_bool(pair[1].may_advance(99)).is_true()
	assert_bool(pair[1].may_advance(100)).is_false()
	assert_bool(pair[1].reached(100, DIGEST, 0, 2)).is_true()
	assert_bool(pair[1].agreed()).is_true()
	assert_bool(pair[1].receive(_message(), 100, 3)).is_true()
	assert_bool(pair[1].reached(100, DIGEST, 0, 4)).is_true()
	assert_int(pair[1].take_messages().size()).is_equal(1)
	var changed := _message()
	changed.elapsed = 126
	assert_bool(pair[1].receive(changed, 100, 5)).is_false()
	assert_str(pair[1].error).is_equal("changed_remote_completion_result")


func test_mismatches_skipped_screens_and_premature_host_commits_fail_closed() -> void:
	var pair := _pair()
	assert_bool(pair[0].reached(100, DIGEST, 125, 1)).is_true()
	var mismatch := _message(2)
	mismatch.digest = "cd".repeat(32)
	assert_bool(pair[0].receive(mismatch, 100, 2)).is_false()
	assert_bool(pair[0].agreed()).is_false()
	assert_array(pair[0].take_messages()).is_empty()
	pair = _pair()
	_agree(pair)
	assert_bool(pair[1].receive(_message(1, Wire.Kind.LEVEL_ADVANCE, 1), 100, 3)).is_false()
	pair = _pair()
	_agree(pair)
	assert_bool(pair[0].screen_ready(2)).is_false()
	assert_str(pair[0].error).is_equal("skipped_completion_screen")
	pair = _pair()
	_agree(pair)
	assert_bool(pair[0].receive(_message(2, Wire.Kind.LEVEL_READY, 2), 100, 3)).is_false()


func test_stale_contexts_future_epochs_tick_window_and_preparation_timeouts() -> void:
	var pair := _pair()
	var message := _message()
	message.epoch = 1
	assert_bool(pair[1].receive(message, 100, 1)).is_true()
	assert_bool(pair[1].active()).is_false()
	message.epoch = 3
	assert_bool(pair[1].receive(message, 100, 1)).is_false()
	for tick in [95, 101]:
		pair = _pair()
		message = _message()
		message.tick = tick
		assert_bool(pair[1].receive(message, 96, 1)).is_false()
	pair = _pair()
	assert_bool(pair[0].reached(100, DIGEST, 125, 1)).is_true()
	pair[0].poll(Completion.TIMEOUT_MS + 1)
	assert_str(pair[0].error).is_equal("completion_timeout")
	pair = _pair()
	_agree(pair)
	assert_bool(pair[0].screen_ready(1)).is_true()
	assert_bool(pair[0].request_advance(1, 10)).is_true()
	pair[0].poll(Completion.TIMEOUT_MS + 10)
	assert_str(pair[0].error).is_equal("completion_timeout")
