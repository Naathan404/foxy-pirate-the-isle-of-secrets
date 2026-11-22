class_name CharmCastClip
extends Resource
## Sprite-sheet timing and foot pivots, independent of skill damage and collision.

@export var charm_id: StringName
@export var texture: Texture2D
## Two complete sequences stacked vertically: back view above front view.
@export var vertical_texture: Texture2D
@export var grid: Vector2i = Vector2i(4, 2)
@export var frame_seconds: PackedFloat32Array = PackedFloat32Array(
	[0.035, 0.045, 0.04, 0.065, 0.055, 0.055, 0.05, 0.045]
)
@export var foot_anchors: PackedVector2Array = PackedVector2Array(
	[
		Vector2(0.5, 0.9),
		Vector2(0.5, 0.9),
		Vector2(0.5, 0.9),
		Vector2(0.5, 0.9),
		Vector2(0.5, 0.9),
		Vector2(0.5, 0.9),
		Vector2(0.5, 0.9),
		Vector2(0.5, 0.9)
	]
)
@export_range(0.1, 1.0, 0.01) var standing_height_fraction: float = 0.74
@export var cast_frames: PackedInt32Array = PackedInt32Array([0, 1, 2, 3, 4, 5, 6, 7])
@export var channel_loop_frames: PackedInt32Array = PackedInt32Array()
## These phases keep their last pose until the effect advances or cancels the cast.
@export var held_phases: Array[StringName] = []
@export var release_frames: PackedInt32Array = PackedInt32Array()
@export var recall_frames: PackedInt32Array = PackedInt32Array()
## Optional crop windows exclude stray pixels from neighbouring generated cells.
@export var frame_regions: Array[Rect2] = []
@export var phase_frames: Dictionary[StringName, PackedInt32Array] = {}
@export var looping_phases: Array[StringName] = []


func is_valid() -> bool:
	if charm_id.is_empty() or texture == null or vertical_texture == null:
		return false
	if grid.x <= 0 or grid.y <= 0:
		return false
	var count := grid.x * grid.y
	if frame_seconds.size() != count or foot_anchors.size() != count or cast_frames.is_empty():
		return false
	if not frame_regions.is_empty() and frame_regions.size() != count:
		return false
	for seconds: float in frame_seconds:
		if not is_finite(seconds) or seconds <= 0.0:
			return false
	for sequence: PackedInt32Array in (
		[cast_frames, channel_loop_frames, release_frames, recall_frames] + phase_frames.values()
	):
		for frame_index: int in sequence:
			if frame_index < 0 or frame_index >= count:
				return false
	for phase in held_phases:
		if (
			get_sequence(phase).is_empty()
			or phase in looping_phases
			or (phase == &"channel" and not channel_loop_frames.is_empty())
		):
			return false
	return true


func get_sequence(phase: StringName) -> PackedInt32Array:
	if phase_frames.has(phase):
		return phase_frames[phase]
	match phase:
		&"cast", &"channel":
			return cast_frames
		&"release":
			return release_frames
		&"recall":
			return recall_frames
	return PackedInt32Array()


func get_sequence_seconds(sequence: PackedInt32Array) -> float:
	var seconds := 0.0
	for frame_index: int in sequence:
		seconds += frame_seconds[frame_index]
	return seconds
