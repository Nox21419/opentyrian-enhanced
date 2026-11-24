extends GdUnitTestSuite

const Identity := preload("res://scripts/network_identity.gd")
const Protocol := preload("res://scripts/network_startup_protocol.gd")
var _roots: Array[String] = []
var _serial := 0


func after_test() -> void:
	for root in _roots:
		_remove_fixture(root)
	_roots.clear()


func _remove_fixture(root: String) -> void:
	for folder in DirAccess.get_directories_at(root):
		_remove_fixture(root.path_join(folder))
	for file in DirAccess.get_files_at(root):
		DirAccess.remove_absolute(root.path_join(file))
	DirAccess.remove_absolute(root)


func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _fixture() -> String:
	_serial += 1
	var root := "user://network_identity_%d_%d" % [OS.get_process_id(), _serial]
	DirAccess.make_dir_recursive_absolute(root)
	_roots.append(root)
	for folder in Identity.ROOTS:
		DirAccess.make_dir_recursive_absolute(root.path_join(folder))
	_write(root.path_join("project.godot"), "config_version=5\n")
	_write(root.path_join("scripts/a.gd"), "extends Node\n")
	return root


func test_client_hash_matches_cross_language_fixture_and_ignores_absolute_paths() -> void:
	var first := _fixture()
	var second := _fixture()
	# SHA-256 over sorted name/NUL/file-hash/LF records, independently generated
	# with Python hashlib. No timestamps or checkout locations enter this value.
	var expected := "fe2e00df7298ef2ae37a998ac107d2a27e689129f95861ea5f06a1fb533c4be5"
	assert_str(Identity.source_digest(first)).is_equal(expected)
	assert_str(Identity.source_digest(second)).is_equal(expected)
	_write(second.path_join("scripts/a.gd"), "extends Node2D\n")
	assert_str(Identity.source_digest(second)).is_not_equal(expected)


func test_client_hash_detects_new_sources_and_missing_roots_but_not_test_files() -> void:
	var root := _fixture()
	var original := Identity.source_digest(root)
	DirAccess.make_dir_recursive_absolute(root.path_join("test"))
	_write(root.path_join("test/ignored.gd"), "extends RefCounted\n")
	assert_str(Identity.source_digest(root)).is_equal(original)
	_write(root.path_join("scripts/new.gd"), "extends RefCounted\n")
	assert_str(Identity.source_digest(root)).is_not_equal(original)
	DirAccess.remove_absolute(root.path_join("config"))
	assert_str(Identity.source_digest(root)).is_empty()


func test_loaded_native_build_and_actual_runtime_content_have_stable_identities() -> void:
	var result: Dictionary = Identity.collect(1)
	assert_bool(result.has("identity")).is_true()
	if not result.has("identity"):
		return
	assert_bool(Protocol.valid_identity(result.identity)).is_true()
	assert_dict(Identity.collect(1)).is_equal(result)
	assert_str(result.identity.client).is_equal(Identity.source_digest())
	assert_bool(Identity.collect(0).has("error")).is_true()


func test_content_identity_rejects_invalid_episode_and_is_independent_of_mod_scan_paths() -> void:
	var first: RefCounted = ClassDB.instantiate("TyrianMods")
	var second: RefCounted = ClassDB.instantiate("TyrianMods")
	first.load(Game.data_dir, PackedStringArray())
	second.load(Game.data_dir, PackedStringArray())
	var a: Dictionary = first.network_content_identity(1)
	assert_bool(a.has("digest")).is_true()
	assert_dict(second.network_content_identity(1)).is_equal(a)
	assert_bool(first.network_content_identity(6).has("error")).is_true()
