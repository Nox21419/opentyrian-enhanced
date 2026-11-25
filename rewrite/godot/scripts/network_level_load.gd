## One post-completion load agreement. No scene/native/transport operations.
extends RefCounted

const Wire := preload("res://scripts/network_protocol.gd")
const Config := preload("res://scripts/network_configuration.gd")
const TIMEOUT_MS := 30000
var error := ""
var next_epoch := 0
var seed := ""
var _session := ""
var _epoch := 0
var _player := 0
var _tick := 0
var _sequence := 0
var _proposal := ""
var _local := ""
var _remote := ""
var _committed := false
var _deadline := 0
var _outbox: Array[Dictionary] = []


func configure(session: String, epoch: int, player: int, tick: int, sequence: int, proposal: String) -> bool:
	if not _session.is_empty() or not Wire.valid_session(session) or not Config.hex_string(proposal, 64):
		return _fail("invalid_load_context")
	if not Config.integer(epoch, 1, Wire.MAX_TICK - 1) or not Config.integer(tick, 1, Wire.MAX_TICK):
		return _fail("invalid_load_context")
	if player not in [1, 2] or sequence not in [1, 2]:
		return _fail("invalid_load_context")
	_session = session
	_epoch = epoch
	next_epoch = epoch + 1
	_player = player
	_tick = tick
	_sequence = sequence
	_proposal = proposal
	return true


func offer(value: String, now: int) -> bool:
	if not poll(now) or _session.is_empty() or _player != 1 or not Config.hex_string(value, 16):
		return false
	if not seed.is_empty():
		return true if seed == value else _fail("changed_load_seed")
	seed = value
	_deadline = now + TIMEOUT_MS
	_outbox.append(_message(Wire.Kind.LOAD_SEED, seed))
	return true


func loaded(request: String, state: String, now: int) -> bool:
	if not poll(now) or seed.is_empty():
		return false
	if not Config.hex_string(request, 64) or not Config.hex_string(state, 64):
		return _fail("invalid_load_diagnostic")
	var digest := Config.sha256(JSON.stringify([_proposal, seed, next_epoch, request, state]))
	if not _local.is_empty():
		return true if _local == digest else _fail("changed_local_load")
	_local = digest
	if not _remote.is_empty() and _remote != _local:
		return _fail("load_state_mismatch")
	_outbox.append(_message(Wire.Kind.LOAD_READY, digest))
	return true


func ready() -> bool:
	return error.is_empty() and not _local.is_empty() and _local == _remote


func committed() -> bool:
	return error.is_empty() and _committed


func has_seen_control(message: Dictionary) -> bool:
	if message.get("session") != _session or message.get("epoch") != _epoch or message.get("tick") != _tick:
		return false
	if message.get("sequence") != _sequence or message.get("player") != 3 - _player:
		return false
	match message.get("kind"):
		Wire.Kind.LOAD_SEED:
			return not seed.is_empty()
		Wire.Kind.LOAD_READY:
			return not _remote.is_empty()
		Wire.Kind.LOAD_ACTIVATE:
			return _committed
	return false


func activate(now: int) -> bool:
	if not poll(now) or _player != 1 or not ready():
		return false
	if _committed:
		return true
	_committed = true
	_deadline = 0
	_outbox.append(_message(Wire.Kind.LOAD_ACTIVATE, _local))
	return true


func receive(message: Dictionary, now: int) -> bool:
	if not poll(now) or not Wire.valid_message(message) or message.player != 3 - _player:
		return _fail(error if not error.is_empty() else "invalid_load_message")
	if message.session != _session or message.epoch < _epoch:
		return true
	if message.epoch != _epoch or message.tick != _tick or message.sequence != _sequence:
		return _fail("load_context_mismatch")
	match message.kind:
		Wire.Kind.LOAD_SEED:
			if not seed.is_empty():
				return true if seed == message.seed else _fail("changed_load_seed")
			seed = message.seed
			_deadline = now + TIMEOUT_MS
		Wire.Kind.LOAD_READY:
			if seed.is_empty():
				return _fail("load_before_seed")
			if not _remote.is_empty() and _remote != message.digest:
				return _fail("changed_remote_load")
			_remote = message.digest
			if not _local.is_empty() and _local != _remote:
				return _fail("load_state_mismatch")
		Wire.Kind.LOAD_ACTIVATE:
			if not ready() or message.digest != _local:
				return _fail("premature_load_activation")
			_committed = true
			_deadline = 0
		_:
			return _fail("unexpected_load_message")
	return true


func poll(now: int) -> bool:
	if not error.is_empty():
		return false
	if _deadline > 0 and now >= _deadline:
		return _fail("load_timeout")
	return true


func take_messages() -> Array[Dictionary]:
	var messages := _outbox
	_outbox = []
	return messages


func _message(kind: int, value: String) -> Dictionary:
	var message := {
		"kind": kind, "session": _session, "epoch": _epoch, "player": _player, "tick": _tick, "sequence": _sequence
	}
	message["seed" if kind == Wire.Kind.LOAD_SEED else "digest"] = value
	return message


func _fail(reason: String) -> bool:
	error = reason
	_outbox.clear()
	return false
