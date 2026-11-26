## Detached Android-profile simulation over ENet. Player scene/input/HUD wiring
## is separate; only explicit Ready, Start, capture and advance calls do work.
extends "res://scripts/network_preview_connection.gd"

const Runner := preload("res://scripts/network_touch_runner.gd")
const Buffer := preload("res://scripts/network_input_buffer.gd")
const Wire := preload("res://scripts/network_protocol.gd")
const Config := preload("res://scripts/network_configuration.gd")
const PauseController := preload("res://scripts/network_pause.gd")
const Completion := preload("res://scripts/network_completion.gd")
const LevelResult := preload("res://scripts/network_level_result.gd")
const Continuation := preload("res://scripts/network_continuation.gd")
const CampaignCursor := preload("res://scripts/network_campaign_cursor.gd")
const LevelLoad := preload("res://scripts/network_level_load.gd")
const Next := preload("res://scripts/network_next_level.gd")
const StoryScript := preload("res://scripts/network_story_script.gd")
const StoryPages := preload("res://scripts/network_story_pages.gd")
const EpisodeEnd := preload("res://scripts/network_episode_end.gd")
const EpisodeHint := preload("res://scripts/network_episode_hint.gd")
const EpisodeScore := preload("res://scripts/network_episode_score.gd")
var _runner := Runner.new()
var _activated := false
var _view_local := false
var _view_remote := false
var _pause := PauseController.new()
var _completion := Completion.new()
var _level_result := LevelResult.new()
var _continuation := Continuation.new()
var _campaign_cursor: RefCounted
var _continuation_candidates := {}
var _level_load := LevelLoad.new()
var _pending_preparation: RefCounted
var _load_sequence := 0
var _active_context := {}
var _active_request := {}
var _view_borrows := {}
var _pending_view_ready := false
var _awaiting_new_views := false
var _story_pages := {}
var _story_descriptors := {}
var _story_early := {}
var _story_receipts := {}
var _story_context := {"warning_red": false, "use_last_bank": false}


func _ready() -> void:
	super._ready()
	_connection.gameplay_packet_received.connect(_receive_input)


func stop() -> void:
	_clear_stories(true)
	_active_context.clear()
	_active_request.clear()
	_view_borrows.clear()
	_awaiting_new_views = false
	_clear_pending_load()
	_continuation = Continuation.new()
	_campaign_cursor = null
	_continuation_candidates.clear()
	_completion = Completion.new()
	_level_result = LevelResult.new()
	_pause = PauseController.new()
	_view_local = false
	_view_remote = false
	_runner.stop()
	_activated = false
	super.stop()


func confirm_ready() -> bool:
	if not _healthy() or _connection.startup.phase not in [Startup.Phase.LOADED, Startup.Phase.READY]:
		return false
	if not _preparation.verify_preview():
		if not _preparation.error.is_empty():
			_fail(_preparation.error)
		return false
	var accepted: bool = _connection.confirm_ready()
	return accepted and _healthy()


func start() -> bool:
	if not _healthy() or _connection.startup.phase != Startup.Phase.READY:
		return false
	if not _preparation.verify_preview():
		if not _preparation.error.is_empty():
			_fail(_preparation.error)
		return false
	var accepted: bool = _connection.start()
	return accepted and running()


func running() -> bool:
	return _activated and _healthy() and _connection.running


func needs_local_input() -> bool:
	return (
		running()
		and (not _awaiting_new_views or views_ready())
		and _pause.may_advance(ticks_executed())
		and _completion.may_advance(ticks_executed())
		and _runner.needs_local_input()
	)


func capture_local(frame: Dictionary) -> bool:
	if _awaiting_new_views and not views_ready():
		return false
	if not running() or not _pause.may_advance(ticks_executed()) or not _completion.may_advance(ticks_executed()):
		return false
	var packet: PackedByteArray = _runner.capture_local(frame)
	if not _runner.error.is_empty():
		return _fail(_runner.error)
	if packet.is_empty():
		return false
	if _connection.transport.send_packet(packet) != OK:
		return _fail("input_send_failed")
	return running()


func advance() -> bool:
	if _awaiting_new_views and not views_ready():
		return false
	if not running() or not _pause.may_advance(ticks_executed()) or not _completion.may_advance(ticks_executed()):
		return false
	var advanced: bool = _runner.advance()
	if not _runner.error.is_empty():
		return _fail(_runner.error)
	return advanced


func ticks_executed() -> int:
	return _runner.ticks_executed


## Borrow only: preparation retains ownership. Never parent/free this node.
## A view must recheck this accessor before using a previously borrowed node.
func simulation_for_view() -> Node:
	if not running():
		return null
	var native: Node = _preparation.get("_preview")
	return native if is_instance_valid(native) else null


