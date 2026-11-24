## First network screen: original VGA backdrop, fonts and menu navigation.
## LAN connection testing only; gameplay stays unavailable until synchronized.
extends TyrianScreen

const Lobby := preload("res://scripts/lan_lobby.gd")
const ROW_Y := 83
const ROW_STEP := 22
const ADDRESS_MAX := 45

var session := Lobby.new()
var menus := MenuEngine.new(self)
var idle := false
var _busy := true
var _touch := OS.get_name() == "Android"
var _pressed := -1
var _typing := false
var _keyboard_requested := false
var _address := ""
var _previous_address := ""


func _ready() -> void:
	add_child(session)
	session.changed.connect(_refresh)
	_run.call_deferred()


func _run() -> void:
	vga.load_pic(VGA_SCREEN2, 2, false)
	TyrianText.draw_font_hv_shadow(
		self, 160, 20, TyrianText.L("net_title"), LARGE_FONT, CENTERED, 15, -3, false, 2, VGA_SCREEN2
	)
	var items := []
	for row in 3:
		var item := MenuEngine.item("", "", MenuEngine.Kind.CUSTOM, {"draw": _draw_row.bind(row)})
		items.append(item)
	await menus.open(
		"",
		items,
		{
			"style": MenuEngine.Style.ROWS,
			"row_y": ROW_Y,
			"row_step": ROW_STEP,
			"on_activate": _activate,
			"on_back": _back,
			"hit": _hit,
			"header_draw": _draw_details,
			"move_sfx": Sfx.CURSOR,
			"accept": [TyrianControls.SELECT, TyrianControls.ACCEPT],
			"pre_present": func() -> void: await fade_palette(10, 0, 255),
		}
	)
	_busy = false
	idle = true


func _row_label(row: int) -> String:
	match row:
		0:
			return TyrianText.L("net_stop_host" if session.hosting else "net_host")
		1:
			return TyrianText.L("net_disconnect" if session.peer != null and not session.hosting else "net_join")
	return TyrianText.L("gd_back")


func _draw_row(_item: Dictionary, _x: int, y: int, selected: bool, row: int) -> void:
	TyrianText.draw_font_hv_shadow(
		self, 160, y, _row_label(row), NORMAL_FONT, CENTERED, 15, -2 if selected and not _typing else -4, false, 2
	)


func _draw_details() -> void:
	var text := _address if _typing else TyrianText.L("net_lan_only")
	# An IPv6 literal can exceed the available width; keep the caret visible.
	while TyrianText.width(text, SMALL_FONT) > 280:
		text = text.substr(1)
	TyrianText.draw_font_hv_shadow(self, 160, 55, text, SMALL_FONT, CENTERED, 15, 4, false, 1)
	if _typing:
		TyrianText.draw_font_hv_shadow(
			self, 160, 43, TyrianText.L("net_enter_address"), SMALL_FONT, CENTERED, 15, 4, false, 1
		)
		# Original name-entry block cursor: underscore has no bitmap glyph.
		var cursor_x := 160 + TyrianText.width(text, SMALL_FONT) / 2
		vga.bar_shade(VGA_SCREEN, cursor_x + 2, 56, cursor_x + 6, 61)
		vga.fill_rectangle_xy(VGA_SCREEN, cursor_x + 1, 55, cursor_x + 5, 60, 8 * 16 + 10)
	TyrianText.draw_font_hv_shadow(
		self, 160, 150, TyrianText.L(session.status_key), SMALL_FONT, CENTERED, 15, 4, false, 1
	)
	var footer := TyrianText.L("net_connection_test")
	TyrianText.draw_font_hv_shadow(self, 160, 184, footer, SMALL_FONT, CENTERED, 15, 4, false, 1)
	if session.hosting:
		var addresses: Array[String] = []
		for address in IP.get_local_addresses():
			if address.contains(".") and not address.begins_with("127.") and not address.begins_with("169.254."):
				addresses.append(address)
		var address_text := " / ".join(addresses)
		if TyrianText.width(address_text, SMALL_FONT) > 288:
			address_text = addresses[0] if not addresses.is_empty() else ""
		TyrianText.draw_font_hv_shadow(self, 160, 166, address_text, SMALL_FONT, CENTERED, 15, 4, false, 1)


