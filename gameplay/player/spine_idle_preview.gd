extends Node3D
## Spine visual overlay; PlayerVisual's AnimationPlayer keeps gameplay timing.

const ATTACK_PLAYBACK_WINDOWS := {
	"Attack_1": 0.4,
	"Attack_2": 0.5,
	"Attack_3": 1.2,
}
const DAGGER_COMBO_ANIMATIONS := ["Attack_1", "Attack_2", "Attack_1", "Attack_3"]
const RUN_SIZE_MULTIPLIERS := {"D_Run": 1.1, "U_Run": 1.08}
## Frames of a run clip averaged into its fixed anchor (about one stride at 60-120 fps).
const RUN_ANCHOR_SAMPLES := 60
## The up and down runs key the hip and neck with large, uneven hops (hold, then a sharp drop;
## the neck bobs 18 Spine units per stride and the hip 15, against 5 and 0 in S_Run). The hip
## is held at its average height and the neck follows an even wave timed to the clip's own
## stride. The feet are IK targets, so they stay planted.
const RUN_BOB_BONES := {"U_Run": ["center_U", "Neck_U"], "D_Run": ["center_D", "Neck_D"]}
## Neck bob per stride (Spine units): the clip's own stride strength (fitted 18), played as an
## even wave. With the hip held, the head travels about 40 units, against 68 in S_Run.
const RUN_BOB_AMPLITUDE := 18.0
## Every run clip is 0.7 s long with two strides.
const RUN_CLIP_SECONDS := 0.7
const RUN_STRIDES_PER_CLIP := 2.0
const STRAY_EYE_SLOT := "Eyes/Eyes_01"
## Root bones of the up/down dash clips. Their scale keys squash the whole body to half its
## height (Y down to 0.5 while X widens), which reads as flattened from the gameplay camera.
const VERTICAL_DASH_ROOT_BONES := {"U_Dash": "center_U", "D_Dash": "center_D"}
## Some Spine 3.8 dash clips are exposed by name but not as animation objects.
const DASH_CLIP_DURATION := 0.5
## spine-godot (GDExtension). Builds without it keep the sprite-sheet Foxy.
const SPINE_SPRITE_CLASS := "SpineSprite3D"
## SpineSprite3D.update_mode values.
const SPINE_UPDATE_PROCESS := 0
const SPINE_UPDATE_MANUAL := 2
## SpineSprite3D.shadow_casting: Double-Sided.
const SPINE_SHADOW_DOUBLE_SIDED := 2
## Multiplied into the skeleton colour at full hit tint (red flash).
const HIT_TINT_COLOR := Color(1.0, 0.25, 0.25)
const SPINE_SLOT_NODE_CLASS := "SpineSlotNode3D"
## Skeleton.update_world_transform(physics): Foxy has no physics constraints.
const SPINE_PHYSICS_NONE := 0
## Slash slot material: spine-godot's generated normal-blend shader, drawn without depth testing.
const SLASH_SHADER_HEAD := """shader_type spatial;
render_mode unshaded, depth_draw_never, depth_test_disabled, blend_mix, cull_disabled;
"""
const SLASH_SHADER_BODY := """
uniform sampler2D spine_texture : repeat_disable;
uniform bool spine_premultiplied_alpha = false;
varying vec4 spine_light_color;
varying vec3 spine_dark_color;
vec3 spine_srgb_to_linear(vec3 color) {
	return mix(pow((color + vec3(0.055)) / 1.055, vec3(2.4)), color / 12.92,
		lessThanEqual(color, vec3(0.04045)));
}
void vertex() {
	VERTEX = spine_apply_camera_depth(VERTEX, MODEL_MATRIX[3].xyz, MODEL_NORMAL_MATRIX[2],
		INV_VIEW_MATRIX[3].xyz);
	spine_light_color = CUSTOM0;
	spine_dark_color = CUSTOM1.rgb;
	if (!OUTPUT_IS_SRGB) {
		spine_light_color.rgb = spine_srgb_to_linear(spine_light_color.rgb);
		spine_dark_color = spine_srgb_to_linear(spine_dark_color);
	}
}
void fragment() {
	vec4 tex = texture(spine_texture, UV);
	if (spine_premultiplied_alpha) tex.rgb = tex.a > 0.000001 ? tex.rgb / tex.a : vec3(0.0);
	if (!OUTPUT_IS_SRGB) tex.rgb = spine_srgb_to_linear(tex.rgb);
	ALBEDO = tex.rgb * spine_light_color.rgb + (vec3(1.0) - tex.rgb) * spine_dark_color;
	ALPHA = tex.a * spine_light_color.a;
	spine_apply_alpha_cutoff(ALPHA);
}
"""
## Skeleton data by path, kept across rooms. Every room instances a new Foxy; loading the data
## again meant decoding and uploading all twelve atlas pages, a ~0.4 s stall on each arrival.
static var _skeleton_data_cache: Dictionary[String, Resource] = {}
## Per run clip: Vector3(sum of bounds centre x, lowest bounds bottom, sample count). Shared by
## every Foxy so the anchor is settled after the first stride of the session.
static var _run_anchors: Dictionary[String, Vector3] = {}
## Per run clip in RUN_BOB_BONES, measured over its first play of the session: time-weighted
## sums of the hip height, the neck height and the neck's stride wave (cos and sin parts).
static var _run_bob_fits: Dictionary[String, Dictionary] = {}

