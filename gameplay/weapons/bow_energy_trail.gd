extends Node3D
## Spatially sampled Catmull-Rom ribbon with a soft rim and a bright inner filament.

const ENERGY_SHADER: Shader = preload("res://gameplay/weapons/bow_energy.gdshader")
const MIN_RIBBON_POINTS: int = 2
const RIBBON_SHAPE: int = 4

@export_group("Ribbon")
@export_range(2, 64, 1) var max_points: int = 24
@export_range(0.001, 0.5, 0.001) var base_width: float = 0.035
@export_range(0.0, 0.5, 0.001) var charge_width_bonus: float = 0.1
@export var tail_color: Color = Color(0.08, 0.4, 1.0, 0.0)
@export var head_color: Color = Color(0.55, 0.9, 1.0, 1.0)
@export_range(0.01, 2.0, 0.01) var fade_seconds: float = 0.22
@export_range(0.01, 1.0, 0.01) var sample_spacing: float = 0.14
@export_range(1, 6, 1) var smoothing_segments: int = 3
@export_range(0.1, 3.0, 0.05) var taper_power: float = 0.7

@export_group("Filament")
@export var core_color: Color = Color(1.0, 0.96, 0.82, 1.0)
@export_range(1.0, 400.0, 1.0) var core_sharpness: float = 90.0
@export_range(0.01, 1.0, 0.01) var glow_softness: float = 0.3
@export_range(0.1, 3.0, 0.05) var brightness: float = 1.3

var strength: float = 1.0
var _points: Array[Vector3] = []
var _head: Vector3
var _previous_head: Vector3
var _finishing: bool = false
var _fade: float = 1.0
var _mesh := ImmediateMesh.new()
var _material := ShaderMaterial.new()


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	_material.shader = ENERGY_SHADER
	_material.set_shader_parameter("shape", RIBBON_SHAPE)
	_material.set_shader_parameter("billboard", false)
	_material.set_shader_parameter("glow_color", head_color)
	_material.set_shader_parameter("core_color", core_color)
	_material.set_shader_parameter("core_sharpness", core_sharpness)
	_material.set_shader_parameter("glow_softness", glow_softness)
	_material.set_shader_parameter("brightness", brightness)
	var visual := MeshInstance3D.new()
	visual.mesh = _mesh
	visual.material_override = _material
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(visual)


func push_point(point: Vector3) -> void:
	if _points.is_empty():
		_points.append(point)
		_head = point
	_previous_head = _head
	_head = point
	var distance := _points[-1].distance_to(point)
	var start := _points[-1]
	var retained_distance := max_points * sample_spacing
	if distance > retained_distance:
		start = point + (start - point).normalized() * retained_distance
		distance = retained_distance
		_points.clear()
		_points.append(start)
	# Fixed spatial spacing keeps length/shape stable across physics frame rates.
	var steps := mini(floori(distance / sample_spacing), max_points)
	for index in steps:
		_points.append(start.lerp(point, float(index + 1) * sample_spacing / distance))
	while _points.size() > max_points:
		_points.pop_front()


func finish() -> void:
	_finishing = true


func _process(delta: float) -> void:
	if _finishing:
		_fade = maxf(0.0, _fade - delta / fade_seconds)
		if _fade <= 0.0:
			queue_free()
			return
	_mesh.clear_surfaces()
	if _points.is_empty():
		return
	var samples: Array[Vector3] = _points.duplicate()
	var head := (
		_head
		if _finishing
		else _previous_head.lerp(_head, Engine.get_physics_interpolation_fraction())
	)
	# The most recent fixed sample can be ahead of the interpolated visual arrow.
	var motion := _head - _previous_head
	while not _finishing and samples.size() > 1 and (samples[-1] - head).dot(motion) > 0.0:
		samples.pop_back()
	while samples.size() > 1 and samples[-1].distance_to(head) < sample_spacing:
		samples.pop_back()
	samples.append(head)
	if samples.size() < MIN_RIBBON_POINTS:
		return
	_draw_ribbon(samples)


func _draw_ribbon(points: Array[Vector3]) -> void:
	var camera := get_viewport().get_camera_3d()
	var smooth: Array[Vector3] = []
	for index in points.size() - 1:
		for step in smoothing_segments:
			smooth.append(
				points[index].cubic_interpolate(
					points[index + 1],
					points[maxi(0, index - 1)],
					points[mini(points.size() - 1, index + 2)],
					float(step) / smoothing_segments
				)
			)
	smooth.append(points[-1])
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for index in smooth.size():
		var tangent := smooth[mini(index + 1, smooth.size() - 1)] - smooth[maxi(0, index - 1)]
		var view := (
			camera.global_position - smooth[index] if is_instance_valid(camera) else Vector3.UP
		)
		var side := tangent.cross(view).normalized()
		if side.is_zero_approx():
			side = Vector3.RIGHT
		var fraction := float(index) / (smooth.size() - 1)
		var width := (
			(base_width + strength * charge_width_bonus) * pow(fraction, taper_power) * _fade
		)
		var color := tail_color.lerp(head_color, fraction)
		color.a *= _fade
		for edge in 2:
			_mesh.surface_set_color(color)
			_mesh.surface_set_uv(Vector2(fraction, float(edge)))
			_mesh.surface_add_vertex(smooth[index] + side * width * (float(edge) * 2.0 - 1.0))
	_mesh.surface_end()
