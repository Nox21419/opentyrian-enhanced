extends GdUnitTestSuite

const Pause := preload("res://scripts/network_pause.gd")
const Wire := preload("res://scripts/network_protocol.gd")
const SESSION := "91919191919191919191919191919191"
const DIGEST := "abababababababababababababababababababababababababababababababab"


func _pair(delay := 3) -> Array:
	var peers := [Pause.new(), Pause.new()]
	for i in 2:
		assert_bool(peers[i].configure(SESSION, 1, i + 1, delay)).is_true()
	return peers


func _deliver(sender: RefCounted, receiver: RefCounted, tick: int) -> Array[Dictionary]:
	var messages: Array[Dictionary] = sender.take_messages()
	for message in messages:
		assert_bool(Wire.valid_message(message)).is_true()
		assert_bool(receiver.receive(message, tick, 100)).is_true()
	return messages


func _paused(peers: Array, current := 10) -> int:
	assert_bool(peers[0].request_pause(current, 100)).is_true()
	_deliver(peers[0], peers[1], current)
	var tick: int = peers[0].target
	assert_bool(peers[0].may_advance(tick - 1)).is_true()
	assert_bool(peers[0].may_advance(tick)).is_false()
	assert_bool(peers[0].reached(tick, DIGEST)).is_true()
	_deliver(peers[0], peers[1], tick)
	assert_bool(peers[0].request_resume(100)).is_false()
	assert_bool(peers[1].reached(tick, DIGEST)).is_true()
	_deliver(peers[1], peers[0], tick)
	assert_bool(peers[0].phase == Pause.Phase.PAUSED).is_true()
	assert_bool(peers[1].phase == Pause.Phase.PAUSED).is_true()
	return tick


func test_host_pause_requires_matching_boundary_and_resume_requires_both_new_epoch_readies() -> void:
	var peers := _pair()
	var tick := _paused(peers)
	assert_int(tick).is_equal(14)
	assert_bool(peers[1].request_resume(100)).is_false()
	peers[0].poll(1000000)  # Human pause has no preparation timeout.
	assert_str(peers[0].error).is_empty()
	assert_bool(peers[0].request_resume(100)).is_true()
	assert_bool(peers[0].needs_input_reset()).is_true()
	assert_bool(peers[0].input_reset_done(DIGEST)).is_true()
	var host_messages := _deliver(peers[0], peers[1], tick)
	assert_bool(peers[0].may_advance(tick)).is_false()
	assert_bool(peers[1].may_advance(tick)).is_false()
	assert_bool(peers[1].input_reset_done(DIGEST)).is_true()
	var guest_messages := _deliver(peers[1], peers[0], tick)
	for peer in peers:
		assert_int(peer.epoch).is_equal(2)
		assert_bool(peer.may_advance(tick)).is_true()
	# Repeated READY and late prior-epoch controls do not replay the transition.
	assert_bool(peers[0].receive(guest_messages[0], tick, 100)).is_true()
	for message in host_messages:
		assert_bool(peers[1].receive(message, tick, 100)).is_true()
	assert_bool(peers[0].request_pause(tick + 20, 100)).is_true()
	_deliver(peers[0], peers[1], tick + 20)
	assert_int(peers[0].target).is_equal(tick + 24)
	assert_bool(peers[1].receive(host_messages[1], tick + 20, 100)).is_true()


func test_guest_request_and_maximum_peer_lead_have_safe_target() -> void:
	var peers := _pair()
	assert_bool(peers[1].request_pause(24, 100)).is_true()
	_deliver(peers[1], peers[0], 20)
	assert_int(peers[0].target).is_equal(24)
	_deliver(peers[0], peers[1], 24)
	assert_bool(peers[1].may_advance(24)).is_false()
	assert_bool(peers[1].reached(24, DIGEST)).is_true()


func test_mismatching_boundary_and_changed_core_on_resume_fail_closed() -> void:
	var peers := _pair()
	peers[0].request_pause(10, 100)
	_deliver(peers[0], peers[1], 10)
	peers[0].reached(14, DIGEST)
	peers[1].reached(14, "cd".repeat(32))
	var mismatch: Dictionary = peers[1].take_messages()[0]
	assert_bool(peers[0].receive(mismatch, 14, 100)).is_false()
	assert_str(peers[0].error).is_equal("pause_state_mismatch")
	peers = _pair()
	_paused(peers)
	peers[0].request_resume(100)
	assert_bool(peers[0].input_reset_done("cd".repeat(32))).is_false()
	assert_str(peers[0].error).is_equal("resume_state_changed")


func test_conflicting_duplicates_out_of_order_control_and_timeout_are_rejected() -> void:
	var peers := _pair()
	peers[0].request_pause(10, 100)
	var message: Dictionary = peers[0].take_messages()[0]
	assert_bool(peers[1].receive(message, 10, 100)).is_true()
	assert_bool(peers[1].receive(message, 10, 100)).is_true()
	message = message.duplicate()
	message.tick += 1
	assert_bool(peers[1].receive(message, 10, 100)).is_false()
	assert_str(peers[1].error).is_equal("conflicting_pause_control")
	peers = _pair()
	message.sequence = 3
	assert_bool(peers[1].receive(message, 10, 100)).is_false()
	assert_str(peers[1].error).is_equal("pause_control_order")
	peers = _pair()
	assert_bool(peers[1].request_pause(10, 100)).is_true()
	peers[1].poll(100 + Pause.TIMEOUT_MS)
	assert_str(peers[1].error).is_equal("pause_timeout")
