## Isolated original two-player high-score transaction. No profile or Game writes.
extends RefCounted

const Ending := preload("res://scripts/network_episode_end.gd")
const Scores := preload("res://scripts/high_scores.gd")
const Config := preload("res://scripts/network_configuration.gd")
const Data := preload("res://scripts/network_story_script.gd")
var error := ""
var source := ""
var table := 0
var difficulty := 0
var mutators := 0
var _rows := []
var _players := []
var _scores := []
var _index := 0
var _entry := {}
var _applied := {}


func begin(config: Dictionary, record: Dictionary, proposal: Dictionary, history: Dictionary, rows: Array) -> bool:
	if not source.is_empty() or not valid_rows(rows):
		return _fail("invalid_high_score_table")
	var ending := Ending.build(config, record, proposal, history)
	if ending.is_empty():
		return _fail("invalid_high_score_source")
	source = ending.digest
	table = 11 + (history.initial_episode - 1) * 2
	difficulty = config.difficulty
	mutators = config.mutators
	_rows = rows.duplicate(true)
	Scores.sort_high_scores([_rows])
	if ending.effects.high_score_check:
		_players = [1, 0] if record.stats.cash < record.stats.cash2 else [0, 1]
		var mult := Scores.mutator_multiplier(mutators)
		_scores = [Scores.apply_multiplier(record.stats.cash, mult), Scores.apply_multiplier(record.stats.cash2, mult)]
	_seek()
	return true


static func valid_rows(rows: Variant) -> bool:
	if not rows is Array or rows.size() != 3:
		return false
	for row in rows:
		if not row is Dictionary or row.size() != 3:
			return false
		if (
			not Config.integer(row.get("score"), 0, 0x7fffffffffffffff)
			or not Config.integer(row.get("difficulty"), 0, 255)
		):
			return false
		if not row.get("name") is String or row.name.length() > 28 or row.name.to_utf8_buffer().size() > 112:
			return false
	return true


func rows() -> Array:
	return _rows.duplicate(true)


func entry() -> Dictionary:
	return _entry.duplicate(true)


func complete() -> bool:
	return not source.is_empty() and error.is_empty() and _entry.is_empty()


func submit(name: String, cancel: bool, expected: String) -> Dictionary:
	if _applied.has(expected):
		var previous: Dictionary = _applied[expected]
		return previous.duplicate(true) if previous.name == name and previous.cancel == cancel else {}
	if (
		not error.is_empty()
		or _entry.is_empty()
		or _entry.digest != expected
		or name.length() > 28
		or name.to_utf8_buffer().size() > 112
	):
		return {}
	var before := _rows.duplicate(true)
	var slot: int = _entry.slot
	# Match the maintained original shift-before-cancel behavior, with no mode flag.
	for index in range(2, slot, -1):
		_rows[index] = _rows[index - 1].duplicate()
	if not cancel:
		var marked := name.strip_edges(false, true)
		if mutators != 0:
			marked = marked.left(26) + " *"
		_rows[slot] = {"score": _entry.score, "name": marked, "difficulty": difficulty}
	var result := {
		"source": source,
		"entry": _entry.duplicate(true),
		"before": before,
		"after": rows(),
		"name": name,
		"cancel": cancel
	}
	result["digest"] = Data.digest(result)
	_applied[expected] = result.duplicate(true)
	_index += 1
	_seek()
	return result


func _seek() -> void:
	_entry.clear()
	while _index < _players.size():
		Scores.sort_high_scores([_rows])
		var player: int = _players[_index]
		for slot in 3:
			if _scores[player] > _rows[slot].score:
				_entry = {
					"source": source,
					"index": _index,
					"player": player,
					"score": _scores[player],
					"slot": slot,
					"table": table,
					"mutators": mutators
				}
				_entry["digest"] = Data.digest(_entry)
				return
		_index += 1


func _fail(reason: String) -> bool:
	error = reason
	return false
