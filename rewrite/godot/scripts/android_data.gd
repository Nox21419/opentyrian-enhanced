## APK resources are not ordinary files for Rust's std::fs. Extract only the
## build-generated manifest into an app-private cache before Game loads assets.
## Player saves/settings are siblings of bundled/, never extraction targets.
class_name AndroidData
extends RefCounted

const BUNDLE := "res://assets/android/runtime.zip"
const MANIFEST := "manifest.json"
static var last_error := ""


static func root_dir() -> String:
	return OS.get_user_data_dir().path_join("bundled/runtime-v1")


## Optional paths allow desktop tests to exercise exactly the phone bootstrap.
static func prepare(bundle: String = BUNDLE, root: String = "") -> bool:
	last_error = ""
	if root.is_empty():
		root = root_dir()
	# Android may compress this ZIP again inside the APK. ZIPReader's seeks then
	# repeatedly inflate the outer asset. One sequential copy avoids that cost.
	if bundle.begins_with("res://"):
		var local_bundle := root.path_join("_runtime.zip")
		if not _write_atomic(local_bundle, FileAccess.get_file_as_bytes(bundle)):
			last_error = "Cannot stage bundled archive"
			return false
		bundle = local_bundle
	var zip := ZIPReader.new()
	if zip.open(bundle) != OK:
		last_error = "Cannot open %s" % bundle
		return false
	var manifest = JSON.parse_string(zip.read_file(MANIFEST).get_string_from_utf8())
	if not manifest is Dictionary or manifest.get("version") != 1 or not manifest.get("files") is Dictionary:
		zip.close()
		last_error = "Invalid manifest"
		return false
	var files: Dictionary = manifest["files"]
	if files.is_empty():
		zip.close()
		last_error = "Empty manifest"
		return false
	# Validate the whole manifest before writing even one file.
	for name in files:
		if not safe_name(str(name)) or not files[name] is String or str(files[name]).length() != 64:
			zip.close()
			last_error = "Invalid entry %s" % name
			return false
		if not zip.file_exists(name):
			zip.close()
			last_error = "Missing entry %s" % name
			return false
	var repaired := 0
	for name: String in files:
		var target := root.path_join(name)
		if FileAccess.file_exists(target) and FileAccess.get_sha256(target) == files[name]:
			continue
		var bytes := zip.read_file(name)
		var hash := HashingContext.new()
		hash.start(HashingContext.HASH_SHA256)
		hash.update(bytes)
		if hash.finish().hex_encode() != files[name] or not _write_atomic(target, bytes):
			zip.close()
			last_error = "Failed to extract %s" % name
			return false
		repaired += 1
	zip.close()
	print("Android data ready: %s (%d files repaired)" % [root, repaired])
	return true


static func safe_name(name: String) -> bool:
	if name.is_empty() or name.contains("\\") or name.contains(":") or name.begins_with("/"):
		return false
	for part in name.split("/"):
		if part in ["", ".", ".."]:
			return false
	# Never accept arbitrary player paths from a bundle, even inside the cache.
	return name.begins_with("data/") or name.begins_with("licenses/") or name in ["COPYING", "DATA-NOTICES.txt"]


static func _write_atomic(path: String, bytes: PackedByteArray) -> bool:
	if DirAccess.make_dir_recursive_absolute(path.get_base_dir()) != OK:
		return false
	var temp := path + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		return false
	file.store_buffer(bytes)
	file.flush()
	var ok := file.get_error() == OK
	file.close()
	if not ok:
		DirAccess.remove_absolute(temp)
		return false
	return DirAccess.rename_absolute(temp, path) == OK
