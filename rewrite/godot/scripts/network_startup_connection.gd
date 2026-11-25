## LAN adapter for the pure startup coordinator. No Game/Sim/scene mutation.
## Future menu/session integration supplies verified local identities and a
## catalog/configuration validator, and explicitly confirms load/Ready boundaries.
extends Node

signal changed
signal gameplay_packet_received(packet: PackedByteArray)

const Lobby := preload("res://scripts/lan_lobby.gd")
const Startup := preload("res://scripts/network_startup.gd")
const Protocol := preload("res://scripts/network_startup_protocol.gd")
const Gameplay := preload("res://scripts/network_protocol.gd")

var transport := Lobby.new()
var startup: RefCounted
var error := ""
var running: bool:
	get:
		return error.is_empty() and transport.connected and startup != null and startup.phase == Startup.Phase.RUNNING

var _identity := {}
var _validator: Callable
var _closing := false
var _borrowed := false


func _ready() -> void:
	add_child(transport)
	transport.changed.connect(_connection_changed)
	transport.packet_received.connect(_receive_packet)


func host(identity: Dictionary, validator: Callable, port := Lobby.PORT) -> Error:
	if not _prepare(identity, validator):
		return ERR_INVALID_PARAMETER
	return transport.host(port)


func join(address: String, identity: Dictionary, validator: Callable, port := Lobby.PORT) -> Error:
	if not _prepare(identity, validator):
		return ERR_INVALID_PARAMETER
	return transport.join(address, port)


## Borrow the persistent menu transport. Never reparent it: its exit hook closes
## the native peer. A fresh connection adapter may adopt only once.
func adopt_transport(lobby: Node, identity: Dictionary, validator: Callable) -> Error:
	if _borrowed or not lobby is Lobby or lobby == transport:
		return ERR_INVALID_PARAMETER
	if not _prepare(identity, validator):
		return ERR_INVALID_PARAMETER
	var previous := transport
	previous.changed.disconnect(_connection_changed)
	previous.packet_received.disconnect(_receive_packet)
	transport = lobby
	_borrowed = true
	transport.changed.connect(_connection_changed)
	transport.packet_received.connect(_receive_packet)
	if previous.get_parent() == self:
		previous.free()
	_connection_changed()
	return OK


func _prepare(identity: Dictionary, validator: Callable) -> bool:
	stop()
	if not Protocol.valid_identity(identity) or not validator.is_valid():
		error = "invalid_local_configuration"
		return false
	_identity = identity.duplicate(true)
	_validator = validator
	return true


func stop() -> void:
	_closing = true
	transport.close()
	startup = null
	_identity.clear()
	_validator = Callable()
	error = ""
	_closing = false


func propose(config: Dictionary, session: String, epoch: int) -> bool:
	if startup == null or not transport.connected:
		return false
	var accepted: bool = startup.propose(config, session, epoch)
	_flush()
	return accepted and error.is_empty()


func mark_loaded(state_digest: String) -> bool:
	if startup == null or not transport.connected:
		return false
	var accepted: bool = startup.mark_loaded(state_digest)
	_flush()
	return accepted and error.is_empty()


func confirm_ready() -> bool:
	if startup == null or not transport.connected:
		return false
	var accepted: bool = startup.confirm_ready()
	_flush()
	return accepted and error.is_empty()


func start() -> bool:
	if startup == null or not transport.connected:
		return false
	var accepted: bool = startup.start()
	_flush()
	return accepted and error.is_empty()


func _connection_changed() -> void:
	if _closing:
		return
	if transport.connected and startup == null:
		startup = Startup.new(1 if transport.hosting else 2, _identity, _validator)
		_flush()
	elif not transport.connected and startup != null and error.is_empty():
		error = "connection_closed"
	changed.emit()


func _receive_packet(packet: PackedByteArray) -> void:
	if startup == null or not error.is_empty():
		return
	if (
		startup.phase == Startup.Phase.RUNNING
		and packet.size() <= Gameplay.MAX_PACKET_BYTES
		and packet.slice(0, 4) == "OT2N".to_utf8_buffer()
		and not gameplay_packet_received.get_connections().is_empty()
	):
		gameplay_packet_received.emit(packet)
		return
	var expected := 2 if transport.hosting else 1
	startup.receive(Protocol.decode(packet, expected))
	_flush()


func _flush() -> void:
	if startup.phase == Startup.Phase.FAILED:
		_close_with_error(startup.error)
		return
	for message in startup.take_messages():
		if transport.send_packet(Protocol.encode(message)) != OK:
			_close_with_error("send_failed")
			return
	changed.emit()


func _close_with_error(reason: String) -> void:
	error = reason
	_closing = true
	transport.close()
	_closing = false
	changed.emit()


func _process(_delta: float) -> void:
	if startup != null and error.is_empty() and transport.connected:
		startup.check_timeout()
		if startup.phase == Startup.Phase.FAILED:
			_close_with_error(startup.error)


func _exit_tree() -> void:
	stop()
