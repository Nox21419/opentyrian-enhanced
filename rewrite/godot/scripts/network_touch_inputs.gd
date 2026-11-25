## Initial Android touch/tilt profile only. Desktop/gamepad profiles are separate.
extends RefCounted

const Wire := preload("res://scripts/network_protocol.gd")
const Config := preload("res://scripts/network_configuration.gd")
const MAX_DELTA := 30


static func neutral_frame(player: int, config: Dictionary) -> Dictionary:
	var frame := Wire.neutral_frame()
	if player == 1 and config.dedicated_special:
		frame.mask = Game.MASK_DEDICATED_SPECIAL
	return frame


## The original two-player HUD publishes player 2's sidekicks/rear mode and
## player 1's special. Project only the controls; keep the full HUD unchanged.
static func controls_hud(hud: PackedInt32Array, player: int, dedicated_special: bool) -> PackedInt32Array:
	if player not in [1, 2] or hud.size() < 33:
		return PackedInt32Array()
	var controls := hud.duplicate()
	if player == 1:
		controls[28] = 0
		controls[29] = 0
		controls[32] = 0
	if player == 2 or not dedicated_special:
		controls[30] = 0
		controls[31] = 0
	return controls


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
