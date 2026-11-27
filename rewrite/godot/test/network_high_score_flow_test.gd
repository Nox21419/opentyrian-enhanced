extends "res://test/network_episode_high_scores_test.gd"

const Flow := preload("res://scripts/network_high_score_flow.gd")
const Wire := preload("res://scripts/network_high_score_wire.gd")


func _pair() -> Array:
	var source := _ending_context(1)
	var peers := [Flow.new(), Flow.new()]
	for i in 2:
		var context := {
			"session": "0123456789abcdef0123456789abcdef", "epoch": 1, "tick": 10, "decision": 1, "player": i + 1
		}
		(
			assert_bool(
				peers[i].configure(context, source[0], source[1], source[2], source[3], _rows() if i == 0 else [], 0)
			)
			. is_true()
		)
	_transfer(peers[0], peers[1], 1)
	return peers


func _transfer(sender: RefCounted, receiver: RefCounted, player: int, now := 1) -> void:
	for message in sender.take_messages():
		var bytes: PackedByteArray = Wire.encode(message)
		assert_bool(bytes.is_empty()).is_false()
		var decoded: Dictionary = Wire.decode(bytes, player)
		assert_dict(decoded).is_equal(message)
		assert_bool(receiver.receive(decoded, now)).is_true()


func test_stage_agreement_requires_peer_ready_and_explicit_persistence() -> void:
	var peers := _pair()
	var host: RefCounted = peers[0]
	var guest: RefCounted = peers[1]
	while host.snapshot().phase != "done":
		var stage: Dictionary = host.snapshot()
		assert_dict(guest.snapshot()).is_equal(stage)
		host.ready(stage.serial, 2)
		_transfer(host, guest, 1, 2)
		if stage.phase == "name":
			host.edit("NETWORK")
			_transfer(host, guest, 1, 2)
			assert_str(guest.snapshot().text).is_equal("NETWORK")
			host.submit("NETWORK", false, 2)
			assert_dict(host.pending_transaction()).is_empty()
		guest.ready(stage.serial, 3)
		_transfer(guest, host, 2, 3)
		if stage.phase == "name":
			var transaction: Dictionary = host.pending_transaction()
			assert_bool(transaction.is_empty()).is_false()
			assert_str(guest.snapshot().phase).is_equal("name")
			assert_bool(host.persisted(transaction.digest, 3)).is_true()
		else:
			assert_bool(host.advance(stage.serial, 3)).is_true()
		_transfer(host, guest, 1, 3)
	for peer in peers:
		peer.ready(peer.snapshot().serial, 4)
	_transfer(host, guest, 1, 4)
	_transfer(guest, host, 2, 4)
	host.finish(5)
	_transfer(host, guest, 1, 5)
	assert_bool(host.complete()).is_false()
	guest.finish(6)
	_transfer(guest, host, 2, 6)
	assert_bool(host.complete()).is_true()
	assert_bool(guest.complete()).is_true()


func test_invalid_context_and_codec_role_and_integer_bounds() -> void:
	var flow := Flow.new()
	assert_bool(flow.configure({"player": 1}, {}, {}, {}, {}, [], 0)).is_false()
	var peers := _pair()
	var stage: Dictionary = peers[0].snapshot()
	peers[0].ready(stage.serial, 1)
	var message: Dictionary = peers[0].take_messages()[0]
	assert_dict(Wire.decode(Wire.encode(message), 2)).is_empty()
	message.serial = 6
	assert_bool(Wire.encode(message).is_empty()).is_true()
	var rows := _rows()
	rows[0].score = 9223372036854775807
	assert_array(Wire.decode_rows(Wire.encode_rows(rows))).is_equal(rows)


func test_duplicate_readiness_does_not_extend_render_timeout() -> void:
	var peers := _pair()
	var host: RefCounted = peers[0]
	var guest: RefCounted = peers[1]
	guest.ready(guest.snapshot().serial, 1)
	var ready_message: Dictionary = guest.take_messages()[0]
	assert_bool(host.receive(ready_message, 2)).is_true()
	assert_bool(host.receive(ready_message, Flow.RENDER_MS - 1)).is_true()
	assert_bool(host.poll(Flow.RENDER_MS)).is_false()
	assert_str(host.error).is_equal("high_score_timeout")


func test_conflicting_ready_and_premature_advance_fail_closed() -> void:
	var peers := _pair()
	var host: RefCounted = peers[0]
	var guest: RefCounted = peers[1]
	guest.ready(guest.snapshot().serial, 1)
	var message: Dictionary = guest.take_messages()[0]
	assert_bool(host.receive(message, 2)).is_true()
	message.digest = "a".repeat(64)
	assert_bool(host.receive(message, 3)).is_false()
	assert_str(host.error).is_equal("conflicting_high_score_message")
	peers = _pair()
	host = peers[0]
	guest = peers[1]
	host.ready(host.snapshot().serial, 1)
	message = host.take_messages()[0]
	message.kind = "advance"
	assert_bool(guest.receive(message, 2)).is_false()
	assert_str(guest.error).is_equal("table_advance_before_ready")
