class_name EnemyVisual
extends Node3D

## Animation adapter for enemy scenes.
## Prefer directional clips named <action>_down, <action>_up, and <action>_side.
## Left/right clips are also supported as <action>_left and <action>_right.

signal animation_finished(animation_name: StringName)
signal death_feedback_finished

@export var sprite: Sprite3D
@export var animation_player: AnimationPlayer
@export_group("Hit Feedback")
@export var hit_flash_color: Color = Color(2.0, 1.4, 1.2, 1.0)
@export_range(0.01, 1.0, 0.01) var hit_flash_duration: float = 0.16
@export_range(1.0, 2.0, 0.01) var hit_pulse_scale: float = 1.18
@export_range(0.1, 1.0, 0.01) var hit_squash_scale: float = 0.78
@export_range(0.01, 1.0, 0.01) var hit_rebound_duration: float = 0.1
@export_range(0.01, 1.0, 0.01) var hit_settle_duration: float = 0.12
@export_group("Death Feedback")
@export_range(0.01, 2.0, 0.01) var death_fade_duration: float = 0.3

var _directional_action: StringName = &""
var _facing: Vector3 = Vector3.BACK
var _sprite_modulate: Color = Color.WHITE
var _sprite_scale: Vector3 = Vector3.ONE
var _sprite_shaded: bool = true
var _hit_flash_tween: Tween
var _hit_pose_tween: Tween
var _death_feedback_tween: Tween


func _ready() -> void:
	if is_instance_valid(sprite):
		_sprite_modulate = sprite.modulate
		_sprite_scale = sprite.scale
		_sprite_shaded = sprite.shaded
	if is_instance_valid(animation_player):
		animation_player.animation_finished.connect(_on_animation_finished)


func _process(_delta: float) -> void:
	if not _directional_action.is_empty():
		_play_directional()


func set_facing(direction: Vector3) -> void:
	var horizontal := Vector3(direction.x, 0.0, direction.z)
	if not horizontal.is_zero_approx():
		_facing = horizontal.normalized()


## Plays an exact clip name, for example "spawn" or "explode".
func play_animation(animation_name: StringName, restart: bool = false) -> bool:
	_directional_action = &""
	return _play(animation_name, restart)


## Plays the direction-specific variant, or falls back to an exact action clip.
func play_directional(action: StringName, direction: Vector3, restart: bool = false) -> bool:
	_directional_action = action
	set_facing(direction)
	return _play_directional(restart)


func has_animation(animation_name: StringName) -> bool:
	return is_instance_valid(animation_player) and animation_player.has_animation(animation_name)


func play_hit_feedback() -> void:
	if not is_instance_valid(sprite):
		return
	if _hit_flash_tween != null:
		_hit_flash_tween.kill()
	if _hit_pose_tween != null:
		_hit_pose_tween.kill()
	sprite.shaded = false
	sprite.modulate = Color(hit_flash_color, _sprite_modulate.a)
	sprite.scale = _sprite_scale * Vector3(hit_pulse_scale, hit_squash_scale, 1.0)
	_hit_flash_tween = create_tween().set_ignore_time_scale(true)
	_hit_flash_tween.tween_property(sprite, "modulate", _sprite_modulate, hit_flash_duration)
	_hit_flash_tween.tween_callback(_restore_sprite_shading)
	_hit_pose_tween = create_tween().set_ignore_time_scale(true)
	_hit_pose_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_hit_pose_tween.tween_property(
		sprite, "scale", _sprite_scale * Vector3(hit_squash_scale, hit_pulse_scale, 1.0),
		hit_rebound_duration
	)
	_hit_pose_tween.tween_property(sprite, "scale", _sprite_scale, hit_settle_duration)


func play_death_feedback() -> bool:
	if not is_instance_valid(sprite):
		return false
	if _hit_flash_tween != null:
		_hit_flash_tween.kill()
	if _hit_pose_tween != null:
		_hit_pose_tween.kill()
	if _death_feedback_tween != null:
		_death_feedback_tween.kill()
	sprite.modulate = _sprite_modulate
	sprite.scale = _sprite_scale
	_restore_sprite_shading()
	_death_feedback_tween = create_tween().set_parallel()
	_death_feedback_tween.tween_property(sprite, "modulate:a", 0.0, death_fade_duration)
	_death_feedback_tween.tween_property(sprite, "scale", _sprite_scale * 0.25, death_fade_duration)
	_death_feedback_tween.finished.connect(_on_death_feedback_finished, CONNECT_ONE_SHOT)
	return true


func _play_directional(restart: bool = false) -> bool:
	var animation_name := _get_directional_animation_name(_directional_action)
	if animation_name.is_empty():
		return _play(_directional_action, restart)
	return _play(animation_name, restart)


func _get_directional_animation_name(action: StringName) -> StringName:
	if not is_instance_valid(animation_player):
		return &""
	var screen_direction := _get_screen_direction()
	var suffix := "down"
	var flip_side := false
	if absf(screen_direction.x) > absf(screen_direction.z):
		var horizontal_suffix := "right" if screen_direction.x > 0.0 else "left"
		var horizontal_name := StringName(String(action) + "_" + horizontal_suffix)
		if animation_player.has_animation(horizontal_name):
			# Horizontal clips own Sprite3D.flip_h in their Animation tracks.
			# Do not reset it here: this method runs every frame and would overwrite
			# the left clip's flip_h=true after AnimationPlayer applies the track.
			return horizontal_name
		suffix = "side"
		flip_side = screen_direction.x < 0.0
	elif screen_direction.z < 0.0:
		suffix = "up"

	if is_instance_valid(sprite):
		sprite.flip_h = flip_side
	var animation_name := StringName(String(action) + "_" + suffix)
	if animation_player.has_animation(animation_name):
		return animation_name
	return &""


## Chọn clip theo hướng trên màn hình, độc lập với hướng vật lý của enemy.
func _get_screen_direction() -> Vector3:
	var camera := get_viewport().get_camera_3d()
	if not is_instance_valid(camera):
		return _facing
	var camera_right: Vector3 = camera.global_basis.x
	var camera_back: Vector3 = camera.global_basis.z
	camera_right.y = 0.0
	camera_back.y = 0.0
	return Vector3(
		_facing.dot(camera_right.normalized()), 0.0, _facing.dot(camera_back.normalized())
	)


func _play(animation_name: StringName, restart: bool) -> bool:
	if not has_animation(animation_name):
		return false
	if animation_player.assigned_animation == animation_name and not restart:
		return true
	if restart:
		animation_player.stop()
	animation_player.play(animation_name)
	return true


func _on_animation_finished(animation_name: StringName) -> void:
	animation_finished.emit(animation_name)


func _on_death_feedback_finished() -> void:
	death_feedback_finished.emit()


func _restore_sprite_shading() -> void:
	if is_instance_valid(sprite):
		sprite.shaded = _sprite_shaded
