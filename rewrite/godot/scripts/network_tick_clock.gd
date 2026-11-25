## Per-session pacing credit. The owner supplies physics callbacks at the
## negotiated original speed; no shared Effects credit or local speed override.
extends RefCounted

const Speed := preload("res://scripts/game_speed.gd")
var credit := 0.0


static func ticks_per_second(game_speed: int) -> int:
	if game_speed < 1 or game_speed > 5:
		# Hidden turbo uses a display refresh rate, which is not negotiated.
		return 0
	return Speed.ticks_per_second(Speed.FAST_PLAY[game_speed - 1])


func reset() -> void:
	credit = 0.0


## Same credit/threshold/update order as Effects.consume_tick. The caller holds
## a due tick through network stalls rather than accruing catch-up ticks.
func consume_tick(speed: float) -> bool:
	if speed >= 1.0:
		credit = 0.0
		return true
	credit += speed
	if credit >= 1.0 - 1e-6:
		credit -= 1.0
		return true
	return false
