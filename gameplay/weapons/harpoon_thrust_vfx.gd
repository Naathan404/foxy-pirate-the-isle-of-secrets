extends Node3D
## Charge particles converge on the tip; the skill dash draws a rotating drill and forward bolts.

const ELECTRIC_SHADER: Shader = preload("res://gameplay/weapons/harpoon_electric.gdshader")
const GOLDEN_ANGLE: float = 2.39996323

var _reach: float = 1.0
var _striking: bool = false
var _charging: bool = false
var _skill: bool = false
var _time: float = 0.0
var _charge_progress: float = 0.0
var _dash_progress: float = 0.0
var _charge_mesh := ImmediateMesh.new()
var _drill_mesh := ImmediateMesh.new()
var _bolt_mesh := ImmediateMesh.new()
var _charge_visual: MeshInstance3D
var _drill_visual: MeshInstance3D
var _bolt_visual: MeshInstance3D
var _tip_light: OmniLight3D

@onready var _guide: MeshInstance3D = $Guide
@onready var _lance: MeshInstance3D = $Lance
@onready var _tip: MeshInstance3D = $Tip
@onready var _particles: GPUParticles3D = $Sparks


func _ready() -> void:
	_guide.hide()
	_lance.hide()
	_tip.hide()
	_charge_visual = _make_visual("ChargeElectrons", _charge_mesh)
	_drill_visual = _make_visual("Drill", _drill_mesh)
	_bolt_visual = _make_visual("Lightning", _bolt_mesh)
	(_drill_visual.material_override as ShaderMaterial).set_shader_parameter("brightness", 1.15)
	(_bolt_visual.material_override as ShaderMaterial).set_shader_parameter("brightness", 1.8)
	_charge_visual.hide()
	_drill_visual.hide()
	_bolt_visual.hide()
	_tip_light = OmniLight3D.new()
	_tip_light.light_color = Color(1.0, 0.75, 0.2)
	_tip_light.light_energy = 2.0
	_tip_light.omni_range = 2.6
	_tip_light.position = Vector3(0.0, 0.82, -1.15)
	_tip_light.visible = false
	add_child(_tip_light)


func _make_visual(node_name: String, geometry: ImmediateMesh) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.name = node_name
	visual.mesh = geometry
	var material := ShaderMaterial.new()
	material.shader = ELECTRIC_SHADER
	visual.material_override = material
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(visual)
	return visual


func prepare(reach: float, width: float, skill: bool) -> void:
	_reach = reach
	_charging = skill
	_skill = skill
	_time = 0.0
	_charge_progress = 0.0
	_charge_visual.visible = skill
	_drill_visual.hide()
	_bolt_visual.hide()
	var ground_height: float = 0.04
	if skill:
		var origin := global_position + Vector3.UP * 0.4
		var query := PhysicsRayQueryParameters3D.create(
			origin, origin + Vector3.DOWN * 3.0, CombatLayers.WORLD
		)
		var ground := get_world_3d().direct_space_state.intersect_ray(query)
		if not ground.is_empty():
			ground_height = float(ground.position.y) - global_position.y + 0.025
	var guide_reach := minf(reach, 2.4) if skill else reach
	var mesh := _guide.mesh.duplicate() as QuadMesh
	mesh.size = Vector2(maxf(0.4, width), guide_reach)
	_guide.mesh = mesh
	_guide.position = Vector3(0.0, ground_height, -guide_reach * 0.5)
	_guide.visible = skill
	_tip.visible = skill
	_tip.position = Vector3(0.0, 0.82, -1.0)
	set_charge_progress(0.0)


func set_charge_progress(progress: float) -> void:
	if not _charging or _striking:
		return
	var amount := clampf(progress, 0.0, 1.0)
	_charge_progress = amount
	_tip.scale = Vector3.ONE * lerpf(0.18, 0.75, amount)
	(_tip.material_override as ShaderMaterial).set_shader_parameter(
		"brightness", lerpf(1.2, 3.2, amount)
	)
	(_guide.material_override as ShaderMaterial).set_shader_parameter(
		"opacity", lerpf(0.2, 0.75, amount)
	)


func strike(reach: float) -> void:
	_striking = true
	_charging = false
	_time = 0.0
	_dash_progress = 0.0
	_charge_visual.hide()
	_charge_mesh.clear_surfaces()
	_drill_visual.visible = _skill
	_bolt_visual.visible = _skill
	_tip_light.visible = _skill
	_reach = reach
	_guide.hide()
	_lance.show()
	_tip.show()
	var mesh := _lance.mesh.duplicate() as QuadMesh
	mesh.size = Vector2(0.35, reach + 0.4)
	_lance.mesh = mesh
	_lance.position = Vector3(0.0, 0.8, -reach * 0.5)
	_tip.position = Vector3(0.0, 0.8, -reach)
	_particles.emitting = true
	set_progress(0.0)


