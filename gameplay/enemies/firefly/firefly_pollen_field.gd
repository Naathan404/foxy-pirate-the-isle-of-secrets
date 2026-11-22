class_name FireflyPollenField
extends Node3D
## Vùng dịch độc phát quang đom đóm: vũng ăn mòn hữu cơ có bọt sôi caustic,
## hào quang mặt đất và hạt ánh sáng lấp lánh bay lên.

enum Stage {
	SPREAD,
	ACTIVE,
	FADE_OUT,
}

const FIELD_GROUP := &"firefly_pollen_fields"
const FIELD_SHADER := preload("res://gameplay/enemies/firefly/firefly_pollen_field.gdshader")
const SPARK_MOTE_TEXTURE := preload("res://assets/sprites/enemies/firefly/firefly_spark_mote.png")
const DEFAULT_SPREAD_SECONDS := 0.22
const DEFAULT_FADE_SECONDS := 0.65
const MIN_RADIUS_METERS := 0.35
const MIN_DURATION_SECONDS := 0.35
const MIN_TICK_INTERVAL_SECONDS := 0.1
const AREA_HEIGHT_METERS := 1.65
const HITBOX_RADIUS_FACTOR := 0.62
const GROUND_PLANE_SCALE := 2.48
const GROUND_AURA_SCALE := 2.85
const GROUND_OFFSET_METERS := 0.036
const AURA_OFFSET_METERS := 0.024
const REHIT_TOLERANCE_SECONDS := 0.02

var _source: Node
var _source_team: int = CombatTeams.ENEMY
var _radius_meters: float = 1.35
var _duration_seconds: float = 4.6
var _remaining_seconds: float = 4.6
var _spread_seconds: float = DEFAULT_SPREAD_SECONDS
var _fade_seconds: float = DEFAULT_FADE_SECONDS
var _fade_remaining_seconds: float = DEFAULT_FADE_SECONDS
var _tick_interval_seconds: float = 0.85
var _tick_damage_hp: float = 0.6
var _tick_cooldown_seconds: float = 0.1
var _arm_delay_seconds: float = 0.0
var _stage: Stage = Stage.SPREAD
var _clock_seconds: float = 0.0
var _pulse_boost: float = 0.0
var _last_hit_time_by_actor: Dictionary[int, float] = {}

var _area: Area3D
var _pollen_plane: MeshInstance3D
var _pollen_material: ShaderMaterial
var _ground_aura: Sprite3D
var _rising_sparks: GPUParticles3D
var _bubble_pops: GPUParticles3D
var _field_light: OmniLight3D


static func create_spark_quad(quad_size: Vector2, additive: bool = true) -> QuadMesh:
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.albedo_texture = SPARK_MOTE_TEXTURE
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var quad := QuadMesh.new()
	quad.size = quad_size
	quad.material = mat
	return quad


static func create_fade_ramp_texture(start_color: Color, end_color: Color) -> GradientTexture1D:
	var grad := Gradient.new()
	grad.colors = PackedColorArray([start_color, end_color])
	grad.offsets = PackedFloat32Array([0.0, 1.0])
	var ramp := GradientTexture1D.new()
	ramp.gradient = grad
	return ramp


func setup(
	owner_node: Node,
	owner_team: int,
	radius_meters: float,
	duration_seconds: float,
	tick_interval_seconds: float,
	tick_damage_hp: float,
	arm_delay_seconds: float = 0.0
) -> void:
	_source = owner_node
	_source_team = owner_team
	_radius_meters = maxf(MIN_RADIUS_METERS, radius_meters)
	_duration_seconds = maxf(MIN_DURATION_SECONDS, duration_seconds)
	_remaining_seconds = _duration_seconds
	_tick_interval_seconds = maxf(MIN_TICK_INTERVAL_SECONDS, tick_interval_seconds)
	_tick_damage_hp = maxf(0.0, tick_damage_hp)
	_arm_delay_seconds = maxf(0.0, arm_delay_seconds)
	_fade_seconds = minf(DEFAULT_FADE_SECONDS, _duration_seconds * 0.45)
	_fade_remaining_seconds = _fade_seconds


func _ready() -> void:
	add_to_group(FIELD_GROUP)
	_build_area()
	_build_ground_aura()
	_build_pollen_plane()
	_build_spark_particles()
	_build_field_light()
	_update_spread_visuals(0.0)


