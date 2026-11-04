extends Node3D
## A short, camera-facing puncture flash with lightning driven along the dash.

const ELECTRIC_SHADER: Shader = preload("res://gameplay/weapons/harpoon_electric.gdshader")

@export_range(0.05, 0.5, 0.01) var duration: float = 0.22
@export_range(0.5, 4.0, 0.1) var forward_length: float = 1.7
@export_range(0.1, 2.0, 0.1) var backward_length: float = 0.65
@export_range(0.1, 2.0, 0.1) var spark_width: float = 0.65
@export_range(0.5, 6.0, 0.1) var brightness: float = 2.8

var _mesh := ImmediateMesh.new()
var _age: float = 0.0
var _direction: Vector3 = Vector3.FORWARD
var _power: float = 1.0


func _ready() -> void:
	var visual := MeshInstance3D.new()
	visual.mesh = _mesh
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = ELECTRIC_SHADER
	material.set_shader_parameter("brightness", brightness)
	visual.material_override = material
	add_child(visual)
	set_process(false)


func burst(direction: Vector3, power: float = 1.0) -> void:
	_direction = direction.normalized() if not direction.is_zero_approx() else Vector3.FORWARD
	_power = clampf(power, 0.7, 1.5)
	_age = 0.0
	_draw_impact()
	set_process(true)


func _process(delta: float) -> void:
	_age += delta
	if _age >= duration:
		queue_free()
		return
	_draw_impact()


func _draw_impact() -> void:
	var viewport := get_viewport()
	var camera: Camera3D = viewport.get_camera_3d() if viewport != null else null
	var view := Vector3.BACK
	if is_instance_valid(camera):
		view = (camera.global_position - global_position).normalized()
	var axis := (_direction - view * _direction.dot(view)).normalized()
	if axis.is_zero_approx():
		axis = camera.global_basis.x if is_instance_valid(camera) else Vector3.RIGHT
	var across := view.cross(axis).normalized()
	var inverse := global_basis.inverse()
	axis = inverse * axis
	across = inverse * across
	view = inverse * view
	var progress := clampf(_age / duration, 0.0, 1.0)
	var fade := pow(1.0 - progress, 1.7)
	var spread := 1.0 + progress * 0.4
	var back := axis * -backward_length * _power
	var front := axis * forward_length * _power
	var gold := Color(1.0, 0.53, 0.04, 0.63 * fade)
	var white := Color(1.0, 1.0, 0.82, 0.95 * fade)
	_mesh.clear_surfaces()
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	# The long white cut and pointed front make the contact read as a pierce.
	_ribbon(back, front, across * 0.19 * _power, gold)
	_ribbon(back * 0.8, front * 0.92, across * 0.055 * _power, white)
	_triangle(front * 0.45 + across * 0.21, front * 1.2, front * 0.45 - across * 0.21, white)
	# Jagged forks break away sideways while still pointing forward.
	for side in [-1.0, 1.0]:
		for index in 3:
			var step := float(index) / 3.0
			var start := axis * (-0.18 + step * 0.6) * _power
			var bend := axis * (0.15 + step * 0.62) * _power
			bend += across * side * spark_width * (0.5 + step * 0.45) * spread
			var end := axis * (0.65 + step * 0.7) * _power
			end += across * side * spark_width * (0.75 + step * 0.6) * spread
			_ribbon(start, bend, across * 0.09 * _power, gold)
			_ribbon(bend, end, across * 0.06 * _power, white)
	# A compact crossing glint flashes on the actual enemy contact point.
	_ribbon(-across * 0.42 * _power, across * 0.42 * _power, axis * 0.08 * _power, white)
	_ribbon(-axis * 0.32 * _power, axis * 0.32 * _power, across * 0.11 * _power, white)
	_mesh.surface_end()


func _ribbon(start: Vector3, end: Vector3, side: Vector3, color: Color) -> void:
	_triangle(start - side, start + side, end + side, color)
	_triangle(start - side, end + side, end - side, color)


func _triangle(a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	for point in [a, b, c]:
		_mesh.surface_set_color(color)
		_mesh.surface_add_vertex(point)
