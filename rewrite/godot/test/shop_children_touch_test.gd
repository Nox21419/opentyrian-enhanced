extends GdUnitTestSuite


func before() -> void:
	EndlessSession.stop()
	Game.modes = PackedInt32Array()
	TyrianControls.install()


func after() -> void:
	Game.campaign_active = false
	Music.release_streams()
	Sfx.release_streams()


func after_test() -> void:
	for child in Effects.game_viewport.get_children():
		child.queue_free()
		Effects.game_viewport.remove_child(child)
	await get_tree().process_frame
	await get_tree().process_frame
	Game.campaign_active = false
	Game.shop_menu_rows = {}


## Shop of section 4 of episode 1 (same state as shop_sounds_test).
func _open_shop(rear := 0) -> Node:
	Game.loadout = PackedInt32Array([1, 1, 1, rear, 1, 4, 2, 0, 0, 0, 40000])
	Game.campaign_active = true
	Game.episode = 1
	Game.main_level = 4
	var r: Dictionary = Game.campaign().run_script(1, 4, 2, 1, true)
	Game.shop_section = int(r.get("section", 4))
	Game.shop_items_available = r.get("items_available", [])
	var m: PackedInt32Array = r.get("map", PackedInt32Array())
	Game.map_sections = PackedInt32Array()
	Game.map_planets = PackedInt32Array()
	for i in range(1, m.size(), 2):
		Game.map_planets.append(m[i - 1])
		Game.map_sections.append(m[i])
	Game.debrief = {"cube_max": 0}
	var shop: Node = Game.goto_scene(Game.SCENE_SHOP)
	for _frame in 3000:
		if shop.idle and shop.get("_shop") != null:
			break
		await get_tree().process_frame
	shop.set("_touch_root", true)
	shop.set("_touch_children", true)
	return shop


