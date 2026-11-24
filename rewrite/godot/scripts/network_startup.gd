## Pure startup state machine. Transport and actual scene/configuration loading
## are explicit callers; this never changes Game, steps a Sim or enables UI.
extends RefCounted

const Protocol := preload("res://scripts/network_startup_protocol.gd")
const Config := preload("res://scripts/network_configuration.gd")
enum Phase { NEW, COMPATIBLE, PROPOSED, AGREED, LOADED, READY, RUNNING, FAILED }
enum Received { ACCEPTED, DUPLICATE, STALE, REJECTED }
const REPLY_TIMEOUT_MS := 8000
const LOAD_TIMEOUT_MS := 30000

var phase := Phase.NEW
var error := ""
var _player := 0
var _identity := {}
var _validator: Callable
var _config := {}
var _session := ""
var _epoch := 0
var _digest := ""
var _loaded := ""
var _remote_loaded := ""
var _ready := false
var _remote_ready := false
var _sequence := 0
var _incoming := 0
var _last_message := {}
var _hello := {}
var _outbox: Array[Dictionary] = []
var _deadline := 0


func _init(player: int, identity: Dictionary, validator: Callable) -> void:
	if player not in [1, 2] or not Protocol.valid_identity(identity) or not validator.is_valid():
		_fail("invalid_local_configuration")
		return
	_player = player
	_identity = identity.duplicate(true)
	_validator = validator
	_outbox.append({"kind": "hello", "player": player, "identity": _identity.duplicate(true)})
	_deadline = Time.get_ticks_msec() + REPLY_TIMEOUT_MS


func configuration() -> Dictionary:
	return _config.duplicate(true)


func context() -> Dictionary:
	return {"session": _session, "epoch": _epoch, "player": _player}


func take_messages() -> Array[Dictionary]:
	var messages: Array[Dictionary] = _outbox.duplicate(true)
	_outbox.clear()
	return messages


func propose(config: Dictionary, session: String, epoch: int) -> bool:
	if phase != Phase.COMPATIBLE or _player != 1:
		return false
	if not Config.valid(config) or not Config.hex_string(session, 32) or not Config.integer(epoch, 1, 0xffffffff):
		return false
	if not _valid_locally(config):
		return false
	_config = config.duplicate(true)
	_session = session
	_epoch = epoch
	_digest = Config.digest(config)
	phase = Phase.PROPOSED
	_send("config", {"config": _config.duplicate(true)})
	if phase == Phase.FAILED:
		return false
	_deadline = Time.get_ticks_msec() + REPLY_TIMEOUT_MS
	return true


func mark_loaded(state_digest: String) -> bool:
	if phase not in [Phase.AGREED, Phase.LOADED] or not Config.hex_string(state_digest, 64):
		return false
	if not _loaded.is_empty():
		return _loaded == state_digest
	if not _remote_loaded.is_empty() and _remote_loaded != state_digest:
		_fail("initial_state_mismatch")
		return false
	_loaded = state_digest
	_send("loaded", {"state": state_digest})
	if phase == Phase.FAILED:
		return false
	_update_loaded()
	return true


func confirm_ready() -> bool:
	if phase not in [Phase.LOADED, Phase.READY]:
		return false
	if not _ready:
		_ready = true
		_send("ready", {"state": _loaded})
		if phase == Phase.FAILED:
			return false
		phase = Phase.READY
	return true


func start() -> bool:
	if _player != 1 or phase != Phase.READY or not _remote_ready:
		return false
	_send("start", {"state": _loaded})
	if phase == Phase.FAILED:
		return false
	phase = Phase.RUNNING
	_deadline = 0
	return true


func receive(message: Dictionary) -> Received:
	if phase == Phase.FAILED:
		return Received.REJECTED
	if not Protocol.valid(message) or message.player == _player:
		return _fail("invalid_startup_message")
	if message.kind == "hello":
		return _receive_hello(message)
	if phase == Phase.NEW:
		return _fail("startup_out_of_order")
	if not _session.is_empty() and (message.session != _session or message.epoch != _epoch):
		return Received.STALE
	if message.sequence == _incoming:
		return Received.DUPLICATE if message == _last_message else _fail("conflicting_control")
	if message.sequence < _incoming:
		return Received.STALE
	if message.sequence != _incoming + 1:
		return _fail("startup_out_of_order")
	_incoming = message.sequence
	_last_message = message.duplicate(true)
	match message.kind:
		"config":
			if _player != 2 or phase != Phase.COMPATIBLE or not _valid_locally(message.config):
				return _fail("configuration_rejected")
			_session = message.session
			_epoch = message.epoch
			_config = message.config.duplicate(true)
			_digest = message.digest
			phase = Phase.AGREED
			_send("accept", {})
			_deadline = Time.get_ticks_msec() + LOAD_TIMEOUT_MS
		"accept":
			if _player != 1 or phase != Phase.PROPOSED or message.digest != _digest:
				return _fail("configuration_rejected")
			phase = Phase.AGREED
			_deadline = Time.get_ticks_msec() + LOAD_TIMEOUT_MS
		"loaded":
			if phase not in [Phase.AGREED, Phase.LOADED] or message.digest != _digest or not _remote_loaded.is_empty():
				return _fail("startup_out_of_order")
			_remote_loaded = message.state
			if not _loaded.is_empty() and _loaded != _remote_loaded:
				return _fail("initial_state_mismatch")
			_update_loaded()
		"ready":
			if phase not in [Phase.LOADED, Phase.READY] or message.digest != _digest or message.state != _loaded:
				return _fail("invalid_ready")
			_remote_ready = true
		"start":
			if (
				_player != 2
				or phase != Phase.READY
				or not _remote_ready
				or message.digest != _digest
				or message.state != _loaded
			):
				return _fail("invalid_start")
			phase = Phase.RUNNING
			_deadline = 0
	return Received.REJECTED if phase == Phase.FAILED else Received.ACCEPTED


func _valid_locally(config: Dictionary) -> bool:
	var accepted: Variant = _validator.call(config.duplicate(true))
	return accepted is bool and accepted


func _receive_hello(message: Dictionary) -> Received:
	if not _hello.is_empty():
		return Received.DUPLICATE if _hello == message else _fail("conflicting_identity")
	if phase != Phase.NEW:
		return _fail("startup_out_of_order")
	for field in Protocol.IDENTITIES:
		if _identity[field] != message.identity[field]:
			return _fail(field + "_mismatch")
	_hello = message.duplicate(true)
	phase = Phase.COMPATIBLE
	_deadline = 0  # Human menu selection is not a network timeout.
	return Received.ACCEPTED


func _update_loaded() -> void:
	if not _loaded.is_empty() and not _remote_loaded.is_empty():
		phase = Phase.LOADED
		_deadline = 0  # Both may take time to explicitly confirm Ready.


func check_timeout(now_msec := -1) -> void:
	var now := Time.get_ticks_msec() if now_msec < 0 else now_msec
	if _deadline > 0 and now >= _deadline:
		_fail("startup_timeout")


func _send(kind: String, extra: Dictionary) -> void:
	if _outbox.size() >= 8:
		_fail("startup_queue_limit")
		return
	_sequence += 1
	var message := {
		"kind": kind, "player": _player, "session": _session, "epoch": _epoch, "sequence": _sequence, "digest": _digest
	}
	message.merge(extra)
	_outbox.append(message)


func _fail(reason: String) -> Received:
	phase = Phase.FAILED
	error = reason
	_deadline = 0
	_outbox.clear()
	return Received.REJECTED
