## Two bounded read-only decisions. Callers derive/verify their own candidates.
## Host proposal -> guest acknowledgement -> host commit; no scene/native access.
extends RefCounted

const Wire := preload("res://scripts/network_protocol.gd")
const Config := preload("res://scripts/network_configuration.gd")
const TIMEOUT_MS := 30000
var error := ""
var epoch := 0
var _session := ""
var _player := 0
var _tick := 0
var _local := {}
var _proposed := {}
var _remote := {}
var _acked := {}
var _committed := {}
var _deadline := 0
var _outbox: Array[Dictionary] = []


func configure(session: String, input_epoch: int, player: int, tick: int) -> bool:
	if not _session.is_empty() or not Wire.valid_session(session) or player not in [1, 2]:
		return _fail("invalid_continuation_context")
	if not Config.integer(input_epoch, 1, Wire.MAX_TICK) or not Config.integer(tick, 1, Wire.MAX_TICK):
		return _fail("invalid_continuation_context")
	_session = session
	epoch = input_epoch
	_player = player
	_tick = tick
	return true


func committed_sequence() -> int:
	return _committed.size() if error.is_empty() else 0


func committed_digest(sequence: int) -> String:
	return _committed.get(sequence, "") if error.is_empty() else ""


func has_candidate(sequence: int) -> bool:
	return _local.has(sequence) and error.is_empty()


## Adapter fast path for bounded history: receive() still checks conflicts and
## deadlines, but a duplicate need not trigger another filesystem verification.
func has_seen_control(message: Dictionary) -> bool:
	if message.get("session") != _session or message.get("epoch") != epoch or message.get("tick") != _tick:
		return false
	if message.get("player") != 3 - _player:
		return false
	var sequence: int = message.get("sequence", 0)
	return _committed.has(sequence) or (message.get("kind") == Wire.Kind.CONTINUATION and _remote.has(sequence))


func prepare(sequence: int, digest: String, now: int) -> bool:
	if not error.is_empty() or _session.is_empty():
		return false
	if _deadline > 0 and now >= _deadline:
		return _fail("continuation_timeout")
	if sequence not in [1, 2] or not Config.hex_string(digest, 64):
		return _fail("invalid_continuation_candidate")
	if _local.has(sequence):
		return true if _local[sequence] == digest else _fail("changed_continuation_candidate")
	if sequence != committed_sequence() + 1:
		return _fail("skipped_continuation_candidate")
	_local[sequence] = digest
	return _acknowledge(sequence)


func propose(sequence: int, now: int) -> bool:
	if not error.is_empty() or _player != 1 or not _local.has(sequence):
		return false
	if _proposed.has(sequence):
		return true
	if sequence != committed_sequence() + 1:
		return _fail("skipped_continuation_proposal")
	_proposed[sequence] = true
	_outbox.append(_message(Wire.Kind.CONTINUATION, sequence, _local[sequence]))
	_deadline = now + TIMEOUT_MS
	return true


func receive(message: Dictionary, now: int) -> bool:
	if not error.is_empty():
		return false
	if not Wire.valid_message(message) or message.player != 3 - _player:
		return _fail("invalid_continuation_message")
	if message.session != _session or message.epoch < epoch:
		return true
	if message.epoch != epoch or message.tick != _tick:
		return _fail("continuation_context_mismatch")
	if _deadline > 0 and now >= _deadline:
		return _fail("continuation_timeout")
	if message.kind not in [Wire.Kind.CONTINUATION, Wire.Kind.CONTINUATION_ACK, Wire.Kind.CONTINUATION_COMMIT]:
		return _fail("unexpected_continuation_message")
	var sequence: int = message.sequence
	if _committed.has(sequence):
		return true if _committed[sequence] == message.digest else _fail("changed_committed_continuation")
	if sequence != committed_sequence() + 1:
		return _fail("skipped_continuation_decision")
	match message.kind:
		Wire.Kind.CONTINUATION:
			if _remote.has(sequence):
				return true if _remote[sequence] == message.digest else _fail("changed_continuation_proposal")
			_remote[sequence] = message.digest
			_deadline = now + TIMEOUT_MS
			return _acknowledge(sequence)
		Wire.Kind.CONTINUATION_ACK:
			if not _proposed.has(sequence) or _local.get(sequence, "") != message.digest:
				return _fail("unmatched_continuation_ack")
			_committed[sequence] = message.digest
			_outbox.append(_message(Wire.Kind.CONTINUATION_COMMIT, sequence, message.digest))
			_deadline = 0
		Wire.Kind.CONTINUATION_COMMIT:
			if not _acked.has(sequence) or _local.get(sequence, "") != message.digest:
				return _fail("premature_continuation_commit")
			_committed[sequence] = message.digest
			_deadline = 0
	return true


func _acknowledge(sequence: int) -> bool:
	if _player != 2 or not _remote.has(sequence) or not _local.has(sequence):
		return true
	if _remote[sequence] != _local[sequence]:
		return _fail("continuation_proposal_mismatch")
	if not _acked.has(sequence):
		_acked[sequence] = true
		_outbox.append(_message(Wire.Kind.CONTINUATION_ACK, sequence, _local[sequence]))
	return true


func poll(now: int) -> void:
	if error.is_empty() and _deadline > 0 and now >= _deadline:
		_fail("continuation_timeout")


func take_messages() -> Array[Dictionary]:
	var messages := _outbox
	_outbox = []
	return messages


func _message(kind: int, sequence: int, digest: String) -> Dictionary:
	return {
		"kind": kind,
		"session": _session,
		"epoch": epoch,
		"player": _player,
		"tick": _tick,
		"sequence": sequence,
		"digest": digest
	}


func _fail(reason: String) -> bool:
	error = reason
	_outbox.clear()
	return false
