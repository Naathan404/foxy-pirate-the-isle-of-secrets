class_name MushroomSporeStream
extends Node3D
## Luồng khói bào tử vật lý thuần phát từ gốc nấm: mật độ hạt cao dễ quan sát,
## vùng collider gây độc nhỏ hơn vùng hiển thị và chỉ kích hoạt tại nơi khói đặc đã bay tới.

const SPORE_CLOUD_SCRIPT := preload("res://gameplay/enemies/mushroom/mushroom_spore_cloud.gd")
const STREAM_GROUP := &"mushroom_spore_stream"
const WALL_CHECK_HEIGHT_METERS := 0.7
const STREAM_MIST_COUNT := 220
const STREAM_SPORE_COUNT := 680
const NEAR_MIST_COUNT := 64
const NEAR_SPORE_COUNT := 180
const PUFF_EMIT_INTERVAL := 0.07
const PUFF_SPEED_MIN_FACTOR := 0.84
const PUFF_SPEED_MAX_FACTOR := 0.92
const PUFF_DRAG_MIN := 9.2
const PUFF_DRAG_MAX := 10.8
const NEAR_SPILL_SPEED_MIN := 2.2
const NEAR_SPILL_SPEED_MAX := 3.9
const NEAR_SPILL_DRAG_MIN := 2.5
const NEAR_SPILL_DRAG_MAX := 3.3
const PUFF_MIN_DAMAGE_AGE := 0.14
const PUFF_DAMAGE_LIFE_RATIO := 0.68
const PUFF_TAPER_START_RATIO := 0.56
const PUFF_GROW_SECONDS := 1.4
const SETTLE_SPEED_THRESHOLD := 4.2
const MAX_MIST_PATCHES := 5
const MIST_MAX_OPACITY := 0.25

var _owner_mushroom: MushroomEnemy
var _origin: Vector3 = Vector3.ZERO
var _has_origin: bool = false
var _direction: Vector3 = Vector3.BACK
var _base_basis: Basis = Basis.IDENTITY
var _jet_speed_min: float = 11.8
var _jet_speed_max: float = 14.4
var _particle_lifetime: float = 3.8
var _duration_seconds: float = 1.65
var _start_radius: float = 0.35
var _end_radius: float = 1.05
var _fan_degrees: float = 52.0
var _tick_interval: float = 0.45
var _tick_damage: float = 1.0
var _near_cloud_radius: float = 0.85
var _ground_y: float = 0.0

var _elapsed: float = 0.0
var _post_stop_elapsed: float = 0.0
var _emit_accum: float = 0.0
var _emit_index: int = 0
var _tick_remaining: float = 0.0
var _streaming: bool = true
var _sway_phase: float = 0.0
var _wind_cross_world: Vector3 = Vector3.ZERO
var _rng := RandomNumberGenerator.new()

var _emitters: Array[GPUParticles3D] = []
var _puffs: Array[Dictionary] = []
var _mist_patches: Array[Dictionary] = []
var _query_sphere: SphereShape3D


func setup(config: Dictionary) -> void:
	_rng.randomize()
	_owner_mushroom = config.get("owner", null) as MushroomEnemy
	if config.has("origin"):
		_origin = config.get("origin", Vector3.ZERO) as Vector3
		_has_origin = true
	var dir := config.get("direction", Vector3.BACK) as Vector3
	dir.y = 0.0
	_direction = dir.normalized() if not dir.is_zero_approx() else Vector3.BACK
	_jet_speed_min = maxf(4.0, float(config.get("jet_speed_min", 11.8)))
	_jet_speed_max = maxf(_jet_speed_min, float(config.get("jet_speed_max", 14.4)))
	_particle_lifetime = maxf(1.2, float(config.get("particle_lifetime", 3.8)))
	_duration_seconds = maxf(0.4, float(config.get("duration_seconds", 1.65)))
	_start_radius = maxf(0.25, float(config.get("start_radius", 0.35)))
	_end_radius = maxf(_start_radius, float(config.get("end_radius", 1.05)))
	_fan_degrees = clampf(float(config.get("fan_degrees", 52.0)), 18.0, 100.0)
	_tick_interval = maxf(0.1, float(config.get("tick_interval", 0.45)))
	_tick_damage = maxf(0.0, float(config.get("tick_damage", 1.0)))
	_near_cloud_radius = maxf(0.0, float(config.get("near_cloud_radius", 0.85)))
	_ground_y = float(config.get("ground_y", 0.0))
	_sway_phase = _rng.randf_range(0.0, TAU)
	var cross := Vector3(-_direction.z, 0.0, _direction.x).normalized()
	_wind_cross_world = cross * _rng.randf_range(-0.85, 0.85)


