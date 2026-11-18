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
func _open_shop() -> Node:
	Game.loadout = PackedInt32Array([1, 1, 11, 0, 1, 4, 2, 0, 0, 0, 15267])
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
	return shop


func _button(shop: Node, p: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = p
	event.pressed = pressed
	shop.handle_mouse(event)


func test_release_opens_upgrade_without_changing_equipment_or_cash() -> void:
	var shop := await _open_shop()
	var cash := int(shop._state.cash)
	var loadout: PackedInt32Array = shop._shop.loadout()
	_button(shop, Vector2(165, 74), true)
	assert_int(int(shop._state.menu)).is_equal(0)
	_button(shop, Vector2(165, 74), false)
	assert_int(int(shop._state.menu)).is_equal(1)
	assert_int(int(shop._state.cash)).is_equal(cash)
	assert_bool(shop._shop.loadout() == loadout).is_true()
	# Upgrade Ship keeps its original mouse-on-press interaction.
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(220, 58)
	motion.relative = Vector2(1, 0)
	TyrianMouse.inactive = false
	shop.handle_mouse(motion)
	_button(shop, Vector2(220, 58), true)
	assert_int(int(shop._state.menu)).is_equal(4)


func test_drag_off_and_footer_do_not_activate() -> void:
	var shop := await _open_shop()
	_button(shop, Vector2(165, 74), true)
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(100, 74)
	motion.relative = Vector2(-65, 0)
	shop.handle_mouse(motion)
	_button(shop, Vector2(165, 74), false)
	assert_int(int(shop._state.menu)).is_equal(0)
	for p in [Vector2(220, 125), Vector2(220, 190), Vector2(100, 74)]:
		_button(shop, p, true)
		_button(shop, p, false)
	assert_int(int(shop._state.menu)).is_equal(0)
	assert_bool(shop.modal_active).is_false()


func test_quit_still_requires_confirmation_and_no_keeps_campaign() -> void:
	var shop := await _open_shop()
	_button(shop, Vector2(165, 138), true)
	assert_bool(shop.modal_active).is_false()
	_button(shop, Vector2(165, 138), false)
	assert_bool(shop.modal_active).is_true()
	shop.modal_input(TyrianControls.NO)
	await get_tree().create_timer(0.3).timeout
	assert_bool(shop.modal_active).is_false()
	assert_bool(Game.campaign_active).is_true()
	assert_int(int(shop._state.menu)).is_equal(0)


func test_start_level_opens_route_choice_not_gameplay() -> void:
	var shop := await _open_shop()
	_button(shop, Vector2(165, 106), true)
	_button(shop, Vector2(165, 106), false)
	assert_int(int(shop._state.menu)).is_equal(3)
	assert_str(shop.scene_file_path).is_equal(Game.SCENE_SHOP)


func test_options_opens_existing_options_screen() -> void:
	var shop := await _open_shop()
	_button(shop, Vector2(165, 90), true)
	_button(shop, Vector2(165, 90), false)
	await get_tree().process_frame
	assert_str(Effects.current_game_scene().scene_file_path).is_equal(Game.SCENE_SAVE_MENU)


func test_ship_specs_opens_on_release() -> void:
	var shop := await _open_shop()
	_button(shop, Vector2(165, 58), true)
	assert_bool(shop.get("_specs_open")).is_false()
	_button(shop, Vector2(165, 58), false)
	assert_bool(shop.get("_specs_open")).is_true()
	shop.handle_action(TyrianControls.ACCEPT)
	await get_tree().create_timer(0.4).timeout


func test_data_opens_existing_cube_list() -> void:
	var shop := await _open_shop()
	_button(shop, Vector2(165, 42), true)
	_button(shop, Vector2(165, 42), false)
	assert_int(int(shop._state.menu)).is_equal(7)


func test_desktop_click_still_activates_on_press() -> void:
	var shop := await _open_shop()
	shop.set("_touch_root", false)
	shop._apply_hover(4)
	_button(shop, Vector2(220, 74), true)
	assert_int(int(shop._state.menu)).is_equal(1)
