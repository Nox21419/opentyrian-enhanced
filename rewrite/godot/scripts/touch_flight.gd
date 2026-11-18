## Single-finger flight in logical game pixels. The simulation still owns
## movement, collisions and speed limits; this supplies its existing mouse input.
class_name TouchFlight
extends RefCounted

const PLAYFIELD := Rect2(0, 0, 264, 184)
var finger := -1
var target := Vector2.ZERO


func feed(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.index == finger and (not event.pressed or event.is_canceled()):
			reset()
		elif event.pressed and not event.is_canceled() and finger == -1 and PLAYFIELD.has_point(event.position):
			finger = event.index
			target = event.position
	elif event is InputEventScreenDrag and event.index == finger:
		target = event.position


func reset() -> void:
	finger = -1


func active() -> bool:
	return finger >= 0


func fire_mask() -> int:
	return Game.MASK_FIRE if active() else 0


func movement(player: Vector2i, sim_x_to_screen: int) -> Vector2i:
	if not active():
		return Vector2i.ZERO
	var wanted := Vector2i(clampi(roundi(target.x) - sim_x_to_screen, 40, 256), clampi(roundi(target.y), 10, 160))
	# The mouse path divides by four and caps input at 30 per tick. Keep that
	# path, repeatedly steering towards the finger even while it stays still.
	return Vector2i(clampi((wanted.x - player.x) * 4, -30, 30), clampi((wanted.y - player.y) * 4, -30, 30))
