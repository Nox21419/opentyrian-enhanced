extends GdUnitTestSuite

const Config := preload("res://scripts/network_configuration.gd")
const Protocol := preload("res://scripts/network_startup_protocol.gd")
const Fixture := preload("res://test/fixtures/network_setup.gd")


func test_config_roundtrip_preserves_u64_fields_and_digest_is_key_order_independent() -> void:
	var config := Fixture.configuration()
	config.cash2 = "ffffffffffffffff"
	assert_bool(Config.valid(config)).is_true()
	var json: Variant = JSON.parse_string(JSON.stringify(Config.values(config)))
	assert_dict(Config.from_values(json)).is_equal(config)
	var reversed := {}
	var keys: Array = config.keys()
	keys.reverse()
	for key in keys:
		reversed[key] = config[key]
	assert_str(Config.digest(reversed)).is_equal(Config.digest(config))
	var different: Dictionary = config.duplicate(true)
	different.hitstop = false
	assert_str(Config.digest(different)).is_not_equal(Config.digest(config))
	var copy: Array = Config.values(config)
	copy[6][0] = 42
	assert_int(config.loadout1[0]).is_equal(11)


func test_config_requires_exact_keys_valid_original_difficulties_and_device_bounds() -> void:
	for field in Config.FIELDS:
		var config := Fixture.configuration()
		config.erase(field)
		assert_bool(Config.valid(config)).is_false()
	for pair in [
		["extra", 1],
		["episode", 6],
		["episode", 1.0],
		["difficulty", 2],
		["initial_difficulty", 5],
		["seed", "1"],
		["cash1", "FF".repeat(8)],
		["mode", "endless"],
		["hitstop", 1],
		["devices", [0, 3]],
		["loadout1", []],
		["input_delay", 9],
		["level_file", 0],
		["processor_type", 7]
	]:
		var config := Fixture.configuration()
		config[pair[0]] = pair[1]
		assert_bool(Config.valid(config)).is_false()
	var values: Array = Config.values(Fixture.configuration())
	values[1] = 1.5
	assert_dict(Config.from_values(values)).is_empty()
	values = Config.values(Fixture.configuration())
	values[6][0] = true
	assert_dict(Config.from_values(values)).is_empty()


func test_startup_codec_is_bounded_and_rejects_unknown_objects_roles_and_fractional_numbers() -> void:
	var message := {
		"kind": "config",
		"player": 1,
		"session": "12".repeat(16),
		"epoch": 1,
		"sequence": 1,
		"config": Fixture.configuration(),
		"digest": Config.digest(Fixture.configuration())
	}
	assert_dict(Protocol.decode(Protocol.encode(message), 1)).is_equal(message)
	assert_dict(Protocol.decode(Protocol.encode(message), 2)).is_empty()
	for packet in [
		PackedByteArray([255, 255, 255, 255, 255]),
		"OT2S".to_utf8_buffer() + PackedByteArray([255]),
		PackedByteArray(),
		"OT2S{}".to_utf8_buffer(),
		("OT2S" + "[".repeat(3000)).to_utf8_buffer(),
		'OT2S[1,"hello",true]'.to_utf8_buffer(),
		'OT2S[1.5,"hello",1]'.to_utf8_buffer(),
		"OT2S[".to_utf8_buffer()
	]:
		assert_dict(Protocol.decode(packet, 1)).is_empty()
	message.digest = "ff".repeat(32)
	assert_bool(Protocol.encode(message).is_empty()).is_true()
	message.digest = Config.digest(message.config)
	message.extra = "unknown"
	assert_bool(Protocol.encode(message).is_empty()).is_true()


func test_simulation_effect_prerequisites_are_negotiated_and_arcade_combos_stay_off() -> void:
	var config := Fixture.configuration()
	config.explosion_style = 2
	assert_dict(Config.core_options(config)).is_equal({"hitstop": true, "modern_explosions": true, "combo_frame_ms": 0})
	for pair in [["particles", false], ["screenshake", false], ["processor_type", 1], ["explosion_style", 1]]:
		var changed := config.duplicate(true)
		changed[pair[0]] = pair[1]
		assert_bool(Config.core_options(changed).modern_explosions).is_false()
		assert_str(Config.digest(changed)).is_not_equal(Config.digest(config))
	config.combos = false
	config.hitstop = false
	assert_int(Config.core_options(config).combo_frame_ms).is_equal(0)
	assert_bool(Config.core_options(config).hitstop).is_false()
	config.particles = 1
	assert_bool(Config.valid(config)).is_false()
	assert_dict(Config.core_options(config)).is_empty()


func test_previous_startup_version_and_short_configuration_are_rejected() -> void:
	var hello := {"kind": "hello", "player": 1, "identity": Fixture.identity()}
	var packet := Protocol.encode(hello)
	var json := JSON.new()
	assert_int(json.parse(packet.slice(4).get_string_from_utf8())).is_equal(OK)
	var body: Array = json.data
	body[0] = 1
	assert_dict(Protocol.decode(("OT2S" + JSON.stringify(body)).to_utf8_buffer(), 1)).is_empty()
	var old := Config.values(Fixture.configuration())
	old.resize(19)
	assert_dict(Config.from_values(old)).is_empty()
