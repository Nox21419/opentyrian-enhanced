## Detached request builder. No Game writes, epoch allocation or native adoption.
## Caller must independently derive and agree the source proposal first.
extends RefCounted

const Config := preload("res://scripts/network_configuration.gd")
const Cursor := preload("res://scripts/network_campaign_cursor.gd")
const Result := preload("res://scripts/network_level_result.gd")


static func valid_configuration(config: Variant) -> bool:
	if not config is Dictionary or not Config.integer(config.get("initial_difficulty"), 1, 8):
		return false
	if not Config.integer(config.get("difficulty"), config.initial_difficulty + 1, 9):
		return false
	var normalized: Dictionary = config.duplicate(true)
	normalized.difficulty = config.initial_difficulty + 1
	for pair in [["loadout1", 4], ["loadout2", 2]]:
		var equipment: Variant = normalized.get(pair[0])
		if not equipment is Array or equipment.size() != 10:
			return false
		if not Config.integer(equipment[pair[1]], 0, 255):
			return false
		equipment[pair[1]] = 1
	return Config.valid(normalized) and config.devices == [0, 0] and config.game_speed <= 5


static func configuration_digest(config: Dictionary) -> String:
	if not valid_configuration(config):
		return ""
	var ordered := []
	for field in Config.FIELDS:
		ordered.append(config[field])
	return Config.sha256(JSON.stringify(ordered))


## Seed is an explicit agreed input, never wall time or a local RNG draw.
static func build(previous: Dictionary, proposal: Dictionary, seed: String) -> Dictionary:
	if not valid_configuration(previous) or not Config.hex_string(seed, 16):
		return {}
	if not Config.hex_string(proposal.get("digest"), 64) or Cursor.proposal_digest(proposal) != proposal.digest:
		return {}
	if proposal.get("format_version") != 1 or proposal.get("kind") != "level":
		return {}
	if proposal.get("sequence") not in [1, 2] or not Config.hex_string(proposal.get("source_result"), 64):
		return {}
	if proposal.sequence == 2 and not Config.hex_string(proposal.get("parent"), 64):
		return {}
	if proposal.get("source_configuration") != configuration_digest(previous):
		return {}
	if proposal.get("difficulty_rule_review_required") != false:
		return {}
	if proposal.get("episode") != previous.episode or proposal.get("initial_difficulty") != previous.initial_difficulty:
		return {}
	var stats: Variant = proposal.get("earned")
	var script: Variant = proposal.get("script")
	if not stats is Dictionary or not script is Dictionary:
		return {}
	if script.get("stop") != "level" or script.has("mini_game"):
		return {}
	# Story/autosave owners are not implemented here. Never silently skip them.
	for effects in [script, proposal.get("entry", {})]:
		if not effects is Dictionary or _pending_effects(effects):
			return {}
	var carry: Variant = stats.get("carry")
	if not carry is PackedInt32Array or carry.size() != 7:
		return {}
	if (
		not Config.integer(carry[4], 0, 1)
		or not Config.integer(carry[5], 0, 255)
		or not Config.integer(carry[6], 0, 255)
	):
		return {}
	if not stats.get("cash") is int or not stats.get("cash2") is int:
		return {}
	var config := previous.duplicate(true)
	config.level_file = script.get("lvl_file_num")
	config.difficulty = proposal.get("network_difficulty")
	config.seed = seed
	config.cash1 = Cursor.unsigned_cash(stats.cash)
	config.cash2 = Cursor.unsigned_cash(stats.cash2)
	for pair in [["loadout1", "loadout"], ["loadout2", "loadout2"]]:
		var equipment: Variant = stats.get(pair[1])
		if not equipment is PackedInt32Array or equipment.size() != 11:
			return {}
		config[pair[0]] = Array(equipment.slice(0, 10))
	if not valid_configuration(config) or config.difficulty < previous.difficulty:
		return {}
	if not script.get("bonus") is bool or not script.get("normal_bonus") is bool:
		return {}
	var request := {
		"configuration": config,
		"carry": carry.duplicate(),
		"bonus_level": script.bonus or script.normal_bonus,
		"source_configuration": proposal.source_configuration,
		"source_result": proposal.source_result,
		"source_proposal": proposal.digest,
		"sequence": proposal.sequence,
		"parent": proposal.get("parent", ""),
		"script": script.duplicate(true),
		"entry": proposal.get("entry", {}).duplicate(true)
	}
	var hash := HashingContext.new()
	var bytes := Result.canonical_bytes(request)
	if bytes.is_empty():
		return {}
	hash.start(HashingContext.HASH_SHA256)
	hash.update(bytes)
	request["digest"] = hash.finish().hex_encode()
	return request


static func _pending_effects(script: Dictionary) -> bool:
	if script.get("autosave", false) != false:
		return true
	var screens: Variant = script.get("screens", [])
	if not screens is Array:
		return true
	for screen in screens:
		if not screen is Dictionary:
			return true
		var directive: Variant = screen.get("directive", "")
		if not directive is String:
			return true
		if directive.length() >= 2 and directive[1] in ["P", "W", "U", "V", "R", "C", "B", "F", "A"]:
			return true
	return false
