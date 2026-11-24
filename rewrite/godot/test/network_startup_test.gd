extends GdUnitTestSuite

const Startup := preload("res://scripts/network_startup.gd")
const Protocol := preload("res://scripts/network_startup_protocol.gd")
const Config := preload("res://scripts/network_configuration.gd")
const Fixture := preload("res://test/fixtures/network_setup.gd")
const SESSION := "12121212121212121212121212121212"
const STATE := "abababababababababababababababababababababababababababababababab"


func _peer(player: int, validator: Callable = Callable()) -> RefCounted:
	if not validator.is_valid():
		validator = func(_config): return true
	return Startup.new(player, Fixture.identity(), validator)


func _deliver(from: RefCounted, to: RefCounted) -> void:
	for message in from.take_messages():
		var decoded: Dictionary = Protocol.decode(Protocol.encode(message), message.player)
		assert_bool(decoded.is_empty()).is_false()
		assert_int(to.receive(decoded)).is_equal(Startup.Received.ACCEPTED)


func _compatible() -> Array:
	var peers := [_peer(1), _peer(2)]
	_deliver(peers[0], peers[1])
	_deliver(peers[1], peers[0])
	return peers


func _agreed() -> Array:
	var peers := _compatible()
	assert_bool(peers[0].propose(Fixture.configuration(), SESSION, 1)).is_true()
	_deliver(peers[0], peers[1])
	_deliver(peers[1], peers[0])
	return peers


func test_neither_peer_can_start_until_config_load_state_and_both_ready_agree() -> void:
	var peers := _agreed()
	for peer in peers:
		assert_int(peer.phase).is_equal(Startup.Phase.AGREED)
		assert_bool(peer.start()).is_false()
		assert_bool(peer.confirm_ready()).is_false()
	# A slow host has not loaded yet; a loaded guest cannot become Ready early.
	assert_bool(peers[1].mark_loaded(STATE)).is_true()
	_deliver(peers[1], peers[0])
	assert_bool(peers[1].confirm_ready()).is_false()
	assert_bool(peers[0].mark_loaded(STATE)).is_true()
	_deliver(peers[0], peers[1])
	assert_bool(peers[0].confirm_ready()).is_true()
	_deliver(peers[0], peers[1])
	assert_bool(peers[0].start()).is_false()
	assert_bool(peers[1].confirm_ready()).is_true()
	_deliver(peers[1], peers[0])
	assert_bool(peers[1].start()).is_false()
	assert_bool(peers[0].start()).is_true()
	_deliver(peers[0], peers[1])
	for peer in peers:
		assert_int(peer.phase).is_equal(Startup.Phase.RUNNING)
		assert_dict(peer.configuration()).is_equal(Fixture.configuration())


func test_each_identity_mismatch_is_rejected_before_configuration() -> void:
	for field in Protocol.IDENTITIES:
		var host := _peer(1)
		var identity := Fixture.identity()
		identity[field] = "ff".repeat(32)
		var message := {"kind": "hello", "player": 2, "identity": identity}
		assert_int(host.receive(message)).is_equal(Startup.Received.REJECTED)
		assert_str(host.error).is_equal(field + "_mismatch")
		assert_bool(host.propose(Fixture.configuration(), SESSION, 1)).is_false()
		assert_array(host.take_messages()).is_empty()


func test_application_validation_is_mandatory_on_both_sides_and_cannot_mutate_proposal() -> void:
	var invalid := Startup.new(1, Fixture.identity(), Callable())
	assert_int(invalid.phase).is_equal(Startup.Phase.FAILED)
	var host := _peer(1, func(_config): return "truthy is not validation")
	var guest := _peer(2)
	_deliver(host, guest)
	_deliver(guest, host)
	assert_bool(host.propose(Fixture.configuration(), SESSION, 1)).is_false()
	host = _peer(
		1,
		func(config):
			config.episode = 5
			return true
	)
	guest = _peer(2, func(_config): return false)
	_deliver(host, guest)
	_deliver(guest, host)
	assert_bool(host.propose(Fixture.configuration(), SESSION, 1)).is_true()
	var message: Dictionary = host.take_messages()[0]
	assert_int(message.config.episode).is_equal(1)
	assert_int(guest.receive(message)).is_equal(Startup.Received.REJECTED)
	assert_str(guest.error).is_equal("configuration_rejected")
	assert_array(guest.take_messages()).is_empty()


