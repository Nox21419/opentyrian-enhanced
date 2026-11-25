extends GdUnitTestSuite

const Connection := preload("res://scripts/network_gameplay_connection.gd")
const Player := preload("res://scripts/network_player.gd")
const Fixture := preload("res://test/fixtures/network_setup.gd")
const Setup := preload("res://scripts/setup.gd")
const Frozen := preload("res://scripts/frozen_level_screen.gd")
var _nodes: Array[Node] = []
var _settings := {}


class Owner:
	extends Node
	var left := false

	func leave_player(view: Node, _reason := "left") -> void:
		left = true
		if is_instance_valid(view.backend):
			view.backend.stop()

	func player_scene_exited(_view: Node) -> void:
		pass


class EndedPlayer:
	extends "res://scripts/network_player.gd"

	func _ready() -> void:
		pass

	func _game_over_shown() -> bool:
		return true


func before_test() -> void:
	_settings = Setup.settings.duplicate(true)


func after_test() -> void:
	for node in _nodes:
		if is_instance_valid(node):
			node.free()
	_nodes.clear()
	Setup.settings = _settings
	Setup.apply_settings()
	await get_tree().process_frame
	await get_tree().process_frame


func after() -> void:
	Music.release_streams()
	Sfx.release_streams()
	await get_tree().process_frame
	await get_tree().process_frame


func _wait(condition: Callable) -> void:
	var deadline := Time.get_ticks_msec() + 10000
	while not condition.call() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	assert_bool(condition.call()).is_true()


func _pair() -> Array:
	var host := Connection.new()
	var guest := Connection.new()
	for node in [host, guest]:
		add_child(node)
		_nodes.append(node)
	assert_int(host.host(Game.data_dir, PackedStringArray(), {}, 1, 27744)).is_equal(OK)
	assert_int(guest.join("127.0.0.1", Game.data_dir, PackedStringArray(), {}, 1, 27744)).is_equal(OK)
	await _wait(func(): return host.compatible() and guest.compatible())
	assert_bool(host.propose(Fixture.configuration(), "93".repeat(16), 1)).is_true()
	await _wait(func(): return host.agreed() and guest.agreed())
	assert_bool(host.compare_preview()).is_true()
	assert_bool(guest.compare_preview()).is_true()
	await _wait(func(): return host.preview_matched() and guest.preview_matched())
	assert_bool(host.confirm_ready()).is_true()
	assert_bool(guest.confirm_ready()).is_true()
	await _wait(func(): return host.readiness().remote and guest.readiness().remote)
	assert_bool(host.start()).is_true()
	await _wait(func(): return host.running() and guest.running())
	var views: Array[Node] = []
	for peer in [host, guest]:
		var owner := Owner.new()
		add_child(owner)
		_nodes.append(owner)
		var view := Player.new()
		assert_bool(view.bind(peer)).is_true()
		view.set("_touch_pause", true)
		view.controller = owner
		add_child(view)
		_nodes.append(view)
		views.append(view)
	await _wait(func(): return host.ticks_executed() >= 12 and guest.ticks_executed() >= 12)
	return views


