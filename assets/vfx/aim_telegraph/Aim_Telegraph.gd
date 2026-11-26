class_name AimTelegraph
extends Node3D
## Ground lane and arrow showing where a directional attack will go.
## The weapon controller owns aiming, charge and release; this node only draws them.
## Local +X is the aim direction; the arrow starts at the actor and ends at the attack range.

const PARAM_ARROW_LENGTH := &"arrow_length"
const PARAM_ARROW_WIDTH := &"arrow_width"
const PARAM_PAD := &"pad"
const PARAM_FILL := &"fill"
const PARAM_SLAB_GROW := &"slab_grow"

@export_range(-0.5, 0.3, 0.01, "suffix:m") var ground_height: float = -0.1
## Length shown before setup() supplies the attack's range.
@export_range(1.0, 30.0, 0.1, "suffix:m") var arrow_length_units: float = 8.0
## Shown length = attack range × this; lower it to shorten the arrow without changing range.
@export_range(0.1, 1.0, 0.01) var length_scale: float = 0.6
@export_range(0.5, 10.0, 0.1, "suffix:m") var arrow_width_units: float = 4.8
## Margin around the arrow so the glow fades out before the quad border.
@export_range(0.0, 5.0, 0.1, "suffix:m") var edge_pad_units: float = 1.4
## Lane width while nothing is charged; it widens to full as the fill reaches the tip.
@export_range(0.0, 1.0, 0.01) var slab_grow_when_empty: float = 0.35

var _actor: Node3D
var _direction: Vector3 = Vector3.RIGHT

@onready var _slab: MeshInstance3D = $Slab
@onready var _arrow: MeshInstance3D = $Arrow


func _ready() -> void:
	_apply_length()
	set_fill(1.0)


func _process(_delta: float) -> void:
	_follow_actor()


func setup(actor: Node3D, direction: Vector3, length_units: float) -> void:
	_actor = actor
	arrow_length_units = maxf(0.01, length_units * length_scale)
	_apply_length()
	set_aim(direction, 0.0)
	_follow_actor()


## fill: 0..1, lights the arrow from its base toward the tip.
func set_aim(direction: Vector3, fill: float) -> void:
	var horizontal := Vector3(direction.x, 0.0, direction.z)
	if not horizontal.is_zero_approx():
		_direction = horizontal.normalized()
	# Rotating around Y by atan2(-z, x) maps local +X onto the aim direction.
	global_basis = Basis(Vector3.UP, atan2(-_direction.z, _direction.x))
	set_fill(fill)


func set_fill(fill: float) -> void:
	var clamped := clampf(fill, 0.0, 1.0)
	for part: MeshInstance3D in [_slab, _arrow]:
		part.set_instance_shader_parameter(PARAM_FILL, clamped)
		part.set_instance_shader_parameter(
			PARAM_SLAB_GROW, lerpf(slab_grow_when_empty, 1.0, clamped)
		)


# Each instance gets its own quad so ranges never leak between telegraphs.
func _apply_length() -> void:
	for part: MeshInstance3D in [_slab, _arrow]:
		var plane := part.mesh.duplicate() as PlaneMesh
		plane.size = Vector2(arrow_length_units + 2.0 * edge_pad_units, arrow_width_units)
		part.mesh = plane
		part.position.x = arrow_length_units * 0.5
		part.set_instance_shader_parameter(PARAM_ARROW_LENGTH, arrow_length_units)
		part.set_instance_shader_parameter(PARAM_ARROW_WIDTH, arrow_width_units)
		part.set_instance_shader_parameter(PARAM_PAD, edge_pad_units)


func _follow_actor() -> void:
	if _actor == null:
		return
	if not is_instance_valid(_actor):
		queue_free()
		return
	global_position = _actor.global_position + Vector3.UP * ground_height
