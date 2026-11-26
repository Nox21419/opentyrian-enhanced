## Live ending entry and checkpoint owner. No episode-finalization side effects.
extends "res://scripts/network_story_owner.gd"

const Score := preload("res://scripts/network_episode_score.gd")
var _ending_left := false


func _accept_proposal(proposal: Dictionary) -> bool:
	return (
		proposal.get("kind") == "episode_end"
		and proposal.get("script") is Dictionary
		and proposal.script.get("stop") == "episode_end"
	)


func _prepare_presentation(background: String) -> bool:
	return _connection.prepare_episode_score(_decision, background)


func _bind_descriptor(descriptor: Dictionary, role: int) -> bool:
	return (
		descriptor.get("script") is Dictionary
		and Score.valid_script(descriptor.script)
		and super._bind_descriptor(descriptor, role)
	)


func _screen(directive: String, text: PackedStringArray) -> void:
	if _page != _script.screens.size():
		await super._screen(directive, text)
		return
	_frame_count_max = 4
	await _display_text(Score.lines(_script))
	if _live():
		await fade_black(15)


func _input(event: InputEvent) -> void:
	if not _released and _local_finished and TyrianControls.menu_action(event) == TyrianControls.BACK:
		if not _ending_left:
			_ending_left = true
			_reported = true
			_fail("left_ending")
			failed.emit("left_ending")
	else:
		super._input(event)
