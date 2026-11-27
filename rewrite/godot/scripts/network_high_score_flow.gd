## Pure high-score stage agreement. Host persistence is an explicit boundary.
extends RefCounted

const Model := preload("res://scripts/network_episode_high_scores.gd")
const Wire := preload("res://scripts/network_high_score_wire.gd")
const Data := preload("res://scripts/network_story_script.gd")
const Config := preload("res://scripts/network_configuration.gd")
const RENDER_MS := 180000
const FINISH_MS := 30000
var error := ""
var _context := {}
var _inputs := []
var _model: RefCounted
var _stage := {}
var _serial := 1
var _local_ready := false
var _remote_ready := false
var _wanted := false
var _local_done := false
var _remote_done := false
var _name := ""
var _edit_id := 0
var _submitted := []
var _pending := {}
var _seen := {}
var _deadline := 0
var _outbox := []


func configure(
	context: Dictionary,
	config: Dictionary,
	record: Dictionary,
	proposal: Dictionary,
	history: Dictionary,
	rows: Array,
	now: int
) -> bool:
	if (
		not _context.is_empty()
		or context.size() != 5
		or not Config.integer(context.get("player"), 1, 2)
		or not Config.hex_string(context.get("session"), 32)
		or not Config.integer(context.get("epoch"), 1, 0xffffffff)
		or not Config.integer(context.get("tick"), 1, 0xffffffff)
		or not Config.integer(context.get("decision"), 1, 2)
	):
		return _fail("invalid_high_score_context")
	_context = context.duplicate()
	_inputs = [config.duplicate(true), record.duplicate(true), proposal.duplicate(true), history.duplicate(true)]
	_deadline = now + RENDER_MS
	if context.player == 1:
		if not _begin_rows(rows, now):
			return false
		_outbox.append(_message("open", Wire.encode_rows(rows)))
	return true


func _begin_rows(rows: Array, now: int) -> bool:
	_model = Model.new()
	if not _model.begin(_inputs[0], _inputs[1], _inputs[2], _inputs[3], rows):
		return _fail(_model.error)
	_next_entry(now)
	return true


func snapshot() -> Dictionary:
	var result := _stage.duplicate(true)
	if not result.is_empty():
		result["text"] = _name
	return result


func ready(serial: int, now: int) -> bool:
	if not poll(now) or serial != _serial or _stage.is_empty():
		return false
	if not _local_ready:
		_local_ready = true
		_outbox.append(_message("ready"))
	return _settle(now)


func edit(name: String) -> bool:
	if (
		_context.get("player") != 1
		or _stage.get("phase") != "name"
		or not Wire.valid_name(name)
		or not _submitted.is_empty()
	):
		return false
	if name != _name:
		_name = name
		_edit_id += 1
		_outbox.append(_message("edit", [_edit_id, name]))
	return true


func submit(name: String, cancel: bool, now: int) -> bool:
	if not poll(now) or _context.get("player") != 1 or _stage.get("phase") != "name" or not Wire.valid_name(name):
		return false
	if not _submitted.is_empty():
		return _submitted == [name, cancel]
	_submitted = [name, cancel]
	return _settle(now)


func pending_transaction() -> Dictionary:
	return _pending.duplicate(true)


func persisted(digest: String, now: int) -> bool:
	if not poll(now) or _context.get("player") != 1 or _pending.is_empty() or _pending.digest != digest:
		return false
	var transaction := _pending.duplicate(true)
	_outbox.append(_message("submit", [transaction.name, transaction.cancel, digest]))
	_pending.clear()
	_serial += 1
	_set_stage("table", transaction.entry, transaction.after, now)
	return true


func advance(serial: int, now: int) -> bool:
	if (
		not poll(now)
		or _context.get("player") != 1
		or _stage.get("phase") != "table"
		or serial != _serial
		or not _local_ready
	):
		return false
	_wanted = true
	return _settle(now)


func finish(now: int) -> bool:
	if not poll(now) or _stage.get("phase") != "done" or not _local_ready:
		return false
	if not _local_done:
		_local_done = true
		_outbox.append(_message("finish"))
		_start_finish_deadline(now)
	return true


func complete() -> bool:
	return error.is_empty() and _local_done and _remote_done


