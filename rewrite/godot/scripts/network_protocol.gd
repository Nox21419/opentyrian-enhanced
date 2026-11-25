## Transport-independent gameplay messages. The adapter binds session and sender.
## Fixed-size little-endian packets: no object/Variant/JSON deserialization.
extends RefCounted

enum Kind {
	INPUT = 1,
	STATE,
	READY,
	START,
	PAUSE,
	LEAVE,
	LEVEL_RESULT,
	LEVEL_READY,
	LEVEL_ADVANCE,
	CONTINUATION,
	CONTINUATION_ACK,
	CONTINUATION_COMMIT
}
enum Pause { REQUEST_PAUSE, COMMIT_PAUSE, REQUEST_RESUME, COMMIT_RESUME }
enum Leave { QUIT, TIMEOUT, DESYNC, INCOMPATIBLE, PROTOCOL_ERROR }

const VERSION := 1
const MAGIC := 0x4e32544f  # OT2N, little-endian.
const HEADER_BYTES := 36
const MAX_PACKET_BYTES := 72
const MAX_TICK := 0xffffffff
const MAX_I32 := 0x7fffffff
const MIN_I32 := -0x80000000
const BASE_FIELDS := ["kind", "session", "epoch", "player", "tick", "sequence"]
const FRAME_FIELDS := ["mask", "mouse_mask", "mouse_dx", "mouse_dy", "analog_x", "analog_y", "new_key"]


static func neutral_frame() -> Dictionary:
	return {"mask": 0, "mouse_mask": 0, "mouse_dx": 0, "mouse_dy": 0, "analog_x": 0, "analog_y": 0, "new_key": false}


static func valid_session(value: Variant) -> bool:
	return _hex(value, 32)


static func valid_frame(frame: Variant) -> bool:
	if not _fields(frame, FRAME_FIELDS):
		return false
	if not _integer(frame.mask, 0, 0x3ff) or not _integer(frame.mouse_mask, 0, 0xf0):
		return false
	if frame.mouse_mask & 0x0f != 0 or not frame.new_key is bool:
		return false
	for field in ["mouse_dx", "mouse_dy", "analog_x", "analog_y"]:
		if not _integer(frame[field], MIN_I32, MAX_I32):
			return false
	return true


static func valid_message(message: Variant) -> bool:
	if not message is Dictionary or not _integer(message.get("kind"), Kind.INPUT, Kind.CONTINUATION_COMMIT):
		return false
	var extra := "frame" if message.kind == Kind.INPUT else "digest"
	if message.kind in [Kind.PAUSE, Kind.LEAVE]:
		extra = "action" if message.kind == Kind.PAUSE else "reason"
	var fields := BASE_FIELDS + [extra]
	if message.kind == Kind.LEVEL_RESULT:
		fields.append("elapsed")
	if not _fields(message, fields):
		return false
	if not valid_session(message.session) or not _integer(message.epoch, 1, MAX_TICK):
		return false
	if not _integer(message.player, 1, 2) or not _integer(message.tick, 0, MAX_TICK):
		return false
	if message.kind >= Kind.LEVEL_RESULT and message.tick == 0:
		return false
	if message.kind in [Kind.INPUT, Kind.STATE, Kind.LEVEL_RESULT]:
		if not _integer(message.sequence, 0, 0):
			return false
	elif not _integer(message.sequence, 1, MAX_TICK):
		return false
	match message.kind:
		Kind.INPUT:
			return valid_frame(message.frame)
		Kind.START:
			return message.player == 1 and _hex(message.digest, 64)
		Kind.STATE, Kind.READY:
			return _hex(message.digest, 64)
		Kind.LEVEL_RESULT:
			return (
				_hex(message.digest, 64)
				and _integer(message.elapsed, 0, MAX_TICK)
				and (message.player == 1 or message.elapsed == 0)
			)
		Kind.LEVEL_READY, Kind.LEVEL_ADVANCE:
			return (
				_hex(message.digest, 64)
				and message.sequence in [1, 2, 3]
				and (message.kind == Kind.LEVEL_READY or message.player == 1)
			)
		Kind.CONTINUATION, Kind.CONTINUATION_ACK, Kind.CONTINUATION_COMMIT:
			return (
				_hex(message.digest, 64)
				and message.sequence in [1, 2]
				and message.player == (2 if message.kind == Kind.CONTINUATION_ACK else 1)
			)
		Kind.PAUSE:
			if not _integer(message.action, Pause.REQUEST_PAUSE, Pause.COMMIT_RESUME):
				return false
			return message.player == 1 or message.action in [Pause.REQUEST_PAUSE, Pause.REQUEST_RESUME]
		Kind.LEAVE:
			return _integer(message.reason, Leave.QUIT, Leave.PROTOCOL_ERROR)
	return false


