## Bounded original ending presentation, with no finalization side effects.
extends RefCounted

const Ending := preload("res://scripts/network_episode_end.gd")
const Hint := preload("res://scripts/network_episode_hint.gd")
const StoryData := preload("res://scripts/network_story_script.gd")
const Config := preload("res://scripts/network_configuration.gd")
const Story := preload("res://scripts/story_screens.gd")


static func build(
	config: Dictionary, record: Dictionary, proposal: Dictionary, history: Dictionary, session: String
) -> Dictionary:
	var ending := Ending.build(config, record, proposal, history)
	var hint := Hint.build(config, record, proposal, history, session)
	if ending.is_empty() or hint.is_empty() or ending.script.get("autosave", false):
		return {}
	if ending.script.screens.size() >= StoryData.MAX_PAGES:
		return {}
	var script: Dictionary = ending.script.duplicate(true)
	script.stop = "shop"  # Presentation envelope only, never a continuation.
	script["episode_score"] = {
		"ending": ending.digest, "hint": hint.digest, "cash": ending.cash.duplicate(), "mutators": config.mutators
	}
	# M is context-neutral. Only the score view interprets this final marker.
	script.screens.append({"directive": "]M", "text": hint.text.duplicate()})
	return script if valid_script(script) else {}


static func valid_script(script: Dictionary) -> bool:
	if not StoryData.valid_script(script) or script.screens.is_empty() or not script.get("episode_score") is Dictionary:
		return false
	var values: Dictionary = script.episode_score
	if (
		values.size() != 4
		or not Config.hex_string(values.get("ending"), 64)
		or not Config.hex_string(values.get("hint"), 64)
	):
		return false
	if (
		not values.get("cash") is Array
		or values.cash.size() != 2
		or not Config.integer(values.get("mutators"), 0, 0x7fffffff)
	):
		return false
	for cash in values.cash:
		if not Config.hex_string(cash, 16):
			return false
	return script.screens.back().directive == "]M"


static func lines(script: Dictionary) -> PackedStringArray:
	if not valid_script(script):
		return PackedStringArray()
	var result := PackedStringArray()
	for i in 2:
		result.append("%s %s" % [TyrianText.L("miscText_%d" % (48 + i)), decimal(script.episode_score.cash[i])])
	result.append(Story.mutator_notice(script.episode_score.mutators))
	result.append_array(script.screens.back().text)
	return result.slice(0, 14)


static func decimal(bits: String) -> String:
	if not Config.hex_string(bits, 16):
		return ""
	var result := "0"
	for nibble in bits:
		var carry := "0123456789abcdef".find(nibble)
		var next := ""
		for i in range(result.length() - 1, -1, -1):
			var digit := int(result[i]) * 16 + carry
			next = str(digit % 10) + next
			carry = digit / 10
		while carry > 0:
			next = str(carry % 10) + next
			carry /= 10
		result = next
	return result