func player_for_view() -> int:
	return int(_gameplay_context().get("player", 0)) if running() else 0


func _gameplay_context() -> Dictionary:
	return _active_context.duplicate() if not _active_context.is_empty() else _connection.startup.context()


func _configuration_digest() -> String:
	return (
		Next.configuration_digest(configuration()) if not _active_request.is_empty() else Config.digest(configuration())
	)


func continuation_level_for_view() -> Dictionary:
	return _active_request.get("script", {}).duplicate(true) if running() else {}


## Source-level bonus context, never the result's similarly named warp flag.
func bonus_completion_for_view() -> bool:
	return completion_agreed() and bool(_active_request.get("bonus_level", false))


func register_view_borrow(view: Node) -> bool:
	if not running() or not is_instance_valid(view) or simulation_for_view() == null:
		return false
	_view_borrows[view.get_instance_id()] = weakref(view)
	return true


func release_view_borrow(view: Node) -> void:
	if is_instance_valid(view):
		_view_borrows.erase(view.get_instance_id())


## Caller must detach all old views before swapping native ownership.
func adopt_next_level() -> bool:
	if not next_level_load_committed() or not _verify_continuation_state() or _pending_preparation == null:
		return false
	for id in _view_borrows.keys():
		if _view_borrows[id].get_ref() == null:
			_view_borrows.erase(id)
	if not _view_borrows.is_empty():
		return false
	if not _pending_preparation.verify_preview():
		return _fail(_pending_preparation.error)
	var request: Dictionary = _pending_preparation.continuation_request()
	if not Next.valid_request(request):
		return _fail("invalid_continuation_request")
	var context := _gameplay_context()
	context.epoch = _level_load.next_epoch
	var runner := Runner.new()
	var native: Node = _pending_preparation.get("_preview")
	if not runner.activate_continuation(native, request, context.session, context.epoch, context.player):
		return _fail(runner.error)
	var pause := PauseController.new()
	if not pause.configure(context.session, context.epoch, context.player, request.configuration.input_delay):
		return _fail(pause.error)
	var cursor := CampaignCursor.new(_pending_preparation.get("_data_dir"))
	if not cursor.begin_continuation(request.configuration, request.script, request.entry):
		return _fail(cursor.error)
	# Cursor construction reads scripts. Reverify both owned snapshots around it
	# and bind the request/state back to the already committed load digest.
	if not _verify_continuation_state():
		return false
	if not _pending_preparation.verify_preview():
		return _fail(_pending_preparation.error)
	if not _level_load.loaded(request.digest, _pending_preparation.preview_digest(), Time.get_ticks_msec()):
		return _fail(_level_load.error)
	var previous: RefCounted = _preparation
	_runner.stop()
	_runner = runner
	_preparation = _pending_preparation
	_pending_preparation = null
	_active_context = context
	_active_request = request.duplicate(true)
	_pause = pause
	_campaign_cursor = cursor
	_completion = Completion.new()
	_level_result = LevelResult.new()
	_continuation = Continuation.new()
	_continuation_candidates.clear()
	_view_local = false
	_view_remote = _pending_view_ready
	_awaiting_new_views = true
	_clear_pending_load()
	previous.clear()
	_clear_stories(false)
	changed.emit()
	return running()


## Production scene barrier, after its original entry fade. No core stepping.
func mark_view_ready() -> bool:
	if not running():
		return false
	if _view_local:
		return true
	if ticks_executed() != 0:
		return false
	var context: Dictionary = _gameplay_context()
	var packet := Wire.encode(
		{
			"kind": Wire.Kind.READY,
			"session": context.session,
			"epoch": context.epoch,
			"player": context.player,
			"tick": 0,
			"sequence": 1,
			"digest": _configuration_digest()
		}
	)
	if _connection.transport.send_packet(packet) != OK:
		return _fail("view_ready_send_failed")
	_view_local = true
	changed.emit()
	return running()


func views_ready() -> bool:
	return running() and _view_local and _view_remote


func request_pause() -> bool:
	if not views_ready() or _completion.active() or not _pause.request_pause(ticks_executed(), Time.get_ticks_msec()):
		return false
	return _settle_pause()


func request_resume() -> bool:
	if not views_ready() or _completion.active() or not _pause.request_resume(Time.get_ticks_msec()):
		return false
	return _settle_pause()


func inputs_quiesced() -> bool:
	return running() and (_pause.quiesced() or _completion.local_reached())


func pause_boundary_reached() -> bool:
	return running() and not _pause.may_advance(ticks_executed())


func pause_confirmed() -> bool:
	return running() and _pause.phase == PauseController.Phase.PAUSED


func local_paused() -> bool:
	return running() and _pause.local_paused()