func _touch(view: Node, finger: int, point: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = finger
	event.position = point
	event.pressed = pressed
	view._input(event)


func _pause(views: Array, requester: int) -> int:
	for view in views:
		_touch(view, 0, Vector2(100, 100), true)
	var point := Player.TOUCH_PAUSE_RECT.get_center()
	_touch(views[requester], 1, point, true)
	_touch(views[requester], 1, point, false)
	await _wait(func(): return views[0].backend.pause_confirmed() and views[1].backend.pause_confirmed())
	var tick: int = views[0].sim.tick()
	assert_int(views[1].sim.tick()).is_equal(tick)
	assert_object(views[0].get("_pause_menu")).is_not_null()
	assert_object(views[1].get("_pause_menu")).is_null()
	assert_str(views[1].get("_hud_vga").pause_text).is_equal(TyrianText.L("miscText_22"))
	for view in views:
		assert_bool(view.get("_touch_flight").active()).is_false()
	return tick


func _shot(view: Node, role: String) -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--network-pause-shots="):
			var dir := arg.trim_prefix("--network-pause-shots=")
			DirAccess.make_dir_recursive_absolute(dir)
			var menu: Node = view.get("_pause_menu")
			var image: Image
			if menu != null:
				image = menu.vga.image(0)
			else:
				var frozen := Frozen.new()
				add_child(frozen)
				assert_bool(frozen.freeze(view)).is_true()
				image = frozen.vga.image(0)
				frozen.free()
			assert_int(image.save_png(dir.path_join("network-pause-" + role + ".png"))).is_equal(OK)


func test_real_peers_freeze_original_host_menu_and_resume_repeated_input_epochs() -> void:
	var views := await _pair()
	var hashes: Array[Dictionary] = [{}, {}]
	for i in 2:
		views[i].network_tick_presented.connect(func(tick: int): hashes[i][tick] = views[i].backend.diagnostic_digest())
	for requester in [0, 1]:
		var tick: int = await _pause(views, requester)
		var digest: String = views[0].backend.diagnostic_digest()
		var host_credit: float = views[0].get("_clock").credit
		views[0].get("_tilt_flight").calibrate(Vector3(0, 0, 9.8))
		var menu: Node = views[0].get("_pause_menu")
		var items: Array = menu.menus.current().items
		assert_int(items.size()).is_equal(9)
		for index in [2, 3, 4, 7, 8]:
			assert_bool(items[index].unavailable).is_true()
			var point := Vector2i(20, 12 + 20 * index + 4)
			assert_str(menu._touch_target(point)).is_empty()
		var speed: int = Engine.physics_ticks_per_second
		menu._speed_adjust(items[3], 1)
		menu._vfx_adjust(items[2], 1)
		menu._volume_adjust(items[0], -1)
		assert_int(Engine.physics_ticks_per_second).is_equal(speed)
		assert_str(views[0].backend.diagnostic_digest()).is_equal(digest)
		_shot(views[0], "host")
		_shot(views[1], "guest")
		for _frame in 8:
			await get_tree().physics_frame
		for view in views:
			assert_int(view.sim.tick()).is_equal(tick)
			assert_str(view.backend.diagnostic_digest()).is_equal(digest)
		assert_float(views[0].get("_clock").credit).is_equal(host_credit)
		menu._close(false)
		assert_int(views[0].sim.tick()).is_equal(tick)
		await _wait(func(): return views[0].sim.tick() >= tick + 15 and views[1].sim.tick() >= tick + 15)
		assert_bool(views[0].get("_tilt_flight").calibrated).is_true()
		for frame_tick in hashes[0]:
			if hashes[1].has(frame_tick):
				assert_str(hashes[0][frame_tick]).is_equal(hashes[1][frame_tick])
	var tick: int = await _pause(views, 1)
	var back := InputEventAction.new()
	back.action = "tyrian_level_exit"
	back.pressed = true
	views[1]._unhandled_input(back)
	assert_bool(views[1].controller.left).is_true()
	await _wait(func(): return not views[0].backend.running())
	assert_int(tick).is_greater(0)


func test_host_original_quit_confirmation_closes_the_network_session() -> void:
	var views := await _pair()
	await _pause(views, 0)
	var menu: Node = views[0].get("_pause_menu")
	menu._quit_action()
	await _wait(func(): return menu.modal_active)
	menu.modal_input(TyrianControls.YES)
	await _wait(func(): return views[0].controller.left and not views[1].backend.running())


func test_game_over_back_leaves_instead_of_requesting_pause() -> void:
	var owner := Owner.new()
	add_child(owner)
	_nodes.append(owner)
	var view := EndedPlayer.new()
	view.controller = owner
	view.set("_clock_started", true)
	add_child(view)
	_nodes.append(view)
	var back := InputEventAction.new()
	back.action = "tyrian_level_exit"
	back.pressed = true
	view._unhandled_input(back)
	assert_bool(owner.left).is_true()
