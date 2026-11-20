class_name VenomPoolProjectile
extends Node3D
## Đạn nọc axit bay parabol: có bóng, vòng cảnh báo điểm rơi và sinh VenomAcidPool.

signal impacted(landing_position: Vector3, pool: VenomAcidPool)

const ACID_POOL_SCRIPT := preload("res://gameplay/enemies/venom_vine/venom_acid_pool.gd")
const GLOB_SHEET := preload("res://assets/sprites/enemies/venom_vine/venom_glob_and_pool.png")
const PARTICLE_SHEET := preload("res://assets/sprites/enemies/venom_vine/venom_acid_particles.png")

const PARTICLE_CELL_SIZE := 256.0
const FRAME_ORB := 0
const FRAME_STREAK := 1
const FRAME_THORNY_POD := 2
const FRAME_SPLASH_BURST := 3
const MIN_FLIGHT_SECONDS := 0.15
const MIN_ARC_HEIGHT_METERS := 0.4
const DIRECT_HIT_RADIUS_METERS := 0.42
const SHADOW_GROUND_OFFSET_METERS := 0.025
const FILL_GROUND_OFFSET_METERS := 0.032
const RING_GROUND_OFFSET_METERS := 0.04
const SPLASH_GROUND_OFFSET_METERS := 0.55
const RING_PIXEL_DIVISOR := 200.0
const GROUND_RAY_UP_METERS := 1.5
const GROUND_RAY_DOWN_METERS := 4.0
const POOL_SEPARATION_BUFFER_METERS := 0.15
const IMPACT_DROPLET_LIFETIME := 0.36
const DROPLET_BURST_SPEED_MIN := 1.8
const DROPLET_BURST_SPEED_MAX := 3.6
const SPOT_SEARCH_ANGLES_DEG := [0.0, 24.0, -24.0, 48.0, -48.0, 72.0, -72.0, 100.0, -100.0]
const SPOT_RADIAL_OFFSETS := [0.0, 1.1, 2.2, -0.75]

var _source: Node
var _source_team: int = CombatTeams.ENEMY
var _start_position: Vector3 = Vector3.ZERO
var _landing_position: Vector3 = Vector3.ZERO
var _flight_duration_seconds: float = 0.65
var _arc_height_meters: float = 2.4
var _direct_damage_hp: float = 1.0
var _pool_config: Dictionary = {}
var _elapsed_seconds: float = 0.0
var _detonated: bool = false

var _glob_sprite: Sprite3D
var _comet_glow: Sprite3D
var _flight_light: OmniLight3D
var _shadow_mesh: MeshInstance3D
var _landing_fill: MeshInstance3D
var _landing_ring: Sprite3D
var _trail_particles: CPUParticles3D
var _direct_hitbox: HitBox


static func collect_active_pool_spots(tree_owner: Node) -> Array[Dictionary]:
	var spots: Array[Dictionary] = []
	if not is_instance_valid(tree_owner) or not tree_owner.is_inside_tree():
		return spots
	for node in tree_owner.get_tree().get_nodes_in_group(ACID_POOL_SCRIPT.POOL_GROUP):
		var pool := node as VenomAcidPool
		if pool == null or not is_instance_valid(pool) or pool.is_fading():
			continue
		spots.append({"pos": pool.global_position, "radius": pool.get_radius()})
	return spots


