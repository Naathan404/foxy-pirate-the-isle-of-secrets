class_name LootTrail
extends Node3D
## Reusable ribbon with a fixed ring buffer; returning to the pool clears all flight state.

signal finished(trail: LootTrail)

const MAX_POINTS: int = 32

@export_range(0.05, 0.5, 0.01) var point_lifetime: float = 0.22

var _source: Node3D
var _positions := PackedVector3Array()
var _ages := PackedFloat32Array()
var _first: int = 0
var _count: int = 0
var _width: float = 0.08
var _active: bool = false
var _lease: int = 0

@onready var _ribbon: MeshInstance3D = $Ribbon
@onready var _mesh: ImmediateMesh = _ribbon.mesh
@onready var _material: ShaderMaterial = _ribbon.material_override


func _ready() -> void:
	_positions.resize(MAX_POINTS)
	_ages.resize(MAX_POINTS)
	reset()


func start(source: Node3D, color: Color, width: float) -> void:
	reset()
	_lease += 1
	_source = source
	_width = maxf(0.01, width)
	_material.set_shader_parameter("tint", color)
	global_transform = Transform3D.IDENTITY
	_active = true
	_append(source.global_position)
	show()
	set_process(true)


func get_lease() -> int:
	return _lease


func finish(lease: int) -> void:
	if not _active or lease != _lease:
		return
	if is_instance_valid(_source):
		_append(_source.global_position)
	_source = null


func reset() -> void:
	_active = false
	_source = null
	_first = 0
	_count = 0
	_mesh.clear_surfaces()
	hide()
	set_process(false)


func _process(delta: float) -> void:
	for offset in _count:
		var index := (_first + offset) % MAX_POINTS
		_ages[index] += maxf(0.0, delta)
	while _count > 0 and _ages[_first] >= point_lifetime:
		_first = (_first + 1) % MAX_POINTS
		_count -= 1
	if is_instance_valid(_source) and not _source.is_queued_for_deletion():
		_append(_source.global_position)
	else:
		_source = null
	_mesh.clear_surfaces()
	if _source == null and _count < 2 and _active:
		_active = false
		finished.emit(self)
		return
	if _count >= 2:
		_draw_ribbon()


func _append(point: Vector3) -> void:
	if _count > 0:
		var previous := (_first + _count - 1) % MAX_POINTS
		if _positions[previous].distance_squared_to(point) < 0.000225:
			return
	if _count == MAX_POINTS:
		_first = (_first + 1) % MAX_POINTS
		_count -= 1
	var index := (_first + _count) % MAX_POINTS
	_positions[index] = point
	_ages[index] = 0.0
	_count += 1


func _draw_ribbon() -> void:
	var camera := get_viewport().get_camera_3d()
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for offset in _count:
		var index := (_first + offset) % MAX_POINTS
		var point := _positions[index]
		var previous := (_first + maxi(0, offset - 1)) % MAX_POINTS
		var following := (_first + mini(_count - 1, offset + 1)) % MAX_POINTS
		var tangent := _positions[following] - _positions[previous]
		var view := camera.global_position - point if is_instance_valid(camera) else Vector3.UP
		var side := tangent.cross(view).normalized()
		if side.is_zero_approx():
			side = Vector3.RIGHT
		var fraction := float(offset) / (_count - 1)
		var fade := clampf(1.0 - _ages[index] / point_lifetime, 0.0, 1.0)
		var half_width := _width * 0.5 * lerpf(0.12, 1.0, fraction) * sqrt(fade)
		for edge in 2:
			_mesh.surface_set_color(Color(1.0, 1.0, 1.0, fade))
			_mesh.surface_set_uv(Vector2(fraction, float(edge)))
			_mesh.surface_add_vertex(point + side * half_width * (float(edge) * 2.0 - 1.0))
	_mesh.surface_end()