func test_duplicate_proposal_is_idempotent_and_conflicting_repeat_fails() -> void:
	var peers := _compatible()
	peers[0].propose(Fixture.configuration(), SESSION, 1)
	var message: Dictionary = peers[0].take_messages()[0]
	assert_int(peers[1].receive(message)).is_equal(Startup.Received.ACCEPTED)
	assert_int(peers[1].receive(message)).is_equal(Startup.Received.DUPLICATE)
	assert_int(peers[1].take_messages().size()).is_equal(1)
	var changed: Dictionary = message.duplicate(true)
	changed.config.episode = 2
	changed.digest = Config.digest(changed.config)
	assert_int(peers[1].receive(changed)).is_equal(Startup.Received.REJECTED)
	assert_str(peers[1].error).is_equal("conflicting_control")


func test_wrong_epoch_is_discarded_without_consuming_sequence() -> void:
	var peers := _agreed()
	peers[1].mark_loaded(STATE)
	var message: Dictionary = peers[1].take_messages()[0]
	var stale: Dictionary = message.duplicate(true)
	stale.epoch = 2
	assert_int(peers[0].receive(stale)).is_equal(Startup.Received.STALE)
	assert_int(peers[0].receive(message)).is_equal(Startup.Received.ACCEPTED)
	assert_bool(peers[0].mark_loaded(STATE)).is_true()


func test_initial_state_mismatch_fails_closed() -> void:
	var peers := _agreed()
	peers[0].mark_loaded(STATE)
	peers[1].mark_loaded("ff".repeat(32))
	var message: Dictionary = peers[1].take_messages()[0]
	assert_int(peers[0].receive(message)).is_equal(Startup.Received.REJECTED)
	assert_str(peers[0].error).is_equal("initial_state_mismatch")
	assert_bool(peers[0].confirm_ready()).is_false()
	assert_bool(peers[0].start()).is_false()


func test_early_ready_and_forged_start_cannot_skip_loading() -> void:
	for kind in ["ready", "start"]:
		var peers := _agreed()
		var receiver: int = 0 if kind == "ready" else 1
		var sender: int = 2 if kind == "ready" else 1
		var message := {
			"kind": kind,
			"player": sender,
			"session": SESSION,
			"epoch": 1,
			"sequence": 2,
			"digest": Config.digest(Fixture.configuration()),
			"state": STATE
		}
		assert_int(peers[receiver].receive(message)).is_equal(Startup.Received.REJECTED)
		assert_int(peers[receiver].phase).is_equal(Startup.Phase.FAILED)


func test_timeouts_stop_network_waits_but_not_human_menu_or_ready_selection() -> void:
	var peer := _peer(1)
	peer.check_timeout(0x7fffffffffffffff)
	assert_str(peer.error).is_equal("startup_timeout")
	var peers := _compatible()
	for compatible in peers:
		compatible.check_timeout(0x7fffffffffffffff)
		assert_int(compatible.phase).is_equal(Startup.Phase.COMPATIBLE)
	peers[0].propose(Fixture.configuration(), SESSION, 1)
	peers[0].check_timeout(0x7fffffffffffffff)
	assert_str(peers[0].error).is_equal("startup_timeout")
	peers = _agreed()
	peers[1].check_timeout(0x7fffffffffffffff)
	assert_str(peers[1].error).is_equal("startup_timeout")
	peers = _agreed()
	for loaded in peers:
		loaded.mark_loaded(STATE)
	_deliver(peers[0], peers[1])
	_deliver(peers[1], peers[0])
	for loaded in peers:
		loaded.check_timeout(0x7fffffffffffffff)
		assert_int(loaded.phase).is_equal(Startup.Phase.LOADED)
