extends GdUnitTestSuite

const Preparation := preload("res://scripts/network_preparation.gd")
const Rules := preload("res://scripts/network_initial_configuration.gd")
const Startup := preload("res://scripts/network_startup.gd")
const Setup := preload("res://test/fixtures/network_setup.gd")


func after() -> void:
	Music.release_streams()
	Sfx.release_streams()
	await get_tree().process_frame
	await get_tree().process_frame


func _capture() -> RefCounted:
	var context := Preparation.new()
	assert_bool(context.capture(Game.data_dir, PackedStringArray(), {}, 1)).is_true()
	return context


func _config() -> Dictionary:
	var config := Setup.configuration()
	var rules := Rules.new(Game.data_dir)
	config.level_file = rules.first_level(1, 2).lvl_file_num
	return config


func test_owned_context_connects_real_identity_and_validation_to_startup_without_starting() -> void:
	var episode: int = Game.episode
	var active: bool = Game.campaign_active
	var first := _capture()
	var second := _capture()
	assert_dict(first.identity()).is_equal(second.identity())
	var host := Startup.new(1, first.identity(), first.validate)
	var guest := Startup.new(2, second.identity(), second.validate)
	for message in host.take_messages():
		guest.receive(message)
	for message in guest.take_messages():
		host.receive(message)
	assert_bool(host.propose(_config(), "19".repeat(16), 1)).is_true()
	for message in host.take_messages():
		guest.receive(message)
	for message in guest.take_messages():
		host.receive(message)
	assert_int(host.phase).is_equal(Startup.Phase.AGREED)
	assert_int(guest.phase).is_equal(Startup.Phase.AGREED)
	assert_str(first.entry().stop).is_equal("shop")
	assert_bool(host.start()).is_false()
	assert_int(Game.episode).is_equal(episode)
	assert_bool(Game.campaign_active).is_equal(active)


func test_accepted_configuration_is_copied_and_cannot_change_within_capture() -> void:
	var context := _capture()
	var config := _config()
	assert_bool(context.validate(config)).is_true()
	var saved: Dictionary = context.configuration()
	config.loadout1[0] = 255
	assert_dict(context.configuration()).is_equal(saved)
	var entry: Dictionary = context.entry()
	entry.stop = "level"
	assert_str(context.entry().stop).is_equal("shop")
	var identity: Dictionary = context.identity()
	identity.content = "00".repeat(32)
	assert_bool(context.identity().content != identity.content).is_true()
	assert_bool(context.validate(saved)).is_true()
	saved.input_delay = 4
	assert_bool(context.validate(saved)).is_false()
	assert_str(context.error).is_equal("configuration_changed")
	assert_bool(context.identity().is_empty()).is_true()
	assert_bool(context.configuration().is_empty()).is_true()


func test_invalid_rules_fail_closed_and_clear_allows_fresh_capture() -> void:
	var context := _capture()
	var config := _config()
	config.cash2 = "0000000000000001"
	assert_bool(context.validate(config)).is_false()
	assert_str(context.error).is_equal("invalid_initial_rules")
	assert_bool(context.verify_current()).is_false()
	context.clear()
	assert_bool(context.identity().is_empty()).is_true()
	assert_bool(context.validate(_config())).is_false()
	assert_bool(context.capture(Game.data_dir, PackedStringArray(), {}, 1)).is_true()
	assert_bool(context.validate(_config())).is_true()


func test_detached_previews_match_despite_intervening_local_starfield_history() -> void:
	var config := _config()
	config.processor_type = 1
	config.explosion_style = 2
	var first := _capture()
	assert_bool(first.validate(config)).is_true()
	assert_bool(first.prepare_preview()).is_true()
	var digest: String = first.preview_digest()
	assert_int(digest.length()).is_equal(64)
	var local: Node = ClassDB.instantiate("TyrianSim")
	local.set_loadout(PackedInt32Array([11, 1, 1, 0, 1, 4, 2, 0, 0, 0, 0]))
	assert_bool(local.load_level(Game.data_dir, 1, 9, 3, 123)).is_true()
	for tick in 20:
		local.step(16, 0)
	local.free()
	var second := _capture()
	assert_bool(second.validate(config)).is_true()
	assert_bool(second.prepare_preview()).is_true()
	assert_str(second.preview_digest()).is_equal(digest)
	assert_bool(first.verify_preview()).is_true()
	assert_str(first.entry().stop).is_equal("shop")
	var preview: Node = first.get("_preview")
	assert_int(preview.processor_type()).is_equal(1)
	assert_int(preview.loadout()[0]).is_equal(11)
	assert_bool(first.prepare_preview()).is_true()
	first.clear()
	assert_bool(is_instance_valid(preview)).is_false()
	assert_str(first.preview_digest()).is_empty()
	second.clear()


func test_preview_cannot_skip_validation_and_detects_unexpected_state_changes() -> void:
	var context := _capture()
	assert_bool(context.prepare_preview()).is_false()
	assert_bool(context.validate(_config())).is_true()
	assert_bool(context.prepare_preview()).is_true()
	var preview: Node = context.get("_preview")
	assert_bool(preview.prepare_network_level(Game.data_dir, _config())).is_false()
	assert_str(preview.last_error()).is_equal("network_preview_requires_fresh_node")
	preview.step(0, 0)
	assert_bool(context.verify_preview()).is_false()
	assert_str(context.error).is_equal("preview_state_changed")
	assert_bool(is_instance_valid(preview)).is_false()
	assert_str(context.preview_digest()).is_empty()


func test_context_release_frees_owned_preview_without_explicit_clear() -> void:
	var context := _capture()
	assert_bool(context.validate(_config())).is_true()
	assert_bool(context.prepare_preview()).is_true()
	var preview: Node = context.get("_preview")
	assert_bool(is_instance_valid(preview)).is_true()
	context = null
	assert_bool(is_instance_valid(preview)).is_false()


func test_native_preview_rechecks_types_bounds_and_assets_before_loading() -> void:
	var sim: Node = ClassDB.instantiate("TyrianSim")
	Mods.attach(sim)
	for pair in [
		["episode", 1.0],
		["devices", [1, 2]],
		["seed", "FFFFFFFFFFFFFFFF"],
		["cash1", "0000000000000001"],
		["level_file", 65535],
		["particles", 1],
		["loadout2", []],
		["input_delay", 9],
		["unknown", false]
	]:
		var config := _config()
		config[pair[0]] = pair[1]
		assert_bool(sim.prepare_network_level(Game.data_dir, config)).is_false()
		assert_str(sim.network_diagnostic_digest()).is_empty()
		assert_str(sim.last_error()).is_equal("invalid_network_preview")
	sim.free()
