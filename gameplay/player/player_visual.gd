class_name PlayerVisual
extends Node3D

signal animation_finished(animation_name: StringName)

@export var sprite: Sprite3D
@export var animation_player: AnimationPlayer

var _action: StringName = &""
var _facing: Vector3 = Vector3.BACK
var _camera: Camera3D


func _ready() -> void:
	if is_instance_valid(animation_player):
		animation_player.animation_finished.connect(_on_animation_finished)


func _process(_delta: float) -> void:
	if not _action.is_empty():
		_update_directional_animation()


func has_directional_animation(action: StringName) -> bool:
	if not is_instance_valid(animation_player):
		return false
	for suffix in ["down", "up", "side"]:
		if not animation_player.has_animation(String(action) + "_" + suffix):
			return false
	return true


func has_attack_animation(action: StringName) -> bool:
	if not has_directional_animation(action) or animation_player.speed_scale <= 0.0:
		return false
	for suffix in ["down", "up", "side"]:
		var animation := animation_player.get_animation(String(action) + "_" + suffix)
		if (
			animation.loop_mode != Animation.LOOP_NONE
			or animation.length <= 0.0
			or animation.get_track_count() == 0
		):
			return false
	return true


func play_animation(animation_name: StringName, restart: bool = false) -> bool:
	_action = &""
	return _play(animation_name, restart)


func play_directional(
	action: StringName, facing: Vector3, camera: Camera3D = null, restart: bool = false
) -> bool:
	_action = action
	if not facing.is_zero_approx():
		_facing = facing
	_camera = camera
	return _update_directional_animation(restart)


func _update_directional_animation(restart: bool = false) -> bool:
	var facing = _facing
	var camera = _camera if is_instance_valid(_camera) else get_viewport().get_camera_3d()
	if is_instance_valid(camera):
		var right = camera.global_basis.x
		var back = camera.global_basis.z
		right.y = 0.0
		back.y = 0.0
		facing = Vector3(_facing.dot(right.normalized()), 0.0, _facing.dot(back.normalized()))
	var suffix := "side" if absf(facing.x) > absf(facing.z) else "down"
	if suffix != "side" and facing.z < 0.0:
		suffix = "up"
	if not _play(String(_action) + "_" + suffix, restart):
		return false
	if is_instance_valid(sprite):
		sprite.flip_h = suffix == "side" and facing.x < 0.0
	return true


func _play(animation_name: StringName, restart: bool) -> bool:
	if (
		not is_instance_valid(animation_player)
		or not animation_player.has_animation(animation_name)
	):
		return false
	if restart or animation_player.assigned_animation != animation_name:
		if restart:
			animation_player.stop()
		animation_player.play(animation_name)
	return true


func _on_animation_finished(animation_name: StringName) -> void:
	animation_finished.emit(animation_name)
