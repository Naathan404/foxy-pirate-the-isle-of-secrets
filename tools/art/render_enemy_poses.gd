extends SceneTree
## Renders each enemy's portrait pose straight from its Spine skeleton onto a transparent
## canvas. Step 1 of the bestiary portraits; step 2 is make_enemy_portraits.py.
##
## Usage (from the project root, windowed: Spine needs a renderer):
##   godot --path . -s tools/art/render_enemy_poses.gd -- <output_dir>

const SIZE := 1024
const MARGIN := 40.0
## Portrait id -> skeleton, animation and how far through it the pose is taken (0 to 1).
const POSES := {
	"crab": ["res://assets/spine/enemies/Enemy_Crab/crab_skeleton.tres", "idle", 0.0],
	"hermit_crab":
	["res://assets/spine/enemies/Enemy_HermitCarb/hermit_crab_skeleton.tres", "idle", 0.5],
	# The lid popped open, so the mimic inside shows.
	"barrel": ["res://assets/spine/enemies/Enemy_Barrel/barrel_skeleton.tres", "pop_up", 1.0],
}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("render_enemy_poses: pass the output folder after --")
		quit(1)
		return
	var out := args[0].trim_suffix("/") + "/"
	var viewport := SubViewport.new()
	viewport.size = Vector2i(SIZE, SIZE)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	for id: String in POSES:
		var pose: Array = POSES[id]
		var spine := ClassDB.instantiate("SpineSprite") as Node2D
		spine.set("skeleton_data_res", load(pose[0]))
		viewport.add_child(spine)
		await process_frame
		var entry = spine.get_animation_state().set_animation(pose[1], false, 0)
		entry.set_mix_duration(0.0)
		var length: float = entry.get_animation().get_duration()
		entry.set_track_time(maxf(0.0, length * float(pose[2]) - 0.001))
		spine.set("time_scale", 0.0)
		spine.update_skeleton(0.0)
		var bounds: Rect2 = spine.get_skeleton().get_bounds()
		var fit: float = (SIZE - MARGIN * 2.0) / maxf(bounds.size.x, bounds.size.y)
		spine.scale = Vector2(fit, fit)
		spine.position = Vector2(SIZE, SIZE) * 0.5 - (bounds.position + bounds.size * 0.5) * fit
		for i in 4:
			await process_frame
		var error := viewport.get_texture().get_image().save_png(out + id + ".png")
		print("render_enemy_poses: %s -> %s" % [id, error_string(error)])
		spine.queue_free()
		await process_frame
	quit(0)
