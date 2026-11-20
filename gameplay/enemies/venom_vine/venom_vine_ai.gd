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

const LEAD_VELOCITY_THRESHOLD := 0.75
const STANDING_SPREAD_OFFSET_METERS := 1.55
const POOL_COVER_BLOCK_FACTOR := 0.85
const MIN_FLIGHT_SECONDS := 0.35
const MAX_FLIGHT_SECONDS := 0.78
const MAX_AGITATION_COOLDOWN_REDUCTION := 0.32

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
	var cooldown_scale := 1.0 - agitation * MAX_AGITATION_COOLDOWN_REDUCTION
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
	}

	if zone == Zone.OUTER_RING:
		return _build_outer_plan(shared, context)

	return _build_inner_plan(shared, context)


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
	var outer_shots := maxi(1, int(context.get("outer_shots", 1)))
	var lead_accuracy := float(context.get("lead_accuracy", 0.7))
	var max_lead := float(context.get("max_lead_meters", 2.8))
	var outer_cd := float(context.get("outer_cooldown", 3.2)) * cooldown_scale
	var base_charge := float(context.get("charge_seconds", 0.75))

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

	for shot_idx in range(outer_shots):
		var desired := predicted
		if already_covered or shot_idx > 0:
			var lateral := _pick_cutoff_offset(origin_pos, target_pos, flat_vel, shot_idx)
			desired = predicted + lateral
		var resolved := VenomPoolProjectile.resolve_landing_spot(
			origin_pos, desired, ground_y, pool_radius, planned_occupied, space, excluded_rids
		)
		aim_positions.append(resolved)
		planned_occupied.append({"pos": resolved, "radius": pool_radius})

	return {
		"mode": mode,
		"aim_positions": aim_positions,
		"cooldown_seconds": maxf(0.8, outer_cd),
		"charge_seconds": base_charge,
		"shot_interval_seconds": float(context.get("outer_shot_interval", 0.28)),
		"recover_seconds": float(context.get("recover_seconds", 0.45)),
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
	var inner_shots := maxi(2, int(context.get("inner_shots", 3)))
	var fan_degrees := maxf(10.0, float(context.get("inner_fan_degrees", 64.0)))
	var lead_accuracy := float(context.get("lead_accuracy", 0.85))
	var max_lead := float(context.get("max_lead_meters", 2.2))
	var inner_cd := float(context.get("inner_cooldown", 1.75)) * cooldown_scale
	var base_charge := float(context.get("charge_seconds", 0.75)) * 0.82

	var predicted := compute_lead_position(
		origin_pos, target_pos, target_vel, est_flight, max_lead, lead_accuracy
	)
	var base_vec := predicted - origin_pos
	base_vec.y = 0.0
	var base_dist := clampf(base_vec.length(), 1.8, 5.2)
	var base_dir := base_vec.normalized() if not base_vec.is_zero_approx() else Vector3.BACK

	var aim_positions: Array[Vector3] = []
	var planned_occupied := occupied.duplicate()
	var arc_rad := deg_to_rad(fan_degrees)
	var step := arc_rad / float(inner_shots - 1) if inner_shots > 1 else 0.0
	var start_angle := -arc_rad * 0.5

	# Bắn tâm trước rồi tỏa ra hai cánh để ép hướng né cân đối.
	var order: Array[int] = _center_first_indices(inner_shots)
	for idx in order:
		var angle := start_angle + step * float(idx)
		var ring_dist := base_dist + (0.45 if idx % 2 == 1 else 0.0)
		var desired := origin_pos + base_dir.rotated(Vector3.UP, angle) * ring_dist
		desired.y = ground_y
		var resolved := VenomPoolProjectile.resolve_landing_spot(
			origin_pos, desired, ground_y, pool_radius, planned_occupied, space, excluded_rids
		)
		aim_positions.append(resolved)
		planned_occupied.append({"pos": resolved, "radius": pool_radius})

	return {
		"mode": AttackMode.ACID_FAN,
		"aim_positions": aim_positions,
		"cooldown_seconds": maxf(0.65, inner_cd),
		"charge_seconds": maxf(0.35, base_charge),
		"shot_interval_seconds": float(context.get("inner_shot_interval", 0.16)),
		"recover_seconds": float(context.get("recover_seconds", 0.45)) * 0.85,
	}


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
