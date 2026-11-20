extends GdUnitTestSuite

var _root: String


func before_test() -> void:
	_root = OS.get_user_data_dir().path_join("android_data_test_%d" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(_root)


func after_test() -> void:
	_remove_tree(_root)


func test_first_run_reuse_repair_and_upgrade_preserve_player_files() -> void:
	var bundle := _root.path_join("runtime.zip")
	var cache := _root.path_join("bundled/runtime-v1")
	_write(_root.path_join("saves/slot_01.json"), "player save".to_utf8_buffer())
	_bundle(bundle, "original")
	assert_bool(AndroidData.prepare(bundle, cache)).is_true()
	var target := cache.path_join("data/tyrian.hdt")
	assert_str(FileAccess.get_file_as_string(target)).is_equal("original")
	var modified := FileAccess.get_modified_time(target)
	assert_bool(AndroidData.prepare(bundle, cache)).is_true()
	assert_int(FileAccess.get_modified_time(target)).is_equal(modified)
	_write(target, "corrupt".to_utf8_buffer())
	assert_bool(AndroidData.prepare(bundle, cache)).is_true()
	assert_str(FileAccess.get_file_as_string(target)).is_equal("original")
	DirAccess.remove_absolute(target)
	assert_bool(AndroidData.prepare(bundle, cache)).is_true()
	_bundle(bundle, "updated")
	assert_bool(AndroidData.prepare(bundle, cache)).is_true()
	assert_str(FileAccess.get_file_as_string(target)).is_equal("updated")
	assert_str(FileAccess.get_file_as_string(_root.path_join("saves/slot_01.json"))).is_equal("player save")


func test_bundle_names_cannot_escape_or_target_player_files() -> void:
	for name in [
		"../save", "data/../../save", "/data/file", "data\\file", "C:/data/file", "saves/slot.json", "data//f"
	]:
		assert_bool(AndroidData.safe_name(name)).is_false()
	for name in ["mods/../saves/slot.json", "mods//mod.json", "modsx/mod.json", "mods"]:
		assert_bool(AndroidData.safe_name(name)).is_false()
	for name in [
		"data/tyrian.hdt",
		"data/midi/01-song.mid",
		"licenses/rustysynth-LICENSE.txt",
		"COPYING",
		"mods/alien_ship_pack/mod.json",
		"mods/alien_ship_pack/sprites/ship.png",
	]:
		assert_bool(AndroidData.safe_name(name)).is_true()


func test_bad_hash_and_unsafe_manifest_fail_without_touching_save() -> void:
	var bundle := _root.path_join("runtime.zip")
	var cache := _root.path_join("bundled/runtime-v1")
	_write(_root.path_join("save.json"), "save".to_utf8_buffer())
	_bundle(bundle, "content", "data/tyrian.hdt", "0".repeat(64))
	assert_bool(AndroidData.prepare(bundle, cache)).is_false()
	assert_str(AndroidData.last_error).contains("Failed to extract")
	assert_bool(FileAccess.file_exists(cache.path_join("data/tyrian.hdt"))).is_false()
	_bundle(bundle, "content", "../../save.json")
	assert_bool(AndroidData.prepare(bundle, cache)).is_false()
	assert_str(AndroidData.last_error).contains("Invalid entry")
	assert_str(FileAccess.get_file_as_string(_root.path_join("save.json"))).is_equal("save")


func _bundle(path: String, content: String, name := "data/tyrian.hdt", digest := "") -> void:
	var bytes := content.to_utf8_buffer()
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(bytes)
	var computed := hash.finish().hex_encode()
	var manifest := {"version": 1, "files": {name: computed if digest.is_empty() else digest}}
	var zip := ZIPPacker.new()
	assert_int(zip.open(path)).is_equal(OK)
	zip.start_file("manifest.json")
	zip.write_file(JSON.stringify(manifest).to_utf8_buffer())
	zip.close_file()
	zip.start_file(name)
	zip.write_file(bytes)
	zip.close_file()
	zip.close()


func _write(path: String, bytes: PackedByteArray) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()


func _remove_tree(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for file in dir.get_files():
		DirAccess.remove_absolute(path.path_join(file))
	for child in dir.get_directories():
		_remove_tree(path.path_join(child))
	DirAccess.remove_absolute(path)