func set_progress(progress: float) -> void:
	if not _striking:
		return
	_dash_progress = clampf(progress, 0.0, 1.0)
	var opacity: float = 1.0 - progress * 0.6
	(_lance.material_override as ShaderMaterial).set_shader_parameter("opacity", opacity)
	_tip.scale = Vector3.ONE * lerpf(0.7, 1.1, sin(progress * PI))
	_particles.position = Vector3(0.0, 0.8, -_reach * 0.75)


func finish() -> void:
	_striking = false
	_charging = false
	_skill = false
	_guide.hide()
	_lance.hide()
	_tip.hide()
	_particles.emitting = false
	_charge_visual.hide()
	_drill_visual.hide()
	_bolt_visual.hide()
	_tip_light.hide()
	_charge_mesh.clear_surfaces()
	_drill_mesh.clear_surfaces()
	_bolt_mesh.clear_surfaces()


func _process(delta: float) -> void:
	if not _charging and not (_striking and _skill):
		return
	_time += maxf(0.0, delta)
	if _charging:
		_draw_charge()
	else:
		_draw_drill()
		_draw_lightning()


func _draw_charge() -> void:
	_charge_mesh.clear_surfaces()
	_charge_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var camera := get_viewport().get_camera_3d()
	var right := Vector3.RIGHT
	var up := Vector3.UP
	if is_instance_valid(camera):
		right = (global_basis.inverse() * camera.global_basis.x).normalized()
		up = (global_basis.inverse() * camera.global_basis.y).normalized()
	var focus := Vector3(0.0, 0.82, -1.0)
	for index in 28:
		var angle := float(index) * GOLDEN_ANGLE
		var cycle := fposmod(_time * 2.2 + float(index) * 0.6180339, 1.0)
		var pull := cycle * cycle * (3.0 - 2.0 * cycle)
		var radius := lerpf(1.9, 0.04, pull)
		var position := focus + Vector3(
			cos(angle + _time * 0.7) * radius,
			sin(angle * 1.7 + _time) * radius * 0.62,
			sin(angle * 1.3) * radius * 0.65
		)
		var alpha := sin(cycle * PI) * (0.65 + _charge_progress * 0.35)
		var size := lerpf(0.12, 0.055, pull) * (0.75 + _charge_progress * 0.5)
		var gold := Color(1.0, 0.67, 0.08, alpha * 0.85)
		var white := Color(1.0, 1.0, 0.66, alpha)
		_add_diamond(_charge_mesh, position, right, up, size, gold)
		_add_diamond(_charge_mesh, position, right, up, size * 0.46, white)
		var inward := (focus - position).normalized()
		_add_ribbon(
			_charge_mesh, position - inward * size * 2.8, position,
			size * 0.22, gold, right
		)
	# A few broken currents connect the surrounding charge directly to the weapon.
	for arc in 6:
		var angle := float(arc) * TAU / 6.0 + _time * 0.9
		var start := focus + Vector3(
			cos(angle) * 1.4, sin(angle * 1.3) * 0.85, sin(angle) * 0.8
		)
		var previous := start
		for segment in 4:
			var fraction := float(segment + 1) / 4.0
			var next := start.lerp(focus, fraction)
			next += (
				right * sin(_time * 30.0 + float(arc * 7 + segment * 5))
				* 0.12 * (1.0 - fraction)
			)
			var energy := Color(1.0, 0.85, 0.2, _charge_progress * 0.45)
			_add_ribbon(_charge_mesh, previous, next, 0.028, energy, right)
			previous = next
	_charge_mesh.surface_end()