@export var enabled: bool = true
@export_file("*.tres")
var skeleton_data_path: String = "res://assets/spine/foxy_anim_spine/foxy_skeleton.tres"
@export var spine_animation: String = "G1_Idle"
@export var spine_skin: String = "G1"
@export var animation_mapping: Dictionary = {}
@export var artwork_faces_left: bool = true
## Scale the fitted Spine artwork without moving its feet from the sprite baseline.
@export_range(0.25, 3.0, 0.05, "or_greater") var size_multiplier: float = 1.0
## Share of the up/down dash clips' authored squash and stretch that is kept (1 = as animated,
## 0 = none). The clips stay untouched so a new artist export still converts as is.
@export_range(0.0, 1.0, 0.05) var vertical_dash_squash: float = 0.4

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
var _attack_spine_animation: String = ""
var _attack_spine_skin: String = ""
var _attack_duration: float = 0.0
var _dash_duration: float = 0.0
var _run_playback_speed: float = 1.0
var _hit_tint_strength: float = 0.0
var _run_bob_last_time: float = -1.0


func _ready() -> void:
	visible = false
	# Run after the Spine node has advanced its clip this frame (its bounds are current).
	process_priority = 100


func set_hit_tint(strength: float) -> void:
	_hit_tint_strength = clampf(strength, 0.0, 1.0)
	_update_hit_tint()


func _update_hit_tint() -> void:
	if not _is_spine_loaded():
		return
	_spine.get_skeleton().set_color(Color.WHITE.lerp(HIT_TINT_COLOR, _hit_tint_strength))


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
	_set_spine_paused(hitstop != null and hitstop.is_frozen(get_parent().get_parent()))
	if _hit_tint_strength > 0.0:
		_update_hit_tint()
	_stabilize_run_size()


func _stabilize_run_size() -> void:
	var factor: float = RUN_SIZE_MULTIPLIERS.get(_current_spine_animation, 1.0)
	if factor == 1.0:
		return
	# Centre and ground the enlarged clip on an anchor averaged over its first stride, then keep
	# it fixed. Re-anchoring on each frame's bounds slid the whole body with every arm swing.
	var anchor: Vector3 = _run_anchors.get(_current_spine_animation, Vector3(0.0, INF, 0.0))
	if anchor.z < RUN_ANCHOR_SAMPLES:
		var bounds: AABB = _spine_bounds()
		if bounds.size.x > 0.01 and bounds.size.y > 0.01:
			anchor.x += bounds.get_center().x
			anchor.y = minf(anchor.y, bounds.position.y)
			anchor.z += 1.0
			_run_anchors[_current_spine_animation] = anchor
	if anchor.z <= 0.0:
		return
	var pose := _spine.transform
	var mirrored := signf(pose.basis.x.x) != signf(_fitted_transform.basis.x.x)
	pose.basis.x = _fitted_transform.basis.x * (-factor if mirrored else factor)
	pose.basis.y = _fitted_transform.basis.y * factor
	pose.origin.x = _reference_bottom.x - pose.basis.x.x * anchor.x / anchor.z
	pose.origin.y = _reference_bottom.y - pose.basis.y.y * anchor.y
	_spine.transform = pose


