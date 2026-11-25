## Borrows the prepared session. Android touch input requires explicit enable;
## the clock also requires explicit enable. No local campaign or scene handoff.
extends "res://scripts/level.gd"

const Rules := preload("res://scripts/network_initial_configuration.gd")
const TouchPolicy := preload("res://scripts/network_touch_inputs.gd")
const Wire := preload("res://scripts/network_protocol.gd")
const Clock := preload("res://scripts/network_tick_clock.gd")
signal network_tick_presented(tick: int)
var backend: Node
var player := 0
var _config := {}
var _network_level_name := ""
var _presented_tick := 0
var _bound := false
var _presentation_ready := false
var _network_input_enabled := false
var _network_clock_enabled := false
var _clock_started := false
var _tick_due := false
var _clock := Clock.new()


## Call before adding the view to the tree. A backend is never owned by the view.
func bind(connection: Node) -> bool:
	if is_inside_tree() or _bound or not is_instance_valid(connection):
		return false
	var native: Node = connection.simulation_for_view()
	if native == null or native.tick() != 0 or not native.has_method("start_network_presentation"):
		return false
	var config: Dictionary = connection.configuration()
	var rules := Rules.new(Game.data_dir)
	var level := rules.first_level(config.episode, config.initial_difficulty)
	if level.is_empty() or int(level.get("lvl_file_num", -1)) != config.level_file:
		return false
	var role: int = connection.player_for_view()
	if role not in [1, 2]:
		return false
	_bound = true
	backend = connection
	_config = config.duplicate(true)
	_network_level_name = str(level.get("level_name", ""))
	player = role
	sim = native
	backend.changed.connect(_backend_changed)
	backend.tree_exiting.connect(_detach)
	return true


func _ready() -> void:
	hotkeys = LevelHotkeys.new(self)
	_load_level()
	set_process_input(false)
	set_process_unhandled_input(false)


func _load_level() -> void:
	if not _borrow_valid():
		return
	if not sim.start_network_presentation():
		visible = false
		return
	_initialize_level_presentation(false)
	_presentation_ready = true
	set_physics_process(false)


## The later network clock calls this once after a successful backend advance.
## Repeated presentation is rejected; presentation itself never steps the core.
func present_network_tick() -> bool:
	if not _borrow_valid() or not _presentation_ready or not is_inside_tree():
		return false
	var tick: int = sim.tick()
	if tick != _presented_tick + 1:
		return false
	_present_simulation_tick()
	_refresh()
	_presented_tick = tick
	return true


func _borrow_valid() -> bool:
	if not is_instance_valid(backend) or not is_instance_valid(sim) or backend.simulation_for_view() != sim:
		disable_network_input()
		sim = null
		visible = false
		return false
	return true


func _backend_changed() -> void:
	_borrow_valid()


func _detach() -> void:
	disable_network_input()
	sim = null
	backend = null
	visible = false


## A network view cannot use the ordinary level's direct stepping APIs.
func step_sim(_mask: int, _p2_mask := 0) -> void:
	pass


func advance(_ticks: int, _mask_at: Callable, _mouse_at := Callable()) -> void:
	pass


## The session owner must set the negotiated physics rate before enabling.
## No debug override or phone-local setting can choose a different rate.
func enable_network_clock() -> bool:
	if _clock_started:
		return _network_clock_enabled
	if not _network_input_enabled or not _presentation_ready or not _borrow_valid() or sim.tick() != 0:
		return false
	var rate := Clock.ticks_per_second(_config.game_speed)
	if rate == 0 or Engine.physics_ticks_per_second != rate:
		return false
	_clock_started = true
	_network_clock_enabled = true
	_clock.reset()
	set_physics_process(true)
	return true


func disable_network_clock() -> void:
	_network_clock_enabled = false
	_tick_due = false
	_clock.reset()
	set_physics_process(false)


func _physics_process(_delta: float) -> void:
	if not _network_clock_enabled or not _borrow_valid():
		return
	if sim.level_ended() or Engine.physics_ticks_per_second != Clock.ticks_per_second(_config.game_speed):
		disable_network_input()
		return
	if not _tick_due:
		var slow: float = sim.kill_slowmo_speed()
		if not _clock.consume_tick(slow if slow > 0.0 else 1.0):
			return
		_tick_due = true
	if backend.needs_local_input() and not capture_network_input():
		return
	if backend.advance():
		if not present_network_tick():
			disable_network_input()
			return
		_tick_due = false
		network_tick_presented.emit(_presented_tick)


