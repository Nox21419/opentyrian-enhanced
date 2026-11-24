extends GdUnitTestSuite

const Snapshot := preload("res://scripts/network_content_snapshot.gd")
const Policy := preload("res://scripts/network_initial_configuration.gd")
const Setup := preload("res://test/fixtures/network_setup.gd")
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


func test_actual_level_and_initial_equipment_validate_for_each_episode() -> void:
	var policy := Policy.new(Game.data_dir)
	for episode in range(1, 6):
		var snapshot := Snapshot.new()
		assert_bool(snapshot.capture(Game.data_dir, PackedStringArray(), {}, episode)).is_true()
		var config := Setup.configuration()
		config.episode = episode
		config.level_file = policy.first_level(episode, 2).lvl_file_num
		assert_bool(snapshot.validate_level(config)).is_true()


func test_invalid_equipment_and_missing_level_fail_without_native_error_logs() -> void:
	var api: RefCounted = ClassDB.instantiate("TyrianMods")
	api.load(Game.data_dir, PackedStringArray())
	var config := Setup.configuration()
	var first := PackedInt32Array(config.loadout1)
	var second := PackedInt32Array(config.loadout2)
	for slot in [0, 1, 3, 5, 6, 7, 8, 9]:
		var bad := first.duplicate()
		bad[slot] = 255
		var result: Dictionary = api.network_validate_level(1, 9, 3, bad, second)
		assert_str(result.get("error", "")).is_equal("invalid_equipment")
	assert_str(api.network_validate_level(1, 65535, 3, first, second).get("error", "")).is_equal("invalid_level_data")
	assert_str(api.network_validate_level(0, 9, 3, first, second).get("error", "")).is_equal(
		"invalid_level_configuration"
	)
	assert_str(api.network_validate_level(1, 9, 3, PackedInt32Array(), second).get("error", "")).is_equal(
		"invalid_equipment"
	)


func test_content_failure_prevents_validation_and_failed_level_poisons_capture() -> void:
	var snapshot := Snapshot.new()
	assert_bool(snapshot.capture(Game.data_dir, PackedStringArray([_root]), {"sample": true}, 1)).is_true()
	_write("sample/changed.txt", "modified after capture")
	assert_bool(snapshot.validate_level(Setup.configuration())).is_false()
	assert_str(snapshot.error).is_equal("content_changed")
	assert_bool(snapshot.capture(Game.data_dir, PackedStringArray(), {}, 1)).is_true()
	var config := Setup.configuration()
	config.level_file = 65535
	assert_bool(snapshot.validate_level(config)).is_false()
	assert_str(snapshot.error).is_equal("invalid_level_data")
	assert_bool(snapshot.verify_current()).is_false()


func test_resolved_shipped_mod_equipment_is_accepted_without_changing_global_mods() -> void:
	var api: RefCounted = ClassDB.instantiate("TyrianMods")
	api.load(Game.data_dir, Mods.dirs())
	for mod in api.list(1):
		api.set_enabled(mod.folder, true)
	api.reload()
	var config := Setup.configuration()
	var seen := {}
	for item in api.items(1):
		var first := PackedInt32Array(config.loadout1)
		if item.kind == "ship":
			first[0] = item.id
		elif item.kind == "weapon":
			first[1] = item.id
		else:
			continue
		seen[item.kind] = true
		var result: Dictionary = api.network_validate_level(1, 9, 3, first, PackedInt32Array(config.loadout2))
		assert_bool(result.get("valid", false)).is_true()
	assert_bool(seen.has("ship") and seen.has("weapon")).is_true()
