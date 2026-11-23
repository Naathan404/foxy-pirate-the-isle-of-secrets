extends SceneTree
## Walks Foxy into every enabled exit of a room and checks the scene that loads. Needs a window
## (not --headless), since transitions wait on rendering.
##
## godot --path . --resolution 1280x720 --script <this> -- res://world/.../room_XX.tscn

const SETTLE_SECONDS := 2.0
const TRANSITION_SECONDS := 4.0


func _initialize() -> void:
	var path: String = OS.get_cmdline_user_args()[0]
	change_scene_to_file(path)
	await create_timer(SETTLE_SECONDS).timeout
	var exits: Array[Dictionary] = []
	for trigger in current_scene.find_children("SceneChangeTrigger", "Area3D", true, false):
		if trigger.get("enabled") == false or String(trigger.get("destination_scene")).is_empty():
			continue
		var shape := trigger.get_child(0) as Node3D
		exits.append({"at": shape.global_position, "to": String(trigger.get("destination_scene"))})
	var failures := 0
	for exit in exits:
		change_scene_to_file(path)
		await create_timer(SETTLE_SECONDS).timeout
		var foxy := current_scene.get_node("Foxy") as Node3D
		foxy.global_position = Vector3(exit.at.x, foxy.global_position.y, exit.at.z)
		await create_timer(TRANSITION_SECONDS).timeout
		var ok: bool = current_scene.scene_file_path == exit.to
		failures += 0 if ok else 1
		print(
			(
				"%s  exit at (%.1f, %.1f) -> %s (loaded %s)"
				% [
					"PASS" if ok else "FAIL",
					exit.at.x,
					exit.at.z,
					exit.to.get_file(),
					current_scene.scene_file_path.get_file()
				]
			)
		)
	quit(1 if failures > 0 else 0)
