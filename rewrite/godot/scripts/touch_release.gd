## Delays a pointer activation until release over the same logical target.
## Hosts keep their existing geometry and action handlers; no global input changes.
class_name TouchRelease
extends RefCounted

var _target := ""


func cancel() -> void:
	_target = ""


func feed(event: InputEvent, target: String) -> InputEventMouseButton:
	if event is InputEventMouseMotion:
		if target != _target:
			cancel()
		return null
	if not event is InputEventMouseButton or event.button_index != MOUSE_BUTTON_LEFT:
		return null
	if event.pressed:
		_target = target
		return null
	var activate := not _target.is_empty() and _target == target
	cancel()
	if not activate:
		return null
	var click: InputEventMouseButton = event.duplicate()
	click.pressed = true
	return click
