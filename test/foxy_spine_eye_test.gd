extends SceneTree

const DATA_PATH := "res://assets/spine/foxy_anim_spine/foxy_skeleton.tres"
const EYE_SLOT := "Eyes/Eyes_01"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var data = load(DATA_PATH)
	var spine_script = load("res://addons/spine_bridge/scripts/spine_sprite_3d.gd")
	var preview_script = load("res://gameplay/player/spine_idle_preview.gd")
	for pair in [["S_Run", "S"], ["D_Run", "D"], ["U_Run", "U"], ["D_Dash", "D"]]:
		var preview = preview_script.new()
		root.add_child(preview)
		var spine = spine_script.new()
		spine.skeleton_data_res = data
		preview.add_child(spine)
		spine.get_node("_SpineSpriteCore3D").set_skin(pair[1])
		assert(spine.set_animation(pair[0], true, 0))
		await process_frame
		preview._spine = spine
		preview._active = true
		preview._update_slash_overlay()
		var core = spine.get_node("_SpineSpriteCore3D")
		var commands = core._get_render_commands_for_external_consumer()
		var rows = core._get_slot_render_rows_for_external_consumer()
		var hidden_eye := false
		var correct_eye_visible := false
		for row in rows:
			var slot_name := str(row.get("slot_name", ""))
			if slot_name != EYE_SLOT and slot_name != "Eye_1" and slot_name != "Eyes/Eyes_Run":
				continue
			if not row.has("command"):
				continue
			var slot_command: Dictionary = row["command"]
			for index in commands.size():
				var command: Dictionary = commands[index]
				if command.get("page_index") == slot_command.get("page_index") \
						and command.get("positions") == slot_command.get("positions") \
						and command.get("uvs") == slot_command.get("uvs"):
					var draw = spine.get_node("_SpineDraw3D_%d" % index)
					if slot_name == EYE_SLOT:
						hidden_eye = not draw.visible
					else:
						correct_eye_visible = correct_eye_visible or draw.visible
					break
		assert(hidden_eye, "Stray eye is visible in " + pair[0])
		if pair[0] == "S_Run" or pair[0] == "D_Run":
			assert(correct_eye_visible, "Foxy's proper eyes disappeared in " + pair[0])
		preview.queue_free()
		await process_frame
	print("Foxy stray eye hidden in run and dash clips")
	quit()
