## Android sensor input only. The simulation retains movement limits and timing.
class_name TiltFlight
extends RefCounted

const DEAD_ZONE := 2.0
var calibrated := false
var neutral := Vector3.ZERO
var _right := Vector3.RIGHT
var _down := Vector3.DOWN
var _filtered := Vector3.ZERO


func calibrate(gravity: Vector3) -> bool:
	if not _valid(gravity):
		return false
	var direction := gravity.normalized()
	var right := Vector3.RIGHT - direction * direction.x
	if right.length_squared() < 0.01:
		return false
	neutral = direction
	_right = right.normalized()
	_down = neutral.cross(_right).normalized()
	_filtered = neutral
	calibrated = true
	return true


func movement(gravity: Vector3, sensitivity: int) -> Vector2i:
	if not _valid(gravity):
		return Vector2i.ZERO
	if not calibrated:
		calibrate(gravity)
		return Vector2i.ZERO
	_filtered = _filtered.lerp(gravity.normalized(), 0.35).normalized()
	var forward := _filtered.dot(neutral)
	var angles := Vector2(
		rad_to_deg(atan2(_filtered.dot(_right), forward)), rad_to_deg(atan2(_filtered.dot(_down), forward))
	)
	# Double level 1's original 32-degree response range; retain level 10.
	# Space the full-input tilt angles evenly, keeping intermediate levels lower.
	var full_tilt := lerpf(66.0, 8.0, float(clampi(sensitivity, 1, 10) - 1) / 9.0)
	return Vector2i(_axis(angles.x, full_tilt), _axis(angles.y, full_tilt))


func _axis(angle: float, full_tilt: float) -> int:
	var amount := clampf((absf(angle) - DEAD_ZONE) / (full_tilt - DEAD_ZONE), 0.0, 1.0)
	return roundi(signf(angle) * amount * 30.0)


func _valid(gravity: Vector3) -> bool:
	return gravity.is_finite() and gravity.length_squared() > 1.0
