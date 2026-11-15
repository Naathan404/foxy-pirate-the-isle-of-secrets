extends Node3D
## Short-lived ground warning/explosion or straight-line spike. Owned by the boss.

signal detonated

var source: Node3D
var direction := Vector3.ZERO
var damage := 10.0
var speed := 0.0
var radius := 1.0
var remaining := 1.0
var spike := false
var hitbox: HitBox
var visual: MeshInstance3D
var barrel_visual: MeshInstance3D
var warning_ring: MeshInstance3D
var exploded := false
var _warning_duration := 1.0
var _flight_time := 0.0
var _flight_duration := 0.0
var _flight_start := Vector3.ZERO


func _ready() -> void:
	_warning_duration = maxf(remaining, 0.01)
	hitbox = HitBox.new()
	hitbox.actor = source
	hitbox.team = CombatTeams.ENEMY
	hitbox.collision_layer = CombatLayers.ENEMY_ATTACK
	hitbox.collision_mask = CombatLayers.PLAYER_HURTBOX
	var collider := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.35 if spike else radius
	collider.shape = shape
	hitbox.add_child(collider)
	add_child(hitbox)
	visual = MeshInstance3D.new()
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(1.0, 0.28, 0.04, 1.0) if spike else Color(1.0, 0.02, 0.02, 0.45)
	if spike:
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.0
		mesh.bottom_radius = 0.22
		mesh.height = 0.8
		visual.mesh = mesh
		visual.rotation = Vector3(PI * 0.5, atan2(-direction.x, -direction.z), 0.0)
	else:
		var mesh := CylinderMesh.new()
		mesh.top_radius = radius
		mesh.bottom_radius = radius
		mesh.height = 0.04
		visual.mesh = mesh
		barrel_visual = MeshInstance3D.new()
		var barrel_mesh := CylinderMesh.new()
		barrel_mesh.top_radius = 0.3
		barrel_mesh.bottom_radius = 0.3
		barrel_mesh.height = 0.65
		barrel_visual.mesh = barrel_mesh
		barrel_visual.position.y = 0.35
		var wood := StandardMaterial3D.new()
		wood.albedo_color = Color(0.35, 0.16, 0.06)
		barrel_visual.material_override = wood
		add_child(barrel_visual)
		warning_ring = MeshInstance3D.new()
		var ring := TorusMesh.new()
		ring.inner_radius = maxf(0.01, radius - 0.08)
		ring.outer_radius = radius
		warning_ring.mesh = ring
		var ring_material := StandardMaterial3D.new()
		ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		ring_material.albedo_color = Color(1.0, 0.12, 0.06)
		warning_ring.material_override = ring_material
		warning_ring.position.y = 0.04
		add_child(warning_ring)
	visual.material_override = material
	add_child(visual)
	if spike:
		hitbox.begin_attack(damage, 0, &"boss_spike")
		_create_spike_trail()


func animate_barrel(from: Vector3) -> void:
	if barrel_visual == null:
		return
	_flight_start = to_local(from + Vector3.UP * 2.0)
	barrel_visual.position = _flight_start
	_flight_duration = maxf(0.05, remaining * 0.65)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(source) or source.get("dead"):
		queue_free()
		return
	var hitstop := get_node_or_null("/root/HitstopController")
	if hitstop != null and hitstop.is_frozen(source):
		return
	remaining -= delta
	if not spike and not exploded:
		_update_warning(delta)
	if spike:
		# Sweep each step to avoid tunnelling through small hurtboxes.
		var shape := SphereShape3D.new()
		shape.radius = 0.35
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = shape
		query.transform = global_transform
		query.collision_mask = CombatLayers.PLAYER_HURTBOX
		query.collide_with_areas = true
		query.collide_with_bodies = false
		var motion := direction * speed * delta
		var steps := maxi(1, ceili(motion.length() / 0.3))
		for step in range(steps + 1):
			query.transform.origin = global_position + motion * float(step) / float(steps)
			for result in get_world_3d().direct_space_state.intersect_shape(query):
				hitbox.try_hit(result.collider as HurtBox)
		global_position += direction * speed * delta
	if remaining > 0.0:
		return
	if spike or exploded:
		queue_free()
		return
	exploded = true
	remaining = 0.18
	barrel_visual.hide()
	warning_ring.hide()
	detonated.emit()
	_spawn_explosion_particles()
	visual.scale.y = 12.0
	(visual.material_override as StandardMaterial3D).albedo_color = Color(1.0, 0.55, 0.05, 0.8)
	hitbox.begin_attack(damage, 0, &"boss_explosion")
	hitbox.sample_shape()


func _update_warning(delta: float) -> void:
	var progress := 1.0 - clampf(remaining / _warning_duration, 0.0, 1.0)
	var material := visual.material_override as StandardMaterial3D
	material.albedo_color.a = 0.25 + 0.25 * progress + 0.08 * sin(progress * PI * 8.0)
	if _flight_duration > 0.0 and _flight_time < _flight_duration:
		_flight_time = minf(_flight_duration, _flight_time + delta)
		var t := _flight_time / _flight_duration
		barrel_visual.position = _flight_start.lerp(Vector3(0, 0.35, 0), t)
		barrel_visual.position.y += sin(t * PI) * 1.5
		barrel_visual.rotation.z = TAU * t * 1.5


func _spawn_explosion_particles() -> void:
	var particles := CPUParticles3D.new()
	particles.name = "BarrelExplosion"
	particles.emitting = false
	particles.amount = 32
	particles.lifetime = 0.65
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.direction = Vector3.UP
	particles.spread = 85.0
	particles.initial_velocity_min = 2.0
	particles.initial_velocity_max = 5.0
	particles.gravity = Vector3(0, -5, 0)
	particles.scale_amount_min = 0.1
	particles.scale_amount_max = 0.4
	particles.color = Color(1.0, 0.55, 0.12)
	var mesh := SphereMesh.new()
	mesh.radius = 0.22
	mesh.height = 0.44
	mesh.material = _particle_material()
	particles.mesh = mesh
	get_parent().add_child(particles)
	particles.global_position = global_position
	particles.emitting = true
	var cleanup := particles.create_tween()
	cleanup.tween_interval(1.0)
	cleanup.tween_callback(particles.queue_free)


func _create_spike_trail() -> void:
	var trail := CPUParticles3D.new()
	trail.emitting = false
	trail.amount = 8
	trail.lifetime = 0.25
	trail.local_coords = false
	trail.direction = -direction
	trail.spread = 20.0
	trail.initial_velocity_min = 0.1
	trail.initial_velocity_max = 0.5
	trail.gravity = Vector3.ZERO
	trail.scale_amount_min = 0.1
	trail.scale_amount_max = 0.22
	trail.color = Color(1.0, 0.35, 0.08, 0.7)
	var mesh := SphereMesh.new()
	mesh.radius = 0.12
	mesh.height = 0.24
	mesh.material = _particle_material()
	trail.mesh = mesh
	add_child(trail)
	trail.set_deferred("emitting", true)


func _particle_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material
