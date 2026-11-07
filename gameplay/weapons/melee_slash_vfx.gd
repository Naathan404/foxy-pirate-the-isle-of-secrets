class_name MeleeSlashVFX
extends Node3D
## Visual only: the execution supplies swing progress; no damage queries live here.

const ENERGY_SHADER: Shader = preload("res://gameplay/weapons/dagger_slash_overlay.gdshader")
const SEGMENTS: int = 40

var _step: MeleeComboStep
var _radius: float
var _progress: float = 0.0
var _mesh := ImmediateMesh.new()
var _material := ShaderMaterial.new()
var _echo_mesh := ImmediateMesh.new()
var _echo_material := ShaderMaterial.new()
var _fade_seconds: float = 0.16
var _released: bool = false
var _age: float = 0.0
var _impact_count: int = 0
var _show_trail: bool = true


func setup(step: MeleeComboStep, radius: float, show_trail: bool = true) -> void:
	_step = step
	_show_trail = show_trail
	_radius = radius * (1.15 if step.heavy_impact else 1.1)
	_fade_seconds = 0.22 if step.heavy_impact else 0.16
	_material.shader = ENERGY_SHADER
	_material.set_shader_parameter("shape", 4)
	_material.set_shader_parameter("tint", step.slash_color)
	_material.set_shader_parameter("energy", 2.0 if step.heavy_impact else 1.65)
	if _show_trail:
		var ribbon := MeshInstance3D.new()
		ribbon.mesh = _mesh
		ribbon.material_override = _material
		ribbon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ribbon)
	_echo_material.shader = ENERGY_SHADER
	_echo_material.set_shader_parameter("shape", 4)
	_echo_material.set_shader_parameter("tint", Color(step.slash_color, step.slash_color.a * 0.4))
	_echo_material.set_shader_parameter("energy", 1.25)
	if _show_trail:
		var echo := MeshInstance3D.new()
		echo.mesh = _echo_mesh
		echo.material_override = _echo_material
		echo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(echo)
	set_progress(0.0)


func set_progress(progress: float) -> void:
	_progress = clampf(progress, 0.0, 1.0)
	_draw_arc()


func finish() -> void:
	if _released:
		return
	_released = true


func impact(at: Vector3, direction: Vector3, heavy: bool, strength: float = 1.0) -> void:
	if _impact_count >= 8:
		return
	_impact_count += 1
	var camera := get_viewport().get_camera_3d()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.92, 0.98, 1.0)
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
	_material.set_shader_parameter("progress", minf(1.0, _age / _fade_seconds))
	_echo_material.set_shader_parameter("progress", minf(1.0, _age / (_fade_seconds * 1.2)))
	if _age >= maxf(0.3, _fade_seconds * 1.2):
		queue_free()


func _draw_arc() -> void:
	if not _show_trail:
		return
	var head := lerpf(_step.swing_start_degrees, _step.swing_end_degrees, _progress)
	var tail := lerpf(
		_step.swing_start_degrees, _step.swing_end_degrees, maxf(0.0, _progress - 0.95)
	)
	var sweep_sign := signf(_step.swing_end_degrees - _step.swing_start_degrees)
	# Give the first frame a readable blade, then retain almost the entire sweep.
	if absf(head - tail) < 10.0:
		head = tail + sweep_sign * 10.0
	var width := _step.slash_width * (1.5 if _step.heavy_impact else 1.35)
	_draw_ribbon(_mesh, tail, head, _radius, width, 1.15)
	var echo_head := head - sweep_sign * minf(12.0, absf(head - tail) * 0.35)
	_draw_ribbon(_echo_mesh, tail, echo_head, _radius * 0.84, width * 0.38, 1.18)


func _draw_ribbon(
	mesh: ImmediateMesh, tail: float, head: float, radius: float, width: float, height: float
) -> void:
	mesh.clear_surfaces()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for index in SEGMENTS + 1:
		var fraction := float(index) / SEGMENTS
		var angle := deg_to_rad(lerpf(tail, head, fraction))
		var direction := Vector3(sin(angle), 0.0, -cos(angle))
		var taper := pow(maxf(0.0, sin(fraction * PI)), 0.6)
		taper *= lerpf(0.45, 1.0, smoothstep(0.0, 0.45, fraction))
		var inner_radius := maxf(radius * 0.15, radius - width * taper)
		for edge in 2:
			mesh.surface_set_uv(Vector2(fraction, float(edge)))
			mesh.surface_add_vertex(
				direction * (radius if edge == 0 else inner_radius) + Vector3.UP * height
			)
	mesh.surface_end()
