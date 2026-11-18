class_name BlubberbeardVenomHazard
extends Node3D
## Đạn nọc độc bay parabol tạo vũng axit ăn mòn gây sát thương theo thời gian.

signal splashed(at: Vector3, pool_radius: float)

enum Stage { FLIGHT, POOL }

const VENOM_SHEET := preload("res://assets/sprites/bosses/blubberbeard/venom_glob_and_puddle.png")
const HAZARD_GROUP := &"blubberbeard_venom_hazards"
const FLIGHT_ARC_HEIGHT := 2.4
const PUDDLE_FRAME_FPS := 6.0

var source: Node3D
var direct_damage: float = 3.5
var pool_radius: float = 2.4
var pool_duration: float = 4.5
var tick_damage: float = 0.5
var tick_interval: float = 0.75

var glob_sprite: Sprite3D
var puddle_sprite: Sprite3D
var warning_ring: MeshInstance3D

var _stage: Stage = Stage.FLIGHT
var _start_pos: Vector3 = Vector3.ZERO
var _landing_pos: Vector3 = Vector3.ZERO
var _flight_elapsed: float = 0.0
var _flight_duration: float = 0.48
var _pool_remaining: float = 4.5
var _tick_cooldown: float = 0.12
var _clock: float = 0.0
var _direct_hitbox: HitBox
var _pool_area: Area3D
var _trail_particles: CPUParticles3D
var _fume_particles: CPUParticles3D


static func fire_fan_volley(
	boss: Node3D,
	target_node: Node3D,
	origin: Vector3,
	ground_y: float,
	skill: BlubberbeardSkillData,
	pool_scale: float,
	on_splashed: Callable
) -> Vector3:
	var container := boss.get_parent()
	if not is_instance_valid(container) or skill == null:
		return Vector3.BACK
	var lead := Vector3.ZERO
	if target_node is CharacterBody3D:
		var vel := (target_node as CharacterBody3D).velocity
		vel.y = 0.0
		lead = (vel * 0.35).limit_length(3.5)
	var target_pos := (
		(target_node.global_position if is_instance_valid(target_node) else boss.global_position)
		+ lead
	)
	var base_vec := target_pos - boss.global_position
	base_vec.y = 0.0
	var dist := clampf(base_vec.length(), 3.2, 13.5)
	var aim_dir := base_vec.normalized() if not base_vec.is_zero_approx() else Vector3.BACK
	var shots := maxi(1, skill.venom_shot_count)
	var half_arc := deg_to_rad(skill.venom_spread_angle_deg) * 0.5
	for i in shots:
		var angle := lerpf(-half_arc, half_arc, 0.5 if shots == 1 else float(i) / float(shots - 1))
		var land := boss.global_position + aim_dir.rotated(Vector3.UP, angle) * dist
		land.y = ground_y
		var hazard := BlubberbeardVenomHazard.new()
		hazard.setup_shot(
			boss,
			origin,
			land,
			skill.damage,
			skill.venom_pool_radius * pool_scale,
			skill.venom_pool_duration,
			skill.venom_tick_damage,
			skill.venom_tick_interval
		)
		if on_splashed.is_valid():
			hazard.splashed.connect(on_splashed)
		container.add_child(hazard)
	return aim_dir


func setup_shot(
	owner_node: Node3D,
	spawn_world: Vector3,
	landing_world: Vector3,
	shot_damage: float,
	radius_m: float,
	duration_s: float,
	dot_damage: float,
	dot_interval_s: float
) -> void:
	source = owner_node
	_start_pos = spawn_world
	_landing_pos = landing_world
	direct_damage = maxf(0.1, shot_damage)
	pool_radius = maxf(0.8, radius_m)
	pool_duration = maxf(0.5, duration_s)
	_pool_remaining = pool_duration
	tick_damage = maxf(0.1, dot_damage)
	tick_interval = maxf(0.15, dot_interval_s)
	var flat_dist := (
		Vector2(landing_world.x - spawn_world.x, landing_world.z - spawn_world.z).length()
	)
	_flight_duration = clampf(0.28 + flat_dist * 0.032, 0.32, 0.72)


func _ready() -> void:
	add_to_group(HAZARD_GROUP)
	global_position = _landing_pos
	_build_flight_visuals()
	_build_pool_visuals()
	_build_direct_hitbox()
	_build_pool_area()
	_enter_flight()


func _physics_process(delta: float) -> void:
	var step := maxf(0.0, delta)
	_clock += step
	if _stage == Stage.FLIGHT:
		_tick_flight(step)
	else:
		_tick_pool(step)


