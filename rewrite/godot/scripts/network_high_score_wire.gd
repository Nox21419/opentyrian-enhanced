## Bounded ordered primitive arrays; distinct from simulation tick packets.
extends RefCounted

const Config := preload("res://scripts/network_configuration.gd")
const Model := preload("res://scripts/network_episode_high_scores.gd")
const MAGIC := "OT2H"
const MAX_BYTES := 2048
const KINDS := ["open", "edit", "submit", "ready", "advance", "finish"]
const FIELDS := ["kind", "player", "session", "epoch", "tick", "decision", "serial", "digest", "payload"]


static func valid(message: Dictionary) -> bool:
	if message.size() != FIELDS.size():
		return false
	for field in FIELDS:
		if not message.has(field):
			return false
	if (
		message.kind not in KINDS
		or not Config.integer(message.player, 1, 2)
		or not Config.hex_string(message.session, 32)
	):
		return false
	for field in ["epoch", "tick"]:
		if not Config.integer(message[field], 1, 0xffffffff):
			return false
	if (
		not Config.integer(message.decision, 1, 2)
		or not Config.integer(message.serial, 1, 5)
		or not Config.hex_string(message.digest, 64)
	):
		return false
	if not message.payload is Array or (message.kind in ["open", "edit", "submit", "advance"] and message.player != 1):
		return false
	var p: Array = message.payload
	match message.kind:
		"open":
			return not decode_rows(p).is_empty()
		"edit":
			return p.size() == 2 and Config.integer(p[0], 1, 0xffffffff) and valid_name(p[1])
		"submit":
			return p.size() == 3 and valid_name(p[0]) and p[1] is bool and Config.hex_string(p[2], 64)
	return p.is_empty()


static func valid_name(value: Variant) -> bool:
	if not value is String or value.length() > 28 or value.to_utf8_buffer().size() > 112:
		return false
	for character in value:
		if character.unicode_at(0) < 32:
			return false
	return true


static func encode_rows(rows: Array) -> Array:
	if not Model.valid_rows(rows):
		return []
	var result := []
	for row in rows:
		result.append(["%016x" % row.score, row.name, row.difficulty])
	return result


static func decode_rows(value: Variant) -> Array:
	if not value is Array or value.size() != 3:
		return []
	var result := []
	for row in value:
		if (
			not row is Array
			or row.size() != 3
			or not Config.hex_string(row[0], 16)
			or row[0][0] not in "01234567"
			or not valid_name(row[1])
		):
			return []
		if not Config.wire_integer(row[2], 0, 255):
			return []
		result.append({"score": row[0].hex_to_int(), "name": row[1], "difficulty": int(row[2])})
	return result if Model.valid_rows(result) else []


static func encode(message: Dictionary) -> PackedByteArray:
	if not valid(message):
		return PackedByteArray()
	var body := [1]
	for field in FIELDS:
		body.append(message[field])
	var bytes := MAGIC.to_utf8_buffer() + JSON.stringify(body).to_utf8_buffer()
	return bytes if bytes.size() <= MAX_BYTES else PackedByteArray()


static func decode(bytes: PackedByteArray, sender: int) -> Dictionary:
	if bytes.size() < 4 or bytes.size() > MAX_BYTES or bytes.slice(0, 4) != MAGIC.to_utf8_buffer():
		return {}
	var raw := bytes.slice(4)
	var text := raw.get_string_from_utf8()
	if text.to_utf8_buffer() != raw:
		return {}
	var json := JSON.new()
	if json.parse(text) != OK or not json.data is Array:
		return {}
	var body: Array = json.data
	if body.size() != 10 or not Config.wire_integer(body[0], 1, 1):
		return {}
	var message := {}
	for index in FIELDS.size():
		message[FIELDS[index]] = body[index + 1]
	for field in ["player", "epoch", "tick", "decision", "serial"]:
		if not Config.wire_integer(message[field], 1, 0xffffffff):
			return {}
		message[field] = int(message[field])
	if message.get("kind") == "edit" and message.payload is Array and message.payload.size() == 2:
		if not Config.wire_integer(message.payload[0], 1, 0xffffffff):
			return {}
		message.payload[0] = int(message.payload[0])
	if message.get("kind") == "open":
		var rows := decode_rows(message.payload)
		if rows.is_empty():
			return {}
		message.payload = encode_rows(rows)
	return message if message.player == sender and valid(message) else {}
