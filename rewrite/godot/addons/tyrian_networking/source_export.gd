@tool
extends EditorExportPlugin

const Identity := preload("res://scripts/network_identity.gd")


func _get_name() -> String:
	return "TyrianNetworkIdentity"


func _export_begin(_features: PackedStringArray, _is_debug: bool, _path: String, _flags: int) -> void:
	var digest := Identity.source_digest()
	if digest.is_empty():
		push_error("Cannot fingerprint client sources for network compatibility")
		return
	# Generated inside this export, including manual editor exports. No stale
	# file on disk and no assumption that exported .gdc files retain source text.
	var stamp := JSON.stringify({"version": 1, "digest": digest}).to_utf8_buffer()
	add_file(Identity.STAMP, stamp, false)
