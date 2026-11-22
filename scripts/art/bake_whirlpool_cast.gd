extends SceneTree
## Bake Whirlpool's character artwork with Godot's renderer and the production Foxy assets.
## Run Godot with a renderer and --script res://scripts/art/bake_whirlpool_cast.gd.

const FOXY := preload("res://gameplay/player/foxy.tscn")
const WATER := preload("res://scripts/art/whirlpool_hand_water.gdshader")
const ART_DIR := "res://assets/sprites/foxy/charm_casts/"
const CELL := 256
const FOOT := Vector2(128, 230.4)
const HEIGHT := CELL * 0.72
const COLUMNS := 8
const SAMPLES := 24
const CHANNEL_SAMPLES := 18
const VIEWS := ["side", "back", "front"]
const SPLASH_END := 0.75
const ARM_BONES := ["arm_l", "arm_r", "forearm_l", "forearm_r"]
# Shoulder and elbow offsets in degrees. The last channel pose leads directly into release.
const ARM_KEYS := [
	Vector4(0, 0, 0, 0),
	Vector4(-19, 19, 22, -25),
	Vector4(17, 37, 24, 14),
	Vector4(37, -8, 12, -18),
	Vector4(54, -28, 7, -35),
	Vector4(49, -38, 5, -42)
]
const BODY_KEYS := [
	Vector2.ZERO, Vector2(5, -3), Vector2(7, -5), Vector2(1, 1), Vector2(-5, 5), Vector2(-6, 4)
]

var viewport: SubViewport
var stage: Node2D
var orbs: Array[ColorRect] = []
var foxy: Node
var rig: Node2D
var fitted: Transform2D
var bones: Dictionary[String, Dictionary] = {}
var suffix: String
var failed := false


func _initialize() -> void:
	_bake.call_deferred()


func _bake() -> void:
	if DisplayServer.get_name() == "headless" or not ClassDB.class_exists("SpineBridge"):
		push_error("Baking needs a renderer and the project's SpineBridge 3.8 provider.")
		quit(1)
		return
	foxy = FOXY.instantiate()
	viewport = SubViewport.new()
	viewport.size = Vector2i(CELL, CELL)
	viewport.disable_3d = true
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	stage = Node2D.new()
	viewport.add_child(stage)
	for i in 2:
		var orb := ColorRect.new()
		var material := ShaderMaterial.new()
		material.shader = WATER
		orb.material = material
		orb.z_index = 2
		stage.add_child(orb)
		orbs.append(orb)
	var strip_height := CELL * (SAMPLES / COLUMNS)
	var side := Image.create_empty(CELL * COLUMNS, strip_height, false, Image.FORMAT_RGBA8)
	var vertical := Image.create_empty(CELL * COLUMNS, strip_height * 2, false, Image.FORMAT_RGBA8)
	for view: String in VIEWS:
		_setup_rig(view)
		for i in SAMPLES:
			if failed:
				break
			_pose(i)
			await RenderingServer.frame_post_draw
			var cell := viewport.get_texture().get_image()
			cell.convert(Image.FORMAT_RGBA8)
			var sheet := side if view == "side" else vertical
			var strip := int(view == "front")
			var grid_pos := Vector2i(i % COLUMNS, i / COLUMNS + strip * (SAMPLES / COLUMNS))
			sheet.blit_rect(cell, Rect2i(Vector2i.ZERO, viewport.size), grid_pos * CELL)
		rig.free()
	if not failed:
		failed = side.save_png(ART_DIR + "abyssal_whirlpool.png") != OK
		failed = vertical.save_png(ART_DIR + "abyssal_whirlpool_vertical.png") != OK or failed
	foxy.free()
	viewport.queue_free()
	print("Whirlpool art bake ", "FAILED" if failed else "complete")
	quit(int(failed))


