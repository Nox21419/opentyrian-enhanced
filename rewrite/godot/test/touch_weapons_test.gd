extends GdUnitTestSuite


func _hud(left := 13, right := 169, mode := true) -> PackedInt32Array:
	var h := PackedInt32Array()
	h.resize(33)
	h[28] = left
	h[29] = right
	h[30] = 94
	h[31] = 1
	h[32] = int(mode)
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
	for i in 4:
		var p: Vector2 = TouchWeapons.TARGETS[i].get_center()
		assert_bool(buttons.feed(_touch(i, p, true))).is_true()
		assert_int(buttons.consume_mask()).is_equal(0)
		assert_bool(buttons.feed(_touch(i, p, false))).is_true()
		assert_int(buttons.consume_mask()).is_equal(TouchWeapons.MASKS[i])
		assert_int(buttons.consume_mask()).is_equal(0)


func test_drag_off_and_back_or_to_another_button_cancels_permanently() -> void:
	var buttons := _buttons()
	for i in 4:
		var p: Vector2 = TouchWeapons.TARGETS[i].get_center()
		buttons.feed(_touch(i, p, true))
		assert_bool(buttons.feed(_drag(i, Vector2(150, 150)))).is_true()
		buttons.feed(_drag(i, p))
		buttons.feed(_touch(i, p, false))
		assert_int(buttons.consume_mask()).is_equal(0)
		buttons.feed(_touch(i, p, true))
		var other: Vector2 = TouchWeapons.TARGETS[(i + 1) % 4].get_center()
		buttons.feed(_drag(i, other))
		buttons.feed(_touch(i, other, false))
		assert_int(buttons.consume_mask()).is_equal(0)


func test_steering_across_buttons_never_claims_finger_or_fires() -> void:
	var buttons := _buttons()
	var flight := TouchFlight.new()
	var down := _touch(0, Vector2(100, 100), true)
	assert_bool(buttons.feed(down)).is_false()
	flight.feed(down)
	for i in 4:
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
	assert_int(buttons.target_at(Vector2(8, 175))).is_equal(1)
	assert_int(buttons.target_at(Vector2(55, 175))).is_equal(-1)
	assert_int(buttons.target_at(Vector2(30, 175))).is_equal(-1)


func test_available_controls_pack_left_and_keep_their_actions_and_widths() -> void:
	var buttons := _buttons()
	for combination in 8:
		var left := (combination & 1) != 0
		var mode := (combination & 2) != 0
		var right := (combination & 4) != 0
		buttons.update_state(_hud(13 if left else 0, 169 if right else 0, mode), true)
		var shown := [left, mode, right]
		var edge := 0.0
		for i in 3:
			if not shown[i]:
				assert_vector(buttons.targets[i].size).is_equal(Vector2.ZERO)
				continue
			assert_float(buttons.targets[i].position.x).is_equal(edge)
			assert_vector(buttons.targets[i].size).is_equal(TouchWeapons.TARGETS[i].size)
			var p: Vector2 = buttons.targets[i].get_center()
			buttons.feed(_touch(i, p, true))
			buttons.feed(_touch(i, p, false))
			assert_int(buttons.consume_mask()).is_equal(TouchWeapons.MASKS[i])
			assert_int(buttons.consume_mask()).is_equal(0)
			edge = buttons.targets[i].end.x
		assert_int(buttons.target_at(Vector2(edge, 175))).is_equal(3 if combination == 0 else -1)
		assert_bool(buttons.get_node("Mode").visible).is_equal(mode)
		assert_vector(buttons.targets[3].position).is_equal(Vector2(0, 162 if combination == 0 else 140))


func test_special_moves_with_its_target_and_cancels_held_touches_when_row_changes() -> void:
	var buttons := _buttons()
	buttons.feed(_touch(0, Vector2(30, 150), true))
	buttons.update_state(_hud(0, 0, false), true)
	assert_vector(buttons.get_node("Special").position).is_equal(Vector2(2, 172))
	assert_int(buttons.target_at(Vector2(30, 150))).is_equal(-1)
	buttons.feed(_touch(0, Vector2(30, 175), false))
	assert_int(buttons.consume_mask()).is_equal(0)
	buttons.feed(_touch(1, Vector2(30, 175), true))
	buttons.feed(_touch(1, Vector2(30, 175), false))
	assert_int(buttons.consume_mask()).is_equal(Game.MASK_SPECIAL)
	assert_int(buttons.consume_mask()).is_equal(0)
	buttons.feed(_touch(2, Vector2(30, 175), true))
	buttons.update_state(_hud(0, 0), true)
	assert_vector(buttons.get_node("Special").position).is_equal(Vector2(2, 150))
	buttons.feed(_touch(2, Vector2(30, 150), false))
	assert_int(buttons.consume_mask()).is_equal(0)


func test_relayout_cancels_held_and_pending_controls() -> void:
	var buttons := _buttons()
	buttons.feed(_touch(0, Vector2(30, 175), true))
	buttons.update_state(_hud(0), true)
	assert_int(buttons.target_at(Vector2(30, 175))).is_equal(2)
	buttons.feed(_touch(0, Vector2(30, 175), false))
	assert_int(buttons.consume_mask()).is_equal(0)
	buttons.feed(_touch(1, Vector2(8, 175), true))
	buttons.feed(_touch(1, Vector2(8, 175), false))
	buttons.update_state(_hud(0, 169, false), true)
	assert_int(buttons.consume_mask()).is_equal(0)
	assert_int(buttons.target_at(Vector2(8, 175))).is_equal(2)


func test_fast_repeated_mode_taps_have_a_release_tick_between_them() -> void:
	var buttons := _buttons()
	buttons.feed(_touch(0, Vector2(30, 175), true))
	buttons.feed(_touch(0, Vector2(30, 175), false))
	assert_int(buttons.consume_mask()).is_equal(Game.MASK_CHANGE_FIRE)
	buttons.feed(_touch(0, Vector2(30, 175), true))
	buttons.feed(_touch(0, Vector2(30, 175), false))
	assert_int(buttons.consume_mask()).is_equal(0)
	assert_int(buttons.consume_mask()).is_equal(Game.MASK_CHANGE_FIRE)


func test_special_hidden_without_equipment_and_dimmed_taps_do_not_queue() -> void:
	var buttons := _buttons()
	var p := TouchWeapons.TARGETS[3].get_center()
	var h := _hud()
	h[31] = 0
	buttons.update_state(h, true)
	assert_int(buttons.target_at(p)).is_equal(-1)
	assert_bool(buttons.get_node("Special").visible).is_false()
	h[31] = 1
	h[30] = 93
	buttons.update_state(h, true)
	assert_bool(buttons.get_node("Special").visible).is_true()
	assert_float(buttons.get_node("Special").modulate.r).is_less(1.0)
	buttons.feed(_touch(0, p, true))
	buttons.feed(_touch(0, p, false))
	h[30] = 94
	buttons.update_state(h, true)
	assert_int(buttons.consume_mask()).is_equal(0)