func note_pause_boundary() -> bool:
	if running() and _pause.local_paused():
		return true
	if not running() or not _pause.reached(ticks_executed(), diagnostic_digest()):
		return _fail(_pause.error if not _pause.error.is_empty() else "invalid_pause_boundary")
	return _settle_pause()


func _settle_pause() -> bool:
	if not _pause.error.is_empty():
		return _fail(_pause.error)
	if _pause.needs_input_reset():
		if not _runner.resume_inputs(_pause.epoch + 1, _pause.target):
			return _fail(_runner.error)
		if not _pause.input_reset_done(diagnostic_digest()):
			return _fail(_pause.error)
	for message in _pause.take_messages():
		if _connection.transport.send_packet(Wire.encode(message)) != OK:
			return _fail("pause_send_failed")
	changed.emit()
	return running()


func _process(_delta: float) -> void:
	if running():
		if _completion.active():
			_completion.poll(Time.get_ticks_msec())
			if not _completion.error.is_empty():
				_fail(_completion.error)
		else:
			_pause.poll(Time.get_ticks_msec())
			if not _pause.error.is_empty():
				_fail(_pause.error)
	if running():
		_continuation.poll(Time.get_ticks_msec())
		if not _continuation.error.is_empty():
			_fail(_continuation.error)
	if running() and not _level_load.poll(Time.get_ticks_msec()):
		_fail(_level_load.error)
	if running():
		for story in _story_pages.values():
			if not story.poll(Time.get_ticks_msec()):
				_fail(story.error)
				return
		for early in _story_early.values():
			if Time.get_ticks_msec() >= early.time + StoryPages.RENDER_TIMEOUT_MS:
				_fail("story_timeout")
				return


## Explicit independent preparation. The presentation owner supplies its own
## entry-frame hash; no peer-provided pixels or script objects are accepted.
func prepare_story(sequence: int, background: String) -> bool:
	if not Config.hex_string(background, 64) or _load_sequence != 0 or not _verify_continuation_state():
		return false
	var candidate := committed_continuation(sequence)
	if candidate.is_empty() or candidate.get("kind") not in ["level", "shop"]:
		return false
	if _story_descriptors.has(sequence):
		var saved: Dictionary = _story_descriptors[sequence]
		return (
			true
			if saved.source == candidate.digest and saved.background == background
			else _fail("changed_story_descriptor")
		)
	if not _story_order_ready(sequence):
		return false
	var descriptor := StoryScript.prepare(candidate.script, candidate.digest, _story_context, background)
	return _prepare_story_descriptor(sequence, descriptor)


## Original ending score/hint only; completion does not apply ending effects.
func prepare_episode_score(sequence: int, background: String) -> bool:
	if not Config.hex_string(background, 64) or _load_sequence != 0 or not _verify_continuation_state():
		return false
	var candidate := committed_continuation(sequence)
	var script := _episode_score_script(sequence)
	if script.is_empty():
		return false
	if _story_descriptors.has(sequence):
		var saved: Dictionary = _story_descriptors[sequence]
		return (
			true
			if saved.source == candidate.digest and saved.background == background and saved.script == script
			else _fail("changed_story_descriptor")
		)
	if not _story_order_ready(sequence):
		return false
	var descriptor := StoryScript.prepare(script, candidate.digest, _story_context, background)
	return _prepare_story_descriptor(sequence, descriptor)


func _episode_score_script(sequence: int) -> Dictionary:
	var candidate := committed_continuation(sequence)
	if candidate.get("kind") != "episode_end":
		return {}
	var initial: Dictionary = _connection.startup.configuration()
	return EpisodeScore.build(
		configuration(),
		_level_result.record(),
		candidate,
		{"initial_episode": initial.get("episode"), "repeated": false},
		_gameplay_context().session
	)


func _prepare_story_descriptor(sequence: int, descriptor: Dictionary) -> bool:
	if descriptor.is_empty() or descriptor.pages.is_empty():
		return false
	var context := _gameplay_context()
	var pages := StoryPages.new()
	if not pages.configure(context.session, _pause.epoch, context.player, ticks_executed(), sequence, descriptor):
		return _fail(pages.error)
	_story_pages[sequence] = pages
	_story_descriptors[sequence] = descriptor
	if _story_early.has(sequence):
		var early: Dictionary = _story_early[sequence]
		_story_early.erase(sequence)
		if not pages.receive(early.message, early.time):
			return _fail(pages.error)
	return _settle_story(sequence)


func story_for_view(sequence: int) -> Dictionary:
	return _story_descriptors.get(sequence, {}).duplicate(true) if running() else {}


func story_committed_page(sequence: int) -> int:
	return _story_pages[sequence].committed_page() if running() and _story_pages.has(sequence) else 0


