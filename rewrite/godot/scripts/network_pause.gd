## Pause targets and input-only resume epochs over one reliable ordered channel.
## No native node, clock, hardware, menu or transport ownership.
extends RefCounted

const Wire := preload("res://scripts/network_protocol.gd")
const Buffer := preload("res://scripts/network_input_buffer.gd")
const Config := preload("res://scripts/network_configuration.gd")
enum Phase { RUNNING, REQUESTED, ARMING, AT_PAUSE, PAUSED, RESUMING, FAILED }
const TIMEOUT_MS := 10000
const HISTORY := 16
var phase := Phase.RUNNING
var error := ""
var epoch := 0
var target := -1
var _session := ""
var _player := 0
var _delay := 0
var _sequence := 1
var _remote_sequence := 1
var _seen := {}
var _outbox: Array[Dictionary] = []
var _local_digest := ""
var _remote_digest := ""
var _resume_local := false
var _resume_remote := false
var _deadline := 0
var _last_resume_tick := -1
var _last_resume_digest := ""


func configure(session: String, initial_epoch: int, player: int, delay: int) -> bool:
	if not Wire.valid_session(session) or initial_epoch < 1 or initial_epoch > Wire.MAX_TICK:
		return _fail("invalid_pause_context")
	if player not in [1, 2] or delay < 0 or delay > Buffer.MAX_DELAY:
		return _fail("invalid_pause_context")
	_session = session
	epoch = initial_epoch
	_player = player
	_delay = delay
	return true


func quiesced() -> bool:
	return phase != Phase.RUNNING


func may_advance(tick: int) -> bool:
	return phase in [Phase.RUNNING, Phase.REQUESTED] or (phase == Phase.ARMING and tick < target)


func local_paused() -> bool:
	return phase in [Phase.AT_PAUSE, Phase.PAUSED, Phase.RESUMING]


func request_pause(tick: int, now: int) -> bool:
	if _player not in [1, 2] or tick < 0 or tick > Wire.MAX_TICK:
		return _fail("invalid_pause_context")
	if phase != Phase.RUNNING:
		return false
	if _player == 1:
		return _commit_pause(tick, now)
	phase = Phase.REQUESTED
	_deadline = now + TIMEOUT_MS
	_queue_control(Wire.Pause.REQUEST_PAUSE, tick)
	return true


func _commit_pause(tick: int, now: int) -> bool:
	if tick < 0 or tick > Wire.MAX_TICK - _delay - 1:
		return _fail("pause_tick_overflow")
	target = tick + _delay + 1
	phase = Phase.ARMING
	_deadline = now + TIMEOUT_MS
	_queue_control(Wire.Pause.COMMIT_PAUSE, target)
	return true


func reached(tick: int, digest: String) -> bool:
	if local_paused():
		return tick == target
	if phase != Phase.ARMING or tick != target or not _digest_valid(digest):
		return _fail("invalid_pause_boundary")
	_local_digest = digest
	phase = Phase.AT_PAUSE
	_outbox.append(_message(Wire.Kind.STATE, epoch, target, 0, {"digest": digest}))
	_check_paused()
	return error.is_empty()


func _check_paused() -> void:
	if _local_digest.is_empty() or _remote_digest.is_empty():
		return
	if _local_digest != _remote_digest:
		_fail("pause_state_mismatch")
		return
	phase = Phase.PAUSED
	_deadline = 0


func request_resume(now: int) -> bool:
	if _player != 1 or phase != Phase.PAUSED or epoch == Wire.MAX_TICK:
		return false
	_queue_control(Wire.Pause.COMMIT_RESUME, target)
	phase = Phase.RESUMING
	_deadline = now + TIMEOUT_MS
	return true


func needs_input_reset() -> bool:
	return phase == Phase.RESUMING and not _resume_local


func input_reset_done(digest: String) -> bool:
	if not needs_input_reset() or digest != _local_digest:
		return _fail("resume_state_changed")
	_resume_local = true
	_outbox.append(_message(Wire.Kind.READY, epoch + 1, target, 1, {"digest": digest}))
	_check_resumed()
	return error.is_empty()


