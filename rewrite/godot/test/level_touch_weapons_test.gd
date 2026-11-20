extends GdUnitTestSuite

var _loadout: PackedInt32Array


func before() -> void:
	_loadout = Game.loadout.duplicate()


func after() -> void:
	Game.loadout = _loadout
	Music.release_streams()
	Sfx.release_streams()


func after_test() -> void:
	for child in Effects.game_viewport.get_children():
		child.queue_free()
		Effects.game_viewport.remove_child(child)
	await get_tree().process_frame


func _level(left := 6, right := 9, android := true) -> Node:
	EndlessSession.stop()
	Game.campaign_active = false
	Game.modes = PackedInt32Array()
	Game.episode = 1
	Game.lvl_file_num = 9
	Game.difficulty = 2
	Game.rng_seed = 1
	Game.loadout = PackedInt32Array([1, 1, 1, 10, 1, 4, 2, left, right, 0, 12345])
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
	_touch(level, 0, Vector2(8, 175), true)
	assert_bool(level._touch_flight.active()).is_true()
	_touch(level, 0, Vector2(8, 175), false)
	_touch(level, 1, Vector2(30, 175), true)
	_touch(level, 1, Vector2(30, 175), false)
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