func _ready() -> void:
	add_to_group(STREAM_GROUP)
	if _has_origin:
		global_position = _origin
	_query_sphere = SphereShape3D.new()
	_orient_along_direction()
	_base_basis = global_basis
	_build_emitters()
	_emit_puff_volley()


func _physics_process(delta: float) -> void:
	var step := maxf(0.0, delta)
	_elapsed += step
	if _streaming:
		_apply_breeze_sway()
		_emit_accum += step
		while _emit_accum >= PUFF_EMIT_INTERVAL:
			_emit_accum -= PUFF_EMIT_INTERVAL
			_emit_puff_volley()
		if _elapsed >= _duration_seconds:
			stop_emitting()
	else:
		_post_stop_elapsed += step

	_step_puffs(step)
	_update_mist_patches(step)

	_tick_remaining -= step
	if _tick_remaining <= 0.0:
		_tick_remaining = _tick_interval
		_apply_poison_tick()

	if (
		not _streaming
		and _puffs.is_empty()
		and _mist_patches.is_empty()
		and _post_stop_elapsed >= _particle_lifetime + 0.35
	):
		queue_free()


func stop_emitting() -> void:
	if not _streaming:
		return
	_streaming = false
	for emitter: GPUParticles3D in _emitters:
		if is_instance_valid(emitter):
			emitter.emitting = false


func is_emitting() -> bool:
	return _streaming


func get_active_puff_count() -> int:
	return _puffs.size()


func get_damage_active_puff_count() -> int:
	var count := 0
	for puff: Dictionary in _puffs:
		if float(puff["damage_radius"]) > 0.0:
			count += 1
	return count


func get_slow_puff_count() -> int:
	var count := 0
	for puff: Dictionary in _puffs:
		var vel := puff["vel"] as Vector3
		if vel.length() <= SETTLE_SPEED_THRESHOLD:
			count += 1
	return count


func get_furthest_puff_distance() -> float:
	var max_dist := 0.0
	for puff: Dictionary in _puffs:
		var pos := puff["pos"] as Vector3
		var dist := Vector2(pos.x - global_position.x, pos.z - global_position.z).length()
		if dist > max_dist:
			max_dist = dist
	return max_dist


func get_max_active_damage_radius() -> float:
	var max_rad := 0.0
	for puff: Dictionary in _puffs:
		var rad := float(puff["damage_radius"])
		if rad > max_rad:
			max_rad = rad
	return max_rad


func get_first_puff_damage_radius() -> float:
	if _puffs.is_empty():
		return 0.0
	return float(_puffs[0]["damage_radius"])


func get_active_mist_patch_count() -> int:
	return _mist_patches.size()


func covers_point(world_position: Vector3, overlap_factor: float) -> bool:
	for puff: Dictionary in _puffs:
		var rad := float(puff["damage_radius"]) * overlap_factor
		if rad <= 0.0:
			continue
		var pos := puff["pos"] as Vector3
		var dist := Vector2(world_position.x - pos.x, world_position.z - pos.z).length()
		if dist <= rad:
			return true
	return false


func _orient_along_direction() -> void:
	if not _direction.is_zero_approx():
		look_at(global_position + _direction, Vector3.UP)


