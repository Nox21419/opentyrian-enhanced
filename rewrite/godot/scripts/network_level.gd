## Presentation checkpoint only: borrows the running session's prepared native
## node. No hardware polling, simulation clock, local campaign or scene handoff.
extends "res://scripts/level.gd"

const Rules := preload("res://scripts/network_initial_configuration.gd")
var backend: Node
var player := 0
var _config := {}
var _network_level_name := ""
var _presented_tick := 0
var _bound := false
var _presentation_ready := false


## Call before adding the view to the tree. A backend is never owned by the view.
func bind(connection: Node) -> bool:
	if is_inside_tree() or _bound or not is_instance_valid(connection):
		return false
	var native: Node = connection.simulation_for_view()
	if native == null or native.tick() != 0:
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
		sim = null
		visible = false
		return false
	return true


func _backend_changed() -> void:
	_borrow_valid()


func _detach() -> void:
	sim = null
	backend = null
	visible = false


## A network view cannot use the ordinary level's direct stepping APIs.
func step_sim(_mask: int, _p2_mask := 0) -> void:
	pass


func advance(_ticks: int, _mask_at: Callable, _mouse_at := Callable()) -> void:
	pass


func _physics_process(_delta: float) -> void:
	pass


func _input(_event: InputEvent) -> void:
	pass


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
	# Role-specific controls are wired in the next clock/input checkpoint.
	pass


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
	if what == NOTIFICATION_EXIT_TREE:
		if _presented_tick > 0:
			Effects.kill_slowmo = -1.0
			Effects.shake_px = Vector2i.ZERO
		_presentation_ready = false
		sim = null