func _setup_rig(view: String) -> void:
	var preview: Node3D = foxy.get_node("Visual/SpineIdlePreview")
	rig = load("res://addons/spine_bridge/scripts/spine_sprite.gd").new()
	stage.add_child(rig)
	rig.set("skeleton_data_res", load(preview.get("skeleton_data_path")))
	var skin := {"side": "G1", "back": "U", "front": "D"}
	var clips := {"side": "G1_Idle", "back": "U_Idle"}
	suffix = "" if view == "side" else "_" + str(skin[view])
	if not rig.call("set_skin", skin[view]):
		failed = true
		return
	if clips.has(view) and not rig.call("set_animation", clips[view], true, 0):
		failed = true
		return
	rig.call("update_skeleton", 0.0)
	rig.call("pause")
	rig.call("set_attachment", "Eyes/Eyes_01", "")
	if view == "front":
		rig.call("set_attachment", "Eyes/Eyes_Run", "")
	if view == "side":
		# Match the same G1 idle calibration and non-uniform scale as SpineIdlePreview.
		var bounds := Rect2()
		for command in rig.call("_get_render_commands_for_external_consumer"):
			var points: PackedVector2Array = command.positions
			for point in points:
				bounds = bounds.expand(point)
		var factor := HEIGHT / bounds.size.y
		var scale_xy := Vector2(preview.scale.x / preview.scale.y, 1.0) * factor
		fitted = Transform2D(
			0.0, scale_xy, 0.0, FOOT - Vector2(bounds.get_center().x, bounds.end.y) * scale_xy
		)
	rig.transform = fitted
	bones.clear()
	for bone in ARM_BONES + ["body", "head"]:
		bones[bone] = rig.call("get_bone_pose", bone + suffix)


func _pose(frame: int) -> void:
	var release := frame >= CHANNEL_SAMPLES
	var progress := (
		float(frame - CHANNEL_SAMPLES) / (SAMPLES - CHANNEL_SAMPLES - 1)
		if release
		else float(frame) / (CHANNEL_SAMPLES - 1)
	)
	var key := progress * (ARM_KEYS.size() - 1)
	var a := mini(floori(key), ARM_KEYS.size() - 2)
	var t := smoothstep(0, 1, key - a)
	var arms: Vector4 = ARM_KEYS[a].lerp(ARM_KEYS[a + 1], t)
	var body: Vector2 = BODY_KEYS[a].lerp(BODY_KEYS[a + 1], t)
	if release:
		arms = Vector4(10, 34, 4, -5).lerp(Vector4.ZERO, smoothstep(0.15, 1.0, progress))
		body = Vector2(7, -5).lerp(Vector2.ZERO, smoothstep(0.15, 1.0, progress))
	var palms := PackedVector2Array()
	for i in ARM_BONES.size():
		_turn(ARM_BONES[i], arms[i])
	_turn("body", body.x)
	_turn("head", body.y)
	rig.call("refresh_pose")
	for name: String in ["forearm_l", "forearm_r"]:
		var bone := name + suffix
		var forearm: Transform2D = rig.call("get_global_bone_transform", bone)
		var length: float = rig.call("get_bone_data", bone).length
		palms.append(forearm * Vector2(length, 0))
	for i in orbs.size():
		var orb := orbs[i]
		var diameter := (
			lerpf(24, 55, smoothstep(0, 1, progress)) if not release else 58.0 + 20.0 * progress
		)
		orb.size = Vector2.ONE * diameter
		orb.position = palms[i] - orb.size * 0.5
		orb.visible = not release or progress < SPLASH_END
		orb.material.set_shader_parameter("phase", (float(frame) / SAMPLES) * TAU * 2.0 + i * PI)
		orb.material.set_shader_parameter(
			"burst", smoothstep(0.0, SPLASH_END, progress) if release else 0.0
		)


func _turn(bone: String, degrees: float) -> void:
	if not rig.call(
		"set_bone_pose", bone + suffix, {"rotation": float(bones[bone].rotation) + degrees}
	):
		failed = true
