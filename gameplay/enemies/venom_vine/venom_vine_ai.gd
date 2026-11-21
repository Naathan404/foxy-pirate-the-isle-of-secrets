class_name VenomVineAI
extends RefCounted
## Bộ não chiến thuật cho VenomVine: phân vùng cự ly, phục kích, đón đầu và tránh chồng vũng axit.

enum Zone {
	OUT_OF_RANGE,
	OUTER_RING,
	INNER_RING,
}

enum AttackMode {
	NONE,
	ACID_SINGLE,
	ACID_LEAD,
	ACID_FAN,
	SPECIAL,
}

enum HitReaction {
	HOLD,
	BURROW,
	COUNTER,
}

enum IdleDecision {
	WAIT,
	BURROW,
}

const LEAD_VELOCITY_THRESHOLD := 0.75
const STANDING_SPREAD_OFFSET_METERS := 1.55
const POOL_COVER_BLOCK_FACTOR := 0.85
const MIN_FLIGHT_SECONDS := 0.35
const MAX_FLIGHT_SECONDS := 0.78
const MAX_AGITATION_COOLDOWN_REDUCTION := 0.32
const MAX_HP_COOLDOWN_REDUCTION := 0.34
const MAX_HP_CHARGE_SPEEDUP := 0.22
const MAX_HP_RECOVER_SPEEDUP := 0.25
const OUTER_EXTRA_SHOT_HP_THRESHOLD := 0.65
const INNER_EXTRA_SHOT_HP_THRESHOLD := 0.4
const DEFAULT_AIM_SCATTER_MIN_METERS := 1.5
const DEFAULT_AIM_SCATTER_MAX_METERS := 2.5
const TARGET_DEFLECT_MARGIN_METERS := 0.45
const DEFAULT_MIN_SHOT_DISTANCE_METERS := 1.6
const DEFAULT_MAX_SHOT_DISTANCE_METERS := 6.2
const HIDE_BASE_CHANCE := 0.2
const HIDE_CLOSE_BONUS := 0.2
const HIDE_LOW_HP_BONUS := 0.12
const HIDE_AGITATION_BONUS := 0.12
const HIDE_CHARGING_BONUS := 0.1
const HIDE_MAX_CHANCE := 0.7
const AIM_LOCK_WINDOW_SECONDS := 0.24
const OUTER_PRESSURE_MIN_OFFSET_METERS := 0.85
const OUTER_PRESSURE_POOL_FACTOR := 0.86
const IDLE_HIDE_BASE_CHANCE := 0.08
const IDLE_HIDE_CLOSE_BONUS := 0.2
const IDLE_HIDE_APPROACH_BONUS := 0.2
const IDLE_HIDE_LOW_HP_BONUS := 0.12
const IDLE_HIDE_AGITATION_BONUS := 0.1
const IDLE_HIDE_MAX_CHANCE := 0.65
const IDLE_HIDE_HAZARD_CHANCE_FACTOR := 0.3
const APPROACH_SPEED_THRESHOLD_METERS_PER_SECOND := 0.5
const LOW_HP_RATIO := 0.4

var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.randomize()


func classify_zone(
	distance_meters: float,
	outer_radius_meters: float,
	inner_radius_meters: float,
	hysteresis_meters: float,
	currently_engaged: bool
) -> Zone:
	var effective_outer := outer_radius_meters + (hysteresis_meters if currently_engaged else 0.0)
	if distance_meters > effective_outer:
		return Zone.OUT_OF_RANGE
	if distance_meters <= inner_radius_meters:
		return Zone.INNER_RING
	return Zone.OUTER_RING


