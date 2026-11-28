class_name KrakenFissure
extends MeshInstance3D
## The torn ground the tentacles burst from. It races along the march during the windup, so it
## is also the telegraph, stays open while they guard and then seals.

const SHADER := preload("res://gameplay/charms/active/kraken_fissure.gdshader")
const HALF_WIDTH_METERS := 0.74
const GLOW_METERS := 0.65
const LIFT_METERS := 0.05
const OPEN_SECONDS := 0.12
const CLOSE_SECONDS := 0.4
## Drawn before other transparent ground marks so the slam telegraphs stay readable.
const RENDER_PRIORITY := -2

var _material := ShaderMaterial.new()
var _length := 0.0


## `path` holds world-space ground points ordered from Foxy outward.
static func spawn(parent: Node3D, path: PackedVector3Array, reveal_seconds: float) -> KrakenFissure:
	var fissure := KrakenFissure.new()
	parent.add_child(fissure)
	fissure.global_transform = Transform3D(Basis.IDENTITY, path[0])
	fissure._build(path)
	fissure._reveal(reveal_seconds)
	return fissure


func close() -> void:
	var tween := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(_material, "shader_parameter/openness", 0.0, CLOSE_SECONDS)
	tween.tween_callback(queue_free)


func _build(path: PackedVector3Array) -> void:
	var strip := ImmediateMesh.new()
	var half := HALF_WIDTH_METERS + GLOW_METERS
	_length = 0.0
	strip.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for index in path.size():
		if index > 0:
			_length += path[index].distance_to(path[index - 1])
		var tangent := path[mini(index + 1, path.size() - 1)] - path[maxi(index - 1, 0)]
		var across := Vector3.UP.cross(tangent).normalized()
		var local := path[index] - path[0] + Vector3.UP * LIFT_METERS
		for side: float in [-1.0, 1.0]:
			strip.surface_set_uv(Vector2(_length, side * half))
			strip.surface_add_vertex(local + across * half * side)
	strip.surface_end()
	mesh = strip
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_material.shader = SHADER
	_material.render_priority = RENDER_PRIORITY
	_material.set_shader_parameter("length_meters", _length)
	_material.set_shader_parameter("half_width_meters", HALF_WIDTH_METERS)
	_material.set_shader_parameter("revealed_meters", 0.0)
	_material.set_shader_parameter("openness", 0.0)
	material_override = _material


func _reveal(seconds: float) -> void:
	var tween := create_tween().set_process_mode(Tween.TWEEN_PROCESS_PHYSICS).set_parallel()
	tween.tween_property(
		_material, "shader_parameter/revealed_meters", _length, maxf(OPEN_SECONDS, seconds)
	)
	tween.tween_property(_material, "shader_parameter/openness", 1.0, OPEN_SECONDS)
