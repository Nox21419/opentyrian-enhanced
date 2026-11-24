extends GdUnitTestSuite

const Snapshot := preload("res://scripts/network_content_snapshot.gd")
var _root := ""


func after() -> void:
	Music.release_streams()
	Sfx.release_streams()


func before_test() -> void:
	_root = ProjectSettings.globalize_path("user://network-content-fixture")
	DirAccess.make_dir_recursive_absolute(_root.path_join("sample"))
	_write("sample/mod.json", JSON.stringify({"format_version": 1, "name": "Session fixture", "enabled": false}))


func after_test() -> void:
	_remove(_root)


func _remove(path: String) -> void:
	for folder in DirAccess.get_directories_at(path):
		_remove(path.path_join(folder))
	for file in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file))
	DirAccess.remove_absolute(path)


func _write(path: String, text: String) -> void:
	var file := FileAccess.open(_root.path_join(path), FileAccess.WRITE)
	file.store_string(text)
	file.close()


func test_snapshot_is_independent_of_global_mod_loader_and_caller_selection() -> void:
	var global_api: RefCounted = Mods.api
	var selection := {"sample": true}
	var snapshot := Snapshot.new()
	assert_bool(snapshot.capture(Game.data_dir, PackedStringArray([_root]), selection, 1)).is_true()
	var digest: String = snapshot.digest
	selection.sample = false
	assert_bool(snapshot.verify_current()).is_true()
	assert_str(snapshot.digest).is_equal(digest)
	assert_object(Mods.api).is_same(global_api)
	var sim: Node = ClassDB.instantiate("TyrianSim")
	assert_bool(snapshot.attach(sim)).is_true()
	sim.free()


func test_changed_enabled_bytes_poison_snapshot_even_if_files_are_restored() -> void:
	_write("sample/notes.txt", "before")
	var snapshot := Snapshot.new()
	assert_bool(snapshot.capture(Game.data_dir, PackedStringArray([_root]), {"sample": true}, 1)).is_true()
	_write("sample/notes.txt", "after")
	assert_bool(snapshot.verify_current()).is_false()
	assert_str(snapshot.error).is_equal("content_changed")
	_write("sample/notes.txt", "before")
	assert_bool(snapshot.verify_current()).is_false()
	assert_bool(snapshot.capture(Game.data_dir, PackedStringArray([_root]), {"sample": true}, 1)).is_true()


func test_disabled_edits_and_new_default_enabled_mods_do_not_change_selection() -> void:
	var snapshot := Snapshot.new()
	assert_bool(snapshot.capture(Game.data_dir, PackedStringArray([_root]), {}, 1)).is_true()
	_write("sample/notes.txt", "disabled content changed")
	DirAccess.make_dir_recursive_absolute(_root.path_join("new_mod"))
	_write("new_mod/mod.json", JSON.stringify({"format_version": 1, "name": "New fixture", "enabled": true}))
	assert_bool(snapshot.verify_current()).is_true()


func test_missing_enabled_mod_invalid_manifest_and_reset_fail_closed() -> void:
	var snapshot := Snapshot.new()
	assert_bool(snapshot.capture(Game.data_dir, PackedStringArray([_root]), {"absent": true}, 1)).is_false()
	assert_str(snapshot.error).is_equal("missing_enabled_mod")
	_write("sample/mod.json", "invalid")
	assert_bool(snapshot.capture(Game.data_dir, PackedStringArray([_root]), {"sample": true}, 1)).is_false()
	assert_bool(snapshot.error.is_empty()).is_false()
	snapshot.clear()
	assert_bool(snapshot.verify_current()).is_false()
	assert_str(snapshot.digest).is_empty()
