extends GdUnitTestSuite


func _hud(left := 13, right := 169) -> PackedInt32Array:
	var h := PackedInt32Array()
	h.resize(30)
	h[28] = left
	h[29] = right
	return h


func _buttons() -> TouchWeapons:
	var buttons := TouchWeapons.new()
	add_child(auto_free(buttons))
	buttons.update_state(_hud(), true)
	return buttons


func _touch(index: int, p: Vector2, pressed: bool, cancelled := false) -> InputEventScreenTouch:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = p
	event.pressed = pressed
	event.canceled = cancelled
	return event


func _drag(index: int, p: Vector2) -> InputEventScreenDrag:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = p
	return event


func test_all_buttons_fire_only_on_release_and_clear_after_one_tick() -> void:
	var buttons := _buttons()
	for i in 3:
		var p: Vector2 = TouchWeapons.TARGETS[i].get_center()
		assert_bool(buttons.feed(_touch(i, p, true))).is_true()
		assert_int(buttons.consume_mask()).is_equal(0)
		assert_bool(buttons.feed(_touch(i, p, false))).is_true()
		assert_int(buttons.consume_mask()).is_equal(TouchWeapons.MASKS[i])
		assert_int(buttons.consume_mask()).is_equal(0)


func test_drag_off_and_back_or_to_another_button_cancels_permanently() -> void:
	var buttons := _buttons()
	for i in 3:
		var p: Vector2 = TouchWeapons.TARGETS[i].get_center()
		buttons.feed(_touch(i, p, true))
		assert_bool(buttons.feed(_drag(i, Vector2(150, 150)))).is_true()
		buttons.feed(_drag(i, p))
		buttons.feed(_touch(i, p, false))
		assert_int(buttons.consume_mask()).is_equal(0)
		buttons.feed(_touch(i, p, true))
		var other: Vector2 = TouchWeapons.TARGETS[(i + 1) % 3].get_center()
		buttons.feed(_drag(i, other))
		buttons.feed(_touch(i, other, false))
		assert_int(buttons.consume_mask()).is_equal(0)


func test_steering_across_buttons_never_claims_finger_or_fires() -> void:
	var buttons := _buttons()
	var flight := TouchFlight.new()
	var down := _touch(0, Vector2(100, 100), true)
	assert_bool(buttons.feed(down)).is_false()
	flight.feed(down)
	for i in 3:
		var p: Vector2 = TouchWeapons.TARGETS[i].get_center()
		var drag := _drag(0, p)
		assert_bool(buttons.feed(drag)).is_false()
		flight.feed(drag)
		assert_vector(flight.target).is_equal(p)
		assert_int(buttons.consume_mask()).is_equal(0)
	var up := _touch(0, Vector2(30, 175), false)
	assert_bool(buttons.feed(up)).is_false()
	flight.feed(up)
	assert_bool(flight.active()).is_false()
	assert_int(buttons.consume_mask()).is_equal(0)


func test_other_fingers_can_use_buttons_while_steering_continues() -> void:
	var buttons := _buttons()
	var flight := TouchFlight.new()
	flight.feed(_touch(0, Vector2(120, 90), true))
	buttons.feed(_touch(1, Vector2(8, 175), true))
	buttons.feed(_touch(2, Vector2(55, 175), true))
	buttons.feed(_touch(1, Vector2(8, 175), false))
	buttons.feed(_touch(2, Vector2(55, 175), false))
	assert_int(buttons.consume_mask()).is_equal(Game.MASK_LEFT_SIDEKICK | Game.MASK_RIGHT_SIDEKICK)
	assert_bool(flight.active()).is_true()
	assert_vector(flight.target).is_equal(Vector2(120, 90))


func test_cancel_hidden_or_disabled_controls_cannot_leave_pending_inputs() -> void:
	var buttons := _buttons()
	buttons.feed(_touch(0, Vector2(30, 175), true))
	buttons.feed(_touch(0, Vector2(30, 175), false, true))
	assert_int(buttons.consume_mask()).is_equal(0)
	buttons.feed(_touch(0, Vector2(30, 175), true))
	buttons.update_state(_hud(), false)
	assert_bool(buttons.visible).is_false()
	assert_bool(buttons.feed(_touch(0, Vector2(30, 175), false))).is_false()
	assert_int(buttons.consume_mask()).is_equal(0)
	buttons.update_state(_hud(0, 0), true)
	assert_int(buttons.target_at(Vector2(8, 175))).is_equal(-1)
	assert_int(buttons.target_at(Vector2(55, 175))).is_equal(-1)
	assert_int(buttons.target_at(Vector2(30, 175))).is_equal(1)


func test_fast_repeated_mode_taps_have_a_release_tick_between_them() -> void:
	var buttons := _buttons()
	buttons.feed(_touch(0, Vector2(30, 175), true))
	buttons.feed(_touch(0, Vector2(30, 175), false))
	assert_int(buttons.consume_mask()).is_equal(Game.MASK_CHANGE_FIRE)
	buttons.feed(_touch(0, Vector2(30, 175), true))
	buttons.feed(_touch(0, Vector2(30, 175), false))
	assert_int(buttons.consume_mask()).is_equal(0)
	assert_int(buttons.consume_mask()).is_equal(Game.MASK_CHANGE_FIRE)
