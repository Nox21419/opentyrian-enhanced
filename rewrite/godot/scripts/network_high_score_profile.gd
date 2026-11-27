## Host-owned, conflict-checked persistence. Guest never binds a writer.
extends RefCounted

const Model := preload("res://scripts/network_episode_high_scores.gd")
const Data := preload("res://scripts/network_story_script.gd")
const Config := preload("res://scripts/network_configuration.gd")
const Scores := preload("res://scripts/high_scores.gd")
var error := ""
var _path := ""
var _bank := []
var _table := -1
var _file_hash := ""
var _receipts := {}
var _source := ""


## Read a fresh host snapshot without touching shared high-score memory.
func begin_current(path: String, table: int, source: String) -> bool:
	var absolute := ProjectSettings.globalize_path(path)
	var initial_hash := FileAccess.get_sha256(absolute) if FileAccess.file_exists(absolute) else "missing"
	var bank := []
	if initial_hash == "missing":
		bank = Scores.default_high_scores()
	else:
		var json := JSON.new()
		if json.parse(FileAccess.get_file_as_string(absolute)) != OK or not json.data is Dictionary:
			return _fail("invalid_profile_file")
		for key in json.data:
			if key not in ["version", "tables"]:
				return _fail("unsupported_profile_fields")
		var tables: Variant = json.data.get("tables")
		if not tables is Array or tables.size() != 20:
			return _fail("invalid_profile_file")
		for rows in tables:
			if not rows is Array or rows.size() != 3:
				return _fail("invalid_profile_file")
			var converted := []
			for row in rows:
				if not row is Dictionary or row.size() != 3:
					return _fail("invalid_profile_file")
				var score: Variant = row.get("score")
				if score is String:
					if score.is_empty() or not score.is_valid_int() or str(int(score)) != score or int(score) < 0:
						return _fail("invalid_profile_score")
				elif not Config.wire_integer(score, 0, 9007199254740991):
					return _fail("invalid_profile_score")
				if not Config.wire_integer(row.get("difficulty"), 0, 255):
					return _fail("invalid_profile_file")
				converted.append({"score": int(score), "name": row.get("name"), "difficulty": int(row.difficulty)})
			bank.append(converted)
	if not begin(1, path, bank, table, source):
		return false
	return true if _file_hash == initial_hash else _fail("changed_profile_file")


func begin(player: int, path: String, bank: Array, table: int, source: String) -> bool:
	if player != 1 or not _path.is_empty() or table < 0 or table >= 20 or bank.size() != 20:
		return _fail("invalid_profile_owner")
	if not Config.hex_string(source, 64):
		return _fail("invalid_profile_source")
	for rows in bank:
		if not Model.valid_rows(rows):
			return _fail("invalid_profile_rows")
	_path = ProjectSettings.globalize_path(path)
	_bank = bank.duplicate(true)
	_table = table
	Scores.sort_high_scores([_bank[_table]])
	_source = source
	_file_hash = _hash()
	return true


func apply(transaction: Dictionary) -> bool:
	if _path.is_empty() or not error.is_empty() or not transaction.get("digest") is String:
		return false
	var body := transaction.duplicate(true)
	body.erase("digest")
	if Data.digest(body) != transaction.digest:
		return _fail("invalid_profile_transaction")
	if transaction.get("source") != _source:
		return _fail("changed_profile_source")
	if _receipts.has(transaction.digest):
		return true
	if _receipts.size() >= 2:
		return _fail("too_many_profile_transactions")
	if not Model.valid_rows(transaction.get("after")) or transaction.get("before") != _bank[_table]:
		return _fail("changed_profile_table")
	if _hash() != _file_hash:
		return _fail("changed_profile_file")
	var bank := _bank.duplicate(true)
	bank[_table] = transaction.after.duplicate(true)
	var encoded := []
	for rows in bank:
		var table := []
		for row in rows:
			# Existing reader calls int(score), accepting strings and old numbers.
			# Strings preserve exact integers across Godot JSON's floating parser.
			table.append({"score": str(row.score), "name": row.name, "difficulty": row.difficulty})
		encoded.append(table)
	var temporary := _path + ".network.tmp"
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return _fail("profile_write_failed")
	file.store_string(JSON.stringify({"version": 1, "tables": encoded}))
	file.flush()
	var ok := file.get_error() == OK
	file.close()
	if not ok or DirAccess.rename_absolute(temporary, _path) != OK:
		DirAccess.remove_absolute(temporary)
		return _fail("profile_write_failed")
	_bank = bank
	_file_hash = _hash()
	_receipts[transaction.digest] = true
	return true


func bank() -> Array:
	return _bank.duplicate(true)


func _hash() -> String:
	return FileAccess.get_sha256(_path) if FileAccess.file_exists(_path) else "missing"


func _fail(reason: String) -> bool:
	error = reason
	return false
