## Ordered complete input pairs. This module never advances the simulation.
## Local sampling and network transmission are owned by the future session adapter.
extends RefCounted

const Wire := preload("res://scripts/network_protocol.gd")
const MAX_AHEAD := 128
const HISTORY_TICKS := 128
const MAX_DELAY := 8  # Prototype negotiation bound, not a measured latency target.

enum Result { ACCEPTED, DUPLICATE, STALE, INVALID, WRONG_SESSION, TOO_FAR, CONFLICT, STOPPED }

var next_tick: int:
	get:
		return _next_tick
var failed: bool:
	get:
		return _failed

var _session := ""
var _epoch := 0
var _local_player := 0
var _delay := 0
var _next_tick := 0
var _active := false
var _failed := false
var _frames: Array[Dictionary] = [{}, {}]
var _history := {}


func configure(session: String, epoch: int, local_player: int, delay: int) -> Error:
	reset()
	if not Wire.valid_session(session) or epoch < 1 or epoch > Wire.MAX_TICK:
		return ERR_INVALID_PARAMETER
	if local_player not in [1, 2] or delay < 0 or delay > MAX_DELAY:
		return ERR_INVALID_PARAMETER
	_session = session
	_epoch = epoch
	_local_player = local_player
	_delay = delay
	_active = true
	for tick in delay:
		for player in 2:
			_frames[player][tick] = Wire.neutral_frame()
	return OK


func reset() -> void:
	_session = ""
	_epoch = 0
	_local_player = 0
	_delay = 0
	_next_tick = 0
	_active = false
	_failed = false
	_frames = [{}, {}]
	_history.clear()


## Read hardware only when this is true. A waiting tick must not consume another
## one-shot action, accumulate another mouse delta or sample a different frame.
func needs_local_input() -> bool:
	return _running() and local_input_tick() <= Wire.MAX_TICK and not _frames[_local_player - 1].has(local_input_tick())


func local_input_tick() -> int:
	return _next_tick + _delay


## Retransmission returns a copy of the already sampled frame, never a new input.
func capture_local(frame: Dictionary) -> Dictionary:
	if not _running() or local_input_tick() > Wire.MAX_TICK:
		return {}
	var tick := local_input_tick()
	var own: Dictionary = _frames[_local_player - 1]
	if not own.has(tick):
		if not Wire.valid_frame(frame):
			return {}
		own[tick] = frame.duplicate(true)
	return {
		"kind": Wire.Kind.INPUT,
		"session": _session,
		"epoch": _epoch,
		"player": _local_player,
		"tick": tick,
		"sequence": 0,
		"frame": own[tick].duplicate(true)
	}


## The transport decoder must also enforce sender identity; receiving one's own
## role here is an error, even if all fields look otherwise valid.
func receive(message: Dictionary) -> Result:
	if not _running():
		return Result.STOPPED
	if not Wire.valid_message(message) or message.kind != Wire.Kind.INPUT:
		return Result.INVALID
	if message.session != _session or message.epoch != _epoch:
		return Result.WRONG_SESSION
	if message.player == _local_player:
		return Result.INVALID
	var tick: int = message.tick
	var player: int = message.player - 1
	if tick < _next_tick:
		if not _history.has(tick):
			return Result.STALE
		return _duplicate(_history[tick][player], message.frame)
	if tick >= _next_tick + MAX_AHEAD:
		return Result.TOO_FAR
	if _frames[player].has(tick):
		return _duplicate(_frames[player][tick], message.frame)
	_frames[player][tick] = message.frame.duplicate(true)
	return Result.ACCEPTED


func _duplicate(previous: Dictionary, frame: Dictionary) -> Result:
	if previous == frame:
		return Result.DUPLICATE
	_failed = true
	return Result.CONFLICT


func ready() -> bool:
	return _running() and _frames[0].has(_next_tick) and _frames[1].has(_next_tick)


## Returns {} while waiting. Callers must not advance on an empty result.
## Returned data never aliases stored future frames or duplicate-check history.
func take_tick() -> Dictionary:
	if not ready():
		return {}
	var tick := _next_tick
	var inputs: Array = [_frames[0][tick], _frames[1][tick]]
	_history[tick] = inputs
	for player in 2:
		_frames[player].erase(tick)
	_history.erase(tick - HISTORY_TICKS)
	_next_tick += 1
	return {"tick": tick, "inputs": inputs.duplicate(true)}


func pending_frame_count() -> int:
	return _frames[0].size() + _frames[1].size()


func history_tick_count() -> int:
	return _history.size()


func _running() -> bool:
	return _active and not _failed and _next_tick <= Wire.MAX_TICK
