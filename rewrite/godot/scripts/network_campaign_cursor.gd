## Detached continuation proposals from an initial Arcade level's agreed result.
## No live adoption, simulation loading, Game mutation, menus or save writes.
extends RefCounted

const Config := preload("res://scripts/network_configuration.gd")
const LevelConfig := preload("res://scripts/network_level_configuration.gd")
const Rules := preload("res://scripts/network_initial_configuration.gd")
const Result := preload("res://scripts/network_level_result.gd")
const Wire := preload("res://scripts/network_protocol.gd")
const STOPS := ["level", "shop", "episode_end", "title", "eof"]
var error := ""
var _rules: RefCounted
var _campaign: RefCounted
var _config := {}
var _level := {}
var _proposal := {}
var _arcade_preview := {}
var _continuation := false


func _init(data_dir: String) -> void:
	_rules = Rules.new(data_dir)
	# Use the same parsed script snapshot as initial validation, not a second
	# disk read that could disagree with its level/entry metadata.
	_campaign = _rules.get("_campaign")


func begin(config: Dictionary) -> bool:
	if not error.is_empty() or not _config.is_empty() or _campaign == null or not _rules.valid(config):
		return _fail("invalid_campaign_start")
	_level = _rules.first_level(config.episode, config.initial_difficulty)
	if _level.is_empty():
		return _fail("missing_campaign_start")
	_config = config.duplicate(true)
	return true


## Caller supplies the locally derived script from its agreed owned request.
## This is context adoption only: no native loading or script effects.
func begin_continuation(config: Dictionary, script: Dictionary, entry: Dictionary) -> bool:
	if not error.is_empty() or not _config.is_empty() or _campaign == null or not LevelConfig.valid(config):
		return _fail("invalid_campaign_continuation")
	if script.get("stop") != "level" or script.get("lvl_file_num") != config.level_file or script.has("mini_game"):
		return _fail("invalid_campaign_continuation")
	if not Config.integer(script.get("next_level"), 1, 65535):
		return _fail("invalid_campaign_continuation")
	_config = config.duplicate(true)
	_level = script.duplicate(true)
	_level["entry"] = entry.duplicate(true)
	_continuation = true
	return true


## Caller must first agree this locally captured record through completion.
## Recompute its hash: a claimed digest is never permission to trust a payload.
func completed(record: Dictionary) -> Dictionary:
	if not error.is_empty() or _config.is_empty():
		return {}
	if not _valid_record(record):
		_fail("invalid_campaign_result")
		return {}
	if not _proposal.is_empty():
		if _proposal.source_result != record.digest:
			_fail("conflicting_campaign_result")
			return {}
		return _proposal.duplicate(true)
	var stats: Dictionary = record.stats
	var checkpoint := int(_level.get("save_level", -1))
	if checkpoint <= 0:
		checkpoint = int(_level.entry.section) if _level.entry.get("stop") == "shop" else 1
	var proposal := {
		"format_version": 1,
		"sequence": 1,
		"source_configuration": record.config,
		"source_result": record.digest,
		"episode": _config.episode,
		"initial_difficulty": _config.initial_difficulty,
		"local_difficulty": _config.difficulty,
		"network_difficulty": _config.difficulty,
		"requires_loader_adaptation": true,
		"difficulty_rule_review_required": false,
		"earned": stats.duplicate(true),
		"source_level": _level.duplicate(true),
		"retry_checkpoint": {"section": checkpoint, "configuration": _config.duplicate(true)},
		"kind": "retry_required",
		"next_section": checkpoint,
		"script": {}
	}
	var bonus := bool(_level.get("bonus", false)) or bool(_level.get("normal_bonus", false))
	if stats.any_player_alive or bonus:
		var section := int(_level.next_level)
		if stats.bonus_level and stats.next_level > 0:
			section = stats.next_level
		proposal.next_section = section
		# Keep the local reference for auditing; the approved network rule uses
		# combined unsigned cash and the original two-player thresholds.
		proposal.local_difficulty = _campaign.adjust_difficulty(
			_config.difficulty, _config.initial_difficulty, stats.total_score
		)
		if not _campaign.has_method("adjust_network_two_player_difficulty"):
			_fail("native_rebuild_required")
			return {}
		proposal.network_difficulty = _campaign.adjust_network_two_player_difficulty(
			_config.difficulty, _config.initial_difficulty, unsigned_cash(stats.cash), unsigned_cash(stats.cash2)
		)
		if not Config.integer(proposal.network_difficulty, _config.difficulty, 9):
			_fail("invalid_network_difficulty")
			return {}
		proposal.script = _read_section(section, stats)
		if not STOPS.has(proposal.script.get("stop")):
			_fail("unsupported_campaign_stop")
			return {}
		proposal.kind = proposal.script.stop
	_proposal = _seal(proposal)
	return _proposal.duplicate(true)


