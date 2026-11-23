extends GdUnitTestSuite

var _loadout: PackedInt32Array
var _modes: PackedInt32Array


func before() -> void:
	_loadout = Game.loadout.duplicate()
	_modes = Game.modes.duplicate()


func after() -> void:
	Game.loadout = _loadout
	Game.modes = _modes
	Music.release_streams()
	Sfx.release_streams()


func after_test() -> void:
	for child in Effects.game_viewport.get_children():
		child.queue_free()
		Effects.game_viewport.remove_child(child)
	await get_tree().process_frame


func _level(left := 6, right := 9, android := true, special := 0, rear := 10, modes := PackedInt32Array()) -> Node:
	EndlessSession.stop()
	Game.campaign_active = false
	Game.modes = modes
	Game.episode = 1
	Game.lvl_file_num = 9
	Game.difficulty = 2
	Game.rng_seed = 1
	Game.loadout = PackedInt32Array([1, 1, 1, rear, 1, 4, 2, left, right, special, 12345])
	var level: Node = Game.goto_scene(Game.SCENE_LEVEL)
	level._touch_pause = android
	for _frame in 60:
		await get_tree().physics_frame
	level.set_physics_process(false)
	level._sync_touch_weapons()
	return level


func _touch(level: Node, index: int, p: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = p
	event.pressed = pressed
	level._input(event)


func test_release_changes_mode_and_fires_only_the_selected_sidekick() -> void:
	var level := await _level()
	var state: PackedInt32Array = level.sim.hud_state()
	assert_int(state[28]).is_equal(13)
	assert_int(state[29]).is_equal(169)
	var mode: int = state[HudRenderer.WEAPON_MODE]
	_touch(level, 0, Vector2(30, 175), true)
	level._physics_process(1.0 / 35.0)
	assert_int(level.sim.hud_state()[HudRenderer.WEAPON_MODE]).is_equal(mode)
	_touch(level, 0, Vector2(30, 175), false)
	for i in 2:
		level._physics_process(1.0 / 35.0)
	assert_int(level.sim.hud_state()[HudRenderer.WEAPON_MODE]).is_not_equal(mode)
	state = level.sim.hud_state()
	var left: int = state[HudRenderer.SK0_AMMO]
	var right: int = state[HudRenderer.SK1_AMMO]
	_touch(level, 1, Vector2(8, 175), true)
	level._physics_process(1.0 / 35.0)
	assert_int(level.sim.hud_state()[HudRenderer.SK0_AMMO]).is_equal(left)
	_touch(level, 1, Vector2(8, 175), false)
	for i in 2:
		level._physics_process(1.0 / 35.0)
	assert_int(level.sim.hud_state()[HudRenderer.SK0_AMMO]).is_equal(left - 1)
	assert_int(level.sim.hud_state()[HudRenderer.SK1_AMMO]).is_equal(right)
	_touch(level, 2, Vector2(55, 175), true)
	_touch(level, 2, Vector2(55, 175), false)
	for i in 2:
		level._physics_process(1.0 / 35.0)
	assert_int(level.sim.hud_state()[HudRenderer.SK1_AMMO]).is_equal(right - 1)


func test_automatic_sidekick_hidden_charge_visible_and_pause_clears_pending() -> void:
	var level := await _level(1, 3)
	assert_int(level._touch_weapons.graphics[0]).is_equal(0)
	assert_int(level._touch_weapons.graphics[1]).is_greater(0)
	assert_float(level._touch_weapons.targets[1].position.x).is_equal(0.0)
	_touch(level, 0, Vector2(80, 175), true)
	assert_bool(level._touch_flight.active()).is_true()
	_touch(level, 0, Vector2(80, 175), false)
	_touch(level, 1, Vector2(15, 175), true)
	_touch(level, 1, Vector2(15, 175), false)
	level.set_paused(true)
	assert_int(level._touch_weapons.consume_mask()).is_equal(0)
	assert_bool(level._touch_weapons.visible).is_false()
	level.set_paused(false)
	level._sync_touch_weapons()
	assert_bool(level._touch_weapons.visible).is_true()


func _nonzero(vga: RefCounted, r: Rect2i) -> int:
	var pixels: PackedByteArray = vga.indices(HudRenderer.OVER_A)
	var n := 0
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			if pixels[y * 320 + x] != 0:
				n += 1
	return n


func test_missing_or_single_mode_rear_hides_mode_and_compacts_sidekick_actions() -> void:
	for rear in [0, 1]:
		var level := await _level(6, 9, true, 0, rear)
		assert_int(level.sim.hud_state()[32]).is_equal(0)
		assert_bool(level._touch_weapons.get_node("Mode").visible).is_false()
		assert_float(level._touch_weapons.targets[0].position.x).is_equal(0.0)
		assert_float(level._touch_weapons.targets[2].position.x).is_equal(18.0)
		var state: PackedInt32Array = level.sim.hud_state()
		_touch(level, 0, Vector2(29, 175), true)
		_touch(level, 0, Vector2(29, 175), false)
		for tick in 2:
			level._physics_process(1.0 / 35.0)
		assert_int(level.sim.hud_state()[HudRenderer.SK0_AMMO]).is_equal(state[HudRenderer.SK0_AMMO])
		assert_int(level.sim.hud_state()[HudRenderer.SK1_AMMO]).is_equal(state[HudRenderer.SK1_AMMO] - 1)
		_touch(level, 0, Vector2(55, 175), true)
		assert_bool(level._touch_flight.active()).is_true()
		_touch(level, 0, Vector2(55, 175), false)


func test_mode_only_and_right_sidekick_only_work_at_left_edge() -> void:
	var level := await _level(1, 1)
	assert_int(level.sim.hud_state()[32]).is_equal(1)
	assert_float(level._touch_weapons.targets[1].position.x).is_equal(0.0)
	var mode: int = level.sim.hud_state()[HudRenderer.WEAPON_MODE]
	_touch(level, 0, Vector2(8, 175), true)
	_touch(level, 0, Vector2(8, 175), false)
	for tick in 2:
		level._physics_process(1.0 / 35.0)
	assert_int(level.sim.hud_state()[HudRenderer.WEAPON_MODE]).is_not_equal(mode)
	level = await _level(0, 9, true, 0, 0)
	assert_float(level._touch_weapons.targets[2].position.x).is_equal(0.0)
	var ammo: int = level.sim.hud_state()[HudRenderer.SK1_AMMO]
	_touch(level, 0, Vector2(8, 175), true)
	_touch(level, 0, Vector2(8, 175), false)
	for tick in 2:
		level._physics_process(1.0 / 35.0)
	assert_int(level.sim.hud_state()[HudRenderer.SK1_AMMO]).is_equal(ammo - 1)


func test_super_arcade_mode_only_shown_for_distinct_specials() -> void:
	for sam in [1, 8]:
		var modes := PackedInt32Array([0, 0, 1, sam, 0, 0, 0, 0, 0, 0])
		var level := await _level(0, 0, true, 7, 0, modes)
		assert_int(level.sim.hud_state()[32]).is_equal(1 if sam == 1 else 0)
		assert_bool(level._touch_weapons.get_node("Mode").visible).is_equal(sam == 1)


func test_special_only_moves_to_bottom_row_and_fires_from_new_position() -> void:
	var level := await _level(0, 0, true, 7, 0)
	assert_vector(level._touch_weapons.targets[3].position).is_equal(Vector2(0, 162))
	assert_vector(level._touch_weapons.get_node("Special").position).is_equal(Vector2(2, 172))
	_touch(level, 0, Vector2(30, 150), true)
	assert_bool(level._touch_flight.active()).is_true()
	for tick in 4:
		level._physics_process(1.0 / 35.0)
	assert_bool(level._touch_weapons.special_ready).is_true()
	_touch(level, 0, Vector2(30, 150), false)
	_touch(level, 0, Vector2(120, 90), true)
	_touch(level, 1, Vector2(30, 175), true)
	level._physics_process(1.0 / 35.0)
	assert_bool(level._touch_weapons.special_ready).is_true()
	_touch(level, 1, Vector2(30, 175), false)
	for tick in 4:
		level._physics_process(1.0 / 35.0)
	assert_bool(level._touch_weapons.special_ready).is_false()
	assert_bool(level._touch_flight.active()).is_true()


func test_special_only_fires_from_its_button_while_steering_continues() -> void:
	var level := await _level(6, 9, true, 7)
	assert_bool(level._touch_weapons.special_equipped).is_true()
	assert_bool(level._touch_weapons.special_ready).is_true()
	for i in 3:
		_touch(level, 0, Vector2(120, 90), true)
		for tick in 4:
			level._physics_process(1.0 / 35.0)
		assert_bool(level._touch_weapons.special_ready).is_true()
		_touch(level, 0, Vector2(120, 90), false)
		level._physics_process(1.0 / 35.0)
	_touch(level, 0, Vector2(120, 90), true)
	_touch(level, 1, Vector2(8, 175), true)
	_touch(level, 1, Vector2(8, 175), false)
	for tick in 4:
		level._physics_process(1.0 / 35.0)
	assert_bool(level._touch_weapons.special_ready).is_true()
	_touch(level, 1, Vector2(30, 150), true)
	level._physics_process(1.0 / 35.0)
	assert_bool(level._touch_weapons.special_ready).is_true()
	_touch(level, 1, Vector2(30, 150), false)
	for tick in 4:
		level._physics_process(1.0 / 35.0)
	assert_bool(level._touch_weapons.special_ready).is_false()
	assert_bool(level._touch_flight.active()).is_true()
	assert_int(level._touch_flight.fire_mask()).is_equal(Game.MASK_FIRE)
	assert_float(level._touch_weapons.get_node("Special").modulate.r).is_less(1.0)
	level.set_paused(true)
	assert_int(level._touch_weapons.consume_mask()).is_equal(0)
	assert_bool(level._touch_weapons.visible).is_false()


func test_android_score_top_right_and_desktop_original_position() -> void:
	var level := await _level(0, 0, false)
	assert_object(level._touch_weapons).is_null()
	var hud: HudRenderer = level._hud_vga
	var state: PackedInt32Array = level.sim.hud_state()
	hud._draw_in_game_displays(state, PackedInt64Array())
	assert_int(_nonzero(hud.vga, Rect2i(28, 173, 65, 11))).is_greater(0)
	assert_int(_nonzero(hud.vga, Rect2i(220, 0, 68, 14))).is_equal(0)
	level._touch_pause = true
	level._sync_touch_weapons()
	hud._draw_in_game_displays(state, PackedInt64Array())
	assert_int(_nonzero(hud.vga, Rect2i(28, 173, 65, 11))).is_equal(0)
	assert_int(_nonzero(hud.vga, Rect2i(220, 0, 68, 14))).is_greater(0)
