## Persistent player-menu transport, startup and first-level prototype handoff.
extends Node

signal changed

const Lobby := preload("res://scripts/lan_lobby.gd")
const Gameplay := preload("res://scripts/network_gameplay_connection.gd")
const Rules := preload("res://scripts/network_initial_configuration.gd")
const SETUP := preload("res://scripts/setup.gd")
const Clock := preload("res://scripts/network_tick_clock.gd")
const Cursor := preload("res://scripts/network_campaign_cursor.gd")
const StoryData := preload("res://scripts/network_story_script.gd")
const PLAYER_SCENE := "res://scenes/network_player.tscn"
const LOBBY_SCENE := "res://scenes/network_lobby.tscn"
const ARCADE_SCENE := "res://scenes/network_arcade_menu.tscn"
const STORY_SCENE := "res://scenes/network_story_owner.tscn"
const ENDING_SCENE := "res://scenes/network_episode_score_owner.tscn"
enum Progress { NONE, DECIDING, ARCADE, CHOOSING, LOADING, ADOPTING, STORY, ENDING_WAIT }

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
		return continuing or _proposed
var _returning := false
var _proposed := false
var _compared := false
var _stopping := false
var _setup_error := ""
var continuing := false
var _progress := Progress.NONE
var _progress_queued := false
var _progress_loading := false
var _progress_decision_requested := false
var _progress_choice_requested := false
var _progress_candidate := {}
var scene_change := Callable(Game, "goto_scene")
var current_scene := Callable(Effects, "current_game_scene")
var _progress_generation := 0
var _story_scene: Node
var _story_sequence := 0
var _story_after := Progress.NONE
var _story_done := false


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
	if continuing or not lobby.hosting or lobby.peer == null or _proposed:
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
	_release_story()
	_progress_generation += 1
	continuing = false
	_progress = Progress.NONE
	_progress_queued = false
	_progress_loading = false
	_progress_decision_requested = false
	_progress_choice_requested = false
	_progress_candidate.clear()
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
	return continuing or (lobby.peer != null and (start_requested or not lobby.hosting or _proposed))


func local_ready() -> bool:
	return is_instance_valid(backend) and backend.readiness().local


func can_ready() -> bool:
	if continuing:
		return false
	return is_instance_valid(backend) and backend.preview_matched() and not local_ready()


func can_start() -> bool:
	if continuing:
		return false
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
	if continuing:
		return "net_wait_host" if _progress == Progress.ARCADE else "net_preparing"
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
	if _leave_queued and not is_instance_valid(_player_scene):
		return
	if continuing:
		_queue_progress()
		return
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
	if not _owns_rate:
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
		_player_scene = null
		_leave_queued = true
		if is_instance_valid(backend):
			_stop_after_player_exit.call_deferred(backend.get_instance_id())


func _stop_after_player_exit(expected_backend: int) -> void:
	if (
		_leave_queued
		and not is_instance_valid(_player_scene)
		and is_instance_valid(backend)
		and backend.get_instance_id() == expected_backend
	):
		stop()


func _process(_delta: float) -> void:
	if _stopping or not is_instance_valid(backend) or not _setup_error.is_empty():
		return
	if _leave_queued and not is_instance_valid(_player_scene):
		return
	if continuing:
		_queue_progress()
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


## Called once by the old player after both final Statistics fades.
func continue_player(scene: Node) -> bool:
	if continuing or scene != _player_scene or not is_instance_valid(backend) or platform_name.call() != "Android":
		return false
	if not backend.running() or not backend.completion_agreed() or backend.result_committed_phase() != 3:
		return false
	continuing = true
	_progress_generation += 1
	_progress = Progress.DECIDING
	_progress_loading = false
	_progress_decision_requested = false
	_progress_choice_requested = false
	scene.disable_network_input()
	_queue_progress()
	return true


func continuation_menu() -> Dictionary:
	return _progress_candidate.duplicate(true) if continuing and _progress_candidate.get("kind") == "shop" else {}


func start_continuation_from_arcade() -> bool:
	if not continuing or _progress != Progress.ARCADE or not selecting_arcade or not lobby.hosting:
		return false
	selecting_arcade = false
	_progress = Progress.CHOOSING
	_returning = true
	_queue_progress()
	return true


func _queue_progress() -> void:
	if _progress_queued or not continuing or not is_instance_valid(backend):
		return
	_progress_queued = true
	_advance_progress.call_deferred(backend.get_instance_id(), _progress_generation)


