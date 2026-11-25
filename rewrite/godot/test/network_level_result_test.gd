extends GdUnitTestSuite

const Result := preload("res://scripts/network_level_result.gd")
const Fixture := preload("res://test/fixtures/network_setup.gd")


class FinishedSimulation:
	extends Node
	var ended := true
	var ticks := 47
	var digest := "ab".repeat(32)
	var cash := [-1, 4294967296]
	var values := {
		"all_players_alive": false,
		"any_player_alive": true,
		"loadout": PackedInt32Array([11, 1, 2, 0, 1, 4, 2, 0, 0, 0, 3]),
		"loadout2": PackedInt32Array([1, 1, 1, 15, 3, 4, 2, 0, 0, 0, 4]),
		"enemy_killed": 12,
		"total_enemy": 17,
		"next_level": 6,
		"bonus_level": true
	}

	func level_ended() -> bool:
		return ended

	func tick() -> int:
		return ticks

	func network_diagnostic_digest() -> String:
		return digest

	func level_stats() -> Dictionary:
		return values

	func player_dict(index: int) -> Dictionary:
		return {"cash": cash[index]}

	func campaign_carry() -> PackedInt32Array:
		return PackedInt32Array([3, 4, 5, 6, 1, 2, 7])


func test_snapshot_retains_two_players_routes_and_exact_cash_without_aliasing() -> void:
	var native: Node = auto_free(FinishedSimulation.new())
	var result := Result.new()
	assert_bool(result.capture(native, Fixture.configuration(), "TYRIAN", 47)).is_true()
	var record := result.record()
	assert_int(record.stats.cash).is_equal(-1)
	assert_int(record.stats.cash2).is_equal(4294967296)
	assert_bool(record.stats.any_player_alive).is_true()
	assert_bool(record.stats.all_players_alive).is_false()
	assert_int(record.stats.next_level).is_equal(6)
	assert_array(Array(record.stats.carry)).is_equal([3, 4, 5, 6, 1, 2, 7])
	assert_int(record.stats.loadout2[4]).is_equal(3)
	var digest: String = record.digest
	record.stats.loadout2[4] = 99
	native.values.loadout[2] = 99
	assert_int(result.record().stats.loadout2[4]).is_equal(3)
	assert_int(result.record().stats.loadout[2]).is_equal(2)
	assert_str(result.record().digest).is_equal(digest)


func test_capture_requires_ended_and_fully_presented_tick_and_clears_old_result() -> void:
	var native: Node = auto_free(FinishedSimulation.new())
	var result := Result.new()
	assert_bool(result.capture(native, Fixture.configuration(), "TYRIAN", 47)).is_true()
	assert_bool(result.capture(native, Fixture.configuration(), "TYRIAN", 46)).is_false()
	assert_dict(result.record()).is_empty()
	native.ended = false
	assert_bool(result.capture(native, Fixture.configuration(), "TYRIAN", 47)).is_false()


func test_canonical_encoding_preserves_integer_bits_types_order_and_rejects_objects() -> void:
	assert_array(Array(Result.canonical_bytes({"b": [1, true], "a": -1}))).is_equal(
		Array(Result.canonical_bytes({"a": -1, "b": [1, true]}))
	)
	assert_bool(Result.canonical_bytes(1) == Result.canonical_bytes(true)).is_false()
	assert_bool(Result.canonical_bytes(4294967296) == Result.canonical_bytes(0)).is_false()
	assert_bool(Result.canonical_bytes(-1) == Result.canonical_bytes(9223372036854775807)).is_false()
	assert_bool(Result.canonical_bytes(1.5).is_empty()).is_true()
	assert_bool(Result.canonical_bytes(self).is_empty()).is_true()
	assert_bool(Result.canonical_bytes({1: "bad"}).is_empty()).is_true()
	assert_bool(Result.canonical_bytes("x".repeat(4097)).is_empty()).is_true()
	assert_bool(Result.canonical_bytes({"x".repeat(4097): 1}).is_empty()).is_true()


func test_natural_native_completion_result_is_read_only_and_repeatable() -> void:
	var config := Fixture.configuration()
	var native: Node = auto_free(ClassDB.instantiate("TyrianSim"))
	var mods: RefCounted = ClassDB.instantiate("TyrianMods")
	mods.load(Game.data_dir, PackedStringArray())
	native.set_mods(mods)
	assert_bool(native.prepare_network_level(Game.data_dir, config)).is_true()
	for i in 20000:
		if native.level_ended():
			break
		native.step(0x100, 0)
		if i % 1000 == 0:
			await get_tree().process_frame
	assert_bool(native.level_ended()).is_true()
	var before: String = native.network_diagnostic_digest()
	var result := Result.new()
	assert_bool(result.capture(native, config, "TYRIAN", native.tick())).is_true()
	var record := result.record()
	assert_bool(result.capture(native, config, "TYRIAN", native.tick())).is_true()
	assert_str(result.record().digest).is_equal(record.digest)
	assert_str(native.network_diagnostic_digest()).is_equal(before)
	assert_array(Array(record.stats.loadout2)).is_equal(Array(native.level_stats().loadout2))
