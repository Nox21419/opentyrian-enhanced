extends GdUnitTestSuite

const Policy := preload("res://scripts/network_initial_configuration.gd")
const Setup := preload("res://test/fixtures/network_setup.gd")
const Startup := preload("res://scripts/network_startup.gd")


func test_initial_rules_use_actual_episode_script_without_campaign_mutation() -> void:
	var policy := Policy.new(Game.data_dir)
	var episode: int = Game.episode
	var active: bool = Game.campaign_active
	for ep in range(1, 6):
		for difficulty in [1, 2, 3, 4, 6, 8]:
			var level := policy.first_level(ep, difficulty)
			assert_bool(level.is_empty()).is_false()
			assert_str(level.entry.stop).is_equal("shop")
			var config := Setup.configuration()
			config.episode = ep
			config.initial_difficulty = difficulty
			config.difficulty = difficulty + 1
			config.level_file = level.lvl_file_num
			assert_bool(policy.valid(config)).is_true()
	assert_int(Game.episode).is_equal(episode)
	assert_bool(Game.campaign_active).is_equal(active)


func test_grammar_valid_but_wrong_initial_rules_are_rejected() -> void:
	var policy := Policy.new(Game.data_dir)
	var original := Setup.configuration()
	original.level_file = policy.first_level(1, 2).lvl_file_num
	for field in ["loadout1", "loadout2", "cash1", "cash2", "devices", "level_file"]:
		var config := original.duplicate(true)
		match field:
			"loadout1", "loadout2":
				config[field][0] = 255
			"cash1", "cash2":
				config[field] = "0000000000000001"
			"devices":
				config.devices = [1, 2]
			"level_file":
				config.level_file = 65535
		assert_bool(policy.valid(config)).is_false()
	assert_bool(policy.valid(original)).is_true()


func test_missing_content_and_invalid_episode_fail_closed() -> void:
	var missing := Policy.new("user://missing-network-data")
	assert_bool(missing.valid(Setup.configuration())).is_false()
	var policy := Policy.new(Game.data_dir)
	assert_bool(policy.first_level(0, 2).is_empty()).is_true()
	assert_bool(policy.first_level(6, 2).is_empty()).is_true()
	assert_bool(policy.first_level(1, 5).is_empty()).is_true()
	var result := policy.first_level(1, 2)
	result.lvl_file_num = 65535
	assert_bool(policy.first_level(1, 2).lvl_file_num != 65535).is_true()


func test_startup_uses_initial_rules_before_accepting_a_proposal() -> void:
	var policy := Policy.new(Game.data_dir)
	var host := Startup.new(1, Setup.identity(), policy.valid)
	var guest := Startup.new(2, Setup.identity(), policy.valid)
	for message in host.take_messages():
		guest.receive(message)
	for message in guest.take_messages():
		host.receive(message)
	var config := Setup.configuration()
	config.level_file = policy.first_level(1, 2).lvl_file_num
	assert_bool(host.propose(config, "12".repeat(16), 1)).is_true()
	for message in host.take_messages():
		guest.receive(message)
	for message in guest.take_messages():
		host.receive(message)
	assert_int(host.phase).is_equal(Startup.Phase.AGREED)
	assert_int(guest.phase).is_equal(Startup.Phase.AGREED)
	assert_bool(host.start()).is_false()