func _draw_drill() -> void:
	_drill_mesh.clear_surfaces()
	_drill_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var fade := 1.0 - _dash_progress * 0.2
	# A tapered luminous core stays ahead of Foxy throughout the dash.
	for ring in 10:
		var start := float(ring) / 10.0
		var end := float(ring + 1) / 10.0
		for side in 12:
			var angle_a := float(side) * TAU / 12.0
			var angle_b := float(side + 1) * TAU / 12.0
			var a := _drill_point(start, angle_a, 0.76)
			var b := _drill_point(start, angle_b, 0.76)
			var c := _drill_point(end, angle_a, 0.76)
			var d := _drill_point(end, angle_b, 0.76)
			var warm := Color(1.0, 0.55 + start * 0.3, 0.08 + start * 0.5, 0.42 * fade)
			var bright := Color(1.0, 0.62 + end * 0.32, 0.16 + end * 0.6, 0.58 * fade)
			_add_triangle(_drill_mesh, a, b, c, warm, warm, bright)
			_add_triangle(_drill_mesh, b, d, c, warm, bright, bright)
	# Three broad helical vanes make the spearhead read as a rotating drill.
	for blade in 3:
		for segment in 16:
			var start := float(segment) / 16.0
			var end := float(segment + 1) / 16.0
			var angle_a := float(blade) * TAU / 3.0 + start * TAU * 1.55 + _time * 24.0
			var angle_b := float(blade) * TAU / 3.0 + end * TAU * 1.55 + _time * 24.0
			var inner_a := _drill_point(start, angle_a, 0.4)
			var outer_a := _drill_point(start, angle_a, 1.35)
			var inner_b := _drill_point(end, angle_b, 0.4)
			var outer_b := _drill_point(end, angle_b, 1.35)
			var core := Color(1.0, 1.0, 0.74, 0.78 * fade)
			var edge := Color(1.0, 0.62, 0.06, 0.62 * fade)
			_add_triangle(_drill_mesh, inner_a, outer_a, inner_b, core, edge, core)
			_add_triangle(_drill_mesh, outer_a, outer_b, inner_b, edge, edge, core)
	_drill_mesh.surface_end()


func _drill_point(progress: float, angle: float, radius_scale: float) -> Vector3:
	var radius := (0.35 * pow(1.0 - progress, 0.75) + 0.008) * radius_scale
	return Vector3(
		cos(angle) * radius,
		0.82 + sin(angle) * radius,
		-0.32 - progress * 1.45
	)


func _draw_lightning() -> void:
	_bolt_mesh.clear_surfaces()
	_bolt_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var camera := get_viewport().get_camera_3d()
	var view := Vector3(0.0, 3.0, 4.0)
	if is_instance_valid(camera):
		view = to_local(camera.global_position)
	var axis_start := Vector3(0.0, 0.82, -0.24)
	var axis_end := Vector3(0.0, 0.82, -3.2)
	_add_ribbon(
		_bolt_mesh, axis_start, axis_end, 0.16,
		Color(1.0, 0.58, 0.06, 0.3), view - axis_start
	)
	_add_ribbon(
		_bolt_mesh, axis_start, axis_end, 0.045,
		Color(1.0, 1.0, 0.82, 0.82), view - axis_start
	)
	for bolt in 3:
		for segment in 9:
			var start := float(segment) / 9.0
			var end := float(segment + 1) / 9.0
			var a := _bolt_point(bolt, segment)
			var b := _bolt_point(bolt, segment + 1)
			var glow := Color(1.0, 0.58, 0.04, (1.0 - start * 0.4) * 0.42)
			var core := Color(1.0, 1.0, 0.72, (1.0 - end * 0.18) * 0.98)
			_add_ribbon(_bolt_mesh, a, b, 0.21 * (1.0 - start * 0.45), glow, view - a)
			_add_ribbon(_bolt_mesh, a, b, 0.075 * (1.0 - start * 0.45), core, view - a)
	_bolt_mesh.surface_end()


func _bolt_point(bolt: int, segment: int) -> Vector3:
	var progress := float(segment) / 9.0
	var phase := float(bolt) * TAU / 3.0
	var jitter := sin(float(segment * 7 + bolt * 11) + _time * 42.0)
	var radius := lerpf(0.78, 0.025, progress) + jitter * 0.13 * (1.0 - progress)
	return Vector3(
		cos(phase) * radius,
		0.82 + sin(phase) * radius,
		-0.12 - progress * 3.1
	)


func _add_diamond(
	mesh: ImmediateMesh, at: Vector3, right: Vector3, up: Vector3,
	size: float, color: Color
) -> void:
	var top := at + up * size
	var bottom := at - up * size
	var left := at - right * size
	var right_edge := at + right * size
	_add_triangle(mesh, top, right_edge, bottom, color, color, color)
	_add_triangle(mesh, top, bottom, left, color, color, color)


func _add_ribbon(
	mesh: ImmediateMesh, start: Vector3, end: Vector3,
	width: float, color: Color, view: Vector3
) -> void:
	var side := (end - start).cross(view).normalized()
	if side.is_zero_approx():
		side = Vector3.RIGHT
	side *= width
	_add_triangle(mesh, start - side, start + side, end + side, color, color, color)
	_add_triangle(mesh, start - side, end + side, end - side, color, color, color)


func _add_triangle(
	mesh: ImmediateMesh, a: Vector3, b: Vector3, c: Vector3,
	color_a: Color, color_b: Color, color_c: Color
) -> void:
	mesh.surface_set_color(color_a)
	mesh.surface_add_vertex(a)
	mesh.surface_set_color(color_b)
	mesh.surface_add_vertex(b)
	mesh.surface_set_color(color_c)
	mesh.surface_add_vertex(c)
