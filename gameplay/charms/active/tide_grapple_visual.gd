class_name TideGrappleVisual
extends Node3D
## The hook tip and real chain links follow execution-owned endpoints and phases.

const HOOK_SHEET: Texture2D = preload("res://assets/sprites/effects/charms/tide_hook.png")
const SEGMENTS: int = 8

@export var hook_width_units: float = 1.35
@export var hook_eye_offset_units: float = 0.57
@export var chain_width_units: float = 0.32
@export var chain_tile_units: float = 1.0

var _hook: CharmSpriteVfx
var _mesh := ImmediateMesh.new()

@onready var _chain: MeshInstance3D = $Chain


func _ready() -> void:
	_chain.mesh = _mesh
	_hook = CharmSpriteVfx.spawn(
		self,
		global_position,
		HOOK_SHEET,
		0,
		hook_width_units,
		1.0,
		Vector3.RIGHT,
		true,
		Vector2(0.88, 0.54)
	)
	_hook.externally_driven = true


func set_flight(
	origin: Vector3, tip: Vector3, direction: Vector3, row: int, progress: float, slack: float
) -> void:
	_hook.global_position = tip
	_hook.sample(row, progress, direction)
	if origin.distance_to(tip) <= hook_eye_offset_units:
		_mesh.clear_surfaces()
		return
	var eye := tip - _hook.global_basis.x * hook_eye_offset_units
	_draw_chain(origin, eye, slack)


func _draw_chain(from: Vector3, to: Vector3, slack: float) -> void:
	_mesh.clear_surfaces()
	var span := to - from
	if span.length() < 0.04:
		return
	var camera := get_viewport().get_camera_3d()
	var normal := camera.global_basis.z if is_instance_valid(camera) else Vector3.BACK
	var sag := minf(span.length() * 0.12, 0.22) * slack
	var points: Array[Vector3] = []
	var arc_length := 0.0
	for index in SEGMENTS + 1:
		var fraction := float(index) / SEGMENTS
		var point := from.lerp(to, fraction) - Vector3.UP * sin(fraction * PI) * sag
		if not points.is_empty():
			arc_length += points[-1].distance_to(point)
		points.append(point)
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	var distance := 0.0
	for index in points.size():
		if index > 0:
			distance += points[index - 1].distance_to(points[index])
		var tangent := points[mini(index + 1, SEGMENTS)] - points[maxi(0, index - 1)]
		var across := normal.cross(tangent).normalized()
		if across.is_zero_approx():
			across = Vector3.UP
		for side in 2:
			_mesh.surface_set_uv(Vector2((distance - arc_length) / chain_tile_units, float(side)))
			_mesh.surface_add_vertex(
				to_local(points[index] + across * chain_width_units * (0.5 if side == 0 else -0.5))
			)
	_mesh.surface_end()
