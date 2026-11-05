class_name ArrowRainTelegraph
extends MeshInstance3D
## Vòng báo trước phạm vi rơi của Arrow Rain.

@export var radius: float = 2.0
@export var lifetime: float = 1.7
@export var ring_color: Color = Color(1.0, 0.28, 0.22, 0.7)

var _material: StandardMaterial3D


func _ready() -> void:
	_material = StandardMaterial3D.new()
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.albedo_color = ring_color
	_material.emission_enabled = true
	_material.emission = Color(ring_color.r, ring_color.g * 0.35, ring_color.b * 0.2, 1.0)
	_material.emission_energy_multiplier = 1.5
	var ring := ImmediateMesh.new()
	ring.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, _material)
	for index in range(65):
		var angle := TAU * float(index) / 64.0
		ring.surface_add_vertex(Vector3(cos(angle) * radius, 0.0, sin(angle) * radius))
	ring.surface_end()
	mesh = ring
	position.y = 0.035
	var fade_start := maxf(0.05, lifetime * 0.7)
	var tween := create_tween()
	tween.tween_interval(fade_start)
	tween.tween_property(_material, "albedo_color:a", 0.0, maxf(0.05, lifetime - fade_start))
	tween.tween_callback(queue_free)

