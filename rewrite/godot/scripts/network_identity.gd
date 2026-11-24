## Conservative compatibility identity. Editor runs hash effective loose client
## sources; exports require a fresh stamp inserted by the export plugin.
@tool
extends RefCounted

const Config := preload("res://scripts/network_configuration.gd")
const Protocol := preload("res://scripts/network_startup_protocol.gd")
const STAMP := "res://assets/network-client-id.json"
const ROOTS := ["scripts", "effects", "scenes", "config", "addons/tyrian_networking"]
const EXTENSIONS := ["gd", "tscn", "tres", "cfg"]
const MAX_FILES := 4096


static func collect(episode: int) -> Dictionary:
	# Export tooling can preload this pure hashing code before autoload globals
	# are registered. Resolve the runtime mod API only when collection is asked for.
	var loop := Engine.get_main_loop()
	var mods: Node = loop.root.get_node_or_null("Mods") if loop is SceneTree else null
	var api: RefCounted = mods.get("api") if mods != null else null
	if episode < 1 or episode > 5 or api == null or not ClassDB.class_exists("TyrianSim"):
		return {"error": "identity_unavailable"}
	var native: Node = ClassDB.instantiate("TyrianSim")
	if not native.has_method("network_build_id") or not api.has_method("network_content_identity"):
		native.free()
		return {"error": "native_rebuild_required"}
	var build: String = native.network_build_id()
	native.free()
	var content: Dictionary = api.network_content_identity(episode)
	if not content.has("digest"):
		return {"error": content.get("error", "content_unavailable")}
	var client := source_digest() if OS.has_feature("editor") else exported_digest()
	var version := Engine.get_version_info()
	var engine := Config.sha256(
		JSON.stringify([version.major, version.minor, version.patch, version.status, version.build, version.hash])
	)
	var identity := {"native": build, "client": client, "content": content.digest, "engine": engine}
	return {"identity": identity} if Protocol.valid_identity(identity) else {"error": "client_stamp_required"}


static func exported_digest() -> String:
	if not FileAccess.file_exists(STAMP):
		return ""
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(STAMP)) != OK:
		return ""
	var stamp: Variant = json.data
	if not stamp is Dictionary or stamp.size() != 2 or stamp.get("version") != 1:
		return ""
	return stamp.digest if Config.hex_string(stamp.get("digest"), 64) else ""


## Optional root permits explicit isolated source fixtures in tests.
static func source_digest(root := "res://") -> String:
	var files: Array[String] = ["project.godot"]
	var visits: Array[int] = [0]
	for folder in ROOTS:
		if not _scan(root, folder, files, 0, visits):
			return ""
	files.sort()
	var manifest := HashingContext.new()
	manifest.start(HashingContext.HASH_SHA256)
	var total_bytes := 0
	for file in files:
		var source := FileAccess.open(root.path_join(file), FileAccess.READ)
		if source == null:
			return ""
		total_bytes += source.get_length()
		source.close()
		if total_bytes > 512 * 1024 * 1024:
			return ""
		var digest := FileAccess.get_sha256(root.path_join(file))
		if not Config.hex_string(digest, 64):
			return ""
		manifest.update(file.to_utf8_buffer())
		manifest.update(PackedByteArray([0]))
		manifest.update((digest + "\n").to_utf8_buffer())
	return manifest.finish().hex_encode()


static func _scan(root: String, relative: String, files: Array[String], depth: int, visits: Array[int]) -> bool:
	if depth > 32 or files.size() >= MAX_FILES:
		return false
	var dir := DirAccess.open(root.path_join(relative))
	if dir == null:
		return false
	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		visits[0] += 1
		if visits[0] > 8192:
			dir.list_dir_end()
			return false
		if entry.contains("\n") or entry.contains("\r") or entry.contains("\\") or dir.is_link(entry):
			dir.list_dir_end()
			return false
		var path := relative.path_join(entry)
		if dir.current_is_dir():
			if not _scan(root, path, files, depth + 1, visits):
				dir.list_dir_end()
				return false
		elif entry.get_extension() in EXTENSIONS:
			if files.size() >= MAX_FILES:
				dir.list_dir_end()
				return false
			files.append(path)
		entry = dir.get_next()
	dir.list_dir_end()
	return true