func roll_ambush_hold(
	distance_meters: float,
	ambush_wake_distance_meters: float,
	min_delay_seconds: float,
	max_delay_seconds: float,
	target_speed: float
) -> float:
	if distance_meters <= ambush_wake_distance_meters:
		return 0.0
	var low := minf(min_delay_seconds, max_delay_seconds)
	var high := maxf(min_delay_seconds, max_delay_seconds)
	if high <= 0.0:
		return 0.0
	# Nếu mục tiêu đi chậm ở rìa vùng ngoài, kéo dài thời gian giả vờ để dụ lại gần hơn.
	if target_speed < 2.0:
		return _rng.randf_range(lerpf(low, high, 0.4), high)
	return _rng.randf_range(low, lerpf(low, high, 0.7))


func choose_hit_reaction(context: Dictionary) -> HitReaction:
	# A rapid melee combo always ends in immediate protection, even during a counter.
	if bool(context.get("melee_combo_limit_reached", false)):
		return HitReaction.BURROW
	if bool(context.get("counter_pending", false)):
		return HitReaction.HOLD
	if bool(context.get("counter_ready", false)):
		return HitReaction.COUNTER
	if not bool(context.get("burrow_ready", false)):
		return HitReaction.HOLD
	var distance_meters := float(context.get("distance_meters", INF))
	var inner_radius_meters := float(context.get("inner_radius_meters", 0.0))
	var hp_ratio := float(context.get("hp_ratio", 1.0))
	var agitation := float(context.get("agitation", 0.0))
	var was_charging := bool(context.get("was_charging", false))
	var chance := HIDE_BASE_CHANCE
	if distance_meters <= inner_radius_meters:
		chance += HIDE_CLOSE_BONUS
	if hp_ratio < 0.4:
		chance += HIDE_LOW_HP_BONUS
	chance += clampf(agitation, 0.0, 1.0) * HIDE_AGITATION_BONUS
	if was_charging:
		chance += HIDE_CHARGING_BONUS
	return HitReaction.BURROW if _rng.randf() < minf(chance, HIDE_MAX_CHANCE) else HitReaction.HOLD


func choose_idle_decision(context: Dictionary) -> IdleDecision:
	if not bool(context.get("burrow_ready", false)):
		return IdleDecision.WAIT
	var chance := IDLE_HIDE_BASE_CHANCE
	var distance_meters := float(context.get("distance_meters", INF))
	if distance_meters <= float(context.get("inner_radius_meters", 0.0)):
		chance += IDLE_HIDE_CLOSE_BONUS
	if float(context.get("approach_speed", 0.0)) >= APPROACH_SPEED_THRESHOLD_METERS_PER_SECOND:
		chance += IDLE_HIDE_APPROACH_BONUS
	if float(context.get("hp_ratio", 1.0)) <= LOW_HP_RATIO:
		chance += IDLE_HIDE_LOW_HP_BONUS
	chance += clampf(float(context.get("agitation", 0.0)), 0.0, 1.0) * IDLE_HIDE_AGITATION_BONUS
	if bool(context.get("active_venom", false)):
		chance *= IDLE_HIDE_HAZARD_CHANCE_FACTOR
	return (
		IdleDecision.BURROW
		if _rng.randf() < minf(chance, IDLE_HIDE_MAX_CHANCE)
		else IdleDecision.WAIT
	)


func compute_lead_position(
	origin_position: Vector3,
	target_position: Vector3,
	target_velocity: Vector3,
	flight_duration_seconds: float,
	max_lead_meters: float,
	lead_accuracy: float
) -> Vector3:
	var flat_vel := Vector3(target_velocity.x, 0.0, target_velocity.z)
	if flat_vel.length() < LEAD_VELOCITY_THRESHOLD:
		return target_position
	var lead_offset := flat_vel * flight_duration_seconds * clampf(lead_accuracy, 0.0, 1.25)
	lead_offset = lead_offset.limit_length(maxf(0.0, max_lead_meters))
	var predicted := target_position + lead_offset
	if predicted.distance_to(origin_position) < 1.2:
		return target_position
	return predicted