func _apply_breeze_sway() -> void:
	var wave := sin(_elapsed * 2.2 + _sway_phase) * 0.68 + cos(_elapsed * 3.7) * 0.32
	var yaw := deg_to_rad(13.0) * wave
	global_basis = _base_basis.rotated(Vector3.UP, yaw)


func _get_current_forward() -> Vector3:
	var fwd := -global_basis.z
	fwd.y = 0.0
	return fwd.normalized() if not fwd.is_zero_approx() else _direction


func _emit_puff_volley() -> void:
	_emit_index += 1
	var fwd := _get_current_forward()
	var half_rad := deg_to_rad(_fan_degrees * 0.28)
	var lane_bias := [-0.45, 0.0, 0.45][_emit_index % 3] as float
	var angle := clampf(lane_bias + _rng.randf_range(-0.35, 0.35), -1.0, 1.0) * half_rad
	var jet_dir := fwd.rotated(Vector3.UP, angle).normalized()
	var jet_speed := _rng.randf_range(
		_jet_speed_min * PUFF_SPEED_MIN_FACTOR, _jet_speed_max * PUFF_SPEED_MAX_FACTOR
	)
	(
		_puffs
		. append(
			{
				"pos": Vector3(global_position.x, _ground_y, global_position.z) + jet_dir * 0.35,
				"vel": jet_dir * jet_speed,
				"drag": _rng.randf_range(PUFF_DRAG_MIN + 0.3, PUFF_DRAG_MAX + 0.3),
				"damage_radius": 0.0,
				"start_radius": _start_radius,
				"max_radius": _end_radius,
				"mist_visual_radius": maxf(_end_radius * 1.85, 1.9),
				"grow_seconds": PUFF_GROW_SECONDS,
				"age": 0.0,
				"lifetime": _particle_lifetime * 0.96,
			}
		)
	)

	if _near_cloud_radius > 0.0 and _emit_index % 2 == 1:
		var near_angle := _rng.randf_range(-deg_to_rad(42.0), deg_to_rad(42.0))
		var near_dir := fwd.rotated(Vector3.UP, near_angle).normalized()
		var near_speed := _rng.randf_range(NEAR_SPILL_SPEED_MIN, NEAR_SPILL_SPEED_MAX)
		(
			_puffs
			. append(
				{
					"pos":
					Vector3(global_position.x, _ground_y, global_position.z) + near_dir * 0.3,
					"vel": near_dir * near_speed,
					"drag": _rng.randf_range(NEAR_SPILL_DRAG_MIN, NEAR_SPILL_DRAG_MAX),
					"damage_radius": 0.0,
					"start_radius": minf(_start_radius, _near_cloud_radius * 0.45),
					"max_radius": _near_cloud_radius,
					"mist_visual_radius": maxf(_near_cloud_radius * 1.9, 1.65),
					"grow_seconds": 0.85,
					"age": 0.0,
					"lifetime": maxf(2.2, _particle_lifetime * 0.68),
				}
			)
		)