## This export leaves a setup-pose eye attachment near the feet, and its clips can restore it
## every frame, so it is cleared after each pose update.
func _hide_stray_eye() -> void:
	if _is_spine_loaded():
		_clear_stray_eye(_spine)


func _clear_stray_eye(sprite: Node) -> void:
	var slot = sprite.get_skeleton().find_slot(STRAY_EYE_SLOT)
	if slot != null:
		slot.get_pose().set_attachment(null)
		slot.get_applied_pose().set_attachment(null)


func set_dagger_combo_index(index: int) -> void:
	_dagger_combo_index = clampi(index, -1, DAGGER_COMBO_ANIMATIONS.size() - 1)


func set_attack_spine_override(animation_name: String, skin_name: String) -> void:
	_attack_spine_animation = animation_name
	_attack_spine_skin = skin_name


func fit_attack_duration(duration: float) -> void:
	_attack_duration = duration
	_apply_attack_speed()


func reset_attack_speed() -> void:
	_attack_duration = 0.0
	_apply_attack_speed()


func fit_dash_duration(duration: float) -> void:
	_dash_duration = duration
	_apply_attack_speed()


func set_run_playback_speed(speed: float) -> void:
	_run_playback_speed = maxf(0.01, speed)
	_apply_attack_speed()


func _apply_attack_speed() -> void:
	if not is_instance_valid(_spine):
		return
	var window: float = ATTACK_PLAYBACK_WINDOWS.get(_current_spine_animation, 0.0)
	var playback_speed := 1.0
	if window > 0.0 and _attack_duration > 0.0:
		playback_speed = window / _attack_duration
	elif _current_spine_animation.ends_with("_Dash") and _dash_duration > 0.0:
		var skeleton_data = _spine.get("skeleton_data_res")
		var animation = skeleton_data.find_animation(_current_spine_animation)
		var clip_duration := (
			float(animation.get_duration()) if animation != null else DASH_CLIP_DURATION
		)
		# Leave a small margin so the clip cannot end before movement.
		playback_speed = clip_duration / (_dash_duration + 0.1)
	elif _current_spine_animation.ends_with("_Run"):
		playback_speed = _run_playback_speed
	_spine.set("time_scale", playback_speed)


## Stable idle dimensions in PlayerVisual space, shared by temporary cast artwork.
func get_reference_body_metrics() -> Vector2:
	var multiplier := size_multiplier if _active else 1.0
	return Vector2(
		absf(transform.basis.y.y) * _reference_height * multiplier,
		(transform * _reference_bottom).y
	)


## Dimensions of the fitted Spine artwork even while another action hides it.
func get_fitted_body_metrics() -> Vector2:
	return Vector2(
		absf(transform.basis.y.y) * _reference_height * size_multiplier,
		(transform * _reference_bottom).y
	)


func _mapping_key_for(animation_name: StringName, screen_facing: Vector3) -> String:
	var key := String(animation_name)
	if animation_name == &"idle_side":
		return "idle_down"
	if key.begins_with("dash_"):
		if screen_facing.z < -0.01:
			return "dash_up"
		if screen_facing.z > 0.01:
			return "dash_down"
		return "dash_side"
	if key.begins_with("run_") and absf(screen_facing.x) > 0.01 \
			and absf(screen_facing.z) > 0.01:
		return "run_side"
	return key


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
	var mapping_key := _mapping_key_for(animation_name, screen_facing)
	var mapping: Array = animation_mapping.get(mapping_key, [])
	if mapping.size() == 2:
		target_animation = str(mapping[0])
		target_skin = str(mapping[1])
		if String(animation_name).begins_with("attack_dagger_"):
			target_animation = (
				DAGGER_COMBO_ANIMATIONS[_dagger_combo_index]
				if _dagger_combo_index >= 0 else ""
			)
	elif animation_mapping.is_empty() and animation_name == &"idle_down":
		target_animation = spine_animation
	if String(animation_name).begins_with("attack_") and not _attack_spine_animation.is_empty():
		target_animation = _attack_spine_animation
		if not _attack_spine_skin.is_empty():
			target_skin = _attack_spine_skin
	var show_preview := enabled and not target_animation.is_empty()
	# One Spine node serves every clip: rebuilding it on each change drew a frame of the setup
	# pose (a visible flicker). _set_spine_skin returns the skeleton to its setup pose instead.
	if show_preview:
		show_preview = _ensure_spine()
	if show_preview and not _fit_ready:
		if not spine_skin.is_empty():
			show_preview = _set_spine_skin(spine_skin)
		if show_preview:
			show_preview = _play_spine(spine_animation, true)
		if show_preview:
			_fit_to_sprite()
			show_preview = _fit_ready
			_current_spine_animation = ""
	if show_preview and (
		not _active
		or restart
		or _current_spine_animation != target_animation
		or _current_spine_skin != target_skin
	):
		if not target_skin.is_empty():
			show_preview = _set_spine_skin(target_skin)
		if show_preview:
			var loop := not (String(animation_name).begins_with("attack_dagger_")
				or String(animation_name).begins_with("dash_"))
			_run_bob_last_time = -1.0
			show_preview = _play_spine(target_animation, loop)
		if show_preview:
			_current_spine_animation = target_animation
			_current_spine_skin = target_skin
	_active = show_preview
	visible = _active
	source.visible = source == active_sprite and not _active
	if not is_instance_valid(_spine):
		return
	if not _active:
		_set_spine_paused(true)
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