func is_position_covered_by_pool(
	world_position: Vector3,
	occupied_spots: Array[Dictionary],
	block_factor: float = POOL_COVER_BLOCK_FACTOR
) -> bool:
	for spot in occupied_spots:
		var pool_pos := spot["pos"] as Vector3
		var pool_radius := float(spot["radius"])
		var flat_dist := (
			Vector2(world_position.x - pool_pos.x, world_position.z - pool_pos.z).length()
		)
		if flat_dist <= pool_radius * block_factor:
			return true
	return false


func select_attack_plan(context: Dictionary) -> Dictionary:
	var zone: Zone = context.get("zone", Zone.OUT_OF_RANGE) as Zone
	if zone == Zone.OUT_OF_RANGE:
		return {"mode": AttackMode.NONE, "aim_positions": [] as Array[Vector3]}

	var agitation := clampf(float(context.get("agitation", 0.0)), 0.0, 1.0)
	var origin_pos := context.get("origin_pos", Vector3.ZERO) as Vector3
	var target_pos := context.get("target_pos", Vector3.ZERO) as Vector3
	var target_vel := context.get("target_velocity", Vector3.ZERO) as Vector3
	var occupied_raw: Array = context.get("occupied_spots", [])
	var occupied: Array[Dictionary] = []
	for item in occupied_raw:
		if item is Dictionary:
			occupied.append(item as Dictionary)
	var ground_y := float(context.get("ground_y", origin_pos.y))
	var pool_radius := maxf(0.4, float(context.get("pool_radius", 1.5)))
	var space: PhysicsDirectSpaceState3D = context.get("space", null)
	var excluded_raw: Array = context.get("excluded_rids", [])
	var excluded_rids: Array[RID] = []
	for rid_item in excluded_raw:
		if rid_item is RID:
			excluded_rids.append(rid_item as RID)

	var flat_dist := Vector2(target_pos.x - origin_pos.x, target_pos.z - origin_pos.z).length()
	var est_flight := clampf(0.28 + flat_dist * 0.045, MIN_FLIGHT_SECONDS, MAX_FLIGHT_SECONDS)
	# The aim is locked during the charge, so lead includes that time as well as the flight.
	est_flight += maxf(0.0, float(context.get("charge_seconds", 0.75)) - AIM_LOCK_WINDOW_SECONDS)
	var hp_ratio := clampf(float(context.get("hp_ratio", 1.0)), 0.0, 1.0)
	var hp_pressure := 1.0 - hp_ratio
	var cooldown_scale := clampf(
		(
			(1.0 - agitation * MAX_AGITATION_COOLDOWN_REDUCTION)
			* (1.0 - hp_pressure * MAX_HP_COOLDOWN_REDUCTION)
		),
		0.48,
		1.0
	)
	var charge_scale := clampf(1.0 - hp_pressure * MAX_HP_CHARGE_SPEEDUP, 0.72, 1.0)
	var recover_scale := clampf(1.0 - hp_pressure * MAX_HP_RECOVER_SPEEDUP, 0.72, 1.0)
	var shared := {
		"origin_pos": origin_pos,
		"target_pos": target_pos,
		"target_vel": target_vel,
		"est_flight": est_flight,
		"ground_y": ground_y,
		"pool_radius": pool_radius,
		"occupied": occupied,
		"space": space,
		"excluded_rids": excluded_rids,
		"cooldown_scale": cooldown_scale,
		"charge_scale": charge_scale,
		"recover_scale": recover_scale,
		"bonus_outer_shots": 1 if hp_ratio <= OUTER_EXTRA_SHOT_HP_THRESHOLD else 0,
		"bonus_inner_shots": 1 if hp_ratio <= INNER_EXTRA_SHOT_HP_THRESHOLD else 0,
	}

	if zone == Zone.OUTER_RING:
		return _build_outer_plan(shared, context)

	return _build_inner_plan(shared, context)


