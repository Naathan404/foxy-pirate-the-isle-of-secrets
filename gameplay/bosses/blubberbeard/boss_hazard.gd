extends Node3D
## Short-lived barrel explosion or arcing spike. Owned by the boss.

signal detonated

const BARREL_GROUP := &"blubberbeard_barrel_hazards"
const BARREL_SHEET := preload("res://assets/sprites/bosses/blubberbeard/powder_barrel_sheet.png")
const BARREL_PIXEL_SIZE := 0.0095
const BARREL_GROUND_Y := 1.45
const SPIKE_TEXTURE := preload("res://assets/sprites/bosses/blubberbeard/enraged_spike.png")
const SPIKE_RADIUS := 0.55
const SPIKE_ARC_HEIGHT := 2.0
const SPIKE_LANDING_DROP := 0.85

var source: Node3D
var direction := Vector3.ZERO
var damage := 10.0
var speed := 0.0
var radius := 1.0
var remaining := 1.0
var spike := false
var hitbox: HitBox
var barrel_visual: Sprite3D
var barrel_shadow: MeshInstance3D
var warning: Node3D
var exploded := false
var _warning_material: StandardMaterial3D
var _warning_duration := 1.0
var _flight_time := 0.0
var _flight_duration := 0.0
var _flight_start := Vector3.ZERO
var _held_for_throw := false
var _landed_elapsed := 0.0
var _fuse_duration := 0.5
var _spike_elapsed := 0.0
var _spike_duration := 1.0


static func pick_wave_spots(
	boss: Node3D,
	anchor: Vector3,
	ground_y: float,
	count: int,
	barrel_radius: float,
	r_min_cfg: float,
	r_max_cfg: float,
	min_boss_distance: float,
	track_player_directly: bool
) -> Array[Vector3]:
	var spots: Array[Vector3] = []
	if count <= 0:
		return spots
	var radius_eff := maxf(0.5, barrel_radius)
	var min_sep := radius_eff * 2.08
	var min_boss_dist := maxf(0.0, min_boss_distance)
	var occupied := _collect_active_barrel_spots(boss)
	var space := (
		boss.get_world_3d().direct_space_state
		if boss.is_inside_tree() and boss.get_world_3d() != null
		else null
	)
	var check_bounds := _has_walkable_floor(boss, space, ground_y)
	var excluded := _collect_ray_excludes(boss)
	var from_pos := Vector3(boss.global_position.x, ground_y, boss.global_position.z)
	var side_count := count - 1 if track_player_directly else count
	if track_player_directly:
		var away := Vector2(anchor.x - from_pos.x, anchor.z - from_pos.z)
		var lead_angle := atan2(away.y, away.x) if not away.is_zero_approx() else 0.0
		var lead_spot := _resolve_barrel_spot(
			anchor,
			ground_y,
			from_pos,
			lead_angle,
			radius_eff,
			min_boss_dist,
			occupied,
			space,
			check_bounds,
			excluded
		)
		spots.append(lead_spot)
		occupied.append({"pos": lead_spot, "radius": radius_eff})
	if side_count <= 0:
		return spots
	var chord_floor := (
		min_sep / maxf(2.0 * sin(PI / float(side_count)), 0.2) if side_count > 1 else min_sep
	)
	var base_floor := maxf(r_min_cfg, min_sep if track_player_directly else 0.8)
	var ring_min := maxf(base_floor, chord_floor)
	var ring_max := maxf(ring_min + 1.4, r_max_cfg)
	var spin_offset := randf() * TAU
	for k in side_count:
		var base_angle := spin_offset + TAU * float(k) / float(side_count)
		var ring_r := randf_range(ring_min, ring_max)
		var angle := base_angle + randf_range(-0.18, 0.18)
		var candidate := anchor + Vector3(cos(angle), 0.0, sin(angle)) * ring_r
		candidate.y = ground_y
		if _is_barrel_spot_valid(
			candidate,
			radius_eff,
			occupied,
			from_pos,
			min_boss_dist,
			space,
			ground_y,
			check_bounds,
			excluded
		):
			spots.append(candidate)
			occupied.append({"pos": candidate, "radius": radius_eff})
			continue
		var resolved := _resolve_barrel_spot(
			anchor,
			ground_y,
			from_pos,
			base_angle,
			radius_eff,
			min_boss_dist,
			occupied,
			space,
			check_bounds,
			excluded,
			ring_min
		)
		spots.append(resolved)
		occupied.append({"pos": resolved, "radius": radius_eff})
	return spots


