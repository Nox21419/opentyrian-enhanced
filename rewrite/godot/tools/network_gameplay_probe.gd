## Explicit development probe: two independent processes, no player-scene wiring.
## -- --probe-role=host|guest --probe-report=<absolute.json> [--probe-port=27738]
## [--probe-data=<original-data-directory>] [--probe-warmup=2]
extends SceneTree

const Fixture := preload("res://test/fixtures/network_setup.gd")
const Wire := preload("res://scripts/network_protocol.gd")
const Config := preload("res://scripts/network_configuration.gd")
const LIMIT := 120
var _role := ""
var _report := ""
var _data := ""
var _port := 27738
var _warmup := 0
var _connection: Node
var _config := {}
var _hashes: Array[String] = []
var _proposed := false
var _compared := false
var _ready := false
var _started := false
var _finishing := false
var _deadline := 0
var _done_at := 0


class Driver:
	extends Node
	var drive: Callable

	func _physics_process(_delta: float) -> void:
		drive.call()


func _initialize() -> void:
	_data = ProjectSettings.globalize_path("res://").path_join("../../data").simplify_path()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--probe-role="):
			_role = arg.trim_prefix("--probe-role=")
		elif arg.begins_with("--probe-report="):
			_report = arg.trim_prefix("--probe-report=")
		elif arg.begins_with("--probe-data="):
			_data = arg.trim_prefix("--probe-data=")
		elif arg.begins_with("--probe-port="):
			_port = arg.trim_prefix("--probe-port=").to_int()
		elif arg.begins_with("--probe-warmup="):
			_warmup = arg.trim_prefix("--probe-warmup=").to_int()
	_start.call_deferred()


func _start() -> void:
	if _role not in ["host", "guest"] or _report.is_empty() or _warmup < 0 or _warmup > 4:
		_finish("invalid_probe_arguments")
		return
	if Engine.physics_ticks_per_second != 35:
		_finish("probe_requires_normal_35hz")
		return
	for index in _warmup:
		var local: Node = ClassDB.instantiate("TyrianSim")
		local.set_loadout(PackedInt32Array([11, 1, 1, 0, 1, 4, 2, 0, 0, 0, 0]))
		if not local.load_level(_data, 1, 9, 3, index + 17):
			local.free()
			_finish("warmup_failed")
			return
		for _tick in 20:
			local.step(16, 0)
		local.free()
	_config = Fixture.configuration()
	# Frontend dependencies require the autoload globals to be registered first.
	_connection = load("res://scripts/network_gameplay_connection.gd").new()
	root.add_child(_connection)
	var result: int
	if _role == "host":
		result = _connection.host(_data, PackedStringArray(), {}, 1, _port)
	else:
		result = _connection.join("127.0.0.1", _data, PackedStringArray(), {}, 1, _port)
	if result != OK:
		_finish("connection_failed")
		return
	print("PROBE_BOUND ", _role)
	_deadline = Time.get_ticks_msec() + 60000
	var driver := Driver.new()
	driver.drive = _drive
	root.add_child(driver)


func _drive() -> void:
	if _finishing:
		return
	if not _connection.error.is_empty():
		_finish("" if _hashes.size() == LIMIT else _connection.error)
		return
	if Time.get_ticks_msec() > _deadline:
		_finish("probe_timeout")
		return
	if _role == "host" and not _proposed and _connection.compatible():
		_proposed = true
		if not _connection.propose(_config, "71".repeat(16), 1):
			_finish("proposal_failed")
			return
	if not _compared and _connection.agreed():
		_compared = true
		if not _connection.compare_preview():
			_finish("preview_failed")
			return
	if not _ready and _connection.preview_matched():
		_ready = true
		if not _connection.confirm_ready():
			_finish("ready_failed")
			return
	if _role == "host" and _ready and not _started:
		var startup: RefCounted = _connection.get("_connection").startup
		if startup.get("_remote_ready"):
			_started = true
			if not _connection.start():
				_finish("start_failed")
				return
	if not _connection.running():
		return
	if _hashes.size() < LIMIT:
		if _connection.needs_local_input():
			var tick: int = _connection.ticks_executed() + _config.input_delay
			var frame := Wire.neutral_frame()
			frame.mouse_mask = 16
			frame.mouse_dx = (tick * 7 + (1 if _role == "host" else 2)) % 61 - 30
			frame.mouse_dy = (tick * 11) % 61 - 30
			frame.new_key = tick % 43 == 0
			if not _connection.capture_local(frame):
				_finish("capture_failed")
				return
		if _connection.advance():
			_hashes.append(_connection.diagnostic_digest())
		if _hashes.size() == LIMIT:
			_done_at = Time.get_ticks_msec() + 1500
	elif Time.get_ticks_msec() >= _done_at:
		_finish("")


func _finish(reason: String) -> void:
	if _finishing:
		return
	_finishing = true
	var exit_code := 0 if reason.is_empty() else 1
	if not _report.is_empty():
		var file := FileAccess.open(_report, FileAccess.WRITE)
		if file == null:
			exit_code = 1
		else:
			file.store_string(
				JSON.stringify(
					{
						"role": _role,
						"ticks": _hashes.size(),
						"hashes": _hashes,
						"config": Config.digest(_config),
						"physics_hz": Engine.physics_ticks_per_second,
						"error": reason
					}
				)
			)
			file.close()
	if is_instance_valid(_connection):
		_connection.stop()
		_connection.queue_free()
	for name in ["Music", "Sfx"]:
		var audio := root.get_node_or_null(name)
		if audio != null:
			audio.release_streams()
	await process_frame
	await process_frame
	print("PROBE_FINISHED ", _role, " ", _hashes.size(), " ", reason)
	quit(exit_code)
