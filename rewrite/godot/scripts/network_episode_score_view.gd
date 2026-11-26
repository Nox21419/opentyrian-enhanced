## Detached original ending score/hint page; owner supplies page agreements.
extends "res://scripts/network_story_view.gd"

const Score := preload("res://scripts/network_episode_score.gd")


func _bind_descriptor(descriptor: Dictionary, role: int) -> bool:
	return (
		descriptor.get("script") is Dictionary
		and Score.valid_script(descriptor.script)
		and super._bind_descriptor(descriptor, role)
	)


func bind_score(descriptor: Dictionary, role: int) -> bool:
	return (
		not is_inside_tree()
		and descriptor.get("script") is Dictionary
		and Score.valid_script(descriptor.script)
		and _bind_descriptor(descriptor, role)
	)


func _screen(directive: String, text: PackedStringArray) -> void:
	if _page != _script.screens.size():
		await super._screen(directive, text)
		return
	_frame_count_max = 4
	await _display_text(Score.lines(_script))
	if not _live():
		return
	await fade_black(15)