static func resolve_landing_spot(
	origin_position: Vector3,
	desired_position: Vector3,
	ground_y: float,
	pool_radius_meters: float,
	occupied_spots: Array[Dictionary],
	space: PhysicsDirectSpaceState3D,
	excluded_rids: Array[RID] = [],
	min_distance_meters: float = 1.2,
	max_distance_meters: float = INF
) -> Vector3:
	var to_desired := desired_position - origin_position
	to_desired.y = 0.0
	var min_d := maxf(0.8, min_distance_meters)
	var max_d := maxf(min_d, max_distance_meters)
	var base_dist := clampf(to_desired.length(), min_d, max_d)
	var base_dir := to_desired.normalized() if not to_desired.is_zero_approx() else Vector3.BACK
	var fallback := origin_position + base_dir * base_dist
	fallback.y = ground_y
	var snapped := _snap_to_walkable_ground(space, fallback, ground_y, excluded_rids)
	if snapped.has("pos"):
		fallback = snapped["pos"] as Vector3
	var best_clearance := _min_spot_clearance(fallback, pool_radius_meters, occupied_spots)
	var has_floor_check := (
		space != null
		and _has_ground_at(
			space, Vector3(origin_position.x, ground_y, origin_position.z), ground_y, excluded_rids
		)
	)

	for angle_deg in SPOT_SEARCH_ANGLES_DEG:
		var cand_dir := base_dir.rotated(Vector3.UP, deg_to_rad(angle_deg))
		for r_mult in SPOT_RADIAL_OFFSETS:
			var cand_dist := clampf(base_dist + float(r_mult) * pool_radius_meters, min_d, max_d)
			var candidate := origin_position + cand_dir * cand_dist
			candidate.y = ground_y
			var cand_y := ground_y
			if has_floor_check:
				var hit := _snap_to_walkable_ground(space, candidate, ground_y, excluded_rids)
				if not hit.has("pos"):
					continue
				candidate = hit["pos"] as Vector3
				cand_y = candidate.y
			candidate.y = cand_y
			var clearance := _min_spot_clearance(candidate, pool_radius_meters, occupied_spots)
			if clearance >= 0.0:
				return candidate
			if clearance > best_clearance:
				best_clearance = clearance
				fallback = candidate
	return fallback


static func _has_ground_at(
	space: PhysicsDirectSpaceState3D, point: Vector3, ground_y: float, excluded_rids: Array[RID]
) -> bool:
	return _snap_to_walkable_ground(space, point, ground_y, excluded_rids).has("pos")


static func _snap_to_walkable_ground(
	space: PhysicsDirectSpaceState3D, point: Vector3, ground_y: float, excluded_rids: Array[RID]
) -> Dictionary:
	if space == null:
		return {}
	var ray_from := Vector3(point.x, ground_y + GROUND_RAY_UP_METERS, point.z)
	var ray_to := Vector3(point.x, ground_y - GROUND_RAY_DOWN_METERS, point.z)
	var query := PhysicsRayQueryParameters3D.create(ray_from, ray_to, CombatLayers.WORLD)
	query.exclude = excluded_rids
	var result := space.intersect_ray(query)
	if result.is_empty():
		return {}
	var hit_pos := result["position"] as Vector3
	return {"pos": hit_pos}


static func _min_spot_clearance(
	candidate: Vector3, pool_radius_meters: float, occupied_spots: Array[Dictionary]
) -> float:
	var min_clear := INF
	for spot in occupied_spots:
		var other := spot["pos"] as Vector3
		var other_rad := float(spot["radius"])
		var flat_dist := Vector2(candidate.x - other.x, candidate.z - other.z).length()
		var clearance := (
			flat_dist - (pool_radius_meters + other_rad + POOL_SEPARATION_BUFFER_METERS)
		)
		if clearance < min_clear:
			min_clear = clearance
	return min_clear


func setup(
	owner_node: Node,
	owner_team: int,
	start_position: Vector3,
	landing_ground: Vector3,
	flight_duration_seconds: float,
	arc_height_meters: float,
	direct_damage_hp: float,
	pool_config: Dictionary = {}
) -> void:
	_source = owner_node
	_source_team = owner_team
	_start_position = start_position
	_landing_position = landing_ground
	_flight_duration_seconds = maxf(MIN_FLIGHT_SECONDS, flight_duration_seconds)
	_arc_height_meters = maxf(MIN_ARC_HEIGHT_METERS, arc_height_meters)
	_direct_damage_hp = maxf(0.0, direct_damage_hp)
	_pool_config = pool_config.duplicate(true)


