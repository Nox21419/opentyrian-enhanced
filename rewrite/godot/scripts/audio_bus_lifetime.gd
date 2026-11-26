## Release owned bus effects before GDExtension class teardown.
extends RefCounted


static func release(effects: Array) -> void:
	# Match resources rather than bus names/indices: buses can move or be renamed.
	# AudioServer synchronizes instance destruction with its mixing thread.
	for bus in AudioServer.bus_count:
		for index in range(AudioServer.get_bus_effect_count(bus) - 1, -1, -1):
			if effects.has(AudioServer.get_bus_effect(bus, index)):
				AudioServer.remove_bus_effect(bus, index)
	effects.clear()
