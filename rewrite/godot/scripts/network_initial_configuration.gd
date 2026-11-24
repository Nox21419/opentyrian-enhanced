## Initial two-player Arcade rules, separate from later campaign/save proposals.
## Reads a fresh campaign script without mutating Game or starting a level.
extends RefCounted

const Config := preload("res://scripts/network_configuration.gd")
const PLAYER1 := [11, 1, 1, 0, 1, 4, 2, 0, 0, 0]
const PLAYER2 := [1, 1, 1, 15, 1, 4, 2, 0, 0, 0]
const ZERO_CASH := "0000000000000000"

var _campaign: RefCounted


func _init(data_dir: String) -> void:
	if ClassDB.class_exists("TyrianCampaign"):
		_campaign = ClassDB.instantiate("TyrianCampaign")
		_campaign.load(data_dir)


## Read-only preview of the default shop destination. The entry result remains
## attached: validation is never permission to skip its shop/story effects.
func first_level(episode: int, initial_difficulty: int) -> Dictionary:
	if (
		_campaign == null
		or episode < 1
		or episode > 5
		or initial_difficulty not in [1, 2, 3, 4, 6, 8]
		or not _campaign.episode_available(episode)
	):
		return {}
	var result: Dictionary = _campaign.run_script(episode, 1, initial_difficulty, PLAYER1[0], true, 0, true, 0)
	var entry := result.duplicate(true)
	if result.get("stop") == "shop":
		var map: PackedInt32Array = result.get("map", PackedInt32Array())
		if not map.is_empty() and (map.size() < 2 or map.size() % 2 != 0):
			return {}
		# shop.gd's Arcade Start Level passes the last map choice, unlike the
		# Full Game shop's default choice. Preserve that existing path.
		var section := int(result.get("section", 0)) + 1 if map.is_empty() else int(map[map.size() - 1])
		result = _campaign.run_script(episode, section, initial_difficulty, PLAYER1[0], true, 0, true, 0)
	if result.get("stop") != "level" or result.has("mini_game"):
		return {}
	result["entry"] = entry
	return result.duplicate(true)


func valid(config: Dictionary) -> bool:
	if not Config.valid(config):
		return false
	# Match new_game.gd MODE_2P_ARCADE exactly. Mod starter overrides are not
	# applied by that path; progression equipment belongs to a later policy.
	if config.loadout1 != PLAYER1 or config.loadout2 != PLAYER2:
		return false
	if config.cash1 != ZERO_CASH or config.cash2 != ZERO_CASH:
		return false
	# The scoped two-phone touch/mouse adaptation has two mouse-capable devices.
	# Other input assignments require their own input-range validation.
	if config.devices != [0, 0]:
		return false
	var level := first_level(config.episode, config.initial_difficulty)
	return not level.is_empty() and config.level_file == level.get("lvl_file_num", -1)