func story_complete(sequence: int) -> bool:
	return running() and _story_pages.has(sequence) and _story_pages[sequence].complete()


func story_receipt(sequence: int) -> Dictionary:
	return _story_receipts.get(sequence, {}).duplicate(true) if story_complete(sequence) else {}


func story_context() -> Dictionary:
	return _story_context.duplicate() if running() else {}


func mark_story_ready(sequence: int, page: int, digest: String) -> bool:
	if not _story_pages.has(sequence) or not _verify_continuation_state():
		return false
	var pages: RefCounted = _story_pages[sequence]
	return _settle_story(sequence) if pages.ready(page, digest, Time.get_ticks_msec()) else _fail(pages.error)


func request_story_advance(sequence: int, page: int, digest: String) -> bool:
	if player_for_view() != 1 or not _story_pages.has(sequence) or not _verify_continuation_state():
		return false
	var pages: RefCounted = _story_pages[sequence]
	if not pages.request_advance(page, digest, Time.get_ticks_msec()):
		return false if pages.error.is_empty() else _fail(pages.error)
	return _settle_story(sequence)


func mark_story_finished(sequence: int, context: Dictionary) -> bool:
	if not _story_pages.has(sequence) or not _verify_continuation_state():
		return false
	var descriptor: Dictionary = _story_descriptors[sequence]
	if context != StoryScript.final_context(descriptor.script, descriptor.context):
		return _fail("invalid_rendered_story_context")
	var pages: RefCounted = _story_pages[sequence]
	return _settle_story(sequence) if pages.finish(context, Time.get_ticks_msec()) else _fail(pages.error)


func _settle_story(sequence: int) -> bool:
	var pages: RefCounted = _story_pages[sequence]
	if not pages.poll(Time.get_ticks_msec()):
		return _fail(pages.error)
	for message in pages.take_messages():
		if _connection.transport.send_packet(Wire.encode(message)) != OK:
			return _fail("story_send_failed")
	if pages.complete() and not _story_receipts.has(sequence):
		_story_context = pages.final_context()
		var descriptor: Dictionary = _story_descriptors[sequence]
		var receipt := StoryScript.receipt(descriptor, _story_context)
		if receipt.is_empty():
			return _fail("invalid_story_receipt")
		_story_receipts[sequence] = receipt
	changed.emit()
	return running()


func _story_pending() -> bool:
	if not _story_early.is_empty():
		return true
	for pages in _story_pages.values():
		if not pages.complete():
			return true
	return false


func _story_order_ready(sequence: int) -> bool:
	if sequence == 1:
		return not _story_pages.has(2) and not _story_early.has(2)
	var first := committed_continuation(1)
	if first.is_empty():
		return false
	var screens: Array = first.get("script", {}).get("screens", [])
	return screens.is_empty() or story_complete(1)


func _clear_stories(reset_context: bool) -> void:
	_story_pages.clear()
	_story_descriptors.clear()
	_story_early.clear()
	_story_receipts.clear()
	if reset_context:
		_story_context = {"warning_red": false, "use_last_bank": false}


## Explicit backend-only load offer. Does not replace the runner or its owner.
func prepare_next_level(sequence: int, seed: String) -> bool:
	if player_for_view() != 1 or not _load_context(sequence):
		return false
	if not _level_load.offer(seed, Time.get_ticks_msec()):
		return _fail(_level_load.error) if not _level_load.error.is_empty() else false
	if not _settle_load() or not _prepare_pending_load():
		return false
	return _settle_load()


func next_level_loaded() -> bool:
	return running() and _level_load.ready()


func next_level_load_committed() -> bool:
	return running() and _level_load.committed()


func next_level_request() -> Dictionary:
	return _pending_preparation.continuation_request() if running() and _pending_preparation != null else {}


## Activation permission only. Scene detachment and runner adoption are separate.
func commit_next_level_load() -> bool:
	if player_for_view() != 1 or not _verify_continuation_state() or _pending_preparation == null:
		return false
	if not _pending_preparation.verify_preview():
		return _fail(_pending_preparation.error)
	if not _level_load.activate(Time.get_ticks_msec()):
		return _fail(_level_load.error) if not _level_load.error.is_empty() else false
	return _settle_load()


func _load_context(sequence: int) -> bool:
	if _story_pending():
		return false
	if not _verify_continuation_state():
		return false
	var candidate := committed_continuation(sequence)
	if candidate.is_empty() or candidate.get("kind") != "level":
		return false
	if _load_sequence != 0:
		return true if _load_sequence == sequence else _fail("changed_load_decision")
	var context: Dictionary = _gameplay_context()
	if not _level_load.configure(
		context.session, _pause.epoch, context.player, ticks_executed(), sequence, candidate.digest
	):
		return _fail(_level_load.error)
	_load_sequence = sequence
	return true