func _step_puffs(step: float) -> void:
	var space := get_world_3d().direct_space_state if is_inside_tree() else null
	var idx := _puffs.size() - 1
	while idx >= 0:
		var puff := _puffs[idx]
		var age := float(puff["age"]) + step
		var life := float(puff["lifetime"])
		if age >= life:
			_puffs.remove_at(idx)
			idx -= 1
			continue
		puff["age"] = age
		var life_t := clampf(age / life, 0.0, 1.0)
		puff["damage_radius"] = _compute_puff_damage_radius(puff, age, life_t)

		var vel := puff["vel"] as Vector3
		var spd := vel.length()
		var drag := float(puff["drag"])
		if spd > 0.001:
			var next_spd := maxf(0.0, spd - drag * step)
			vel = vel * (next_spd / spd)
		vel += _wind_cross_world * lerpf(0.18, 0.78, life_t) * step

		var pos := puff["pos"] as Vector3
		var next_pos := pos + vel * step
		if space != null and pos.distance_squared_to(next_pos) > 0.0001:
			var ray_from := Vector3(pos.x, _ground_y + WALL_CHECK_HEIGHT_METERS, pos.z)
			var ray_to := Vector3(next_pos.x, _ground_y + WALL_CHECK_HEIGHT_METERS, next_pos.z)
			var query := PhysicsRayQueryParameters3D.create(ray_from, ray_to, CombatLayers.WORLD)
			if is_instance_valid(_owner_mushroom):
				query.exclude = [_owner_mushroom.get_rid()]
			var hit := space.intersect_ray(query)
			if not hit.is_empty():
				var hit_pos := hit["position"] as Vector3
				var normal := hit["normal"] as Vector3
				normal.y = 0.0
				if not normal.is_zero_approx():
					normal = normal.normalized()
					next_pos = Vector3(hit_pos.x, _ground_y, hit_pos.z) + normal * 0.45
					vel = vel.slide(normal) * 0.35
				else:
					next_pos = pos
					vel = Vector3.ZERO
		puff["pos"] = next_pos
		puff["vel"] = vel

		if vel.length() <= SETTLE_SPEED_THRESHOLD and age >= 0.22:
			_maybe_spawn_mist_patch(next_pos, float(puff["mist_visual_radius"]))
		idx -= 1


func _compute_puff_damage_radius(puff: Dictionary, age: float, life_t: float) -> float:
	# Damage only activates after particles emerge visibly and ends before they fade away.
	if age < PUFF_MIN_DAMAGE_AGE or life_t >= PUFF_DAMAGE_LIFE_RATIO:
		return 0.0
	var active_span := maxf(0.2, float(puff["grow_seconds"]) - PUFF_MIN_DAMAGE_AGE)
	var grow_t := clampf((age - PUFF_MIN_DAMAGE_AGE) / active_span, 0.0, 1.0)
	var base_rad := lerpf(float(puff["start_radius"]), float(puff["max_radius"]), grow_t)
	if life_t > PUFF_TAPER_START_RATIO:
		var taper_t := (
			(life_t - PUFF_TAPER_START_RATIO)
			/ maxf(0.02, PUFF_DAMAGE_LIFE_RATIO - PUFF_TAPER_START_RATIO)
		)
		base_rad *= lerpf(1.0, 0.4, clampf(taper_t, 0.0, 1.0))
	return base_rad


func _maybe_spawn_mist_patch(world_pos: Vector3, patch_radius: float) -> void:
	if _mist_patches.size() >= MAX_MIST_PATCHES or not is_inside_tree():
		return
	for patch: Dictionary in _mist_patches:
		var p_pos := patch["pos"] as Vector3
		if Vector2(world_pos.x - p_pos.x, world_pos.z - p_pos.z).length() < 2.2:
			return
	var floor_hit := _sample_floor(world_pos)
	if floor_hit.is_empty():
		return
	var ground_pos := floor_hit["position"] as Vector3
	var mat := ShaderMaterial.new()
	mat.shader = SPORE_CLOUD_SCRIPT.GROUND_MIST_SHADER
	mat.set_shader_parameter("opacity", 0.0)
	mat.set_shader_parameter("seed_offset", _rng.randf_range(0.0, 100.0))
	var plane := PlaneMesh.new()
	var span := (
		patch_radius
		* SPORE_CLOUD_SCRIPT.DEFAULT_VISUAL_SPREAD_SCALE
		* SPORE_CLOUD_SCRIPT.DEFAULT_GROUND_MIST_SCALE
	)
	plane.size = Vector2(span, span)
	plane.material = mat
	var mesh := MeshInstance3D.new()
	mesh.name = "DynamicGroundMist"
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.mesh = plane
	add_child(mesh)
	mesh.global_position = ground_pos + Vector3.UP * 0.025
	(
		_mist_patches
		. append(
			{
				"mesh": mesh,
				"material": mat,
				"pos": ground_pos,
				"radius": patch_radius,
				"opacity": 0.0,
			}
		)
	)


