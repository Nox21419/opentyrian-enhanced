extends GdUnitTestSuite


func after() -> void:
	Music.release_streams()
	Sfx.release_streams()


func test_diagnostic_requires_loaded_sim_and_covers_pending_input_without_mutation() -> void:
	var sim: Node = ClassDB.instantiate("TyrianSim")
	assert_str(sim.network_diagnostic_digest()).is_empty()
	sim.set_loadout(PackedInt32Array([11, 1, 1, 0, 1, 4, 2, 0, 0, 0, 0]))
	assert_bool(sim.load_level(Game.data_dir, 1, 9, 3, 73)).is_true()
	var original: String = sim.network_diagnostic_digest()
	var legacy: int = sim.state_hash()
	assert_int(original.length()).is_equal(64)
	assert_str(sim.network_diagnostic_digest()).is_equal(original)
	sim.set_player_mice(0, 4, -4, 0, -4, 4)
	assert_int(sim.state_hash()).is_equal(legacy)
	assert_str(sim.network_diagnostic_digest()).is_not_equal(original)
	sim.clear_player_mice()
	assert_str(sim.network_diagnostic_digest()).is_equal(original)
	sim.step(16, 0)
	var next: String = sim.network_diagnostic_digest()
	assert_str(next).is_not_equal(original)
	assert_str(sim.network_diagnostic_digest()).is_equal(next)
	sim.free()
