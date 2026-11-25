## Player-menu owner supplies the binding, clock rate and exit policy before
## entering the tree. Original entry transition precedes the two-view barrier.
extends "res://scripts/network_level.gd"

var controller: Node


func _ready() -> void:
	super._ready()
	if not _presentation_ready or not enable_network_input():
		_leave("player_initialization_failed")
		return
	set_process_unhandled_input(true)
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	if not _borrow_valid() or not _presentation_ready or sim.level_ended():
		_leave("session_or_level_ended")
		return
	if not _network_clock_enabled:
		if entry_pending():
			return
		if not backend.mark_view_ready():
			_leave("view_ready_failed")
			return
		if not backend.views_ready():
			return
		if not enable_network_clock():
			_leave("clock_start_failed")
			return
	super._physics_process(delta)
	if not _network_clock_enabled:
		_leave("clock_stopped")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("tyrian_level_exit") and not event.is_echo():
		get_viewport().set_input_as_handled()
		_leave()


func _leave(reason := "left") -> void:
	disable_network_input()
	if is_instance_valid(controller):
		controller.leave_player(self, reason)


func _exit_tree() -> void:
	if is_instance_valid(controller):
		controller.player_scene_exited(self)