func build_counter_plan(context: Dictionary) -> Dictionary:
	var origin_pos := context.get("origin_pos", Vector3.ZERO) as Vector3
	var target_pos := context.get("target_pos", Vector3.ZERO) as Vector3
	var target_vel := context.get("target_velocity", Vector3.ZERO) as Vector3
	var ground_y := float(context.get("ground_y", origin_pos.y))
	var inner_radius := float(context.get("inner_radius", 3.5))
	var pool_radius := maxf(0.4, float(context.get("counter_pool_radius", 0.9)))
	var space: PhysicsDirectSpaceState3D = context.get("space", null)
	var excluded_raw: Array = context.get("excluded_rids", [])
	var excluded_rids: Array[RID] = []
	for rid_item in excluded_raw:
		if rid_item is RID:
			excluded_rids.append(rid_item as RID)
	var occupied_raw: Array = context.get("occupied_spots", [])
	var planned_occupied: Array[Dictionary] = []
	for item in occupied_raw:
		if item is Dictionary:
			planned_occupied.append(item as Dictionary)

	var to_target := target_pos - origin_pos
	to_target.y = 0.0
	var dist := to_target.length()
	var base_dir := to_target.normalized() if dist > 0.001 else Vector3.BACK
	var aim_positions: Array[Vector3] = []
	planned_occupied.append(_make_target_exclusion_spot(target_pos, pool_radius, 1.35))

	if dist <= inner_radius:
		var count := maxi(2, int(context.get("counter_inner_shots", 3)))
		var spread_rad := deg_to_rad(140.0)
		var step := spread_rad / float(count - 1) if count > 1 else 0.0
		var start_angle := -spread_rad * 0.5
		var ring_dist := clampf(dist * 0.85, 0.85, 1.85)
		for idx in range(count):
			var angle := start_angle + step * float(idx)
			# Tách phát chính giữa lệch sang sườn để phản công không ném thẳng vào người Player.
			if count % 2 == 1 and idx == count / 2:
				angle += deg_to_rad(28.0)
			var desired := origin_pos + base_dir.rotated(Vector3.UP, angle) * ring_dist
			desired.y = ground_y
			var resolved := VenomPoolProjectile.resolve_landing_spot(
				origin_pos,
				desired,
				ground_y,
				pool_radius,
				planned_occupied,
				space,
				excluded_rids,
				0.75,
				2.3
			)
			aim_positions.append(resolved)
			planned_occupied.append({"pos": resolved, "radius": pool_radius})
	else:
		var count := maxi(1, int(context.get("counter_outer_shots", 2)))
		var max_dist := float(context.get("max_shot_distance", 6.2))
		var predicted := compute_lead_position(origin_pos, target_pos, target_vel, 0.45, 1.8, 0.8)
		for idx in range(count):
			var offset := _pick_nearby_offset(
				origin_pos, predicted, Vector3(target_vel.x, 0.0, target_vel.z), 0.9, 1.75, idx
			)
			var desired := predicted + offset
			var resolved := VenomPoolProjectile.resolve_landing_spot(
				origin_pos,
				desired,
				ground_y,
				pool_radius,
				planned_occupied,
				space,
				excluded_rids,
				1.5,
				max_dist
			)
			aim_positions.append(resolved)
			planned_occupied.append({"pos": resolved, "radius": pool_radius})

	var hp_ratio := clampf(float(context.get("hp_ratio", 1.0)), 0.0, 1.0)
	var hp_pressure := 1.0 - hp_ratio
	var base_post_counter_cd := float(context.get("post_counter_cooldown", 0.9))
	return {
		"mode": AttackMode.ACID_FAN if aim_positions.size() > 1 else AttackMode.ACID_SINGLE,
		"is_counter": true,
		"aim_positions": aim_positions,
		"cooldown_seconds": maxf(0.6, base_post_counter_cd * (1.0 - hp_pressure * 0.28)),
		"charge_seconds": maxf(0.18, float(context.get("counter_charge_seconds", 0.28))),
		"shot_interval_seconds": 0.09,
		"recover_seconds": 0.24,
	}