## Runs after the clip is applied and before bone world transforms are built.
func _on_spine_pose_applied(_sprite: Node) -> void:
	if RUN_BOB_BONES.has(_current_spine_animation):
		_even_out_run_bob(_current_spine_animation)
	elif VERTICAL_DASH_ROOT_BONES.has(_current_spine_animation):
		_soften_dash_squash(_current_spine_animation)


func _soften_dash_squash(animation_name: String) -> void:
	var bone = _spine.get_skeleton().find_bone(VERTICAL_DASH_ROOT_BONES[animation_name])
	if bone == null:
		return
	# The root's setup scale is 1, so blending toward 1 scales the authored squash down.
	var pose = bone.get_pose()
	pose.set_scale_x(lerpf(1.0, float(pose.get_scale_x()), vertical_dash_squash))
	pose.set_scale_y(lerpf(1.0, float(pose.get_scale_y()), vertical_dash_squash))


func _even_out_run_bob(animation_name: String) -> void:
	if not is_instance_valid(_spine):
		return
	var track = _spine.get_animation_state().get_track(0)
	if track == null:
		return
	var time := float(track.get_track_time())
	var step := time - _run_bob_last_time
	_run_bob_last_time = time
	var skeleton = _spine.get_skeleton()
	var hip = skeleton.find_bone(RUN_BOB_BONES[animation_name][0]).get_pose()
	var neck = skeleton.find_bone(RUN_BOB_BONES[animation_name][1]).get_pose()
	var stride := TAU * RUN_STRIDES_PER_CLIP / RUN_CLIP_SECONDS * time
	var fit: Dictionary = _run_bob_fits.get(
		animation_name, {"hip": 0.0, "neck": 0.0, "cos": 0.0, "sin": 0.0, "time": 0.0}
	)
	# Learn the authored averages and stride timing over the first play of the session.
	if float(fit.time) < RUN_CLIP_SECONDS and step > 0.0 and step < RUN_CLIP_SECONDS * 0.5:
		fit.hip += float(hip.get_y()) * step
		fit.neck += float(neck.get_y()) * step
		fit.cos += float(neck.get_y()) * cos(stride) * step
		fit.sin += float(neck.get_y()) * sin(stride) * step
		fit.time += step
		_run_bob_fits[animation_name] = fit
	if float(fit.time) <= 0.0:
		return
	hip.set_y(fit.hip / fit.time)
	neck.set_y(fit.neck / fit.time + RUN_BOB_AMPLITUDE * cos(stride - atan2(fit.sin, fit.cos)))


