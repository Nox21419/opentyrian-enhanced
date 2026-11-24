## Backend preview comparison only. No Ready/Start or gameplay scene handoff.
## The selected episode is explicit on both callers; player lobby wiring follows
## the original shop/progression integration, not this diagnostic milestone.
extends Node

signal changed

const Connection := preload("res://scripts/network_startup_connection.gd")
const Preparation := preload("res://scripts/network_preparation.gd")
const Startup := preload("res://scripts/network_startup.gd")
const PORT := 26635

var error := ""
var _connection := Connection.new()
var _preparation := Preparation.new()
var _stopping := false


func _ready() -> void:
	add_child(_connection)
	_connection.changed.connect(_changed)


func host(data_dir: String, dirs: PackedStringArray, enabled: Dictionary, episode: int, port := PORT) -> Error:
	if not _capture(data_dir, dirs, enabled, episode):
		return ERR_INVALID_PARAMETER
	var result := _connection.host(_preparation.identity(), _preparation.validate, port)
	if result != OK:
		_fail("host_failed")
	return result


func join(
	address: String, data_dir: String, dirs: PackedStringArray, enabled: Dictionary, episode: int, port := PORT
) -> Error:
	if not _capture(data_dir, dirs, enabled, episode):
		return ERR_INVALID_PARAMETER
	var result := _connection.join(address, _preparation.identity(), _preparation.validate, port)
	if result != OK:
		_fail("join_failed")
	return result


func _capture(data_dir: String, dirs: PackedStringArray, enabled: Dictionary, episode: int) -> bool:
	stop()
	if not _preparation.capture(data_dir, dirs, enabled, episode):
		return _fail(_preparation.error)
	return true


func stop() -> void:
	_stopping = true
	_connection.stop()
	_preparation.clear()
	error = ""
	_stopping = false
	changed.emit()


func compatible() -> bool:
	return _healthy() and _connection.startup.phase == Startup.Phase.COMPATIBLE


func agreed() -> bool:
	return _healthy() and _connection.startup.phase in [Startup.Phase.AGREED, Startup.Phase.LOADED]


func preview_matched() -> bool:
	return _healthy() and _connection.startup.phase == Startup.Phase.LOADED


func propose(config: Dictionary, session: String, epoch: int) -> bool:
	if not compatible():
		return false
	var accepted: bool = _connection.propose(config, session, epoch)
	return accepted and _healthy()


## LOADED here is the diagnostic coordinator's preview barrier, not a claim that
## the player's campaign passed its shop/story or can enable Ready/gameplay.
func compare_preview() -> bool:
	if not agreed():
		return false
	if not _preparation.prepare_preview() or not _preparation.verify_preview():
		return _fail(_preparation.error if not _preparation.error.is_empty() else "preview_failed")
	var accepted: bool = _connection.mark_loaded(_preparation.preview_digest())
	return accepted and _healthy()


func preview_digest() -> String:
	return _preparation.preview_digest() if _healthy() else ""


func entry() -> Dictionary:
	return _preparation.entry() if _healthy() else {}


func _healthy() -> bool:
	return (
		error.is_empty()
		and _connection.error.is_empty()
		and _connection.transport.connected
		and _connection.startup != null
	)


func _changed() -> void:
	if _stopping:
		return
	if not _connection.error.is_empty():
		_fail(_connection.error)
	elif not _preparation.error.is_empty():
		_fail(_preparation.error)
	else:
		changed.emit()


func _fail(reason: String) -> bool:
	_stopping = true
	error = reason
	_connection.stop()
	_preparation.clear()
	_stopping = false
	changed.emit()
	return false


func _exit_tree() -> void:
	stop()
