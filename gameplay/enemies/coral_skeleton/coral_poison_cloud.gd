class_name CoralPoisonCloud
extends Node3D

const SMOKE_TEXTURE := preload("res://assets/sprites/effects/smoke/smoke_04.png")

var _source: Node
var _source_team: int = CombatTeams.ENEMY
var _radius: float = 2.0
var _remaining: float = 3.5
var _duration: float = 3.5
var _tick_interval: float = 0.9
var _tick_damage: float = 0.5
var _tick_cooldown: float = 0.1
var _fading: bool = false

var _area: Area3D
var _particles: GPUParticles3D
var _ground_mist: MeshInstance3D
var _ground_mist_material: StandardMaterial3D


func setup(
	owner_node: Node,
	owner_team: int,
	cloud_radius: float,
	cloud_duration: float,
	tick_interval: float,
	tick_damage: float
) -> void:
	_source = owner_node
	_source_team = owner_team
	_radius = maxf(0.4, cloud_radius)
	_duration = maxf(0.2, cloud_duration)
	_remaining = _duration
	_tick_interval = maxf(0.1, tick_interval)
	_tick_damage = maxf(0.0, tick_damage)


func _ready() -> void:
	_build_area()
	_build_ground_mist()
	_build_smoke_particles()


func _physics_process(delta: float) -> void:
	var step := maxf(0.0, delta)
	if _fading:
		return
	_remaining = maxf(0.0, _remaining - step)
	_tick_cooldown = maxf(0.0, _tick_cooldown - step)
	if _tick_cooldown <= 0.0:
		_tick_cooldown += _tick_interval
		_apply_poison_tick()
	if _remaining < 0.6 and is_instance_valid(_ground_mist_material):
		_ground_mist_material.albedo_color.a = 0.28 * clampf(_remaining / 0.6, 0.0, 1.0)
	if _remaining <= 0.0:
		_begin_fade_out()


func _build_area() -> void:
	_area = Area3D.new()
	_area.name = "PoisonArea"
	_area.collision_layer = 0
	_area.collision_mask = CombatLayers.PLAYER_HURTBOX
	_area.monitoring = true
	_area.monitorable = false
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = _radius
	shape.height = 1.8
	collision.shape = shape
	collision.position = Vector3(0.0, 0.9, 0.0)
	_area.add_child(collision)
	add_child(_area)


func _build_ground_mist() -> void:
	_ground_mist_material = StandardMaterial3D.new()
	_ground_mist_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ground_mist_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ground_mist_material.albedo_color = Color(0.28, 0.52, 0.18, 0.28)
	_ground_mist_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = _radius
	cylinder.bottom_radius = _radius
	cylinder.height = 0.03
	cylinder.radial_segments = 24
	cylinder.material = _ground_mist_material
	_ground_mist = MeshInstance3D.new()
	_ground_mist.name = "GroundMist"
	_ground_mist.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ground_mist.mesh = cylinder
	_ground_mist.position = Vector3(0.0, 0.03, 0.0)
	add_child(_ground_mist)


func _build_smoke_particles() -> void:
	_particles = GPUParticles3D.new()
	_particles.name = "PoisonSmoke"
	_particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_particles.amount = 26
	_particles.lifetime = 0.85
	_particles.local_coords = false
	_particles.visibility_aabb = AABB(
		Vector3(-_radius - 1.0, -0.5, -_radius - 1.0),
		Vector3((_radius + 1.0) * 2.0, 4.0, (_radius + 1.0) * 2.0)
	)
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(_radius * 0.65, 0.12, _radius * 0.65)
	process.direction = Vector3.UP
	process.spread = 28.0
	process.gravity = Vector3(0.0, 0.9, 0.0)
	process.initial_velocity_min = 0.35
	process.initial_velocity_max = 0.9
	process.damping_min = 0.4
	process.damping_max = 0.9
	process.scale_min = 0.85
	process.scale_max = 1.5
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.42, 0.68, 0.25, 0.72))
	gradient.set_color(1, Color(0.2, 0.36, 0.14, 0.0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = gradient
	process.color_ramp = ramp
	_particles.process_material = process
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.albedo_texture = SMOKE_TEXTURE
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	var quad := QuadMesh.new()
	quad.material = material
	quad.size = Vector2(0.75, 0.75)
	_particles.draw_pass_1 = quad
	add_child(_particles)
	_particles.emitting = true


func _apply_poison_tick() -> void:
	if _tick_damage <= 0.0 or not is_instance_valid(_area):
		return
	for body_area in _area.get_overlapping_areas():
		var hurtbox := body_area as HurtBox
		if hurtbox == null:
			continue
		var context := DamageContext.new()
		context.source = _source if is_instance_valid(_source) else self
		context.source_team = _source_team
		context.base_amount_hp = _tick_damage
		context.amount_hp = _tick_damage
		context.tag = &"poison"
		context.knockback_multiplier = 0.0
		hurtbox.take_damage(context)


func _begin_fade_out() -> void:
	_fading = true
	if is_instance_valid(_area):
		_area.monitoring = false
	if is_instance_valid(_ground_mist):
		_ground_mist.visible = false
	if is_instance_valid(_particles):
		_particles.emitting = false
		get_tree().create_timer(_particles.lifetime + 0.15).timeout.connect(queue_free)
	else:
		queue_free()
