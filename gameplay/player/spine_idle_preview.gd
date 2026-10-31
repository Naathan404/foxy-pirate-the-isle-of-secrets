extends Node3D
## Optional idle-down experiment; gameplay continues to use PlayerVisual's animation clock.

@export var enabled: bool = true
@export_file("*.tres")
var skeleton_data_path: String = "res://assets/spine/compat/foxy_skeleton.tres"
@export var spine_animation: String = "animation"

var _spine: Node3D
var _load_attempted: bool = false
var _active: bool = false
var _fitted_transform: Transform3D = Transform3D.IDENTITY
var _reference_height: float = 0.0
var _reference_bottom: Vector3 = Vector3.ZERO
var _fit_ready: bool = false


func _ready() -> void:
	visible = false


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
	var frame_size := Vector2i(image.get_size()) / Vector2i(source.hframes, source.vframes)
	var coords := Vector2i(frame % source.hframes, frame / source.hframes)
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


func sync_animation(
	animation_name: StringName,
	source: Sprite3D,
	active_sprite: Sprite3D,
	camera: Camera3D,
	facing_left: bool
) -> void:
	var show_preview := enabled and animation_name == &"idle_down"
	if show_preview:
		show_preview = _ensure_spine()
	if show_preview and not _active:
		if not _fit_ready:
			_fit_to_sprite()
		show_preview = _fit_ready and bool(_spine.set_animation(spine_animation, true, 0))
	_active = show_preview
	visible = _active
	source.visible = source == active_sprite and not _active
	if not is_instance_valid(_spine):
		return
	if not _active:
		_spine.pause()
		return
	# This artwork faces left. Mirror its fitted offset along with its geometry.
	var facing_transform := _fitted_transform
	if not facing_left:
		facing_transform.basis.x *= -1.0
		facing_transform.origin.x = 2.0 * _reference_bottom.x - _fitted_transform.origin.x
	_spine.transform = facing_transform
	var active_camera := camera
	if not is_instance_valid(active_camera):
		active_camera = get_viewport().get_camera_3d()
	if is_instance_valid(active_camera):
		var direction: Vector3 = get_parent().to_local(active_camera.global_position) - position
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
	_spine.set("skeleton_data_res", load(skeleton_data_path))
	_spine.pause()
	return _spine.is_loaded()


func _fit_to_sprite() -> void:
	# Calibrate once against the initial skeleton bounds, never against a paused animated pose.
	_spine.transform = Transform3D.IDENTITY
	_spine.update_skeleton(0.0)
	var bounds: AABB = _spine.get_aabb()
	if bounds.size.y <= 0.0 or _reference_height <= 0.0:
		return
	var factor := _reference_height / bounds.size.y
	_spine.scale = Vector3.ONE * factor
	_spine.position = (
		Vector3(-bounds.get_center().x * factor, -bounds.position.y * factor, 0.0)
		+ _reference_bottom
	)
	_fitted_transform = _spine.transform
	_fit_ready = true
