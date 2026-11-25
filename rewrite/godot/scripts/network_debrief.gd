## Detached original debrief/Statistics view. A session coordinator must agree
## results and both phase-readiness acknowledgements before committing advance.
## This view never selects a level or modifies Game's local campaign globals.
extends "res://scripts/debrief.gd"

const Config := preload("res://scripts/network_configuration.gd")
signal phase_ready(stage: int)
signal advance_requested(stage: int)
signal finished
var _snapshot := {}
var _episode := 0
var _role := 0
var _elapsed_seconds := 0
var _stage := 0
var _committed := 0
var _requested := false
var _frozen := false


func bind(result: RefCounted, config: Dictionary, role: int, elapsed_seconds: int) -> bool:
	if is_inside_tree() or not _snapshot.is_empty() or role not in [1, 2] or elapsed_seconds < 0:
		return false
	if not Config.valid(config) or not is_instance_valid(result) or not result.has_method("record"):
		return false
	var record: Dictionary = result.record()
	if record.is_empty() or record.config != Config.digest(config) or not record.stats.get("any_player_alive", false):
		return false
	_snapshot = record.stats.duplicate(true)
	_episode = config.episode
	_role = role
	_elapsed_seconds = elapsed_seconds
	return true


func _ready() -> void:
	if _snapshot.is_empty():
		queue_free()
		return
	super._ready()


## Coordinator-only commits, after both screens reached this phase. Duplicate
## commits are idempotent; future/out-of-order commits cannot skip a screen.
func commit_phase(stage: int) -> bool:
	if stage < 1 or stage > 2 or stage > _stage or stage > _committed + 1:
		return false
	_committed = maxi(_committed, stage)
	return true


func _debrief_data() -> Dictionary:
	return _snapshot.duplicate(true)


func _debrief_episode() -> int:
	return _episode


func _consume_frozen_background() -> bool:
	var frozen := _frozen
	_frozen = false
	return frozen


## The owner freezes the last presented frame immediately before scene handoff.
## Reuse the local renderer, but never write Game.debrief_frozen.
func freeze_from(level: Node) -> bool:
	if is_inside_tree() or _snapshot.is_empty() or not is_instance_valid(level):
		return false
	var frozen: Node = preload("res://scripts/frozen_level_screen.gd").new()
	_frozen = frozen.freeze(level)
	frozen.free()
	return _frozen


func _debrief_two_players() -> bool:
	return true


func _debrief_timed() -> bool:
	return false


func _debrief_show_cubes() -> bool:
	return false


func _debrief_elapsed_seconds() -> int:
	return _elapsed_seconds


func _continue_prompt(summary: bool) -> String:
	return TyrianText.L("net_wait_host") if _role == 2 else super._continue_prompt(summary)


func _input(event: InputEvent) -> void:
	if _role == 1:
		super._input(event)


func _any_button() -> bool:
	return super._any_button() if _role == 1 else false


func _wait_summary(_was_animating: bool) -> void:
	_stage = 1
	_requested = false
	_input_seen = false
	phase_ready.emit(1)
	while is_inside_tree() and _committed < 1:
		if _any_button():
			_request_advance()
		await wait_units(1)


func _wait_statistics() -> void:
	_stage = 2
	_requested = false
	_input_seen = false
	phase_ready.emit(2)
	while is_inside_tree() and _committed < 2:
		await wait_units(1)


func _request_advance() -> void:
	if _role == 1 and not _requested and _stage > _committed:
		_requested = true
		advance_requested.emit(_stage)


func handle_action(action: StringName) -> void:
	_touch_release.cancel()
	if stats_shown and action in [TyrianControls.ACCEPT, TyrianControls.BACK]:
		_request_advance()


func _finish_debrief() -> void:
	if is_inside_tree() and _committed == 2:
		finished.emit()
