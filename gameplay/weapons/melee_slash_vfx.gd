class_name MeleeSlashVFX
extends Node3D
## Visual only: the execution supplies swing progress; no damage queries live here.

const ENERGY_SHADER: Shader = preload("res://gameplay/weapons/dagger_energy.gdshader")
const SEGMENTS: int = 28

var _step: MeleeComboStep
var _radius: float
var _progress: float = 0.0
var _mesh := ImmediateMesh.new()
var _material := ShaderMaterial.new()
var _released: bool = false
var _age: float = 0.0
var _impact_count: int = 0


func setup(step: MeleeComboStep, radius: float) -> void:
	_step = step
	_radius = radius
	_material.shader = ENERGY_SHADER
	_material.set_shader_parameter("shape", 4)
	_material.set_shader_parameter("tint", step.slash_color)
	var ribbon := MeshInstance3D.new()
	ribbon.mesh = _mesh
	ribbon.material_override = _material
	ribbon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(ribbon)
	set_progress(0.0)


func set_progress(progress: float) -> void:
	_progress = clampf(progress, 0.0, 1.0)
	_draw_arc()


func finish() -> void:
	_released = true


func impact(at: Vector3, direction: Vector3, heavy: bool, strength: float = 1.0) -> void:
	if _impact_count >= 8:
		return
	_impact_count += 1
	var camera := get_viewport().get_camera_3d()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.95, 0.75)
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	for index in 7 if heavy else 4:
		var spark := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(0.055, 0.22 if heavy else 0.14) * strength
		spark.mesh = quad
		spark.material_override = material
		spark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(spark)
		spark.global_position = at
		var side := camera.global_basis.x if camera != null else Vector3.RIGHT
		var spread := float(index) / (6.0 if heavy else 3.0) * 2.0 - 1.0
		var velocity := direction * 0.4 + side * spread + Vector3.UP * (0.3 + absf(spread))
		var tween := spark.create_tween().set_parallel()
		tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(spark, "global_position", at + velocity * 0.65 * strength, 0.18)
		tween.tween_property(spark, "scale", Vector3.ZERO, 0.18)
		tween.chain().tween_callback(spark.queue_free)


func _process(delta: float) -> void:
	if not _released:
		return
	_age += delta
	_material.set_shader_parameter("progress", minf(1.0, _age / 0.1))
	if _age >= 0.3:
		queue_free()


func _draw_arc() -> void:
	_mesh.clear_surfaces()
	var head := lerpf(_step.swing_start_degrees, _step.swing_end_degrees, _progress)
	var tail := lerpf(
		_step.swing_start_degrees, _step.swing_end_degrees, maxf(0.0, _progress - 0.65)
	)
	# Show a short leading mark on the first active frame.
	if is_equal_approx(head, tail):
		head += signf(_step.swing_end_degrees - _step.swing_start_degrees) * 3.0
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for index in SEGMENTS + 1:
		var fraction := float(index) / SEGMENTS
		var angle := deg_to_rad(lerpf(tail, head, fraction))
		var direction := Vector3(sin(angle), 0.0, -cos(angle))
		var width := _step.slash_width * sin(fraction * PI)
		for edge in 2:
			_mesh.surface_set_uv(Vector2(fraction, float(edge)))
			_mesh.surface_add_vertex(
				direction * (_radius - width * float(edge)) + Vector3.UP * 1.15
			)
	_mesh.surface_end()