func _ready() -> void:
	global_position = _start_position
	_build_flight_visuals()
	_build_direct_hitbox()
	_update_flight_visuals(0.0)


func _physics_process(delta: float) -> void:
	if _detonated:
		return
	var step := maxf(0.0, delta)
	_elapsed_seconds = minf(_flight_duration_seconds, _elapsed_seconds + step)
	var progress := _elapsed_seconds / _flight_duration_seconds
	var arc_offset := Vector3.UP * sin(PI * progress) * _arc_height_meters
	global_position = _start_position.lerp(_landing_position, progress) + arc_offset
	_update_flight_visuals(progress)
	if progress >= 1.0:
		_detonate()


func _build_flight_visuals() -> void:
	var pool_radius := maxf(0.4, float(_pool_config.get("pool_radius", 1.6)))
	var use_thorny := bool(_pool_config.get("use_thorny_pod", false))

	_glob_sprite = Sprite3D.new()
	_glob_sprite.name = "VenomGlobSprite"
	_glob_sprite.texture = GLOB_SHEET
	_glob_sprite.hframes = 4
	_glob_sprite.vframes = 2
	_glob_sprite.frame = FRAME_THORNY_POD if use_thorny else FRAME_ORB
	_glob_sprite.pixel_size = 0.0038
	_glob_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_glob_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_glob_sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_glob_sprite)

	_build_comet_aura()
	_build_ground_telegraph(pool_radius)

	_trail_particles = CPUParticles3D.new()
	_trail_particles.name = "TrailParticles"
	_trail_particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_trail_particles.amount = 22
	_trail_particles.lifetime = 0.38
	_trail_particles.local_coords = false
	_trail_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_trail_particles.emission_sphere_radius = 0.16
	_trail_particles.gravity = Vector3(0.0, -2.4, 0.0)
	_trail_particles.scale_amount_min = 0.24
	_trail_particles.scale_amount_max = 0.44
	_trail_particles.scale_amount_curve = ACID_POOL_SCRIPT.create_scale_curve(1.0, 0.1)
	_trail_particles.color_ramp = ACID_POOL_SCRIPT.create_fade_ramp(
		Color(0.85, 1.0, 0.45, 0.92), Color(0.25, 0.9, 0.2, 0.0)
	)
	_trail_particles.mesh = ACID_POOL_SCRIPT.create_particle_quad(0, Vector2(0.45, 0.45), true)
	add_child(_trail_particles)
	_trail_particles.emitting = true


func _build_comet_aura() -> void:
	var glow_atlas := AtlasTexture.new()
	glow_atlas.atlas = PARTICLE_SHEET
	glow_atlas.region = Rect2(0.0, 0.0, PARTICLE_CELL_SIZE, PARTICLE_CELL_SIZE)
	var glow_mat := StandardMaterial3D.new()
	glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glow_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	glow_mat.albedo_texture = glow_atlas
	glow_mat.albedo_color = Color(0.65, 1.0, 0.35, 0.72)
	glow_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	glow_mat.no_depth_test = false
	glow_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED

	_comet_glow = Sprite3D.new()
	_comet_glow.name = "CometGlow"
	_comet_glow.texture = glow_atlas
	_comet_glow.pixel_size = 0.0068
	_comet_glow.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_comet_glow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_comet_glow.material_override = glow_mat
	add_child(_comet_glow)

	_flight_light = OmniLight3D.new()
	_flight_light.name = "FlightLight"
	_flight_light.light_color = Color(0.52, 1.0, 0.28)
	_flight_light.light_energy = 0.75
	_flight_light.omni_range = 2.6
	_flight_light.shadow_enabled = false
	add_child(_flight_light)


