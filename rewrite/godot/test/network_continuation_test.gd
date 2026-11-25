extends GdUnitTestSuite

const Decision := preload("res://scripts/network_continuation.gd")
const Wire := preload("res://scripts/network_protocol.gd")
const SESSION := "11111111111111111111111111111111"
const DIGEST := "abababababababababababababababababababababababababababababababab"


func _message(kind := Wire.Kind.CONTINUATION, sequence := 1, digest := DIGEST) -> Dictionary:
	return {
		"kind": kind,
		"session": SESSION,
		"epoch": 2,
		"player": 2 if kind == Wire.Kind.CONTINUATION_ACK else 1,
		"tick": 100,
		"sequence": sequence,
		"digest": digest
	}


func _pair() -> Array:
	var pair := [Decision.new(), Decision.new()]
	for i in 2:
		assert_bool(pair[i].configure(SESSION, 2, i + 1, 100)).is_true()
	return pair


func _deliver(sender: RefCounted, receiver: RefCounted, now := 10) -> Array:
	var messages: Array = sender.take_messages()
	for message in messages:
		var decoded := Wire.decode(Wire.encode(message), SESSION, 2, message.player)
		assert_dict(decoded).is_equal(message)
		assert_bool(receiver.receive(decoded, now)).is_true()
	return messages


func _round(pair: Array, sequence: int, digest: String, now := 1) -> void:
	for peer in pair:
		assert_bool(peer.prepare(sequence, digest, now)).is_true()
	assert_bool(pair[1].propose(sequence, now)).is_false()
	assert_bool(pair[0].propose(sequence, now)).is_true()
	var proposals := _deliver(pair[0], pair[1], now)
	var acks := _deliver(pair[1], pair[0], now)
	var commits := _deliver(pair[0], pair[1], now)
	assert_int(proposals.size()).is_equal(1)
	assert_int(acks.size()).is_equal(1)
	assert_int(commits.size()).is_equal(1)
	assert_bool(pair[0].has_seen_control(acks[0])).is_true()
	assert_bool(pair[1].has_seen_control(proposals[0])).is_true()
	assert_bool(pair[1].has_seen_control(commits[0])).is_true()
	assert_bool(pair[0].receive(acks[0], now)).is_true()
	assert_bool(pair[1].receive(proposals[0], now)).is_true()
	assert_bool(pair[1].receive(commits[0], now)).is_true()
	for peer in pair:
		assert_int(peer.committed_sequence()).is_equal(sequence)
		assert_str(peer.committed_digest(sequence)).is_equal(digest)
		assert_array(peer.take_messages()).is_empty()


func test_fixed_digest_codec_roles_ranges_and_exact_sizes() -> void:
	var expected := "4f54324e01000a01" + SESSION + "020000006400000001000000" + DIGEST
	assert_str(Wire.encode(_message()).hex_encode()).is_equal(expected)
	for kind in [Wire.Kind.CONTINUATION, Wire.Kind.CONTINUATION_ACK, Wire.Kind.CONTINUATION_COMMIT]:
		for sequence in [1, 2]:
			var message := _message(kind, sequence)
			assert_dict(Wire.decode(Wire.encode(message), SESSION, 2, message.player)).is_equal(message)
			message.player = 3 - message.player
			assert_bool(Wire.encode(message).is_empty()).is_true()
	for pair in [["sequence", 0], ["sequence", 3], ["tick", 0], ["digest", "xx".repeat(32)]]:
		var message := _message()
		message[pair[0]] = pair[1]
		assert_bool(Wire.encode(message).is_empty()).is_true()
	var packet := expected.hex_decode()
	for length in packet.size():
		assert_dict(Wire.decode(packet.slice(0, length), SESSION, 2, 1)).is_empty()
	packet.append(0)
	assert_dict(Wire.decode(packet, SESSION, 2, 1)).is_empty()
	assert_dict(Wire.decode(expected.hex_decode(), SESSION, 2, 2)).is_empty()