func _prepare_pending_load() -> bool:
	if _pending_preparation != null:
		return true if _pending_preparation.verify_preview() else _fail(_pending_preparation.error)
	var receipts := {}
	if _story_receipts.has(_load_sequence):
		receipts["script"] = _story_receipts[_load_sequence].duplicate(true)
	if _load_sequence == 2 and _story_receipts.has(1):
		receipts["entry"] = _story_receipts[1].duplicate(true)
	_pending_preparation = _preparation.fork_continuation(
		committed_continuation(_load_sequence), _level_load.seed, receipts
	)
	if _pending_preparation == null:
		return _fail("next_level_preparation_failed")
	if not _verify_continuation_state():
		return false
	return (
		_level_load.loaded(
			_pending_preparation.continuation_request().digest,
			_pending_preparation.preview_digest(),
			Time.get_ticks_msec()
		)
		or _fail(_level_load.error)
	)


func _settle_load() -> bool:
	if not _level_load.poll(Time.get_ticks_msec()):
		return _fail(_level_load.error)
	for message in _level_load.take_messages():
		if _connection.transport.send_packet(Wire.encode(message)) != OK:
			return _fail("load_send_failed")
	changed.emit()
	return running()


func _clear_pending_load() -> void:
	_pending_view_ready = false
	if _pending_preparation != null:
		_pending_preparation.clear()
	_pending_preparation = null
	_level_load = LevelLoad.new()
	_load_sequence = 0


## Explicit read-only post-fade proposals; never called by the prototype's live
## lobby exit. Native loading/adoption remains a separate approved operation.
func prepare_continuation(sequence := 1) -> bool:
	if not _verify_continuation_state() or sequence not in [1, 2] or not _continuation_context():
		return false
	if _campaign_cursor == null:
		_campaign_cursor = CampaignCursor.new(_preparation.get("_data_dir"))
		if not _campaign_cursor.begin(configuration()):
			return _fail(_campaign_cursor.error)
	var candidate: Dictionary
	if sequence == 1:
		candidate = _campaign_cursor.completed(_level_result.record())
	else:
		var parent: String = _continuation.committed_digest(1)
		if parent.is_empty():
			return false
		candidate = _campaign_cursor.preview_arcade_start(parent)
	if candidate.is_empty():
		return _fail(_campaign_cursor.error)
	if not _valid_continuation_candidate(candidate, sequence):
		return _fail("invalid_continuation_candidate")
	if not _verify_continuation_state():
		return false
	if not _continuation.prepare(sequence, candidate.digest, Time.get_ticks_msec()):
		return _fail(_continuation.error)
	_continuation_candidates[sequence] = candidate.duplicate(true)
	return _settle_continuation()


func propose_continuation(sequence := 1) -> bool:
	if sequence == 2 and _story_pending():
		return false
	if player_for_view() != 1 or not prepare_continuation(sequence):
		return false
	if not _continuation.propose(sequence, Time.get_ticks_msec()):
		return _fail(_continuation.error)
	return _settle_continuation()


func continuation_sequence() -> int:
	return _continuation.committed_sequence() if running() else 0


## Detached ledger only. The session has no live episode-finalization owner yet.
func episode_end_plan(sequence := 1) -> Dictionary:
	if _load_sequence != 0 or _story_pending() or not _verify_continuation_state():
		return {}
	var candidate := committed_continuation(sequence)
	if candidate.get("kind") != "episode_end":
		return {}
	# Current sessions cannot cross an ending, so history starts unrepeated.
	# Replace this with adopted history before implementing episode transitions.
	var initial: Dictionary = _connection.startup.configuration()
	return EpisodeEnd.build(
		configuration(),
		_level_result.record(),
		candidate,
		{"initial_episode": initial.get("episode"), "repeated": false}
	)


## Cosmetic choices from already agreed inputs, not presentation completion.
func episode_hint_for_view(sequence := 1) -> Dictionary:
	var ending := episode_end_plan(sequence)
	if ending.is_empty():
		return {}
	return EpisodeHint.build(
		configuration(),
		_level_result.record(),
		committed_continuation(sequence),
		ending.history,
		_gameplay_context().session
	)


func _valid_continuation_candidate(candidate: Dictionary, sequence: int) -> bool:
	var record := _level_result.record()
	if candidate.get("sequence") != sequence or candidate.get("source_result") != record.digest:
		return false
	if candidate.get("source_configuration") != record.config:
		return false
	if not candidate.get("requires_loader_adaptation") is bool or not candidate.requires_loader_adaptation:
		return false
	if not candidate.get("difficulty_rule_review_required") is bool:
		return false
	if (
		sequence == 2
		and (candidate.get("parent") != _continuation.committed_digest(1) or candidate.get("action") != "arcade_start")
	):
		return false
	return (
		Config.hex_string(candidate.get("digest"), 64) and CampaignCursor.proposal_digest(candidate) == candidate.digest
	)


