## Detached Android-profile simulation over ENet. Player scene/input/HUD wiring
## is separate; only explicit Ready, Start, capture and advance calls do work.
extends "res://scripts/network_preview_connection.gd"

const Runner := preload("res://scripts/network_touch_runner.gd")
const Buffer := preload("res://scripts/network_input_buffer.gd")
const Wire := preload("res://scripts/network_protocol.gd")
const Config := preload("res://scripts/network_configuration.gd")
var _runner := Runner.new()
var _activated := false
var _view_local := false
var _view_remote := false


func _ready() -> void:
	super._ready()
	_connection.gameplay_packet_received.connect(_receive_input)


func stop() -> void:
	_view_local = false
	_view_remote = false
	_runner.stop()
	_activated = false
	super.stop()


func confirm_ready() -> bool:
	if not _healthy() or _connection.startup.phase not in [Startup.Phase.LOADED, Startup.Phase.READY]:
		return false
	if not _preparation.verify_preview():
		if not _preparation.error.is_empty():
			_fail(_preparation.error)
		return false
	var accepted: bool = _connection.confirm_ready()
	return accepted and _healthy()


func start() -> bool:
	if not _healthy() or _connection.startup.phase != Startup.Phase.READY:
		return false
	if not _preparation.verify_preview():
		if not _preparation.error.is_empty():
			_fail(_preparation.error)
		return false
	var accepted: bool = _connection.start()
	return accepted and running()


func running() -> bool:
	return _activated and _healthy() and _connection.running


func needs_local_input() -> bool:
	return running() and _runner.needs_local_input()


func capture_local(frame: Dictionary) -> bool:
	if not running():
		return false
	var packet: PackedByteArray = _runner.capture_local(frame)
	if not _runner.error.is_empty():
		return _fail(_runner.error)
	if packet.is_empty():
		return false
	if _connection.transport.send_packet(packet) != OK:
		return _fail("input_send_failed")
	return running()


func advance() -> bool:
	if not running():
		return false
	var advanced: bool = _runner.advance()
	if not _runner.error.is_empty():
		return _fail(_runner.error)
	return advanced


func ticks_executed() -> int:
	return _runner.ticks_executed


## Borrow only: preparation retains ownership. Never parent/free this node.
## A view must recheck this accessor before using a previously borrowed node.
func simulation_for_view() -> Node:
	if not running():
		return null
	var native: Node = _preparation.get("_preview")
	return native if is_instance_valid(native) else null


func player_for_view() -> int:
	return int(_connection.startup.context().get("player", 0)) if running() else 0


## Production scene barrier, after its original entry fade. No core stepping.
func mark_view_ready() -> bool:
	if not running():
		return false
	if _view_local:
		return true
	if ticks_executed() != 0:
		return false
	var context: Dictionary = _connection.startup.context()
	var packet := Wire.encode(
		{
			"kind": Wire.Kind.READY,
			"session": context.session,
			"epoch": context.epoch,
			"player": context.player,
			"tick": 0,
			"sequence": 1,
			"digest": Config.digest(configuration())
		}
	)
	if _connection.transport.send_packet(packet) != OK:
		return _fail("view_ready_send_failed")
	_view_local = true
	changed.emit()
	return running()


func views_ready() -> bool:
	return running() and _view_local and _view_remote


func _receive_view_ready(packet: PackedByteArray) -> void:
	var context: Dictionary = _connection.startup.context()
	var message := Wire.decode(packet, packet.slice(8, 24).hex_encode(), packet.decode_u32(24), 3 - context.player)
	if message.is_empty():
		_fail("invalid_view_ready")
		return
	if message.session != context.session or message.epoch != context.epoch:
		return
	if (
		message.tick != 0
		or message.sequence != 1
		or message.digest != Config.digest(configuration())
		or (not _view_remote and ticks_executed() != 0)
	):
		_fail("invalid_view_ready")
		return
	_view_remote = true
	changed.emit()


## Diagnostic valid only at the same untouched observer-consumption boundary.
func diagnostic_digest() -> String:
	if not running():
		return ""
	return _preparation.get("_preview").network_diagnostic_digest()


func _changed() -> void:
	if _stopping:
		return
	if not _connection.error.is_empty():
		_fail(_connection.error)
		return
	if not _preparation.error.is_empty():
		_fail(_preparation.error)
		return
	if _connection.running and not _activated:
		if not _preparation.verify_preview():
			_fail(_preparation.error)
			return
		var context: Dictionary = _connection.startup.context()
		if not _runner.activate(
			_preparation.get("_preview"), _preparation.configuration(), context.session, context.epoch, context.player
		):
			_fail(_runner.error)
			return
		_activated = true
	changed.emit()


func _receive_input(packet: PackedByteArray) -> void:
	if not running():
		_fail("input_before_start")
		return
	if packet.size() >= Wire.HEADER_BYTES and int(packet[6]) == Wire.Kind.READY:
		_receive_view_ready(packet)
		return
	var result: int = _runner.receive(packet)
	if not _runner.error.is_empty():
		_fail(_runner.error)
	elif result == Buffer.Result.INVALID:
		_fail("invalid_remote_input")


func _fail(reason: String) -> bool:
	_view_local = false
	_view_remote = false
	_runner.stop()
	_activated = false
	return super._fail(reason)