func _check_resumed() -> void:
	if not _resume_local or not _resume_remote:
		return
	epoch += 1
	_last_resume_tick = target
	_last_resume_digest = _local_digest
	phase = Phase.RUNNING
	target = -1
	_local_digest = ""
	_remote_digest = ""
	_resume_local = false
	_resume_remote = false
	_sequence = 1
	_remote_sequence = 1
	_seen.clear()
	_deadline = 0


func receive(message: Dictionary, tick: int, now: int) -> bool:
	if not Wire.valid_message(message) or message.player != 3 - _player:
		return _fail("invalid_pause_message")
	if message.session != _session or message.epoch < epoch:
		return true
	if message.kind == Wire.Kind.READY and message.epoch == epoch:
		if message.tick == _last_resume_tick and message.sequence == 1 and message.digest == _last_resume_digest:
			return true
		return _fail("invalid_resume_ready")
	if message.kind == Wire.Kind.READY and phase == Phase.RESUMING and message.epoch == epoch + 1:
		if message.tick != target or message.sequence != 1 or message.digest != _local_digest:
			return _fail("invalid_resume_ready")
		_resume_remote = true
		_check_resumed()
		return true
	if message.epoch != epoch:
		return _fail("invalid_pause_epoch")
	if message.kind == Wire.Kind.STATE:
		if phase not in [Phase.ARMING, Phase.AT_PAUSE, Phase.PAUSED, Phase.RESUMING] or message.tick != target:
			return _fail("invalid_pause_state")
		if not _remote_digest.is_empty() and _remote_digest != message.digest:
			return _fail("conflicting_pause_state")
		_remote_digest = message.digest
		if phase != Phase.RESUMING:
			_check_paused()
		return error.is_empty()
	if message.kind != Wire.Kind.PAUSE:
		return _fail("invalid_pause_message")
	if message.sequence <= _remote_sequence:
		if _seen.has(message.sequence) and _seen[message.sequence] != message:
			return _fail("conflicting_pause_control")
		return true
	if message.sequence != _remote_sequence + 1:
		return _fail("pause_control_order")
	_remote_sequence = message.sequence
	_seen[message.sequence] = message.duplicate(true)
	_seen.erase(message.sequence - HISTORY)
	match message.action:
		Wire.Pause.REQUEST_PAUSE:
			if _player != 1 or absi(message.tick - tick) > _delay + 1:
				return _fail("invalid_pause_request")
			return _commit_pause(tick, now) if phase == Phase.RUNNING else true
		Wire.Pause.COMMIT_PAUSE:
			if _player != 2 or phase not in [Phase.RUNNING, Phase.REQUESTED]:
				return _fail("invalid_pause_commit")
			if message.tick < tick or message.tick > tick + 2 * _delay + 2:
				return _fail("invalid_pause_target")
			target = message.tick
			phase = Phase.ARMING
			_deadline = now + TIMEOUT_MS
		Wire.Pause.COMMIT_RESUME:
			if _player != 2 or phase != Phase.PAUSED or message.tick != target or epoch == Wire.MAX_TICK:
				return _fail("invalid_resume_commit")
			phase = Phase.RESUMING
			_deadline = now + TIMEOUT_MS
		_:
			return _fail("invalid_pause_action")
	return true


func poll(now: int) -> void:
	if _deadline > 0 and now >= _deadline:
		_fail("pause_timeout")


func take_messages() -> Array[Dictionary]:
	var messages := _outbox
	_outbox = []
	return messages


func _queue_control(action: int, tick: int) -> void:
	_sequence += 1
	_outbox.append(_message(Wire.Kind.PAUSE, epoch, tick, _sequence, {"action": action}))


func _message(kind: int, message_epoch: int, tick: int, sequence: int, extra: Dictionary) -> Dictionary:
	var message := {
		"kind": kind, "session": _session, "epoch": message_epoch, "player": _player, "tick": tick, "sequence": sequence
	}
	message.merge(extra)
	return message


func _digest_valid(digest: String) -> bool:
	return Config.hex_string(digest, 64)


func _fail(reason: String) -> bool:
	error = reason
	phase = Phase.FAILED
	_outbox.clear()
	return false
