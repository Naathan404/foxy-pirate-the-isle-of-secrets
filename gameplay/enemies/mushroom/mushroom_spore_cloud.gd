extends Node3D
## A gradually emitted cloud that applies poison while the player is inside it.

const SPORE_TEXTURE := preload("res://assets/sprites/enemies/mushroom/spore_mote.png")
const MIST_TEXTURE := preload("res://assets/sprites/enemies/mushroom/spore_mist.png")
const SPORE_COUNT := 240
const MIST_COUNT := 18
const SPORE_LIFETIME := 2.0
const MIST_LIFETIME := 2.2

const MIN_EMISSION_RATIO := 0.05
const POISON_AREA_HEIGHT := 1.8

var _source: Node3D
var _radius: float = 2.6
var _remaining: float = 0.0
var _ramp_seconds: float = 1.6
var _elapsed: float = 0.0
var _fading: bool = false
var _damage_enabled: bool = false
var _tick_interval: float = 1.0
var _tick_damage: float = 0.5
var _tick_remaining: float = 0.0
var _area: Area3D
var _particles: GPUParticles3D
var _spores: GPUParticles3D


func setup(
	source: Node3D,
	radius: float,
	duration_seconds: float,
	ramp_seconds: float,
	tick_interval_seconds: float,
	tick_damage: float
) -> void:
	_source = source
	_radius = radius
	_remaining = duration_seconds
	_ramp_seconds = maxf(0.01, ramp_seconds)
	_tick_interval = maxf(0.1, tick_interval_seconds)
	_tick_damage = maxf(0.0, tick_damage)


func _ready() -> void:
	_build_area()
	_build_smoke_particles()


func _physics_process(delta: float) -> void:
	if _fading:
		return
	_elapsed += maxf(delta, 0.0)
	_remaining -= maxf(delta, 0.0)
	var progress := clampf(_elapsed / _ramp_seconds, 0.0, 1.0)
	var ratio := lerpf(MIN_EMISSION_RATIO, 1.0, progress)
	_particles.amount_ratio = ratio
	_spores.amount_ratio = ratio
	if _remaining <= 0.0:
		finish()
		return
	if _damage_enabled:
		_tick_remaining -= maxf(delta, 0.0)
		if _tick_remaining <= 0.0:
			_tick_remaining = _tick_interval
			_apply_poison_tick()


func activate_poison() -> void:
	if not _fading:
		_damage_enabled = true
		_tick_remaining = 0.0


func finish() -> void:
	if _fading:
		return
	_fading = true
	_area.set_deferred("monitoring", false)
	_particles.emitting = false
	_spores.emitting = false
	get_tree().create_timer(maxf(MIST_LIFETIME, SPORE_LIFETIME) + 0.15, false).timeout.connect(
		queue_free
	)


func _build_area() -> void:
	_area = Area3D.new()
	_area.name = "PoisonArea"
	_area.collision_layer = 0
	_area.collision_mask = CombatLayers.PLAYER_HURTBOX
	_area.monitorable = false
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = _radius
	shape.height = POISON_AREA_HEIGHT
	collision.shape = shape
	collision.position.y = POISON_AREA_HEIGHT * 0.5
	_area.add_child(collision)
	add_child(_area)


func _apply_poison_tick() -> void:
	if _tick_damage <= 0.0:
		return
	var hit_actors: Dictionary = {}
	for overlapping_area in _area.get_overlapping_areas():
		var hurtbox := overlapping_area as HurtBox
		if hurtbox == null or not is_instance_valid(hurtbox.actor):
			continue
		var actor_id := hurtbox.actor.get_instance_id()
		if hit_actors.has(actor_id):
			continue
		hit_actors[actor_id] = true
		var damage := DamageContext.new()
		damage.source = _source if is_instance_valid(_source) else self
		damage.source_team = CombatTeams.ENEMY
		damage.base_amount_hp = _tick_damage
		damage.amount_hp = _tick_damage
		damage.tag = &"poison"
		damage.knockback_multiplier = 0.0
		hurtbox.take_damage(damage)


func _build_smoke_particles() -> void:
	_particles = _create_particles("PoisonMist", MIST_TEXTURE, MIST_COUNT, MIST_LIFETIME)
	_particles.amount_ratio = MIN_EMISSION_RATIO
	var mist_mesh := _particles.draw_pass_1 as QuadMesh
	mist_mesh.size = Vector2(1.6, 1.6)
	var mist_process := _particles.process_material as ParticleProcessMaterial
	mist_process.initial_velocity_min = 0.1
	mist_process.initial_velocity_max = 0.32
	mist_process.gravity = Vector3(0.0, 0.12, 0.0)
	mist_process.scale_min = 0.65
	mist_process.scale_max = 1.15
	mist_process.color_ramp = _color_ramp(
		Color(0.68, 0.43, 0.78, 0.3), Color(0.32, 0.18, 0.42, 0.0)
	)
	add_child(_particles)
	_particles.emitting = true

	_spores = _create_particles("FloatingSpores", SPORE_TEXTURE, SPORE_COUNT, SPORE_LIFETIME)
	_spores.amount_ratio = MIN_EMISSION_RATIO
	var spore_mesh := _spores.draw_pass_1 as QuadMesh
	spore_mesh.size = Vector2(0.65, 0.65)
	var material := spore_mesh.material as StandardMaterial3D
	material.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	var spore_process := _spores.process_material as ParticleProcessMaterial
	spore_process.initial_velocity_min = 0.12
	spore_process.initial_velocity_max = 0.65
	spore_process.gravity = Vector3(0.0, 0.2, 0.0)
	spore_process.scale_min = 0.55
	spore_process.scale_max = 1.35
	spore_process.color_ramp = _color_ramp(Color(0.82, 1.0, 0.5, 0.85), Color(0.65, 0.34, 0.9, 0.0))
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
	particles.local_coords = false
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particles.visibility_aabb = AABB(
		Vector3(-_radius - 1.0, -0.5, -_radius - 1.0),
		Vector3((_radius + 1.0) * 2.0, 4.0, (_radius + 1.0) * 2.0)
	)
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(_radius * 0.65, 0.15, _radius * 0.65)
	process.direction = Vector3.UP
	process.spread = 35.0
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