func committed_continuation(sequence := 1) -> Dictionary:
	if not running() or not _continuation_candidates.has(sequence):
		return {}
	var candidate: Dictionary = _continuation_candidates[sequence]
	return candidate.duplicate(true) if _continuation.committed_digest(sequence) == candidate.digest else {}


func _verify_continuation_state() -> bool:
	if not completion_agreed() or result_committed_phase() != 3:
		return false
	if not _preparation.verify_current():
		return _fail(_preparation.error)
	if _level_result.record().digest != _completion.result_digest():
		return _fail("changed_continuation_result")
	if diagnostic_digest() != _level_result.record().core:
		return _fail("changed_continuation_state")
	return true


func _continuation_context() -> bool:
	if _continuation.epoch == _pause.epoch:
		return true
	if _continuation.epoch != 0:
		return _fail("changed_continuation_epoch")
	var context: Dictionary = _gameplay_context()
	if not _continuation.configure(context.session, _pause.epoch, context.player, ticks_executed()):
		return _fail(_continuation.error)
	return true


func _settle_continuation() -> bool:
	_continuation.poll(Time.get_ticks_msec())
	if not _continuation.error.is_empty():
		return _fail(_continuation.error)
	for message in _continuation.take_messages():
		if _connection.transport.send_packet(Wire.encode(message)) != OK:
			return _fail("continuation_send_failed")
	changed.emit()
	return running()


## Explicit final post-presentation boundary. Never steps/reloads the native node.
func note_level_result(presented_tick: int, level_name: String, elapsed_seconds: int) -> bool:
	if not views_ready() or not _completion_context():
		return false
	var native := simulation_for_view()
	if not _level_result.capture(native, configuration(), level_name, presented_tick, not _active_request.is_empty()):
		return _fail(_level_result.error)
	var record := _level_result.record()
	if not _completion.reached(record.tick, record.digest, elapsed_seconds, Time.get_ticks_msec()):
		return _fail(_completion.error)
	return _settle_completion()


func completion_agreed() -> bool:
	return running() and _completion.agreed()


func result_for_view() -> RefCounted:
	return _level_result if completion_agreed() else null


func result_elapsed_seconds() -> int:
	return _completion.elapsed_seconds() if completion_agreed() else -1


func mark_result_screen_ready(stage: int) -> bool:
	if not completion_agreed():
		return false
	if not _completion.screen_ready(stage):
		return _fail(_completion.error) if not _completion.error.is_empty() else false
	return _settle_completion()


func request_result_advance(stage: int) -> bool:
	return completion_agreed() and _completion.request_advance(stage, Time.get_ticks_msec()) and _settle_completion()


func result_committed_phase() -> int:
	return _completion.committed_phase() if running() else 0


func _completion_context() -> bool:
	if _completion.epoch == _pause.epoch:
		return true
	if _completion.active():
		return _fail("changed_completion_epoch")
	_completion = Completion.new()
	var context: Dictionary = _gameplay_context()
	if not _completion.configure(context.session, _pause.epoch, context.player, configuration().input_delay):
		return _fail(_completion.error)
	return true


func _settle_completion() -> bool:
	if not _completion.error.is_empty():
		return _fail(_completion.error)
	for message in _completion.take_messages():
		if _connection.transport.send_packet(Wire.encode(message)) != OK:
			return _fail("completion_send_failed")
	changed.emit()
	return running()


func _receive_view_ready(packet: PackedByteArray) -> void:
	var context: Dictionary = _gameplay_context()
	var message := Wire.decode(packet, packet.slice(8, 24).hex_encode(), packet.decode_u32(24), 3 - context.player)
	if message.is_empty():
		_fail("invalid_view_ready")
		return
	if message.session != context.session or message.epoch != context.epoch:
		return
	if (
		message.tick != 0
		or message.sequence != 1
		or message.digest != _configuration_digest()
		or (not _view_remote and ticks_executed() != 0)
	):
		_fail("invalid_view_ready")
		return
	_view_remote = true
	changed.emit()


## Diagnostic valid only at the same untouched observer-consumption boundary.
func diagnostic_digest() -> String:
	if not running():
		return ""
	return _preparation.get("_preview").network_diagnostic_digest()


