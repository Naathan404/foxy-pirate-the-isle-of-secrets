class_name CharmCastAnimator
extends Node3D
## Plays generated Foxy + VFX frames without changing combat state or activation timing.

signal finished

@export var actor: Node3D
@export var clips: Array[CharmCastClip] = []
@export_range(0.5, 6.0, 0.05) var body_height_units: float = 3.0

var _catalog: Dictionary[StringName, CharmCastClip] = {}
var _clip: CharmCastClip
var _sequence: PackedInt32Array
var _sequence_index: int = 0
var _frame_elapsed: float = 0.0
var _loop_sequence: PackedInt32Array
var _playback_rate: float = 1.0
var _material: ShaderMaterial

@onready var _sprite: Sprite3D = $Sprite3D


func _ready() -> void:
	_material = _sprite.material_override.duplicate() as ShaderMaterial
	_sprite.material_override = _material
	for clip: CharmCastClip in clips:
		if clip == null or not clip.is_valid() or _catalog.has(clip.charm_id):
			push_error("CharmCastAnimator: invalid or duplicate clip")
			continue
		_catalog[clip.charm_id] = clip
	_sprite.hide()
	set_process(false)


func play(
	charm_id: StringName, phase: StringName, direction: Vector3, duration_seconds: float = 0.0
) -> bool:
	var clip := _catalog.get(charm_id) as CharmCastClip
	if clip == null:
		return false
	var sequence := clip.get_sequence(phase)
	if sequence.is_empty():
		return false
	_clip = clip
	_sequence = sequence
	_sequence_index = 0
	_frame_elapsed = 0.0
	_loop_sequence = PackedInt32Array()
	if phase == &"channel":
		_loop_sequence = clip.channel_loop_frames
	elif phase in clip.looping_phases:
		_loop_sequence = sequence
	_playback_rate = (
		clip.get_sequence_seconds(sequence) / duration_seconds if duration_seconds > 0.0 else 1.0
	)
	_sprite.texture = clip.texture
	_sprite.hframes = clip.grid.x
	_sprite.vframes = clip.grid.y
	_sprite.pixel_size = (
		body_height_units
		/ (float(clip.texture.get_height()) / clip.grid.y * clip.standing_height_fraction)
	)
	_material.set_shader_parameter("atlas_texture", clip.texture)
	_material.set_shader_parameter("grid", Vector2(clip.grid))
	var camera := get_viewport().get_camera_3d()
	if is_instance_valid(camera):
		var horizontal := direction.dot(camera.global_basis.x)
		if not is_zero_approx(horizontal):
			_sprite.flip_h = horizontal < 0.0
	_update_frame()
	_face_camera()
	_sprite.show()
	set_process(true)
	return true


func stop(charm_id: StringName = &"") -> void:
	if _clip == null or (not charm_id.is_empty() and _clip.charm_id != charm_id):
		return
	_clip = null
	_loop_sequence = PackedInt32Array()
	_sprite.hide()
	set_process(false)
	finished.emit()


func is_playing() -> bool:
	return _clip != null


func is_playing_charm(charm_id: StringName) -> bool:
	return _clip != null and _clip.charm_id == charm_id


func _process(delta: float) -> void:
	if is_instance_valid(actor) and bool(actor.get("dead")):
		stop()
		return
	_face_camera()
	if get_node("/root/HitstopController").is_frozen(actor):
		return
	_frame_elapsed += maxf(0.0, delta) * _playback_rate
	while _clip != null and _frame_elapsed >= _clip.frame_seconds[_sequence[_sequence_index]]:
		_frame_elapsed -= _clip.frame_seconds[_sequence[_sequence_index]]
		_sequence_index += 1
		if _sequence_index >= _sequence.size():
			if _loop_sequence.is_empty():
				stop()
				return
			_sequence = _loop_sequence
			_sequence_index = 0
		_update_frame()


func _update_frame() -> void:
	var frame_index := _sequence[_sequence_index]
	_sprite.frame = frame_index
	var region := Rect2(0.0, 0.0, 1.0, 1.0)
	if not _clip.frame_regions.is_empty():
		region = _clip.frame_regions[frame_index]
	_material.set_shader_parameter(
		"frame_region", Vector4(region.position.x, region.position.y, region.end.x, region.end.y)
	)
	var anchor := _clip.foot_anchors[frame_index]
	var frame_size := Vector2(_clip.texture.get_size()) / Vector2(_clip.grid)
	var horizontal_offset := (0.5 - anchor.x) * frame_size.x
	_sprite.offset = Vector2(
		-horizontal_offset if _sprite.flip_h else horizontal_offset, (anchor.y - 0.5) * frame_size.y
	)


func _face_camera() -> void:
	var camera := get_viewport().get_camera_3d()
	if not is_instance_valid(camera):
		return
	var visual_root := get_parent() as Node3D
	var toward_camera := visual_root.global_basis.inverse() * camera.global_basis.z
	rotation.y = atan2(toward_camera.x, toward_camera.z)
