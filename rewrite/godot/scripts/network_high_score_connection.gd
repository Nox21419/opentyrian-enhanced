## Owns high-score agreement and the host's explicit persistence boundary.
extends RefCounted

const Flow := preload("res://scripts/network_high_score_flow.gd")
const Wire := preload("res://scripts/network_high_score_wire.gd")
const Profile := preload("res://scripts/network_high_score_profile.gd")
const Scores := preload("res://scripts/high_scores.gd")
var flow: RefCounted
var profile: RefCounted
var error := ""
var sequence := 0


func begin(
	context: Dictionary, config: Dictionary, record: Dictionary, proposal: Dictionary, history: Dictionary
) -> bool:
	if flow != null:
		return sequence == context.decision
	sequence = context.decision
	var rows := []
	if context.player == 1:
		profile = Profile.new()
		var source := preload("res://scripts/network_episode_end.gd").build(config, record, proposal, history)
		if (
			source.is_empty()
			or not profile.begin_current(Scores.SCORES_PATH, 11 + (history.initial_episode - 1) * 2, source.digest)
		):
			return _fail("invalid_host_high_score_profile" if profile.error.is_empty() else profile.error)
		rows = profile.bank()[11 + (history.initial_episode - 1) * 2]
	flow = Flow.new()
	return flow.configure(context, config, record, proposal, history, rows, Time.get_ticks_msec()) or _fail(flow.error)


func receive(message: Dictionary) -> bool:
	return flow != null and (flow.receive(message, Time.get_ticks_msec()) or _fail(flow.error))


func settle(transport: Node) -> bool:
	if flow == null:
		return true
	if not flow.poll(Time.get_ticks_msec()):
		return _fail(flow.error)
	var transaction: Dictionary = flow.pending_transaction()
	if not transaction.is_empty():
		if profile == null or not profile.apply(transaction):
			return _fail("high_score_save_failed" if profile == null else profile.error)
		Scores.t2k_high_scores = profile.bank()
		if not flow.persisted(transaction.digest, Time.get_ticks_msec()):
			return _fail(flow.error)
	for message in flow.take_messages():
		var packet := Wire.encode(message)
		if packet.is_empty() or transport.send_packet(packet) != OK:
			return _fail("high_score_send_failed")
	return true


func _fail(reason: String) -> bool:
	error = reason
	return false