func _advance_progress(expected_backend: int, generation: int) -> void:
	if (
		not continuing
		or generation != _progress_generation
		or not is_instance_valid(backend)
		or backend.get_instance_id() != expected_backend
	):
		return
	_drive_progress()
	_progress_queued = false


func _drive_progress() -> void:
	var current: Node = current_scene.call()
	if is_instance_valid(_player_scene) and current != _player_scene:
		stop()
		last_player_exit = "continuation_scene_replaced"
		return
	if (
		not is_instance_valid(_player_scene)
		and current != null
		and (
			current.scene_file_path
			not in [ARCADE_SCENE, LOBBY_SCENE, STORY_SCENE, ENDING_SCENE, "res://scenes/network_options.tscn"]
		)
	):
		stop()
		last_player_exit = "continuation_scene_replaced"
		return
	if not backend.running():
		_end_progress("continuation_disconnected")
		return
	match _progress:
		Progress.DECIDING:
			if backend.continuation_sequence() == 0:
				if _progress_decision_requested:
					return
				_progress_decision_requested = true
				var accepted: bool = (
					backend.propose_continuation(1) if lobby.hosting else backend.prepare_continuation(1)
				)
				if not accepted:
					_end_progress("continuation_decision_failed")
				return
			_progress_candidate = backend.committed_continuation(1)
			_route_candidate(1)
		Progress.ARCADE:
			if not lobby.hosting and backend.continuation_sequence() == 2:
				_progress_candidate = backend.committed_continuation(2)
				_route_candidate(2)
		Progress.CHOOSING:
			if backend.continuation_sequence() != 2:
				if _progress_choice_requested:
					return
				_progress_choice_requested = true
				if not backend.propose_continuation(2):
					_end_progress("continuation_choice_failed")
				return
			_progress_candidate = backend.committed_continuation(2)
			_route_candidate(2)
		Progress.STORY, Progress.ENDING_WAIT:
			if not is_instance_valid(_story_scene) or current != _story_scene:
				stop()
				last_player_exit = "continuation_scene_replaced"
				return
			if _progress == Progress.STORY and _story_done and backend.story_complete(_story_sequence):
				var next := _story_after
				if next == Progress.ENDING_WAIT:
					_progress = next
					last_player_exit = "episode_score_agreed"
				else:
					_release_story()
					_enter_progress(next)
		Progress.LOADING:
			var sequence: int = _progress_candidate.get("sequence", 0)
			if lobby.hosting and not _progress_loading:
				_progress_loading = true
				var seed := Crypto.new().generate_random_bytes(8).hex_encode()
				if not backend.prepare_next_level(sequence, seed):
					_end_progress("continuation_load_failed")
				return
			if lobby.hosting and backend.next_level_loaded() and not backend.next_level_load_committed():
				if not backend.commit_next_level_load():
					_end_progress("continuation_activation_failed")
				return
			if backend.next_level_load_committed():
				_progress = Progress.ADOPTING
				_replace_continuation_player()
	changed.emit()


func _route_candidate(sequence: int) -> void:
	var kind: String = _progress_candidate.get("kind", "")
	var script: Variant = _progress_candidate.get("script")
	if kind == "episode_end":
		if not script is Dictionary or script.get("stop") != "episode_end":
			_end_progress("unsupported_continuation_ending")
		else:
			_open_story(sequence, Progress.ENDING_WAIT, ENDING_SCENE)
		return
	if kind not in ["shop", "level"] or (sequence == 2 and kind != "level") or not script is Dictionary:
		_end_progress("unsupported_continuation_route")
		return
	var screens: Variant = script.get("screens", [])
	if script.get("autosave", false) != false or script.has("mini_game") or not screens is Array:
		_end_progress("unsupported_continuation_route")
		return
	var next := Progress.ARCADE if kind == "shop" else Progress.LOADING
	if screens.is_empty():
		_enter_progress(next)
		return
	if not StoryData.valid_script(script):
		_end_progress("unsupported_continuation_story")
		return
	_open_story(sequence, next, STORY_SCENE)


func ending_checkpoint() -> bool:
	return continuing and _progress == Progress.ENDING_WAIT


