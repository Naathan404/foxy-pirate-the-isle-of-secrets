extends SceneTree
## Average GPU and render-CPU time per frame for each scene given, with Foxy at (x, z).
## Integrated GPUs drift with temperature: always measure the room next to a reference
## (room_00 or castaway_cove) in the same run. Needs a window (not --headless).
##
## godot --path . --resolution 1280x720 --script <this> -- <x> <z> <scene> [<scene> ...]

const SETTLE_SECONDS := 2.0
const FRAMES := 150


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var x := float(args[0])
	var z := float(args[1])
	for path in args.slice(2):
		change_scene_to_file(path)
		await create_timer(SETTLE_SECONDS).timeout
		var foxy := current_scene.get_node("Foxy") as Node3D
		foxy.global_position = Vector3(x, foxy.global_position.y, z)
		await create_timer(SETTLE_SECONDS).timeout
		var viewport := root.get_viewport_rid()
		RenderingServer.viewport_set_measure_render_time(viewport, true)
		var gpu := 0.0
		var cpu := 0.0
		var draws := 0
		for i in FRAMES:
			await process_frame
			gpu += RenderingServer.viewport_get_measured_render_time_gpu(viewport)
			cpu += RenderingServer.viewport_get_measured_render_time_cpu(viewport)
			draws += RenderingServer.get_rendering_info(
				RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME
			)
		print(
			(
				"%-24s gpu %.2f ms  render-cpu %.2f ms  draws %d"
				% [path.get_file(), gpu / FRAMES, cpu / FRAMES, draws / FRAMES]
			)
		)
	quit()
