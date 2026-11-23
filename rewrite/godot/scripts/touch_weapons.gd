## Android-only gameplay buttons. A finger belongs to a button only if its
## initial press hits it; cancelled gestures stay owned until release.
class_name TouchWeapons
extends Node2D

const TARGETS := [Rect2(0, 162, 18, 22), Rect2(18, 162, 30, 22), Rect2(48, 162, 22, 22), Rect2(0, 140, 70, 22)]
const MASKS := [Game.MASK_LEFT_SIDEKICK, Game.MASK_CHANGE_FIRE, Game.MASK_RIGHT_SIDEKICK, Game.MASK_SPECIAL]
var graphics := PackedInt32Array([0, 0])
var targets: Array[Rect2] = [Rect2(), Rect2(), Rect2(), Rect2()]
var mode_available := false
var special_equipped := false
var special_ready := false
var enabled := false
var _mode_label: TyrianText
var _special_label: TyrianText
var _fingers := {}
var _pending := 0
var _previous := 0


func _ready() -> void:
	_mode_label = TyrianText.new()
	_mode_label.name = "Mode"
	_mode_label.font = TyrianText.FontKind.NORMAL
	_mode_label.text = "Mode"  # locale-exempt: approved compact gameplay control
	_mode_label.outline = true
	_mode_label.color = Color(0.85, 0.75, 0.45)
	_mode_label.scale = Vector2.ONE * 0.65
	add_child(_mode_label)
	_special_label = TyrianText.new()
	_special_label.name = "Special"
	_special_label.font = TyrianText.FontKind.NORMAL
	_special_label.text = "Special"  # locale-exempt: approved compact gameplay control
	_special_label.outline = true
	_special_label.color = Color(0.85, 0.75, 0.45)
	_special_label.scale = Vector2.ONE * 0.65
	add_child(_special_label)
	_layout_targets()


func update_state(hud: PackedInt32Array, active: bool) -> void:
	var next := PackedInt32Array([hud[28], hud[29]]) if hud.size() >= 30 else PackedInt32Array([0, 0])
	var equipped := hud.size() > 31 and hud[31] > 0
	var mode := hud.size() > 32 and hud[32] != 0
	if next != graphics or equipped != special_equipped or mode != mode_available:
		graphics = next
		special_equipped = equipped
		mode_available = mode
		_layout_targets()
		# A held finger must not activate a different control after the row moves.
		for finger in _fingers:
			_fingers[finger] = -1
		_pending = 0
		queue_redraw()
	special_ready = hud.size() > 30 and hud[30] == 94
	_special_label.visible = special_equipped
	_special_label.modulate = Color.WHITE if special_ready else Color(0.4, 0.4, 0.4)
	enabled = active
	visible = active
	if not active:
		reset()


func _layout_targets() -> void:
	var x := 0.0
	for i in 3:
		var shown: bool = mode_available if i == 1 else graphics[0 if i == 0 else 1] > 0
		targets[i] = Rect2(Vector2(x, 162), TARGETS[i].size) if shown else Rect2()
		if shown:
			x += TARGETS[i].size.x
	targets[3] = TARGETS[3] if special_equipped else Rect2()
	if special_equipped and x == 0.0:
		targets[3].position.y = 162
	_special_label.position = targets[3].position + Vector2(2, 10)
	_mode_label.visible = mode_available
	_mode_label.position = targets[1].position + Vector2(1, 10)


func reset() -> void:
	_fingers.clear()
	_pending = 0
	_previous = 0


func target_at(p: Vector2) -> int:
	for i in targets.size():
		if targets[i].has_point(p):
			return i
	return -1


func feed(event: InputEvent) -> bool:
	if not enabled:
		return false
	if event is InputEventScreenTouch:
		if _fingers.has(event.index):
			var target: int = _fingers[event.index]
			if not event.pressed or event.is_canceled():
				if (
					not event.is_canceled()
					and target >= 0
					and target_at(event.position) == target
					and (target != 3 or special_ready)
				):
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
			sheet.draw_2x2(self, graphics[i], targets[i * 2].position.x / 0.65, 165 / 0.65)
