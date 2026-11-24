extends GdUnitTestSuite

const Wire := preload("res://scripts/network_protocol.gd")
const SESSION := "00112233445566778899aabbccddeeff"


func _input_message() -> Dictionary:
	return {
		"kind": Wire.Kind.INPUT,
		"session": SESSION,
		"epoch": 7,
		"player": 2,
		"tick": 291,
		"sequence": 0,
		"frame": Wire.neutral_frame()
	}


func test_fixed_wire_fixture_and_full_signed_input_roundtrip() -> void:
	var message := _input_message()
	message.frame = {
		"mask": 16, "mouse_mask": 16, "mouse_dx": -30, "mouse_dy": 30, "analog_x": -1, "analog_y": 2, "new_key": true
	}
	var expected := "4f54324e0100010200112233445566778899aabbccddeeff070000002301000000000000"
	expected += "10001001e2ffffff1e000000ffffffff02000000"
	assert_str(Wire.encode(message).hex_encode()).is_equal(expected)
	assert_dict(Wire.decode(expected.hex_decode(), SESSION, 7, 2)).is_equal(message)
	message.frame.mask = 0x3ff
	message.frame.mouse_mask = 0xf0
	message.frame.mouse_dx = Wire.MIN_I32
	message.frame.mouse_dy = Wire.MAX_I32
	message.frame.analog_x = Wire.MAX_I32
	message.frame.analog_y = Wire.MIN_I32
	assert_dict(Wire.decode(Wire.encode(message), SESSION, 7, 2)).is_equal(message)


func test_control_messages_roundtrip_and_guest_cannot_commit() -> void:
	for kind in [Wire.Kind.STATE, Wire.Kind.READY, Wire.Kind.START, Wire.Kind.PAUSE, Wire.Kind.LEAVE]:
		var message := {
			"kind": kind,
			"session": SESSION,
			"epoch": 7,
			"player": 1,
			"tick": Wire.MAX_TICK,
			"sequence": 0 if kind == Wire.Kind.STATE else 1
		}
		if kind == Wire.Kind.PAUSE:
			message.action = Wire.Pause.COMMIT_PAUSE
		elif kind == Wire.Kind.LEAVE:
			message.reason = Wire.Leave.DESYNC
		else:
			message.digest = "ab".repeat(32)
		assert_dict(Wire.decode(Wire.encode(message), SESSION, 7, 1)).is_equal(message)
		message.player = 2
		if kind in [Wire.Kind.START, Wire.Kind.PAUSE]:
			assert_bool(Wire.encode(message).is_empty()).is_true()
	var request := {
		"kind": Wire.Kind.PAUSE,
		"session": SESSION,
		"epoch": 7,
		"player": 2,
		"tick": 40,
		"sequence": 5,
		"action": Wire.Pause.REQUEST_RESUME
	}
	assert_dict(Wire.decode(Wire.encode(request), SESSION, 7, 2)).is_equal(request)


func test_stale_session_epoch_or_spoofed_role_is_rejected() -> void:
	var packet: PackedByteArray = Wire.encode(_input_message())
	assert_dict(Wire.decode(packet, "ff".repeat(16), 7, 2)).is_empty()
	assert_dict(Wire.decode(packet, SESSION, 8, 2)).is_empty()
	assert_dict(Wire.decode(packet, SESSION, 7, 1)).is_empty()
	assert_dict(Wire.decode(packet, SESSION, 7, 0)).is_empty()


func test_truncation_trailing_bytes_and_unknown_wire_values_are_rejected() -> void:
	var packet: PackedByteArray = Wire.encode(_input_message())
	for length in packet.size():
		assert_dict(Wire.decode(packet.slice(0, length), SESSION, 7, 2)).is_empty()
	var extra := packet.duplicate()
	extra.append(0)
	assert_dict(Wire.decode(extra, SESSION, 7, 2)).is_empty()
	extra.resize(4096)
	assert_dict(Wire.decode(extra, SESSION, 7, 2)).is_empty()
	for mutation in [[0, 0], [4, 2], [6, 0], [6, 255], [7, 3], [37, 4], [38, 1], [39, 2]]:
		var changed := packet.duplicate()
		changed[mutation[0]] = mutation[1]
		assert_dict(Wire.decode(changed, SESSION, 7, 2)).is_empty()


func test_unknown_fields_wrong_types_and_out_of_range_inputs_are_rejected() -> void:
	var message := _input_message()
	message.extra = 0
	assert_bool(Wire.encode(message).is_empty()).is_true()
	message = _input_message()
	message.frame.extra = 0
	assert_bool(Wire.encode(message).is_empty()).is_true()
	for invalid in [1.0, "1", true, null, [], {}]:
		message = _input_message()
		message.tick = invalid
		assert_bool(Wire.encode(message).is_empty()).is_true()
		message = _input_message()
		message.frame.mouse_dx = invalid
		assert_bool(Wire.encode(message).is_empty()).is_true()
	for field in ["mask", "mouse_mask", "new_key", "mouse_dx", "analog_x"]:
		message = _input_message()
		message.frame.erase(field)
		assert_bool(Wire.encode(message).is_empty()).is_true()
	for pair in [
		["mask", 1024],
		["mouse_mask", 1],
		["new_key", 1],
		["mouse_dx", Wire.MIN_I32 - 1],
		["analog_y", Wire.MAX_I32 + 1]
	]:
		message = _input_message()
		message.frame[pair[0]] = pair[1]
		assert_bool(Wire.encode(message).is_empty()).is_true()
	for invalid in ["", "AB".repeat(16), "gg".repeat(16), "0".repeat(31)]:
		message = _input_message()
		message.session = invalid
		assert_bool(Wire.encode(message).is_empty()).is_true()
	for pair in [["epoch", 0], ["tick", -1], ["tick", Wire.MAX_TICK + 1], ["sequence", 1]]:
		message = _input_message()
		message[pair[0]] = pair[1]
		assert_bool(Wire.encode(message).is_empty()).is_true()


func test_control_sequences_digests_actions_and_reasons_are_strict() -> void:
	var message := {
		"kind": Wire.Kind.READY,
		"session": SESSION,
		"epoch": 7,
		"player": 2,
		"tick": 0,
		"sequence": 1,
		"digest": "12".repeat(32)
	}
	for digest in ["", "ab".repeat(31), "XX".repeat(32), 42]:
		message.digest = digest
		assert_bool(Wire.encode(message).is_empty()).is_true()
	message.digest = "12".repeat(32)
	message.sequence = 0
	assert_bool(Wire.encode(message).is_empty()).is_true()
	message = {
		"kind": Wire.Kind.PAUSE, "session": SESSION, "epoch": 7, "player": 1, "tick": 0, "sequence": 1, "action": 4
	}
	assert_bool(Wire.encode(message).is_empty()).is_true()
	message = {
		"kind": Wire.Kind.LEAVE, "session": SESSION, "epoch": 7, "player": 1, "tick": 0, "sequence": 1, "reason": 5
	}
	assert_bool(Wire.encode(message).is_empty()).is_true()