static func _collect_active_barrel_spots(boss: Node3D) -> Array[Dictionary]:
	var spots: Array[Dictionary] = []
	if not is_instance_valid(boss) or not boss.is_inside_tree():
		return spots
	for node in boss.get_tree().get_nodes_in_group(BARREL_GROUP):
		if not is_instance_valid(node) or node.is_queued_for_deletion():
			continue
		if not (node is Node3D) or bool(node.get("exploded")):
			continue
		var rad := float(node.get("radius"))
		if rad > 0.0:
			spots.append({"pos": (node as Node3D).global_position, "radius": rad})
	return spots


static func _collect_ray_excludes(boss: Node3D) -> Array[RID]:
	var excluded: Array[RID] = []
	if is_instance_valid(boss) and boss is CollisionObject3D:
		excluded.append((boss as CollisionObject3D).get_rid())
	return excluded


static func _has_walkable_floor(
	boss: Node3D, space: PhysicsDirectSpaceState3D, ground_y: float
) -> bool:
	if space == null or not is_instance_valid(boss):
		return false
	var center := Vector3(boss.global_position.x, ground_y, boss.global_position.z)
	return not BlubberbeardAI.spot_crosses_boundary(
		space, center, center, ground_y, _collect_ray_excludes(boss)
	)


static func _is_barrel_spot_valid(
	candidate: Vector3,
	radius_eff: float,
	occupied: Array[Dictionary],
	from_pos: Vector3,
	min_boss_dist: float,
	space: PhysicsDirectSpaceState3D,
	ground_y: float,
	check_bounds: bool,
	excluded: Array[RID]
) -> bool:
	if (
		check_bounds
		and BlubberbeardAI.spot_crosses_boundary(space, from_pos, candidate, ground_y, excluded)
	):
		return false
	if _flat_dist(candidate, from_pos) < min_boss_dist:
		return false
	return _min_barrel_clearance(candidate, radius_eff, occupied) >= 0.0


static func _resolve_barrel_spot(
	anchor: Vector3,
	ground_y: float,
	from_pos: Vector3,
	base_angle: float,
	radius_eff: float,
	min_boss_dist: float,
	occupied: Array[Dictionary],
	space: PhysicsDirectSpaceState3D,
	check_bounds: bool,
	excluded: Array[RID],
	min_ring_dist: float = 0.0
) -> Vector3:
	var fallback := anchor
	fallback.y = ground_y
	if min_ring_dist > 0.0:
		fallback += Vector3(cos(base_angle), 0.0, sin(base_angle)) * min_ring_dist
	var best_score := _spot_clearance_score(fallback, radius_eff, occupied, from_pos, min_boss_dist)
	var dists: Array[float] = []
	if min_ring_dist <= 0.0:
		dists.append(0.0)
		var boss_gap := maxf(0.0, min_boss_dist - _flat_dist(anchor, from_pos))
		if boss_gap > 0.01:
			dists.append(boss_gap)
		for mult in [2.08, 2.9, 3.8, 4.7]:
			dists.append(maxf(boss_gap, float(mult) * radius_eff))
	else:
		for mult in [0.0, 0.85, 1.7, 2.55, 3.4]:
			dists.append(min_ring_dist + float(mult) * radius_eff)
	for ang_m in [0, 1, -1, 2, -2, 3, -3, 4, -4, 5, -5, 6]:
		var angle := base_angle + float(ang_m) * deg_to_rad(20.0)
		for dist in dists:
			var cand := anchor + Vector3(cos(angle), 0.0, sin(angle)) * dist
			cand.y = ground_y
			if (
				check_bounds
				and BlubberbeardAI.spot_crosses_boundary(space, from_pos, cand, ground_y, excluded)
			):
				continue
			var score := _spot_clearance_score(cand, radius_eff, occupied, from_pos, min_boss_dist)
			if score >= 0.0:
				return cand
			if score > best_score:
				best_score = score
				fallback = cand
	return fallback


static func _spot_clearance_score(
	candidate: Vector3,
	radius_eff: float,
	occupied: Array[Dictionary],
	from_pos: Vector3,
	min_boss_dist: float
) -> float:
	var boss_clearance := _flat_dist(candidate, from_pos) - min_boss_dist
	return minf(boss_clearance, _min_barrel_clearance(candidate, radius_eff, occupied))


static func _min_barrel_clearance(
	candidate: Vector3, radius_eff: float, occupied: Array[Dictionary]
) -> float:
	var min_clear := INF
	for spot in occupied:
		var other := spot["pos"] as Vector3
		var other_rad := float(spot["radius"])
		var clearance := _flat_dist(candidate, other) - (radius_eff + other_rad + 0.14)
		if clearance < min_clear:
			min_clear = clearance
	return min_clear


