## Detached Android-profile simulation over ENet. Player scene/input/HUD wiring
## is separate; only explicit Ready, Start, capture and advance calls do work.
extends "res://scripts/network_preview_connection.gd"

const Runner := preload("res://scripts/network_touch_runner.gd")
const Buffer := preload("res://scripts/network_input_buffer.gd")
const Wire := preload("res://scripts/network_protocol.gd")
const Config := preload("res://scripts/network_configuration.gd")
const PauseController := preload("res://scripts/network_pause.gd")
const Completion := preload("res://scripts/network_completion.gd")
const LevelResult := preload("res://scripts/network_level_result.gd")
var _runner := Runner.new()
var _activated := false
var _view_local := false
var _view_remote := false
var _pause := PauseController.new()
var _completion := Completion.new()
var _level_result := LevelResult.new()


func _ready() -> void:
	super._ready()
	_connection.gameplay_packet_received.connect(_receive_input)


func stop() -> void:
	_completion = Completion.new()
	_level_result = LevelResult.new()
	_pause = PauseController.new()
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
	return (
		running()
		and _pause.may_advance(ticks_executed())
		and _completion.may_advance(ticks_executed())
		and _runner.needs_local_input()
	)


func capture_local(frame: Dictionary) -> bool:
	if not running() or not _pause.may_advance(ticks_executed()) or not _completion.may_advance(ticks_executed()):
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
	if not running() or not _pause.may_advance(ticks_executed()) or not _completion.may_advance(ticks_executed()):
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


func request_pause() -> bool:
	if not views_ready() or _completion.active() or not _pause.request_pause(ticks_executed(), Time.get_ticks_msec()):
		return false
	return _settle_pause()


func request_resume() -> bool:
	if not views_ready() or _completion.active() or not _pause.request_resume(Time.get_ticks_msec()):
		return false
	return _settle_pause()


func inputs_quiesced() -> bool:
	return running() and (_pause.quiesced() or _completion.local_reached())


func pause_boundary_reached() -> bool:
	return running() and not _pause.may_advance(ticks_executed())


func pause_confirmed() -> bool:
	return running() and _pause.phase == PauseController.Phase.PAUSED


func local_paused() -> bool:
	return running() and _pause.local_paused()


func note_pause_boundary() -> bool:
	if running() and _pause.local_paused():
		return true
	if not running() or not _pause.reached(ticks_executed(), diagnostic_digest()):
		return _fail(_pause.error if not _pause.error.is_empty() else "invalid_pause_boundary")
	return _settle_pause()


func _settle_pause() -> bool:
	if not _pause.error.is_empty():
		return _fail(_pause.error)
	if _pause.needs_input_reset():
		if not _runner.resume_inputs(_pause.epoch + 1, _pause.target):
			return _fail(_runner.error)
		if not _pause.input_reset_done(diagnostic_digest()):
			return _fail(_pause.error)
	for message in _pause.take_messages():
		if _connection.transport.send_packet(Wire.encode(message)) != OK:
			return _fail("pause_send_failed")
	changed.emit()
	return running()


func _process(_delta: float) -> void:
	if running():
		if _completion.active():
			_completion.poll(Time.get_ticks_msec())
			if not _completion.error.is_empty():
				_fail(_completion.error)
		else:
			_pause.poll(Time.get_ticks_msec())
			if not _pause.error.is_empty():
				_fail(_pause.error)


## Explicit final post-presentation boundary. Never steps/reloads the native node.
func note_level_result(presented_tick: int, level_name: String, elapsed_seconds: int) -> bool:
	if not views_ready() or not _completion_context():
		return false
	var native := simulation_for_view()
	if not _level_result.capture(native, configuration(), level_name, presented_tick):
		return _fail(_level_result.error)
	var record := _level_result.record()
	if not _completion.reached(record.tick, record.digest, elapsed_seconds, Time.get_ticks_msec()):
		return _fail(_completion.error)
	return _settle_completion()


func completion_agreed() -> bool:
	return running() and _completion.agreed()


func result_for_view() -> RefCounted:
	return _level_result if completion_agreed() else null


