## One epoch's owned preparation context. No Game/scene/profile mutation and no
## loaded/Ready claims: complete state hashing and shop integration come later.
extends RefCounted

const Content := preload("res://scripts/network_content_snapshot.gd")
const Identity := preload("res://scripts/network_identity.gd")
const Rules := preload("res://scripts/network_initial_configuration.gd")
const Config := preload("res://scripts/network_configuration.gd")

var error := ""
var _content: RefCounted
var _rules: RefCounted
var _identity := {}
var _config := {}
var _entry := {}
var _digest := ""


func capture(data_dir: String, dirs: PackedStringArray, enabled: Dictionary, episode: int) -> bool:
	clear()
	_content = Content.new()
	if not _content.capture(data_dir, dirs, enabled, episode):
		return _fail(_content.error)
	_rules = Rules.new(data_dir)
	var result := Identity.from_content(_content.digest)
	if not result.has("identity"):
		return _fail(result.get("error", "identity_unavailable"))
	_identity = result.identity.duplicate(true)
	return verify_current()


func clear() -> void:
	error = ""
	_content = null
	_rules = null
	_identity.clear()
	_config.clear()
	_entry.clear()
	_digest = ""


func identity() -> Dictionary:
	return _identity.duplicate(true) if error.is_empty() else {}


func configuration() -> Dictionary:
	return _config.duplicate(true) if error.is_empty() else {}


func entry() -> Dictionary:
	return _entry.duplicate(true) if error.is_empty() else {}


## Supply this callable to NetworkStartup/NetworkStartupConnection on both peers.
## Once accepted, a different config requires fresh capture/negotiation.
func validate(config: Dictionary) -> bool:
	if _rules == null or not error.is_empty():
		return false
	if not _rules.valid(config):
		return _fail("invalid_initial_rules")
	var digest := Config.digest(config)
	if not _digest.is_empty() and digest != _digest:
		return _fail("configuration_changed")
	if not _content.validate_level(config):
		return _fail(_content.error if not _content.error.is_empty() else "invalid_level_configuration")
	var preview: Dictionary = _rules.first_level(config.episode, config.initial_difficulty)
	if preview.is_empty() or not verify_current():
		return _fail(error if not error.is_empty() else "invalid_campaign_entry")
	_digest = digest
	_config = config.duplicate(true)
	_entry = preview.entry.duplicate(true)
	return true


func verify_current() -> bool:
	if _content == null or not error.is_empty():
		return false
	if not _content.verify_current():
		return _fail(_content.error)
	var current := Identity.from_content(_content.digest)
	if not current.has("identity") or current.identity != _identity:
		return _fail("identity_changed")
	return true


func _fail(reason: String) -> bool:
	error = reason
	_identity.clear()
	_config.clear()
	_entry.clear()
	return false
