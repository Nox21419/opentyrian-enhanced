## Explicit detached tick adapter; no clock, transport, scene or hardware polling.
## Caller owns the native node and must authorize activation after startup.
extends RefCounted

const Wire := preload("res://scripts/network_protocol.gd")
const Buffer := preload("res://scripts/network_input_buffer.gd")
const Policy := preload("res://scripts/network_touch_inputs.gd")

var error := ""
var ticks_executed := 0
var _sim: Node
var _buffer := Buffer.new()
var _config := {}
var _session := ""
var _epoch := 0
var _player := 0
var _active := false


func activate(sim: Node, config: Dictionary, session: String, epoch: int, player: int) -> bool:
	stop()
	if not Policy.supports(config) or not is_instance_valid(sim):
		return _fail("invalid_touch_session")
	for method in [
		"tick", "level_ended", "network_diagnostic_digest", "set_player_mice", "set_analog", "set_new_key", "step"
	]:
		if not sim.has_method(method):
			return _fail("invalid_simulation")
	if sim.tick() != 0 or sim.level_ended() or sim.network_diagnostic_digest().length() != 64:
		return _fail("simulation_not_at_start")
	if _buffer.configure(session, epoch, player, config.input_delay) != OK:
		return _fail("invalid_touch_session")
	_sim = sim
	_config = config.duplicate(true)
	_session = session
	_epoch = epoch
	_player = player
	_active = true
	return true


func stop() -> void:
	_active = false
	_sim = null
	_buffer.reset()
	_config.clear()
	_session = ""
	_epoch = 0
	_player = 0
	ticks_executed = 0
	error = ""


func needs_local_input() -> bool:
	return _running() and _buffer.needs_local_input()


## Only the agreed pause/resume controller may call this. No native setters,
## reload, RNG changes or replay of the already-executed absolute tick history.
func resume_inputs(epoch: int, tick: int) -> bool:
	if not _running() or epoch != _epoch + 1 or tick != ticks_executed or _sim.tick() != tick:
		return _fail("invalid_input_resume")
	var neutral := [Policy.neutral_frame(1, _config), Policy.neutral_frame(2, _config)]
	if _buffer.configure_at(_session, epoch, _player, _config.input_delay, tick, neutral) != OK:
		return _fail("invalid_input_resume")
	_epoch = epoch
	return true


## Waiting/retransmission returns the exact frozen packet. The caller should
## poll hardware only after needs_local_input(), never once per render frame.
func capture_local(frame: Dictionary) -> PackedByteArray:
	if not _running():
		return PackedByteArray()
	if _buffer.needs_local_input() and not Policy.valid(frame, _player, _config):
		_fail("invalid_local_input")
		return PackedByteArray()
	return Wire.encode(_buffer.capture_local(frame))


func receive(packet: PackedByteArray) -> int:
	if not _running():
		return Buffer.Result.STOPPED
	var message := {}
	if packet.size() >= Wire.HEADER_BYTES:
		# Validate the actual packet context first, then discard old epochs.
		# Sender is always the role bound by the caller's transport, not a claim.
		message = Wire.decode(packet, packet.slice(8, 24).hex_encode(), packet.decode_u32(24), 3 - _player)
	if message.is_empty():
		_fail("invalid_remote_input")
		return Buffer.Result.INVALID
	if message.session != _session or message.epoch != _epoch:
		return Buffer.Result.WRONG_SESSION
	if message.kind != Wire.Kind.INPUT or not Policy.valid(message.frame, 3 - _player, _config):
		_fail("invalid_remote_input")
		return Buffer.Result.INVALID
	var result: int = _buffer.receive(message)
	if result in [Buffer.Result.INVALID, Buffer.Result.TOO_FAR, Buffer.Result.CONFLICT]:
		_fail("conflicting_input" if result == Buffer.Result.CONFLICT else "invalid_input_window")
	return result


func advance() -> bool:
	if not _running() or _buffer.needs_local_input() or not _buffer.ready():
		return false
	if _sim.tick() != ticks_executed:
		return _fail("simulation_tick_changed")
	var pair: Dictionary = _buffer.take_tick()
	var first: Dictionary = pair.inputs[0]
	var second: Dictionary = pair.inputs[1]
	_sim.set_player_mice(
		first.mouse_mask, first.mouse_dx, first.mouse_dy, second.mouse_mask, second.mouse_dx, second.mouse_dy
	)
	_sim.set_analog(0, 0, 0, 0)
	_sim.set_new_key(first.new_key or second.new_key)
	_sim.step(first.mask, second.mask)
	if _sim.tick() != ticks_executed + 1:
		return _fail("simulation_did_not_advance")
	ticks_executed += 1
	return true


func _running() -> bool:
	if not _active:
		return false
	if not is_instance_valid(_sim):
		return _fail("simulation_unavailable")
	return not _sim.level_ended()


func _fail(reason: String) -> bool:
	error = reason
	_active = false
	_sim = null
	_buffer.reset()
	return false
