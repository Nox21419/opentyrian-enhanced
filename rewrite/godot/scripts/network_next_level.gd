## Detached request builder. No Game writes, epoch allocation or native adoption.
## Caller must independently derive and agree the source proposal first.
extends RefCounted

const LevelConfig := preload("res://scripts/network_level_configuration.gd")
const Config := preload("res://scripts/network_configuration.gd")
const Cursor := preload("res://scripts/network_campaign_cursor.gd")
const Result := preload("res://scripts/network_level_result.gd")


static func valid_configuration(config: Variant) -> bool:
	return LevelConfig.valid(config)


static func configuration_digest(config: Dictionary) -> String:
	return LevelConfig.digest(config)


static func valid_request(request: Dictionary) -> bool:
	var fields := [
		"configuration",
		"carry",
		"bonus_level",
		"source_configuration",
		"source_result",
		"source_proposal",
		"sequence",
		"parent",
		"script",
		"entry",
		"digest"
	]
	if request.size() != fields.size():
		return false
	for field in fields:
		if not request.has(field):
			return false
	if not LevelConfig.valid(request.configuration) or not request.bonus_level is bool:
		return false
	for field in ["source_configuration", "source_result", "source_proposal", "digest"]:
		if not Config.hex_string(request[field], 64):
			return false
	if request.sequence not in [1, 2] or not request.sequence is int:
		return false
	if request.parent != "" and not Config.hex_string(request.parent, 64):
		return false
	if request.sequence == 2 and request.parent == "":
		return false
	if not request.carry is PackedInt32Array or request.carry.size() != 7:
		return false
	if (
		not Config.integer(request.carry[4], 0, 1)
		or not Config.integer(request.carry[5], 0, 255)
		or not Config.integer(request.carry[6], 0, 255)
	):
		return false
	if not request.script is Dictionary or not request.entry is Dictionary:
		return false
	if (
		request.script.get("stop") != "level"
		or request.script.get("lvl_file_num") != request.configuration.level_file
		or request.script.has("mini_game")
	):
		return false
	if not request.script.get("bonus") is bool or not request.script.get("normal_bonus") is bool:
		return false
	if request.bonus_level != (request.script.bonus or request.script.normal_bonus):
		return false
	if _pending_effects(request.script) or _pending_effects(request.entry):
		return false
	var body := request.duplicate(true)
	body.erase("digest")
	var bytes := Result.canonical_bytes(body)
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(bytes)
	return not bytes.is_empty() and hash.finish().hex_encode() == request.digest


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
