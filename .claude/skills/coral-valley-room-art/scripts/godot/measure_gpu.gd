extends SceneTree
## Average GPU and render-CPU time per frame for each scene given, with Foxy at (x, z), plus the
## whole frame (game logic included) with vsync off: average, frames per second and the slowest
## 1% of frames. The project's target is 60 fps, so the 1% low must stay under 16.6 ms.
## Integrated GPUs drift with temperature: always measure the room next to a reference
## (room_00 or castaway_cove) in the same run. Needs a window (not --headless).
##
## godot --path . --resolution 1280x720 --script <this> -- <x> <z> <scene> [<scene> ...]

## Long enough for first-use shader compiles to finish before measuring.
const SETTLE_SECONDS := 4.0
const FRAMES := 300


func _initialize() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
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
		var frame_ms: Array[float] = []
		var logic_ms := 0.0
		var last := Time.get_ticks_usec()
		for i in FRAMES:
			await process_frame
			var now := Time.get_ticks_usec()
			frame_ms.append((now - last) / 1000.0)
			last = now
			logic_ms += (
				(
					Performance.get_monitor(Performance.TIME_PROCESS)
					+ Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)
				)
				* 1000.0
			)
			gpu += RenderingServer.viewport_get_measured_render_time_gpu(viewport)
			cpu += RenderingServer.viewport_get_measured_render_time_cpu(viewport)
			draws += RenderingServer.get_rendering_info(
				RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME
			)
		var average := 0.0
		for ms in frame_ms:
			average += ms
		average /= frame_ms.size()
		frame_ms.sort()
		var slowest := frame_ms[int(frame_ms.size() * 0.99)]
		print(
			(
				"%-24s gpu %.2f  render-cpu %.2f  logic %.2f  frame %.2f ms (%d fps)  1%% low %.2f ms  draws %d"
				% [
					path.get_file(),
					gpu / FRAMES,
					cpu / FRAMES,
					logic_ms / FRAMES,
					average,
					roundi(1000.0 / average),
					slowest,
					draws / FRAMES,
				]
			)
		)
	quit()
