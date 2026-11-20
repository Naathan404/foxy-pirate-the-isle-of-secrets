class_name VenomAcidPool
extends Node3D
## Vùng axit mặt đất: loang ra, sủi bọt/bốc hơi gây sát thương độc và tan dần theo thời gian.

enum Stage {
	SPREAD,
	ACTIVE,
	FADE_OUT,
}

const POOL_GROUP := &"venom_acid_pools"
const PUDDLE_SHEET := preload("res://assets/sprites/enemies/venom_vine/venom_glob_and_pool.png")
const PARTICLE_SHEET := preload("res://assets/sprites/enemies/venom_vine/venom_acid_particles.png")
const POOL_SHADER := preload("res://gameplay/enemies/venom_vine/venom_acid_pool.gdshader")

const PARTICLE_CELL_SIZE := 256.0
const PUDDLE_BASE_FRAME := 4
const PUDDLE_FRAME_COUNT := 4
const PUDDLE_ANIMATION_FPS := 5.5
const PUDDLE_PIXEL_DIVISOR := 360.0
const DEFAULT_SPREAD_SECONDS := 0.24
const DEFAULT_FADE_SECONDS := 0.65
const MIN_RADIUS_METERS := 0.4
const MIN_DURATION_SECONDS := 0.3
const MIN_TICK_INTERVAL_SECONDS := 0.1
const POOL_AREA_HEIGHT_METERS := 1.6
const POOL_HITBOX_RADIUS_FACTOR := 0.92
const GROUND_AURA_SCALE_FACTOR := 2.35
const DECAL_GROUND_OFFSET_METERS := 0.035
const AURA_GROUND_OFFSET_METERS := 0.025
const REHIT_TOLERANCE_SECONDS := 0.02

var _source: Node
var _source_team: int = CombatTeams.ENEMY
var _radius_meters: float = 1.6
var _duration_seconds: float = 4.0
var _remaining_seconds: float = 4.0
var _spread_seconds: float = DEFAULT_SPREAD_SECONDS
var _fade_seconds: float = DEFAULT_FADE_SECONDS
var _fade_remaining_seconds: float = DEFAULT_FADE_SECONDS
var _tick_interval_seconds: float = 0.85
var _tick_damage_hp: float = 0.5
var _tick_cooldown_seconds: float = 0.1
var _snare_slow_ratio: float = 0.0
var _visual_tint: Color = Color.WHITE
var _stage: Stage = Stage.SPREAD
var _clock_seconds: float = 0.0
var _last_hit_time_by_actor: Dictionary[int, float] = {}

var _area: Area3D
var _puddle_sprite: Sprite3D
var _ground_aura: MeshInstance3D
var _ground_aura_material: ShaderMaterial
var _bubbles: CPUParticles3D
var _fumes: CPUParticles3D


func setup(
	owner_node: Node,
	owner_team: int,
	radius_meters: float,
	duration_seconds: float,
	tick_interval_seconds: float,
	tick_damage_hp: float,
	options: Dictionary = {}
) -> void:
	_source = owner_node
	_source_team = owner_team
	_radius_meters = maxf(MIN_RADIUS_METERS, radius_meters)
	_duration_seconds = maxf(MIN_DURATION_SECONDS, duration_seconds)
	_remaining_seconds = _duration_seconds
	_tick_interval_seconds = maxf(MIN_TICK_INTERVAL_SECONDS, tick_interval_seconds)
	_tick_damage_hp = maxf(0.0, tick_damage_hp)
	_spread_seconds = clampf(
		float(options.get("spread_duration_seconds", DEFAULT_SPREAD_SECONDS)),
		0.05,
		_duration_seconds * 0.4
	)
	_fade_seconds = clampf(
		float(options.get("fade_duration_seconds", DEFAULT_FADE_SECONDS)),
		0.1,
		_duration_seconds * 0.5
	)
	_fade_remaining_seconds = _fade_seconds
	_snare_slow_ratio = clampf(float(options.get("snare_slow_ratio", 0.0)), 0.0, 0.85)
	var tint_value: Variant = options.get("visual_tint", Color.WHITE)
	if tint_value is Color:
		_visual_tint = tint_value as Color


func _ready() -> void:
	add_to_group(POOL_GROUP)
	_build_area()
	_build_ground_aura()
	_build_puddle_sprite()
	_build_bubble_particles()
	_build_fume_particles()
	_update_spread_visuals(0.0)


