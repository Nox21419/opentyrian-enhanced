## Android Destruct input. Only existing native commands are emitted.
## Each finger owns its initial target; dragging off cancels until release.
extends Node2D

const LABEL_KEYS := [
	"destruct_touch_left_dir",
	"destruct_touch_right_dir",
	"destruct_touch_up",
	"destruct_touch_down",
	"W-",
	"destruct_touch_vehicle",
	"destruct_touch_fire",
	"W+"
]
const COMMANDS := [0, 1, 2, 3, 6, 4, 5, 7]
var enabled := false
var _fingers := {}
var _pending := PackedInt32Array()
var _labels: Array[TyrianText] = []


func _ready() -> void:
	_pending.resize(16)
	for i in 16:
		var label := TyrianText.new()
		label.font = TyrianText.FontKind.NORMAL
		label.scale = Vector2.ONE * 0.65
		label.outline = true
		label.align = TyrianText.Align.CENTER
		var key: String = LABEL_KEYS[i % 8]
		var translated := key.begins_with("destruct_")
		label.text = TyrianText.L(key) if translated else key
		label.position = target_rect(i).get_center() - Vector2(0, 3)
		add_child(label)
		_labels.append(label)
	visible = false


static func target_rect(index: int) -> Rect2:
	return Rect2((index / 8) * 160 + (index % 4) * 40, 156 + ((index % 8) / 4) * 22, 40, 22)


func target_at(point: Vector2) -> int:
	for i in 16:
		if target_rect(i).has_point(point):
			return i
	return -1


func update_state(active: bool, cpu_left: bool, cpu_right: bool) -> void:
	enabled = active
	visible = active
	if not active:
		reset()
	for i in _labels.size():
		var cpu := cpu_left if i < 8 else cpu_right
		var held := i in _fingers.values()
		_labels[i].modulate = (Color(0.4, 0.4, 0.4) if cpu else (Color.WHITE if held else Color(0.85, 0.75, 0.45)))


func reset() -> void:
	_fingers.clear()
	_pending.fill(0)


func feed(event: InputEvent) -> bool:
	if not enabled:
		return false
	if event is InputEventScreenTouch:
		if _fingers.has(event.index):
			var target: int = _fingers[event.index]
			if not event.pressed or event.is_canceled():
				if not event.is_canceled() and target >= 0 and target_at(event.position) == target:
					var command: int = COMMANDS[target % 8]
					if command in [4, 6, 7]:
						_pending[(target / 8) * 8 + command] += 1
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


func read_moves() -> PackedInt32Array:
	var moves := PackedInt32Array()
	moves.resize(16)
	for target in _fingers.values():
		if target >= 0:
			var command: int = COMMANDS[target % 8]
			if command not in [4, 6, 7]:
				moves[(target / 8) * 8 + command] = 1
	for i in 16:
		if _pending[i] > 0:
			moves[i] = 1
			_pending[i] -= 1
	return moves
