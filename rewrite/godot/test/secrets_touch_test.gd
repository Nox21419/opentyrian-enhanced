extends GdUnitTestSuite

const SETUP := preload("res://scripts/setup.gd")
const NG := preload("res://scripts/new_game.gd")


func before_test() -> void:
	EndlessSession.stop()
	Game.campaign_active = false
	Game.mutators = 0
	SETUP.entry_row = 0


func after_test() -> void:
	for child in Effects.game_viewport.get_children():
		child.queue_free()
		Effects.game_viewport.remove_child(child)
	await get_tree().process_frame
	await get_tree().process_frame
	NG.flow = NG.Flow.NEW_GAME
	NG.secret_difficulty = 0
	NG.secret_return = false
	SETUP.entry_row = 0
	Game.campaign_active = false
	Music.release_streams()
	Sfx.release_streams()
	TyrianMouse.inactive = true
	TyrianMouse.buttons = 0


func _wait(cond: Callable) -> void:
	var end := Time.get_ticks_msec() + 10000
	while not cond.call() and Time.get_ticks_msec() < end:
		await get_tree().process_frame
	assert_bool(cond.call()).is_true()


func _open(mobile := true) -> Node:
	var setup: Node = Game.goto_scene(Game.SCENE_SETUP)
	setup._touch_setup = mobile
	await _wait(func() -> bool: return setup.idle and not setup._busy)
	return setup


func _button(screen: Node, row: int, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = Vector2(160, 40 + row * 15)
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	screen.handle_mouse(event)


func _tap(screen: Node, row: int) -> void:
	_button(screen, row, true)
	_button(screen, row, false)


func _continue_intro(screen: Node) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	screen._input(event)
	event.pressed = false
	screen._input(event)


func _new_game(id: String) -> Node:
	await _wait(
		func() -> bool:
			var scene := Effects.current_game_scene()
			return (
				scene.scene_file_path == Game.SCENE_NEW_GAME
				and scene.current_screen == id
				and scene.idle
				and (not scene._busy or id in ["super_arcade", "super_tyrian"])
			)
	)
	return Effects.current_game_scene()


func test_secrets_release_navigation_cancel_and_desktop_scope() -> void:
	var setup := await _open()
	_button(setup, SETUP.SECRETS_ROW, true)
	assert_int(setup.menus.stack.size()).is_equal(1)
	_button(setup, SETUP.SECRETS_ROW, false)
	assert_str(setup.menus.current().header).is_equal("secrets_header")
	_button(setup, 0, true)
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(0, 0)
	setup.handle_mouse(motion)
	_button(setup, 0, false)
	assert_str(setup.menus.current().header).is_equal("secrets_header")
	_tap(setup, 0)
	assert_str(setup.menus.current().header).is_equal("superShip_0")
	assert_int(setup.menus.current().items.size()).is_equal(10)
	assert_int(setup.menus.row_at(setup.menus.current(), Vector2i(300, 175))).is_equal(9)
	_tap(setup, 9)
	assert_str(setup.menus.current().header).is_equal("secrets_header")
	_tap(setup, 3)
	assert_str(setup.menus.current().header).is_equal("setup_header")
	setup = await _open(false)
	assert_int(setup.menus.current().items.size()).is_equal(8)
	for item in setup.menus.current().items:
		assert_str(item.label).is_not_equal("setup_secrets")


func test_all_secret_ships_start_with_original_loadouts() -> void:
	for ship in 9:
		var setup := await _open()
		_tap(setup, SETUP.SECRETS_ROW)
		_tap(setup, 0)
		_button(setup, ship, true)
		assert_bool(setup._busy).is_false()
		_button(setup, ship, false)
		var game := await _new_game("episode")
		game._touch_difficulty = true
		game.handle_action(TyrianControls.ACCEPT)
		game = await _new_game("difficulty")
		assert_int(game.difficulty_count).is_equal(6)
		game.handle_action(TyrianControls.ACCEPT)
		await _new_game("super_arcade")
		_continue_intro(game)
		await _wait(func() -> bool: return Game.campaign_active)
		assert_int(Game.loadout[0]).is_equal(NG.SA_SHIP[ship])
		assert_int(Game.loadout[1]).is_equal(NG.SA_FRONT_WEAPON[ship])
		assert_int(Game.loadout[9]).is_equal(NG.SA_SPECIAL[ship])
		assert_int(Game.initial_difficulty).is_equal(3)
		assert_int(Game.campaign_modes[3]).is_equal(ship + 1)
		if ship == 6:
			assert_int(Game.loadout[7]).is_equal(24)
			assert_int(Game.loadout[8]).is_equal(24)
		Game.campaign_active = false


func test_super_tyrian_variants_keep_original_difficulty_and_equipment() -> void:
	for choice in 2:
		var setup := await _open()
		_tap(setup, SETUP.SECRETS_ROW)
		_tap(setup, 1)
		_tap(setup, choice)
		var game := await _new_game("super_tyrian")
		_continue_intro(game)
		game = await _new_game("episode")
		game.handle_action(TyrianControls.ACCEPT)
		await _wait(func() -> bool: return Game.campaign_active)
		assert_int(Game.loadout[0]).is_equal(13)
		assert_int(Game.loadout[1]).is_equal(39)
		assert_int(Game.initial_difficulty).is_equal(8 if choice == 0 else 6)
		assert_int(Game.campaign_modes[4]).is_equal(1)
		assert_int(NG.secret_difficulty).is_equal(0)
		Game.campaign_active = false


func test_cancel_secret_game_returns_to_setup() -> void:
	var setup := await _open()
	_tap(setup, SETUP.SECRETS_ROW)
	_tap(setup, 0)
	_tap(setup, 0)
	var game := await _new_game("episode")
	game.handle_action(TyrianControls.BACK)
	await _wait(func() -> bool: return Effects.current_game_scene().scene_file_path == Game.SCENE_SETUP)
	setup = Effects.current_game_scene()
	setup._touch_setup = true
	await _wait(func() -> bool: return setup.idle and not setup._busy)
	assert_int(setup.menus.selection()).is_equal(SETUP.SECRETS_ROW)
	assert_str(setup.menus.current().items[SETUP.SECRETS_ROW].label).is_equal("setup_secrets")
	assert_bool(NG.secret_return).is_false()


func test_destruct_entry_opens_existing_minigame() -> void:
	var setup := await _open()
	_tap(setup, SETUP.SECRETS_ROW)
	_tap(setup, 2)
	await _wait(func() -> bool: return Effects.current_game_scene().scene_file_path == Game.SCENE_DESTRUCT)


func test_secrets_labels_fit_in_all_six_languages() -> void:
	var setup := await _open()
	var items: Array = [setup._setup_items()[SETUP.SECRETS_ROW]]
	items.append_array(setup._secrets_items())
	items.append_array(setup._secret_ship_items())
	items.append_array(setup._secret_tyrian_items())
	for lang in ["en", "fr", "de", "es", "it", "pt"]:
		for item in items:
			var label := TyrianText.L(item.label, lang)
			assert_int(TyrianText.width(label, TyrianScreen.NORMAL_FONT)).is_less_equal(280)
			if item.help != "":
				var help := TyrianText.L(item.help, lang)
				assert_int(TyrianText.width(help, TyrianScreen.SMALL_FONT)).is_less_equal(296)
