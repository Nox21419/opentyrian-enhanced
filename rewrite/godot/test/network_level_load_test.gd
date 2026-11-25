extends GdUnitTestSuite

const Load := preload("res://scripts/network_level_load.gd")
const Wire := preload("res://scripts/network_protocol.gd")
const SESSION := "12121212121212121212121212121212"
const PROPOSAL := "abababababababababababababababababababababababababababababababab"
const REQUEST := "cdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcd"
const STATE := "efefefefefefefefefefefefefefefefefefefefefefefefefefefefefefefef"
const SEED := "ffffffffffffffff"


func _pair() -> Array:
	var pair := [Load.new(), Load.new()]
	for i in 2:
		assert_bool(pair[i].configure(SESSION, 2, i + 1, 100, 2, PROPOSAL)).is_true()
	return pair


func _deliver(sender: RefCounted, receiver: RefCounted, now := 2) -> Array:
	var messages: Array = sender.take_messages()
	for message in messages:
		var packet := Wire.encode(message)
		assert_int(packet.size()).is_equal(44 if message.kind == Wire.Kind.LOAD_SEED else 68)
		var decoded := Wire.decode(packet, SESSION, 2, message.player)
		assert_dict(decoded).is_equal(message)
		assert_bool(receiver.receive(decoded, now)).is_true()
	return messages


func _loaded_pair() -> Array:
	var pair := _pair()
	assert_bool(pair[0].offer(SEED, 1)).is_true()
	_deliver(pair[0], pair[1])
	for peer in pair:
		assert_bool(peer.loaded(REQUEST, STATE, 3)).is_true()
	_deliver(pair[0], pair[1], 4)
	_deliver(pair[1], pair[0], 4)
	return pair


func test_offer_independent_load_and_host_activation_require_both_digests() -> void:
	var pair := _pair()
	assert_bool(pair[1].offer(SEED, 1)).is_false()
	assert_bool(pair[0].loaded(REQUEST, STATE, 1)).is_false()
	assert_bool(pair[0].offer(SEED, 1)).is_true()
	var offers := _deliver(pair[0], pair[1])
	assert_bool(pair[0].activate(2)).is_false()
	assert_bool(pair[1].loaded(REQUEST, STATE, 3)).is_true()
	var guest_ready := _deliver(pair[1], pair[0], 4)
	assert_bool(pair[0].ready()).is_false()
	assert_bool(pair[0].loaded(REQUEST, STATE, 5)).is_true()
	var host_ready := _deliver(pair[0], pair[1], 6)
	assert_bool(pair[1].activate(7)).is_false()
	assert_bool(pair[0].activate(7)).is_true()
	assert_bool(pair[1].committed()).is_false()
	var starts := _deliver(pair[0], pair[1], 8)
	for peer in pair:
		assert_bool(peer.committed()).is_true()
		assert_int(peer.next_epoch).is_equal(3)
		assert_bool(peer.poll(999999)).is_true()
	for message in offers + host_ready + starts:
		assert_bool(pair[1].has_seen_control(message)).is_true()
		assert_bool(pair[1].receive(message, 999999)).is_true()
	assert_bool(pair[0].receive(guest_ready[0], 999999)).is_true()
	assert_bool(pair[0].activate(999999)).is_true()
	assert_array(pair[0].take_messages()).is_empty()


func test_context_and_duplicate_conflicts_and_premature_activation_fail_closed() -> void:
	var pair := _loaded_pair()
	var start := {
		"kind": Wire.Kind.LOAD_ACTIVATE,
		"session": SESSION,
		"epoch": 2,
		"player": 1,
		"tick": 100,
		"sequence": 2,
		"digest": "00".repeat(32)
	}
	assert_bool(pair[1].receive(start, 5)).is_false()
	assert_str(pair[1].error).is_equal("premature_load_activation")
	for field in ["epoch", "tick", "sequence", "seed"]:
		pair = _pair()
		assert_bool(pair[0].offer(SEED, 1)).is_true()
		var offer: Dictionary = pair[0].take_messages()[0]
		assert_bool(pair[1].receive(offer, 2)).is_true()
		offer[field] = "00".repeat(8) if field == "seed" else 3 if field != "tick" else 101
		assert_bool(pair[1].receive(offer, 3)).is_false()
	pair = _pair()
	start.digest = STATE
	assert_bool(pair[1].receive(start, 1)).is_false()


func test_different_request_state_or_proposal_never_authorizes_activation() -> void:
	for mismatch in ["request", "state", "proposal"]:
		var pair := _pair()
		if mismatch == "proposal":
			pair[1] = Load.new()
			assert_bool(pair[1].configure(SESSION, 2, 2, 100, 2, STATE)).is_true()
		assert_bool(pair[0].offer(SEED, 1)).is_true()
		_deliver(pair[0], pair[1])
		assert_bool(pair[0].loaded(REQUEST, STATE, 3)).is_true()
		(
			assert_bool(
				pair[1].loaded(
					STATE if mismatch == "request" else REQUEST, REQUEST if mismatch == "state" else STATE, 3
				)
			)
			. is_true()
		)
		var message: Dictionary = pair[0].take_messages()[0]
		assert_bool(pair[1].receive(message, 4)).is_false()
		assert_str(pair[1].error).is_equal("load_state_mismatch")
		assert_bool(pair[1].committed()).is_false()


func test_active_timeout_is_not_extended_by_duplicates_and_idle_human_wait_has_none() -> void:
	var pair := _pair()
	for peer in pair:
		assert_bool(peer.poll(999999)).is_true()
	assert_bool(pair[0].offer(SEED, 1)).is_true()
	var offer: Dictionary = pair[0].take_messages()[0]
	assert_bool(pair[1].receive(offer, 2)).is_true()
	assert_bool(pair[1].receive(offer, 30001)).is_true()
	assert_bool(pair[1].poll(30002)).is_false()
	assert_str(pair[1].error).is_equal("load_timeout")
	assert_bool(pair[0].offer(SEED, 30000)).is_true()
	assert_bool(pair[0].poll(30001)).is_false()


func test_codec_rejects_roles_lengths_values_and_context_overflow() -> void:
	var pair := _pair()
	assert_bool(pair[0].offer(SEED, 1)).is_true()
	var offer: Dictionary = pair[0].take_messages()[0]
	var packet := Wire.encode(offer)
	for count in packet.size():
		assert_dict(Wire.decode(packet.slice(0, count), SESSION, 2, 1)).is_empty()
	packet.append(0)
	assert_dict(Wire.decode(packet, SESSION, 2, 1)).is_empty()
	for item in [["player", 2], ["seed", "FFFFFFFFFFFFFFFF"], ["seed", 0], ["sequence", 3], ["tick", 0]]:
		var invalid := offer.duplicate()
		invalid[item[0]] = item[1]
		assert_bool(Wire.encode(invalid).is_empty()).is_true()
	var exhausted := Load.new()
	assert_bool(exhausted.configure(SESSION, Wire.MAX_TICK, 1, 100, 1, PROPOSAL)).is_false()


func test_old_context_is_ignored_without_changing_load() -> void:
	var pair := _pair()
	assert_bool(pair[0].offer(SEED, 1)).is_true()
	var offer: Dictionary = pair[0].take_messages()[0]
	offer.epoch = 1
	assert_bool(pair[1].receive(offer, 2)).is_true()
	offer.epoch = 2
	offer.session = "34".repeat(16)
	assert_bool(pair[1].receive(offer, 3)).is_true()
	assert_str(pair[1].seed).is_empty()
