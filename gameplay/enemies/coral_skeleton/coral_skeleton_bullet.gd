class_name CoralSkeletonBullet
extends Node3D

const VFX := preload("res://gameplay/enemies/coral_skeleton/coral_skeleton_vfx.tscn")
const SHADOW_CAST_DISTANCE := 25.0
const SHADOW_GROUND_OFFSET := 0.025

@export_range(0.0, 2.0, 0.05, "suffix:s") var death_duration := 0.28

var source: Node
var source_team := 0
var direction := Vector3.FORWARD
var speed := 0.0
var damage := 0.0
var remaining := 0.0
var trail: GPUParticles3D
var _dying := false
var _death_remaining := 0.0
var _mesh_material: StandardMaterial3D
var _mesh_base_alpha := 1.0
var _shadow_material: StandardMaterial3D
var _shadow_base_alpha := 0.42
@onready var mesh: MeshInstance3D = $Mesh
@onready var shadow: MeshInstance3D = $Shadow
@onready var ground_ray: RayCast3D = $GroundRay
@onready var sweep: ShapeCast3D = $Sweep
@onready var hitbox: HitBox = $HitBox


func setup(
	owner_node: Node, team: int, heading: Vector3, shot_speed: float, amount: float, lifetime: float
) -> void:
	source = owner_node
	source_team = team
	direction = heading.normalized()
	speed = maxf(0.0, shot_speed)
	damage = maxf(0.0, amount)
	remaining = maxf(0.0, lifetime)


func _ready() -> void:
	_create_trail()
	_setup_materials()
	shadow.top_level = true
	shadow.visible = false
	ground_ray.collision_mask = CombatLayers.WORLD
	sweep.collision_mask = CombatLayers.WORLD | CombatLayers.ENEMY_BODY | CombatLayers.PLAYER_HURTBOX
	if source is CollisionObject3D:
		sweep.add_exception(source)
	hitbox.actor = source
	hitbox.team = source_team
	var context := DamageContext.new()
	context.source = source
	context.source_team = source_team
	context.base_amount_hp = damage
	context.amount_hp = damage
	context.tag = &"projectile"
	context.knockback_multiplier = 0.0
	if is_instance_valid(source) and damage > 0.0:
		hitbox.begin_attack_with_context(context)
		hitbox.set_physics_process(false)
	_update_shadow.call_deferred()


func _physics_process(delta: float) -> void:
	if _dying:
		_death_remaining = maxf(0.0, _death_remaining - maxf(0.0, delta))
		_update_death_visuals()
		_update_shadow()
		if _death_remaining <= 0.0:
			_finalize_death()
		return
	var step := minf(maxf(0.0, delta), remaining)
	remaining -= step
	var movement := direction * speed * step
	sweep.target_position = sweep.global_basis.inverse() * movement
	sweep.force_shapecast_update()
	if sweep.is_colliding():
		global_position += movement * clampf(sweep.get_closest_collision_safe_fraction(), 0.0, 1.0)
		for index in sweep.get_collision_count():
			var hurtbox := sweep.get_collider(index) as HurtBox
			if hurtbox != null:
				hitbox.try_hit(hurtbox)
				break
		_update_shadow()
		_finish(true)
		return
	global_position += movement
	_update_shadow()
	if remaining <= 0.0:
		_finish(false)


func _setup_materials() -> void:
	var active_mesh_mat := mesh.get_active_material(0) as StandardMaterial3D
	if active_mesh_mat != null:
		_mesh_material = active_mesh_mat.duplicate() as StandardMaterial3D
		_mesh_base_alpha = _mesh_material.albedo_color.a
		mesh.material_override = _mesh_material
	var active_shadow_mat := shadow.get_active_material(0) as StandardMaterial3D
	if active_shadow_mat != null:
		_shadow_material = active_shadow_mat.duplicate() as StandardMaterial3D
		_shadow_base_alpha = _shadow_material.albedo_color.a
		shadow.material_override = _shadow_material


