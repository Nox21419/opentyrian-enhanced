## Original frozen Android Pause menu; host-local audio and shared Return/Quit.
## Keep all original rows; negotiated and unsupported actions remain locked.
extends "res://scripts/pause_menu.gd"


func _items() -> Array:
	var items := super._items()
	for item in items:
		if item.label not in ["ig_music_vol", "ig_sfx_vol", "ig_return", "ig_quit"]:
			item.unavailable = true
			if item.label in ["ig_detail", "ig_game_speed"]:
				item.unavailable_draw = _draw_locked_setting
	return items


func _draw_locked_setting(it: Dictionary, x: int, y: int) -> void:
	var config: Dictionary = level.get("_config")
	var value: String
	if it.label == "ig_game_speed":
		value = TyrianText.L(GAME_SPEED.LABELS[clampi(config.game_speed, 1, 5) - 1])
	else:
		var preset: int = SETUP.VISUAL_FX_PROCESSOR_TYPE.find(config.processor_type)
		value = TyrianText.L(VISUAL_FX_LABELS[preset] if preset >= 0 else "fx_preset_custom")
	TyrianText.draw_font_hv_shadow(self, x, y, TyrianText.L(it.label), NORMAL_FONT, LEFT, 10, -3, false, 2)
	TyrianText.draw_font_hv_shadow(self, PAUSE_VALUE_X, y, value, NORMAL_FONT, LEFT, 10, -3, false, 2)


func _touch_target(p: Vector2i) -> String:
	var target := super._touch_target(p)
	if target.begins_with("row:"):
		var index := int(target.get_slice(":", 1))
		if menus.current().items[index].get("unavailable", false):
			return ""
	return target


func _apply_audio() -> void:
	Music.user_volume = int(SETUP.settings.music_volume)
	Music.muted = SETUP.settings.music_disabled or SETUP.settings.sound_muted
	Music.set_volume(Music.user_volume)
	Sfx.volume = int(SETUP.settings.fx_volume)
	SETUP._apply_sfx_enabled()


func _volume_toggle(it: Dictionary) -> void:
	Sfx.play(Sfx.SELECT)
	SETUP.settings[it.disabled] = not SETUP.settings[it.disabled]
	_apply_audio()


func _volume_adjust(it: Dictionary, dir: int) -> void:
	Sfx.play(Sfx.CURSOR)
	var value := int(SETUP.settings[it.volume]) + dir * 12
	if value < 0 or value > 255:
		Sfx.play(Sfx.CLINK)
	SETUP.settings[it.volume] = clampi(value, 0, 255)
	_apply_audio()


func _volume_click(it: Dictionary, rel_x: int) -> void:
	if rel_x < PAUSE_NAME_W:
		_volume_toggle(it)
	elif rel_x - PAUSE_NAME_W < PAUSE_VALUE_W:
		SETUP.settings[it.volume] = clampi((rel_x - PAUSE_NAME_W) * 255 / (VOLUME_BAR_W - 1), 0, 255)
		_apply_audio()
		Sfx.play(Sfx.CURSOR)


func _vfx_adjust(_it: Dictionary, _dir: int) -> void:
	pass


func _speed_adjust(_it: Dictionary, _dir: int) -> void:
	pass
