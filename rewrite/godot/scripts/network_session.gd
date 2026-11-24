## Persistent ownership for the reviewed connection/host-Episode menu checkpoint.
## Startup/gameplay integration is deliberately not enabled by this menu state.
extends Node

const Lobby := preload("res://scripts/lan_lobby.gd")

var lobby := Lobby.new()
var selected_episode := 0
var selected_difficulty := 0
var selecting_episode := false
var selecting_arcade := false
var selecting_options := false
var options_row := 2
var arcade_row := 2
var start_requested := false
var _returning := false


func _ready() -> void:
	add_child(lobby)


func enter_lobby() -> void:
	if not _returning:
		stop()
	_returning = false


func host() -> Error:
	stop()
	return lobby.host()


func join(address: String) -> Error:
	stop()
	return lobby.join(address)


func begin_episode_selection() -> bool:
	if not lobby.hosting or lobby.peer == null:
		return false
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
	selected_episode = 0
	selected_difficulty = 0
	selecting_episode = false
	selecting_arcade = false
	selecting_options = false
	options_row = 2
	arcade_row = 2
	start_requested = false
	_returning = false
	lobby.close()