func _tick_flight(delta: float) -> void:
	_flight_elapsed += delta
	var progress := clampf(_flight_elapsed / maxf(0.05, _flight_duration), 0.0, 1.0)
	var pos := _start_pos.lerp(_landing_pos, progress)
	pos.y += sin(progress * PI) * FLIGHT_ARC_HEIGHT
	if is_instance_valid(glob_sprite):
		glob_sprite.global_position = pos
		glob_sprite.frame = 0 if progress < 0.3 else (1 if progress < 0.7 else 2)
		glob_sprite.rotation.z = sin(_clock * 14.0) * 0.16
	if is_instance_valid(_direct_hitbox):
		_direct_hitbox.global_position = pos
	if is_instance_valid(_trail_particles):
		_trail_particles.global_position = pos
	if progress >= 1.0:
		_enter_pool()


func _tick_pool(delta: float) -> void:
	_pool_remaining = maxf(0.0, _pool_remaining - delta)
	if is_instance_valid(puddle_sprite):
		puddle_sprite.frame = 4 + (int(_clock * PUDDLE_FRAME_FPS) % 4)
		if _pool_remaining < 0.7:
			puddle_sprite.modulate.a = clampf(_pool_remaining / 0.7, 0.0, 1.0)
	_tick_cooldown -= delta
	if _tick_cooldown <= 0.0:
		_tick_cooldown += tick_interval
		_apply_poison_tick()
	if _pool_remaining <= 0.0:
		queue_free()


func _enter_flight() -> void:
	_stage = Stage.FLIGHT
	glob_sprite.visible = true
	puddle_sprite.visible = false
	warning_ring.visible = true
	_pool_area.monitoring = false
	_fume_particles.emitting = false
	_trail_particles.emitting = true
	var ctx := DamageContext.new()
	ctx.source = source if is_instance_valid(source) else self
	ctx.source_team = CombatTeams.ENEMY
	ctx.base_amount_hp = direct_damage
	ctx.amount_hp = direct_damage
	ctx.tag = &"boss_venom_hit"
	ctx.knockback_multiplier = 0.65
	_direct_hitbox.begin_attack_with_context(ctx, HitBox.RehitPolicy.ONCE_PER_ATTACK)


func _enter_pool() -> void:
	_stage = Stage.POOL
	_direct_hitbox.end_attack()
	_trail_particles.emitting = false
	warning_ring.visible = false
	glob_sprite.visible = false
	puddle_sprite.visible = true
	puddle_sprite.modulate.a = 0.94
	_pool_area.monitoring = true
	_fume_particles.emitting = true
	splashed.emit(_landing_pos, pool_radius)
	_spawn_splash_burst()


func _apply_poison_tick() -> void:
	if not is_instance_valid(_pool_area):
		return
	for area in _pool_area.get_overlapping_areas():
		var hurtbox := area as HurtBox
		if hurtbox == null:
			continue
		var ctx := DamageContext.new()
		ctx.source = source if is_instance_valid(source) else self
		ctx.source_team = CombatTeams.ENEMY
		ctx.base_amount_hp = tick_damage
		ctx.amount_hp = tick_damage
		ctx.tag = &"poison"
		ctx.origin = _landing_pos
		ctx.knockback_multiplier = 0.0
		hurtbox.take_damage(ctx)


func _on_direct_hit(_damage: DamageContext, _target: Node, _applied: float) -> void:
	if _stage == Stage.FLIGHT:
		_landing_pos.x = glob_sprite.global_position.x
		_landing_pos.z = glob_sprite.global_position.z
		global_position = _landing_pos
		_enter_pool()


func _build_flight_visuals() -> void:
	warning_ring = MeshInstance3D.new()
	warning_ring.name = "VenomLandingWarning"
	warning_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var cyl := CylinderMesh.new()
	cyl.top_radius = pool_radius * 0.65
	cyl.bottom_radius = pool_radius * 0.65
	cyl.height = 0.02
	warning_ring.mesh = cyl
	var warn_mat := StandardMaterial3D.new()
	warn_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	warn_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	warn_mat.albedo_color = Color(0.45, 0.92, 0.25, 0.24)
	warning_ring.material_override = warn_mat
	warning_ring.position = Vector3(0.0, 0.03, 0.0)
	add_child(warning_ring)

	glob_sprite = Sprite3D.new()
	glob_sprite.name = "VenomGlobSprite"
	glob_sprite.top_level = true
	glob_sprite.texture = VENOM_SHEET
	glob_sprite.hframes = 4
	glob_sprite.vframes = 2
	glob_sprite.frame = 0
	glob_sprite.pixel_size = 0.0052
	glob_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	glob_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	glob_sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(glob_sprite)

	_trail_particles = CPUParticles3D.new()
	_trail_particles.name = "VenomTrailParticles"
	_trail_particles.top_level = true
	_trail_particles.amount = 18
	_trail_particles.lifetime = 0.4
	_trail_particles.local_coords = false
	_trail_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_trail_particles.emission_sphere_radius = 0.25
	_trail_particles.gravity = Vector3(0.0, -4.5, 0.0)
	_trail_particles.scale_amount_min = 0.14
	_trail_particles.scale_amount_max = 0.3
	_trail_particles.color = Color(0.45, 0.96, 0.28, 0.85)
	var mesh := SphereMesh.new()
	mesh.radius = 0.16
	mesh.height = 0.32
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mesh.material = mat
	_trail_particles.mesh = mesh
	add_child(_trail_particles)


