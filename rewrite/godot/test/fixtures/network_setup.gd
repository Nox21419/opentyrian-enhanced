extends RefCounted


static func identity() -> Dictionary:
	return {"native": "11".repeat(32), "client": "22".repeat(32), "content": "33".repeat(32), "engine": "44".repeat(32)}


static func configuration() -> Dictionary:
	return {
		"mode": "arcade",
		"episode": 1,
		"level_file": 9,
		"initial_difficulty": 2,
		"difficulty": 3,
		"seed": "ffffffffffffffff",
		"loadout1": [11, 1, 1, 0, 1, 4, 2, 0, 0, 0],
		"loadout2": [1, 1, 1, 15, 1, 4, 2, 0, 0, 0],
		"cash1": "0000000000000000",
		"cash2": "0000000000000000",
		"devices": [0, 0],
		"input_delay": 3,
		"mutators": 0,
		"processor_type": 4,
		"game_speed": 4,
		"explosion_style": 1,
		"hitstop": true,
		"combos": true,
		"dedicated_special": true,
		"particles": true,
		"screenshake": true
	}
