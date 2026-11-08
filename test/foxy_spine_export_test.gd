extends SceneTree

const SKELETON_PATH := "res://assets/spine/foxy_anim_spine/foxy_skeleton.tres"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var data = load(SKELETON_PATH)
	assert(data != null, "Foxy Spine skeleton failed to load")
	var animations: PackedStringArray = data.get_animation_names()
	var skins: PackedStringArray = data.get_skin_names()
	for name in ["Attack_1", "Attack_2", "Attack_3", "D_Dash", "D_Run", "G1_Dash", "G1_Idle", "S_Run", "U_Dash", "U_Idle", "U_Run"]:
		assert(animations.has(name), "Missing Foxy animation: " + name)
	for name in ["D", "G1", "S", "U"]:
		assert(skins.has(name), "Missing Foxy skin: " + name)
	var spine_script := load("res://addons/spine_bridge/scripts/spine_sprite_3d.gd") as Script
	for pair in [["G1_Idle", "G1"], ["U_Idle", "U"], ["D_Run", "D"], ["S_Run", "S"], ["U_Run", "U"], ["D_Dash", "D"], ["G1_Dash", "G1"], ["U_Dash", "U"], ["Attack_1", "G1"], ["Attack_2", "G1"], ["Attack_3", "G1"]]:
		var sprite = spine_script.new()
		sprite.skeleton_data_res = data
		root.add_child(sprite)
		assert(sprite.is_loaded(), "Foxy Spine failed to load for " + pair[0])
		assert(sprite.get_node("_SpineSpriteCore3D").set_skin(pair[1]), "Foxy Spine skin failed: " + pair[1])
		assert(sprite.set_animation(pair[0], true, 0), "Foxy Spine playback failed: " + pair[0])
		sprite.queue_free()
	var foxy_scene := load("res://gameplay/player/foxy.tscn") as PackedScene
	assert(foxy_scene != null, "Foxy scene failed to load")
	var foxy := foxy_scene.instantiate()
	var preview = foxy.get_node("Visual/SpineIdlePreview")
	assert(preview.skeleton_data_path == SKELETON_PATH, "Foxy uses the wrong Spine export")
	for facing in [Vector3(1, 0, 1), Vector3(-1, 0, 1)]:
		assert(preview._mapping_key_for(&"dash_side", facing) == "dash_down")
	for facing in [Vector3(1, 0, -1), Vector3(-1, 0, -1)]:
		assert(preview._mapping_key_for(&"dash_side", facing) == "dash_up")
	for facing in [Vector3.RIGHT, Vector3.LEFT]:
		assert(preview._mapping_key_for(&"dash_side", facing) == "dash_side")
	assert(preview._mapping_key_for(&"run_down", Vector3(1, 0, 1)) == "run_side")
	for mapping in preview.animation_mapping.values():
		assert(animations.has(mapping[0]), "Mapped animation missing: " + mapping[0])
		assert(skins.has(mapping[1]), "Mapped skin missing: " + mapping[1])
	assert(preview.animation_mapping["fall_down"] == preview.animation_mapping["idle_down"])
	assert(preview.animation_mapping["fall_side"] == preview.animation_mapping["idle_down"])
	assert(preview.animation_mapping["fall_up"] == preview.animation_mapping["idle_up"])
	foxy.free()
	print("Foxy Spine export contains all mapped animations and skins")
	quit()
