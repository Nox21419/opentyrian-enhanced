extends GdUnitTestSuite


func _make(devices: Vector2i) -> Node:
	var sim: Node = auto_free(ClassDB.instantiate("TyrianSim"))
	sim.set_loadout(PackedInt32Array([11, 1, 1, 0, 1, 4, 2, 0, 0, 0, 0]))
	sim.set_modes(PackedInt32Array([1, 0, 0, 0, 0, 0, 0, 0, devices.x, devices.y]))
	sim.set_modes_extra(0, 0, 2, PackedInt32Array([1, 1, 1, 15, 1, 4, 2, 0, 0, 0]))
	assert_bool(sim.load_level(Game.data_dir, 1, 9, 2, 73)).is_true()
	return sim


func test_each_player_matches_shared_mouse_through_native_bridge() -> void:
	for target in 2:
		var devices := Vector2i(2, 1) if target == 0 else Vector2i(1, 2)
		var shared := _make(devices)
		var separate := _make(devices)
		for tick in 350:
			var dx := (tick * 7) % 81 - 40
			var dy := (tick * 11) % 81 - 40
			var mask := 0xf0 if tick % 61 < 43 else 0
			shared.set_mouse(mask, dx, dy)
			if target == 0:
				separate.set_player_mice(mask, dx, dy, 0, 0, 0)
			else:
				separate.set_player_mice(0, 0, 0, mask, dx, dy)
			shared.step(0x1a, 0x65)
			separate.step(0x1a, 0x65)
			assert_int(separate.state_hash()).is_equal(shared.state_hash())


func test_two_mice_move_separately_and_can_be_cleared() -> void:
	var sim := _make(Vector2i(2, 2))
	for _tick in 200:
		sim.step(0, 0)
	var p1: int = sim.player(0)[0]
	var p2: int = sim.player(1)[0]
	sim.set_player_mice(0x40, -8, 0, 0, 8, 0)
	for _tick in 10:
		sim.step(0, 0)
	assert_int(sim.player(0)[0]).is_less(p1)
	assert_int(sim.player(1)[0]).is_greater(p2)
	sim.clear_player_mice()
	sim.set_mouse(0, 0, 0)
	for _tick in 30:
		sim.step(0, 0)
	p1 = sim.player(0)[0]
	p2 = sim.player(1)[0]
	for _tick in 10:
		sim.step(0, 0)
	assert_int(sim.player(0)[0]).is_equal(p1)
	assert_int(sim.player(1)[0]).is_equal(p2)