func _build_outer_plan(shared: Dictionary, context: Dictionary) -> Dictionary:
	var origin_pos := shared["origin_pos"] as Vector3
	var target_pos := shared["target_pos"] as Vector3
	var target_vel := shared["target_vel"] as Vector3
	var est_flight := float(shared["est_flight"])
	var ground_y := float(shared["ground_y"])
	var pool_radius := float(shared["pool_radius"])
	var occupied: Array[Dictionary] = shared["occupied"]
	var space: PhysicsDirectSpaceState3D = shared["space"]
	var excluded_rids: Array[RID] = shared["excluded_rids"]
	var cooldown_scale := float(shared["cooldown_scale"])
	var charge_scale := float(shared.get("charge_scale", 1.0))
	var recover_scale := float(shared.get("recover_scale", 1.0))
	var bonus_outer := int(shared.get("bonus_outer_shots", 0))
	var outer_shots := maxi(1, int(context.get("outer_shots", 1)) + bonus_outer)
	var lead_accuracy := float(context.get("lead_accuracy", 0.7))
	var max_lead := float(context.get("max_lead_meters", 2.0))
	var scatter_min := float(context.get("aim_scatter_min", DEFAULT_AIM_SCATTER_MIN_METERS))
	var scatter_max := float(context.get("aim_scatter_max", DEFAULT_AIM_SCATTER_MAX_METERS))
	var min_shot_dist := float(context.get("min_shot_distance", DEFAULT_MIN_SHOT_DISTANCE_METERS))
	var max_shot_dist := float(context.get("max_shot_distance", DEFAULT_MAX_SHOT_DISTANCE_METERS))
	var raw_outer_cd := float(context.get("outer_cooldown", 2.6))
	var outer_cd := maxf(0.8, raw_outer_cd * cooldown_scale)
	var raw_charge := float(context.get("charge_seconds", 0.75))
	var base_charge := maxf(minf(raw_charge, 0.42), raw_charge * charge_scale)
	var raw_recover := float(context.get("recover_seconds", 0.45))

	var predicted := compute_lead_position(
		origin_pos, target_pos, target_vel, est_flight, max_lead, lead_accuracy
	)
	var flat_vel := Vector3(target_vel.x, 0.0, target_vel.z)
	var mode := (
		AttackMode.ACID_LEAD
		if flat_vel.length() >= LEAD_VELOCITY_THRESHOLD
		else AttackMode.ACID_SINGLE
	)

	var aim_positions: Array[Vector3] = []
	var planned_occupied := occupied.duplicate()
	var already_covered := is_position_covered_by_pool(target_pos, planned_occupied)
	# Land near enough that an idle target must react, while keeping the impact off its center.
	var pressure_max := maxf(
		OUTER_PRESSURE_MIN_OFFSET_METERS,
		minf(scatter_max, pool_radius * OUTER_PRESSURE_POOL_FACTOR)
	)
	var pressure_min := clampf(scatter_min, OUTER_PRESSURE_MIN_OFFSET_METERS, pressure_max)

	for shot_idx in range(outer_shots):
		var nearby_offset := _pick_nearby_offset(
			origin_pos, predicted, flat_vel, pressure_min, pressure_max, shot_idx
		)
		var desired := predicted + nearby_offset
		if already_covered and shot_idx == 0:
			desired += _pick_cutoff_offset(origin_pos, target_pos, flat_vel, shot_idx) * 0.5
		desired = _clamp_shot_distance(origin_pos, desired, min_shot_dist, max_shot_dist, ground_y)
		var resolved := VenomPoolProjectile.resolve_landing_spot(
			origin_pos,
			desired,
			ground_y,
			pool_radius,
			planned_occupied,
			space,
			excluded_rids,
			min_shot_dist,
			max_shot_dist
		)
		aim_positions.append(resolved)
		planned_occupied.append({"pos": resolved, "radius": pool_radius})

	return {
		"mode": mode,
		"aim_positions": aim_positions,
		"cooldown_seconds": outer_cd,
		"charge_seconds": base_charge,
		"shot_interval_seconds": float(context.get("outer_shot_interval", 0.28)),
		"recover_seconds": maxf(minf(raw_recover, 0.28), raw_recover * recover_scale),
	}


