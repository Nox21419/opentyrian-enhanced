## Shared cosmetic hint selection only. Never use this for gameplay rewards.
extends RefCounted

const Ending := preload("res://scripts/network_episode_end.gd")
const StoryData := preload("res://scripts/network_story_script.gd")
const Wire := preload("res://scripts/network_protocol.gd")


static func context(session: String) -> Dictionary:
	if not Wire.valid_session(session):
		return {}
	var value := {"session": session, "group": _choice("episode-hint-group-v1", session) + 1}
	value["digest"] = StoryData.digest(value)
	return value


static func build(
	config: Dictionary, record: Dictionary, proposal: Dictionary, history: Dictionary, session: String
) -> Dictionary:
	var ending := Ending.build(config, record, proposal, history)
	var owned_context := context(session)
	if ending.is_empty() or owned_context.is_empty():
		return {}
	var variant := _choice("episode-hint-variant-v1", owned_context.digest + ending.digest)
	var requested: int = owned_context.group + variant * 3
	var selection := select_block(ending.script.hint_blocks, owned_context.group, variant)
	if selection.is_empty():
		return {}
	var descriptor := {
		"source_plan": ending.digest,
		"context": owned_context,
		"variant": variant,
		"requested_block": requested,
		"selected_block": selection.block,
		"text": selection.text
	}
	descriptor["digest"] = StoryData.digest(descriptor)
	return descriptor


static func valid(
	descriptor: Dictionary,
	config: Dictionary,
	record: Dictionary,
	proposal: Dictionary,
	history: Dictionary,
	session: String
) -> bool:
	var expected := build(config, record, proposal, history, session)
	return not expected.is_empty() and descriptor == expected


## Original block calculation/fallback. Bounds come from the ending planner.
static func select_block(blocks: Array, group: int, variant: int) -> Dictionary:
	if group < 1 or group > 3 or variant < 0 or variant > 2 or blocks.size() > 9:
		return {}
	for block in blocks:
		if not block is PackedStringArray or block.size() > 128:
			return {}
		for line in block:
			if line.to_utf8_buffer().size() > 2048:
				return {}
	if blocks.is_empty():
		return {"block": 0, "text": PackedStringArray()}
	var block := group + variant * 3
	if block > blocks.size():
		block = 1
	return {"block": block, "text": blocks[block - 1].duplicate()}


static func _choice(domain: String, source: String) -> int:
	var hash := StoryData.digest({"domain": domain, "source": source}).hex_decode()
	return hash.decode_u32(0) % 3