func _update_mist_patches(step: float) -> void:
	var idx := _mist_patches.size() - 1
	while idx >= 0:
		var patch := _mist_patches[idx]
		var p_pos := patch["pos"] as Vector3
		var p_rad := float(patch["radius"])
		var cover_weight := 0.0
		for puff: Dictionary in _puffs:
			var puff_pos := puff["pos"] as Vector3
			var dist := Vector2(puff_pos.x - p_pos.x, puff_pos.z - p_pos.z).length()
			if dist > p_rad * 1.05:
				continue
			var spd := (puff["vel"] as Vector3).length()
			var slow_factor := lerpf(1.0, 0.3, clampf(spd / 7.5, 0.0, 1.0))
			var remaining := float(puff["lifetime"]) - float(puff["age"])
			var life_fade := clampf(remaining / 0.85, 0.0, 1.0)
			cover_weight += slow_factor * life_fade

		var target := clampf(cover_weight * 0.08, 0.0, MIST_MAX_OPACITY)
		var next_opacity := move_toward(float(patch["opacity"]), target, step * 0.38)
		patch["opacity"] = next_opacity
		var mat := patch["material"] as ShaderMaterial
		if is_instance_valid(mat):
			mat.set_shader_parameter("opacity", next_opacity)

		if not _streaming and target <= 0.001 and next_opacity <= 0.004:
			var mesh := patch["mesh"] as MeshInstance3D
			if is_instance_valid(mesh):
				mesh.queue_free()
			_mist_patches.remove_at(idx)
		idx -= 1


