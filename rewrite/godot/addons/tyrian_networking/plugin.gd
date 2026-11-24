@tool
extends EditorPlugin

var _exporter := preload("res://addons/tyrian_networking/source_export.gd").new()


func _enter_tree() -> void:
	add_export_plugin(_exporter)


func _exit_tree() -> void:
	remove_export_plugin(_exporter)
