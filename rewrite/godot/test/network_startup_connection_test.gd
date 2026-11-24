extends GdUnitTestSuite

const Connection := preload("res://scripts/network_startup_connection.gd")
const Startup := preload("res://scripts/network_startup.gd")
const Fixture := preload("res://test/fixtures/network_setup.gd")
const Identity := preload("res://scripts/network_identity.gd")
var _nodes: Array[Node] = []


func after_test() -> void:
	for node in _nodes:
		node.free()
	_nodes.clear()


func _connection() -> Node:
	var connection := Connection.new()
	add_child(connection)
	_nodes.append(connection)
	return connection


func _wait(condition: Callable) -> void:
	var deadline := Time.get_ticks_msec() + 4000
	while not condition.call() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	assert_bool(condition.call()).is_true()


func _pair(guest_identity := Fixture.identity(), host_identity := Fixture.identity()) -> Array:
	var host := _connection()
	var guest := _connection()
	var validate := func(_config): return true
	assert_int(host.host(host_identity, validate, 27735)).is_equal(OK)
	assert_int(guest.join("127.0.0.1", guest_identity, validate, 27735)).is_equal(OK)
	return [host, guest]


func test_real_enet_peers_negotiate_and_pass_shared_startup_barrier() -> void:
	var peers := _pair()
	await _wait(
		func():
			return (
				peers[0].startup != null
				and peers[1].startup != null
				and peers[0].startup.phase == Startup.Phase.COMPATIBLE
				and peers[1].startup.phase == Startup.Phase.COMPATIBLE
			)
	)
	assert_bool(peers[0].propose(Fixture.configuration(), "12".repeat(16), 1)).is_true()
	await _wait(func(): return peers[0].startup.phase == Startup.Phase.AGREED)
	assert_bool(peers[0].mark_loaded("ab".repeat(32))).is_true()
	assert_bool(peers[1].mark_loaded("ab".repeat(32))).is_true()
	await _wait(
		func(): return peers[0].startup.phase == Startup.Phase.LOADED and peers[1].startup.phase == Startup.Phase.LOADED
	)
	assert_bool(peers[0].start()).is_false()
	peers[0].confirm_ready()
	peers[1].confirm_ready()
	await _wait(func(): return peers[0].startup.get("_remote_ready") and peers[1].startup.get("_remote_ready"))
	assert_bool(peers[1].start()).is_false()
	assert_bool(peers[0].start()).is_true()
	await _wait(func(): return peers[0].running and peers[1].running)
	peers[1].stop()
	await _wait(func(): return not peers[0].running)
	assert_bool(peers[0].error.is_empty()).is_false()


func test_real_mismatched_peers_close_without_entering_config_or_gameplay() -> void:
	var identity := Fixture.identity()
	identity.content = "ff".repeat(32)
	var peers := _pair(identity)
	await _wait(func(): return not peers[0].error.is_empty() and not peers[1].error.is_empty())
	assert_bool(peers[0].running).is_false()
	assert_bool(peers[1].running).is_false()
	assert_bool(peers[0].transport.peer == null).is_true()
	assert_bool(peers[1].transport.peer == null).is_true()
	assert_bool(peers[0].error == "content_mismatch" or peers[1].error == "content_mismatch").is_true()


func test_malformed_startup_packet_closes_receiver() -> void:
	var peers := _pair()
	await _wait(
		func():
			return (
				peers[0].startup != null
				and peers[1].startup != null
				and peers[0].startup.phase == Startup.Phase.COMPATIBLE
				and peers[1].startup.phase == Startup.Phase.COMPATIBLE
			)
	)
	assert_int(peers[1].transport.send_packet("not a startup packet".to_utf8_buffer())).is_equal(OK)
	await _wait(func(): return not peers[0].error.is_empty())
	assert_str(peers[0].error).is_equal("invalid_startup_message")
	assert_bool(peers[0].transport.peer == null).is_true()


func test_actual_loaded_build_and_content_identities_cross_real_transport() -> void:
	var first: Dictionary = Identity.collect(1)
	var second: Dictionary = Identity.collect(1)
	assert_bool(first.has("identity") and second.has("identity")).is_true()
	if not first.has("identity") or not second.has("identity"):
		return
	var peers := _pair(second.identity, first.identity)
	await _wait(
		func():
			return (
				peers[0].startup != null
				and peers[1].startup != null
				and peers[0].startup.phase == Startup.Phase.COMPATIBLE
				and peers[1].startup.phase == Startup.Phase.COMPATIBLE
			)
	)
	assert_str(peers[0].error).is_empty()
	assert_str(peers[1].error).is_empty()