func _build_emitters() -> void:
	var mist_tex := SPORE_CLOUD_SCRIPT._create_soft_mist_texture()
	var spore_tex := SPORE_CLOUD_SCRIPT._create_purple_spore_texture()
	var half_fan := _fan_degrees * 0.5
	var mist_peak := SPORE_CLOUD_SCRIPT.MIST_GLOW_START_COLOR
	mist_peak.a = minf(0.62, mist_peak.a * 1.18)
	var mist_scale := _stream_scale_curve(0.62, 1.24, 1.82)
	var spore_scale := _stream_scale_curve(0.85, 1.15, 0.56)
	var jet_damping_curve := _stream_damping_curve(0.31, 0.48)
	var near_damping_curve := _stream_damping_curve(0.28, 0.45)
	var jet_vel_limit := _stream_velocity_limit_curve(20.0, 12.0, 1.5, 1.15)
	var near_vel_limit := _stream_velocity_limit_curve(8.0, 4.5, 1.25, 0.95)

	var stream_mist := _create_emitter(
		{
			"name": "StreamMist",
			"texture": mist_tex,
			"count": STREAM_MIST_COUNT,
			"lifetime": _particle_lifetime * 0.95,
			"quad_size": Vector2(1.5, 1.5),
			"additive": false,
			"box_extents": Vector3(0.72, 0.24, 0.36),
			"spread_deg": half_fan * 0.88,
			"speed_range": Vector2(_jet_speed_min * 0.95, _jet_speed_max * 0.98),
			"damping_range": Vector2(PUFF_DRAG_MIN, PUFF_DRAG_MAX),
			"damping_curve": jet_damping_curve,
			"vel_limit_curve": jet_vel_limit,
			"dir": Vector3(0.0, 0.03, -1.0),
			"gravity": Vector3(_wind_cross_world.x * 0.22, 0.15, _wind_cross_world.z * 0.22),
			"turb_strength": 1.65,
			"peak_color": mist_peak,
			"end_color": SPORE_CLOUD_SCRIPT.MIST_GLOW_END_COLOR,
			"scale_range": Vector2(0.82, 1.38),
			"scale_curve": mist_scale,
		}
	)
	add_child(stream_mist)
	stream_mist.emitting = true
	_emitters.append(stream_mist)

	var stream_spores := _create_emitter(
		{
			"name": "StreamSpores",
			"texture": spore_tex,
			"count": STREAM_SPORE_COUNT,
			"lifetime": _particle_lifetime,
			"quad_size": Vector2(0.7, 0.7),
			"additive": true,
			"box_extents": Vector3(0.68, 0.24, 0.34),
			"spread_deg": half_fan,
			"speed_range": Vector2(_jet_speed_min, _jet_speed_max * 1.04),
			"damping_range": Vector2(PUFF_DRAG_MIN - 0.3, PUFF_DRAG_MAX - 0.2),
			"damping_curve": jet_damping_curve,
			"vel_limit_curve": jet_vel_limit,
			"dir": Vector3(0.0, 0.04, -1.0),
			"gravity": Vector3(_wind_cross_world.x * 0.28, 0.32, _wind_cross_world.z * 0.28),
			"turb_strength": 2.1,
			"peak_color": SPORE_CLOUD_SCRIPT.SPORE_GLOW_START_COLOR,
			"end_color": SPORE_CLOUD_SCRIPT.SPORE_GLOW_END_COLOR,
			"scale_range":
			Vector2(
				SPORE_CLOUD_SCRIPT.SPORE_SCALE_MIN * 1.12,
				SPORE_CLOUD_SCRIPT.SPORE_SCALE_MAX * 1.1,
			),
			"scale_curve": spore_scale,
		}
	)
	add_child(stream_spores)
	stream_spores.emitting = true
	_emitters.append(stream_spores)

	if _near_cloud_radius > 0.0:
		var near_mist := _create_emitter(
			{
				"name": "NearSpillMist",
				"texture": mist_tex,
				"count": NEAR_MIST_COUNT,
				"lifetime": maxf(2.2, _particle_lifetime * 0.68),
				"quad_size": Vector2(1.45, 1.45),
				"additive": false,
				"box_extents": Vector3(0.75, 0.22, 0.4),
				"spread_deg": 56.0,
				"speed_range": Vector2(NEAR_SPILL_SPEED_MIN, NEAR_SPILL_SPEED_MAX),
				"damping_range": Vector2(NEAR_SPILL_DRAG_MIN, NEAR_SPILL_DRAG_MAX),
				"damping_curve": near_damping_curve,
				"vel_limit_curve": near_vel_limit,
				"dir": Vector3(0.0, 0.02, -1.0),
				"gravity": Vector3(0.0, 0.14, 0.0),
				"turb_strength": 1.2,
				"peak_color": mist_peak,
				"end_color": SPORE_CLOUD_SCRIPT.MIST_GLOW_END_COLOR,
				"scale_range": Vector2(0.75, 1.2),
				"scale_curve": mist_scale,
			}
		)
		add_child(near_mist)
		near_mist.emitting = true
		_emitters.append(near_mist)

		var near_spores := _create_emitter(
			{
				"name": "NearSpillSpores",
				"texture": spore_tex,
				"count": NEAR_SPORE_COUNT,
				"lifetime": maxf(2.2, _particle_lifetime * 0.72),
				"quad_size": Vector2(0.68, 0.68),
				"additive": true,
				"box_extents": Vector3(0.72, 0.22, 0.4),
				"spread_deg": 62.0,
				"speed_range": Vector2(NEAR_SPILL_SPEED_MIN, NEAR_SPILL_SPEED_MAX * 1.1),
				"damping_range": Vector2(NEAR_SPILL_DRAG_MIN, NEAR_SPILL_DRAG_MAX),
				"damping_curve": near_damping_curve,
				"vel_limit_curve": near_vel_limit,
				"dir": Vector3(0.0, 0.03, -1.0),
				"gravity": Vector3(0.0, 0.32, 0.0),
				"turb_strength": 1.6,
				"peak_color": SPORE_CLOUD_SCRIPT.SPORE_GLOW_START_COLOR,
				"end_color": SPORE_CLOUD_SCRIPT.SPORE_GLOW_END_COLOR,
				"scale_range":
				Vector2(SPORE_CLOUD_SCRIPT.SPORE_SCALE_MIN, SPORE_CLOUD_SCRIPT.SPORE_SCALE_MAX),
				"scale_curve": spore_scale,
			}
		)
		add_child(near_spores)
		near_spores.emitting = true
		_emitters.append(near_spores)


