# GdUnit4: Android touch on the Mods screen (docs/android-build.md, Mods touch
# toggles): a release over a mod row toggles it, dragging off cancels, the
# action rows are grey and unreachable, Back replaces the keys hint. Desktop
# keeps mod_manager.c's keyboard-only screen.
extends GdUnitTestSuite

const MenuScript := preload("res://scripts/mods_menu.gd")
const FOLDER := "mods_touch_test_mod"

var _dir: String


func before_test() -> void:
	# A mod in error toggles like any other (mods_menu_test) and never changes tables.
	_dir = ProjectSettings.globalize_path(Mods.USER_MODS).path_join(FOLDER)
	DirAccess.make_dir_recursive_absolute(_dir)
	var f := FileAccess.open(_dir.path_join("mod.json"), FileAccess.WRITE)
	f.store_string("{ this is not json")
	f.close()
	Mods.reload()


func after_test() -> void:
	Mods.set_enabled(FOLDER, false)
	Mods._remove_tree(_dir)
	Mods.reload()


func _menu(touch := true) -> Node:
	var m: Node = MenuScript.new()
	m.set("_touch_mods", touch)
	add_child(m)
	return auto_free(m)


func _row_of(m: Node) -> int:
	for i in m.mods.size():
		if m.mods[i]["folder"] == FOLDER:
			return i
	fail("test mod missing from the list")
	return -1


func _row_point(row: int) -> Vector2:
	return Vector2(60, 28 + row * 12 + 4)


func _button(m: Node, p: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = p
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	m._unhandled_input(event)


func _motion(m: Node, p: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = p
	m._unhandled_input(event)


func test_release_on_a_mod_row_selects_and_toggles_it() -> void:
	var m := _menu()
	var row := _row_of(m)
	var before: bool = m.mods[row]["enabled"]
	_button(m, _row_point(row), true)
	assert_int(m.index).is_equal(row)
	assert_bool(m.mods[row]["enabled"]).override_failure_message("press alone must not toggle").is_equal(before)
	_button(m, _row_point(row), false)
	assert_bool(m.mods[row]["enabled"]).is_equal(not before)
	assert_int(m.last_sfx).is_equal(Sfx.CLICK)
	# A second tap toggles back.
	_button(m, _row_point(row), true)
	_button(m, _row_point(row), false)
	assert_bool(m.mods[row]["enabled"]).is_equal(before)


func test_dragging_off_the_row_cancels_the_toggle() -> void:
	var m := _menu()
	var row := _row_of(m)
	var before: bool = m.mods[row]["enabled"]
	_button(m, _row_point(row), true)
	var away := Vector2(160, 150)  # detail card: not a target
	_motion(m, away)
	_button(m, away, false)
	assert_bool(m.mods[row]["enabled"]).is_equal(before)
	# Back over the row after leaving it: still cancelled (TouchRelease).
	_button(m, _row_point(row), true)
	_motion(m, away)
	_motion(m, _row_point(row))
	_button(m, _row_point(row), false)
	assert_bool(m.mods[row]["enabled"]).is_equal(before)


func test_action_rows_are_grey_and_unreachable_on_android() -> void:
	var m := _menu()
	var n: int = m.mods.size()
	assert_bool(m.menus.current().items[n].get("unavailable", false)).is_true()
	assert_bool(m.menus.current().items[n + 1].get("unavailable", false)).is_true()
	assert_str(m._touch_target(Vector2i(_row_point(n)))).is_equal("")
	assert_str(m._touch_target(Vector2i(_row_point(n + 1)))).is_equal("")
	# Keyboard / gamepad stop on the last mod.
	m.menus.current().sel = n - 1
	m.handle_action(TyrianControls.DOWN)
	assert_int(m.index).is_equal(n - 1)


func test_back_label_is_the_footer_target() -> void:
	var m := _menu()
	assert_str(m._touch_target(Vector2i(280, 192))).is_equal("back")
	assert_str(m._touch_target(Vector2i(160, 150))).is_equal("")


func test_desktop_ignores_the_mouse_and_keeps_action_rows() -> void:
	var m := _menu(false)
	var row := _row_of(m)
	var before: bool = m.mods[row]["enabled"]
	_button(m, _row_point(row), true)
	_button(m, _row_point(row), false)
	assert_bool(m.mods[row]["enabled"]).is_equal(before)
	var n: int = m.mods.size()
	assert_bool(m.menus.current().items[n].get("unavailable", false)).is_false()
	m.menus.current().sel = n - 1
	m.handle_action(TyrianControls.DOWN)
	assert_int(m.index).is_equal(n)