func _refresh() -> void:
	if idle and not _busy and not menus.stack.is_empty():
		menus.draw()


func _hit(p: Vector2i) -> int:
	if _typing:
		return 1 if Rect2i(16, 45, 288, 30).has_point(p) else -1
	if p.y < ROW_Y - 2 or p.y >= ROW_Y - 2 + 3 * ROW_STEP:
		return -1
	var row := (p.y - ROW_Y + 2) / ROW_STEP
	var width := TyrianText.width(_row_label(row), NORMAL_FONT)
	if _touch:
		return row if p.x >= 16 and p.x < 304 else -1
	return row if p.x >= 160 - width / 2 and p.x < 160 + width / 2 and p.y < ROW_Y + row * ROW_STEP + 13 else -1


func _activate(row: int) -> void:
	Sfx.play(Sfx.SELECT)
	match row:
		0:
			if session.hosting:
				session.close()
			else:
				session.host()
		1:
			if session.peer != null and not session.hosting:
				session.close()
			else:
				_previous_address = _address
				_typing = true
				_show_keyboard()
		2:
			_back()
	_refresh()


func _back() -> void:
	if _busy:
		return
	_busy = true
	idle = false
	session.close()
	_hide_keyboard()
	Sfx.play(Sfx.SPRING)
	await fade_black(15)
	Game.goto_scene(Game.SCENE_NEW_GAME)


func _show_keyboard() -> void:
	if _touch and DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		_keyboard_requested = true
		DisplayServer.virtual_keyboard_show(
			_address, Rect2(), DisplayServer.KEYBOARD_TYPE_DEFAULT, ADDRESS_MAX, _address.length(), _address.length()
		)


func _hide_keyboard() -> void:
	if _keyboard_requested:
		DisplayServer.virtual_keyboard_hide()
	_keyboard_requested = false


func handle_event(event: InputEvent) -> void:
	if not _typing:
		super(event)
		return
	if not event is InputEventKey or not event.pressed:
		return
	match event.keycode:
		KEY_ENTER, KEY_KP_ENTER:
			_finish_address(true)
		KEY_ESCAPE, KEY_BACK:
			_finish_address(false)
		KEY_BACKSPACE:
			_address = _address.left(maxi(0, _address.length() - 1))
		_:
			var character := String.chr(event.unicode)
			if character in "0123456789abcdefABCDEF:." and _address.length() < ADDRESS_MAX:
				_address += character
	_refresh()


func _finish_address(accept: bool) -> void:
	_typing = false
	_hide_keyboard()
	if accept:
		session.join(_address)
	else:
		_address = _previous_address
	_refresh()


func handle_action(action: StringName) -> void:
	if _busy or not idle:
		return
	if _typing:
		if action in [TyrianControls.SELECT, TyrianControls.ACCEPT, TyrianControls.BACK]:
			_finish_address(action != TyrianControls.BACK)
		return
	menus.handle_action(action)


func handle_mouse(event: InputEvent) -> void:
	if _busy or not idle:
		return
	if _typing:
		if TyrianMouse.is_button_press(event):
			if Rect2(16, 45, 288, 30).has_point(event.position):
				_show_keyboard()
			else:
				_finish_address(false)
		return
	if not _touch:
		super(event)
		return
	var row := _hit(Vector2i(event.position.floor()))
	if event is InputEventMouseMotion:
		if row != _pressed:
			_pressed = -1
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_pressed = row
			if row >= 0:
				menus.hover(menus.current(), row)
		else:
			var pressed := _pressed
			_pressed = -1
			if row >= 0 and row == pressed:
				_activate(row)


func _exit_tree() -> void:
	_hide_keyboard()
	session.close()
