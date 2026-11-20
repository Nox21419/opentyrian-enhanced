## Android-only gameplay buttons. A finger belongs to a button only if its
## initial press hits it; cancelled gestures stay owned until release.
class_name TouchWeapons
extends Node2D

const TARGETS := [Rect2(0, 162, 18, 22), Rect2(18, 162, 30, 22), Rect2(48, 162, 22, 22)]
const MASKS := [Game.MASK_LEFT_SIDEKICK, Game.MASK_CHANGE_FIRE, Game.MASK_RIGHT_SIDEKICK]
var graphics := PackedInt32Array([0, 0])
var enabled := false
var _fingers := {}
var _pending := 0
var _previous := 0


func _ready() -> void:
	var label := TyrianText.new()
	label.name = "Mode"
	label.font = TyrianText.FontKind.NORMAL
	label.text = "Mode"  # locale-exempt: approved compact gameplay control
	label.outline = true
	label.color = Color(0.85, 0.75, 0.45)
	label.position = Vector2(19, 172)
	label.scale = Vector2.ONE * 0.65
	add_child(label)


func update_state(hud: PackedInt32Array, active: bool) -> void:
	var next := PackedInt32Array([hud[28], hud[29]]) if hud.size() >= 30 else PackedInt32Array([0, 0])
	if next != graphics:
		graphics = next
		_fingers.clear()
		_pending = 0
		queue_redraw()
	enabled = active
	visible = active
	if not active:
		reset()


func reset() -> void:
	_fingers.clear()
	_pending = 0
	_previous = 0


func target_at(p: Vector2) -> int:
	for i in 3:
		if i != 1 and graphics[0 if i == 0 else 1] <= 0:
			continue
		if TARGETS[i].has_point(p):
			return i
	return -1


func feed(event: InputEvent) -> bool:
	if not enabled:
		return false
	if event is InputEventScreenTouch:
		if _fingers.has(event.index):
			var target: int = _fingers[event.index]
			if not event.pressed or event.is_canceled():
				if not event.is_canceled() and target >= 0 and target_at(event.position) == target:
					_pending |= MASKS[target]
				_fingers.erase(event.index)
			return true
		if event.pressed and not event.is_canceled():
			var target := target_at(event.position)
			if target >= 0:
				_fingers[event.index] = target
				return true
	elif event is InputEventScreenDrag and _fingers.has(event.index):
		if target_at(event.position) != _fingers[event.index]:
			_fingers[event.index] = -1
		return true
	return false


## One tick of the existing keyboard-style input. Insert a released tick
## between repeated taps so the simulation sees each mode-switch edge.
func consume_mask() -> int:
	if _previous != 0:
		_previous = 0
		return 0
	_previous = _pending
	_pending = 0
	return _previous


func _draw() -> void:
	var sheet := TyrianAssets.sheet("newsh1")
	if sheet == null:
		return
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE * 0.65)
	for i in 2:
		if graphics[i] > 0:
			sheet.draw_2x2(self, graphics[i], (0 if i == 0 else 48) / 0.65, 165 / 0.65)