func _build_inner_plan(shared: Dictionary, context: Dictionary) -> Dictionary:
	var origin_pos := shared["origin_pos"] as Vector3
	var target_pos := shared["target_pos"] as Vector3
	var target_vel := shared["target_vel"] as Vector3
	var est_flight := float(shared["est_flight"])
	var ground_y := float(shared["ground_y"])
	var pool_radius := float(shared["pool_radius"])
	var occupied: Array[Dictionary] = shared["occupied"]
	var space: PhysicsDirectSpaceState3D = shared["space"]
	var excluded_rids: Array[RID] = shared["excluded_rids"]
	var cooldown_scale := float(shared["cooldown_scale"])
	var charge_scale := float(shared.get("charge_scale", 1.0))
	var recover_scale := float(shared.get("recover_scale", 1.0))
	var bonus_inner := int(shared.get("bonus_inner_shots", 0))
	var inner_shots := maxi(2, int(context.get("inner_shots", 3)) + bonus_inner)
	var fan_degrees := maxf(10.0, float(context.get("inner_fan_degrees", 64.0)))
	var lead_accuracy := float(context.get("lead_accuracy", 0.85))
	var max_lead := float(context.get("max_lead_meters", 1.8))
	var scatter_min := float(context.get("aim_scatter_min", DEFAULT_AIM_SCATTER_MIN_METERS))
	var scatter_max := float(context.get("aim_scatter_max", DEFAULT_AIM_SCATTER_MAX_METERS))
	var min_shot_dist := float(context.get("min_shot_distance", DEFAULT_MIN_SHOT_DISTANCE_METERS))
	var max_shot_dist := float(context.get("max_shot_distance", DEFAULT_MAX_SHOT_DISTANCE_METERS))
	var raw_inner_cd := float(context.get("inner_cooldown", 1.6))
	var inner_cd := maxf(0.65, raw_inner_cd * cooldown_scale)
	var raw_charge := float(context.get("charge_seconds", 0.75)) * 0.82
	var base_charge := maxf(minf(raw_charge, 0.35), raw_charge * charge_scale)
	var raw_recover := float(context.get("recover_seconds", 0.45)) * 0.85

	var predicted := compute_lead_position(
		origin_pos, target_pos, target_vel, est_flight, max_lead, lead_accuracy
	)
	var flat_vel := Vector3(target_vel.x, 0.0, target_vel.z)
	var nearby_anchor := (
		predicted
		+ _pick_nearby_offset(
			origin_pos, predicted, flat_vel, scatter_min * 0.85, scatter_max * 0.9, 0
		)
	)
	var base_vec := nearby_anchor - origin_pos
	base_vec.y = 0.0
	var base_dist := clampf(base_vec.length(), min_shot_dist, minf(max_shot_dist, 4.6))
	var base_dir := base_vec.normalized() if not base_vec.is_zero_approx() else Vector3.BACK

	var aim_positions: Array[Vector3] = []
	var planned_occupied := occupied.duplicate()
	planned_occupied.append(_make_target_exclusion_spot(target_pos, pool_radius, scatter_min))
	var arc_rad := deg_to_rad(fan_degrees)
	var step := arc_rad / float(inner_shots - 1) if inner_shots > 1 else 0.0
	var start_angle := -arc_rad * 0.5

	# Bắn tâm lệch về vùng lân cận trước rồi tỏa ra hai cánh để ép hướng né.
	var order: Array[int] = _center_first_indices(inner_shots)
	for idx in order:
		var angle := start_angle + step * float(idx)
		var ring_dist := clampf(
			base_dist + (0.45 if idx % 2 == 1 else 0.0), min_shot_dist, max_shot_dist
		)
		var desired := origin_pos + base_dir.rotated(Vector3.UP, angle) * ring_dist
		desired.y = ground_y
		var resolved := VenomPoolProjectile.resolve_landing_spot(
			origin_pos,
			desired,
			ground_y,
			pool_radius,
			planned_occupied,
			space,
			excluded_rids,
			min_shot_dist,
			max_shot_dist
		)
		aim_positions.append(resolved)
		planned_occupied.append({"pos": resolved, "radius": pool_radius})

	return {
		"mode": AttackMode.ACID_FAN,
		"aim_positions": aim_positions,
		"cooldown_seconds": inner_cd,
		"charge_seconds": base_charge,
		"shot_interval_seconds": float(context.get("inner_shot_interval", 0.16)),
		"recover_seconds": maxf(minf(raw_recover, 0.24), raw_recover * recover_scale),
	}


