extends GdUnitTestSuite

const Pages := preload("res://scripts/network_story_pages.gd")
const StoryData := preload("res://scripts/network_story_script.gd")
const Wire := preload("res://scripts/network_protocol.gd")
const SESSION := "12121212121212121212121212121212"
const SOURCE := "abababababababababababababababababababababababababababababababab"
const BACKGROUND := "cdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcdcd"
const CONTEXT := {"warning_red": false, "use_last_bank": false}


class OrderProbe:
	extends "res://scripts/network_gameplay_connection.gd"
	var first := {}
	var done := false

	func committed_continuation(sequence := 1) -> Dictionary:
		return first.duplicate(true) if sequence == 1 else {}

	func story_complete(sequence: int) -> bool:
		return done and sequence == 1


func test_next_decision_context_waits_for_prior_nonempty_story_completion() -> void:
	var probe: Node = auto_free(OrderProbe.new())
	add_child(probe)
	probe.first = {"script": _descriptor().script}
	assert_bool(probe._story_order_ready(1)).is_true()
	assert_bool(probe._story_order_ready(2)).is_false()
	probe.done = true
	assert_bool(probe._story_order_ready(2)).is_true()
	probe.get("_story_pages")[2] = Pages.new()
	assert_bool(probe._story_order_ready(1)).is_false()
	probe.first.script.screens.clear()
	probe.done = false
	assert_bool(probe._story_order_ready(2)).is_true()


func _descriptor() -> Dictionary:
	return StoryData.prepare(
		{
			"stop": "level",
			"screens":
			[
				{"directive": "]W 00[", "text": PackedStringArray(["FIRST"])},
				{"directive": "]W 00[", "text": PackedStringArray(["SECOND"])}
			]
		},
		SOURCE,
		CONTEXT,
		BACKGROUND
	)


func _pair() -> Array:
	var pair := [Pages.new(), Pages.new()]
	for i in 2:
		assert_bool(pair[i].configure(SESSION, 2, i + 1, 100, 2, _descriptor())).is_true()
	return pair


func _deliver(sender: RefCounted, receiver: RefCounted, now := 10) -> Array:
	var messages: Array = sender.take_messages()
	for message in messages:
		var packet := Wire.encode(message)
		assert_int(packet.size()).is_equal(68)
		var decoded := Wire.decode(packet, SESSION, 2, message.player)
		assert_dict(decoded).is_equal(message)
		assert_bool(receiver.receive(decoded, now)).is_true()
	return messages


func _round(pair: Array, page: int, now := 1) -> void:
	var digest := StoryData.page_digest(_descriptor(), page)
	assert_bool(pair[0].ready(page, digest, now)).is_true()
	_deliver(pair[0], pair[1], now + 1)
	assert_bool(pair[0].request_advance(page, digest, now + 2)).is_true()
	assert_int(pair[0].committed_page()).is_equal(page - 1)
	assert_bool(pair[1].ready(page, digest, now + 3)).is_true()
	assert_bool(pair[1].request_advance(page, digest, now + 3)).is_false()
	_deliver(pair[1], pair[0], now + 4)
	var advances := _deliver(pair[0], pair[1], now + 5)
	assert_int(advances.size()).is_equal(1)
	for peer in pair:
		assert_int(peer.committed_page()).is_equal(page)
	assert_bool(pair[1].has_seen_control(advances[0])).is_true()
	assert_bool(pair[1].receive(advances[0], now + 6)).is_true()


func test_two_pages_wait_for_both_ready_then_host_commit_and_matching_final_context() -> void:
	var pair := _pair()
	_round(pair, 1)
	_round(pair, 2, 20)
	assert_bool(pair[0].finish(CONTEXT, 40)).is_true()
	var finish_messages := _deliver(pair[0], pair[1], 41)
	assert_bool(pair[1].complete()).is_false()
	assert_bool(pair[1].finish(CONTEXT, 42)).is_true()
	_deliver(pair[1], pair[0], 43)
	for peer in pair:
		assert_bool(peer.complete()).is_true()
		assert_dict(peer.final_context()).is_equal(CONTEXT)
		assert_bool(peer.poll(999999999)).is_true()
	assert_bool(pair[1].receive(finish_messages[0], 999999999)).is_true()
	assert_bool(pair[0].finish(CONTEXT, 999999999)).is_true()
	assert_array(pair[0].take_messages()).is_empty()


func test_both_ready_human_wait_has_no_timer_and_render_duplicates_do_not_extend_deadline() -> void:
	var pair := _pair()
	var digest := StoryData.page_digest(_descriptor(), 1)
	for peer in pair:
		assert_bool(peer.ready(1, digest, 1)).is_true()
	_deliver(pair[0], pair[1], 2)
	_deliver(pair[1], pair[0], 2)
	for peer in pair:
		assert_bool(peer.poll(999999999)).is_true()
	assert_bool(pair[0].request_advance(1, digest, 999999999)).is_true()
	_deliver(pair[0], pair[1], 999999999)
	pair = _pair()
	assert_bool(pair[0].ready(1, digest, 1)).is_true()
	var message: Dictionary = pair[0].take_messages()[0]
	assert_bool(pair[1].receive(message, 2)).is_true()
	assert_bool(pair[1].receive(message, Pages.RENDER_TIMEOUT_MS + 1)).is_true()
	assert_bool(pair[1].poll(Pages.RENDER_TIMEOUT_MS + 2)).is_false()
	assert_str(pair[1].error).is_equal("story_timeout")


