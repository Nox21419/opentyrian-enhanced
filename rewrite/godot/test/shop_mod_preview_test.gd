extends GdUnitTestSuite

const ShopScript := preload("res://scripts/shop.gd")
var _enabled := {}


func before() -> void:
	for mod in Mods.list():
		_enabled[mod["folder"]] = mod["enabled"]
		Mods.set_enabled(mod["folder"], true)
	Mods.reload()


func after() -> void:
	for folder in _enabled:
		Mods.set_enabled(folder, _enabled[folder])
	Mods.reload()


func test_all_shipped_weapons_supply_animated_preview_pngs() -> void:
	var frames := PackedInt32Array()
	for sprite in Mods.api.sprites(1):
		if sprite["table"] == "shots":
			frames.append(int(sprite["index"]))
	var vga: RefCounted = ClassDB.instantiate("TyrianVga")
	ClassDB.class_call_static("TyrianVga", "load_assets", Game.data_dir)
	var weapons := 0
	for item in Mods.items():
		if item["kind"] != "weapon":
			continue
		weapons += 1
		# Give both ports the item so front-only and rear-only packs both fire.
		var id := int(item["id"])
		var shop: RefCounted = ClassDB.instantiate("TyrianShop")
		shop.set_mods(Mods.api)
		(
			assert_bool(shop.open(Game.data_dir, 1, PackedInt32Array([1, id, 1, id, 1, 4, 6, 0, 0, 0, 100000]), [], 1))
			. is_true()
		)
		shop.set_preview_mod_frames(frames)
		var seen := {}
		for _tick in 90:
			shop.weapon_view_frame(vga)
			var shots: PackedInt32Array = shop.preview_mod_shots()
			# Reading presentation data must not advance the demonstration.
			assert_array(Array(shop.preview_mod_shots())).is_equal(Array(shots))
			for k in range(0, shots.size(), 3):
				assert_object(Mods.texture("shots", shots[k + 2])).is_not_null()
				seen[shots[k + 2]] = true
		assert_int(seen.size()).override_failure_message(String(item["name"])).is_greater(1)
	assert_int(weapons).is_equal(18)


func test_preview_mask_preserves_frame_and_power_panel() -> void:
	var shop: Node = auto_free(ShopScript.new())
	shop._mod_preview = auto_free(Node2D.new())
	shop._setup_mod_preview_mask()
	var mat: ShaderMaterial = shop._mod_preview.material
	var mask: Image = mat.get_shader_parameter("preview_mask").get_image()
	assert_float(mask.get_pixel(72, 60).r).is_equal(1.0)
	assert_float(mask.get_pixel(0, 60).r).is_equal(0.0)
	assert_float(mask.get_pixel(72, 137).r).is_equal(0.0)
	assert_float(mask.get_pixel(160, 60).r).is_equal(0.0)


func _offered_mod_weapons(episode: int, section: int, equipped := 1) -> Array[String]:
	var names := {}
	for item in Mods.api.items(episode):
		if item["kind"] == "weapon":
			names[int(item["id"])] = String(item["name"])
	var offered: Array[String] = []
	for category in [3, 4]:
		var shop: RefCounted = ClassDB.instantiate("TyrianShop")
		shop.set_mods(Mods.api)
		shop.set_campaign_section(section)
		var loadout := PackedInt32Array([1, equipped, 1, 0, 1, 4, 6, 0, 0, 0, 1000000])
		assert_bool(shop.open(Game.data_dir, episode, loadout, [], 1)).is_true()
		shop.click_row(4)
		shop.click_row(4)
		shop.click_row(category)
		shop.click_row(category)
		var state: Dictionary = shop.state()
		assert_int(int(state["category"])).is_equal(category)
		for id in state["items"]:
			if names.has(id):
				offered.append(names[id])
	return offered


func test_campaign_stock_uses_the_actual_shop_section() -> void:
	for point in [[1, 2, 3], [1, 9, 6], [1, 17, 3], [2, 1, 9], [2, 7, 10], [3, 1, 12], [3, 7, 14]]:
		var stock := _offered_mod_weapons(point[0], point[1])
		assert_int(stock.size()).override_failure_message(str(point)).is_equal(point[2])
	assert_int(_offered_mod_weapons(4, 1).size()).is_equal(16)
	assert_int(_offered_mod_weapons(5, 1).size()).is_equal(17)
	assert_int(_offered_mod_weapons(5, 9).size()).is_equal(18)
	assert_bool(_offered_mod_weapons(1, 2).has("Zica Thermal Lance")).is_false()


func test_equipped_late_weapon_remains_in_an_early_shop() -> void:
	var lance := -1
	for item in Mods.api.items(1):
		if item["name"] == "Zica Thermal Lance":
			lance = int(item["id"])
	assert_int(lance).is_greater(0)
	assert_bool(_offered_mod_weapons(1, 2, lance).has("Zica Thermal Lance")).is_true()


func _offered_mod_ships(episode: int, section: int, equipped := 1) -> Array[String]:
	var names := {}
	for item in Mods.api.items(episode):
		if item["kind"] == "ship":
			names[int(item["id"])] = String(item["name"])
			assert_bool(bool(item["always_available"])).is_false()
	var shop: RefCounted = ClassDB.instantiate("TyrianShop")
	shop.set_mods(Mods.api)
	shop.set_campaign_section(section)
	var loadout := PackedInt32Array([equipped, 1, 1, 0, 1, 4, 6, 0, 0, 0, 1000000])
	assert_bool(shop.open(Game.data_dir, episode, loadout, [], 1)).is_true()
	shop.click_row(4)
	shop.click_row(4)
	shop.click_row(2)
	shop.click_row(2)
	var state: Dictionary = shop.state()
	assert_int(int(state["category"])).is_equal(2)
	var offered: Array[String] = []
	for id in state["items"]:
		if names.has(id):
			offered.append(names[id])
	return offered


func test_campaign_ships_unlock_by_armor_tier_and_keep_owned_ships() -> void:
	for point in [[1, 2, 3], [1, 17, 3], [1, 9, 5], [2, 1, 8], [3, 1, 10], [4, 1, 12], [5, 1, 14]]:
		assert_int(_offered_mod_ships(point[0], point[1]).size()).is_equal(point[2])
	var hive := -1
	for item in Mods.api.items(1):
		if item["name"] == "Hive Mother":
			hive = int(item["id"])
			assert_int(int(item["cost"])).is_equal(52000)
	assert_int(hive).is_greater(0)
	assert_bool(_offered_mod_ships(1, 2, hive).has("Hive Mother")).is_true()
