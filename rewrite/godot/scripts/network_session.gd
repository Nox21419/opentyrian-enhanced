## Persistent player-menu transport, startup and first-level prototype handoff.
extends Node

signal changed

const Lobby := preload("res://scripts/lan_lobby.gd")
const Gameplay := preload("res://scripts/network_gameplay_connection.gd")
const Rules := preload("res://scripts/network_initial_configuration.gd")
const SETUP := preload("res://scripts/setup.gd")
const Clock := preload("res://scripts/network_tick_clock.gd")
const PLAYER_SCENE := "res://scenes/network_player.tscn"
const LOBBY_SCENE := "res://scenes/network_lobby.tscn"

var lobby := Lobby.new()
var selected_episode := 0
var selected_difficulty := 0
var selecting_episode := false
var selecting_arcade := false
var selecting_options := false
var options_row := 2
var arcade_row := 2
var start_requested := false
var backend: Node
var platform_name := Callable(OS, "get_name")
var last_player_exit := ""
var _player_scene: Node
var _handoff_queued := false
var _leave_queued := false
var _owns_rate := false
var _previous_rate := 35
var configuration_locked: bool:
	get:
		return _proposed
var _returning := false
var _proposed := false
var _compared := false
var _stopping := false
var _setup_error := ""


func _ready() -> void:
	add_child(lobby)


func enter_lobby() -> void:
	if not _returning:
		stop()
	_returning = false


func host() -> Error:
	stop()
	var result := _bind_backend()
	if result != OK:
		return result
	return lobby.host()


func join(address: String) -> Error:
	stop()
	var result := _bind_backend()
	if result != OK:
		return result
	return lobby.join(address)


func _bind_backend() -> Error:
	if Mods.api == null:
		_setup_error = "native_unavailable"
		return ERR_UNAVAILABLE
	backend = Gameplay.new()
	add_child(backend)
	backend.changed.connect(_backend_changed)
	var enabled := {}
	for mod in Mods.api.list(1):
		enabled[mod.folder] = bool(mod.enabled)
	var result: int = backend.adopt_lobby(lobby, Game.data_dir, Mods.dirs(), enabled)
	if result != OK:
		_setup_error = backend.error
		lobby.close()
	return result


func begin_episode_selection() -> bool:
	if not lobby.hosting or lobby.peer == null or _proposed:
		return false
	start_requested = false
	selecting_episode = true
	return true


func finish_episode_selection(episode := 0) -> void:
	if lobby.hosting and episode >= 1 and episode <= 5:
		selected_episode = episode
	elif not lobby.hosting:
		selected_episode = 0
		selected_difficulty = 0
	selecting_episode = false
	_returning = true


func choose_episode(episode: int) -> void:
	if not selecting_episode or not lobby.hosting or episode < 1 or episode > 5:
		return
	if selected_episode != episode:
		selected_difficulty = 0
		start_requested = false
	selected_episode = episode


func finish_difficulty_selection(difficulty: int) -> void:
	if selecting_episode and lobby.hosting and difficulty in [1, 2, 3, 4, 6, 8]:
		selected_difficulty = difficulty
		start_requested = false
	finish_episode_selection()


func begin_arcade_menu() -> bool:
	if not lobby.hosting or lobby.peer == null or selected_episode == 0 or selected_difficulty == 0:
		return false
	selecting_arcade = true
	arcade_row = 2
	options_row = 2
	return true


func finish_arcade_menu() -> void:
	if not lobby.hosting:
		stop()
		_returning = true
		return
	start_requested = lobby.hosting and selecting_arcade
	selecting_arcade = false
	_returning = true


func begin_options() -> bool:
	if not selecting_arcade or not lobby.hosting or lobby.peer == null:
		return false
	selecting_arcade = false
	selecting_options = true
	arcade_row = 5
	return true


func finish_options() -> bool:
	if not selecting_options or not lobby.hosting or lobby.peer == null:
		stop()
		_returning = true
		return false
	selecting_options = false
	selecting_arcade = true
	return true


func stop() -> void:
	_stopping = true
	if is_instance_valid(_player_scene):
		_player_scene.disable_network_input()
	_player_scene = null
	_handoff_queued = false
	_leave_queued = false
	if _owns_rate:
		Engine.physics_ticks_per_second = _previous_rate
		_owns_rate = false
	if is_instance_valid(backend):
		backend.stop()
		backend.free()
	backend = null
	selected_episode = 0
	selected_difficulty = 0
	selecting_episode = false
	selecting_arcade = false
	selecting_options = false
	options_row = 2
	arcade_row = 2
	start_requested = false
	_returning = false
	_proposed = false
	_compared = false
	_setup_error = ""
	lobby.close()
	_stopping = false
	changed.emit()


func ready_screen() -> bool:
	return lobby.peer != null and (start_requested or not lobby.hosting or _proposed)


func local_ready() -> bool:
	return is_instance_valid(backend) and backend.readiness().local


func can_ready() -> bool:
	return is_instance_valid(backend) and backend.preview_matched() and not local_ready()


func can_start() -> bool:
	return (
		lobby.hosting
		and is_instance_valid(backend)
		and backend.readiness().local
		and backend.readiness().remote
		and not backend.running()
	)


func confirm_ready() -> bool:
	return can_ready() and backend.confirm_ready()


