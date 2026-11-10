class_name PushableCrate
extends CharacterBody3D
## A controlled puzzle prop: one movement request per physics tick, no accumulated impulse.

const DUST_SCENE: PackedScene = preload("res://gameplay/player/effects/run_dust_effect.tscn")

@export_range(0.1, 10.0, 0.1) var push_speed: float = 2.0
@export var push_enabled: bool = true
@export_group("Knockback")
@export_range(0.1, 15.0, 0.1) var knockback_speed: float = 6.0
@export_range(0.1, 3.0, 0.1) var maximum_knockback_distance: float = 1.5

@export_group("Weapon Impact Feedback")
@export var impact_sound: AudioStream = preload("res://assets/audio/world/crate_lever.wav")
@export_range(-30.0, 0.0, 1.0) var impact_volume_db: float = -12.0
@export_range(0.0, 0.2, 0.01) var impact_recoil: float = 0.08
@export_range(0.0, 0.3, 0.01) var impact_squash: float = 0.12
@export_range(0.0, 4.0, 0.1) var impact_shake_pixels: float = 1.2


var _push_direction: Vector3 = Vector3.ZERO
var _requested_speed: float = 0.0
var _knockback_direction: Vector3 = Vector3.ZERO
var _knockback_remaining: float = 0.0
var _reset_transform: Transform3D
var _initial_settled: bool = false
var _reset_tween: Tween
var _impact_tween: Tween
var _impact_dust: GPUParticles3D

@onready var _ground_snap_length: float = floor_snap_length
@onready var _visual: MeshInstance3D = $MeshInstance3D
@onready var _visual_scale: Vector3 = _visual.scale
@onready var _visual_position: Vector3 = _visual.position


func _ready() -> void:
	_reset_transform = global_transform
	_create_impact_dust()


func get_reset_transform() -> Transform3D:
	return _reset_transform


func reset_to_start() -> void:
	_push_direction = Vector3.ZERO
	_requested_speed = 0.0
	_knockback_remaining = 0.0
	velocity = Vector3.ZERO
	floor_snap_length = _ground_snap_length
	global_transform = _reset_transform
	reset_physics_interpolation()
	if _reset_tween != null and _reset_tween.is_valid():
		_reset_tween.kill()
	if _impact_tween != null and _impact_tween.is_valid():
		_impact_tween.kill()
	_visual.position = _visual_position
	_visual.scale = Vector3.ONE * 0.001
	_reset_tween = create_tween()
	_reset_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_reset_tween.tween_property(_visual, "scale", _visual_scale, 0.22)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PAUSED:
		_push_direction = Vector3.ZERO
		_knockback_remaining = 0.0


func request_push(direction: Vector3, speed_limit: float = -1.0) -> bool:
	if not _can_be_pushed():
		return false
	var horizontal := Vector3(direction.x, 0.0, direction.z)
	if horizontal.is_zero_approx():
		return false
	_push_direction = horizontal.normalized()
	_requested_speed = push_speed if speed_limit < 0.0 else minf(push_speed, maxf(0.0, speed_limit))
	return true


func request_knockback(direction: Vector3, distance: float) -> bool:
	if not _can_be_pushed() or not is_finite(distance) or distance <= 0.0:
		return false
	var horizontal := Vector3(direction.x, 0.0, direction.z)
	if horizontal.is_zero_approx():
		return false
	_knockback_direction = horizontal.normalized()
	_knockback_remaining = minf(distance, maximum_knockback_distance)
	return true


func play_weapon_impact_feedback(direction: Vector3) -> void:
	var horizontal := Vector3(direction.x, 0.0, direction.z).normalized()
	if _impact_tween != null and _impact_tween.is_valid():
		_impact_tween.kill()
	if _reset_tween != null and _reset_tween.is_valid():
		_reset_tween.kill()
	var local_direction := global_basis.inverse() * horizontal
	_visual.position = _visual_position + local_direction * impact_recoil
	_visual.scale = _visual_scale * Vector3(
		1.0 + impact_squash, 1.0 - impact_squash, 1.0 + impact_squash
	)
	_impact_tween = create_tween().set_parallel().set_ignore_time_scale(true)
	_impact_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_impact_tween.tween_property(_visual, "position", _visual_position, 0.18)
	_impact_tween.tween_property(_visual, "scale", _visual_scale, 0.18)
	if is_instance_valid(_impact_dust):
		_impact_dust.global_position = global_position - horizontal * 0.65 + Vector3.UP * 0.12
		var material := _impact_dust.process_material as ParticleProcessMaterial
		material.direction = (
			_impact_dust.global_basis.inverse() * (horizontal + Vector3.UP * 0.5).normalized()
		)
		_impact_dust.restart()
		_impact_dust.emitting = true
	get_node("/root/AudioManager").play_sfx_3d(impact_sound, global_position, impact_volume_db, 0.8)
	get_node("/root/ScreenShakeController").request(impact_shake_pixels, 0.09)


func _create_impact_dust() -> void:
	var source := DUST_SCENE.instantiate()
	_impact_dust = source.get_node("Particle").duplicate() as GPUParticles3D
	source.free()
	_impact_dust.process_material = _impact_dust.process_material.duplicate()
	_impact_dust.one_shot = true
	_impact_dust.explosiveness = 1.0
	_impact_dust.amount = 10
	_impact_dust.amount_ratio = 1.0
	_impact_dust.lifetime = 0.28
	_impact_dust.local_coords = false
	_impact_dust.emitting = false
	add_child(_impact_dust)
	_impact_dust.top_level = true


func _physics_process(delta: float) -> void:
	var direction := _push_direction if _can_be_pushed() else Vector3.ZERO
	_push_direction = Vector3.ZERO
	var horizontal_speed := _requested_speed
	if _knockback_remaining > 0.0:
		if _can_be_pushed() and delta > 0.0:
			direction = _knockback_direction
			var step := minf(_knockback_remaining, knockback_speed * delta)
			horizontal_speed = step / delta
			_knockback_remaining -= step
		else:
			_knockback_remaining = 0.0
	velocity.x = direction.x * horizontal_speed
	velocity.z = direction.z * horizontal_speed
	_requested_speed = 0.0
	if not is_on_floor():
		velocity += get_gravity() * delta
	elif velocity.y < 0.0:
		velocity.y = 0.0
	move_and_slide()
	# Capture the first dry resting pose, before any walking push can move the box.
	if not _initial_settled and is_on_floor():
		_reset_transform = global_transform
		_initial_settled = true


func _can_be_pushed() -> bool:
	return push_enabled and is_on_floor()
