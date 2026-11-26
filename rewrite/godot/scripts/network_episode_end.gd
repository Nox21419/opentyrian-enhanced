## Read-only ending ownership ledger. This is not permission to execute effects.
extends RefCounted

const Config := preload("res://scripts/network_configuration.gd")
const LevelConfig := preload("res://scripts/network_level_configuration.gd")
const Cursor := preload("res://scripts/network_campaign_cursor.gd")
const StoryData := preload("res://scripts/network_story_script.gd")
const Wire := preload("res://scripts/network_protocol.gd")


static func build(config: Dictionary, record: Dictionary, proposal: Dictionary, history: Dictionary) -> Dictionary:
	if not LevelConfig.valid(config) or not _history_valid(history):
		return {}
	if (
		record.size() != 5
		or not Config.integer(record.get("tick"), 1, Wire.MAX_TICK)
		or not Config.hex_string(record.get("core"), 64)
	):
		return {}
	if record.get("config") != LevelConfig.digest(config) or not Config.hex_string(record.get("digest"), 64):
		return {}
	var body := record.duplicate(true)
	body.erase("digest")
	if StoryData.digest(body) != record.digest or not record.get("stats") is Dictionary:
		return {}
	if (
		proposal.get("format_version") != 1
		or proposal.get("kind") != "episode_end"
		or not Config.integer(proposal.get("sequence"), 1, 2)
	):
		return {}
	if proposal.get("source_result") != record.digest or proposal.get("source_configuration") != record.config:
		return {}
	if proposal.get("episode") != config.episode or proposal.get("initial_difficulty") != config.initial_difficulty:
		return {}
	if (
		not Config.hex_string(proposal.get("digest"), 64)
		or proposal.digest != Cursor.proposal_digest(proposal)
		or proposal.get("earned") != record.stats
	):
		return {}
	if proposal.sequence == 2 and not Config.hex_string(proposal.get("parent"), 64):
		return {}
	var script: Variant = proposal.get("script")
	if not script is Dictionary or not _script_valid(script, config.episode):
		return {}
	for field in ["cash", "cash2"]:
		if not record.stats.get(field) is int:
			return {}
	var wrap: bool = script.jump_back_to_episode1
	var plan := {
		"format_version": 1,
		"source_configuration": record.config,
		"source_result": record.digest,
		"source_proposal": proposal.digest,
		"sequence": proposal.sequence,
		"parent": proposal.get("parent", ""),
		"episode": config.episode,
		"history": history.duplicate(true),
		"script": script.duplicate(true),
		"cash": [Cursor.unsigned_cash(record.stats.cash), Cursor.unsigned_cash(record.stats.cash2)],
		"presentation":
		(
			["script", "score_hint", "credits", "next_episode"]
			if wrap and config.episode > 2
			else ["script", "score_hint", "next_episode"]
		),
		"effects":
		{
			"applied": false,
			"completed_names": true,
			"episode_achievement": true,
			"high_score_check": config.episode == history.initial_episode and not history.repeated,
			"hint_context_required": true,
			"hint_random_choice_required": true,
			"set_repeated": wrap,
			"super_carrot_random_choice_required": wrap,
			"next_episode": script.next_episode,
			"next_section": 1,
			"autosave_pending": script.get("autosave", false)
		}
	}
	plan["digest"] = StoryData.digest(plan)
	return plan if not plan.digest.is_empty() else {}


static func valid(
	plan: Dictionary, config: Dictionary, record: Dictionary, proposal: Dictionary, history: Dictionary
) -> bool:
	var expected := build(config, record, proposal, history)
	return not expected.is_empty() and plan == expected


static func _history_valid(history: Dictionary) -> bool:
	return (
		history.size() == 2 and Config.integer(history.get("initial_episode"), 1, 5) and history.get("repeated") is bool
	)


static func _script_valid(script: Dictionary, episode: int) -> bool:
	if script.get("stop") != "episode_end" or not Config.integer(script.get("section"), 1, 65535):
		return false
	if not Config.integer(script.get("next_episode"), 1, 5) or not script.get("jump_back_to_episode1") is bool:
		return false
	if script.jump_back_to_episode1:
		if script.next_episode != 1:
			return false
	elif script.next_episode <= episode:
		return false
	# Validate the same bounded display grammar without granting it a live owner.
	var display := script.duplicate(true)
	display.stop = "shop"
	display["autosave"] = false
	if not StoryData.valid_script(display) or not script.get("autosave", false) is bool:
		return false
	var blocks: Variant = script.get("hint_blocks")
	if not blocks is Array or blocks.size() > 9:
		return false
	for block in blocks:
		if not block is PackedStringArray or block.size() > 128:
			return false
		for line in block:
			if line.to_utf8_buffer().size() > 2048:
				return false
	return true
