extends GdUnitTestSuite


func test_held_finger_tracks_absolute_target_and_fires_until_release() -> void:
	var flight := TouchFlight.new()
	flight.feed(_touch(2, Vector2(200, 100), true))
	assert_int(flight.fire_mask()).is_equal(Game.MASK_FIRE)
	assert_vector(flight.movement(Vector2i(100, 140), -24)).is_equal(Vector2i(30, -30))
	# No new drag event is needed for the next tick to approach a held finger.
	assert_vector(flight.movement(Vector2i(220, 100), -24)).is_equal(Vector2i(16, 0))
	assert_vector(flight.movement(Vector2i(224, 100), -24)).is_equal(Vector2i.ZERO)
	assert_int(flight.fire_mask()).is_equal(Game.MASK_FIRE)
	flight.feed(_touch(2, Vector2(-100, -100), false))
	assert_int(flight.fire_mask()).is_equal(0)
	assert_vector(flight.movement(Vector2i(100, 100), -24)).is_equal(Vector2i.ZERO)


func test_extra_fingers_hud_and_cancel_cannot_hijack_or_stick_controls() -> void:
	var flight := TouchFlight.new()
	flight.feed(_touch(0, Vector2(300, 100), true))
	assert_bool(flight.active()).is_false()
	flight.feed(_touch(3, Vector2(80, 80), true))
	flight.feed(_touch(4, Vector2(200, 150), true))
	flight.feed(_touch(4, Vector2.ZERO, false))
	assert_vector(flight.target).is_equal(Vector2(80, 80))
	assert_bool(flight.active()).is_true()
	var drag := InputEventScreenDrag.new()
	drag.index = 3
	drag.position = Vector2(999, 999)
	flight.feed(drag)
	assert_vector(flight.movement(Vector2i(256, 160), -24)).is_equal(Vector2i.ZERO)
	var cancel := _touch(3, Vector2.ZERO, true)
	cancel.canceled = true
	flight.feed(cancel)
	assert_bool(flight.active()).is_false()
	flight.feed(_touch(0, Vector2(80, 80), true))
	flight.reset()
	assert_int(flight.fire_mask()).is_equal(0)


func test_touch_uses_same_display_mapping_as_menu_pointer() -> void:
	var saved: Vector2 = Effects._screen.size
	Effects._screen.size = Vector2(320, 240)
	var event := _touch(0, Vector2(160, 120), true)
	var mapped = Effects.touch_event_in_game_pixels(event)
	assert_vector(mapped.position).is_equal(Vector2(160, 100))
	assert_vector(event.position).is_equal(Vector2(160, 120))
	Effects._screen.size = saved


func test_level_ignores_emulated_mouse_and_clears_touch_on_pause_and_focus_loss() -> void:
	var level = load("res://scripts/level.gd").new()
	level._input(_touch(0, Vector2(80, 80), true))
	assert_bool(level._touch_flight.active()).is_true()
	var mouse := InputEventMouseButton.new()
	mouse.device = InputEvent.DEVICE_ID_EMULATION
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	level._input(mouse)
	assert_int(level._mouse_mask).is_equal(0)
	level.set_paused(true)
	assert_bool(level._touch_flight.active()).is_false()
	level.set_paused(false)
	level._input(_touch(0, Vector2(80, 80), true))
	level._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert_bool(level._touch_flight.active()).is_false()
	level.free()


func test_native_ship_moves_to_stationary_finger_while_shooting() -> void:
	var sim = ClassDB.instantiate("TyrianSim")
	assert_bool(sim.load_level(Game.data_dir, 1, 9, 2, 1)).is_true()
	sim.set_dev_god_mode(true)
	var flight := TouchFlight.new()
	flight.feed(_touch(0, Vector2(160, 100), true))
	var shots_seen := false
	for tick in 60:
		var player: PackedInt32Array = sim.player(0)
		var movement := flight.movement(Vector2i(player[0], player[1]), -24)
		sim.set_mouse(flight.fire_mask(), movement.x, movement.y)
		sim.step(0, 0)
		shots_seen = shots_seen or not sim.player_shots().is_empty()
	var final: PackedInt32Array = sim.player(0)
	assert_int(absi(final[0] - 184)).is_less_equal(4)
	assert_int(absi(final[1] - 100)).is_less_equal(4)
	assert_bool(shots_seen).is_true()
	sim.free()


func _touch(index: int, position: Vector2, pressed: bool) -> InputEventScreenTouch:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = position
	event.pressed = pressed
	return event