func _ensure_spine() -> bool:
	if is_instance_valid(_spine):
		return _is_spine_loaded()
	if _load_attempted:
		return false
	_load_attempted = true
	# Avoid a hard dependency on the extension: builds without it keep the sprite sheet.
	if not ClassDB.class_exists(SPINE_SPRITE_CLASS) or not ResourceLoader.exists(skeleton_data_path):
		return false
	_spine = ClassDB.instantiate(SPINE_SPRITE_CLASS) as Node3D
	add_child(_spine)
	_spine.set("shadow_casting", SPINE_SHADOW_DOUBLE_SIDED)
	var skeleton_data: Resource = _skeleton_data_cache.get(skeleton_data_path)
	if skeleton_data == null:
		skeleton_data = load(skeleton_data_path)
		_skeleton_data_cache[skeleton_data_path] = skeleton_data
	_spine.set("skeleton_data_res", skeleton_data)
	_set_spine_paused(true)
	if not _is_spine_loaded():
		return false
	_spine.world_transforms_changed.connect(_clear_stray_eye)
	_spine.before_world_transforms_change.connect(_on_spine_pose_applied)
	_add_slash_overlays()
	return true


## Skeleton bounds in the Spine node's space. Computed from the bones, so it also works while
## the preview is hidden (SpineSprite3D only measures what it has drawn).
func _spine_bounds() -> AABB:
	var rect: Rect2 = _spine.get_skeleton().get_bounds()
	var pixel_size: float = _spine.get("pixel_size")
	return AABB(
		Vector3(rect.position.x, -rect.end.y, 0.0) * pixel_size,
		Vector3(rect.size.x, rect.size.y, 0.0) * pixel_size
	)


func _is_spine_loaded() -> bool:
	return is_instance_valid(_spine) and _spine.get_skeleton() != null


func _set_spine_paused(paused: bool) -> void:
	if is_instance_valid(_spine):
		_spine.set("update_mode", SPINE_UPDATE_MANUAL if paused else SPINE_UPDATE_PROCESS)


func _set_spine_skin(skin_name: String) -> bool:
	var skeleton_data = _spine.get("skeleton_data_res")
	if skeleton_data == null or skeleton_data.find_skin(skin_name) == null:
		return false
	_prepare_skin(_spine.get_skeleton(), skin_name)
	return true


## Switches `skeleton` to `skin_name` in its setup pose.
func _prepare_skin(skeleton: Object, skin_name: String) -> void:
	skeleton.set_skin_by_name(skin_name)
	skeleton.set_to_setup_pose()
	# Some default-skin meshes are weighted to bones of other skins (Eyes/Eyes_08 to the side
	# skin's "bone"). Those bones are inactive and never updated, so they would keep the last
	# pose of the previous skin and draw the mesh floating there. A never-posed bone has a zero
	# matrix, which collapses such meshes out of sight, as a fresh 3.8 instance did.
	for bone in skeleton.get_bones():
		if not bone.is_active():
			var pose = bone.get_applied_pose()
			pose.set_a(0.0)
			pose.set_b(0.0)
			pose.set_c(0.0)
			pose.set_d(0.0)


## Starts `animation_name` and poses the skeleton on its first frame right away, so the next
## draw and any bounds read this frame already show the new clip.
func _play_spine(animation_name: String, loop: bool) -> bool:
	if _spine.get_animation_state().set_animation(animation_name, loop, 0) == null:
		return false
	_pose_spine_now()
	return true


## SpineSprite3D skips update_skeleton() while it is hidden (as during calibration), so the
## clip is applied and the world transforms rebuilt directly.
func _pose_spine_now() -> void:
	var skeleton = _spine.get_skeleton()
	_spine.get_animation_state().apply(skeleton)
	_hide_stray_eye()
	skeleton.update_world_transform(SPINE_PHYSICS_NONE)


## Draws the slash slots over the terrain, as the dagger trail did with SpineBridge: the trail
## lies in the sprite's tilted plane and would otherwise sink into the ground.
func _add_slash_overlays() -> void:
	var material := ShaderMaterial.new()
	material.shader = Shader.new()
	material.shader.code = SLASH_SHADER_HEAD + _spine.get_depth_shader_code() + SLASH_SHADER_BODY
	for slot in _spine.get_skeleton().get_slots():
		var slot_name: String = slot.get_data().get_name()
		if not slot_name.to_lower().contains("slash"):
			continue
		var overlay := ClassDB.instantiate(SPINE_SLOT_NODE_CLASS) as Node3D
		overlay.set("slot_name", slot_name)
		overlay.set("normal_material", material)
		_spine.add_child(overlay)


func _fit_to_sprite() -> void:
	# Calibrate once against the authored idle pose. Action clips can start compressed.
	_spine.transform = Transform3D.IDENTITY
	_pose_spine_now()
	var bounds: AABB = _spine_bounds()
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
