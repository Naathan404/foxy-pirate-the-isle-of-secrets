extends Node3D
## Spine visual overlay; PlayerVisual's AnimationPlayer keeps gameplay timing.

const ATTACK_PLAYBACK_WINDOWS := {
	"Attack_1": 0.4,
	"Attack_2": 0.5,
	"Attack_3": 1.2,
}

@export var enabled: bool = true
@export_file("*.tres")
var skeleton_data_path: String = "res://assets/spine/compat/foxy_skeleton.tres"
@export var spine_animation: String = "animation"
@export var spine_skin: String = ""
@export var animation_mapping: Dictionary = {}
@export var artwork_faces_left: bool = true
## Scale the fitted Spine artwork without moving its feet from the sprite baseline.
@export_range(0.25, 3.0, 0.05, "or_greater") var size_multiplier: float = 1.0

var _spine: Node3D
var _load_attempted: bool = false
var _active: bool = false
var _fitted_transform: Transform3D = Transform3D.IDENTITY
var _reference_height: float = 0.0
var _reference_bottom: Vector3 = Vector3.ZERO
var _fit_ready: bool = false
var _current_spine_animation: String = ""
var _current_spine_skin: String = ""
var _dagger_combo_index: int = 0
var _slash_overlay_shaders: Dictionary = {}
var _attack_duration: float = 0.0


func _ready() -> void:
	visible = false
	# Let the Spine node rebuild its draw meshes before updating the slash material.
	process_priority = 100


## Capture the authored idle pose before dash stretch, recoil and animation frames modify it.
func configure_reference(source: Sprite3D, animator: AnimationPlayer) -> void:
	var texture: Texture2D = source.texture
	var frame: int = source.frame
	if is_instance_valid(animator) and animator.has_animation(&"idle_down"):
		var idle := animator.get_animation(&"idle_down")
		var animation_root := animator.get_node(animator.root_node)
		for track in idle.get_track_count():
			if (
				idle.track_get_type(track) != Animation.TYPE_VALUE
				or idle.track_get_key_count(track) == 0
			):
				continue
			var path := idle.track_get_path(track)
			if path.get_subname_count() != 1:
				continue
			if animation_root.get_node_or_null(NodePath(path.get_concatenated_names())) != source:
				continue
			match String(path.get_subname(0)):
				"frame":
					frame = int(idle.track_get_key_value(track, 0))
				"texture":
					texture = idle.track_get_key_value(track, 0) as Texture2D
	if texture == null:
		return
	var image := texture.get_image()
	var frame_size := Vector2i(
		floori(float(image.get_width()) / source.hframes),
		floori(float(image.get_height()) / source.vframes)
	)
	var coords := Vector2i(frame % source.hframes, floori(float(frame) / source.hframes))
	var used := image.get_region(Rect2i(coords * frame_size, frame_size)).get_used_rect()
	if not used.has_area():
		used = Rect2i(Vector2i.ZERO, frame_size)
	var height := float(used.size.y) * source.pixel_size * source.scale.y
	var bottom := (
		(float(frame_size.y) / 2.0 + source.offset.y - float(used.end.y))
		* source.pixel_size
		* source.scale.y
	)
	# The preview has its own authored transform; fitting in Visual coordinates would apply
	# its vertical scale/offset a second time and move the feet below the sprite's baseline.
	var inverse := transform.affine_inverse()
	_reference_height = absf((inverse.basis * Vector3.UP * height).y)
	_reference_bottom = inverse * (source.position + Vector3.UP * bottom)
	_fit_ready = false


func _process(_delta: float) -> void:
	if not is_instance_valid(_spine) or not _active:
		return
	var hitstop := get_node_or_null("/root/HitstopController")
	if hitstop != null and hitstop.is_frozen(get_parent().get_parent()):
		_spine.pause()
	else:
		_spine.resume()
	_update_slash_overlay()


