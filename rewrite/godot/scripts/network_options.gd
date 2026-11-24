## Original host-local audio Options. Campaign saves/devices stay unavailable.
extends "res://scripts/save_menu.gd"


func _ready() -> void:
	if not NetworkSession.selecting_options or not NetworkSession.lobby.hosting:
		Game.goto_scene.call_deferred("res://scenes/network_lobby.tscn")
		return
	vga.load_pic(VGA_SCREEN, 1, true)
	vga.copy(VGA_SCREEN2, VGA_SCREEN)
	_background = vga.indices(VGA_SCREEN)
	_open_options()


func _options_entry_row() -> int:
	return NetworkSession.options_row


func _unavailable_options_rows() -> Array:
	return [0, 1, 4, 5, 6]


func _remember_row(_screen: String) -> void:
	NetworkSession.options_row = menus.selection()


func _draw_status() -> void:
	for i in 2:
		vga.text_shade(
			VGA_SCREEN, 25, 50 + 10 * i, "%s 0" % TyrianText.L("miscText_%d" % (40 + i)), 15, 0, TyrianText.FULL_SHADE
		)


func _leave() -> void:
	idle = false
	var scene := (
		"res://scenes/network_arcade_menu.tscn"
		if NetworkSession.finish_options()
		else "res://scenes/network_lobby.tscn"
	)
	Game.goto_scene(scene)


func _exit_tree() -> void:
	if NetworkSession.selecting_options:
		NetworkSession.stop()