func receive(message: Dictionary, now: int) -> bool:
	if not poll(now) or not Wire.valid(message) or _context.is_empty() or message.player != 3 - _context.player:
		return _fail("invalid_high_score_message")
	if message.session != _context.session or message.epoch < _context.epoch:
		return true
	if message.epoch != _context.epoch or message.tick != _context.tick or message.decision != _context.decision:
		return _fail("high_score_context_mismatch")
	var key := "%d:%s:%d" % [message.serial, message.kind, message.player]
	if message.kind != "edit" and _seen.has(key):
		return true if _seen[key] == message else _fail("conflicting_high_score_message")
	if message.kind == "open":
		if _context.player != 2 or not _stage.is_empty() or message.serial != 1:
			return _fail("unexpected_high_score_open")
		if not _begin_rows(Wire.decode_rows(message.payload), now):
			return false
	if message.serial < _serial and message.kind == "edit":
		return true
	if message.serial != _serial or _stage.is_empty() or message.digest != _stage.digest:
		return _fail("high_score_stage_mismatch")
	match message.kind:
		"open":
			pass
		"ready":
			_remote_ready = true
		"edit":
			if _stage.phase != "name":
				return _fail("edit_outside_name")
			if message.payload[0] < _edit_id:
				return true
			if message.payload[0] == _edit_id:
				return true if message.payload[1] == _name else _fail("conflicting_name_edit")
			if message.payload[0] != _edit_id + 1:
				return _fail("skipped_name_edit")
			_edit_id = message.payload[0]
			_name = message.payload[1]
		"submit":
			if _stage.phase != "name" or not _local_ready or not _remote_ready:
				return _fail("name_commit_before_ready")
			var transaction: Dictionary = _model.submit(message.payload[0], message.payload[1], _stage.entry.digest)
			if transaction.is_empty() or transaction.digest != message.payload[2]:
				return _fail("high_score_transaction_mismatch")
			_serial += 1
			_set_stage("table", transaction.entry, transaction.after, now)
		"advance":
			if _stage.phase != "table" or not _local_ready or not _remote_ready:
				return _fail("table_advance_before_ready")
			_serial += 1
			_next_entry(now)
		"finish":
			if _stage.phase != "done" or not _remote_ready:
				return _fail("high_score_finish_before_ready")
			_remote_done = true
			_start_finish_deadline(now)
	if message.kind != "edit":
		_seen[key] = message.duplicate(true)
	return _settle(now)


func poll(now: int) -> bool:
	if not error.is_empty():
		return false
	return _fail("high_score_timeout") if _deadline > 0 and now >= _deadline and not complete() else true


func take_messages() -> Array:
	var result := _outbox.duplicate(true)
	_outbox.clear()
	return result


func _next_entry(now: int) -> void:
	var entry: Dictionary = _model.entry()
	_set_stage("done" if entry.is_empty() else "name", entry, _model.rows(), now)


func _set_stage(phase: String, entry: Dictionary, rows: Array, now: int) -> void:
	_stage = {
		"source": _model.source,
		"serial": _serial,
		"phase": phase,
		"entry": entry.duplicate(true),
		"rows": rows.duplicate(true)
	}
	_stage["digest"] = Data.digest(_stage)
	_local_ready = false
	_remote_ready = false
	_wanted = false
	_name = ""
	_edit_id = 0
	_submitted.clear()
	_deadline = now + RENDER_MS


func _settle(now: int) -> bool:
	if _local_ready and _remote_ready:
		if complete() or not (_local_done or _remote_done):
			_deadline = 0
		if _context.player == 1 and _stage.get("phase") == "name" and not _submitted.is_empty() and _pending.is_empty():
			_pending = _model.submit(_submitted[0], _submitted[1], _stage.entry.digest)
			if _pending.is_empty():
				return _fail("invalid_name_submission")
		if _context.player == 1 and _stage.get("phase") == "table" and _wanted:
			_outbox.append(_message("advance"))
			_serial += 1
			_next_entry(now)
	return true


func _start_finish_deadline(now: int) -> void:
	if complete():
		_deadline = 0
	elif not (_local_done and _remote_done) and (_deadline == 0 or _deadline > now + FINISH_MS):
		_deadline = now + FINISH_MS


func _message(kind: String, payload := []) -> Dictionary:
	return {
		"kind": kind,
		"player": _context.player,
		"session": _context.session,
		"epoch": _context.epoch,
		"tick": _context.tick,
		"decision": _context.decision,
		"serial": _serial,
		"digest": _stage.digest,
		"payload": payload.duplicate(true)
	}


func _fail(reason: String) -> bool:
	error = reason
	_outbox.clear()
	return false
