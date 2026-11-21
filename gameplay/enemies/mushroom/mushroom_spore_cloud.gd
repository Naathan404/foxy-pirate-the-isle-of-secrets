class_name MushroomSporeCloud
extends Node3D
## Gradually emitted spore cloud that marks its area on the ground and poisons players inside.

const SPORE_TEXTURE := preload("res://assets/sprites/enemies/mushroom/spore_mote.png")
const GROUND_MIST_SHADER := preload("res://gameplay/enemies/mushroom/spore_ground_mist.gdshader")
const POISON_CLOUD_GROUP := &"mushroom_spore_cloud"
const DEFAULT_SPORE_COUNT := 240
const DEFAULT_MIST_COUNT := 64
const DEFAULT_SPORE_LIFETIME := 2.0
const DEFAULT_MIST_LIFETIME := 2.2
const MIN_EMISSION_RATIO := 0.05
const SOFT_MIST_TEXTURE_SIZE_PIXELS := 128
const SOFT_MIST_TEXTURE_FALLOFF := 4.6
const SOFT_MIST_TEXTURE_MAX_ALPHA := 0.24
const SPORE_TEXTURE_SIZE_PIXELS := 128
const POISON_AREA_HEIGHT := 1.8
const DEFAULT_GROUND_MIST_OPACITY := 0.26
const DEFAULT_GROUND_MIST_SCALE := 2.45
const DEFAULT_VISUAL_SPREAD_SCALE := 1.15
const FADE_OUT_SECONDS := 0.75
const MIST_ORBIT_VELOCITY_MIN := 0.16
const MIST_ORBIT_VELOCITY_MAX := 0.42
const MIST_GLOW_START_COLOR := Color(0.72, 0.42, 0.94, 0.48)
const MIST_GLOW_END_COLOR := Color(0.38, 0.2, 0.62, 0.0)
const SPORE_INITIAL_VELOCITY_MIN := 0.42
const SPORE_INITIAL_VELOCITY_MAX := 1.05
const SPORE_GRAVITY_Y := 0.32
const SPORE_ORBIT_VELOCITY_MIN := 0.22
const SPORE_ORBIT_VELOCITY_MAX := 0.58
const SPORE_SCALE_MIN := 0.35
const SPORE_SCALE_MAX := 1.05
const SPORE_GLOW_START_COLOR := Color(0.76, 0.46, 1.0, 0.98)
const SPORE_GLOW_END_COLOR := Color(0.42, 0.22, 0.72, 0.0)

static var _soft_mist_texture: ImageTexture
static var _purple_spore_texture: ImageTexture

var _source_ref: WeakRef
var _radius: float = 2.6
var _remaining: float = 0.0
var _ramp_seconds: float = 0.8
var _elapsed: float = 0.0
var _fading: bool = false
var _fade_remaining: float = 0.0
var _damage_enabled: bool = false
var _tick_interval: float = 0.85
var _tick_damage: float = 1.0
var _tick_remaining: float = 0.0
var _spore_count: int = DEFAULT_SPORE_COUNT
var _mist_count: int = DEFAULT_MIST_COUNT
var _spore_lifetime: float = DEFAULT_SPORE_LIFETIME
var _mist_lifetime: float = DEFAULT_MIST_LIFETIME
var _ground_mist_opacity: float = DEFAULT_GROUND_MIST_OPACITY
var _ground_mist_scale: float = DEFAULT_GROUND_MIST_SCALE
var _visual_spread_scale: float = DEFAULT_VISUAL_SPREAD_SCALE
var _query_shape: CylinderShape3D
var _particles: GPUParticles3D
var _spores: GPUParticles3D
var _ground_mist: MeshInstance3D
var _ground_mist_material: ShaderMaterial


static func _create_soft_mist_texture() -> ImageTexture:
	if is_instance_valid(_soft_mist_texture):
		return _soft_mist_texture
	var image := Image.create(
		SOFT_MIST_TEXTURE_SIZE_PIXELS, SOFT_MIST_TEXTURE_SIZE_PIXELS, false, Image.FORMAT_RGBA8
	)
	var texture_center := float(SOFT_MIST_TEXTURE_SIZE_PIXELS - 1) * 0.5
	var texture_radius := float(SOFT_MIST_TEXTURE_SIZE_PIXELS) * 0.5
	for y in range(SOFT_MIST_TEXTURE_SIZE_PIXELS):
		var offset_y := (float(y) - texture_center) / texture_radius
		for x in range(SOFT_MIST_TEXTURE_SIZE_PIXELS):
			var offset_x := (float(x) - texture_center) / texture_radius
			var distance_squared := offset_x * offset_x + offset_y * offset_y
			var alpha := exp(-distance_squared * SOFT_MIST_TEXTURE_FALLOFF)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, alpha * SOFT_MIST_TEXTURE_MAX_ALPHA))
	_soft_mist_texture = ImageTexture.create_from_image(image)
	return _soft_mist_texture