func test_mismatched_entry_context_script_or_background_cannot_agree_a_page() -> void:
	for field in ["source", "context", "background", "script"]:
		var pair := _pair()
		var descriptor := _descriptor()
		match field:
			"source":
				descriptor.source = BACKGROUND
			"context":
				descriptor.context.warning_red = true
			"background":
				descriptor.background = SOURCE
			"script":
				descriptor.script.screens[0].text[0] = "CHANGED"
		descriptor = StoryData.prepare(descriptor.script, descriptor.source, descriptor.context, descriptor.background)
		pair[1] = Pages.new()
		assert_bool(pair[1].configure(SESSION, 2, 2, 100, 2, descriptor)).is_true()
		assert_bool(pair[0].ready(1, StoryData.page_digest(_descriptor(), 1), 1)).is_true()
		var message: Dictionary = pair[0].take_messages()[0]
		assert_bool(pair[1].receive(message, 2)).is_false()
		assert_str(pair[1].error).is_equal("story_page_mismatch")


func test_wrong_roles_context_skips_and_early_finish_are_rejected() -> void:
	var pair := _pair()
	var digest := StoryData.page_digest(_descriptor(), 1)
	assert_bool(pair[0].ready(1, digest, 1)).is_true()
	var message: Dictionary = pair[0].take_messages()[0]
	message.kind = Wire.Kind.STORY_ADVANCE
	assert_bool(pair[1].receive(message, 2)).is_false()
	assert_str(pair[1].error).is_equal("premature_story_advance")
	for field in ["tick", "epoch", "sequence", "player"]:
		pair = _pair()
		var bad := message.duplicate()
		match field:
			"tick":
				bad.tick = 101
			"epoch":
				bad.epoch = 3
			"sequence":
				bad.sequence = (1 << 16) | 1
			"player":
				bad.player = 2
		assert_bool(pair[1].receive(bad, 2)).is_false()
	pair = _pair()
	assert_bool(pair[0].ready(2, StoryData.page_digest(_descriptor(), 2), 1)).is_false()
	assert_str(pair[0].error).is_equal("skipped_story_page")
	pair = _pair()
	assert_bool(pair[0].finish(CONTEXT, 1)).is_false()
	assert_str(pair[0].error).is_equal("story_finished_before_pages")


func test_finish_context_mismatch_and_missing_finish_timeout() -> void:
	var pair := _pair()
	_round(pair, 1)
	_round(pair, 2, 20)
	assert_bool(pair[0].finish(CONTEXT, 40)).is_true()
	_deliver(pair[0], pair[1], 41)
	assert_bool(pair[1].finish({"warning_red": true, "use_last_bank": false}, 42)).is_false()
	assert_str(pair[1].error).is_equal("story_context_mismatch")
	assert_bool(pair[0].poll(40 + Pages.FINISH_TIMEOUT_MS)).is_false()
	assert_str(pair[0].error).is_equal("story_timeout")


func test_codec_exact_sizes_sequence_domains_and_sender_roles() -> void:
	var pair := _pair()
	assert_bool(pair[0].ready(1, StoryData.page_digest(_descriptor(), 1), 1)).is_true()
	var message: Dictionary = pair[0].take_messages()[0]
	var packet := Wire.encode(message)
	for size in packet.size():
		assert_dict(Wire.decode(packet.slice(0, size), SESSION, 2, 1)).is_empty()
	packet.append(0)
	assert_dict(Wire.decode(packet, SESSION, 2, 1)).is_empty()
	for kind in [Wire.Kind.STORY_READY, Wire.Kind.STORY_ADVANCE, Wire.Kind.STORY_DONE]:
		for decision in [1, 2]:
			var valid := message.duplicate()
			valid.kind = kind
			valid.sequence = (decision << 16) | (129 if kind == Wire.Kind.STORY_DONE else 128)
			assert_int(Wire.encode(valid).size()).is_equal(68)
			valid.player = 2
			assert_bool(Wire.encode(valid).is_empty()).is_equal(kind == Wire.Kind.STORY_ADVANCE)
	for sequence in [0, 1, 65536, (3 << 16) | 1, (1 << 16) | 129, (2 << 16) | 130]:
		var invalid := message.duplicate()
		invalid.sequence = sequence
		assert_bool(Wire.encode(invalid).is_empty()).is_true()


func test_stale_packets_and_descriptor_mutation_do_not_change_prepared_story() -> void:
	var pair := _pair()
	assert_bool(pair[0].ready(1, StoryData.page_digest(_descriptor(), 1), 1)).is_true()
	var message: Dictionary = pair[0].take_messages()[0]
	message.epoch = 1
	assert_bool(pair[1].receive(message, 2)).is_true()
	message.epoch = 2
	message.session = "34".repeat(16)
	assert_bool(pair[1].receive(message, 3)).is_true()
	assert_int(pair[1].committed_page()).is_equal(0)
	var descriptor := _descriptor()
	var pages := Pages.new()
	assert_bool(pages.configure(SESSION, 2, 1, 100, 2, descriptor)).is_true()
	descriptor.pages[0] = SOURCE
	assert_bool(StoryData.valid(descriptor)).is_false()
	assert_bool(pages.ready(1, StoryData.page_digest(_descriptor(), 1), 1)).is_true()
