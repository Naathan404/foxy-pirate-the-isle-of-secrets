extends SceneTree

const DATA_PATH := "res://assets/spine/foxy_anim_spine/foxy_skeleton.tres"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var data = load(DATA_PATH)
	var spine_script = load("res://addons/spine_bridge/scripts/spine_sprite_3d.gd")
	var preview_script = load("res://gameplay/player/spine_idle_preview.gd")
	var idle_height := 10.0
	for pair in [["D_Dash", "D"], ["G1_Dash", "G1"], ["U_Dash", "U"]]:
		var preview = preview_script.new()
		root.add_child(preview)
		var spine = spine_script.new()
		spine.skeleton_data_res = data
		preview.add_child(spine)
		spine.get_node("_SpineSpriteCore3D").set_skin(pair[1])
		assert(spine.set_animation(pair[0], false, 0))
		preview._spine = spine
		preview._current_spine_animation = pair[0]
		preview._idle_spine_height = idle_height
		preview._fitted_transform = Transform3D.IDENTITY
		preview._reference_bottom = Vector3.ZERO
		if pair[0] == "G1_Dash":
			spine.scale.x = -1.0
		for sample in range(4):
			spine.update_skeleton(0.1)
			preview._stabilize_dash_size()
			var bounds: AABB = spine.get_aabb()
			var pose: Transform3D = spine.transform
			assert(is_equal_approx(pose.basis.x.length(), 1.0), "Dash width changed")
			if pair[0] == "G1_Dash":
				assert(pose.basis.x.x < 0.0, "Side dash mirror direction changed")
				assert(pose.basis.y.length() <= 1.351, "Side dash became too tall")
			else:
				assert(
					is_equal_approx(pose.basis.y.y * bounds.size.y, idle_height),
					"Dash height differs from idle"
				)
			assert(
				is_zero_approx(pose.origin.y + pose.basis.y.y * bounds.position.y),
				"Dash feet moved"
			)
		preview.queue_free()
		await process_frame
	print("Foxy side dash keeps its width and limited height")
	quit()