func _physics_process(delta: float) -> void:
	var step := maxf(0.0, delta)
	_clock_seconds += step
	_update_puddle_frame()

	if _stage == Stage.FADE_OUT:
		_tick_fade_out(step)
		return

	_remaining_seconds = maxf(0.0, _remaining_seconds - step)
	if _stage == Stage.SPREAD:
		var spread_progress := clampf(_clock_seconds / _spread_seconds, 0.0, 1.0)
		_update_spread_visuals(spread_progress)
		if spread_progress >= 1.0:
			_stage = Stage.ACTIVE
			_apply_poison_tick()
	else:
		var pulse := 1.0 + sin(_clock_seconds * 3.2) * 0.025
		if is_instance_valid(_puddle_sprite):
			_puddle_sprite.scale = Vector3.ONE * pulse

	_tick_cooldown_seconds = maxf(0.0, _tick_cooldown_seconds - step)
	if _tick_cooldown_seconds <= 0.0:
		_tick_cooldown_seconds += _tick_interval_seconds
		_apply_poison_tick()

	if _remaining_seconds <= 0.0:
		begin_fade_out()


func get_radius() -> float:
	return _radius_meters


func is_fading() -> bool:
	return _stage == Stage.FADE_OUT


func get_remaining_seconds() -> float:
	return _remaining_seconds


func get_snare_slow_ratio() -> float:
	return _snare_slow_ratio


func begin_fade_out() -> void:
	if _stage == Stage.FADE_OUT:
		return
	_stage = Stage.FADE_OUT
	_fade_remaining_seconds = _fade_seconds
	if is_in_group(POOL_GROUP):
		remove_from_group(POOL_GROUP)
	if is_instance_valid(_area):
		_area.set_deferred("monitoring", false)
	if is_instance_valid(_bubbles):
		_bubbles.emitting = false
	if is_instance_valid(_fumes):
		_fumes.emitting = false


func _tick_fade_out(step: float) -> void:
	_fade_remaining_seconds = maxf(0.0, _fade_remaining_seconds - step)
	var ratio := clampf(_fade_remaining_seconds / maxf(0.01, _fade_seconds), 0.0, 1.0)
	if is_instance_valid(_puddle_sprite):
		_puddle_sprite.modulate.a = 0.94 * ratio
		_puddle_sprite.scale = Vector3.ONE * lerpf(0.84, 1.0, ratio)
	if is_instance_valid(_ground_aura_material):
		_ground_aura_material.set_shader_parameter("fade_progress", ratio)
	if _fade_remaining_seconds <= 0.0:
		queue_free()


func _update_spread_visuals(progress: float) -> void:
	var eased := 1.0 - pow(1.0 - progress, 2.0)
	var scale_factor := lerpf(0.28, 1.0, eased)
	if is_instance_valid(_puddle_sprite):
		_puddle_sprite.scale = Vector3.ONE * scale_factor
		_puddle_sprite.modulate = Color(
			_visual_tint.r, _visual_tint.g, _visual_tint.b, lerpf(0.45, 0.94, eased)
		)
	if is_instance_valid(_ground_aura_material):
		_ground_aura_material.set_shader_parameter("fade_progress", eased)


func _update_puddle_frame() -> void:
	if not is_instance_valid(_puddle_sprite):
		return
	var offset := int(_clock_seconds * PUDDLE_ANIMATION_FPS) % PUDDLE_FRAME_COUNT
	_puddle_sprite.frame = PUDDLE_BASE_FRAME + offset


func _build_area() -> void:
	_area = Area3D.new()
	_area.name = "PoisonPoolArea"
	_area.collision_layer = 0
	_area.collision_mask = CombatLayers.PLAYER_HURTBOX
	_area.monitoring = true
	_area.monitorable = false
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = _radius_meters * POOL_HITBOX_RADIUS_FACTOR
	shape.height = POOL_AREA_HEIGHT_METERS
	collision.shape = shape
	collision.position = Vector3(0.0, POOL_AREA_HEIGHT_METERS * 0.5, 0.0)
	_area.add_child(collision)
	_area.area_entered.connect(_on_area_entered)
	add_child(_area)


func _build_ground_aura() -> void:
	_ground_aura_material = ShaderMaterial.new()
	_ground_aura_material.shader = POOL_SHADER
	_ground_aura_material.set_shader_parameter("seed_offset", randf_range(0.0, 50.0))
	_ground_aura_material.set_shader_parameter("fade_progress", 0.0)
	var plane := PlaneMesh.new()
	var span := _radius_meters * GROUND_AURA_SCALE_FACTOR
	plane.size = Vector2(span, span)
	plane.material = _ground_aura_material
	_ground_aura = MeshInstance3D.new()
	_ground_aura.name = "GroundAura"
	_ground_aura.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ground_aura.mesh = plane
	_ground_aura.position = Vector3(0.0, AURA_GROUND_OFFSET_METERS, 0.0)
	add_child(_ground_aura)


