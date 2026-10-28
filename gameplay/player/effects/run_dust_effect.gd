extends Node3D

@export var player: Player
@export_range(0.0, 5.0, 0.01) var minimum_speed: float = 0.2
@export_range(0.0, 2.0, 0.01) var heel_offset: float = 0.15

@export_group("Running Feedback")
@export_range(0.3, 2.0, 0.05) var step_distance: float = 1.1
@export_range(0.0, 0.4, 0.01) var step_width: float = 0.16
@export_range(0.0, 0.3, 0.01) var ground_clearance: float = 0.05

var _was_running: bool = false
var _distance_since_step: float = 0.0
var _step_side: float = 1.0
var _next_step: int = 0
var _last_direction: Vector3 = Vector3.BACK
var _bursts: Array[GPUParticles3D] = []
var _trail_material: ParticleProcessMaterial

@onready var particle: GPUParticles3D = $Particle


func _ready() -> void:
	particle.emitting = false
	particle.local_coords = false
	_trail_material = particle.process_material as ParticleProcessMaterial
	_create_bursts()


func _create_bursts() -> void:
	# Ba emitter luân phiên cho bước chân, một cho xuất phát và một cho dừng.
	for index in range(5):
		var burst := particle.duplicate() as GPUParticles3D
		burst.name = "RunPuff%d" % index
		burst.process_material = particle.process_material.duplicate()
		burst.one_shot = true
		burst.explosiveness = 1.0
		burst.amount_ratio = 1.0
		burst.amount = 5 if index < 3 else (10 if index == 3 else 12)
		burst.lifetime = 0.26 if index < 3 else 0.34
		burst.emitting = false
		var material := burst.process_material as ParticleProcessMaterial
		material.spread = 55.0 if index < 3 else 80.0
		material.initial_velocity_min = 0.6 if index < 3 else 1.2
		material.initial_velocity_max = 1.2 if index < 3 else 2.0
		material.scale_min = 0.65 if index < 3 else 1.0
		material.scale_max = 1.15 if index < 3 else 1.8
		add_child(burst)
		burst.top_level = true
		_bursts.append(burst)


func _process(delta: float) -> void:
	if not is_instance_valid(player) or not is_instance_valid(player.fsm) or player.data == null:
		_stop_running(false)
		return

	var movement = player.get_real_velocity()
	movement.y = 0.0
	var running = player.fsm.current_state == player.fsm.states.get("run")
	if not running or player.dead or not player.is_on_floor() or movement.length() <= minimum_speed:
		var idle: bool = player.fsm.current_state == player.fsm.states.get("idle")
		_stop_running(idle and not player.dead and player.is_on_floor())
		return
	_update_running(movement, delta)


func _update_running(movement: Vector3, delta: float) -> void:
	var speed: float = movement.length()
	var direction: Vector3 = movement.normalized()
	var foot: Vector3 = _get_foot_position()
	var speed_ratio: float = clampf(speed / maxf(0.1, player.data.move_speed), 0.0, 1.0)
	particle.global_position = foot - direction * heel_offset
	particle.amount_ratio = lerpf(0.15, 0.5, speed_ratio)
	_trail_material.direction = (
		particle.global_basis.inverse() * (-direction + Vector3.UP * 0.45).normalized()
	)
	particle.emitting = true
	if not _was_running:
		_emit_burst(3, foot - direction * heel_offset, direction)
		_was_running = true
		_distance_since_step = 0.0
	_last_direction = direction
	_distance_since_step += speed * maxf(0.0, delta)
	if _distance_since_step >= maxf(0.1, step_distance):
		_distance_since_step = fmod(_distance_since_step, maxf(0.1, step_distance))
		var side: Vector3 = direction.cross(Vector3.UP).normalized() * step_width * _step_side
		_emit_burst(_next_step, foot + side - direction * heel_offset, direction)
		_next_step = (_next_step + 1) % 3
		_step_side = -_step_side


func _stop_running(play_stop_burst: bool) -> void:
	particle.emitting = false
	if _was_running and play_stop_burst and is_instance_valid(player):
		_emit_burst(4, _get_foot_position() + _last_direction * 0.1, _last_direction)
	_was_running = false
	_distance_since_step = 0.0
	_step_side = 1.0


func _emit_burst(index: int, origin: Vector3, direction: Vector3) -> void:
	var burst: GPUParticles3D = _bursts[index]
	burst.global_position = origin
	var material := burst.process_material as ParticleProcessMaterial
	material.direction = (
		burst.global_basis.inverse() * (-direction + Vector3.UP * 0.35).normalized()
	)
	burst.restart()
	burst.emitting = true


func _get_foot_position() -> Vector3:
	var foot: Vector3 = player.global_position
	var collider := player.get_node_or_null("CollisionShape3D") as CollisionShape3D
	if collider != null and collider.shape is CapsuleShape3D:
		var capsule := collider.shape as CapsuleShape3D
		foot = collider.global_position
		foot.y -= capsule.height * collider.global_basis.y.length() * 0.5
	return foot + Vector3.UP * ground_clearance
