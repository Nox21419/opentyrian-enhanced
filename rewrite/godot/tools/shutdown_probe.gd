## Short independent-process lifetime probe. OS exit status is the verdict.
## -- --probe-audio-playing exercises active players as well as bus resources.
extends SceneTree


func _initialize() -> void:
	_probe.call_deferred()


func _probe() -> void:
	# Load after autoloads have registered their script globals.
	var screen: Node = load("res://scripts/tyrian_screen.gd").new()
	root.add_child(screen)
	await process_frame
	screen.free()
	if "--probe-audio-playing" in OS.get_cmdline_user_args():
		var music := root.get_node("Music")
		var sfx := root.get_node("Sfx")
		music.set_engine(music.ENGINE_CLASSIC)
		music.widen = true
		music.play_song(0)
		sfx.play_in_headless = true
		sfx.play(sfx.WEAPON_1)
		await physics_frame
		await physics_frame
	print("SHUTDOWN_PROBE_READY")
	# Do not manually remove effects here: actual autoload exit must own cleanup.
	if "--probe-audio-playing" in OS.get_cmdline_user_args():
		# Use the player's existing stream-drain path for active OGG/WAV playback.
		root.get_node("Game").quit_cleanly()
	else:
		quit()