func _physics_process(delta: float) -> void:
	var step := maxf(0.0, delta)
	_clock_seconds += step
	_pulse_boost = maxf(0.0, _pulse_boost - step * 2.8)
	if is_instance_valid(_pollen_material):
		_pollen_material.set_shader_parameter(&"pulse_boost", _pulse_boost)

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
	elif is_instance_valid(_ground_aura):
		var pulse := 1.0 + 0.04 * sin(_clock_seconds * 3.8)
		var base_scale := (_radius_meters * GROUND_AURA_SCALE) / 2.2
		_ground_aura.scale = Vector3.ONE * base_scale * pulse

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


func begin_fade_out() -> void:
	if _stage == Stage.FADE_OUT:
		return
	_stage = Stage.FADE_OUT
	_fade_remaining_seconds = _fade_seconds
	if is_in_group(FIELD_GROUP):
		remove_from_group(FIELD_GROUP)
	if is_instance_valid(_area):
		_area.set_deferred("monitoring", false)
	if is_instance_valid(_rising_sparks):
		_rising_sparks.emitting = false
	if is_instance_valid(_bubble_pops):
		_bubble_pops.emitting = false


func _tick_fade_out(step: float) -> void:
	_fade_remaining_seconds = maxf(0.0, _fade_remaining_seconds - step)
	var ratio := clampf(_fade_remaining_seconds / maxf(0.01, _fade_seconds), 0.0, 1.0)
	if is_instance_valid(_pollen_material):
		_pollen_material.set_shader_parameter(&"fade_progress", ratio)
	if is_instance_valid(_ground_aura):
		_ground_aura.modulate.a = 0.42 * ratio
	if is_instance_valid(_field_light):
		_field_light.light_energy = 1.15 * ratio
	if _fade_remaining_seconds <= 0.0:
		queue_free()


func _update_spread_visuals(progress: float) -> void:
	var eased := 1.0 - pow(1.0 - progress, 2.0)
	if is_instance_valid(_pollen_plane):
		_pollen_plane.scale = Vector3.ONE * lerpf(0.28, 1.0, eased)
	if is_instance_valid(_pollen_material):
		_pollen_material.set_shader_parameter(&"fade_progress", eased)
	if is_instance_valid(_ground_aura):
		var base_scale := (_radius_meters * GROUND_AURA_SCALE) / 2.2
		_ground_aura.scale = Vector3.ONE * base_scale * lerpf(0.35, 1.0, eased)
		_ground_aura.modulate.a = 0.42 * eased
	if is_instance_valid(_field_light):
		_field_light.light_energy = 1.15 * eased
	if is_instance_valid(_rising_sparks):
		_rising_sparks.amount_ratio = lerpf(0.25, 1.0, eased)
	if is_instance_valid(_bubble_pops):
		_bubble_pops.amount_ratio = lerpf(0.25, 1.0, eased)


func _build_area() -> void:
	_area = Area3D.new()
	_area.name = "PollenFieldArea"
	_area.collision_layer = 0
	_area.collision_mask = CombatLayers.PLAYER_HURTBOX
	_area.monitoring = true
	_area.monitorable = false
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = _radius_meters * HITBOX_RADIUS_FACTOR
	shape.height = AREA_HEIGHT_METERS
	collision.shape = shape
	collision.position = Vector3(0.0, AREA_HEIGHT_METERS * 0.5, 0.0)
	_area.add_child(collision)
	_area.area_entered.connect(_on_area_entered)
	add_child(_area)


func _build_ground_aura() -> void:
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	mat.albedo_texture = SPARK_MOTE_TEXTURE
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS

	_ground_aura = Sprite3D.new()
	_ground_aura.name = "ToxicGroundAura"
	_ground_aura.texture = SPARK_MOTE_TEXTURE
	_ground_aura.pixel_size = 0.01
	_ground_aura.rotation.x = -PI * 0.5
	_ground_aura.position = Vector3(0.0, AURA_OFFSET_METERS, 0.0)
	_ground_aura.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ground_aura.modulate = Color(0.76, 1.0, 0.24, 0.0)
	_ground_aura.material_override = mat
	add_child(_ground_aura)


