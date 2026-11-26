## Bounded story readiness/host commits. No renderer, native or transport calls.
extends RefCounted

const Wire := preload("res://scripts/network_protocol.gd")
const Config := preload("res://scripts/network_configuration.gd")
const StoryData := preload("res://scripts/network_story_script.gd")
const RENDER_TIMEOUT_MS := 180000
const FINISH_TIMEOUT_MS := 30000
var error := ""
var _session := ""
var _epoch := 0
var _player := 0
var _tick := 0
var _decision := 0
var _descriptor := {}
var _local := {}
var _remote := {}
var _wanted := {}
var _committed := 0
var _local_done := ""
var _remote_done := ""
var _final_context := {}
var _deadline := 0
var _outbox: Array[Dictionary] = []


func configure(session: String, epoch: int, player: int, tick: int, decision: int, descriptor: Dictionary) -> bool:
	if (
		not error.is_empty()
		or not _session.is_empty()
		or not Wire.valid_session(session)
		or not StoryData.valid(descriptor)
	):
		return _fail("invalid_story_context")
	if (
		not Config.integer(epoch, 1, Wire.MAX_TICK)
		or not Config.integer(tick, 1, Wire.MAX_TICK)
		or player not in [1, 2]
		or decision not in [1, 2]
	):
		return _fail("invalid_story_context")
	_session = session
	_epoch = epoch
	_player = player
	_tick = tick
	_decision = decision
	_descriptor = descriptor.duplicate(true)
	return true


func committed_page() -> int:
	return _committed if error.is_empty() else 0


func complete() -> bool:
	return error.is_empty() and not _local_done.is_empty() and _local_done == _remote_done


func final_context() -> Dictionary:
	return _final_context.duplicate() if complete() else {}


func ready(page: int, digest: String, now: int) -> bool:
	if not poll(now) or _session.is_empty() or digest.is_empty() or digest != StoryData.page_digest(_descriptor, page):
		return _fail(error if not error.is_empty() else "invalid_story_page")
	if _local.has(page):
		return true
	if page != _committed + 1:
		return _fail("skipped_story_page")
	_local[page] = digest
	_outbox.append(_message(Wire.Kind.STORY_READY, page, digest))
	return _settle_page(page, now)


func request_advance(page: int, digest: String, now: int) -> bool:
	if not poll(now) or _player != 1 or not _local.has(page):
		return false
	if digest != _local[page]:
		return _fail("changed_story_request")
	if page <= _committed:
		return true
	_wanted[page] = true
	return _settle_page(page, now)


func finish(context: Dictionary, now: int) -> bool:
	if (
		not poll(now)
		or _session.is_empty()
		or not StoryData.valid_context(context)
		or _committed != _descriptor.pages.size()
	):
		return _fail(error if not error.is_empty() else "story_finished_before_pages")
	var digest := StoryData.digest({"descriptor": _descriptor.digest, "context": context})
	if not _local_done.is_empty():
		return true if _local_done == digest else _fail("changed_story_finish")
	_local_done = digest
	_final_context = context.duplicate()
	_outbox.append(_message(Wire.Kind.STORY_DONE, 129, digest))
	if not _remote_done.is_empty() and _remote_done != _local_done:
		return _fail("story_context_mismatch")
	if complete():
		_deadline = 0
	elif _deadline == 0:
		_deadline = now + FINISH_TIMEOUT_MS
	return true


func has_seen_control(message: Dictionary) -> bool:
	if (
		message.get("session") != _session
		or message.get("epoch") != _epoch
		or message.get("tick") != _tick
		or message.get("player") != 3 - _player
		or message.get("sequence", 0) >> 16 != _decision
	):
		return false
	var page: int = message.sequence & 0xffff
	match message.get("kind"):
		Wire.Kind.STORY_READY:
			return _remote.has(page)
		Wire.Kind.STORY_ADVANCE:
			return page <= _committed
		Wire.Kind.STORY_DONE:
			return not _remote_done.is_empty()
	return false


func receive(message: Dictionary, now: int) -> bool:
	if not poll(now) or not Wire.valid_message(message) or message.player != 3 - _player:
		return _fail(error if not error.is_empty() else "invalid_story_message")
	if message.session != _session or message.epoch < _epoch:
		return true
	if message.epoch != _epoch or message.tick != _tick or message.sequence >> 16 != _decision:
		return _fail("story_context_mismatch")
	var page: int = message.sequence & 0xffff
	if message.kind == Wire.Kind.STORY_DONE:
		if _committed != _descriptor.pages.size():
			return _fail("story_finished_before_pages")
		if not _remote_done.is_empty() and _remote_done != message.digest:
			return _fail("changed_story_finish")
		_remote_done = message.digest
		if not _local_done.is_empty() and _local_done != _remote_done:
			return _fail("story_context_mismatch")
		if complete():
			_deadline = 0
		elif _deadline == 0:
			_deadline = now + FINISH_TIMEOUT_MS
		return true
	if (
		message.kind not in [Wire.Kind.STORY_READY, Wire.Kind.STORY_ADVANCE]
		or message.digest != StoryData.page_digest(_descriptor, page)
	):
		return _fail("story_page_mismatch")
	if page <= _committed:
		return true
	if page != _committed + 1:
		return _fail("skipped_story_page")
	match message.kind:
		Wire.Kind.STORY_READY:
			_remote[page] = message.digest
			return _settle_page(page, now)
		Wire.Kind.STORY_ADVANCE:
			if not _local.has(page) or not _remote.has(page):
				return _fail("premature_story_advance")
			_committed = page
			_deadline = 0
	return true


func poll(now: int) -> bool:
	if not error.is_empty():
		return false
	if _deadline > 0 and now >= _deadline:
		return _fail("story_timeout")
	return true


func take_messages() -> Array[Dictionary]:
	var messages := _outbox
	_outbox = []
	return messages


func _settle_page(page: int, now: int) -> bool:
	if _local.has(page) and _remote.has(page):
		_deadline = 0
		if _player == 1 and _wanted.has(page):
			_committed = page
			_outbox.append(_message(Wire.Kind.STORY_ADVANCE, page, _local[page]))
	elif _deadline == 0:
		_deadline = now + RENDER_TIMEOUT_MS
	return true


func _message(kind: int, page: int, digest: String) -> Dictionary:
	return {
		"kind": kind,
		"session": _session,
		"epoch": _epoch,
		"player": _player,
		"tick": _tick,
		"sequence": (_decision << 16) | page,
		"digest": digest
	}


func _fail(reason: String) -> bool:
	error = reason
	_outbox.clear()
	return false