func _build_ground_telegraph(pool_radius: float) -> void:
	var shadow_mat := StandardMaterial3D.new()
	shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shadow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shadow_mat.albedo_color = Color(0.03, 0.05, 0.02, 0.42)
	shadow_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var shadow_cyl := CylinderMesh.new()
	shadow_cyl.top_radius = 0.32
	shadow_cyl.bottom_radius = 0.32
	shadow_cyl.height = 0.02
	shadow_cyl.material = shadow_mat
	_shadow_mesh = MeshInstance3D.new()
	_shadow_mesh.name = "GlobShadow"
	_shadow_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_shadow_mesh.mesh = shadow_cyl
	_shadow_mesh.top_level = true
	add_child(_shadow_mesh)

	var fill_mat := StandardMaterial3D.new()
	fill_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fill_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fill_mat.albedo_color = Color(0.45, 1.0, 0.22, 0.16)
	fill_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	fill_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	var fill_cyl := CylinderMesh.new()
	fill_cyl.top_radius = pool_radius
	fill_cyl.bottom_radius = pool_radius
	fill_cyl.height = 0.01
	fill_cyl.material = fill_mat
	_landing_fill = MeshInstance3D.new()
	_landing_fill.name = "LandingWarningFill"
	_landing_fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_landing_fill.mesh = fill_cyl
	_landing_fill.top_level = true
	add_child(_landing_fill)
	_landing_fill.global_position = _landing_position + Vector3.UP * FILL_GROUND_OFFSET_METERS

	var ring_atlas := AtlasTexture.new()
	ring_atlas.atlas = PARTICLE_SHEET
	ring_atlas.region = Rect2(3.0 * PARTICLE_CELL_SIZE, 0.0, PARTICLE_CELL_SIZE, PARTICLE_CELL_SIZE)
	_landing_ring = Sprite3D.new()
	_landing_ring.name = "LandingWarningRing"
	_landing_ring.texture = ring_atlas
	_landing_ring.pixel_size = (pool_radius * 2.0) / RING_PIXEL_DIVISOR
	_landing_ring.rotation.x = -PI * 0.5
	_landing_ring.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_landing_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_landing_ring.top_level = true
	add_child(_landing_ring)
	_landing_ring.global_position = _landing_position + Vector3.UP * RING_GROUND_OFFSET_METERS


func _build_direct_hitbox() -> void:
	_direct_hitbox = HitBox.new()
	_direct_hitbox.name = "DirectHitBox"
	_direct_hitbox.actor = _source if is_instance_valid(_source) else self
	_direct_hitbox.team = _source_team
	_direct_hitbox.collision_layer = CombatLayers.ENEMY_ATTACK
	_direct_hitbox.collision_mask = CombatLayers.PLAYER_HURTBOX
	_direct_hitbox.monitoring = _direct_damage_hp > 0.0
	_direct_hitbox.monitorable = false
	var collision := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = DIRECT_HIT_RADIUS_METERS
	collision.shape = sphere
	_direct_hitbox.add_child(collision)
	_direct_hitbox.damage_applied.connect(_on_direct_hit)
	add_child(_direct_hitbox)

	if _direct_damage_hp > 0.0:
		var context := DamageContext.new()
		context.source = _source if is_instance_valid(_source) else self
		context.source_team = _source_team
		context.base_amount_hp = _direct_damage_hp
		context.amount_hp = _direct_damage_hp
		context.tag = &"projectile"
		context.knockback_multiplier = 0.45
		_direct_hitbox.begin_attack_with_context(context, HitBox.RehitPolicy.ONCE_PER_ATTACK)


