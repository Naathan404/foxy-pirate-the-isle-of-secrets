class_name CoralPoisonMortar
extends Node3D

const VFX := preload("res://gameplay/enemies/coral_skeleton/coral_skeleton_vfx.tscn")
const POISON_CLOUD_SCRIPT := preload(
	"res://gameplay/enemies/coral_skeleton/coral_poison_cloud.gd"
)
const SHADOW_OFFSET := 0.025

var _source: Node
var _source_team: int = CombatTeams.ENEMY
var _start: Vector3 = Vector3.ZERO
var _target: Vector3 = Vector3.ZERO
var _duration: float = 1.1
var _arc_height: float = 4.5
var _impact_damage: float = 2.0
var _cloud_radius: float = 2.0
var _cloud_duration: float = 3.5
var _tick_interval: float = 0.9
var _tick_damage: float = 0.5
var _elapsed: float = 0.0
var _detonated: bool = false

var _mesh: MeshInstance3D
var _shadow: MeshInstance3D
var _landing_ring: MeshInstance3D
var _trail: GPUParticles3D
var _hitbox: HitBox


func setup(
	owner_node: Node,
	owner_team: int,
	start_position: Vector3,
	target_ground: Vector3,
	flight_duration: float,
	arc_height: float,
	impact_damage: float
) -> void:
	_source = owner_node
	_source_team = owner_team
	_start = start_position
	_target = target_ground
	_duration = maxf(0.15, flight_duration)
	_arc_height = maxf(0.5, arc_height)
	_impact_damage = maxf(0.0, impact_damage)


func configure_poison(
	cloud_radius: float, cloud_duration: float, tick_interval: float, tick_damage: float
) -> void:
	_cloud_radius = maxf(0.4, cloud_radius)
	_cloud_duration = maxf(0.2, cloud_duration)
	_tick_interval = maxf(0.1, tick_interval)
	_tick_damage = maxf(0.0, tick_damage)


func _ready() -> void:
	global_position = _start
	_build_visuals()
	_build_hitbox()
	_update_flight_visuals(0.0)


func _physics_process(delta: float) -> void:
	if _detonated:
		return
	_elapsed = minf(_duration, _elapsed + maxf(0.0, delta))
	var t := _elapsed / _duration
	global_position = _start.lerp(_target, t) + Vector3.UP * sin(PI * t) * _arc_height
	_update_flight_visuals(t)
	if t >= 1.0:
		_detonate()


