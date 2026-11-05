class_name PushableCrate
extends CharacterBody3D
## A controlled puzzle prop: one movement request per physics tick, no accumulated impulse.

const DUST_SCENE: PackedScene = preload("res://gameplay/player/effects/run_dust_effect.tscn")

@export_range(0.1, 10.0, 0.1) var push_speed: float = 2.0
@export var push_enabled: bool = true
## Optional water source; a grounded crate remains pushable while its base is dry.
@export var tide_controller: TideController
@export_group("Knockback")
@export_range(0.1, 15.0, 0.1) var knockback_speed: float = 6.0
@export_range(0.1, 3.0, 0.1) var maximum_knockback_distance: float = 1.5

@export_group("Weapon Impact Feedback")
@export var impact_sound: AudioStream = preload("res://assets/audio/world/crate_lever.wav")
@export_range(-30.0, 0.0, 1.0) var impact_volume_db: float = -12.0
@export_range(0.0, 0.2, 0.01) var impact_recoil: float = 0.08
@export_range(0.0, 0.3, 0.01) var impact_squash: float = 0.12
@export_range(0.0, 4.0, 0.1) var impact_shake_pixels: float = 1.2

@export_group("Floating")
@export var float_enabled: bool = true
## Waterline above the crate's base, measured in world units.
@export_range(0.0, 3.0, 0.05) var float_draft: float = 0.2
@export_range(0.1, 20.0, 0.1) var float_speed: float = 6.0

var is_floating: bool = false

var _push_direction: Vector3 = Vector3.ZERO
var _requested_speed: float = 0.0
var _knockback_direction: Vector3 = Vector3.ZERO
var _knockback_remaining: float = 0.0
var _reset_transform: Transform3D
var _initial_settled: bool = false
var _reset_tween: Tween
var _impact_tween: Tween
var _impact_dust: GPUParticles3D

@onready var _body_shape: CollisionShape3D = $CollisionShape3D
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
	is_floating = false
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
	_update_float_velocity(delta)
	# Let the box touch land physically instead of snapping down before the water recedes.
	floor_snap_length = 0.0 if is_floating else _ground_snap_length
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
	if not is_floating:
		if not is_on_floor():
			velocity += get_gravity() * delta
		elif velocity.y < 0.0:
			velocity.y = 0.0
	move_and_slide()
	# Capture the first dry resting pose, before any walking push can move the box.
	if not _initial_settled and is_on_floor() and not is_floating:
		_reset_transform = global_transform
		_initial_settled = true


func _update_float_velocity(delta: float) -> void:
	var was_floating := is_floating
	is_floating = false
	if was_floating:
		velocity.y = minf(velocity.y, 0.0)
	if not float_enabled or not is_instance_valid(tide_controller) or delta <= 0.0:
		return
	var water := tide_controller.water
	if not is_instance_valid(water) or not _is_over_water(water):
		return
	var water_height := tide_controller.get_water_height()
	var bottom_height := _get_bottom_height()
	var bottom_offset := bottom_height - global_position.y
	var target_height := water_height - float_draft - bottom_offset
	if water_height <= bottom_height:
		return
	# A grounded crate starts rising only when water can support its draft.
	if is_on_floor() and target_height <= global_position.y + 0.002:
		return
	if not was_floating and target_height <= global_position.y + 0.002:
		return
	is_floating = true
	velocity.y = clampf((target_height - global_position.y) / delta, -float_speed, float_speed)


func _get_bottom_height() -> float:
	var box := _body_shape.shape as BoxShape3D
	if box == null:
		return global_position.y
	var half_size := box.size * 0.5
	var shape_basis := _body_shape.global_basis
	var extent := absf(shape_basis.x.y) * half_size.x + absf(shape_basis.y.y) * half_size.y
	extent += absf(shape_basis.z.y) * half_size.z
	return _body_shape.global_position.y - extent


func _is_over_water(water: Node3D) -> bool:
	var surface := water as MeshInstance3D
	if surface == null or surface.mesh == null:
		return true
	var point := surface.to_local(global_position)
	var bounds := surface.get_aabb()
	return (
		point.x >= bounds.position.x
		and point.x <= bounds.end.x
		and point.z >= bounds.position.z
		and point.z <= bounds.end.z
	)


func _can_be_pushed() -> bool:
	return (
		push_enabled
		and not is_floating
		and is_on_floor()
		and (
			not is_instance_valid(tide_controller)
			or tide_controller.get_depth_at(
				Vector3(global_position.x, _get_bottom_height(), global_position.z)
			) <= 0.0
		)
	)