func test_two_decisions_commit_only_after_local_verification_and_are_idempotent() -> void:
	var pair := _pair()
	_round(pair, 1, DIGEST)
	for peer in pair:
		peer.poll(1000000)
		assert_str(peer.error).is_empty()
	_round(pair, 2, "cd".repeat(32), 1000001)
	assert_bool(pair[0].propose(2, 1000002)).is_true()
	assert_array(pair[0].take_messages()).is_empty()
	assert_bool(pair[0].prepare(3, DIGEST, 1000002)).is_false()


func test_early_proposal_waits_for_guest_derivation_and_does_not_reset_timeout() -> void:
	var pair := _pair()
	assert_bool(pair[0].prepare(1, DIGEST, 1)).is_true()
	assert_bool(pair[0].propose(1, 1)).is_true()
	var proposals := _deliver(pair[0], pair[1], 1)
	assert_int(pair[1].committed_sequence()).is_equal(0)
	assert_array(pair[1].take_messages()).is_empty()
	assert_bool(pair[1].receive(proposals[0], 20000)).is_true()
	assert_bool(pair[1].prepare(1, DIGEST, 20001)).is_true()
	_deliver(pair[1], pair[0], 20002)
	_deliver(pair[0], pair[1], 20003)
	assert_int(pair[1].committed_sequence()).is_equal(1)
	pair = _pair()
	assert_bool(pair[1].receive(_message(), 1)).is_true()
	assert_bool(pair[1].receive(_message(), 20000)).is_true()
	assert_bool(pair[1].prepare(1, DIGEST, Decision.TIMEOUT_MS + 1)).is_false()
	assert_str(pair[1].error).is_equal("continuation_timeout")


func test_mismatched_candidates_conflicts_and_premature_controls_fail_closed() -> void:
	var pair := _pair()
	assert_bool(pair[1].prepare(1, "cd".repeat(32), 1)).is_true()
	assert_bool(pair[1].receive(_message(), 2)).is_false()
	assert_str(pair[1].error).is_equal("continuation_proposal_mismatch")
	assert_array(pair[1].take_messages()).is_empty()
	pair = _pair()
	assert_bool(pair[0].receive(_message(Wire.Kind.CONTINUATION_ACK), 1)).is_false()
	pair = _pair()
	assert_bool(pair[1].receive(_message(Wire.Kind.CONTINUATION_COMMIT), 1)).is_false()
	pair = _pair()
	assert_bool(pair[1].receive(_message(Wire.Kind.CONTINUATION, 2), 1)).is_false()
	pair = _pair()
	_round(pair, 1, DIGEST)
	assert_bool(pair[1].receive(_message(Wire.Kind.CONTINUATION_COMMIT, 1, "cd".repeat(32)), 11)).is_false()
	assert_str(pair[1].committed_digest(1)).is_empty()


func test_stale_contexts_are_ignored_and_future_or_wrong_final_tick_fails() -> void:
	var pair := _pair()
	var message := _message()
	message.epoch = 1
	assert_bool(pair[1].receive(message, 1)).is_true()
	assert_array(pair[1].take_messages()).is_empty()
	message.epoch = 3
	assert_bool(pair[1].receive(message, 1)).is_false()
	pair = _pair()
	message = _message()
	message.tick = 101
	assert_bool(pair[1].receive(message, 1)).is_false()
	pair = _pair()
	assert_bool(pair[0].prepare(1, DIGEST, 1)).is_true()
	pair[0].poll(1000000)  # Merely deriving a candidate is not a timed proposal.
	assert_str(pair[0].error).is_empty()
	assert_bool(pair[0].propose(1, 1000001)).is_true()
	pair[0].poll(1000001 + Decision.TIMEOUT_MS)
	assert_str(pair[0].error).is_equal("continuation_timeout")