func _build_visuals() -> void:
	var sphere_mat := StandardMaterial3D.new()
	sphere_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sphere_mat.albedo_color = Color(0.42, 0.72, 0.24, 1.0)
	var sphere := SphereMesh.new()
	sphere.radius = 0.28
	sphere.height = 0.56
	sphere.material = sphere_mat
	_mesh = MeshInstance3D.new()
	_mesh.name = "Mesh"
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mesh.mesh = sphere
	add_child(_mesh)

	var shadow_mat := StandardMaterial3D.new()
	shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shadow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shadow_mat.albedo_color = Color(0.03, 0.02, 0.02, 0.42)
	shadow_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var shadow_sphere := SphereMesh.new()
	shadow_sphere.radius = 0.34
	shadow_sphere.height = 0.68
	shadow_sphere.material = shadow_mat
	_shadow = MeshInstance3D.new()
	_shadow.name = "Shadow"
	_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_shadow.mesh = shadow_sphere
	_shadow.top_level = true
	add_child(_shadow)

	var ring_mat := StandardMaterial3D.new()
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.albedo_color = Color(0.42, 0.75, 0.24, 0.55)
	var torus := TorusMesh.new()
	torus.inner_radius = maxf(0.1, _cloud_radius - 0.08)
	torus.outer_radius = _cloud_radius
	torus.rings = 28
	torus.ring_segments = 6
	torus.material = ring_mat
	_landing_ring = MeshInstance3D.new()
	_landing_ring.name = "LandingRing"
	_landing_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_landing_ring.mesh = torus
	_landing_ring.top_level = true
	add_child(_landing_ring)
	_landing_ring.global_position = _target + Vector3.UP * 0.04

	_trail = GPUParticles3D.new()
	_trail.name = "Trail"
	_trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_trail.amount = 20
	_trail.lifetime = 0.26
	_trail.local_coords = false
	_trail.visibility_aabb = AABB(Vector3(-4, -4, -4), Vector3(8, 8, 8))
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3.ZERO
	process.spread = 180.0
	process.gravity = Vector3(0.0, 0.4, 0.0)
	process.initial_velocity_min = 0.05
	process.initial_velocity_max = 0.35
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.48, 0.76, 0.28, 0.9))
	gradient.set_color(1, Color(0.22, 0.38, 0.14, 0.0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = gradient
	process.color_ramp = ramp
	_trail.process_material = process
	var trail_mat := StandardMaterial3D.new()
	trail_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	trail_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	trail_mat.vertex_color_use_as_albedo = true
	trail_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	var quad := QuadMesh.new()
	quad.material = trail_mat
	quad.size = Vector2(0.24, 0.24)
	_trail.draw_pass_1 = quad
	add_child(_trail)
	_trail.emitting = true


func _build_hitbox() -> void:
	_hitbox = HitBox.new()
	_hitbox.name = "ImpactHitBox"
	_hitbox.actor = _source if is_instance_valid(_source) else self
	_hitbox.team = _source_team
	_hitbox.monitoring = false
	_hitbox.monitorable = false
	add_child(_hitbox)


func _update_flight_visuals(t: float) -> void:
	if is_instance_valid(_shadow):
		var ground_pos := Vector3(global_position.x, _target.y + SHADOW_OFFSET, global_position.z)
		var height := maxf(0.0, global_position.y - _target.y)
		var shadow_size := clampf(1.0 - height * 0.08, 0.4, 1.0)
		_shadow.global_position = ground_pos
		_shadow.scale = Vector3(shadow_size, 0.02, shadow_size)
	if is_instance_valid(_landing_ring):
		var pulse := lerpf(0.55, 1.0, t)
		_landing_ring.global_position = _target + Vector3.UP * 0.04
		_landing_ring.scale = Vector3(pulse, 1.0, pulse)


func _detonate() -> void:
	if _detonated:
		return
	_detonated = true
	global_position = _target
	_deal_impact_damage()
	var parent := get_parent()
	if is_instance_valid(parent) and not parent.is_queued_for_deletion():
		for effect_kind: StringName in [&"impact", &"smoke"]:
			var effect := VFX.instantiate()
			effect.effect = effect_kind
			parent.add_child(effect)
			effect.global_position = _target + Vector3.UP * 0.15
		var cloud := POISON_CLOUD_SCRIPT.new() as CoralPoisonCloud
		cloud.setup(
			_source,
			_source_team,
			_cloud_radius,
			_cloud_duration,
			_tick_interval,
			_tick_damage
		)
		parent.add_child(cloud)
		cloud.global_position = _target
		if is_instance_valid(_trail):
			_trail.emitting = false
			_trail.reparent(parent, true)
			get_tree().create_timer(_trail.lifetime + 0.1).timeout.connect(_trail.queue_free)
	queue_free()


func _deal_impact_damage() -> void:
	if _impact_damage <= 0.0 or not is_inside_tree():
		return
	var shape := CylinderShape3D.new()
	shape.radius = _cloud_radius * 0.65
	shape.height = 1.6
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, _target + Vector3.UP * 0.8)
	query.collision_mask = CombatLayers.PLAYER_HURTBOX
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var hits := get_world_3d().direct_space_state.intersect_shape(query, 8)
	if hits.is_empty():
		return
	var context := DamageContext.new()
	context.source = _source if is_instance_valid(_source) else self
	context.source_team = _source_team
	context.base_amount_hp = _impact_damage
	context.amount_hp = _impact_damage
	context.tag = &"projectile"
	context.knockback_multiplier = 0.0
	_hitbox.begin_attack_with_context(context)
	for hit in hits:
		var hurtbox := hit.get("collider") as HurtBox
		if hurtbox != null:
			_hitbox.try_hit(hurtbox)
	_hitbox.end_attack()
