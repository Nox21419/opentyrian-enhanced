extends GdUnitTestSuite

const Lobby := preload("res://scripts/lan_lobby.gd")
var _nodes: Array[Node] = []


func after_test() -> void:
	for node in _nodes:
		node.free()
	_nodes.clear()


func _lobby() -> Node:
	var lobby := Lobby.new()
	add_child(lobby)
	_nodes.append(lobby)
	return lobby


func _host(lobby: Node) -> int:
	for port in range(27635, 27655):
		if lobby.host(port) == OK:
			return port
	fail("No free test port")
	return 0


func _wait(condition: Callable) -> void:
	var deadline := Time.get_ticks_msec() + 3000
	while not condition.call() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	assert_bool(condition.call()).is_true()


func test_two_peers_complete_handshake_and_disconnect() -> void:
	var host := _lobby()
	var client := _lobby()
	var port := _host(host)
	assert_bool(host.connected).is_false()
	assert_int(client.join("127.0.0.1", port)).is_equal(OK)
	await _wait(func(): return host.connected and client.connected)
	assert_str(host.status_key).is_equal("net_connected")
	assert_str(client.status_key).is_equal("net_connected")
	client.close()
	await _wait(func(): return host.peer == null)
	assert_bool(host.connected).is_false()
	assert_str(host.status_key).is_equal("net_disconnected")
	# Closing releases the socket; a new session can use the same port.
	assert_int(host.host(port)).is_equal(OK)


func test_invalid_address_and_port_do_not_open_socket() -> void:
	var client := _lobby()
	for address in ["", "example.com", "999.1.2.3", "127.0.0.1:26635"]:
		assert_int(client.join(address)).is_equal(ERR_INVALID_PARAMETER)
		assert_bool(client.peer == null).is_true()
		assert_str(client.status_key).is_equal("net_bad_address")
	assert_int(client.host(0)).is_equal(ERR_INVALID_PARAMETER)
	assert_int(client.join("127.0.0.1", 65536)).is_equal(ERR_INVALID_PARAMETER)


func test_occupied_port_fails_without_interrupting_host() -> void:
	var host := _lobby()
	var other := _lobby()
	var port := _host(host)
	# A deliberate native bind failure prints an engine error as well as returning
	# ERR_CANT_CREATE. Suppress only this synchronous, explicitly checked failure.
	var print_errors := Engine.print_error_messages
	Engine.print_error_messages = false
	var error: int = other.host(port)
	Engine.print_error_messages = print_errors
	assert_int(error).is_equal(ERR_CANT_CREATE)
	assert_bool(other.peer == null).is_true()
	assert_str(other.status_key).is_equal("net_host_failed")
	assert_bool(host.hosting).is_true()
	assert_bool(host.peer != null).is_true()


func test_join_timeout_closes_socket() -> void:
	var client := _lobby()
	assert_int(client.join("127.0.0.1", 27655)).is_equal(OK)
	client.set("_deadline", Time.get_ticks_msec() - 1)
	client._process(0.0)
	assert_str(client.status_key).is_equal("net_timeout")
	assert_bool(client.peer == null).is_true()


func test_bad_handshake_is_rejected() -> void:
	var host := _lobby()
	var port := _host(host)
	var raw := ENetMultiplayerPeer.new()
	assert_int(raw.create_client("127.0.0.1", port, 1)).is_equal(OK)
	var deadline := Time.get_ticks_msec() + 3000
	while raw.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTING and Time.get_ticks_msec() < deadline:
		raw.poll()
		await get_tree().process_frame
	assert_int(raw.get_connection_status()).is_equal(MultiplayerPeer.CONNECTION_CONNECTED)
	raw.set_target_peer(1)
	raw.transfer_mode = MultiplayerPeer.TRANSFER_MODE_RELIABLE
	assert_int(raw.put_packet('["OT2-LAN-LOBBY",999,"wrong"]'.to_utf8_buffer())).is_equal(OK)
	while host.peer != null and Time.get_ticks_msec() < deadline:
		raw.poll()
		await get_tree().process_frame
	assert_bool(host.peer == null).is_true()
	assert_str(host.status_key).is_equal("net_incompatible")
	raw.close()


func test_backgrounding_closes_connection() -> void:
	var host := _lobby()
	_host(host)
	host.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	assert_bool(host.peer == null).is_true()
	assert_str(host.status_key).is_equal("net_disconnected")