func _pick_nearby_offset(
	origin_pos: Vector3,
	anchor_pos: Vector3,
	flat_vel: Vector3,
	min_scatter: float,
	max_scatter: float,
	shot_index: int
) -> Vector3:
	var low := maxf(0.4, minf(min_scatter, max_scatter))
	var high := maxf(low, max_scatter)
	var radius := _rng.randf_range(low, high)
	var to_anchor := anchor_pos - origin_pos
	to_anchor.y = 0.0
	var forward := to_anchor.normalized() if not to_anchor.is_zero_approx() else Vector3.BACK
	var base_dir := (
		flat_vel.normalized() if flat_vel.length() >= LEAD_VELOCITY_THRESHOLD else forward
	)
	var side_sign := 1.0 if (_rng.randi() % 2 == 0) else -1.0
	if shot_index % 2 == 1:
		side_sign *= -1.0
	var angle_deg := _rng.randf_range(35.0, 115.0) * side_sign
	return base_dir.rotated(Vector3.UP, deg_to_rad(angle_deg)) * radius


func _clamp_shot_distance(
	origin_pos: Vector3, spot: Vector3, min_dist: float, max_dist: float, target_y: float
) -> Vector3:
	var offset := spot - origin_pos
	offset.y = 0.0
	var dist := offset.length()
	var dir := offset.normalized() if dist > 0.001 else Vector3.BACK
	var clamped_dist := clampf(dist, maxf(0.8, min_dist), maxf(min_dist + 0.5, max_dist))
	var result := origin_pos + dir * clamped_dist
	result.y = target_y
	return result


func _pick_cutoff_offset(
	origin_pos: Vector3, target_pos: Vector3, flat_vel: Vector3, shot_index: int
) -> Vector3:
	var to_target := target_pos - origin_pos
	to_target.y = 0.0
	var forward := to_target.normalized() if not to_target.is_zero_approx() else Vector3.BACK
	if flat_vel.length() >= LEAD_VELOCITY_THRESHOLD:
		return flat_vel.normalized() * STANDING_SPREAD_OFFSET_METERS
	var side := forward.rotated(Vector3.UP, PI * 0.5)
	var sign_val := 1.0 if shot_index % 2 == 0 else -1.0
	return (side * sign_val + forward * 0.45).normalized() * STANDING_SPREAD_OFFSET_METERS


func _make_target_exclusion_spot(
	target_pos: Vector3, pool_radius: float, scatter_min_meters: float
) -> Dictionary:
	var deflect_dist := maxf(scatter_min_meters, pool_radius + TARGET_DEFLECT_MARGIN_METERS)
	var exclusion_radius := maxf(
		0.1, deflect_dist - pool_radius - VenomPoolProjectile.POOL_SEPARATION_BUFFER_METERS
	)
	return {"pos": target_pos, "radius": exclusion_radius}


func _center_first_indices(count: int) -> Array[int]:
	var indices: Array[int] = []
	for i in range(count):
		indices.append(i)
	var half := float(count - 1) * 0.5
	indices.sort_custom(
		func(a: int, b: int) -> bool:
			var da := absf(float(a) - half)
			var db := absf(float(b) - half)
			if not is_equal_approx(da, db):
				return da < db
			return a < b
	)
	return indices
