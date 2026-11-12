class_name CoralSkeletonBullet
extends Node3D

const VFX := preload("res://gameplay/enemies/coral_skeleton/coral_skeleton_vfx.tscn")

var source: Node
var source_team := 0
var direction := Vector3.FORWARD
var speed := 0.0
var damage := 0.0
var remaining := 0.0
var trail: GPUParticles3D
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


func _physics_process(delta: float) -> void:
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
		_finish(true)
		return
	global_position += movement
	if remaining <= 0.0:
		_finish(false)


func _finish(impact: bool) -> void:
	var parent := get_parent()
	if is_instance_valid(parent) and not parent.is_queued_for_deletion():
		if impact:
			var effect := VFX.instantiate()
			effect.effect = &"impact"
			parent.add_child(effect)
			effect.global_position = global_position
		if is_instance_valid(trail):
			trail.emitting = false
			trail.reparent(parent, true)
			get_tree().create_timer(trail.lifetime + 0.1).timeout.connect(trail.queue_free)
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
	gradient.set_color(0, Color(1.0, 0.75, 0.35, 0.8))
	gradient.set_color(1, Color(0.9, 0.25, 0.12, 0.0))
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
	quad.size = Vector2(0.1, 0.1)
	trail.draw_pass_1 = quad
	add_child(trail)
	trail.emitting = true