func _update_shadow() -> void:
	if not is_inside_tree() or not is_instance_valid(shadow) or not is_instance_valid(ground_ray):
		return
	var down := Vector3.DOWN * SHADOW_CAST_DISTANCE
	ground_ray.target_position = ground_ray.global_basis.inverse() * down
	ground_ray.force_raycast_update()
	if not ground_ray.is_colliding():
		shadow.visible = false
		return
	var hit_point := ground_ray.get_collision_point()
	var hit_normal := ground_ray.get_collision_normal()
	var offset_normal := hit_normal.normalized() if not hit_normal.is_zero_approx() else Vector3.UP
	var height := maxf(0.0, global_position.y - hit_point.y)
	var height_scale := clampf(1.0 - height * 0.06, 0.45, 1.0)
	var death_ratio := 1.0
	if _dying:
		death_ratio = clampf(_death_remaining / maxf(0.001, death_duration), 0.0, 1.0)
	var shadow_scale := height_scale * lerpf(0.3, 1.0, death_ratio) if _dying else height_scale
	shadow.visible = not _dying or death_ratio > 0.02
	shadow.global_position = hit_point + offset_normal * SHADOW_GROUND_OFFSET
	shadow.scale = Vector3(shadow_scale, 0.02, shadow_scale)
	if is_instance_valid(_shadow_material):
		_shadow_material.albedo_color.a = _shadow_base_alpha * height_scale * death_ratio


func _update_death_visuals() -> void:
	var ratio := clampf(_death_remaining / maxf(0.001, death_duration), 0.0, 1.0)
	mesh.scale = Vector3.ONE * lerpf(0.25, 1.0, ratio)
	if is_instance_valid(_mesh_material):
		_mesh_material.albedo_color.a = _mesh_base_alpha * ratio


func _spawn_effect(kind: StringName) -> void:
	var parent := get_parent()
	if not is_instance_valid(parent) or parent.is_queued_for_deletion():
		return
	var effect := VFX.instantiate()
	effect.effect = kind
	parent.add_child(effect)
	effect.global_position = global_position


func _finish(impact: bool) -> void:
	if _dying:
		return
	_dying = true
	_death_remaining = maxf(0.0, death_duration)
	hitbox.end_attack()
	sweep.enabled = false
	if is_instance_valid(trail):
		trail.emitting = false
	if impact:
		_spawn_effect(&"impact")
	_spawn_effect(&"smoke")
	if _death_remaining <= 0.0:
		_finalize_death()
		return
	if is_instance_valid(_mesh_material):
		_mesh_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_update_death_visuals()


func _finalize_death() -> void:
	var parent := get_parent()
	if is_instance_valid(parent) and not parent.is_queued_for_deletion() and is_instance_valid(trail):
		var remaining_trail := maxf(0.0, trail.lifetime - death_duration) + 0.1
		trail.reparent(parent, true)
		get_tree().create_timer(remaining_trail).timeout.connect(trail.queue_free)
	queue_free()


func _create_trail() -> void:
	trail = GPUParticles3D.new()
	trail.name = "Trail"
	trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	trail.amount = 16
	trail.lifetime = 0.18
	trail.local_coords = false
	trail.visibility_aabb = AABB(Vector3(-3, -3, -3), Vector3(6, 6, 6))
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3.ZERO
	process.spread = 180.0
	process.gravity = Vector3.ZERO
	process.initial_velocity_min = 0.0
	process.initial_velocity_max = 0.2
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.45, 0.63, 0.3, 0.85))
	gradient.set_color(1, Color(0.2, 0.33, 0.14, 0.0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = gradient
	process.color_ramp = ramp
	trail.process_material = process
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	var quad := QuadMesh.new()
	quad.material = material
	quad.size = Vector2(0.2, 0.2)
	trail.draw_pass_1 = quad
	add_child(trail)
	trail.emitting = true
