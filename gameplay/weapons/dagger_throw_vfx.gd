extends Node3D
## World-space visuals survive the projectile just long enough to fade out.

const ENERGY_SHADER: Shader = preload("res://gameplay/weapons/dagger_energy.gdshader")
const POOL_SIZE: int = 8
const SPARK_COUNT: int = 24

@export var outbound_color: Color = Color(1.0, 0.52, 0.12)
@export var return_color: Color = Color(0.25, 0.85, 1.0)
@export_range(0.05, 0.5, 0.01) var trail_lifetime: float = 0.19
@export_range(0.02, 0.5, 0.01) var trail_width: float = 0.19
@export_range(0.05, 0.4, 0.01) var ghost_lifetime: float = 0.14

var _source: AnimatedSprite3D
var _flying: bool = false
var _returning: bool = false
var _elapsed: float = 0.0
var _fade_age: float = 0.0
var _sample_clock: float = 0.0
var _ghost_clock: float = 0.0
var _next_burst: int = 0
var _next_ghost: int = 0
var _next_spark: int = 0
var _last_position: Vector3
var _points: Array[Vector3] = []
var _point_ages: Array[float] = []
var _ghosts: Array[Sprite3D] = []
var _ghost_ages: Array[float] = []
var _bursts: Array[MeshInstance3D] = []
var _burst_ages: Array[float] = []
var _burst_sizes: Array[float] = []
var _sparks: Array[MeshInstance3D] = []
var _spark_ages: Array[float] = []
var _spark_velocities: Array[Vector3] = []
var _ribbon_mesh := ImmediateMesh.new()
var _ribbon_material: ShaderMaterial
var _aura: MeshInstance3D
var _glint: MeshInstance3D


func _ready() -> void:
	var ribbon := MeshInstance3D.new()
	ribbon.name = "EnergyRibbon"
	ribbon.mesh = _ribbon_mesh
	ribbon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ribbon_material = _make_material(2)
	ribbon.material_override = _ribbon_material
	add_child(ribbon)
	_aura = _make_quad("BladeHalo", 0)
	_glint = _make_quad("BladeGlint", 1)
	_aura.hide()
	_glint.hide()
	for index in POOL_SIZE:
		var burst := _make_quad("Burst%d" % index, index % 2)
		burst.hide()
		_bursts.append(burst)
		_burst_ages.append(1.0)
		_burst_sizes.append(1.0)
		var ghost := Sprite3D.new()
		ghost.name = "BladeEcho%d" % index
		ghost.shaded = false
		ghost.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ghost)
		ghost.hide()
		_ghosts.append(ghost)
		_ghost_ages.append(ghost_lifetime)
	for index in SPARK_COUNT:
		var spark := _make_quad("EnergyChip%d" % index, 1)
		spark.hide()
		_sparks.append(spark)
		_spark_ages.append(1.0)
		_spark_velocities.append(Vector3.ZERO)
	set_process(false)


func start(source: AnimatedSprite3D) -> void:
	_source = source
	# Remain in the same world, independent of the dagger's lifetime/transform.
	reparent(source.get_parent().get_parent())
	top_level = true
	global_transform = Transform3D.IDENTITY
	_flying = true
	_last_position = source.global_position
	_aura.show()
	_glint.show()
	burst(_last_position, 1.7)
	set_process(true)


func turn() -> void:
	if _returning:
		return
	_returning = true
	burst(_last_position, 1.3)


func impact(at: Vector3) -> void:
	burst(at, 1.5)


func finish(caught: bool = false) -> void:
	if not _flying:
		return
	if is_instance_valid(_source):
		_last_position = _source.global_position
	if caught:
		burst(_last_position, 1.8)
	_flying = false
	_source = null
	_aura.hide()
	_glint.hide()


func burst(at: Vector3, size: float) -> void:
	# One slash ring and one hot glint; reuse nodes even on rapid multi-hits.
	for shape_index in 2:
		var index := _next_burst
		_next_burst = (_next_burst + 1) % POOL_SIZE
		var mesh := _bursts[index]
		mesh.global_position = at
		_burst_ages[index] = 0.0
		_burst_sizes[index] = size if shape_index == 0 else size * 0.7
		var material := mesh.material_override as ShaderMaterial
		material.set_shader_parameter("tint", _color())
		material.set_shader_parameter("progress", 0.0)
		mesh.show()
	for chip in 6:
		var index := _next_spark
		_next_spark = (_next_spark + 1) % SPARK_COUNT
		var angle := float(chip) * TAU / 6.0 + _elapsed * 5.0
		_spark_ages[index] = 0.0
		_spark_velocities[index] = Vector3(cos(angle), sin(angle), sin(angle + 0.7) * 0.4)
		_spark_velocities[index] *= size * 1.8
		_sparks[index].global_position = at
		_sparks[index].show()
		var material := _sparks[index].material_override as ShaderMaterial
		material.set_shader_parameter("tint", _color())
		material.set_shader_parameter("progress", 0.0)


func _process(delta: float) -> void:
	_elapsed += delta
	if _flying and not is_instance_valid(_source):
		finish()
	if _flying:
		_update_blade(delta)
	else:
		_fade_age += delta
		if _fade_age > maxf(0.4, maxf(trail_lifetime, ghost_lifetime)):
			queue_free()
			return
	_update_trail(delta)
	_update_echoes(delta)
	_update_bursts(delta)
	_update_sparks(delta)


