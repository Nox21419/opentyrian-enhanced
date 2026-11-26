extends GdUnitTestSuite

const Lifetime := preload("res://scripts/audio_bus_lifetime.gd")
const MusicOwner := preload("res://scripts/music.gd")
const SfxOwner := preload("res://scripts/sfx.gd")
var _buses: Array[StringName] = []
var _nodes: Array[Node] = []


func after_test() -> void:
	for node in _nodes:
		if is_instance_valid(node):
			node.free()
	_nodes.clear()
	for name in _buses:
		var index := AudioServer.get_bus_index(name)
		if index >= 0:
			AudioServer.remove_bus(index)
	_buses.clear()
	await get_tree().process_frame


func _bus(name: StringName) -> int:
	AudioServer.add_bus()
	var index := AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, name)
	_buses.append(name)
	return index


func test_owned_native_effects_and_instances_release_after_bus_rename_and_move() -> void:
	var bus := _bus(&"LifetimeOriginal")
	var owned: Array = [ClassDB.instantiate("TyrianStereoGain"), ClassDB.instantiate("TyrianPseudoStereo")]
	var foreign := AudioEffectAmplify.new()
	AudioServer.add_bus_effect(bus, owned[0])
	AudioServer.add_bus_effect(bus, foreign)
	AudioServer.add_bus_effect(bus, owned[1])
	AudioServer.set_bus_effect_enabled(bus, 2, false)
	var effect_id: int = owned[0].get_instance_id()
	var instance: WeakRef = weakref(AudioServer.get_bus_effect_instance(bus, 0))
	assert_bool(instance.get_ref() != null).is_true()
	AudioServer.set_bus_name(bus, &"LifetimeRenamed")
	_buses[0] = &"LifetimeRenamed"
	AudioServer.move_bus(bus, 1)
	Lifetime.release(owned)
	assert_array(owned).is_empty()
	assert_object(instance_from_id(effect_id)).is_null()
	assert_object(instance.get_ref()).is_null()
	bus = AudioServer.get_bus_index(&"LifetimeRenamed")
	assert_int(AudioServer.get_bus_effect_count(bus)).is_equal(1)
	assert_object(AudioServer.get_bus_effect(bus, 0)).is_same(foreign)
	Lifetime.release(owned)
	assert_int(AudioServer.get_bus_effect_count(bus)).is_equal(1)


func test_effect_shared_across_buses_is_removed_from_every_owned_attachment() -> void:
	var owned: Array = [ClassDB.instantiate("TyrianStereoGain")]
	for name in [&"LifetimeA", &"LifetimeB"]:
		AudioServer.add_bus_effect(_bus(name), owned[0])
	Lifetime.release(owned)
	for name in _buses:
		assert_int(AudioServer.get_bus_effect_count(AudioServer.get_bus_index(name))).is_equal(0)


func _counts() -> Dictionary:
	var counts := {}
	for bus in AudioServer.bus_count:
		counts[AudioServer.get_bus_name(bus)] = AudioServer.get_bus_effect_count(bus)
	return counts


func test_real_audio_owner_exit_removes_only_its_effects_and_stream_release_keeps_them() -> void:
	var initial := _counts()
	for owner_script in [MusicOwner, SfxOwner]:
		var owner: Node = owner_script.new()
		_nodes.append(owner)
		add_child(owner)
		var effects: Array = owner.get("_owned_bus_effects") if owner_script == MusicOwner else owner.get("_pans")
		var ids := []
		for effect in effects:
			ids.append(effect.get_instance_id())
		var attached := _counts()
		assert_bool(attached == initial).is_false()
		owner.release_streams()
		assert_dict(_counts()).is_equal(attached)
		# Drop this test's shared Array reference only after owner cleanup clears it.
		owner.free()
		assert_array(effects).is_empty()
		for id in ids:
			assert_object(instance_from_id(id)).is_null()
		assert_dict(_counts()).is_equal(initial)