func _update_flight_visuals(progress: float) -> void:
	if is_instance_valid(_glob_sprite):
		_glob_sprite.rotation.z = sin(_elapsed_seconds * 12.0) * 0.18
	if is_instance_valid(_comet_glow):
		var glow_pulse := 0.86 + 0.22 * sin(_elapsed_seconds * 18.0)
		_comet_glow.scale = Vector3.ONE * glow_pulse
	if is_instance_valid(_shadow_mesh):
		var height := maxf(0.0, global_position.y - _landing_position.y)
		var shadow_scale := clampf(1.0 - height * 0.12, 0.35, 1.0)
		_shadow_mesh.global_position = Vector3(
			global_position.x, _landing_position.y + SHADOW_GROUND_OFFSET_METERS, global_position.z
		)
		_shadow_mesh.scale = Vector3(shadow_scale, 1.0, shadow_scale)
	if is_instance_valid(_landing_fill):
		var fill_scale := lerpf(0.22, 1.0, progress)
		_landing_fill.global_position = (_landing_position + Vector3.UP * FILL_GROUND_OFFSET_METERS)
		_landing_fill.scale = Vector3(fill_scale, 1.0, fill_scale)
	if is_instance_valid(_landing_ring):
		var ring_scale := lerpf(0.5, 1.0, progress)
		_landing_ring.global_position = (_landing_position + Vector3.UP * RING_GROUND_OFFSET_METERS)
		_landing_ring.scale = Vector3.ONE * ring_scale
		_landing_ring.rotation.y = _elapsed_seconds * 1.8
		_landing_ring.modulate.a = lerpf(0.35, 0.92, progress)


func _on_direct_hit(_damage: DamageContext, _target: Node, _applied: float) -> void:
	if _detonated:
		return
	_landing_position.x = global_position.x
	_landing_position.z = global_position.z
	_detonate()


func _detonate() -> void:
	if _detonated:
		return
	_detonated = true
	if is_instance_valid(_direct_hitbox):
		_direct_hitbox.end_attack()
		_direct_hitbox.set_deferred("monitoring", false)

	var pool := _spawn_acid_pool()
	_spawn_splash_burst()
	_spawn_split_pods_if_enabled()
	impacted.emit(_landing_position, pool)
	queue_free()


func _spawn_acid_pool() -> VenomAcidPool:
	var parent := get_parent()
	if not is_instance_valid(parent) or parent.is_queued_for_deletion():
		return null
	var pool := ACID_POOL_SCRIPT.new() as VenomAcidPool
	var pool_radius := float(_pool_config.get("pool_radius", 1.6))
	var pool_duration := float(_pool_config.get("pool_duration_seconds", 4.0))
	var tick_interval := float(_pool_config.get("tick_interval_seconds", 0.85))
	var tick_damage := float(_pool_config.get("tick_damage_hp", 0.5))
	pool.setup(
		_source, _source_team, pool_radius, pool_duration, tick_interval, tick_damage, _pool_config
	)
	parent.add_child(pool)
	pool.global_position = _landing_position
	return pool


func _spawn_splash_burst() -> void:
	var parent := get_parent()
	if not is_instance_valid(parent) or parent.is_queued_for_deletion():
		return
	var burst := Sprite3D.new()
	burst.name = "AcidSplashBurst"
	burst.texture = GLOB_SHEET
	burst.hframes = 4
	burst.vframes = 2
	burst.frame = FRAME_SPLASH_BURST
	burst.pixel_size = 0.0056
	burst.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	burst.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	burst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(burst)
	burst.global_position = _landing_position + Vector3.UP * SPLASH_GROUND_OFFSET_METERS
	var tween := burst.create_tween().set_parallel(true)
	tween.tween_property(burst, "scale", Vector3.ONE * 1.45, 0.28)
	tween.tween_property(burst, "modulate:a", 0.0, 0.28)
	tween.chain().tween_callback(burst.queue_free)

	_spawn_impact_ring(parent)
	_spawn_impact_droplets(parent)