func _update_slash_overlay() -> void:
	var core := _spine.get_node_or_null("_SpineSpriteCore3D")
	if core == null:
		return
	var commands: Array = core._get_render_commands_for_external_consumer()
	var rows: Array = core._get_slot_render_rows_for_external_consumer()
	for row in rows:
		var slot_name := str(row.get("slot_name", "")).to_lower()
		if not slot_name.contains("slash"):
			continue
		if not row.has("command"):
			continue
		var slot_command: Dictionary = row["command"]
		# Spine draw commands omit slot_name, so identify the matching mesh by geometry.
		var index := -1
		for command_index in commands.size():
			var command: Dictionary = commands[command_index]
			if command.get("page_index") == slot_command.get("page_index") \
					and command.get("positions") == slot_command.get("positions") \
					and command.get("uvs") == slot_command.get("uvs"):
				index = command_index
				break
		if index < 0:
			continue
		var draw := _spine.get_node_or_null("_SpineDraw3D_%d" % index) as MeshInstance3D
		if draw == null or not draw.visible:
			continue
		var material := draw.material_override as ShaderMaterial
		if material == null or material.shader == null:
			continue
		var code := material.shader.code
		if code.contains("depth_test_disabled"):
			continue
		var overlay_code := code.replace("depth_draw_always", "depth_draw_never, depth_test_disabled")
		if overlay_code == code:
			overlay_code = code.replace("depth_draw_never", "depth_draw_never, depth_test_disabled")
		if overlay_code == code:
			continue
		if not _slash_overlay_shaders.has(code):
			var shader := Shader.new()
			shader.code = overlay_code
			_slash_overlay_shaders[code] = shader
		material.shader = _slash_overlay_shaders[code]


func set_dagger_combo_index(index: int) -> void:
	_dagger_combo_index = clampi(index, -1, 2)


func fit_attack_duration(duration: float) -> void:
	_attack_duration = duration
	_apply_attack_speed()


func reset_attack_speed() -> void:
	_attack_duration = 0.0
	_apply_attack_speed()


func _apply_attack_speed() -> void:
	if not is_instance_valid(_spine):
		return
	var window: float = ATTACK_PLAYBACK_WINDOWS.get(_current_spine_animation, 0.0)
	_spine.set("time_scale", window / _attack_duration if window > 0.0 and _attack_duration > 0.0 else 1.0)


## The dash effect snapshots the meshes currently drawn by Spine.
func get_afterimage_source() -> Node3D:
	return _spine if _active and visible and is_instance_valid(_spine) else null


