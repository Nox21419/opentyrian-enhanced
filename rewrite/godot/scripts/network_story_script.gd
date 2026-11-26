## Pure bounded story description; no rendering, transport or campaign effects.
extends RefCounted

const Config := preload("res://scripts/network_configuration.gd")
const Result := preload("res://scripts/network_level_result.gd")
const MAX_PAGES := 128


static func valid_script(script: Dictionary) -> bool:
	if script.get("stop") not in ["level", "shop"] or script.has("mini_game") or script.get("autosave", false) != false:
		return false
	var pages: Variant = script.get("screens")
	if not pages is Array or pages.size() > MAX_PAGES:
		return false
	for page in pages:
		if not page is Dictionary or page.size() != 2 or not page.get("directive") is String:
			return false
		var directive: String = page.directive
		if directive.length() < 2 or directive.length() > 128 or directive[1] not in "M@PUVRCBFAW":
			return false
		if not page.get("text") is PackedStringArray or page.text.size() > 128:
			return false
		for line in page.text:
			if line.to_utf8_buffer().size() > 2048:
				return false
	return not Result.canonical_bytes(script).is_empty()


static func valid_context(context: Dictionary) -> bool:
	return context.size() == 2 and context.get("warning_red") is bool and context.get("use_last_bank") is bool


static func prepare(script: Dictionary, source: String, context: Dictionary, background: String) -> Dictionary:
	if not valid_script(script) or not Config.hex_string(source, 64):
		return {}
	for key in context:
		if key not in ["warning_red", "use_last_bank"] or not context[key] is bool:
			return {}
	if background.is_empty():
		background = Config.sha256("unspecified-standalone-story-background")
	if not Config.hex_string(background, 64):
		return {}
	var descriptor := {
		"source": source,
		"script": script.duplicate(true),
		"context": {"warning_red": context.get("warning_red", false), "use_last_bank": false},
		"background": background
	}
	descriptor["digest"] = digest(descriptor)
	if descriptor.digest.is_empty():
		return {}
	var pages := []
	for index in script.screens.size():
		pages.append(digest({"descriptor": descriptor.digest, "page": index + 1}))
	descriptor["pages"] = pages
	return descriptor


static func valid(descriptor: Dictionary) -> bool:
	if (
		descriptor.size() != 6
		or not descriptor.get("script") is Dictionary
		or not descriptor.get("context") is Dictionary
	):
		return false
	if not descriptor.get("source") is String or not descriptor.get("background") is String:
		return false
	return descriptor == prepare(descriptor.script, descriptor.source, descriptor.context, descriptor.background)


static func page_digest(descriptor: Dictionary, page: int) -> String:
	var pages: Array = descriptor.get("pages", [])
	return pages[page - 1] if page >= 1 and page <= pages.size() else ""


static func digest(value: Dictionary) -> String:
	var bytes := Result.canonical_bytes(value)
	if bytes.is_empty():
		return ""
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(bytes)
	return hash.finish().hex_encode()
