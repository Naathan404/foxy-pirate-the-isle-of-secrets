extends SceneTree
## Render the player fallback and HUD portraits from the same artwork as the live Spine actor.
## Run with a renderer and --script res://scripts/art/bake_foxy_gameplay.gd.

const RIG := preload("res://addons/spine_bridge/scripts/spine_sprite.gd")
const SKELETON := preload("res://assets/spine/foxy_anim_spine/foxy_skeleton.tres")
const SPINE_PREVIEW := preload("res://gameplay/player/spine_idle_preview.gd")
const ATLAS := "res://assets/sprites/foxy/foxy_gameplay.png"
const HUD_DIR := "res://assets/ui/player_hud/"
const CELL := 256
const FOOT := Vector2(128, 164)
const BODY_HEIGHT := 124.0
const PORTRAIT_SIZE := 48
const SKINS := ["D", "G1", "U"]
const RUN_SKINS := ["D", "S", "U"]
const RUN_SAMPLES := [0.0, 0.12, 0.24, 0.36]
const ATTACK_SAMPLES := [0.02, 0.10, 0.19, 0.34]
const PORTRAIT_SLOTS := ["EarL_back", "Head", "EarR_front", "Eye_1"]
const PORTRAIT_TILTS := [0.0, -13.0, 3.0, 6.0, 4.0, 1.0]

var viewport := SubViewport.new()
var rig: SpineSprite
var idle_bounds: Rect2
var failed := false


func _initialize() -> void:
	_bake.call_deferred()


func _bake() -> void:
	if DisplayServer.get_name() == "headless" or not ClassDB.class_exists("SpineBridge"):
		push_error("Baking Foxy requires a renderer and the project's SpineBridge provider.")
		quit(1)
		return
	viewport.size = Vector2i(CELL, CELL)
	viewport.disable_3d = true
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	_pose("G1", "G1_Idle", 0.0)
	idle_bounds = _bounds()
	if not failed and idle_bounds.has_area():
		await _bake_body()
		await _bake_portraits()
	else:
		failed = true
	viewport.queue_free()
	print("Foxy artwork bake ", "FAILED" if failed else "complete")
	quit(int(failed))


func _pose(skin: String, animation: String, seconds: float) -> void:
	# A fresh Spine 3.8 instance clears attachments left behind by the previous skin.
	if is_instance_valid(rig):
		rig.free()
	rig = RIG.new()
	viewport.add_child(rig)
	rig.skeleton_data_res = SKELETON
	if not rig.set_skin(skin) or not rig.set_animation(animation, true, 0):
		push_error("Missing Foxy pose %s / %s" % [skin, animation])
		failed = true
		return
	rig.update_skeleton(seconds)
	rig.pause()
	rig.set_attachment("Eyes/Eyes_01", "")


func _bounds() -> Rect2:
	var points := PackedVector2Array()
	for command in rig._get_render_commands_for_external_consumer():
		points.append_array(command.positions)
	if points.is_empty():
		return Rect2()
	var bounds := Rect2(points[0], Vector2.ZERO)
	for point in points:
		bounds = bounds.expand(point)
	return bounds


func _bake_body() -> void:
	# Keep the frame addresses used by Foxy's AnimationPlayer and dash afterimages.
	var atlas := Image.create_empty(CELL * 4, CELL * 15, false, Image.FORMAT_RGBA8)
	for column in SKINS.size():
		for row in 15:
			if row == 9:
				continue
			_body_pose(row, column)
			await _stamp(atlas, Vector2i(column, row))
		var skin: String = SKINS[column]
		_pose(skin, skin + "_Dash", 0.06)
		var bounds := _bounds()
		var stretch := maxf(1.0, idle_bounds.size.y / bounds.size.y)
		if skin == "G1":
			stretch = minf(stretch, 1.35)
		_place_body(bounds, Vector2(1.0, stretch))
		await _stamp(atlas, Vector2i(3, column))
	if not failed:
		_save(atlas, ATLAS)


