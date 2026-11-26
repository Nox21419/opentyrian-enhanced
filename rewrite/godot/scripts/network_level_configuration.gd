## Continuation-only grammar. Initial startup validation remains separate.
extends RefCounted

const Config := preload("res://scripts/network_configuration.gd")


static func valid(config: Variant) -> bool:
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


static func digest(config: Dictionary) -> String:
	if not valid(config):
		return ""
	var ordered := []
	for field in Config.FIELDS:
		ordered.append(config[field])
	return Config.sha256(JSON.stringify(ordered))