static func encode(message: Dictionary) -> PackedByteArray:
	if not valid_message(message):
		return PackedByteArray()
	var packet := PackedByteArray()
	packet.resize(_packet_size(message.kind))
	packet.encode_u32(0, MAGIC)
	packet.encode_u16(4, VERSION)
	packet[6] = message.kind
	packet[7] = message.player
	var session_bytes: PackedByteArray = message.session.hex_decode()
	for i in 16:
		packet[8 + i] = session_bytes[i]
	packet.encode_u32(24, message.epoch)
	packet.encode_u32(28, message.tick)
	packet.encode_u32(32, message.sequence)
	match message.kind:
		Kind.INPUT:
			packet.encode_u16(36, message.frame.mask)
			packet[38] = message.frame.mouse_mask
			packet[39] = int(message.frame.new_key)
			for i in 4:
				packet.encode_s32(40 + i * 4, message.frame[FRAME_FIELDS[2 + i]])
		Kind.PAUSE:
			packet[HEADER_BYTES] = message.action
		Kind.LEAVE:
			packet[HEADER_BYTES] = message.reason
		_:  # Every other validated kind has a fixed digest payload.
			var digest: PackedByteArray = message.digest.hex_decode()
			for i in 32:
				packet[HEADER_BYTES + i] = digest[i]
			if message.kind == Kind.LEVEL_RESULT:
				packet.encode_u32(68, message.elapsed)
	return packet


## The adapter supplies the authenticated role, not a role claimed by the packet.
## Session/epoch filtering happens before allocating a frame or digest dictionary.
static func decode(packet: PackedByteArray, session: String, epoch: int, sender: int) -> Dictionary:
	if packet.size() < HEADER_BYTES or packet.size() > MAX_PACKET_BYTES:
		return {}
	if packet.decode_u32(0) != MAGIC or packet.decode_u16(4) != VERSION:
		return {}
	var kind := int(packet[6])
	if packet.size() != _packet_size(kind):
		return {}
	if packet[7] != sender or packet.slice(8, 24).hex_encode() != session or packet.decode_u32(24) != epoch:
		return {}
	var message := {
		"kind": kind,
		"session": session,
		"epoch": epoch,
		"player": sender,
		"tick": packet.decode_u32(28),
		"sequence": packet.decode_u32(32)
	}
	match kind:
		Kind.INPUT:
			if packet[39] > 1:
				return {}
			var frame := neutral_frame()
			frame.mask = packet.decode_u16(36)
			frame.mouse_mask = int(packet[38])
			frame.new_key = bool(packet[39])
			for i in 4:
				frame[FRAME_FIELDS[2 + i]] = packet.decode_s32(40 + i * 4)
			message.frame = frame
		Kind.PAUSE:
			message.action = int(packet[HEADER_BYTES])
		Kind.LEAVE:
			message.reason = int(packet[HEADER_BYTES])
		_:  # Exact packet size has already rejected unknown kinds.
			message.digest = packet.slice(HEADER_BYTES, 68).hex_encode()
			if kind == Kind.LEVEL_RESULT:
				message.elapsed = packet.decode_u32(68)
	return message if valid_message(message) else {}


static func _packet_size(kind: int) -> int:
	match kind:
		Kind.INPUT:
			return 56
		Kind.LEVEL_RESULT:
			return 72
		Kind.PAUSE, Kind.LEAVE:
			return 37
	return 68 if kind >= Kind.STATE and kind <= Kind.CONTINUATION_COMMIT else 0


static func _fields(value: Variant, fields: Array) -> bool:
	if not value is Dictionary or value.size() != fields.size():
		return false
	for field in fields:
		if not value.has(field):
			return false
	return true


static func _integer(value: Variant, low: int, high: int) -> bool:
	return value is int and value >= low and value <= high


static func _hex(value: Variant, length: int) -> bool:
	if not value is String or value.length() != length:
		return false
	for character in value:
		if character not in "0123456789abcdef":
			return false
	return true
