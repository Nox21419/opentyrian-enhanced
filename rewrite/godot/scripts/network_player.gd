## Player-menu owner supplies the binding, clock rate and exit policy before
## entering the tree. Original entry transition precedes the two-view barrier.
extends "res://scripts/network_level.gd"

var controller: Node
const PauseMenu := preload("res://scripts/network_pause_menu.gd")
const Debrief := preload("res://scripts/network_debrief.gd")
var _quiet_input := false
var _level_started_ms := 0
var _ending := false
var _leaving := false
var _debrief: Node


func _ready() -> void:
	pause_controls = true
	super._ready()
	if not _presentation_ready or not enable_network_input():
		_leave("player_initialization_failed")
		return
	set_process_unhandled_input(true)
	set_physics_process(true)


func _physics_process(delta: float) -> void:
	if not _borrow_valid() or not _presentation_ready:
		_leave("session_ended")
		return
	if sim.level_ended():
		_begin_completion()
		return
	if _clock_started and backend.pause_boundary_reached():
		if not backend.note_pause_boundary():
			_leave("pause_boundary_failed")
			return
		_sync_pause_ui()
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
		_level_started_ms = Time.get_ticks_msec()
	super._physics_process(delta)
	if not _network_clock_enabled:
		_leave("clock_stopped")


func _unhandled_input(event: InputEvent) -> void:
	if _pause_menu != null or _ending:
		return
	if (
		(event.is_action_pressed("tyrian_level_exit") and not event.is_echo())
		or TyrianControls.global_pressed(event, TyrianControls.PAUSE)
		or (event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_P)
	):
		get_viewport().set_input_as_handled()
		if not _clock_started or _game_over_shown() or (is_instance_valid(backend) and backend.local_paused()):
			_leave()
		else:
			open_pause_menu()


func _input(event: InputEvent) -> void:
	if _ending or (is_instance_valid(backend) and backend.inputs_quiesced()):
		return
	super._input(event)


func open_pause_menu() -> void:
	if not _ending and _clock_started and is_instance_valid(backend):
		backend.request_pause()


func _backend_changed() -> void:
	super._backend_changed()
	if _ending:
		_sync_completion()
	else:
		_sync_pause_ui()


func _begin_completion() -> void:
	if _ending or _leaving:
		return
	_ending = true
	disable_network_clock()
	_clear_pause_gestures()
	if _touch_pause_label != null:
		_touch_pause_label.visible = false
	var elapsed := maxi(Time.get_ticks_msec() - _level_started_ms, 0) / 1000 if player == 1 else 0
	if not backend.note_level_result(_presented_tick, _network_level_name, elapsed):
		_leave("result_capture_failed")
		return
	_sync_completion()


func _sync_completion() -> void:
	if _leaving or not _borrow_valid() or not backend.completion_agreed():
		return
	if _debrief == null:
		var result: RefCounted = backend.result_for_view()
		var before: String = backend.diagnostic_digest()
		if result.record().core != before:
			_leave("changed_final_state")
			return
		var bonus_completion: bool = (
			backend.has_method("bonus_completion_for_view") and backend.bonus_completion_for_view()
		)
		if not bool(result.record().stats.get("any_player_alive", false)) and not bonus_completion:
			_leave("game_over")
			return
		var screen := Debrief.new()
		var continuation: bool = (
			backend.has_method("continuation_level_for_view") and not backend.continuation_level_for_view().is_empty()
		)
		if (
			not screen.bind(result, _config, player, backend.result_elapsed_seconds(), continuation, bonus_completion)
			or not screen.freeze_from(self)
		):
			screen.free()
			_leave("debrief_binding_failed")
			return
		if backend.diagnostic_digest() != before:
			screen.free()
			_leave("debrief_changed_final_state")
			return
		_debrief = screen
		screen.name = "NetworkDebrief"
		screen.z_index = Z.HUD + 4
		screen.set("_touch_stats", true)
		screen.phase_ready.connect(_result_screen_ready)
		screen.advance_requested.connect(_result_advance_requested)
		screen.finished.connect(_result_fade_finished)
		add_child(screen)
	var phase: int = backend.result_committed_phase()
	if phase == 3:
		if is_instance_valid(controller) and controller.has_method("continue_player"):
			_leaving = true
			disable_network_input()
			if not controller.continue_player(self):
				controller.leave_player(self, "continuation_handoff_failed")
		else:
			_leave("first_level_complete")
	elif phase > 0 and not _debrief.commit_phase(phase):
		_leave("debrief_phase_failed")


func _result_screen_ready(stage: int) -> void:
	if not is_instance_valid(backend) or not backend.mark_result_screen_ready(stage):
		_leave("debrief_ready_failed")


func _result_advance_requested(stage: int) -> void:
	if not is_instance_valid(backend) or not backend.request_result_advance(stage):
		_leave("debrief_advance_failed")


func _result_fade_finished() -> void:
	_result_screen_ready(3)
	if not _leaving and player == 1:
		_result_advance_requested(3)


func _clear_pause_gestures() -> void:
	_touch_flight.reset()
	_reset_touch_weapons()
	_pause_touch_finger = -1
	_pause_touch_armed = false


func _sync_pause_ui() -> void:
	if not _presentation_ready or not is_instance_valid(sim) or not is_instance_valid(backend):
		return
	var quiet: bool = backend.inputs_quiesced()
	if quiet != _quiet_input:
		_clear_pause_gestures()
		_quiet_input = quiet
	if _touch_pause_label != null:
		_touch_pause_label.visible = not backend.local_paused()
	if backend.local_paused():
		if player == 1 and backend.pause_confirmed():
			if _pause_menu == null:
				set_paused(false)
				var menu := PauseMenu.new()
				menu.name = "NetworkPauseMenu"
				menu.z_index = Z.HUD + 2
				menu.set("_touch_pause", true)
				add_child(menu)
				if not menu.open_menu(self):
					menu.queue_free()
					_leave("pause_display_failed")
					return
				_pause_menu = menu
				if _hud_vga != null:
					_hud_vga.prepare_frozen_screen(sim)
				menu.closed.connect(_network_pause_closed)
		elif _pause_menu == null and not paused:
			set_paused(true)
	elif paused:
		set_paused(false)


func _network_pause_closed(quit: bool) -> void:
	if _pause_menu != null:
		_pause_menu.queue_free()
		_pause_menu = null
	if _hud_vga != null:
		_hud_vga.release_frozen_screen()
	if quit:
		_leave()
	elif not is_instance_valid(backend) or not backend.request_resume():
		_leave("resume_failed")


func _leave(reason := "left") -> void:
	if _leaving:
		return
	_leaving = true
	disable_network_input()
	if is_instance_valid(controller):
		controller.leave_player(self, reason)


func _exit_tree() -> void:
	Music.set_volume(Music.user_volume)
	if is_instance_valid(controller):
		controller.player_scene_exited(self)
