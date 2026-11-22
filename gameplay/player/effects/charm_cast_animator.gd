class_name CharmCastAnimator
extends Node3D
## Plays generated Foxy + VFX frames without changing combat state or activation timing.

signal finished

enum View { SIDE, BACK, FRONT }

const VERTICAL_FOOT := Vector2(0.5, 0.9)
const VERTICAL_BODY_FRACTION := 0.72

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
var _cast_direction: Vector3
var _view: View

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
	_cast_direction = direction
	_update_view(true)
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
	_update_view()
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
	var vertical := _view != View.SIDE
	var front_offset := _clip.grid.x * _clip.grid.y if _view == View.FRONT else 0
	_sprite.frame = frame_index + front_offset
	var region := Rect2(0.0, 0.0, 1.0, 1.0)
	if not vertical and not _clip.frame_regions.is_empty():
		region = _clip.frame_regions[frame_index]
	_material.set_shader_parameter(
		"frame_region", Vector4(region.position.x, region.position.y, region.end.x, region.end.y)
	)
	var anchor := VERTICAL_FOOT if vertical else _clip.foot_anchors[frame_index]
	var frame_size := _sprite.texture.get_size() / Vector2(_sprite.hframes, _sprite.vframes)
	var horizontal_offset := (0.5 - anchor.x) * frame_size.x
	_sprite.offset = Vector2(
		-horizontal_offset if _sprite.flip_h else horizontal_offset, (anchor.y - 0.5) * frame_size.y
	)


func _update_view(force: bool = false) -> void:
	var camera := get_viewport().get_camera_3d()
	var screen_direction := _cast_direction
	if is_instance_valid(camera):
		var visual_root := get_parent() as Node3D
		var toward_camera := visual_root.global_basis.inverse() * camera.global_basis.z
		rotation.y = atan2(toward_camera.x, toward_camera.z)
		var right := camera.global_basis.x.slide(Vector3.UP).normalized()
		var back := camera.global_basis.z.slide(Vector3.UP).normalized()
		screen_direction = Vector3(_cast_direction.dot(right), 0.0, _cast_direction.dot(back))
	var view := View.SIDE
	if absf(screen_direction.z) >= absf(screen_direction.x):
		view = View.BACK if screen_direction.z < 0.0 else View.FRONT
	var flip := view == View.SIDE and screen_direction.x < 0.0
	if not force and view == _view and flip == _sprite.flip_h:
		return
	_view = view
	_sprite.flip_h = flip
	var vertical := view != View.SIDE
	var sheet := _clip.vertical_texture if vertical else _clip.texture
	var grid := Vector2i(_clip.grid.x, _clip.grid.y * 2) if vertical else _clip.grid
	var height := VERTICAL_BODY_FRACTION if vertical else _clip.standing_height_fraction
	_sprite.texture = sheet
	_sprite.hframes = grid.x
	_sprite.vframes = grid.y
	_sprite.pixel_size = body_height_units / (float(sheet.get_height()) / grid.y * height)
	_material.set_shader_parameter("atlas_texture", sheet)
	_material.set_shader_parameter("grid", Vector2(grid))
	_update_frame()