static func _create_purple_spore_texture() -> ImageTexture:
	if is_instance_valid(_purple_spore_texture):
		return _purple_spore_texture
	var image := SPORE_TEXTURE.get_image()
	image.resize(SPORE_TEXTURE_SIZE_PIXELS, SPORE_TEXTURE_SIZE_PIXELS, Image.INTERPOLATE_LANCZOS)
	for y in range(SPORE_TEXTURE_SIZE_PIXELS):
		for x in range(SPORE_TEXTURE_SIZE_PIXELS):
			var source_color := image.get_pixel(x, y)
			var brightness := maxf(maxf(source_color.r, source_color.g), source_color.b)
			image.set_pixel(x, y, Color(1.0, 1.0, 1.0, source_color.a * brightness))
	_purple_spore_texture = ImageTexture.create_from_image(image)
	return _purple_spore_texture


func _ready() -> void:
	add_to_group(POISON_CLOUD_GROUP)
	_build_query_shape()
	_build_ground_mist()
	_build_smoke_particles()


func _physics_process(delta: float) -> void:
	var step := maxf(delta, 0.0)
	if _fading:
		_update_fade_out(step)
		return
	_elapsed += step
	_remaining -= step
	var progress := clampf(_elapsed / _ramp_seconds, 0.0, 1.0)
	var ratio := lerpf(MIN_EMISSION_RATIO, 1.0, progress)
	_particles.amount_ratio = ratio
	_spores.amount_ratio = ratio
	if is_instance_valid(_ground_mist_material):
		_ground_mist_material.set_shader_parameter("opacity", _ground_mist_opacity * progress)
	if _remaining <= 0.0:
		finish()
		return
	if _damage_enabled:
		_tick_remaining -= step
		if _tick_remaining <= 0.0:
			_tick_remaining = _tick_interval
			_apply_poison_tick()


func setup(
	source: Variant,
	radius: float,
	duration_seconds: float,
	ramp_seconds: float,
	tick_interval_seconds: float,
	tick_damage: float
) -> void:
	_source_ref = (
		weakref(source)
		if source != null and is_instance_valid(source) and source is Node3D
		else null
	)
	_radius = maxf(0.4, radius)
	_remaining = maxf(0.2, duration_seconds)
	_ramp_seconds = maxf(0.01, ramp_seconds)
	_tick_interval = maxf(0.1, tick_interval_seconds)
	_tick_damage = maxf(0.0, tick_damage)


func configure_visuals(
	spore_count: int,
	mist_count: int,
	spore_lifetime: float,
	mist_lifetime: float,
	ground_mist_opacity: float,
	ground_mist_scale: float,
	visual_spread_scale: float = DEFAULT_VISUAL_SPREAD_SCALE
) -> void:
	_spore_count = maxi(1, spore_count)
	_mist_count = maxi(1, mist_count)
	_spore_lifetime = maxf(0.1, spore_lifetime)
	_mist_lifetime = maxf(0.1, mist_lifetime)
	_ground_mist_opacity = clampf(ground_mist_opacity, 0.0, 1.0)
	_ground_mist_scale = maxf(0.5, ground_mist_scale)
	_visual_spread_scale = maxf(0.5, visual_spread_scale)


func activate_poison() -> void:
	if not _fading:
		_damage_enabled = true
		_tick_remaining = 0.0


func is_fading() -> bool:
	return _fading


func get_radius() -> float:
	return _radius


func get_visual_radius() -> float:
	return _radius * _visual_spread_scale


func finish() -> void:
	if _fading:
		return
	_fading = true
	_fade_remaining = FADE_OUT_SECONDS
	_particles.emitting = false
	_spores.emitting = false


func _build_query_shape() -> void:
	_query_shape = CylinderShape3D.new()
	_query_shape.radius = _radius
	_query_shape.height = POISON_AREA_HEIGHT


func _build_ground_mist() -> void:
	_ground_mist_material = ShaderMaterial.new()
	_ground_mist_material.shader = GROUND_MIST_SHADER
	_ground_mist_material.set_shader_parameter("opacity", 0.0)
	_ground_mist_material.set_shader_parameter("seed_offset", randf_range(0.0, 100.0))
	var plane := PlaneMesh.new()
	var span := get_visual_radius() * _ground_mist_scale
	plane.size = Vector2(span, span)
	plane.material = _ground_mist_material
	_ground_mist = MeshInstance3D.new()
	_ground_mist.name = "GroundMist"
	_ground_mist.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ground_mist.mesh = plane
	_ground_mist.position = Vector3(0.0, 0.025, 0.0)
	add_child(_ground_mist)


func _update_fade_out(step: float) -> void:
	_fade_remaining = maxf(0.0, _fade_remaining - step)
	var ratio := clampf(_fade_remaining / FADE_OUT_SECONDS, 0.0, 1.0)
	if is_instance_valid(_ground_mist_material):
		_ground_mist_material.set_shader_parameter("opacity", _ground_mist_opacity * ratio)
	_set_particles_fade_alpha(_particles, ratio)
	_set_particles_fade_alpha(_spores, ratio)
	if _fade_remaining <= 0.0:
		queue_free()


