## Immutable startup configuration grammar. Application/catalog validation is
## separate and mandatory in NetworkStartup before accepting a proposal.
extends RefCounted

const FIELDS := [
	"mode",
	"episode",
	"level_file",
	"initial_difficulty",
	"difficulty",
	"seed",
	"loadout1",
	"loadout2",
	"cash1",
	"cash2",
	"devices",
	"input_delay",
	"mutators",
	"processor_type",
	"game_speed",
	"explosion_style",
	"hitstop",
	"combos",
	"dedicated_special"
]
const RANGES := {
	"episode": [1, 5],
	"level_file": [1, 65535],
	"initial_difficulty": [1, 8],
	"difficulty": [2, 9],
	"input_delay": [0, 8],
	"mutators": [0, 255],
	"processor_type": [1, 6],
	"game_speed": [1, 6],
	"explosion_style": [0, 2]
}


static func valid(config: Variant) -> bool:
	if not config is Dictionary or config.size() != FIELDS.size():
		return false
	for field in FIELDS:
		if not config.has(field):
			return false
	if config.mode != "arcade" or not config.mode is String:
		return false
	for field in RANGES:
		if not integer(config[field], RANGES[field][0], RANGES[field][1]):
			return false
	if config.initial_difficulty not in [1, 2, 3, 4, 6, 8] or config.difficulty != config.initial_difficulty + 1:
		return false
	for field in ["seed", "cash1", "cash2"]:
		if not hex_string(config[field], 16):
			return false
	for field in ["hitstop", "combos", "dedicated_special"]:
		if not config[field] is bool:
			return false
	for field in ["loadout1", "loadout2"]:
		if not config[field] is Array or config[field].size() != 10:
			return false
		for value in config[field]:
			if not integer(value, 0, 255):
				return false
		if not integer(config[field][2], 1, 11) or not integer(config[field][4], 1, 11):
			return false
	if not config.devices is Array or config.devices.size() != 2:
		return false
	for device in config.devices:
		if not integer(device, 0, 2):
			return false
	return true


static func values(config: Dictionary) -> Array:
	if not valid(config):
		return []
	var result := []
	for field in FIELDS:
		result.append(config[field])
	return result.duplicate(true)


## JSON has only floating-point numbers. Accept only exact bounded integers,
## normalize them explicitly, and retain u64 seeds/money as hexadecimal strings.
static func from_values(array: Variant) -> Dictionary:
	if not array is Array or array.size() != FIELDS.size():
		return {}
	var config := {}
	for i in FIELDS.size():
		var field: String = FIELDS[i]
		var value: Variant = array[i]
		if RANGES.has(field):
			if not wire_integer(value, RANGES[field][0], RANGES[field][1]):
				return {}
			value = int(value)
		elif field in ["loadout1", "loadout2", "devices"]:
			if not value is Array or value.size() != (2 if field == "devices" else 10):
				return {}
			value = value.duplicate()
			for j in value.size():
				if not wire_integer(value[j], 0, 255):
					return {}
				value[j] = int(value[j])
		config[field] = value
	return config if valid(config) else {}


static func digest(config: Dictionary) -> String:
	var ordered := values(config)
	return sha256(JSON.stringify(ordered)) if not ordered.is_empty() else ""


static func sha256(text: String) -> String:
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(text.to_utf8_buffer())
	return hash.finish().hex_encode()


static func integer(value: Variant, low: int, high: int) -> bool:
	return value is int and value >= low and value <= high


static func wire_integer(value: Variant, low: int, high: int) -> bool:
	return (
		(value is int or value is float)
		and is_finite(float(value))
		and value >= low
		and value <= high
		and float(value) == floorf(float(value))
	)


static func hex_string(value: Variant, length: int) -> bool:
	if not value is String or value.length() != length:
		return false
	for character in value:
		if character not in "0123456789abcdef":
			return false
	return true