func result_elapsed_seconds() -> int:
	return _completion.elapsed_seconds() if completion_agreed() else -1


func mark_result_screen_ready(stage: int) -> bool:
	if not completion_agreed():
		return false
	if not _completion.screen_ready(stage):
		return _fail(_completion.error) if not _completion.error.is_empty() else false
	return _settle_completion()


func request_result_advance(stage: int) -> bool:
	return completion_agreed() and _completion.request_advance(stage, Time.get_ticks_msec()) and _settle_completion()


func result_committed_phase() -> int:
	return _completion.committed_phase() if running() else 0


func _completion_context() -> bool:
	if _completion.epoch == _pause.epoch:
		return true
	if _completion.active():
		return _fail("changed_completion_epoch")
	_completion = Completion.new()
	var context: Dictionary = _connection.startup.context()
	if not _completion.configure(context.session, _pause.epoch, context.player, configuration().input_delay):
		return _fail(_completion.error)
	return true


func _settle_completion() -> bool:
	if not _completion.error.is_empty():
		return _fail(_completion.error)
	for message in _completion.take_messages():
		if _connection.transport.send_packet(Wire.encode(message)) != OK:
			return _fail("completion_send_failed")
	changed.emit()
	return running()


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
		_pause = PauseController.new()
		if not _pause.configure(context.session, context.epoch, context.player, configuration().input_delay):
			_fail(_pause.error)
			return
	changed.emit()


func _receive_input(packet: PackedByteArray) -> void:
	if not running():
		_fail("input_before_start")
		return
	if (
		packet.size() >= Wire.HEADER_BYTES
		and int(packet[6]) in [Wire.Kind.LEVEL_RESULT, Wire.Kind.LEVEL_READY, Wire.Kind.LEVEL_ADVANCE]
	):
		_receive_completion(packet)
		return
	if packet.size() >= Wire.HEADER_BYTES and int(packet[6]) == Wire.Kind.READY:
		var initial_epoch: int = _connection.startup.context().epoch
		if packet.decode_u32(24) == initial_epoch and packet.decode_u32(28) == 0:
			_receive_view_ready(packet)
		else:
			_receive_pause(packet)
		return
	if packet.size() >= Wire.HEADER_BYTES and int(packet[6]) in [Wire.Kind.PAUSE, Wire.Kind.STATE]:
		_receive_pause(packet)
		return
	var result: int = _runner.receive(packet)
	if not _runner.error.is_empty():
		_fail(_runner.error)
	elif result == Buffer.Result.INVALID:
		_fail("invalid_remote_input")


func _receive_pause(packet: PackedByteArray) -> void:
	if not views_ready():
		_fail("pause_before_views")
		return
	var message := Wire.decode(packet, packet.slice(8, 24).hex_encode(), packet.decode_u32(24), 3 - player_for_view())
	if not message.is_empty() and _completion.local_reached():
		return  # Natural completion supersedes an in-flight future pause target.
	if not _pause.receive(message, ticks_executed(), Time.get_ticks_msec()):
		_fail(_pause.error)
		return
	_settle_pause()


func _receive_completion(packet: PackedByteArray) -> void:
	if not views_ready():
		_fail("completion_before_views")
		return
	var context: Dictionary = _connection.startup.context()
	var message := Wire.decode(packet, packet.slice(8, 24).hex_encode(), packet.decode_u32(24), 3 - context.player)
	if message.is_empty():
		_fail("invalid_completion_message")
		return
	if message.session != context.session or message.epoch < _pause.epoch:
		return
	if message.epoch != _pause.epoch:
		_fail("future_completion_epoch")
		return
	if not _completion_context() or not _completion.receive(message, ticks_executed(), Time.get_ticks_msec()):
		if not _completion.error.is_empty():
			_fail(_completion.error)
		return
	_settle_completion()


func _fail(reason: String) -> bool:
	_completion = Completion.new()
	_level_result = LevelResult.new()
	_pause = PauseController.new()
	_view_local = false
	_view_remote = false
	_runner.stop()
	_activated = false
	return super._fail(reason)