func start_game() -> bool:
	return can_start() and backend.start()


func status_key() -> String:
	if not _setup_error.is_empty():
		if _setup_error in ["native_mismatch", "client_mismatch", "engine_mismatch"]:
			return "net_incompatible"
		return "net_content_mismatch" if _setup_error == "content_mismatch" else "net_setup_failed"
	if not is_instance_valid(backend) or not lobby.connected:
		return lobby.status_key
	if backend.running():
		return "net_session_prepared"
	if local_ready():
		return "net_wait_start" if backend.readiness().remote else "net_ready_wait"
	if backend.preview_matched():
		return "net_ready_prompt"
	if backend.agreed():
		return "net_preparing"
	return "net_wait_host" if backend.compatible() else "net_checking"


func _backend_changed() -> void:
	if _stopping or not is_instance_valid(backend):
		return
	if not backend.error.is_empty():
		_setup_error = backend.error
	var config: Dictionary = backend.configuration()
	if not config.is_empty():
		selected_episode = config.episode
		selected_difficulty = config.initial_difficulty
	changed.emit()
	if is_instance_valid(_player_scene):
		if not backend.running():
			leave_player(_player_scene, backend.error if not backend.error.is_empty() else "session_closed")
	elif backend.running() and not _handoff_queued:
		_handoff_queued = true
		_open_player.call_deferred(backend.get_instance_id())


func _open_player(expected_backend: int) -> void:
	if not is_instance_valid(backend) or backend.get_instance_id() != expected_backend:
		return
	_handoff_queued = false
	if _stopping or not backend.running() or is_instance_valid(_player_scene):
		return
	var previous := Effects.current_game_scene()
	if previous == null or previous.scene_file_path != LOBBY_SCENE or platform_name.call() != "Android":
		_setup_error = "unsupported_player_handoff"
		backend.stop()
		return
	previous.set("_handoff", true)
	var scene := Game.goto_scene(PLAYER_SCENE, _prepare_player)
	if scene == null:
		previous.set("_handoff", false)
		_setup_error = "player_handoff_failed"
		backend.stop()
		changed.emit()


func _prepare_player(scene: Node) -> bool:
	var config: Dictionary = backend.configuration()
	var rate := Clock.ticks_per_second(config.game_speed)
	if rate == 0 or not scene.bind(backend):
		return false
	scene.controller = self
	scene.use_entry_fade = true
	scene.set("_touch_pause", true)
	_previous_rate = Engine.physics_ticks_per_second
	_owns_rate = true
	Engine.physics_ticks_per_second = rate
	_player_scene = scene
	return true


func leave_player(scene: Node, reason := "left") -> void:
	if _leave_queued or not is_instance_valid(_player_scene) or scene != _player_scene:
		return
	_leave_queued = true
	last_player_exit = reason
	scene.disable_network_input()
	_return_to_lobby.call_deferred(scene.get_instance_id())


func _return_to_lobby(expected_scene: int) -> void:
	if not is_instance_valid(_player_scene) or _player_scene.get_instance_id() != expected_scene:
		return
	stop()
	_returning = true
	Game.goto_scene(LOBBY_SCENE)


func player_scene_exited(scene: Node) -> void:
	if is_instance_valid(_player_scene) and scene == _player_scene:
		last_player_exit = "scene_replaced"
		stop()


func _process(_delta: float) -> void:
	if _stopping or not is_instance_valid(backend) or not _setup_error.is_empty():
		return
	if lobby.hosting and start_requested and not _proposed and backend.compatible():
		_proposed = true
		var config := _build_configuration()
		var session := Crypto.new().generate_random_bytes(16).hex_encode()
		if config.is_empty() or not backend.propose(config, session, 1):
			_setup_error = backend.error if not backend.error.is_empty() else "configuration_rejected"
			backend.stop()
			changed.emit()
			return
	if not _compared and backend.agreed():
		_compared = true
		if not backend.compare_preview():
			_setup_error = backend.error if not backend.error.is_empty() else "preview_failed"
		changed.emit()


func _build_configuration() -> Dictionary:
	var preview := Rules.new(Game.data_dir).first_level(selected_episode, selected_difficulty)
	if preview.is_empty():
		return {}
	return {
		"mode": "arcade",
		"episode": selected_episode,
		"level_file": preview.lvl_file_num,
		"initial_difficulty": selected_difficulty,
		"difficulty": selected_difficulty + 1,
		"seed": Crypto.new().generate_random_bytes(8).hex_encode(),
		"loadout1": Rules.PLAYER1.duplicate(),
		"loadout2": Rules.PLAYER2.duplicate(),
		"cash1": Rules.ZERO_CASH,
		"cash2": Rules.ZERO_CASH,
		"devices": [0, 0],
		"input_delay": 3,
		"mutators": Game.mutators,
		"processor_type": Game.processor_type,
		"game_speed": int(SETUP.settings.game_speed),
		"explosion_style": int(SETUP.settings.explosion_style),
		"hitstop": bool(SETUP.settings.hitstop_enabled),
		"combos": Game.combos_enabled,
		"dedicated_special": true,
		"particles": bool(SETUP.settings.particles_enabled),
		"screenshake": bool(SETUP.settings.screenshake_enabled),
	}