func _button(shop: Node, p: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = p
	event.pressed = pressed
	shop.handle_mouse(event)


func _tap(shop: Node, p: Vector2) -> void:
	_button(shop, p, true)
	_button(shop, p, false)


func _open_upgrade(shop: Node) -> void:
	shop._apply_hover(4)
	shop.handle_action(TyrianControls.ACCEPT)


func test_upgrade_category_waits_for_release_and_cancels_drag() -> void:
	var shop := await _open_shop()
	_open_upgrade(shop)
	_button(shop, Vector2(220, 58), true)
	assert_int(int(shop._state.menu)).is_equal(1)
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(100, 58)
	motion.relative = Vector2(-120, 0)
	shop.handle_mouse(motion)
	_button(shop, Vector2(220, 58), false)
	assert_int(int(shop._state.menu)).is_equal(1)
	_tap(shop, Vector2(220, 58))
	assert_int(int(shop._state.menu)).is_equal(4)


func test_item_purchase_and_power_arrows_wait_for_release() -> void:
	var shop := await _open_shop()
	_open_upgrade(shop)
	_tap(shop, Vector2(220, 58))  # Front Gun
	var owned := int(shop._state.owned_item)
	var cash := int(shop._state.cash)
	var chosen := -1
	for i in mini(5, shop._state.items.size()):
		if int(shop._state.items[i]) != owned and int(shop._state.costs[i]) > 0 and int(shop._state.costs[i]) < cash:
			chosen = i
			break
	assert_int(chosen).is_greater_equal(0)
	var p := Vector2(220, 42 + (chosen - shop._shop_scroll) * 26)
	var expected := int(shop._state.items[chosen])
	_button(shop, p, true)
	assert_int(int(shop._state.cash)).is_equal(cash)
	assert_int(int(shop._state.owned_item)).is_equal(owned)
	var expected_cash := cash - int(shop._state.costs[chosen])
	_button(shop, p, false)
	assert_int(int(shop._state.owned_item)).is_equal(expected)
	shop.handle_action(TyrianControls.BACK)
	assert_int(int(shop._shop.loadout()[10])).is_equal(expected_cash)
	assert_int(int(shop._shop.loadout()[1])).is_equal(expected)
	shop._apply_hover(3)
	shop.handle_action(TyrianControls.ACCEPT)
	var before: PackedInt32Array = shop._shop.loadout()
	_button(shop, Vector2(125, 155), true)
	assert_bool(shop._shop.loadout() == before).is_true()
	_button(shop, Vector2(125, 155), false)
	assert_int(int(shop._shop.loadout()[2])).is_equal(int(before[2]) + 1)


func test_data_reader_exit_waits_and_dragging_away_cancels() -> void:
	var shop := await _open_shop()
	shop._shop.set_cubes(Game.data_dir, 1, PackedInt32Array([1]), 1, TyrianText.language)
	shop._state = shop._shop.state()
	shop._apply_hover(2)
	shop.handle_action(TyrianControls.ACCEPT)
	assert_int(int(shop._state.menu)).is_equal(7)
	_button(shop, Vector2(220, 42), true)
	assert_int(int(shop._state.menu)).is_equal(7)
	_button(shop, Vector2(220, 42), false)
	assert_int(int(shop._state.menu)).is_equal(8)
	_button(shop, Vector2(270, 165), true)
	assert_int(int(shop._state.menu)).is_equal(8)
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(100, 165)
	motion.relative = Vector2(-170, 0)
	shop.handle_mouse(motion)
	_button(shop, Vector2(270, 165), false)
	assert_int(int(shop._state.menu)).is_equal(8)
	_tap(shop, Vector2(270, 165))
	assert_int(int(shop._state.menu)).is_equal(7)


func test_next_level_exit_waits_for_release() -> void:
	var shop := await _open_shop()
	shop._apply_hover(6)
	shop.handle_action(TyrianControls.ACCEPT)
	var exit_row := int(shop._state.menu_choices)
	var p := Vector2(220, 42 + 16 * (exit_row - 2) + 16)
	_button(shop, p, true)
	assert_int(int(shop._state.menu)).is_equal(3)
	_button(shop, p, false)
	assert_int(int(shop._state.menu)).is_equal(0)


func _open_rear(rear := 10) -> Node:
	var shop := await _open_shop(rear)
	shop.set("_touch_rear_mode", true)
	_open_upgrade(shop)
	shop._apply_hover(4)
	shop.handle_action(TyrianControls.ACCEPT)
	return shop


func _indicator(shop: Node) -> PackedByteArray:
	shop._weapon_sim_frame(4, shop._shop.loadout())
	var pixels: PackedByteArray = shop.vga.indices(TyrianScreen.VGA_SCREEN)
	var strip := PackedByteArray()
	# The original two mode lamps sit on the left frame, outside the starfield.
	for y in range(56, 72):
		for x in range(3, 8):
			strip.append(pixels[y * 320 + x])
	return strip


func test_rear_mode_hint_matches_slash_on_release() -> void:
	var shop := await _open_rear()
	assert_bool(shop._rear_touch_hint_visible()).is_true()
	var before := _indicator(shop)
	var equipment: PackedInt32Array = shop._shop.loadout()
	var cash := int(shop._state.cash)
	_button(shop, Vector2(80, 140), true)
	assert_bool(_indicator(shop) == before).is_true()
	_button(shop, Vector2(80, 140), false)
	assert_bool(_indicator(shop) == before).is_false()
	assert_bool(shop._shop.loadout() == equipment).is_true()
	assert_int(int(shop._state.cash)).is_equal(cash)
	# The existing keyboard command cycles the same state back to the first lamp.
	shop.handle_event(TyrianControls.key_event(KEY_SLASH))
	assert_bool(_indicator(shop) == before).is_true()


func test_rear_mode_drag_off_cancels_and_single_mode_has_no_target() -> void:
	var shop := await _open_rear()
	var before := _indicator(shop)
	_button(shop, Vector2(80, 140), true)
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(150, 140)
	motion.relative = Vector2(70, 0)
	shop.handle_mouse(motion)
	_button(shop, Vector2(80, 140), false)
	assert_bool(_indicator(shop) == before).is_true()
	shop = await _open_rear(7)
	assert_bool(shop._rear_touch_hint_visible()).is_false()
	assert_str(shop._child_touch_target(Vector2i(80, 140))).is_empty()


func test_desktop_keeps_slash_hint_and_touch_hint_fits_all_locales() -> void:
	var shop := await _open_rear()
	shop.set("_touch_rear_mode", false)
	assert_bool(shop._rear_touch_hint_visible()).is_false()
	assert_str(shop._child_touch_target(Vector2i(80, 140))).is_empty()
	for language in ["en", "fr", "de", "es", "it", "pt"]:
		var label := TyrianText.L("shop_touch_rear_mode", language)
		assert_int(TyrianText.width(label, TyrianScreen.SMALL_FONT)).is_less_equal(116)


func _open_sidekick(category: int) -> Node:
	var shop := await _open_shop()
	shop.set("_touch_sidekick", true)
	_open_upgrade(shop)
	shop._apply_hover(category)
	shop.handle_action(TyrianControls.ACCEPT)
	return shop


func test_manual_sidekick_icon_uses_selected_side_and_release() -> void:
	for category in [7, 8]:
		var shop := await _open_sidekick(category)
		var found := false
		for row in shop._state.items.size():
			shop._apply_hover(row + 2)
			if bool(shop._state.get("manual_sidekick", false)):
				found = true
				break
		assert_bool(found).is_true()
		assert_bool(shop._sidekick_touch_icon_visible()).is_true()
		var equipment: PackedInt32Array = shop._shop.loadout()
		var cash := int(shop._state.cash)
		_button(shop, Vector2(35, 158), true)
		assert_int(shop._preview_sidekick_fire).is_equal(-1)
		_button(shop, Vector2(35, 158), false)
		assert_int(shop._preview_sidekick_fire).is_equal(category - 7)
		shop._weapon_sim_frame(category, equipment)
		assert_int(shop._preview_sidekick_fire).is_equal(-1)
		assert_bool(shop._shop.loadout() == equipment).is_true()
		assert_int(int(shop._state.cash)).is_equal(cash)
		_button(shop, Vector2(35, 158), true)
		var motion := InputEventMouseMotion.new()
		motion.position = Vector2(80, 158)
		shop.handle_mouse(motion)
		_button(shop, Vector2(35, 158), false)
		assert_int(shop._preview_sidekick_fire).is_equal(-1)
		shop.set("_touch_sidekick", false)
		assert_bool(shop._sidekick_touch_icon_visible()).is_false()
		assert_str(shop._child_touch_target(Vector2i(35, 158))).is_empty()


func test_automatic_and_empty_sidekick_have_no_fire_icon() -> void:
	var shop := await _open_sidekick(7)
	assert_bool(shop._sidekick_touch_icon_visible()).is_false()  # None equipped.
	var found := false
	for row in shop._state.items.size():
		shop._apply_hover(row + 2)
		if int(shop._state.loadout[7]) > 0 and not bool(shop._state.manual_sidekick):
			found = true
			assert_bool(shop._sidekick_touch_icon_visible()).is_false()
			assert_str(shop._child_touch_target(Vector2i(35, 158))).is_empty()
			break
	assert_bool(found).is_true()
