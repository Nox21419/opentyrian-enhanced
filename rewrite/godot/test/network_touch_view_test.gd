extends GdUnitTestSuite

const View := preload("res://scripts/network_level.gd")
const Policy := preload("res://scripts/network_touch_inputs.gd")
const Fixture := preload("res://test/fixtures/network_setup.gd")
const Setup := preload("res://scripts/setup.gd")
var _tilt_enabled: bool


class Native:
	extends Node
	var hud := PackedInt32Array()

	func _init() -> void:
		hud.resize(33)
		hud[16] = 1
		hud[28] = 13
		hud[29] = 169
		hud[30] = 94
		hud[31] = 1
		hud[32] = 1

	func player(index: int) -> PackedInt32Array:
		return PackedInt32Array([80 if index == 0 else 180, 90])

	func hud_state() -> PackedInt32Array:
		return hud

	func level_ended() -> bool:
		return false


class Backend:
	extends Node
	signal changed
	var native: Node
	var needs := true
	var frames: Array[Dictionary] = []

	func simulation_for_view() -> Node:
		return native

	func needs_local_input() -> bool:
		return needs

	func inputs_quiesced() -> bool:
		return false

	func capture_local(frame: Dictionary) -> bool:
		frames.append(frame.duplicate(true))
		needs = false
		return true

	func stop() -> void:
		native = null
		changed.emit()


class InputView:
	extends "res://scripts/network_level.gd"

	# Exercise actual input methods without needing a second rendering/native setup.
	func _ready() -> void:
		_hud = Node2D.new()
		add_child(_hud)
		_presentation_ready = true
		set_physics_process(false)
		set_process_input(false)


func before_test() -> void:
	_tilt_enabled = Setup.settings.tilt_controls_enabled
	Setup.settings.tilt_controls_enabled = false


func after_test() -> void:
	Setup.settings.tilt_controls_enabled = _tilt_enabled


func _view(role: int) -> Node:
	var native: Node = auto_free(Native.new())
	var backend: Node = auto_free(Backend.new())
	backend.native = native
	var view: Node = auto_free(InputView.new())
	view.backend = backend
	view.sim = native
	view.player = role
	view.set("_config", Fixture.configuration())
	view.set("_touch_pause", true)
	add_child(view)
	backend.changed.connect(view._backend_changed)
	return view


