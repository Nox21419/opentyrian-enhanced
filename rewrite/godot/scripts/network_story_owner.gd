## Live presentation adapter. The session owns transport and scene transitions.
extends "res://scripts/network_story_view.gd"

signal completed
signal failed(reason: String)
var _connection: Node
var _decision := 0
var _expected_source := ""
var _entry_active := false
var _released := false
var _local_finished := false
var _reported := false


func bind(connection: Node, decision: int) -> bool:
	if is_inside_tree() or is_instance_valid(_connection) or decision not in [1, 2]:
		return false
	if not is_instance_valid(connection) or not connection.running():
		return false
	var proposal: Dictionary = connection.committed_continuation(decision)
	if not _accept_proposal(proposal):
		return false
	_connection = connection
	_decision = decision
	_expected_source = proposal.digest
	_role = connection.player_for_view()
	page_ready.connect(_ready_page)
	advance_requested.connect(_request_page)
	finished.connect(_finished_locally)
	_connection.changed.connect(_sync)
	return _role in [1, 2]


func _accept_proposal(proposal: Dictionary) -> bool:
	return (
		proposal.get("script") is Dictionary
		and StoryData.valid_script(proposal.script)
		and not proposal.script.screens.is_empty()
		and proposal.get("kind") in ["level", "shop"]
	)


func _prepare_presentation(background: String) -> bool:
	return _connection.prepare_story(_decision, background)


func _run() -> void:
	if _released or not is_instance_valid(_connection):
		return
	_entry_active = true
	await fade_black(10)
	if not _live():
		return
	# Both roles start from the same original surface, not different menu text.
	vga.clear(VGA_SCREEN, 0)
	vga.load_palette(0)
	vga.set_palette(0, 255)
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(vga.indices(VGA_SCREEN))
	hash.update(vga.image(VGA_SCREEN).get_data())
	var background := hash.finish().hex_encode()
	present()
	if not _prepare_presentation(background):
		_abort("story_preparation_failed")
		return
	var descriptor: Dictionary = _connection.story_for_view(_decision)
	if descriptor.get("source") != _expected_source or not _bind_descriptor(descriptor, _role):
		_abort("story_binding_failed")
		return
	_entry_active = false
	await super._run()
	_sync()


func _ready_page(page: int, digest: String) -> void:
	if not _connection.mark_story_ready(_decision, page, digest):
		_abort("story_ready_failed")
	else:
		_sync()


func _request_page(page: int, digest: String) -> void:
	if not _connection.request_story_advance(_decision, page, digest):
		_abort("story_advance_failed")
	else:
		_sync()


func _finished_locally(_source_digest: String) -> void:
	_local_finished = true
	if not _connection.mark_story_finished(_decision, context_state()):
		_abort("story_finish_failed")
	else:
		_sync()


func _sync() -> void:
	if _released or _reported or not is_instance_valid(_connection):
		return
	if not _connection.running():
		_abort("story_session_closed")
		return
	if _active and _page_ready and not _committed.has(_page) and _connection.story_committed_page(_decision) >= _page:
		if not commit_page(_page, _digest):
			_abort("story_commit_failed")
			return
	if _local_finished and _connection.story_complete(_decision):
		_reported = true
		completed.emit()


func _live() -> bool:
	return not _released and (_entry_active or _active) and error.is_empty() and is_inside_tree()


func _input(event: InputEvent) -> void:
	if not _released and _role == 2 and TyrianControls.menu_action(event) == TyrianControls.BACK:
		_abort("left_story")
	else:
		super._input(event)


func _abort(reason: String) -> void:
	if _released or _reported:
		return
	_reported = true
	_fail(reason)
	failed.emit(reason)


func release() -> void:
	_released = true
	_entry_active = false
	_active = false
	_reset_story_input()
	if is_instance_valid(_connection) and _connection.changed.is_connected(_sync):
		_connection.changed.disconnect(_sync)
	if page_ready.is_connected(_ready_page):
		page_ready.disconnect(_ready_page)
	if advance_requested.is_connected(_request_page):
		advance_requested.disconnect(_request_page)
	if finished.is_connected(_finished_locally):
		finished.disconnect(_finished_locally)
	_connection = null


func _notification(what: int) -> void:
	if what == NOTIFICATION_EXIT_TREE:
		release()
