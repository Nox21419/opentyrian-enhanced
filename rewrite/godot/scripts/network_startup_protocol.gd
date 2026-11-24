## Bounded startup packets, distinct from gameplay tick packets and the LAN hello.
## Ordered arrays avoid ambiguous duplicate JSON object keys. No object decoding.
extends RefCounted

const Config := preload("res://scripts/network_configuration.gd")
const VERSION := 1
const MAX_BYTES := 2048
const KINDS := ["hello", "config", "accept", "loaded", "ready", "start"]
const IDENTITIES := ["native", "client", "content", "engine"]


static func valid_identity(identity: Variant) -> bool:
	if not identity is Dictionary or identity.size() != IDENTITIES.size():
		return false
	for field in IDENTITIES:
		if not Config.hex_string(identity.get(field), 64):
			return false
	return true


static func valid(message: Variant) -> bool:
	if not message is Dictionary or message.get("kind") not in KINDS:
		return false
	if not Config.integer(message.get("player"), 1, 2):
		return false
	if message.kind == "hello":
		return message.size() == 3 and valid_identity(message.get("identity"))
	if not Config.hex_string(message.get("session"), 32) or not Config.integer(message.get("epoch"), 1, 0xffffffff):
		return false
	if not Config.integer(message.get("sequence"), 1, 0xffffffff) or not Config.hex_string(message.get("digest"), 64):
		return false
	if message.kind == "config":
		return (
			message.size() == 7
			and message.player == 1
			and Config.valid(message.get("config"))
			and Config.digest(message.config) == message.digest
		)
	if message.kind == "accept":
		return message.size() == 6 and message.player == 2
	return (
		message.size() == 7
		and Config.hex_string(message.get("state"), 64)
		and (message.kind != "start" or message.player == 1)
	)


static func encode(message: Dictionary) -> PackedByteArray:
	if not valid(message):
		return PackedByteArray()
	var body := [VERSION, message.kind, message.player]
	if message.kind == "hello":
		for field in IDENTITIES:
			body.append(message.identity[field])
	else:
		body.append_array([message.session, message.epoch, message.sequence, message.digest])
		if message.kind == "config":
			body.append(Config.values(message.config))
		elif message.kind != "accept":
			body.append(message.state)
	var packet := ("OT2S" + JSON.stringify(body)).to_utf8_buffer()
	return packet if packet.size() <= MAX_BYTES else PackedByteArray()


static func decode(packet: PackedByteArray, expected_sender: int) -> Dictionary:
	if packet.size() < 5 or packet.size() > MAX_BYTES or packet.slice(0, 4) != "OT2S".to_utf8_buffer():
		return {}
	# This schema contains only ASCII tags, integer fields and hex digests. Reject
	# arbitrary UTF-8 before decoding, avoiding engine diagnostics on bad bytes.
	for byte in packet:
		if byte < 32 or byte > 126:
			return {}
	var json := JSON.new()
	if json.parse(packet.slice(4).get_string_from_utf8()) != OK:
		return {}
	var body: Variant = json.data
	if not body is Array or body.size() < 3 or not Config.wire_integer(body[0], VERSION, VERSION):
		return {}
	if body[1] not in KINDS or not Config.wire_integer(body[2], 1, 2) or int(body[2]) != expected_sender:
		return {}
	var message := {"kind": body[1], "player": int(body[2])}
	if message.kind == "hello":
		if body.size() != 7:
			return {}
		message.identity = {}
		for i in IDENTITIES.size():
			message.identity[IDENTITIES[i]] = body[3 + i]
	else:
		if body.size() != (7 if message.kind == "accept" else 8):
			return {}
		if not Config.wire_integer(body[4], 1, 0xffffffff) or not Config.wire_integer(body[5], 1, 0xffffffff):
			return {}
		message.merge({"session": body[3], "epoch": int(body[4]), "sequence": int(body[5]), "digest": body[6]})
		if message.kind == "config":
			message.config = Config.from_values(body[7])
		elif message.kind != "accept":
			message.state = body[7]
	return message if valid(message) else {}