func _changed() -> void:
	if _stopping:
		return
	if not _connection.error.is_empty():
		_fail(_connection.error)
		return
	if not _preparation.error.is_empty():
		_fail(_preparation.error)
		return
	if _connection.running and not _activated:
		if not _preparation.verify_preview():
			_fail(_preparation.error)
			return
		var context: Dictionary = _gameplay_context()
		if not _runner.activate(
			_preparation.get("_preview"), _preparation.configuration(), context.session, context.epoch, context.player
		):
			_fail(_runner.error)
			return
		_activated = true
		_pause = PauseController.new()
		if not _pause.configure(context.session, context.epoch, context.player, configuration().input_delay):
			_fail(_pause.error)
			return
	changed.emit()


func _receive_input(packet: PackedByteArray) -> void:
	if not running():
		_fail("input_before_start")
		return
	if packet.size() >= Wire.HEADER_BYTES:
		var context := _gameplay_context()
		if packet.decode_u32(24) < context.epoch:
			var old := Wire.decode(packet, packet.slice(8, 24).hex_encode(), packet.decode_u32(24), 3 - context.player)
			if old.is_empty():
				_fail("invalid_stale_packet")
			return
		if (
			int(packet[6]) == Wire.Kind.READY
			and _level_load.committed()
			and packet.decode_u32(24) == _level_load.next_epoch
		):
			_stage_next_view_ready(packet)
			return
	if (
		packet.size() >= Wire.HEADER_BYTES
		and int(packet[6]) in [Wire.Kind.STORY_READY, Wire.Kind.STORY_ADVANCE, Wire.Kind.STORY_DONE]
	):
		_receive_story(packet)
		return
	if (
		packet.size() >= Wire.HEADER_BYTES
		and int(packet[6]) in [Wire.Kind.LOAD_SEED, Wire.Kind.LOAD_READY, Wire.Kind.LOAD_ACTIVATE]
	):
		_receive_load(packet)
		return
	if (
		packet.size() >= Wire.HEADER_BYTES
		and int(packet[6]) in [Wire.Kind.CONTINUATION, Wire.Kind.CONTINUATION_ACK, Wire.Kind.CONTINUATION_COMMIT]
	):
		_receive_continuation(packet)
		return
	if (
		packet.size() >= Wire.HEADER_BYTES
		and int(packet[6]) in [Wire.Kind.LEVEL_RESULT, Wire.Kind.LEVEL_READY, Wire.Kind.LEVEL_ADVANCE]
	):
		_receive_completion(packet)
		return
	if packet.size() >= Wire.HEADER_BYTES and int(packet[6]) == Wire.Kind.READY:
		var initial_epoch: int = _gameplay_context().epoch
		if packet.decode_u32(24) == initial_epoch and packet.decode_u32(28) == 0:
			_receive_view_ready(packet)
		else:
			_receive_pause(packet)
		return
	if packet.size() >= Wire.HEADER_BYTES and int(packet[6]) in [Wire.Kind.PAUSE, Wire.Kind.STATE]:
		_receive_pause(packet)
		return
	var result: int = _runner.receive(packet)
	if not _runner.error.is_empty():
		_fail(_runner.error)
	elif result == Buffer.Result.INVALID:
		_fail("invalid_remote_input")


func _receive_pause(packet: PackedByteArray) -> void:
	if not views_ready():
		_fail("pause_before_views")
		return
	var message := Wire.decode(packet, packet.slice(8, 24).hex_encode(), packet.decode_u32(24), 3 - player_for_view())
	if not message.is_empty() and _completion.local_reached():
		return  # Natural completion supersedes an in-flight future pause target.
	if not _pause.receive(message, ticks_executed(), Time.get_ticks_msec()):
		_fail(_pause.error)
		return
	_settle_pause()


func _receive_completion(packet: PackedByteArray) -> void:
	if not views_ready():
		_fail("completion_before_views")
		return
	var context: Dictionary = _gameplay_context()
	var message := Wire.decode(packet, packet.slice(8, 24).hex_encode(), packet.decode_u32(24), 3 - context.player)
	if message.is_empty():
		_fail("invalid_completion_message")
		return
	if message.session != context.session or message.epoch < _pause.epoch:
		return
	if message.epoch != _pause.epoch:
		_fail("future_completion_epoch")
		return
	if not _completion_context() or not _completion.receive(message, ticks_executed(), Time.get_ticks_msec()):
		if not _completion.error.is_empty():
			_fail(_completion.error)
		return
	_settle_completion()