static func _flat_dist(a: Vector3, b: Vector3) -> float:
	var dx := a.x - b.x
	var dz := a.z - b.z
	return sqrt(dx * dx + dz * dz)


func _ready() -> void:
	hitbox = HitBox.new()
	hitbox.actor = source
	hitbox.team = CombatTeams.ENEMY
	hitbox.collision_layer = CombatLayers.ENEMY_ATTACK
	hitbox.collision_mask = CombatLayers.PLAYER_HURTBOX
	var collider := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = SPIKE_RADIUS if spike else radius
	collider.shape = shape
	hitbox.add_child(collider)
	add_child(hitbox)
	if spike:
		_spike_duration = maxf(remaining, 0.01)
		var spike_sprite := Sprite3D.new()
		spike_sprite.name = "SpikeSprite"
		spike_sprite.texture = SPIKE_TEXTURE
		spike_sprite.pixel_size = (
			2.4 / float(maxi(SPIKE_TEXTURE.get_width(), SPIKE_TEXTURE.get_height()))
		)
		spike_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		spike_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		spike_sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(spike_sprite)
	else:
		add_to_group(BARREL_GROUP)
		_create_barrel_warning()
		barrel_visual = Sprite3D.new()
		barrel_visual.name = "BarrelSprite"
		barrel_visual.texture = BARREL_SHEET
		barrel_visual.hframes = 4
		barrel_visual.vframes = 2
		barrel_visual.frame = 4
		barrel_visual.pixel_size = BARREL_PIXEL_SIZE
		barrel_visual.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		barrel_visual.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
		barrel_visual.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		barrel_visual.position = Vector3(0.0, BARREL_GROUND_Y, 0.0)
		add_child(barrel_visual)

		barrel_shadow = MeshInstance3D.new()
		barrel_shadow.name = "BarrelShadow"
		barrel_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var shadow_mesh := CylinderMesh.new()
		shadow_mesh.top_radius = 0.9
		shadow_mesh.bottom_radius = 0.9
		shadow_mesh.height = 0.02
		barrel_shadow.mesh = shadow_mesh
		var shadow_mat := StandardMaterial3D.new()
		shadow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		shadow_mat.albedo_color = Color(0.03, 0.02, 0.02, 0.45)
		barrel_shadow.material_override = shadow_mat
		barrel_shadow.position = Vector3(0.0, 0.03, 0.0)
		add_child(barrel_shadow)

	if spike:
		hitbox.begin_attack(damage, 0, &"boss_spike")
		_create_spike_trail()


func hold_barrel_for_throw() -> void:
	_held_for_throw = true
	if is_instance_valid(barrel_visual):
		barrel_visual.visible = false
	if is_instance_valid(barrel_shadow):
		barrel_shadow.visible = false


func release_barrel_from(world_origin: Vector3) -> void:
	_held_for_throw = false
	if barrel_visual == null:
		return
	barrel_visual.visible = true
	if is_instance_valid(barrel_shadow):
		barrel_shadow.visible = true
	_flight_start = to_local(world_origin)
	barrel_visual.position = _flight_start
	barrel_visual.frame = 0
	_flight_time = 0.0
	_flight_duration = clampf(remaining * 0.58, 0.2, 0.85)
	_fuse_duration = maxf(0.1, remaining - _flight_duration)
	_landed_elapsed = 0.0


func animate_barrel(from: Vector3) -> void:
	release_barrel_from(from + Vector3.UP * 2.0)


