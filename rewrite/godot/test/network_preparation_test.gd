extends GdUnitTestSuite

const Preparation := preload("res://scripts/network_preparation.gd")
const Rules := preload("res://scripts/network_initial_configuration.gd")
const Startup := preload("res://scripts/network_startup.gd")
const Setup := preload("res://test/fixtures/network_setup.gd")


func after() -> void:
	Music.release_streams()
	Sfx.release_streams()


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