func _build_puddle_sprite() -> void:
	_puddle_sprite = Sprite3D.new()
	_puddle_sprite.name = "AcidPuddleDecal"
	_puddle_sprite.texture = PUDDLE_SHEET
	_puddle_sprite.hframes = 4
	_puddle_sprite.vframes = 2
	_puddle_sprite.frame = PUDDLE_BASE_FRAME
	_puddle_sprite.pixel_size = (_radius_meters * 2.0) / PUDDLE_PIXEL_DIVISOR
	_puddle_sprite.rotation.x = -PI * 0.5
	_puddle_sprite.rotation.z = randf_range(0.0, TAU)
	_puddle_sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_puddle_sprite.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_puddle_sprite.position = Vector3(0.0, DECAL_GROUND_OFFSET_METERS, 0.0)
	_puddle_sprite.modulate = _visual_tint
	add_child(_puddle_sprite)


func _build_bubble_particles() -> void:
	_bubbles = CPUParticles3D.new()
	_bubbles.name = "AcidBubbles"
	_bubbles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_bubbles.amount = maxi(6, int(roundf(_radius_meters * 6.0)))
	_bubbles.lifetime = 0.65
	_bubbles.local_coords = false
	_bubbles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_bubbles.emission_box_extents = Vector3(_radius_meters * 0.55, 0.05, _radius_meters * 0.55)
	_bubbles.direction = Vector3.UP
	_bubbles.spread = 18.0
	_bubbles.initial_velocity_min = 0.35
	_bubbles.initial_velocity_max = 0.85
	_bubbles.gravity = Vector3(0.0, 0.4, 0.0)
	_bubbles.scale_amount_min = 0.16
	_bubbles.scale_amount_max = 0.34
	_bubbles.color = Color(0.85, 1.0, 0.65, 0.9) * _visual_tint
	_bubbles.mesh = _create_particle_quad(0, Vector2(0.45, 0.45))
	_bubbles.position = Vector3(0.0, 0.08, 0.0)
	add_child(_bubbles)
	_bubbles.emitting = true


func _build_fume_particles() -> void:
	_fumes = CPUParticles3D.new()
	_fumes.name = "AcidFumes"
	_fumes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_fumes.amount = maxi(6, int(roundf(_radius_meters * 5.0)))
	_fumes.lifetime = 0.95
	_fumes.local_coords = false
	_fumes.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_fumes.emission_box_extents = Vector3(_radius_meters * 0.5, 0.06, _radius_meters * 0.5)
	_fumes.direction = Vector3.UP
	_fumes.spread = 24.0
	_fumes.initial_velocity_min = 0.45
	_fumes.initial_velocity_max = 1.0
	_fumes.gravity = Vector3(0.0, 0.5, 0.0)
	_fumes.scale_amount_min = 0.35
	_fumes.scale_amount_max = 0.7
	_fumes.color = Color(0.75, 1.0, 0.65, 0.58) * _visual_tint
	_fumes.mesh = _create_particle_quad(1, Vector2(0.8, 0.8))
	_fumes.position = Vector3(0.0, 0.14, 0.0)
	add_child(_fumes)
	_fumes.emitting = true


func _create_particle_quad(cell_column: int, quad_size: Vector2) -> QuadMesh:
	var atlas := AtlasTexture.new()
	atlas.atlas = PARTICLE_SHEET
	atlas.region = Rect2(
		float(cell_column) * PARTICLE_CELL_SIZE, 0.0, PARTICLE_CELL_SIZE, PARTICLE_CELL_SIZE
	)
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.albedo_texture = atlas
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var quad := QuadMesh.new()
	quad.size = quad_size
	quad.material = mat
	return quad


func _on_area_entered(other_area: Area3D) -> void:
	if _stage == Stage.FADE_OUT:
		return
	_apply_poison_to_hurtbox(other_area as HurtBox)


func _apply_poison_tick() -> void:
	if _tick_damage_hp <= 0.0 or not is_instance_valid(_area) or _stage == Stage.FADE_OUT:
		return
	for body_area in _area.get_overlapping_areas():
		_apply_poison_to_hurtbox(body_area as HurtBox)


func _apply_poison_to_hurtbox(hurtbox: HurtBox) -> void:
	if hurtbox == null or _tick_damage_hp <= 0.0:
		return
	var actor_id := (
		hurtbox.actor.get_instance_id()
		if is_instance_valid(hurtbox.actor)
		else hurtbox.get_instance_id()
	)
	var last_time := float(_last_hit_time_by_actor.get(actor_id, -INF))
	if _clock_seconds - last_time < _tick_interval_seconds - REHIT_TOLERANCE_SECONDS:
		return
	_last_hit_time_by_actor[actor_id] = _clock_seconds
	var context := DamageContext.new()
	context.source = _source if is_instance_valid(_source) else self
	context.source_team = _source_team
	context.base_amount_hp = _tick_damage_hp
	context.amount_hp = _tick_damage_hp
	context.tag = &"poison"
	context.origin = global_position
	context.knockback_multiplier = 0.0
	hurtbox.take_damage(context)
