## Read-only final result, captured after the last network presentation boundary.
## No native setters, local campaign writes, presentation draining or wire decode.
extends RefCounted

const Config := preload("res://scripts/network_configuration.gd")
const LevelConfig := preload("res://scripts/network_level_configuration.gd")
var error := ""
var _record := {}


func capture(native: Node, config: Dictionary, level_name: String, presented_tick: int, continuation := false) -> bool:
	_record.clear()
	error = ""
	if not is_instance_valid(native) or not (LevelConfig.valid(config) if continuation else Config.valid(config)):
		return _fail("invalid_result_context")
	if not native.level_ended() or native.tick() != presented_tick or presented_tick < 1:
		return _fail("result_not_at_final_boundary")
	var before: String = native.network_diagnostic_digest()
	if not Config.hex_string(before, 64):
		return _fail("invalid_result_diagnostic")
	# Mirror level.gd's local _finished_level_stats, retaining native loadout2,
	# exact 64-bit cash bit patterns and the existing seven-value carry payload.
	var stats: Dictionary = native.level_stats().duplicate(true)
	stats["cash"] = int(native.player_dict(0).get("cash", 0))
	stats["cash2"] = int(native.player_dict(1).get("cash", 0))
	stats["carry"] = native.campaign_carry()
	stats["level_name"] = level_name
	if not stats.has("any_player_alive"):
		stats["any_player_alive"] = (
			bool(stats.get("all_players_alive", true)) or (native.player(1).size() > 4 and native.player(1)[4] != 0)
		)
	if native.tick() != presented_tick or native.network_diagnostic_digest() != before:
		return _fail("result_read_changed_simulation")
	var digest := LevelConfig.digest(config) if continuation else Config.digest(config)
	var record := {"tick": presented_tick, "config": digest, "core": before, "stats": stats}
	var bytes := canonical_bytes(record)
	if bytes.is_empty():
		return _fail("invalid_result_values")
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(bytes)
	record["digest"] = hash.finish().hex_encode()
	_record = record.duplicate(true)
	return true


func record() -> Dictionary:
	return _record.duplicate(true)


## Local hashing only. No Variant deserialization or remote result payloads.
## Fixed tags/lengths and sorted keys preserve integer bits and dictionary order.
static func canonical_bytes(value: Variant, depth := 0) -> PackedByteArray:
	if depth > 8:
		return PackedByteArray()
	var bytes := PackedByteArray()
	if value is bool:
		return PackedByteArray([1, int(value)])
	if value is int:
		bytes.resize(9)
		bytes[0] = 2
		bytes.encode_s64(1, value)
		return bytes
	if value is String:
		bytes = value.to_utf8_buffer()
		if bytes.size() > 4096:
			return PackedByteArray()
		return _header(3, bytes.size()) + bytes
	if value is Dictionary:
		var keys: Array = value.keys()
		if keys.size() > 128:
			return PackedByteArray()
		for key in keys:
			if not key is String:
				return PackedByteArray()
		keys.sort()
		bytes = _header(4, keys.size())
		for key in keys:
			var item := canonical_bytes(value[key], depth + 1)
			var key_bytes := canonical_bytes(key, depth + 1)
			if item.is_empty() or key_bytes.is_empty():
				return PackedByteArray()
			bytes.append_array(key_bytes)
			bytes.append_array(item)
			if bytes.size() > 65536:
				return PackedByteArray()
	elif value is Array or value is PackedInt32Array or value is PackedInt64Array or value is PackedStringArray:
		if value.size() > 128:
			return PackedByteArray()
		bytes = _header(5, value.size())
		for entry in value:
			var item := canonical_bytes(entry, depth + 1)
			if item.is_empty():
				return PackedByteArray()
			bytes.append_array(item)
			if bytes.size() > 65536:
				return PackedByteArray()
	else:
		return PackedByteArray()
	return bytes if bytes.size() <= 65536 else PackedByteArray()


static func _header(tag: int, count: int) -> PackedByteArray:
	var bytes := PackedByteArray()
	bytes.resize(5)
	bytes[0] = tag
	bytes.encode_u32(1, count)
	return bytes


func _fail(reason: String) -> bool:
	error = reason
	return false
