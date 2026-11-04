class_name BoundedFollowCamera3D
extends Camera3D

var _follow_offset: Vector3
var _bounds: CameraBounds3D
var _dialogue_override := false


func _ready() -> void:
	_follow_offset = position
	process_priority = 100
	var player := get_parent()
	if is_instance_valid(player) and is_instance_valid(player.get_parent()):
		_bounds = player.get_parent().get_node_or_null("CameraBounds") as CameraBounds3D


func _process(_delta: float) -> void:
	if not _dialogue_override:
		# A boundary clamp changes a child camera's local position. Rebuild the
		# desired follow offset each frame so it follows when Foxy moves back.
		position = _follow_offset
	set_bounded_global_position(global_position)


func begin_dialogue_override() -> void:
	_dialogue_override = true


func end_dialogue_override() -> void:
	_dialogue_override = false
	position = _follow_offset
	set_bounded_global_position(global_position)


func set_bounded_global_position(desired_position: Vector3) -> void:
	if is_instance_valid(_bounds):
		global_position = _bounds.clamp_camera_position(self, desired_position)
	else:
		global_position = desired_position
