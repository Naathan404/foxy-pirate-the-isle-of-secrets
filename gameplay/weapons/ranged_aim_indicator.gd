class_name RangedAimIndicator
extends Node3D
## Ground marker only; the weapon controller owns aiming, charge and release.

@export_range(0.01, 0.3, 0.01) var ground_height: float = 0

var _actor: Node3D
var _direction: Vector3 = Vector3.FORWARD

@onready var _material: ShaderMaterial = $Arrow.material_override


func setup(actor: Node3D, direction: Vector3) -> void:
	_actor = actor
	set_aim(direction, 0.0)
	_follow_actor()


func set_aim(direction: Vector3, charge: float) -> void:
	var horizontal := Vector3(direction.x, 0.0, direction.z)
	if not horizontal.is_zero_approx():
		_direction = horizontal.normalized()
	_material.set_shader_parameter("charge", clampf(charge, 0.0, 1.0))
	global_basis = Basis.looking_at(_direction, Vector3.UP)


func _process(_delta: float) -> void:
	_follow_actor()


func _follow_actor() -> void:
	if not is_instance_valid(_actor):
		queue_free()
		return
	global_position = _actor.global_position + Vector3.UP * ground_height