func _update_blade(delta: float) -> void:
	_last_position = _source.global_position
	_sample_clock -= delta
	if _sample_clock <= 0.0:
		_points.append(_last_position)
		_point_ages.append(0.0)
		_sample_clock = 0.012
	_ghost_clock -= delta
	if _ghost_clock <= 0.0:
		_stamp_echo()
		_ghost_clock = 0.035
	_aura.global_position = _last_position
	_glint.global_position = _last_position
	_face_camera(_aura, 0.92)
	_face_camera(_glint, 0.65 + sin(_elapsed * 28.0) * 0.08)
	for mesh in [_aura, _glint]:
		var material := mesh.material_override as ShaderMaterial
		material.set_shader_parameter("tint", _color())
		material.set_shader_parameter("phase", _elapsed * -18.0)
		material.set_shader_parameter("energy", 1.25)


func _update_trail(delta: float) -> void:
	for index in _point_ages.size():
		_point_ages[index] += delta
	while not _point_ages.is_empty() and _point_ages[0] >= trail_lifetime:
		_point_ages.pop_front()
		_points.pop_front()
	_ribbon_mesh.clear_surfaces()
	if _points.size() < 2:
		return
	_ribbon_material.set_shader_parameter("tint", _color())
	var camera := get_viewport().get_camera_3d()
	_ribbon_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for index in _points.size():
		var previous := _points[maxi(index - 1, 0)]
		var next := _points[mini(index + 1, _points.size() - 1)]
		var direction := (next - previous).normalized()
		var view := Vector3.FORWARD
		if camera != null:
			view = (camera.global_position - _points[index]).normalized()
		var side := direction.cross(view).normalized()
		if side.is_zero_approx():
			side = Vector3.UP
		var remaining := clampf(1.0 - _point_ages[index] / trail_lifetime, 0.0, 1.0)
		var along := float(index) / float(_points.size() - 1)
		var width := trail_width * remaining
		_ribbon_mesh.surface_set_color(Color(1, 1, 1, remaining))
		_ribbon_mesh.surface_set_uv(Vector2(along, 0))
		_ribbon_mesh.surface_add_vertex(_points[index] - side * width)
		_ribbon_mesh.surface_set_uv(Vector2(along, 1))
		_ribbon_mesh.surface_add_vertex(_points[index] + side * width)
	_ribbon_mesh.surface_end()


func _stamp_echo() -> void:
	var ghost := _ghosts[_next_ghost]
	_ghost_ages[_next_ghost] = 0.0
	_next_ghost = (_next_ghost + 1) % POOL_SIZE
	ghost.texture = _source.sprite_frames.get_frame_texture(_source.animation, _source.frame)
	ghost.pixel_size = _source.pixel_size
	ghost.billboard = _source.billboard
	ghost.offset = _source.offset
	ghost.flip_h = _source.flip_h
	ghost.flip_v = _source.flip_v
	ghost.global_transform = _source.global_transform
	ghost.modulate = Color(_color(), 0.32)
	ghost.show()


func _update_echoes(delta: float) -> void:
	for index in POOL_SIZE:
		_ghost_ages[index] += delta
		var remaining := clampf(1.0 - _ghost_ages[index] / ghost_lifetime, 0.0, 1.0)
		_ghosts[index].modulate.a = remaining * remaining * 0.32
		_ghosts[index].visible = remaining > 0.0


func _update_bursts(delta: float) -> void:
	for index in POOL_SIZE:
		_burst_ages[index] += delta
		var progress := clampf(_burst_ages[index] / 0.28, 0.0, 1.0)
		var mesh := _bursts[index]
		mesh.visible = progress < 1.0
		if not mesh.visible:
			continue
		var material := mesh.material_override as ShaderMaterial
		material.set_shader_parameter("progress", progress)
		material.set_shader_parameter("phase", _elapsed * 9.0)
		var expansion := 0.25 + (1.0 - pow(1.0 - progress, 3.0)) * 0.75
		_face_camera(mesh, _burst_sizes[index] * expansion)


func _face_camera(mesh: MeshInstance3D, size: float) -> void:
	var camera := get_viewport().get_camera_3d()
	mesh.global_basis = camera.global_basis.orthonormalized() if camera != null else Basis.IDENTITY
	mesh.scale = Vector3.ONE * size


func _update_sparks(delta: float) -> void:
	for index in SPARK_COUNT:
		_spark_ages[index] += delta
		var progress := clampf(_spark_ages[index] / 0.3, 0.0, 1.0)
		var spark := _sparks[index]
		spark.visible = progress < 1.0
		if not spark.visible:
			continue
		spark.global_position += _spark_velocities[index] * delta
		_spark_velocities[index] *= exp(-7.0 * delta)
		_face_camera(spark, 0.32 * (1.0 - progress))
		var velocity := _spark_velocities[index]
		var angle := atan2(velocity.dot(spark.global_basis.y), velocity.dot(spark.global_basis.x))
		spark.rotate_object_local(Vector3.BACK, angle)
		spark.scale *= Vector3(1.8, 0.5, 1.0)
		var material := spark.material_override as ShaderMaterial
		material.set_shader_parameter("progress", progress)


func _color() -> Color:
	return return_color if _returning else outbound_color


func _make_material(shape: int) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = ENERGY_SHADER
	material.set_shader_parameter("shape", shape)
	return material


func _make_quad(label: String, shape: int) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.name = label
	mesh.mesh = QuadMesh.new()
	mesh.material_override = _make_material(shape)
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mesh)
	return mesh