func _receive_continuation(packet: PackedByteArray) -> void:
	var context: Dictionary = _gameplay_context()
	var message := Wire.decode(packet, packet.slice(8, 24).hex_encode(), packet.decode_u32(24), 3 - context.player)
	if message.is_empty():
		_fail("invalid_continuation_message")
		return
	if message.session != context.session or message.epoch < _pause.epoch:
		return
	if message.epoch != _pause.epoch:
		_fail("future_continuation_epoch")
		return
	if message.sequence == 2 and _story_pending():
		_fail("continuation_before_story")
		return
	if _continuation.has_seen_control(message):
		if not _continuation.receive(message, Time.get_ticks_msec()):
			_fail(_continuation.error)
		else:
			_settle_continuation()
		return
	if not _verify_continuation_state():
		if running():
			_fail("continuation_before_completion")
		return
	if not _continuation_context() or not _continuation.receive(message, Time.get_ticks_msec()):
		if not _continuation.error.is_empty():
			_fail(_continuation.error)
		return
	if message.kind == Wire.Kind.CONTINUATION and not _continuation.has_candidate(message.sequence):
		if not prepare_continuation(message.sequence):
			if running():
				_fail("continuation_derivation_failed")
			return
	_settle_continuation()


func _receive_load(packet: PackedByteArray) -> void:
	var context: Dictionary = _gameplay_context()
	var message := Wire.decode(packet, packet.slice(8, 24).hex_encode(), packet.decode_u32(24), 3 - context.player)
	if message.is_empty():
		_fail("invalid_load_message")
		return
	if message.session != context.session or message.epoch < _pause.epoch:
		return
	if message.epoch != _pause.epoch:
		_fail("future_load_epoch")
		return
	if _level_load.has_seen_control(message):
		if not _level_load.receive(message, Time.get_ticks_msec()):
			_fail(_level_load.error)
		return
	if not _load_context(message.sequence):
		if running():
			_fail("load_before_committed_continuation")
		return
	if _pending_preparation != null and not _pending_preparation.verify_preview():
		_fail(_pending_preparation.error)
		return
	if not _level_load.receive(message, Time.get_ticks_msec()):
		_fail(_level_load.error)
		return
	if message.kind == Wire.Kind.LOAD_SEED and not _prepare_pending_load():
		return
	_settle_load()


func _stage_next_view_ready(packet: PackedByteArray) -> void:
	var context := _gameplay_context()
	var message := Wire.decode(packet, context.session, _level_load.next_epoch, 3 - context.player)
	if message.is_empty() or _pending_preparation == null:
		_fail("invalid_next_view_ready")
		return
	if (
		message.tick != 0
		or message.sequence != 1
		or message.digest != Next.configuration_digest(_pending_preparation.configuration())
	):
		_fail("invalid_next_view_ready")
		return
	_pending_view_ready = true


func _receive_story(packet: PackedByteArray) -> void:
	var context := _gameplay_context()
	var message := Wire.decode(packet, packet.slice(8, 24).hex_encode(), packet.decode_u32(24), 3 - context.player)
	if message.is_empty():
		_fail("invalid_story_message")
		return
	if message.session != context.session or message.epoch < _pause.epoch:
		return
	if message.epoch != _pause.epoch:
		_fail("future_story_epoch")
		return
	var sequence: int = message.sequence >> 16
	if _story_pages.has(sequence):
		var pages: RefCounted = _story_pages[sequence]
		if not pages.has_seen_control(message) and not _verify_continuation_state():
			return
		if not pages.receive(message, Time.get_ticks_msec()):
			_fail(pages.error)
			return
		_settle_story(sequence)
		return
	if _story_early.has(sequence):
		if _story_early[sequence].message != message:
			_fail("conflicting_early_story")
		return
	if not _verify_continuation_state():
		if running():
			_fail("story_before_completion")
		return
	var candidate := committed_continuation(sequence)
	var display_script: Dictionary = candidate.get("script", {})
	if candidate.get("kind") == "episode_end":
		display_script = _episode_score_script(sequence)
	if (
		candidate.is_empty()
		or candidate.get("kind") not in ["level", "shop", "episode_end"]
		or not StoryScript.valid_script(display_script)
		or display_script.screens.is_empty()
		or message.kind != Wire.Kind.STORY_READY
		or message.sequence & 0xffff != 1
		or message.tick != ticks_executed()
		or _load_sequence != 0
	):
		_fail("story_before_preparation")
		return
	if not _story_order_ready(sequence):
		_fail("story_before_previous_completion")
		return
	_story_early[sequence] = {"message": message.duplicate(true), "time": Time.get_ticks_msec()}


func _fail(reason: String) -> bool:
	_clear_stories(true)
	_active_context.clear()
	_active_request.clear()
	_view_borrows.clear()
	_awaiting_new_views = false
	_clear_pending_load()
	_continuation = Continuation.new()
	_campaign_cursor = null
	_continuation_candidates.clear()
	_completion = Completion.new()
	_level_result = LevelResult.new()
	_pause = PauseController.new()
	_view_local = false
	_view_remote = false
	_runner.stop()
	_activated = false
	return super._fail(reason)