func _create_emitter(cfg: Dictionary) -> GPUParticles3D:
	var particles := GPUParticles3D.new()
	particles.name = String(cfg["name"])
	particles.emitting = false
	particles.amount = int(cfg["count"])
	particles.lifetime = float(cfg["lifetime"])
	particles.local_coords = false
	particles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	particles.visibility_aabb = AABB(Vector3(-18.0, -3.0, -18.0), Vector3(36.0, 8.0, 36.0))

	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = cfg["box_extents"] as Vector3
	process.direction = (cfg["dir"] as Vector3).normalized()
	process.spread = float(cfg["spread_deg"])
	var speed_range := cfg["speed_range"] as Vector2
	process.initial_velocity_min = speed_range.x
	process.initial_velocity_max = speed_range.y
	var damping_range := cfg["damping_range"] as Vector2
	process.damping_min = damping_range.x
	process.damping_max = damping_range.y
	process.damping_curve = cfg["damping_curve"] as CurveTexture
	process.velocity_limit_curve = cfg["vel_limit_curve"] as CurveTexture
	process.gravity = cfg["gravity"] as Vector3
	process.turbulence_enabled = true
	process.turbulence_noise_strength = float(cfg["turb_strength"])
	process.turbulence_noise_scale = 1.45
	process.turbulence_noise_speed = Vector3(0.75, 0.45, 0.75)
	process.turbulence_noise_speed_random = 0.5
	process.turbulence_influence_min = 0.22
	process.turbulence_influence_max = 0.68
	process.turbulence_influence_over_life = _turbulence_life_curve()
	var scale_range := cfg["scale_range"] as Vector2
	process.scale_min = scale_range.x
	process.scale_max = scale_range.y
	process.scale_curve = cfg["scale_curve"] as CurveTexture
	process.color_ramp = _stream_color_ramp(cfg["peak_color"] as Color, cfg["end_color"] as Color)
	particles.process_material = process
	particles.draw_pass_1 = _particle_quad(
		cfg["texture"] as Texture2D, cfg["quad_size"] as Vector2, bool(cfg["additive"])
	)
	return particles


func _particle_quad(texture: Texture2D, quad_size: Vector2, additive: bool) -> QuadMesh:
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	mat.albedo_texture = texture
	if additive:
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	var mesh := QuadMesh.new()
	mesh.size = quad_size
	mesh.material = mat
	return mesh


func _apply_poison_tick() -> void:
	if _tick_damage <= 0.0 or not is_inside_tree() or _puffs.is_empty():
		return
	var space := get_world_3d().direct_space_state
	if space == null:
		return
	var hit_actors: Dictionary = {}
	var sampled_centers: Array[Vector3] = []
	for puff: Dictionary in _puffs:
		var dmg_rad := float(puff["damage_radius"])
		if dmg_rad <= 0.0:
			continue
		var pos := puff["pos"] as Vector3
		var skip := false
		for center: Vector3 in sampled_centers:
			if Vector2(pos.x - center.x, pos.z - center.z).length() < 0.65:
				skip = true
				break
		if skip:
			continue
		sampled_centers.append(pos)
		_query_poison_sphere(space, pos + Vector3.UP * 0.85, dmg_rad, hit_actors)


func _query_poison_sphere(
	space: PhysicsDirectSpaceState3D, center: Vector3, radius: float, hit_actors: Dictionary
) -> void:
	_query_sphere.radius = radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _query_sphere
	query.transform = Transform3D(Basis.IDENTITY, center)
	query.collision_mask = CombatLayers.PLAYER_HURTBOX
	query.collide_with_areas = true
	query.collide_with_bodies = false
	for hit in space.intersect_shape(query, 8):
		_try_apply_poison_to_hit(hit.get("collider") as HurtBox, hit_actors)


