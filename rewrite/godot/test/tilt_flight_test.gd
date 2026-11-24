extends GdUnitTestSuite


func test_neutral_dead_zone_directions_sensitivity_and_speed_cap() -> void:
	var tilt := TiltFlight.new()
	assert_bool(tilt.calibrate(Vector3(0, 0, -9.8))).is_true()
	assert_vector(tilt.movement(Vector3(0.05, 0.05, -9.8), 5)).is_equal(Vector2i.ZERO)
	for frame in 20:
		tilt.movement(Vector3(3, -3, -8), 5)
	var movement := tilt.movement(Vector3(3, -3, -8), 5)
	assert_int(movement.x).is_greater(0)
	assert_int(movement.y).is_greater(0)
	var low := tilt.movement(Vector3(3, -3, -8), 1)
	var high := tilt.movement(Vector3(3, -3, -8), 10)
	assert_int(high.x).is_greater(low.x)
	assert_int(high.y).is_greater(low.y)
	for frame in 20:
		tilt.movement(Vector3(-8, 8, -1), 10)
	assert_vector(tilt.movement(Vector3(-8, 8, -1), 10)).is_equal(Vector2i(-30, -30))
	assert_bool(tilt.calibrate(Vector3(-8, 8, -1))).is_true()
	assert_vector(tilt.movement(Vector3(-8, 8, -1), 10)).is_equal(Vector2i.ZERO)


func test_late_sensor_reading_invalid_samples_and_upright_neutral() -> void:
	var tilt := TiltFlight.new()
	assert_bool(tilt.calibrate(Vector3.ZERO)).is_false()
	assert_vector(tilt.movement(Vector3.ZERO, 5)).is_equal(Vector2i.ZERO)
	assert_bool(tilt.calibrated).is_false()
	assert_vector(tilt.movement(Vector3(0, -9.8, 0), 5)).is_equal(Vector2i.ZERO)
	assert_bool(tilt.calibrated).is_true()
	for frame in 20:
		tilt.movement(Vector3(0, -9, 3), 5)
	assert_int(tilt.movement(Vector3(0, -9, 3), 5).y).is_greater(0)
	assert_vector(tilt.movement(Vector3(INF, 0, 0), 5)).is_equal(Vector2i.ZERO)
	assert_bool(tilt.calibrate(Vector3.ZERO)).is_false()
	assert_vector(tilt.neutral).is_equal(Vector3(0, -1, 0))


func test_native_input_preserves_mouse_limit_inertia_and_independent_fire() -> void:
	var sim = ClassDB.instantiate("TyrianSim")
	sim.set_loadout(PackedInt32Array(Game.NEW_GAME_LOADOUT))
	assert_bool(sim.load_level(Game.data_dir, 1, 9, 2, 1)).is_true()
	# First tick applies the normal spawn-position bounds before measuring input.
	sim.step(0, 0)
	var tilt := TiltFlight.new()
	tilt.calibrate(Vector3(0, 0, -9.8))
	var shots_seen := false
	for tick in 20:
		var before: PackedInt32Array = sim.player(0)
		var movement := tilt.movement(Vector3(8, -8, -1), 10)
		sim.set_mouse(Game.MASK_FIRE if tick >= 10 else 0, movement.x, movement.y)
		sim.step(0, 0)
		var after: PackedInt32Array = sim.player(0)
		assert_int(absi(after[0] - before[0])).is_less_equal(12)
		assert_int(absi(after[1] - before[1])).is_less_equal(12)
		if tick < 10:
			assert_bool(sim.player_shots().is_empty()).is_true()
		shots_seen = shots_seen or not sim.player_shots().is_empty()
	assert_bool(shots_seen).is_true()
	sim.free()


func test_sensitivity_half_low_unchanged_high_and_even_tilt_steps() -> void:
	var tilt := TiltFlight.new()
	# The original level-1 range was 32 degrees beyond the two-degree dead zone.
	assert_int(tilt._axis(14.8, 34.0)).is_equal(12)
	assert_int(tilt._axis(14.8, 66.0)).is_equal(6)
	for sensitivity in range(1, 11):
		# Midpoint of each evenly spaced response range should give half input.
		var full_angle := 66.0 - float(sensitivity - 1) * 58.0 / 9.0
		var angle := deg_to_rad(2.0 + (full_angle - 2.0) / 2.0)
		tilt.calibrate(Vector3(0, 0, -9.8))
		var gravity := Vector3(sin(angle), 0, -cos(angle)) * 9.8
		for frame in 50:
			tilt.movement(gravity, sensitivity)
		assert_int(tilt.movement(gravity, sensitivity).x).is_equal(15)
	# Level 10 keeps the previous response through the real movement path.
	for degrees in [0.0, 1.0, 2.0, 4.0, 6.0, 8.0, 20.0]:
		var angle := deg_to_rad(degrees)
		var gravity := Vector3(sin(angle), 0, -cos(angle)) * 9.8
		tilt.calibrate(Vector3(0, 0, -9.8))
		for frame in 50:
			tilt.movement(gravity, 10)
		assert_int(tilt.movement(gravity, 10).x).is_equal(tilt._axis(degrees, 8.0))