func _body_pose(row: int, column: int) -> void:
	var idle_skin := "U" if column == 2 else "G1"
	var stretch := Vector2.ONE
	if row < 4:
		var skin: String = RUN_SKINS[column]
		var clip := skin + "_Run"
		_pose(skin, clip, RUN_SAMPLES[row])
		_place_body(
			_bounds(), Vector2.ONE * float(SPINE_PREVIEW.RUN_SIZE_MULTIPLIERS.get(clip, 1.0))
		)
		return
	if row >= 11:
		# PlayerVisual plays the side-facing attack for every world aim direction.
		_pose("G1", "Attack_1", ATTACK_SAMPLES[row - 11])
	else:
		_pose(idle_skin, idle_skin + "_Idle", 0.45 if row == 5 else 0.0)
		if row in [6, 7, 8, 10]:
			var recoil := {6: -5.0, 7: -12.0, 8: -3.0, 10: 18.0}
			var suffix := "_U" if column == 2 else ""
			_turn("body" + suffix, recoil[row])
			_turn("head" + suffix, -recoil[row] * 0.4)
			rig.refresh_pose()
			stretch = Vector2(1.10, 0.84) if row == 10 else Vector2.ONE
	_place_body(idle_bounds, stretch)


func _place_body(bounds: Rect2, stretch: Vector2) -> void:
	var scale_xy := stretch * BODY_HEIGHT / idle_bounds.size.y
	rig.scale = scale_xy
	rig.position = FOOT - Vector2(bounds.get_center().x, bounds.end.y) * scale_xy


func _stamp(atlas: Image, grid_position: Vector2i) -> void:
	await RenderingServer.frame_post_draw
	var cell := viewport.get_texture().get_image()
	cell.convert(Image.FORMAT_RGBA8)
	var used := cell.get_used_rect()
	if not used.has_area() or not Rect2i(1, 1, CELL - 2, CELL - 2).encloses(used):
		push_error("Empty or clipped Foxy frame at %s: %s" % [grid_position, used])
		failed = true
	atlas.blit_rect(cell, Rect2i(Vector2i.ZERO, viewport.size), grid_position * CELL)


func _bake_portraits() -> void:
	var low_hp := Image.create_empty(PORTRAIT_SIZE * 4, PORTRAIT_SIZE, false, Image.FORMAT_RGBA8)
	var neutral_bounds := Rect2()
	for i in 6:
		_pose("G1", "G1_Idle", 0.0)
		for slot in rig.get_slot_names():
			if slot not in PORTRAIT_SLOTS and not slot.begins_with("Eyes/"):
				rig.set_attachment(slot, "")
		if i == 0:
			neutral_bounds = _bounds()
		_turn("head", PORTRAIT_TILTS[i])
		rig.refresh_pose()
		var factor := CELL * 0.85 / maxf(neutral_bounds.size.x, neutral_bounds.size.y)
		rig.scale = Vector2.ONE * factor
		rig.position = viewport.size * 0.5 - neutral_bounds.get_center() * factor
		await RenderingServer.frame_post_draw
		var face := viewport.get_texture().get_image()
		face.convert(Image.FORMAT_RGBA8)
		face.resize(PORTRAIT_SIZE, PORTRAIT_SIZE, Image.INTERPOLATE_LANCZOS)
		if i < 2:
			_save(face, HUD_DIR + ("portrait.png" if i == 0 else "hit_portrait.png"))
		else:
			# Preserve the animated sweat cue when health is low.
			var drop := Vector2i(5, 14 + (i - 2) * 2)
			face.fill_rect(Rect2i(drop + Vector2i(2, 0), Vector2i(2, 5)), Color.SKY_BLUE)
			face.fill_rect(Rect2i(drop + Vector2i(1, 4), Vector2i(4, 3)), Color.DEEP_SKY_BLUE)
			face.set_pixelv(drop + Vector2i(2, 4), Color.WHITE)
			var dest := Vector2i((i - 2) * PORTRAIT_SIZE, 0)
			low_hp.blit_rect(face, Rect2i(Vector2i.ZERO, face.get_size()), dest)
	_save(low_hp, HUD_DIR + "30%_status-Sheet.png")


func _turn(bone: String, degrees: float) -> void:
	var pose := rig.get_bone_pose(bone)
	if (
		not pose.has("rotation")
		or not rig.set_bone_pose(bone, {"rotation": float(pose.rotation) + degrees})
	):
		push_error("Missing Foxy pose bone " + bone)
		failed = true


func _save(image: Image, path: String) -> void:
	if image.save_png(path) != OK:
		push_error("Could not save " + path)
		failed = true
