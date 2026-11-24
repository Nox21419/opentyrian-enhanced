## Connection-only two-phone LAN lobby. No simulation or scene replication.
## Own the peer directly so tests and ordinary local play keep their MultiplayerAPI.
extends Node

signal changed

const PORT := 26635
const PROTOCOL := 1
const CONNECT_TIMEOUT_MS := 8000
const MAX_PACKET_BYTES := 256

var peer: ENetMultiplayerPeer
var hosting := false
var connected := false
var status_key := "net_idle"
var _remote := 0
var _deadline := 0
var _pending_failure := ""


func host(port := PORT) -> Error:
	close()
	if port < 1 or port > 65535:
		return _fail("net_host_failed", ERR_INVALID_PARAMETER)
	peer = ENetMultiplayerPeer.new()
	var error := peer.create_server(port, 1, 1)
	if error != OK:
		return _fail("net_host_failed", error)
	hosting = true
	_wire_peer()
	_set_status("net_waiting")
	return OK


func join(address: String, port := PORT) -> Error:
	close()
	# Literal addresses only: avoid blocking DNS lookups on the game thread.
	if not address.is_valid_ip_address() or port < 1 or port > 65535:
		return _fail("net_bad_address", ERR_INVALID_PARAMETER)
	peer = ENetMultiplayerPeer.new()
	var error := peer.create_client(address, port, 1)
	if error != OK:
		return _fail("net_join_failed", error)
	_wire_peer()
	_deadline = Time.get_ticks_msec() + CONNECT_TIMEOUT_MS
	_set_status("net_connecting")
	return OK


func _wire_peer() -> void:
	peer.peer_connected.connect(_peer_connected)
	peer.peer_disconnected.connect(_peer_disconnected)


func close() -> void:
	if peer != null:
		peer.close()
	peer = null
	hosting = false
	connected = false
	_remote = 0
	_deadline = 0
	_pending_failure = ""
	_set_status("net_idle")


func _set_status(key: String) -> void:
	status_key = key
	changed.emit()


func _fail(key: String, error: Error) -> Error:
	close()
	_set_status(key)
	return error


func _peer_connected(id: int) -> void:
	if _remote != 0 or (not hosting and id != 1):
		peer.disconnect_peer(id)
		return
	_remote = id
	_deadline = Time.get_ticks_msec() + CONNECT_TIMEOUT_MS
	peer.set_target_peer(id)
	peer.transfer_mode = MultiplayerPeer.TRANSFER_MODE_RELIABLE
	var hello := ["OT2-LAN-LOBBY", PROTOCOL, str(ProjectSettings.get_setting("application/config/version"))]
	if peer.put_packet(JSON.stringify(hello).to_utf8_buffer()) != OK:
		_pending_failure = "net_join_failed"


func _peer_disconnected(id: int) -> void:
	if id == _remote:
		# Closing an ENet host from its poll callback invalidates native state.
		_pending_failure = "net_disconnected"


func _process(_delta: float) -> void:
	if peer == null:
		return
	peer.poll()
	if not _pending_failure.is_empty():
		_fail(_pending_failure, ERR_CONNECTION_ERROR)
		return
	if peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
		_fail("net_disconnected", ERR_CONNECTION_ERROR)
		return
	while peer != null and peer.get_available_packet_count() > 0:
		var sender := peer.get_packet_peer()
		var packet := peer.get_packet()
		if sender != _remote or connected or packet.size() > MAX_PACKET_BYTES:
			_fail("net_incompatible", ERR_INVALID_DATA)
			return
		var hello: Variant = JSON.parse_string(packet.get_string_from_utf8())
		# JSON numbers decode to floats; Array equality also compares element types.
		var expected := [
			"OT2-LAN-LOBBY", float(PROTOCOL), str(ProjectSettings.get_setting("application/config/version"))
		]
		if not hello is Array or hello != expected:
			_fail("net_incompatible", ERR_INVALID_DATA)
			return
		connected = true
		_deadline = 0
		_set_status("net_connected")
	if _deadline > 0 and Time.get_ticks_msec() >= _deadline:
		_fail("net_timeout", ERR_TIMEOUT)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED and peer != null:
		_fail("net_disconnected", ERR_CONNECTION_ERROR)


func _exit_tree() -> void:
	close()