func _touch(view: Node, finger: int, position: Vector2, pressed: bool, canceled := false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = finger
	event.position = position
	event.pressed = pressed
	event.canceled = canceled
	view._input(event)


func _drag(view: Node, finger: int, position: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = finger
	event.position = position
	view._input(event)


func test_role_controls_project_original_hud_without_changing_it() -> void:
	var native: Node = auto_free(Native.new())
	var before: PackedInt32Array = native.hud.duplicate()
	var host := Policy.controls_hud(native.hud, 1, true)
	var guest := Policy.controls_hud(native.hud, 2, true)
	assert_int(host[28] | host[29] | host[32]).is_equal(0)
	assert_int(host[31]).is_equal(1)
	assert_int(guest[28]).is_equal(13)
	assert_int(guest[29]).is_equal(169)
	assert_int(guest[32]).is_equal(1)
	assert_int(guest[30] | guest[31]).is_equal(0)
	assert_int(Policy.controls_hud(native.hud, 1, false)[31]).is_equal(0)
	assert_bool(Policy.controls_hud(native.hud, 0, true).is_empty()).is_true()
	assert_bool(Policy.controls_hud(PackedInt32Array(), 1, true).is_empty()).is_true()
	assert_bool(native.hud == before).is_true()


func test_each_phone_steers_relative_to_its_own_ship_using_original_flight() -> void:
	for role in [1, 2]:
		var view := _view(role)
		assert_bool(view.enable_network_input()).is_true()
		_touch(view, 0, Vector2(100, 90), true)
		var reference := TouchFlight.new()
		var event := InputEventScreenTouch.new()
		event.pressed = true
		event.position = Vector2(100, 90)
		reference.feed(event)
		var position: PackedInt32Array = view.sim.player(role - 1)
		var expected := reference.movement(Vector2i(position[0], position[1]), View.SIM_X_TO_SCREEN)
		var frame: Dictionary = view._sample_network_touch()
		assert_int(frame.mouse_dx).is_equal(expected.x)
		assert_int(frame.mouse_dy).is_equal(expected.y)
		assert_int(frame.mouse_mask).is_equal(Game.MASK_FIRE)
		assert_bool(Policy.valid(frame, role, Fixture.configuration())).is_true()
		assert_int(frame.mouse_dx).is_equal(30 if role == 1 else -30)
		_touch(view, 0, Vector2(100, 90), false, true)
		frame = view._sample_network_touch()
		assert_int(frame.mouse_mask | frame.mouse_dx | frame.mouse_dy).is_equal(0)


func test_original_weapon_controls_keep_special_and_sidekick_ownership() -> void:
	for role in [1, 2]:
		var view := _view(role)
		assert_bool(view.enable_network_input()).is_true()
		var buttons: TouchWeapons = view.get("_touch_weapons")
		assert_bool(buttons.special_equipped).is_equal(role == 1)
		assert_bool(buttons.mode_available).is_equal(role == 2)
		_touch(view, 0, Vector2(100, 90), true)
		for button in [3] if role == 1 else [0, 1, 2]:
			var point: Vector2 = buttons.targets[button].get_center()
			_touch(view, 1, point, true)
			var frame: Dictionary = view._sample_network_touch()
			assert_int(frame.mask).is_equal(Game.MASK_DEDICATED_SPECIAL if role == 1 else 0)
			_touch(view, 1, point, false)
			frame = view._sample_network_touch()
			var expected: int = TouchWeapons.MASKS[button]
			if role == 1:
				expected |= Game.MASK_DEDICATED_SPECIAL
			assert_int(frame.mask).is_equal(expected)
			assert_int(frame.mouse_mask).is_equal(Game.MASK_FIRE)
			assert_bool(Policy.valid(frame, role, Fixture.configuration())).is_true()
			view._sample_network_touch()


func test_stalled_capture_keeps_future_frame_and_preserves_later_button_release() -> void:
	var view := _view(2)
	assert_bool(view.enable_network_input()).is_true()
	_touch(view, 0, Vector2(100, 90), true)
	assert_bool(view.capture_network_input()).is_true()
	var first: Dictionary = view.backend.frames[0].duplicate(true)
	var buttons: TouchWeapons = view.get("_touch_weapons")
	var point := buttons.targets[1].get_center()
	_touch(view, 1, point, true)
	_touch(view, 1, point, false)
	_drag(view, 0, Vector2(220, 90))
	for _attempt in 4:
		assert_bool(view.capture_network_input()).is_false()
		view._sync_touch_weapons()
	assert_int(view.backend.frames.size()).is_equal(1)
	assert_dict(view.backend.frames[0]).is_equal(first)
	view.backend.needs = true
	assert_bool(view.capture_network_input()).is_true()
	assert_int(view.backend.frames[1].mask).is_equal(Game.MASK_CHANGE_FIRE)
	assert_int(view.backend.frames[1].mouse_dx).is_equal(30)


func test_input_requires_explicit_android_enable_and_disable_clears_pending_fingers() -> void:
	var view := _view(1)
	_touch(view, 0, Vector2(100, 90), true)
	assert_bool(view.capture_network_input()).is_false()
	assert_bool(view.get("_touch_flight").active()).is_false()
	view.set("_touch_pause", false)
	assert_bool(view.enable_network_input()).is_false()
	view.set("_touch_pause", true)
	assert_bool(view.enable_network_input()).is_true()
	assert_bool(view.enable_network_input()).is_true()
	_touch(view, 0, Vector2(100, 90), true)
	var buttons: TouchWeapons = view.get("_touch_weapons")
	var point := buttons.targets[3].get_center()
	_touch(view, 1, point, true)
	_touch(view, 1, point, false)
	view.disable_network_input()
	assert_bool(view.get("_touch_flight").active()).is_false()
	assert_int(buttons.consume_mask()).is_equal(0)
	assert_bool(buttons.visible).is_false()
	assert_bool(view.capture_network_input()).is_false()


func test_tilt_reuses_existing_filter_and_touch_remains_required_for_fire() -> void:
	Setup.settings.tilt_controls_enabled = true
	var view := _view(2)
	assert_bool(view.enable_network_input()).is_true()
	var reference := TiltFlight.new()
	for gravity in [Vector3(0, 0, 9.8), Vector3(3, 0, 9.2), Vector3(6, 0, 7.5)]:
		var expected := reference.movement(gravity, int(Setup.settings.tilt_sensitivity))
		var frame: Dictionary = view._sample_network_touch(gravity)
		assert_int(frame.mouse_dx).is_equal(expected.x)
		assert_int(frame.mouse_dy).is_equal(expected.y)
		assert_int(frame.mouse_mask).is_equal(0)
		assert_bool(Policy.valid(frame, 2, Fixture.configuration())).is_true()
	_touch(view, 0, Vector2(100, 90), true)
	assert_int(view._sample_network_touch(Vector3(6, 0, 7.5)).mouse_mask).is_equal(Game.MASK_FIRE)


func test_disconnect_and_focus_loss_clear_input_without_opening_local_pause() -> void:
	for focus_loss in [false, true]:
		var view := _view(2)
		assert_bool(view.enable_network_input()).is_true()
		_touch(view, 0, Vector2(100, 90), true)
		if focus_loss:
			view._notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
		else:
			view.backend.stop()
		assert_bool(view.get("_touch_flight").active()).is_false()
		assert_bool(view.get("_network_input_enabled")).is_false()
		assert_bool(view.paused).is_false()
		assert_object(view.sim).is_null()
		assert_bool(view.capture_network_input()).is_false()
