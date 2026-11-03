extends Node
## A visual-only kick, owned by the sprite so projectile deletion cannot interrupt recovery.

const FLASH_SHADER: Shader = preload("res://gameplay/weapons/dagger_hit_flash.gdshader")

@export_group("Hit Flash")
@export_range(0.0, 0.3, 0.005) var flash_hold_seconds: float = 0.035
@export_range(0.01, 0.3, 0.005) var flash_fade_seconds: float = 0.09

var _sprite: Sprite3D
var _rest_position: Vector3
var _pose_tween: Tween
var _flash_tween: Tween
var _flash_material: ShaderMaterial
var _previous_overlay: Material


func _ready() -> void:
	_sprite = get_parent() as Sprite3D
	_rest_position = _sprite.position
	set_process(false)


func kick(direction: Vector3, distance: float, flash: bool = false, strength: float = 1.0) -> void:
	if _pose_tween != null and _pose_tween.is_valid():
		_pose_tween.kill()
	var parent := _sprite.get_parent() as Node3D
	var local_direction := parent.global_basis.inverse() * direction.normalized()
	_sprite.position = _rest_position + local_direction * distance
	_pose_tween = create_tween()
	_pose_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_pose_tween.tween_property(_sprite, "position", _rest_position, 0.18)
	if flash:
		_play_flash(strength)


func _play_flash(strength: float) -> void:
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	if _flash_material == null:
		_flash_material = ShaderMaterial.new()
		_flash_material.shader = FLASH_SHADER
		_flash_material.render_priority = 2
	if _sprite.material_overlay != _flash_material:
		_previous_overlay = _sprite.material_overlay
	_sprite.material_overlay = _flash_material
	_flash_material.set_shader_parameter("sprite_texture", _sprite.texture)
	_flash_material.set_shader_parameter("strength", clampf(strength, 0.0, 1.0))
	set_process(true)
	_flash_tween = create_tween().set_ignore_time_scale(true)
	_flash_tween.tween_interval(flash_hold_seconds * strength)
	_flash_tween.tween_property(
		_flash_material, "shader_parameter/strength", 0.0, flash_fade_seconds * strength
	)
	_flash_tween.tween_callback(_restore_overlay)


func _process(_delta: float) -> void:
	# Directional animations can change atlas textures during the flash.
	_flash_material.set_shader_parameter("sprite_texture", _sprite.texture)


func _restore_overlay() -> void:
	if is_instance_valid(_sprite) and _sprite.material_overlay == _flash_material:
		_sprite.material_overlay = _previous_overlay
	set_process(false)


func _exit_tree() -> void:
	_restore_overlay()
	if is_instance_valid(_sprite):
		_sprite.position = _rest_position