## Read-only original Arcade Start choice. Keep all entry effects attached;
## selecting this preview is not permission to skip story or prepare a level.
func preview_arcade_start(expected_digest: String) -> Dictionary:
	if not error.is_empty():
		return {}
	if _proposal.is_empty() or _proposal.kind != "shop" or expected_digest != _proposal.digest:
		_fail("invalid_arcade_continuation")
		return {}
	if not _arcade_preview.is_empty():
		return _arcade_preview.duplicate(true)
	var map: PackedInt32Array = _proposal.script.get("map", PackedInt32Array())
	if map.size() % 2 != 0:
		_fail("invalid_arcade_map")
		return {}
	var section := int(_proposal.script.section) + 1 if map.is_empty() else int(map[map.size() - 1])
	var script := _read_section(section, _proposal.earned)
	if not STOPS.has(script.get("stop")):
		_fail("unsupported_campaign_stop")
		return {}
	var proposal := _proposal.duplicate(true)
	proposal.erase("digest")
	proposal["parent"] = expected_digest
	proposal["action"] = "arcade_start"
	proposal.sequence = 2
	proposal["entry"] = _proposal.script.duplicate(true)
	proposal.script = script
	proposal.kind = script.stop
	proposal.next_section = section
	_arcade_preview = _seal(proposal)
	return _arcade_preview.duplicate(true)


func _read_section(section: int, stats: Dictionary) -> Dictionary:
	if not Config.integer(section, 1, 65535):
		return {}
	return (
		_campaign
		. run_script(
			_config.episode,
			section,
			_config.initial_difficulty,
			stats.loadout[0],
			stats.all_players_alive,
			stats.cube_max,
			true,
			0
		)
		. duplicate(true)
	)


func _valid_record(record: Dictionary) -> bool:
	var fields := ["tick", "config", "core", "stats", "digest"]
	if record.size() != fields.size():
		return false
	for key in fields:
		if not record.has(key):
			return false
	var digest := LevelConfig.digest(_config) if _continuation else Config.digest(_config)
	if record.config != digest or not Config.hex_string(record.core, 64):
		return false
	if not Config.integer(record.tick, 1, Wire.MAX_TICK) or not Config.hex_string(record.digest, 64):
		return false
	var body := record.duplicate(true)
	body.erase("digest")
	if _hash(body) != record.digest or not record.stats is Dictionary:
		return false
	var stats: Dictionary = record.stats
	for key in ["cash", "cash2", "total_score", "cube_max", "next_level"]:
		if not stats.get(key) is int:
			return false
	for key in ["all_players_alive", "any_player_alive", "bonus_level"]:
		if not stats.get(key) is bool:
			return false
	if stats.all_players_alive and not stats.any_player_alive:
		return false
	# The native raw counter is a wrapping u8. run_script performs its existing
	# 0..4 clamp; preserve the original raw value rather than adding a new rule.
	if not Config.integer(stats.cube_max, 0, 255) or not Config.integer(stats.next_level, 0, 65535):
		return false
	for key in ["loadout", "loadout2"]:
		if not stats.get(key) is PackedInt32Array or stats[key].size() != 11:
			return false
		for i in 10:
			if not Config.integer(stats[key][i], 0, 255):
				return false
	if not stats.get("carry") is PackedInt32Array or stats.carry.size() != 7:
		return false
	return (
		Config.integer(stats.carry[4], 0, 1)
		and Config.integer(stats.carry[5], 0, 255)
		and Config.integer(stats.carry[6], 0, 255)
		and Config.integer(stats.get("lives"), 0, 255)
	)


func _seal(proposal: Dictionary) -> Dictionary:
	var digest := _hash(proposal)
	if digest.is_empty():
		_fail("unhashable_campaign_proposal")
		return {}
	proposal["digest"] = digest
	return proposal


static func proposal_digest(proposal: Dictionary) -> String:
	var body := proposal.duplicate(true)
	body.erase("digest")
	return _hash(body)


## Native exposes u64 cash through signed Variant integers. Preserve its bits.
static func unsigned_cash(value: int) -> String:
	var bytes := PackedByteArray()
	bytes.resize(8)
	bytes.encode_s64(0, value)
	bytes.reverse()
	return bytes.hex_encode()


static func _hash(value: Dictionary) -> String:
	var bytes := Result.canonical_bytes(value)
	if bytes.is_empty():
		return ""
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(bytes)
	return hash.finish().hex_encode()


func _fail(reason: String) -> bool:
	error = reason
	return false