func _open_story(sequence: int, next: int, path: String) -> void:
	_progress = Progress.STORY
	_story_sequence = sequence
	_story_after = next
	_story_done = false
	_detach_progress_player()
	var previous: Node = current_scene.call()
	if previous != null and previous.scene_file_path == LOBBY_SCENE:
		previous.set("_handoff", true)
	if scene_change.call(path, _prepare_story) == null:
		_end_progress("continuation_story_failed")


func _enter_progress(next: int) -> void:
	_progress = next
	if next == Progress.ARCADE:
		selecting_arcade = lobby.hosting
		arcade_row = 2
		options_row = 2
	_move_progress_scene(ARCADE_SCENE if next == Progress.ARCADE and lobby.hosting else LOBBY_SCENE)


func _prepare_story(scene: Node) -> bool:
	if not scene.bind(backend, _story_sequence):
		return false
	_story_scene = scene
	scene.completed.connect(_story_completed.bind(scene.get_instance_id(), _progress_generation))
	scene.failed.connect(_story_failed.bind(scene.get_instance_id(), _progress_generation))
	return true


func _story_completed(identity: int, generation: int) -> void:
	if (
		generation == _progress_generation
		and is_instance_valid(_story_scene)
		and _story_scene.get_instance_id() == identity
	):
		_story_done = true
		_queue_progress()


func _story_failed(reason: String, identity: int, generation: int) -> void:
	_story_failure_checked.call_deferred(reason, identity, generation)


func _story_failure_checked(reason: String, identity: int, generation: int) -> void:
	if (
		generation != _progress_generation
		or not is_instance_valid(_story_scene)
		or _story_scene.get_instance_id() != identity
	):
		return
	if current_scene.call() == _story_scene:
		_end_progress(reason)


func _release_story() -> void:
	if is_instance_valid(_story_scene):
		_story_scene.release()
	_story_scene = null
	_story_sequence = 0
	_story_after = Progress.NONE
	_story_done = false


func _detach_progress_player() -> void:
	if is_instance_valid(_player_scene):
		_player_scene._detach()
	_player_scene = null


func _move_progress_scene(path: String) -> void:
	_detach_progress_player()
	var current: Node = current_scene.call()
	if current != null and current.scene_file_path == path:
		return
	if current != null and current.scene_file_path == LOBBY_SCENE:
		current.set("_handoff", true)
	_returning = path == LOBBY_SCENE
	if scene_change.call(path, Callable()) == null:
		_end_progress("continuation_scene_failed")


func _replace_continuation_player() -> void:
	_detach_progress_player()
	if platform_name.call() != "Android" or not backend.adopt_next_level():
		_end_progress("continuation_adoption_failed")
		return
	var current: Node = current_scene.call()
	if current != null and current.scene_file_path == LOBBY_SCENE:
		current.set("_handoff", true)
	selecting_arcade = false
	selecting_options = false
	if scene_change.call(PLAYER_SCENE, _prepare_player) == null:
		_end_progress("continuation_player_failed")
		return
	continuing = false
	_progress = Progress.NONE
	_progress_candidate.clear()
	_progress_loading = false
	_returning = false
	last_player_exit = "continued"
	changed.emit()


func _end_progress(reason: String) -> void:
	if not continuing:
		return
	_detach_progress_player()
	var current: Node = current_scene.call()
	if current != null and current.scene_file_path == LOBBY_SCENE:
		current.set("_handoff", true)
	stop()
	_setup_error = reason
	last_player_exit = reason
	_returning = true
	scene_change.call(LOBBY_SCENE, Callable())


func continuation_cash(player: int) -> String:
	var stats: Dictionary = _progress_candidate.get("earned", {})
	var value := int(stats.get("cash" if player == 0 else "cash2", 0))
	if value >= 0:
		return str(value)
	# Convert the unsigned native cash bits without floating point or overflow.
	var decimal := "0"
	for nibble in Cursor.unsigned_cash(value):
		var carry := "0123456789abcdef".find(nibble)
		var next := ""
		for i in range(decimal.length() - 1, -1, -1):
			var digit := int(decimal[i]) * 16 + carry
			next = str(digit % 10) + next
			carry = digit / 10
		while carry > 0:
			next = str(carry % 10) + next
			carry /= 10
		decimal = next
	return decimal


func _notification(what: int) -> void:
	if continuing and what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]:
		_end_progress_checked.call_deferred("continuation_focus_lost", _progress_generation)


func _end_progress_checked(reason: String, generation: int) -> void:
	if generation == _progress_generation:
		_end_progress(reason)


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
