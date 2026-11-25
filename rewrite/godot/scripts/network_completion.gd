## Per-level agreement, two original screen barriers and a final fade barrier.
## No native node, scene, gameplay mutation or transport ownership.
extends RefCounted

const Wire := preload("res://scripts/network_protocol.gd")
const Config := preload("res://scripts/network_configuration.gd")
const TIMEOUT_MS := 10000
var error := ""
var epoch := 0
var _session := ""
var _player := 0
var _delay := 0
var _tick := -1
var _digest := ""
var _remote_tick := -1
var _remote_digest := ""
var _remote_elapsed := -1
var _elapsed := -1
var _local_ready := 0
var _remote_ready := 0
var _committed := 0
var _requested := 0
var _matched := false
var _deadline := 0
var _outbox: Array[Dictionary] = []


func configure(session: String, input_epoch: int, player: int, delay: int) -> bool:
	if not _session.is_empty() or not Wire.valid_session(session):
		return _fail("invalid_completion_context")
	if not Config.integer(input_epoch, 1, Wire.MAX_TICK) or player not in [1, 2] or delay < 0 or delay > 8:
		return _fail("invalid_completion_context")
	_session = session
	epoch = input_epoch
	_player = player
	_delay = delay
	return true


func active() -> bool:
	return _tick >= 0 or _remote_tick >= 0


func local_reached() -> bool:
	return _tick >= 0


func may_advance(tick: int) -> bool:
	return error.is_empty() and _tick < 0 and (_remote_tick < 0 or tick < _remote_tick)


func agreed() -> bool:
	return error.is_empty() and _matched


func elapsed_seconds() -> int:
	return _elapsed if agreed() else -1


func result_digest() -> String:
	return _digest if agreed() else ""


func committed_phase() -> int:
	return _committed if error.is_empty() else 0


func reached(tick: int, digest: String, elapsed: int, now: int) -> bool:
	if not error.is_empty() or _session.is_empty():
		return false
	if not Config.integer(tick, 1, Wire.MAX_TICK) or not Config.hex_string(digest, 64):
		return _fail("invalid_completion_result")
	if not Config.integer(elapsed, 0, Wire.MAX_TICK) or (_player == 2 and elapsed != 0):
		return _fail("invalid_completion_elapsed")
	if local_reached():
		return (
			true
			if _tick == tick and _digest == digest and (_player == 2 or _elapsed == elapsed)
			else _fail("changed_completion_result")
		)
	_tick = tick
	_digest = digest
	if _player == 1:
		_elapsed = elapsed
	_deadline = now + TIMEOUT_MS
	_outbox.append(_message(Wire.Kind.LEVEL_RESULT, 0, {"elapsed": elapsed}))
	return _compare()


func screen_ready(stage: int) -> bool:
	if not agreed() or stage < 1 or stage > 3:
		return false
	if stage <= _local_ready:
		return true
	if stage != _local_ready + 1 or stage != _committed + 1:
		return _fail("skipped_completion_screen")
	_local_ready = stage
	_outbox.append(_message(Wire.Kind.LEVEL_READY, stage))
	_try_commit()
	return error.is_empty()


func request_advance(stage: int, now: int) -> bool:
	if not agreed() or _player != 1 or stage != _committed + 1 or stage > _local_ready:
		return false
	if _requested != stage:
		_requested = stage
		_deadline = now + TIMEOUT_MS
	_try_commit()
	return true


func receive(message: Dictionary, current_tick: int, now: int) -> bool:
	if not error.is_empty():
		return false
	if not Wire.valid_message(message) or message.player != 3 - _player:
		return _fail("invalid_completion_message")
	if message.session != _session or message.epoch < epoch:
		return true
	if message.epoch != epoch:
		return _fail("future_completion_epoch")
	if message.kind == Wire.Kind.LEVEL_RESULT:
		return _receive_result(message, current_tick, now)
	if not agreed() or message.tick != _tick or message.digest != _digest:
		return _fail("completion_state_mismatch")
	if message.kind == Wire.Kind.LEVEL_READY:
		if message.sequence <= _remote_ready:
			return true
		if message.sequence != _remote_ready + 1 or message.sequence != _committed + 1:
			return _fail("skipped_completion_screen")
		_remote_ready = message.sequence
		_try_commit()
	elif message.kind == Wire.Kind.LEVEL_ADVANCE:
		if message.sequence <= _committed:
			return true
		if message.sequence != _committed + 1 or message.sequence > mini(_local_ready, _remote_ready):
			return _fail("premature_completion_advance")
		_committed = message.sequence
	else:
		return _fail("unexpected_completion_message")
	return error.is_empty()


func _receive_result(message: Dictionary, current_tick: int, now: int) -> bool:
	if _remote_tick >= 0:
		return (
			true
			if message.tick == _remote_tick and message.digest == _remote_digest and message.elapsed == _remote_elapsed
			else _fail("changed_remote_completion_result")
		)
	if (
		not Config.integer(current_tick, 0, Wire.MAX_TICK)
		or message.tick < current_tick
		or message.tick > current_tick + _delay + 1
	):
		return _fail("completion_tick_outside_window")
	_remote_tick = message.tick
	_remote_digest = message.digest
	_remote_elapsed = message.elapsed
	if _player == 2:
		_elapsed = message.elapsed
	_deadline = now + TIMEOUT_MS
	return _compare()


func _compare() -> bool:
	if _tick < 0 or _remote_tick < 0:
		return true
	if _tick != _remote_tick or _digest != _remote_digest:
		return _fail("completion_state_mismatch")
	_matched = true
	_deadline = 0
	return true


func _try_commit() -> void:
	if _player == 1 and _requested == _committed + 1 and _requested <= mini(_local_ready, _remote_ready):
		_committed = _requested
		_outbox.append(_message(Wire.Kind.LEVEL_ADVANCE, _committed))
		_deadline = 0


func poll(now: int) -> void:
	if error.is_empty() and _deadline > 0 and now >= _deadline:
		_fail("completion_timeout")


func take_messages() -> Array[Dictionary]:
	var messages := _outbox
	_outbox = []
	return messages


func _message(kind: int, sequence: int, extra := {}) -> Dictionary:
	var message := {
		"kind": kind,
		"session": _session,
		"epoch": epoch,
		"player": _player,
		"tick": _tick,
		"sequence": sequence,
		"digest": _digest
	}
	message.merge(extra)
	return message


func _fail(reason: String) -> bool:
	error = reason
	_outbox.clear()
	return false
