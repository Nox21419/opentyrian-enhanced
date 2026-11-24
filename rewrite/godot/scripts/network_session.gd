## Persistent ownership for the reviewed connection/host-Episode menu checkpoint.
## Startup/gameplay integration is deliberately not enabled by this menu state.
extends Node

const Lobby := preload("res://scripts/lan_lobby.gd")

var lobby := Lobby.new()
var selected_episode := 0
var selected_difficulty := 0
var selecting_episode := false
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
	selected_episode = episode


func finish_difficulty_selection(difficulty: int) -> void:
	if selecting_episode and lobby.hosting and difficulty in [1, 2, 3, 4, 6, 8]:
		selected_difficulty = difficulty
	finish_episode_selection()


func stop() -> void:
	selected_episode = 0
	selected_difficulty = 0
	selecting_episode = false
	_returning = false
	lobby.close()
