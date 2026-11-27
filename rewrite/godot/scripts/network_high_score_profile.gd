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