func sync_animation(
	animation_name: StringName,
	source: Sprite3D,
	active_sprite: Sprite3D,
	camera: Camera3D,
	facing_left: bool,
	screen_facing: Vector3,
	restart: bool = false
) -> void:
	var target_animation := ""
	var target_skin := spine_skin
	var mapping_key := String(animation_name)
	if animation_name == &"idle_side":
		mapping_key = "idle_down"
	elif (
		(mapping_key.begins_with("run_") or mapping_key.begins_with("dash_"))
		and absf(screen_facing.x) > 0.01
		and absf(screen_facing.z) > 0.01
	):
		mapping_key = mapping_key.get_slice("_", 0) + "_side"
	var mapping: Array = animation_mapping.get(mapping_key, [])
	if mapping.size() == 2:
		target_animation = str(mapping[0])
		target_skin = str(mapping[1])
		if String(animation_name).begins_with("attack_dagger_"):
			target_animation = (
				"Attack_%d" % (_dagger_combo_index + 1)
				if _dagger_combo_index >= 0 else ""
			)
	elif animation_mapping.is_empty() and animation_name == &"idle_down":
		target_animation = spine_animation
	var show_preview := enabled and not target_animation.is_empty()
	if show_preview and is_instance_valid(_spine) and (
		restart
		or _current_spine_animation != target_animation
		or _current_spine_skin != target_skin
	):
		# Spine 3.8 cannot restore setup pose after a skin/clip change.
		# A fresh instance prevents leftover bone and attachment state.
		_spine.visible = false
		_spine.set_process(false)
		_spine.set_physics_process(false)
		_spine.queue_free()
		_spine = null
		_load_attempted = false
	if show_preview:
		show_preview = _ensure_spine()
	if show_preview and not _fit_ready:
		var calibration_core = _spine.get_node("_SpineSpriteCore3D")
		if not spine_skin.is_empty():
			show_preview = calibration_core.set_skin(spine_skin)
		if show_preview:
			show_preview = bool(_spine.set_animation(spine_animation, true, 0))
		if show_preview:
			_fit_to_sprite()
			show_preview = _fit_ready
		if show_preview:
			_spine.visible = false
			_spine.set_process(false)
			_spine.set_physics_process(false)
			_spine.queue_free()
			_spine = null
			_load_attempted = false
			show_preview = _ensure_spine()
	if show_preview and (
		not _active
		or restart
		or _current_spine_animation != target_animation
		or _current_spine_skin != target_skin
	):
		if not target_skin.is_empty():
			var core = _spine.get_node("_SpineSpriteCore3D")
			show_preview = core.set_skin(target_skin)
		if show_preview:
			var loop := not String(animation_name).begins_with("attack_dagger_")
			show_preview = bool(_spine.set_animation(target_animation, loop, 0))
		if show_preview:
			_current_spine_animation = target_animation
			_current_spine_skin = target_skin
	_active = show_preview
	visible = _active
	source.visible = source == active_sprite and not _active
	if not is_instance_valid(_spine):
		return
	if not _active:
		_spine.pause()
		return
	_apply_attack_speed()
	# Mirror the artwork and its fitted offset together.
	var facing_transform := _fitted_transform
	if facing_left != artwork_faces_left:
		facing_transform.basis.x *= -1.0
		facing_transform.origin.x = 2.0 * _reference_bottom.x - _fitted_transform.origin.x
	_spine.transform = facing_transform
	var active_camera := camera
	if not is_instance_valid(active_camera):
		active_camera = get_viewport().get_camera_3d()
	if is_instance_valid(active_camera):
		# Face the camera's view direction. Its position slides sideways at map
		# bounds, which must not yaw the flat Spine artwork.
		var direction: Vector3 = (
			get_parent().global_basis.inverse() * active_camera.global_basis.z
		)
		rotation.y = atan2(direction.x, direction.z)


func _ensure_spine() -> bool:
	if is_instance_valid(_spine):
		return _spine.is_loaded()
	if _load_attempted:
		return false
	_load_attempted = true
	# Avoid a hard native-resource dependency on platforms without this Windows addon.
	if not ClassDB.class_exists("SpineBridge"):
		return false
	var script_path := "res://addons/spine_bridge/scripts/spine_sprite_3d.gd"
	if not ResourceLoader.exists(script_path) or not ResourceLoader.exists(skeleton_data_path):
		return false
	var spine_script := load(script_path) as Script
	_spine = spine_script.new() as Node3D
	if not _spine.has_method("set_animation"):
		_spine.free()
		_spine = null
		push_warning("Spine idle preview needs the SpineBridge 3.8 playback patch")
		return false
	add_child(_spine)
	_spine.set("shadow_casting", 2)  # Double Sided
	var skeleton_data = load(skeleton_data_path)
	_spine.set("skeleton_data_res", skeleton_data)
	_spine.pause()
	return _spine.is_loaded()


func _fit_to_sprite() -> void:
	# Calibrate once against the authored idle pose. Action clips can start compressed.
	_spine.transform = Transform3D.IDENTITY
	_spine.update_skeleton(0.0)
	var bounds: AABB = _spine.get_aabb()
	if bounds.size.y <= 0.0 or _reference_height <= 0.0:
		return
	var factor := _reference_height / bounds.size.y * size_multiplier
	_spine.scale = Vector3.ONE * factor
	_spine.position = (
		Vector3(-bounds.get_center().x * factor, -bounds.position.y * factor, 0.0)
		+ _reference_bottom
	)
	_fitted_transform = _spine.transform
	_fit_ready = true