func _try_apply_poison_to_hit(hurtbox: HurtBox, hit_actors: Dictionary) -> void:
	if hurtbox == null or not is_instance_valid(hurtbox.actor):
		return
	if hurtbox.actor == _owner_mushroom:
		return
	var actor_id := hurtbox.actor.get_instance_id()
	if hit_actors.has(actor_id):
		return
	hit_actors[actor_id] = true
	var damage := DamageContext.new()
	damage.source = _owner_mushroom if is_instance_valid(_owner_mushroom) else self
	damage.source_team = CombatTeams.ENEMY
	damage.base_amount_hp = _tick_damage
	damage.amount_hp = _tick_damage
	damage.tag = &"poison"
	damage.knockback_multiplier = 0.0
	hurtbox.take_damage(damage)


func _sample_floor(at_pos: Vector3) -> Dictionary:
	if not is_inside_tree():
		return {}
	var space := get_world_3d().direct_space_state
	if space == null:
		return {}
	var query := PhysicsRayQueryParameters3D.create(
		Vector3(at_pos.x, _ground_y + 1.5, at_pos.z),
		Vector3(at_pos.x, _ground_y - 3.0, at_pos.z),
		CombatLayers.WORLD
	)
	if is_instance_valid(_owner_mushroom):
		query.exclude = [_owner_mushroom.get_rid()]
	return space.intersect_ray(query)


func _stream_color_ramp(peak: Color, end: Color) -> GradientTexture1D:
	var gradient := Gradient.new()
	var start := Color(peak.r, peak.g, peak.b, 0.0)
	var mid_linger := Color(peak.r * 0.88, peak.g * 0.88, peak.b * 0.95, peak.a * 0.82)
	var late_fade := Color(peak.r * 0.68, peak.g * 0.68, peak.b * 0.84, peak.a * 0.42)
	gradient.offsets = PackedFloat32Array([0.0, 0.04, 0.64, 0.85, 1.0])
	gradient.colors = PackedColorArray([start, peak, mid_linger, late_fade, end])
	var ramp := GradientTexture1D.new()
	ramp.gradient = gradient
	return ramp


func _stream_scale_curve(start_s: float, mid_s: float, end_s: float) -> CurveTexture:
	var curve := Curve.new()
	curve.max_value = maxf(2.0, end_s)
	curve.add_point(Vector2(0.0, start_s))
	curve.add_point(Vector2(0.25, mid_s))
	curve.add_point(Vector2(1.0, end_s))
	var tex := CurveTexture.new()
	tex.curve = curve
	return tex


func _stream_damping_curve(hold_end: float, drop_end: float) -> CurveTexture:
	# Damping is strong early to arrest forward jet momentum, then drops to 0 so
	# buoyant gravity and 3D turbulence keep settled particles floating continuously.
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 1.0))
	curve.add_point(Vector2(hold_end, 1.0))
	curve.add_point(Vector2((hold_end + drop_end) * 0.5, 0.16))
	curve.add_point(Vector2(drop_end, 0.0))
	curve.add_point(Vector2(1.0, 0.0))
	var tex := CurveTexture.new()
	tex.curve = curve
	return tex


func _stream_velocity_limit_curve(
	start_lim: float, mid_lim: float, float_lim: float, end_lim: float
) -> CurveTexture:
	var curve := Curve.new()
	curve.min_value = 0.0
	curve.max_value = maxf(2.0, start_lim)
	curve.add_point(Vector2(0.0, start_lim))
	curve.add_point(Vector2(0.3, mid_lim))
	curve.add_point(Vector2(0.46, float_lim))
	curve.add_point(Vector2(1.0, end_lim))
	var tex := CurveTexture.new()
	tex.curve = curve
	return tex


func _turbulence_life_curve() -> CurveTexture:
	var curve := Curve.new()
	curve.add_point(Vector2(0.0, 0.03))
	curve.add_point(Vector2(0.28, 0.12))
	curve.add_point(Vector2(0.45, 0.72))
	curve.add_point(Vector2(1.0, 0.96))
	var tex := CurveTexture.new()
	tex.curve = curve
	return tex