func _build_pollen_plane() -> void:
	_pollen_material = ShaderMaterial.new()
	_pollen_material.shader = FIELD_SHADER
	_pollen_material.set_shader_parameter(&"seed_offset", randf_range(0.0, 50.0))
	_pollen_material.set_shader_parameter(&"fade_progress", 0.0)
	var plane := PlaneMesh.new()
	var span := _radius_meters * GROUND_PLANE_SCALE
	plane.size = Vector2(span, span)
	plane.material = _pollen_material
	_pollen_plane = MeshInstance3D.new()
	_pollen_plane.name = "PollenFieldPlane"
	_pollen_plane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_pollen_plane.mesh = plane
	_pollen_plane.position = Vector3(0.0, GROUND_OFFSET_METERS, 0.0)
	add_child(_pollen_plane)


func _build_spark_particles() -> void:
	var spark_count := clampi(int(roundf(_radius_meters * 54.0)), 32, 110)
	_rising_sparks = _create_gpu_emitter(
		"LuminousFireflySparks", spark_count, 1.45, _radius_meters * 0.88, Vector2(0.28, 0.28), true
	)
	var spark_mat := _rising_sparks.process_material as ParticleProcessMaterial
	spark_mat.initial_velocity_min = 0.42
	spark_mat.initial_velocity_max = 1.05
	spark_mat.gravity = Vector3(0.0, 0.32, 0.0)
	spark_mat.orbit_velocity_min = 0.22
	spark_mat.orbit_velocity_max = 0.58
	spark_mat.scale_min = 0.35
	spark_mat.scale_max = 1.05
	spark_mat.color_ramp = create_fade_ramp_texture(
		Color(0.95, 1.0, 0.48, 0.98), Color(0.55, 0.98, 0.16, 0.0)
	)
	add_child(_rising_sparks)
	_rising_sparks.emitting = true

	var pop_count := clampi(int(roundf(_radius_meters * 24.0)), 14, 48)
	_bubble_pops = _create_gpu_emitter(
		"AcidBubblePops", pop_count, 0.62, _radius_meters * 0.78, Vector2(0.18, 0.18), true
	)
	var pop_mat := _bubble_pops.process_material as ParticleProcessMaterial
	pop_mat.initial_velocity_min = 0.85
	pop_mat.initial_velocity_max = 1.75
	pop_mat.gravity = Vector3(0.0, -2.6, 0.0)
	pop_mat.scale_min = 0.45
	pop_mat.scale_max = 0.95
	pop_mat.color_ramp = create_fade_ramp_texture(
		Color(1.0, 0.98, 0.62, 0.95), Color(0.75, 1.0, 0.22, 0.0)
	)
	add_child(_bubble_pops)
	_bubble_pops.emitting = true


func _create_gpu_emitter(
	node_name: String,
	count: int,
	lifetime_seconds: float,
	emission_radius_meters: float,
	quad_size: Vector2,
	additive: bool
) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.name = node_name
	particles.emitting = false
	particles.amount = maxi(1, count)
	particles.lifetime = maxf(0.15, lifetime_seconds)
	particles.local_coords = true
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var span := maxf(0.5, emission_radius_meters) + 1.5
	particles.visibility_aabb = AABB(
		Vector3(-span, -0.5, -span), Vector3(span * 2.0, 4.0, span * 2.0)
	)
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	process.emission_ring_axis = Vector3.UP
	process.emission_ring_height = 0.16
	process.emission_ring_radius = maxf(0.15, emission_radius_meters)
	process.emission_ring_inner_radius = 0.0
	process.direction = Vector3.UP
	process.spread = 35.0
	particles.process_material = process
	particles.draw_pass_1 = create_spark_quad(quad_size, additive)
	return particles


func _build_field_light() -> void:
	_field_light = OmniLight3D.new()
	_field_light.name = "PollenFieldLight"
	_field_light.light_color = Color(0.84, 1.0, 0.28)
	_field_light.light_energy = 0.0
	_field_light.omni_range = _radius_meters * 2.15
	_field_light.shadow_enabled = false
	_field_light.position = Vector3(0.0, 0.45, 0.0)
	add_child(_field_light)


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
	if hurtbox == null or _tick_damage_hp <= 0.0 or _clock_seconds < _arm_delay_seconds:
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
	if hurtbox.take_damage(context) > 0.0:
		_pulse_boost = 1.2
