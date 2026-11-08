extends SceneTree

const DATA_PATH := "res://assets/spine/foxy_anim_spine/foxy_skeleton.tres"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var data = load(DATA_PATH)
	var spine_script = load("res://addons/spine_bridge/scripts/spine_sprite_3d.gd")
	var preview_script = load("res://gameplay/player/spine_idle_preview.gd")
	for pair in [["D_Run", "D", 1.1], ["U_Run", "U", 1.08]]:
		var preview = preview_script.new()
		root.add_child(preview)
		var spine = spine_script.new()
		spine.skeleton_data_res = data
		preview.add_child(spine)
		spine.get_node("_SpineSpriteCore3D").set_skin(pair[1])
		assert(spine.set_animation(pair[0], true, 0))
		preview._spine = spine
		preview._current_spine_animation = pair[0]
		preview._fitted_transform = Transform3D.IDENTITY
		preview._reference_bottom = Vector3.ZERO
		for sample in range(5):
			spine.update_skeleton(0.1)
			preview._stabilize_run_size()
			var pose: Transform3D = spine.transform
			var bounds: AABB = spine.get_aabb()
			assert(is_equal_approx(pose.basis.x.length(), pair[2]), "Wrong run width")
			assert(is_equal_approx(pose.basis.y.length(), pair[2]), "Run proportions changed")
			assert(is_zero_approx(pose.origin.y + pose.basis.y.y * bounds.position.y), "Run feet moved")
		preview.queue_free()
		await process_frame
	print("Foxy up/down run size matches idle without stretching")
	quit()
