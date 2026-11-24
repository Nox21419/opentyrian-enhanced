## Initial Android touch/tilt profile only. Desktop/gamepad profiles are separate.
extends RefCounted

const Wire := preload("res://scripts/network_protocol.gd")
const Config := preload("res://scripts/network_configuration.gd")
const MAX_DELTA := 30


static func supports(config: Dictionary) -> bool:
	return Config.valid(config) and config.devices == [0, 0]


static func valid(frame: Dictionary, player: int, config: Dictionary) -> bool:
	if player not in [1, 2] or not supports(config) or not Wire.valid_frame(frame):
		return false
	if absi(frame.mouse_dx) > MAX_DELTA or absi(frame.mouse_dy) > MAX_DELTA:
		return false
	if frame.analog_x != 0 or frame.analog_y != 0:
		return false
	var dedicated: bool = frame.mask & 0x100 != 0
	var special_press: bool = frame.mask & 0x200 != 0
	if (dedicated or special_press) and (player != 1 or not config.dedicated_special):
		return false
	return not special_press or dedicated
