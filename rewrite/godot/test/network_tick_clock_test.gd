extends GdUnitTestSuite

const Clock := preload("res://scripts/network_tick_clock.gd")
const Speed := preload("res://scripts/game_speed.gd")


func test_negotiated_original_speed_presets_ignore_local_override() -> void:
	var saved: int = Speed.speed_override
	var physics := Engine.physics_ticks_per_second
	Speed.speed_override = 1
	var expected := [14, 23, 28, 35, 49]
	for speed in range(1, 6):
		assert_int(Clock.ticks_per_second(speed)).is_equal(expected[speed - 1])
	assert_int(Clock.ticks_per_second(6)).is_equal(0)
	assert_int(Clock.ticks_per_second(0)).is_equal(0)
	assert_int(Engine.physics_ticks_per_second).is_equal(physics)
	Speed.speed_override = saved


func test_boss_slowdown_credit_matches_existing_pacing_through_recovery() -> void:
	var saved_speed: float = Effects.kill_slowmo
	var saved_credit: float = Effects.get("_tick_credit")
	Effects.set("_tick_credit", 0.0)
	var clock := Clock.new()
	var ticks := 0
	for _callback in 900:
		# The native renderer's existing ramp advances on simulation steps,
		# rather than on skipped physics callbacks.
		var speed := minf(1.0, 0.3 + float(ticks) * 0.006 * 0.7)
		Effects.kill_slowmo = speed
		var existing: bool = Effects.consume_tick()
		assert_bool(clock.consume_tick(speed)).is_equal(existing)
		assert_float(clock.credit).is_equal(float(Effects.get("_tick_credit")))
		if existing:
			ticks += 1
		if ticks == 220:
			break
	assert_int(ticks).is_equal(220)
	Effects.kill_slowmo = saved_speed
	Effects.set("_tick_credit", saved_credit)


func test_reset_drops_old_fractional_credit() -> void:
	var clock := Clock.new()
	assert_bool(clock.consume_tick(0.3)).is_false()
	clock.reset()
	assert_float(clock.credit).is_equal(0.0)
	assert_bool(clock.consume_tick(1.0)).is_true()
	assert_float(clock.credit).is_equal(0.0)
