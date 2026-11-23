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
