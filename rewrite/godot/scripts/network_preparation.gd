## One epoch's owned preparation context. No Game/scene/profile mutation and no
## loaded/Ready claims: complete state hashing and shop integration come later.
extends RefCounted

const Content := preload("res://scripts/network_content_snapshot.gd")
const Identity := preload("res://scripts/network_identity.gd")
const Rules := preload("res://scripts/network_initial_configuration.gd")
const Config := preload("res://scripts/network_configuration.gd")
const Next := preload("res://scripts/network_next_level.gd")

var error := ""
var _content: RefCounted
var _rules: RefCounted
var _identity := {}
var _config := {}
var _entry := {}
var _digest := ""
var _preview: Node
var _preview_digest := ""
var _data_dir := ""
var _dirs := PackedStringArray()
var _enabled := {}
var _episode := 0
var _next_request := {}


func capture(data_dir: String, dirs: PackedStringArray, enabled: Dictionary, episode: int) -> bool:
	clear()
	_data_dir = data_dir
	_dirs = dirs.duplicate()
	_enabled = enabled.duplicate()
	_episode = episode
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
	_release_preview()
	_data_dir = ""
	_dirs.clear()
	_enabled.clear()
	_episode = 0
	error = ""
	_content = null
	_rules = null
	_identity.clear()
	_config.clear()
	_entry.clear()
	_digest = ""
	_next_request.clear()


func _notification(what: int) -> void:
	# During RefCounted PREDELETE, script method dispatch can already be gone.
	# Release the owned native Node directly rather than calling another method.
	if what == NOTIFICATION_PREDELETE and is_instance_valid(_preview):
		_preview.free()


func _release_preview() -> void:
	if is_instance_valid(_preview):
		_preview.free()
	_preview = null
	_preview_digest = ""


## Read-only initial-level preview, still behind the retained shop entry.
## No loaded/Ready signal or gameplay scene handoff is authorized here.
func prepare_preview() -> bool:
	if _config.is_empty() or not error.is_empty():
		return false
	if _preview != null:
		return verify_preview()
	if not verify_current():
		return false
	_preview = ClassDB.instantiate("TyrianSim")
	var method := "prepare_network_continuation" if not _next_request.is_empty() else "prepare_network_level"
	if not _preview.has_method(method):
		return _fail("native_rebuild_required")
	if not _content.attach(_preview):
		return _fail("preview_load_failed")
	var loaded: bool
	if _next_request.is_empty():
		loaded = _preview.prepare_network_level(_data_dir, _config)
	else:
		loaded = _preview.prepare_network_continuation(
			_data_dir, _config, _next_request.carry, _next_request.bonus_level
		)
	if not loaded:
		return _fail("preview_load_failed")
	if not verify_current():
		return false
	_preview_digest = _preview.network_diagnostic_digest()
	if not Config.hex_string(_preview_digest, 64):
		return _fail("preview_digest_unavailable")
	return true


func preview_digest() -> String:
	return _preview_digest if error.is_empty() else ""


func verify_preview() -> bool:
	if not verify_current():
		return false
	if _preview == null or _preview.network_diagnostic_digest() != _preview_digest:
		return _fail("preview_state_changed")
	return true


func identity() -> Dictionary:
	return _identity.duplicate(true) if error.is_empty() else {}


func configuration() -> Dictionary:
	return _config.duplicate(true) if error.is_empty() else {}


func entry() -> Dictionary:
	return _entry.duplicate(true) if error.is_empty() else {}


## Caller owns this new context. The old preview stays alive and unchanged.
## Agreement, fresh epoch allocation and scene adoption are separate operations.
func fork_continuation(proposal: Dictionary, seed: String) -> RefCounted:
	if _preview == null or not verify_current():
		return null
	var request := Next.build(_config, proposal, seed)
	if request.is_empty():
		return null
	var context: RefCounted = get_script().new()
	if not context.capture(_data_dir, _dirs, _enabled, _episode) or context.identity() != _identity:
		context.clear()
		return null
	if not context._accept_continuation(request) or not context.prepare_preview() or not verify_current():
		context.clear()
		return null
	return context


func continuation_request() -> Dictionary:
	return _next_request.duplicate(true) if error.is_empty() else {}


func _accept_continuation(request: Dictionary) -> bool:
	if not _config.is_empty() or not _content.validate_continuation_level(request.configuration):
		return _fail("invalid_continuation_configuration")
	_next_request = request.duplicate(true)
	_config = request.configuration.duplicate(true)
	_entry = request.entry.duplicate(true)
	_digest = Next.configuration_digest(_config)
	return not _digest.is_empty() and verify_current()


## Supply this callable to NetworkStartup/NetworkStartupConnection on both peers.
## Once accepted, a different config requires fresh capture/negotiation.
func validate(config: Dictionary) -> bool:
	if not _next_request.is_empty():
		return false
	if _rules == null or not error.is_empty():
		return false
	if not Config.valid(config):
		return _fail("invalid_initial_rules")
	var digest := Config.digest(config)
	if not _digest.is_empty() and digest != _digest:
		return _fail("configuration_changed")
	if config.episode != _episode:
		# Episode was chosen after hello; raw content/build identity must remain
		# the same, and recapture must precede any accepted configuration.
		var content := Content.new()
		if not content.capture(_data_dir, _dirs, _enabled, config.episode):
			return _fail(content.error)
		var identity := Identity.from_content(content.digest)
		if not identity.has("identity") or identity.identity != _identity:
			return _fail("identity_changed")
		_content = content
		_rules = Rules.new(_data_dir)
		_episode = config.episode
	if not _rules.valid(config):
		return _fail("invalid_initial_rules")
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
	_release_preview()
	_next_request.clear()
	error = reason
	_identity.clear()
	_config.clear()
	_entry.clear()
	return false
