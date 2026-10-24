extends Node3D

@export var player: Player
@export_range(0.0, 5.0, 0.01) var minimum_speed: float = 0.2
@export_range(0.0, 2.0, 0.01) var heel_offset: float = 0.15

var _rest_position: Vector3

@onready var particle: GPUParticles3D = $Particle


func _ready() -> void:
	_rest_position = particle.position
	particle.emitting = false
	particle.local_coords = false


func _process(_delta: float) -> void:
	if not is_instance_valid(player) or not is_instance_valid(player.fsm):
		particle.emitting = false
		return

	var movement = player.get_real_velocity()
	movement.y = 0.0
	var running = player.fsm.current_state == player.fsm.states.get("run")
	particle.emitting = (
		running
		and not player.dead
		and player.is_on_floor()
		and movement.length() > minimum_speed
	)
	if not particle.emitting:
		return

	var behind := -movement.normalized() * heel_offset
	particle.position = _rest_position + global_basis.inverse() * behind