func _physics_process(delta: float) -> void:
	if not is_instance_valid(source) or source.get("dead"):
		queue_free()
		return
	var hitstop := get_node_or_null("/root/HitstopController")
	if hitstop != null and hitstop.is_frozen(source):
		return
	var step_delta := minf(delta, maxf(remaining, 0.0)) if spike else delta
	remaining -= delta
	if not spike and not exploded:
		_update_barrel_animation(delta)
		var progress := 1.0 - clampf(remaining / _warning_duration, 0.0, 1.0)
		var pulse := 0.0
		if remaining < 0.45:
			pulse = (sin(_landed_elapsed * 28.0) * 0.5 + 0.5) * 0.18
		_warning_material.albedo_color.a = 0.14 + progress * 0.24 + pulse
	if spike:
		# Sweep each step to avoid tunnelling through small hurtboxes.
		var shape := SphereShape3D.new()
		shape.radius = SPIKE_RADIUS
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = shape
		query.transform = global_transform
		query.collision_mask = CombatLayers.PLAYER_HURTBOX
		query.collide_with_areas = true
		query.collide_with_bodies = false
		var previous_t := _spike_elapsed / _spike_duration
		_spike_elapsed = minf(_spike_elapsed + step_delta, _spike_duration)
		var t := _spike_elapsed / _spike_duration
		var previous_height := (
			4.0 * SPIKE_ARC_HEIGHT * previous_t * (1.0 - previous_t)
			- SPIKE_LANDING_DROP * previous_t
		)
		var height := 4.0 * SPIKE_ARC_HEIGHT * t * (1.0 - t) - SPIKE_LANDING_DROP * t
		var motion := direction * speed * step_delta + Vector3.UP * (height - previous_height)
		var steps := maxi(1, ceili(motion.length() / 0.3))
		for step in range(steps + 1):
			query.transform.origin = global_position + motion * float(step) / float(steps)
			for result in get_world_3d().direct_space_state.intersect_shape(query):
				hitbox.try_hit(result.collider as HurtBox)
		global_position += motion
	if remaining > 0.0:
		return
	if spike or exploded:
		queue_free()
		return
	exploded = true
	remaining = 0.18
	if is_instance_valid(warning):
		warning.hide()
	if is_instance_valid(barrel_visual):
		barrel_visual.hide()
	if is_instance_valid(barrel_shadow):
		barrel_shadow.hide()
	detonated.emit()
	_spawn_explosion_particles()
	hitbox.begin_attack(damage, 0, &"boss_explosion")
	hitbox.sample_shape()


func _create_barrel_warning() -> void:
	_warning_duration = maxf(remaining, 0.01)
	warning = Node3D.new()
	warning.name = "BarrelWarning"
	add_child(warning)
	var disc := MeshInstance3D.new()
	var disc_mesh := CylinderMesh.new()
	disc_mesh.top_radius = radius
	disc_mesh.bottom_radius = radius
	disc_mesh.height = 0.02
	disc.mesh = disc_mesh
	_warning_material = StandardMaterial3D.new()
	_warning_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_warning_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_warning_material.albedo_color = Color(1.0, 0.12, 0.04, 0.12)
	disc.material_override = _warning_material
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	disc.position.y = 0.03
	warning.add_child(disc)
	var ring := MeshInstance3D.new()
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = maxf(0.01, radius - 0.09)
	ring_mesh.outer_radius = radius
	ring.mesh = ring_mesh
	var ring_material := StandardMaterial3D.new()
	ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_material.albedo_color = Color(1.0, 0.18, 0.04)
	ring.material_override = ring_material
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.position.y = 0.05
	warning.add_child(ring)


func _update_barrel_animation(delta: float) -> void:
	if _held_for_throw or not is_instance_valid(barrel_visual):
		return
	if _flight_duration > 0.0 and _flight_time < _flight_duration:
		_flight_time = minf(_flight_duration, _flight_time + delta)
		var t := _flight_time / _flight_duration
		var ground_pos := Vector3(0.0, BARREL_GROUND_Y, 0.0)
		var pos := _flight_start.lerp(ground_pos, t)
		pos.y += sin(t * PI) * 2.2
		barrel_visual.position = pos
		barrel_visual.frame = int(t * 6.0) % 4
		barrel_visual.scale = Vector3.ONE
		if is_instance_valid(barrel_shadow):
			barrel_shadow.position = Vector3(pos.x, 0.03, pos.z)
			var h_scale := clampf(1.0 - maxf(0.0, pos.y - BARREL_GROUND_Y) * 0.08, 0.45, 1.0)
			barrel_shadow.scale = Vector3(h_scale, 1.0, h_scale)
		return
	# Grounded priming / about-to-explode state: fuse burning -> glowing seams -> rupture burst.
	_landed_elapsed += delta
	var fuse_t := clampf(_landed_elapsed / maxf(0.05, _fuse_duration), 0.0, 1.0)
	if fuse_t < 0.40:
		barrel_visual.frame = 4
	elif fuse_t < 0.72:
		barrel_visual.frame = 5
	elif remaining > 0.08:
		barrel_visual.frame = 6
	else:
		barrel_visual.frame = 7
	var swell := 1.0 + 0.16 * maxf(0.0, (fuse_t - 0.35) / 0.65)
	var wobble := sin(_landed_elapsed * 44.0) * 0.06 * maxf(0.0, (fuse_t - 0.45) / 0.55)
	barrel_visual.position = Vector3(wobble, BARREL_GROUND_Y * swell, 0.0)
	barrel_visual.scale = Vector3(swell + wobble * 0.3, swell, 1.0)
	if is_instance_valid(barrel_shadow):
		barrel_shadow.position = Vector3(0.0, 0.03, 0.0)
		barrel_shadow.scale = Vector3(swell, 1.0, swell)


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