func _spawn_impact_ring(parent: Node) -> void:
	var pool_radius := maxf(0.4, float(_pool_config.get("pool_radius", 1.6)))
	var ring_atlas := AtlasTexture.new()
	ring_atlas.atlas = PARTICLE_SHEET
	ring_atlas.region = Rect2(3.0 * PARTICLE_CELL_SIZE, 0.0, PARTICLE_CELL_SIZE, PARTICLE_CELL_SIZE)
	var ring_mat := StandardMaterial3D.new()
	ring_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ring_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	ring_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_mat.vertex_color_use_as_albedo = true
	ring_mat.albedo_texture = ring_atlas
	ring_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	ring_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	var wave := Sprite3D.new()
	wave.name = "AcidImpactWave"
	wave.texture = ring_atlas
	wave.pixel_size = (pool_radius * 2.0) / RING_PIXEL_DIVISOR
	wave.rotation.x = -PI * 0.5
	wave.modulate = Color(0.65, 1.0, 0.35, 0.9)
	wave.scale = Vector3.ONE * 0.45
	wave.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	wave.material_override = ring_mat
	parent.add_child(wave)
	wave.global_position = _landing_position + Vector3.UP * RING_GROUND_OFFSET_METERS
	var wave_tween := wave.create_tween().set_parallel(true)
	wave_tween.tween_property(wave, "scale", Vector3.ONE * 1.55, 0.32)
	wave_tween.tween_property(wave, "modulate:a", 0.0, 0.32)
	wave_tween.chain().tween_callback(wave.queue_free)


func _spawn_impact_droplets(parent: Node) -> void:
	var particles := CPUParticles3D.new()
	particles.name = "ImpactDroplets"
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particles.amount = 18
	particles.lifetime = IMPACT_DROPLET_LIFETIME
	particles.one_shot = true
	particles.explosiveness = 1.0
	particles.local_coords = false
	particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	particles.emission_sphere_radius = 0.22
	particles.direction = Vector3.UP
	particles.spread = 58.0
	particles.initial_velocity_min = DROPLET_BURST_SPEED_MIN
	particles.initial_velocity_max = DROPLET_BURST_SPEED_MAX
	particles.gravity = Vector3(0.0, -9.8, 0.0)
	particles.scale_amount_min = 0.22
	particles.scale_amount_max = 0.42
	particles.scale_amount_curve = ACID_POOL_SCRIPT.create_scale_curve(1.0, 0.15)
	particles.color_ramp = ACID_POOL_SCRIPT.create_fade_ramp(
		Color(0.85, 1.0, 0.45, 0.95), Color(0.3, 0.95, 0.2, 0.0)
	)
	particles.mesh = ACID_POOL_SCRIPT.create_particle_quad(2, Vector2(0.45, 0.45), true)
	parent.add_child(particles)
	particles.global_position = _landing_position + Vector3.UP * 0.15
	particles.emitting = true
	var cleanup := particles.create_tween()
	cleanup.tween_interval(IMPACT_DROPLET_LIFETIME + 0.2)
	cleanup.tween_callback(particles.queue_free)


func _spawn_split_pods_if_enabled() -> void:
	var split_count := int(_pool_config.get("split_pod_count", 0))
	if split_count <= 0:
		return
	var parent := get_parent()
	if not is_instance_valid(parent) or parent.is_queued_for_deletion():
		return
	var split_radius := maxf(0.5, float(_pool_config.get("split_pool_radius", 1.1)))
	var split_dist := maxf(1.2, float(_pool_config.get("split_distance_meters", 2.2)))
	var sub_config := _pool_config.duplicate(true)
	sub_config["split_pod_count"] = 0
	sub_config["use_thorny_pod"] = false
	sub_config["pool_radius"] = split_radius
	var start_angle := randf() * TAU
	for idx in range(split_count):
		var angle := start_angle + TAU * float(idx) / float(split_count)
		var target_pos := _landing_position + Vector3(cos(angle), 0.0, sin(angle)) * split_dist
		var sub_proj := get_script().new() as VenomPoolProjectile
		sub_proj.setup(
			_source,
			_source_team,
			_landing_position + Vector3.UP * 0.35,
			target_pos,
			0.38,
			1.4,
			_direct_damage_hp * 0.5,
			sub_config
		)
		parent.add_child(sub_proj)
