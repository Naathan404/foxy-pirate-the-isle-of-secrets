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


func _ready() -> void:
	visible = false


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
		_fit_to_sprite(source)
		show_preview = bool(_spine.set_animation(spine_animation, true, 0))
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
		facing_transform.origin.x = 2.0 * source.position.x - _fitted_transform.origin.x
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
	_spine.set("shadow_casting", 2) # Double Sided
	_spine.set("skeleton_data_res", load(skeleton_data_path))
	_spine.pause()
	return _spine.is_loaded()


func _fit_to_sprite(source: Sprite3D) -> void:
	# Restore a positive scale before recalculating bounds after a mirrored idle.
	_spine.transform = Transform3D.IDENTITY
	_spine.update_skeleton(0.0)
	var bounds: AABB = _spine.get_aabb()
	if bounds.size.y <= 0.0:
		return
	var image := source.texture.get_image()
	var frame_size := Vector2i(image.get_size()) / Vector2i(source.hframes, source.vframes)
	var frame_rect := Rect2i(source.frame_coords * frame_size, frame_size)
	var used := image.get_region(frame_rect).get_used_rect()
	if not used.has_area():
		used = Rect2i(Vector2i.ZERO, frame_size)
	var target_height := float(used.size.y) * source.pixel_size * source.scale.y
	var factor := target_height / bounds.size.y
	_spine.scale = Vector3.ONE * factor
	var target_bottom := (
		(float(frame_size.y) / 2.0 + source.offset.y - float(used.end.y))
		* source.pixel_size
		* source.scale.y
	)
	_spine.position = (
		Vector3(-bounds.get_center().x * factor, target_bottom - bounds.position.y * factor, 0.0)
		+ source.position
	)
	_fitted_transform = _spine.transform
