class_name EnemyVisual
extends Node3D

## Animation adapter for enemy scenes.
## Prefer directional clips named <action>_down, <action>_up, and <action>_side.
## Left/right clips are also supported as <action>_left and <action>_right.

signal animation_finished(animation_name: StringName)
signal death_feedback_finished

@export var sprite: Sprite3D
@export var animation_player: AnimationPlayer
@export var hit_flash_color: Color = Color(1.0, 0.45, 0.45, 1.0)
@export_range(0.01, 1.0, 0.01) var hit_flash_duration: float = 0.12
@export_range(1.0, 2.0, 0.01) var hit_pulse_scale: float = 1.12
@export_range(0.01, 2.0, 0.01) var death_fade_duration: float = 0.3

var _directional_action: StringName = &""
var _facing: Vector3 = Vector3.BACK
var _sprite_modulate: Color = Color.WHITE
var _sprite_scale: Vector3 = Vector3.ONE
var _hit_flash_tween: Tween
var _death_feedback_tween: Tween


func _ready() -> void:
	if is_instance_valid(sprite):
		_sprite_modulate = sprite.modulate
		_sprite_scale = sprite.scale
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
	sprite.modulate = hit_flash_color
	sprite.scale = _sprite_scale * hit_pulse_scale
	_hit_flash_tween = create_tween().set_parallel()
	_hit_flash_tween.tween_property(sprite, "modulate", _sprite_modulate, hit_flash_duration)
	_hit_flash_tween.tween_property(sprite, "scale", _sprite_scale, hit_flash_duration)


func play_death_feedback() -> bool:
	if not is_instance_valid(sprite):
		return false
	if _hit_flash_tween != null:
		_hit_flash_tween.kill()
	if _death_feedback_tween != null:
		_death_feedback_tween.kill()
	sprite.modulate = _sprite_modulate
	sprite.scale = _sprite_scale
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
	var suffix := "down"
	var flip_side := false
	if absf(_facing.x) > absf(_facing.z):
		var horizontal_suffix := "right" if _facing.x > 0.0 else "left"
		var horizontal_name := StringName(String(action) + "_" + horizontal_suffix)
		if animation_player.has_animation(horizontal_name):
			return horizontal_name
		suffix = "side"
		flip_side = _facing.x < 0.0
	elif _facing.z < 0.0:
		suffix = "up"

	if is_instance_valid(sprite):
		sprite.flip_h = flip_side
	var animation_name := StringName(String(action) + "_" + suffix)
	if animation_player.has_animation(animation_name):
		return animation_name
	return &""


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
