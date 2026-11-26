## Detached original story presentation. Caller owns agreement/transport/effects.
extends "res://scripts/story_screens.gd"

const StoryData := preload("res://scripts/network_story_script.gd")
const Config := preload("res://scripts/network_configuration.gd")
const MAX_PAGES := 128
signal page_ready(page: int, digest: String)
signal advance_requested(page: int, digest: String)
signal finished(source: String)
var error := ""
var _script := {}
var _descriptor := {}
var _source := ""
var _role := 0
var _page := 0
var _digest := ""
var _committed := {}
var _page_ready := false
var _requested := false
var _active := false
var _local_red := false
var _local_bank := false


## The caller must have independently derived/agreed this script, not decoded it
## from an untrusted peer. This binding itself grants no network authorization.
func bind_script(script: Dictionary, source: String, role: int, context := {}, background := "") -> bool:
	if is_inside_tree() or not _script.is_empty() or not Config.hex_string(source, 64) or role not in [1, 2]:
		return false
	if not StoryData.valid_script(script):
		return false
	for key in context:
		if key not in ["warning_red", "use_last_bank"] or not context[key] is bool:
			return false
	_descriptor = StoryData.prepare(script, source, context, background)
	if _descriptor.is_empty():
		return false
	_script = script.duplicate(true)
	_source = source
	_role = role
	_local_red = context.get("warning_red", false)
	return true


func context_state() -> Dictionary:
	return {"warning_red": _local_red, "use_last_bank": _local_bank}


func presentation_descriptor() -> Dictionary:
	return _descriptor.duplicate(true)


func page_digest(page: int) -> String:
	return StoryData.page_digest(_descriptor, page)


func commit_page(page: int, digest: String) -> bool:
	if not error.is_empty() or digest.is_empty() or digest != page_digest(page):
		return _fail("invalid_story_commit")
	if _committed.has(page):
		return true
	if not _active or not _page_ready or page != _page:
		return _fail("premature_story_commit")
	_committed[page] = digest
	return true


func _run() -> void:
	if _script.is_empty():
		return
	_active = true
	_local_bank = false  # Original JE_loadMap entry resets useLastBank.
	for index in _script.screens.size():
		_page = index + 1
		_digest = page_digest(_page)
		_page_ready = false
		_requested = false
		_reset_story_input()
		var screen: Dictionary = _script.screens[index]
		await _screen(screen.directive, screen.text)
		if not _live():
			return
		if not _committed.has(_page):
			await _wait_page(true)
		if not _live():
			return
	_active = false
	finished.emit(_source)


func _wait_text_completion(finish_on_skip: bool) -> void:
	await _wait_page(finish_on_skip and _frame_count_max == 0)


func _wait_page(automatic: bool) -> void:
	if not _live():
		return
	_page_ready = true
	page_ready.emit(_page, _digest)
	while _live() and not _committed.has(_page):
		if _role == 1 and not _requested and (automatic or _any_button()):
			_requested = true
			advance_requested.emit(_page, _digest)
		if _warning_display:
			_update_warning()
		await get_tree().process_frame


func _story_red() -> bool:
	return _local_red


func _story_alive() -> bool:
	return _live()


func fade_palette_over_pointer(steps: int, first := 0, last := 255, surf := VGA_SCREEN) -> void:
	if not _live():
		return
	vga.fade_palette_init(first, last)
	for step in range(steps, 0, -1):
		if not _live():
			return
		vga.fade_step(step, first, last)
		present(surf)
		await wait_units(1)


func fade_solid(color: Color, steps: int, first := 0, last := 255, surf := VGA_SCREEN) -> void:
	if not _live():
		return
	push_pointer_hidden()
	vga.fade_solid_init(color, first, last)
	for step in range(steps, 0, -1):
		if not _live():
			break
		vga.fade_step(step, first, last)
		present(surf)
		await wait_units(1)
	pop_pointer_hidden()


func _set_story_red(value: bool) -> void:
	_local_red = value


func _story_bank() -> bool:
	return _local_bank


func _set_story_bank(value: bool) -> void:
	_local_bank = value


func _story_prompt() -> String:
	return TyrianText.L("net_wait_host" if _role == 2 else "misc_press_key")


func _input(event: InputEvent) -> void:
	if _role == 1 and _active:
		super._input(event)


func _unhandled_input(_event: InputEvent) -> void:
	pass  # Local campaign/name-entry handlers never own this view.


func _any_button() -> bool:
	return super._any_button() if _role == 1 else false


func present(surf := VGA_SCREEN) -> void:
	if _live():
		super.present(surf)


func _live() -> bool:
	return _active and error.is_empty() and is_inside_tree()


func _notification(what: int) -> void:
	if what == NOTIFICATION_EXIT_TREE:
		_active = false
		_reset_story_input()


func _fail(reason: String) -> bool:
	error = reason
	_active = false
	return false
