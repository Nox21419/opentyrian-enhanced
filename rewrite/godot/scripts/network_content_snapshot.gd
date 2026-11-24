## Session-owned resolved content. No changes to Mods, preferences or Game.
## Capture before negotiation; verify again before/after preparing a level.
extends RefCounted

const Config := preload("res://scripts/network_configuration.gd")

var error := ""
var digest := ""
var _api: RefCounted
var _data_dir := ""
var _dirs := PackedStringArray()
var _enabled := {}
var _episode := 0


func capture(data_dir: String, dirs: PackedStringArray, enabled: Dictionary, episode: int) -> bool:
	clear()
	if episode < 1 or episode > 5:
		return _fail("invalid_episode")
	for folder in enabled:
		if not folder is String or folder.is_empty() or enabled[folder] is not bool:
			return _fail("invalid_mod_selection")
	_data_dir = data_dir
	_dirs = dirs.duplicate()
	_enabled = enabled.duplicate()
	_episode = episode
	var fresh := _read()
	if fresh.has("error"):
		return _fail(fresh.error)
	_api = fresh.api
	digest = fresh.digest
	return true


func clear() -> void:
	_api = null
	digest = ""
	error = ""
	_data_dir = ""
	_dirs.clear()
	_enabled.clear()
	_episode = 0


## A fresh loader prevents an old resolved cache from masking edited mod JSON.
## Failure poisons this capture; restoring files requires a new negotiation.
func verify_current() -> bool:
	if _api == null or not error.is_empty():
		return false
	var fresh := _read()
	if fresh.has("error"):
		return _fail(fresh.error)
	if fresh.digest != digest:
		return _fail("content_changed")
	return true


func attach(sim: Node) -> bool:
	if sim == null or not sim.has_method("set_mods") or not verify_current():
		return false
	sim.set_mods(_api)
	return true


## Checks actual parsed assets and resolved definitions, without creating or
## stepping a simulation. Initial/progression rule validation is also required.
func validate_level(config: Dictionary) -> bool:
	if not Config.valid(config) or config.episode != _episode:
		return false
	if not verify_current():
		return false
	if not _api.has_method("network_validate_level"):
		return _fail("native_rebuild_required")
	var result: Dictionary = _api.network_validate_level(
		_episode,
		config.level_file,
		config.difficulty,
		PackedInt32Array(config.loadout1),
		PackedInt32Array(config.loadout2)
	)
	if result.get("valid") != true:
		return _fail(result.get("error", "invalid_level_data"))
	return verify_current()


func _fail(reason: String) -> bool:
	error = reason
	_api = null
	return false


func _read() -> Dictionary:
	if not ClassDB.class_exists("TyrianMods"):
		return {"error": "native_unavailable"}
	var api: RefCounted = ClassDB.instantiate("TyrianMods")
	api.load(_data_dir, _dirs)
	var seen := {}
	for mod in api.list(_episode):
		var folder: String = mod.folder
		seen[folder] = true
		# Freeze the explicit selection: newly discovered default-enabled mods
		# cannot silently join this session.
		api.set_enabled(folder, _enabled.get(folder, false))
	for folder in _enabled:
		if _enabled[folder] and not seen.has(folder):
			return {"error": "missing_enabled_mod"}
	api.reload()
	var before: Dictionary = api.network_content_identity(_episode)
	if not Config.hex_string(before.get("digest"), 64):
		return {"error": before.get("error", "content_unavailable")}
	# Discard all resolved tables, then hash again around the resolution that
	# will actually be retained. A detected edit cannot pair new bytes with an
	# old cache. Callers still recheck after level loading; files are not locked.
	api.reload()
	var identity: Dictionary = api.network_content_identity(_episode)
	if not Config.hex_string(identity.get("digest"), 64):
		return {"error": identity.get("error", "content_unavailable")}
	if identity.digest != before.digest:
		return {"error": "content_changed"}
	return {"api": api, "digest": identity.digest}