func _build_pool_visuals() -> void:
	puddle_sprite = Sprite3D.new()
	puddle_sprite.name = "PoisonPuddleDecal"
	puddle_sprite.texture = VENOM_SHEET
	puddle_sprite.hframes = 4
	puddle_sprite.vframes = 2
	puddle_sprite.frame = 4
	puddle_sprite.pixel_size = (pool_radius * 2.0) / 360.0
	puddle_sprite.rotation.x = -PI * 0.5
	puddle_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	puddle_sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	puddle_sprite.position = Vector3(0.0, 0.04, 0.0)
	add_child(puddle_sprite)

	_fume_particles = CPUParticles3D.new()
	_fume_particles.name = "PoisonFumes"
	_fume_particles.emitting = false
	_fume_particles.amount = 16
	_fume_particles.lifetime = 0.75
	_fume_particles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_fume_particles.emission_box_extents = Vector3(pool_radius * 0.55, 0.08, pool_radius * 0.55)
	_fume_particles.direction = Vector3.UP
	_fume_particles.spread = 22.0
	_fume_particles.initial_velocity_min = 0.5
	_fume_particles.initial_velocity_max = 1.4
	_fume_particles.gravity = Vector3(0.0, 0.6, 0.0)
	_fume_particles.scale_amount_min = 0.2
	_fume_particles.scale_amount_max = 0.42
	_fume_particles.color = Color(0.55, 0.95, 0.3, 0.65)
	var mesh := SphereMesh.new()
	mesh.radius = 0.18
	mesh.height = 0.36
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.vertex_color_use_as_albedo = true
	mesh.material = mat
	_fume_particles.mesh = mesh
	_fume_particles.position = Vector3(0.0, 0.15, 0.0)
	add_child(_fume_particles)


func _build_direct_hitbox() -> void:
	_direct_hitbox = HitBox.new()
	_direct_hitbox.name = "VenomDirectHitBox"
	_direct_hitbox.top_level = true
	_direct_hitbox.actor = source if is_instance_valid(source) else self
	_direct_hitbox.team = CombatTeams.ENEMY
	_direct_hitbox.collision_layer = CombatLayers.ENEMY_ATTACK
	_direct_hitbox.collision_mask = CombatLayers.PLAYER_HURTBOX
	_direct_hitbox.damage_applied.connect(_on_direct_hit)
	var col := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.8
	col.shape = sphere
	_direct_hitbox.add_child(col)
	add_child(_direct_hitbox)


func _build_pool_area() -> void:
	_pool_area = Area3D.new()
	_pool_area.name = "PoisonPoolArea"
	_pool_area.collision_layer = 0
	_pool_area.collision_mask = CombatLayers.PLAYER_HURTBOX
	_pool_area.monitoring = false
	_pool_area.monitorable = false
	var col := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = pool_radius * 0.92
	cyl.height = 1.6
	col.shape = cyl
	col.position = Vector3(0.0, 0.8, 0.0)
	_pool_area.add_child(col)
	add_child(_pool_area)


func _spawn_splash_burst() -> void:
	var burst := Sprite3D.new()
	burst.name = "VenomSplashBurst"
	burst.texture = VENOM_SHEET
	burst.hframes = 4
	burst.vframes = 2
	burst.frame = 3
	burst.pixel_size = 0.0085
	burst.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	burst.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	burst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	burst.position = Vector3(0.0, 0.9, 0.0)
	add_child(burst)
	var tween := burst.create_tween().set_parallel(true)
	tween.tween_property(burst, "scale", Vector3.ONE * 1.35, 0.25)
	tween.tween_property(burst, "modulate:a", 0.0, 0.25)
	tween.chain().tween_callback(burst.queue_free)
