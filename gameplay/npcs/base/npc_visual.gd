class_name NpcVisual
extends Node3D

## Directional-animation adapter shared by non-hostile NPCs.
## NPC art is displayed in screen space, so animation direction is resolved against
## the active camera instead of the world's fixed axes.

@export var sprite: Sprite3D
@export var animation_player: AnimationPlayer

var _action: StringName = &""
var _facing: Vector3 = Vector3.BACK


func _process(_delta: float) -> void:
	if not _action.is_empty():
		_play_directional()


func set_facing(direction: Vector3) -> void:
	var horizontal := Vector3(direction.x, 0.0, direction.z)
	if not horizontal.is_zero_approx():
		_facing = horizontal.normalized()


func play_directional(action: StringName, direction: Vector3, restart: bool = false) -> bool:
	_action = action
	set_facing(direction)
	return _play_directional(restart)


func _play_directional(restart: bool = false) -> bool:
	if not is_instance_valid(animation_player):
		return false

	var screen_direction := _get_screen_direction()
	var suffix := "down"
	if absf(screen_direction.x) > absf(screen_direction.z):
		suffix = "right" if screen_direction.x > 0.0 else "left"
	elif screen_direction.z < 0.0:
		suffix = "up"

	var animation_name := StringName(String(_action) + "_" + suffix)
	if not animation_player.has_animation(animation_name):
		return false
	if animation_player.assigned_animation == animation_name and not restart:
		return true
	if restart:
		animation_player.stop()
	animation_player.play(animation_name)
	return true


func _get_screen_direction() -> Vector3:
	var camera := get_viewport().get_camera_3d()
	if not is_instance_valid(camera):
		return _facing
	var camera_right := camera.global_basis.x
	var camera_back := camera.global_basis.z
	camera_right.y = 0.0
	camera_back.y = 0.0
	return Vector3(
		_facing.dot(camera_right.normalized()), 0.0, _facing.dot(camera_back.normalized())
	)
