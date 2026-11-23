extends SceneTree
## Saves an in-game screenshot of a room, optionally with Foxy moved to (x, z) first. Set the
## environment variable OVERVIEW=<metres> for a top-down orthographic overview instead.
## Needs a window (not --headless). Keep x/z off exit triggers or the room changes.
##
## godot --path . --resolution 1280x720 --script <this> -- <scene> <out.png> [wait_s] [x] [z]

const DEFAULT_WAIT_SECONDS := 2.0
const MOVE_SETTLE_SECONDS := 1.5
const OVERVIEW_HEIGHT := 40.0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var wait := float(args[2]) if args.size() > 2 else DEFAULT_WAIT_SECONDS
	change_scene_to_file(args[0])
	await create_timer(wait).timeout
	if args.size() > 4:
		var foxy := current_scene.get_node_or_null("Foxy") as Node3D
		if foxy != null:
			foxy.global_position = Vector3(float(args[3]), foxy.global_position.y, float(args[4]))
		await create_timer(MOVE_SETTLE_SECONDS).timeout
	if not OS.get_environment("OVERVIEW").is_empty():
		var camera := Camera3D.new()
		current_scene.add_child(camera)
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = float(OS.get_environment("OVERVIEW"))
		camera.position = Vector3(0, OVERVIEW_HEIGHT, 0)
		camera.rotation_degrees = Vector3(-90, 0, 0)
		camera.current = true
		await create_timer(0.5).timeout
	root.get_viewport().get_texture().get_image().save_png(args[1])
	quit()