func _set_particles_fade_alpha(particles: GPUParticles3D, alpha_value: float) -> void:
	if not is_instance_valid(particles):
		return
	var quad := particles.draw_pass_1 as QuadMesh
	if quad == null:
		return
	var mat := quad.material as StandardMaterial3D
	if mat != null:
		mat.albedo_color.a = alpha_value


func _apply_poison_tick() -> void:
	if _tick_damage <= 0.0 or not is_inside_tree():
		return
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _query_shape
	query.transform = Transform3D(
		Basis.IDENTITY, global_position + Vector3.UP * (POISON_AREA_HEIGHT * 0.5)
	)
	query.collision_mask = CombatLayers.PLAYER_HURTBOX
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var hits := get_world_3d().direct_space_state.intersect_shape(query, 16)
	if hits.is_empty():
		return
	var hit_actors: Dictionary = {}
	for hit in hits:
		var hurtbox := hit.get("collider") as HurtBox
		if hurtbox == null or not is_instance_valid(hurtbox.actor):
			continue
		var actor_id := hurtbox.actor.get_instance_id()
		if hit_actors.has(actor_id):
			continue
		hit_actors[actor_id] = true
		var damage := DamageContext.new()
		var live_source: Object = _source_ref.get_ref() if _source_ref != null else null
		damage.source = (live_source as Node3D) if is_instance_valid(live_source) else self
		damage.source_team = CombatTeams.ENEMY
		damage.base_amount_hp = _tick_damage
		damage.amount_hp = _tick_damage
		damage.tag = &"poison"
		damage.knockback_multiplier = 0.0
		hurtbox.take_damage(damage)


func _build_smoke_particles() -> void:
	_particles = _create_particles(
		"PoisonMist", _create_soft_mist_texture(), _mist_count, _mist_lifetime
	)
	_particles.amount_ratio = MIN_EMISSION_RATIO
	var mist_mesh := _particles.draw_pass_1 as QuadMesh
	mist_mesh.size = Vector2(1.6, 1.6)
	var mist_process := _particles.process_material as ParticleProcessMaterial
	mist_process.initial_velocity_min = 0.1
	mist_process.initial_velocity_max = 0.32
	mist_process.gravity = Vector3(0.0, 0.12, 0.0)
	mist_process.scale_min = 0.65
	mist_process.scale_max = 1.15
	mist_process.orbit_velocity_min = MIST_ORBIT_VELOCITY_MIN
	mist_process.orbit_velocity_max = MIST_ORBIT_VELOCITY_MAX
	mist_process.color_ramp = _color_ramp(MIST_GLOW_START_COLOR, MIST_GLOW_END_COLOR)
	add_child(_particles)
	_particles.emitting = true

	_spores = _create_particles(
		"FloatingSpores", _create_purple_spore_texture(), _spore_count, _spore_lifetime
	)
	_spores.amount_ratio = MIN_EMISSION_RATIO
	var spore_mesh := _spores.draw_pass_1 as QuadMesh
	spore_mesh.size = Vector2(0.65, 0.65)
	var material := spore_mesh.material as StandardMaterial3D
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	var spore_process := _spores.process_material as ParticleProcessMaterial
	spore_process.initial_velocity_min = SPORE_INITIAL_VELOCITY_MIN
	spore_process.initial_velocity_max = SPORE_INITIAL_VELOCITY_MAX
	spore_process.gravity = Vector3(0.0, SPORE_GRAVITY_Y, 0.0)
	spore_process.orbit_velocity_min = SPORE_ORBIT_VELOCITY_MIN
	spore_process.orbit_velocity_max = SPORE_ORBIT_VELOCITY_MAX
	spore_process.scale_min = SPORE_SCALE_MIN
	spore_process.scale_max = SPORE_SCALE_MAX
	spore_process.color_ramp = _color_ramp(SPORE_GLOW_START_COLOR, SPORE_GLOW_END_COLOR)
	add_child(_spores)
	_spores.emitting = true


func _create_particles(
	node_name: String, texture: Texture2D, count: int, lifetime: float
) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.name = node_name
	particles.emitting = false
	particles.amount = count
	particles.lifetime = lifetime
	particles.local_coords = true
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var visual_radius := get_visual_radius()
	particles.visibility_aabb = AABB(
		Vector3(-visual_radius - 1.5, -0.5, -visual_radius - 1.5),
		Vector3((visual_radius + 1.5) * 2.0, 4.0, (visual_radius + 1.5) * 2.0)
	)
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	process.emission_ring_axis = Vector3.UP
	process.emission_ring_height = 0.3
	process.emission_ring_radius = visual_radius * 0.92
	process.emission_ring_inner_radius = 0.0
	process.direction = Vector3.UP
	process.spread = 45.0
	particles.process_material = process
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	material.albedo_texture = texture
	var mesh := QuadMesh.new()
	mesh.material = material
	particles.draw_pass_1 = mesh
	return particles


func _color_ramp(start: Color, end: Color) -> GradientTexture1D:
	var gradient := Gradient.new()
	gradient.set_color(0, start)
	gradient.set_color(1, end)
	var ramp := GradientTexture1D.new()
	ramp.gradient = gradient
	return ramp