func enable_network_input() -> bool:
	if not _touch_pause or not _presentation_ready or not is_inside_tree() or not _borrow_valid():
		return false
	if not _network_input_enabled:
		_touch_flight.reset()
		_reset_touch_weapons()
		_network_input_enabled = true
		set_process_input(true)
		_sync_touch_weapons()
	return true


func disable_network_input() -> void:
	disable_network_clock()
	_network_input_enabled = false
	set_process_input(false)
	_touch_flight.reset()
	_reset_touch_weapons()
	_tilt_flight.calibrated = false


## Call only from the future session clock. Never consumes a later touch action
## while the backend retains the previously captured future frame.
func capture_network_input() -> bool:
	if not _network_input_enabled or not _borrow_valid() or not backend.needs_local_input():
		return false
	_sync_touch_weapons()
	var gravity := Input.get_gravity() if tilt_enabled() else Vector3.ZERO
	return backend.capture_local(_sample_network_touch(gravity))


func _sample_network_touch(gravity := Vector3.ZERO) -> Dictionary:
	var position: PackedInt32Array = sim.player(player - 1)
	var movement := Vector2i.ZERO
	if tilt_enabled():
		movement = _tilt_flight.movement(gravity, int(SetupScreen.settings.tilt_sensitivity))
	elif _touch_flight.active():
		movement = _touch_flight.movement(Vector2i(position[0], position[1]), SIM_X_TO_SCREEN)
	var frame := Wire.neutral_frame()
	frame.mouse_dx = movement.x
	frame.mouse_dy = movement.y
	frame.mouse_mask = _touch_flight.fire_mask()
	frame.mask = _touch_weapons.consume_mask() if _touch_weapons != null else 0
	if player == 1 and _config.dedicated_special:
		frame.mask |= Game.MASK_DEDICATED_SPECIAL
	return frame


func _input(event: InputEvent) -> void:
	if not _network_input_enabled or not _borrow_valid():
		return
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		_sync_touch_weapons()
		if _touch_weapons != null and _touch_weapons.feed(event):
			return
		_touch_flight.feed(event)


func _unhandled_input(_event: InputEvent) -> void:
	pass


func _mark_level_start() -> void:
	pass


func _apply_session_options() -> void:
	pass


func apply_effects() -> void:
	pass


func _ach_start() -> void:
	pass


func _ach_tick() -> void:
	pass


func _recording_started() -> void:
	pass


func _sync_touch_weapons() -> void:
	if not _network_input_enabled or not is_instance_valid(sim):
		_reset_touch_weapons()
		return
	if _touch_weapons == null:
		_touch_weapons = TouchWeapons.new()
		_touch_weapons.name = "TouchWeapons"
		_hud.add_child(_touch_weapons)
	if _hud_vga != null:
		_hud_vga.touch_layout = true
	_touch_weapons.update_state(
		TouchPolicy.controls_hud(sim.hud_state(), player, _config.dedicated_special), not sim.level_ended()
	)


func _build_touch_pause_label() -> void:
	pass


func _draw_endless_hud() -> void:
	pass


func _endless_intro_elapsed_ms() -> int:
	return 0


func _start_entry_fade() -> void:
	# A synchronized scene-start barrier must precede the live entry transition.
	pass


func _presentation_level_id() -> String:
	return "ep%d_%02d" % [_config.episode, _config.level_file]


func _presentation_level_name() -> String:
	return _network_level_name


func _presentation_loadout() -> PackedInt32Array:
	return PackedInt32Array(_config.loadout1)


func _presentation_processor_type() -> int:
	return int(_config.processor_type)


func _presentation_song() -> int:
	return Music.level_song(_config.episode, _config.level_file)


func _music_start() -> void:
	# Keep each phone's output volume local; do not write it into the core.
	_level_song = _presentation_song()
	Music.set_volume(Music.user_volume)
	Music.fade_song()
	if Music.ingame_song_override >= 0:
		Music.fade_and_play_song(Music.ingame_song_override)
	elif _level_song > 0:
		Music.fade_and_play_song(_level_song - 1)


func _notification(what: int) -> void:
	# The detached checkpoint cannot enter the ordinary campaign pause/save flow.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and _network_input_enabled:
		disable_network_input()
		if is_instance_valid(backend):
			backend.stop()
	if what == NOTIFICATION_EXIT_TREE:
		disable_network_input()
		if _presented_tick > 0:
			Effects.kill_slowmo = -1.0
			Effects.shake_px = Vector2i.ZERO
		_presentation_ready = false
		sim = null
