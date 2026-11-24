## Detached Android-profile simulation over ENet. Player scene/input/HUD wiring
## is separate; only explicit Ready, Start, capture and advance calls do work.
extends "res://scripts/network_preview_connection.gd"

const Runner := preload("res://scripts/network_touch_runner.gd")
const Buffer := preload("res://scripts/network_input_buffer.gd")
var _runner := Runner.new()
var _activated := false


func _ready() -> void:
	super._ready()
	_connection.gameplay_packet_received.connect(_receive_input)


func stop() -> void:
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
	var result: int = _runner.receive(packet)
	if not _runner.error.is_empty():
		_fail(_runner.error)
	elif result == Buffer.Result.INVALID:
		_fail("invalid_remote_input")


func _fail(reason: String) -> bool:
	_runner.stop()
	_activated = false
	return super._fail(reason)
