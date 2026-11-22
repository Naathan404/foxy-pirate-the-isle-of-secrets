class_name VenomVineRelocateHelper
extends RefCounted
## Bộ tính toán điểm chui đất giữ khoảng cách và quỹ đạo uốn lượn cho Elite Venom Vine.

const RELOCATE_CANDIDATE_ANGLES := 16
const RELOCATE_RING_DIRECTIONS := 8
const CLEARANCE_PROBE_RADIUS_METERS := 0.75
const CLEARANCE_PROBE_HEIGHT_METERS := 1.6
const RELOCATE_GROUND_PROBE_UP := 1.5
const RELOCATE_GROUND_PROBE_DOWN := 3.5
const RELOCATE_EDGE_MARGIN_METERS := 1.4
const RELOCATE_OPENNESS_PROBE_RADIUS_METERS := 2.35
const RELOCATE_WALL_PROBE_HEIGHT_METERS := 0.85
const RELOCATE_MIN_OPEN_DIRECTIONS := 6
const RELOCATE_FALLBACK_OPEN_DIRECTIONS := 4
const RELOCATE_MAX_FLOOR_STEP := 0.65
const RELOCATE_MIN_DISPLACEMENT_METERS := 5.2
const RELOCATE_MIN_PLAYER_DISTANCE_METERS := 5.0
const RELOCATE_PREFERRED_SAFE_DISTANCE_METERS := 7.2
const RELOCATE_FALLBACK_EDGE_MARGIN_METERS := 1.05
const RELOCATE_FALLBACK_MIN_DISPLACEMENT_METERS := 3.2
const RELOCATE_FALLBACK_EXTRA_DISTANCE_METERS := 2.6
const RELOCATE_FALLBACK_ANCHOR_SCALE := 1.5
const RELOCATE_FALLBACK_PLAYER_DISTANCE_METERS := 3.8
const RELOCATE_EMERGENCY_MIN_DISPLACEMENT_METERS := 2.0
const RELOCATE_EMERGENCY_MAX_DISTANCE_METERS := 11.5
const RELOCATE_EMERGENCY_ANCHOR_LIMIT_METERS := 999.0
const RELOCATE_EMERGENCY_PLAYER_DISTANCE_METERS := 2.8
const RELOCATE_EMERGENCY_EDGE_MARGIN_METERS := 0.65
const RELOCATE_RING_FALLBACK_ANGLES := 24
const RELOCATE_RING_FALLBACK_EDGE_MARGIN_METERS := 0.4
const RELOCATE_RING_FALLBACK_MIN_MOVE_METERS := 2.0
const TUNNEL_ZIGZAG_OFFSET_MIN_METERS := 1.35
const TUNNEL_ZIGZAG_OFFSET_MAX_METERS := 2.25
const TUNNEL_SPLINE_SAMPLES := 12


static func find_relocate_spot(ctx: Dictionary) -> Variant:
	var min_dist := float(ctx.get("min_distance", 5.4))
	var max_dist := float(ctx.get("max_distance", 10.6))
	var anchor_radius := float(ctx.get("anchor_radius", 13.5))
	var strict_spot: Variant = _search_relocate_candidate(
		ctx,
		min_dist,
		max_dist,
		anchor_radius,
		RELOCATE_MIN_PLAYER_DISTANCE_METERS,
		RELOCATE_EDGE_MARGIN_METERS,
		RELOCATE_MIN_OPEN_DIRECTIONS
	)
	if strict_spot is Vector3:
		return strict_spot
	var fallback_spot: Variant = _search_relocate_candidate(
		ctx,
		RELOCATE_FALLBACK_MIN_DISPLACEMENT_METERS,
		max_dist + RELOCATE_FALLBACK_EXTRA_DISTANCE_METERS,
		anchor_radius * RELOCATE_FALLBACK_ANCHOR_SCALE,
		RELOCATE_FALLBACK_PLAYER_DISTANCE_METERS,
		RELOCATE_FALLBACK_EDGE_MARGIN_METERS,
		RELOCATE_FALLBACK_OPEN_DIRECTIONS
	)
	if fallback_spot is Vector3:
		return fallback_spot
	var emergency_spot: Variant = _search_relocate_candidate(
		ctx,
		RELOCATE_EMERGENCY_MIN_DISPLACEMENT_METERS,
		RELOCATE_EMERGENCY_MAX_DISTANCE_METERS,
		RELOCATE_EMERGENCY_ANCHOR_LIMIT_METERS,
		RELOCATE_EMERGENCY_PLAYER_DISTANCE_METERS,
		RELOCATE_EMERGENCY_EDGE_MARGIN_METERS,
		0
	)
	if emergency_spot is Vector3:
		return emergency_spot
	return _find_emergency_ring_relocate_spot(ctx)


static func build_tunnel_polyline(
	space: PhysicsDirectSpaceState3D, excluded: Array[RID], start_pos: Vector3, end_pos: Vector3
) -> Array[Vector3]:
	var span := end_pos - start_pos
	span.y = 0.0
	var dist := span.length()
	if dist < 0.8:
		return [start_pos, end_pos]
	var fwd := span / dist
	var perp := Vector3(-fwd.z, 0.0, fwd.x)
	var sign_dir := 1.0 if randf() < 0.5 else -1.0
	var amp := (
		sign_dir * randf_range(TUNNEL_ZIGZAG_OFFSET_MIN_METERS, TUNNEL_ZIGZAG_OFFSET_MAX_METERS)
	)
	var points: Array[Vector3] = [start_pos]
	for step_idx in range(1, TUNNEL_SPLINE_SAMPLES):
		var frac := float(step_idx) / float(TUNNEL_SPLINE_SAMPLES)
		# Uốn lượn hình sin liên tục rồi thu mượt về hố đích để vệt đất không gãy khúc thô.
		var envelope := sin(frac * PI)
		var wave := sin(frac * TAU * 1.15)
		var lateral := perp * (amp * envelope * wave)
		points.append(
			snap_tunnel_waypoint(space, start_pos.lerp(end_pos, frac) + lateral, excluded)
		)
	points.append(end_pos)
	return points


static func snap_tunnel_waypoint(
	space: PhysicsDirectSpaceState3D, point: Vector3, excluded: Array[RID]
) -> Vector3:
	if space == null:
		return point
	var hit_y: Variant = probe_ground_height(space, point, point.y, excluded)
	if hit_y is float:
		return Vector3(point.x, hit_y as float, point.z)
	return point


static func polyline_length(points: Array[Vector3]) -> float:
	var total := 0.0
	for idx in range(points.size() - 1):
		total += (
			Vector2(points[idx + 1].x - points[idx].x, points[idx + 1].z - points[idx].z).length()
		)
	return total


static func sample_polyline(points: Array[Vector3], frac: float) -> Vector3:
	if points.is_empty():
		return Vector3.ZERO
	if points.size() == 1:
		return points[0]
	var total := polyline_length(points)
	if total <= 0.001:
		return points[points.size() - 1]
	var target_len := clampf(frac, 0.0, 1.0) * total
	var accum := 0.0
	for idx in range(points.size() - 1):
		var seg_len := (
			Vector2(points[idx + 1].x - points[idx].x, points[idx + 1].z - points[idx].z).length()
		)
		if accum + seg_len >= target_len or idx == points.size() - 2:
			var t := clampf((target_len - accum) / maxf(0.001, seg_len), 0.0, 1.0)
			return points[idx].lerp(points[idx + 1], t)
		accum += seg_len
	return points[points.size() - 1]


static func probe_ground_height(
	space: PhysicsDirectSpaceState3D, pos: Vector3, ref_y: float, excluded: Array[RID]
) -> Variant:
	if space == null:
		return null
	var ray_from := Vector3(pos.x, ref_y + RELOCATE_GROUND_PROBE_UP, pos.z)
	var ray_to := Vector3(pos.x, ref_y - RELOCATE_GROUND_PROBE_DOWN, pos.z)
	var ray := PhysicsRayQueryParameters3D.create(ray_from, ray_to, CombatLayers.WORLD)
	ray.exclude = excluded
	var hit := space.intersect_ray(ray)
	if hit.is_empty():
		return null
	return (hit["position"] as Vector3).y


static func _find_emergency_ring_relocate_spot(ctx: Dictionary) -> Variant:
	var origin := ctx.get("origin", Vector3.ZERO) as Vector3
	var space := ctx.get("space", null) as PhysicsDirectSpaceState3D
	var excluded: Array[RID] = []
	excluded.assign(ctx.get("excluded", []))
	var shape_params := _create_relocate_clearance_probe(space, excluded)
	var base_y := origin.y
	var best_spot: Variant = null
	var best_dist := -INF
	for dist: float in [2.2, 3.6, 5.2, 6.8]:
		for idx in range(RELOCATE_RING_FALLBACK_ANGLES):
			var angle := TAU * float(idx) / float(RELOCATE_RING_FALLBACK_ANGLES)
			var cand := origin + Vector3(cos(angle), 0.0, sin(angle)) * dist
			var ground_y := base_y
			if space != null:
				var hit_y: Variant = probe_ground_height(space, cand, base_y, excluded)
				if not (hit_y is float):
					continue
				ground_y = hit_y as float
				if not _has_solid_relocate_floor(
					space, cand, ground_y, RELOCATE_RING_FALLBACK_EDGE_MARGIN_METERS, excluded
				):
					continue
			var grounded := Vector3(cand.x, ground_y, cand.z)
			if (
				space != null
				and shape_params != null
				and _has_body_obstruction(space, shape_params, grounded)
			):
				continue
			var move_dist := Vector2(cand.x - origin.x, cand.z - origin.z).length()
			if move_dist >= RELOCATE_RING_FALLBACK_MIN_MOVE_METERS and move_dist > best_dist:
				best_dist = move_dist
				best_spot = grounded
	return best_spot


static func _search_relocate_candidate(
	ctx: Dictionary,
	min_dist_limit: float,
	max_dist_limit: float,
	anchor_limit: float,
	min_player_dist: float,
	edge_margin: float,
	min_open_dirs: int
) -> Variant:
	var origin := ctx.get("origin", Vector3.ZERO) as Vector3
	var anchor := ctx.get("anchor", origin) as Vector3
	var has_target := bool(ctx.get("has_target", false))
	var target_pos := ctx.get("target_pos", Vector3.ZERO) as Vector3
	var space := ctx.get("space", null) as PhysicsDirectSpaceState3D
	var excluded: Array[RID] = []
	excluded.assign(ctx.get("excluded", []))

	var candidates := _build_relocate_candidates(
		origin, has_target, target_pos, min_dist_limit, max_dist_limit
	)
	var shape_params := _create_relocate_clearance_probe(space, excluded)

	var best_spot: Variant = null
	var best_score := -INF
	var base_y := origin.y
	var min_move := (
		min_dist_limit
		if min_open_dirs == 0
		else maxf(
			RELOCATE_FALLBACK_MIN_DISPLACEMENT_METERS,
			minf(min_dist_limit, RELOCATE_MIN_DISPLACEMENT_METERS)
		)
	)
	for cand in candidates:
		var move_dist := Vector2(cand.x - origin.x, cand.z - origin.z).length()
		if move_dist < min_move or move_dist > max_dist_limit:
			continue
		var anchor_dist := Vector2(cand.x - anchor.x, cand.z - anchor.z).length()
		if anchor_dist > anchor_limit:
			continue
		var ground_y := base_y
		var open_dirs := RELOCATE_RING_DIRECTIONS
		if space != null:
			var hit_y: Variant = probe_ground_height(space, cand, base_y, excluded)
			if not (hit_y is float):
				continue
			ground_y = hit_y as float
			if not _has_solid_relocate_floor(space, cand, ground_y, edge_margin, excluded):
				continue
			open_dirs = count_open_directions(space, cand, ground_y, excluded)
			if open_dirs < min_open_dirs:
				continue
		var grounded := Vector3(cand.x, ground_y, cand.z)
		if (
			space != null
			and shape_params != null
			and _has_body_obstruction(space, shape_params, grounded)
		):
			continue
		var player_dist := flat_distance(grounded, target_pos) if has_target else move_dist
		if has_target and player_dist < min_player_dist:
			continue
		var current_player_dist := flat_distance(origin, target_pos) if has_target else 0.0
		var score := _score_relocate_spot(
			player_dist, current_player_dist, move_dist, anchor_dist, open_dirs
		)
		if score > best_score:
			best_score = score
			best_spot = grounded
	return best_spot


static func _build_relocate_candidates(
	origin: Vector3,
	has_target: bool,
	target_pos: Vector3,
	min_dist_limit: float,
	max_dist_limit: float
) -> Array[Vector3]:
	var candidates: Array[Vector3] = []
	var angle_offset := randf() * TAU
	var min_d := minf(min_dist_limit, max_dist_limit)
	var max_d := maxf(min_d + 0.25, max_dist_limit)
	for idx in range(RELOCATE_CANDIDATE_ANGLES):
		var angle := angle_offset + TAU * float(idx) / float(RELOCATE_CANDIDATE_ANGLES)
		var dir := Vector3(cos(angle), 0.0, sin(angle))
		for dist_t: float in [0.45, 0.72, 1.0]:
			candidates.append(origin + dir * lerpf(min_d, max_d, dist_t))
		if has_target:
			# Lấy mẫu quanh Player ở cự ly tầm xa để trồi lên cách xa và khó đoán hơn.
			for safe_dist: float in [5.8, 7.2, 8.6]:
				candidates.append(target_pos + dir * safe_dist)
	return candidates


static func _create_relocate_clearance_probe(
	space: PhysicsDirectSpaceState3D, excluded: Array[RID]
) -> PhysicsShapeQueryParameters3D:
	if space == null:
		return null
	var probe := CylinderShape3D.new()
	probe.radius = CLEARANCE_PROBE_RADIUS_METERS
	probe.height = CLEARANCE_PROBE_HEIGHT_METERS
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = probe
	params.collision_mask = CombatLayers.WORLD | CombatLayers.ENEMY_BODY
	params.exclude = excluded
	return params


static func _has_body_obstruction(
	space: PhysicsDirectSpaceState3D, params: PhysicsShapeQueryParameters3D, grounded: Vector3
) -> bool:
	params.transform = Transform3D(
		Basis.IDENTITY, grounded + Vector3(0.0, CLEARANCE_PROBE_HEIGHT_METERS * 0.5 + 0.15, 0.0)
	)
	return not space.intersect_shape(params, 1).is_empty()


static func _has_solid_relocate_floor(
	space: PhysicsDirectSpaceState3D,
	center: Vector3,
	center_y: float,
	margin: float,
	excluded: Array[RID]
) -> bool:
	for idx in range(RELOCATE_RING_DIRECTIONS):
		var angle := TAU * float(idx) / float(RELOCATE_RING_DIRECTIONS)
		var probe := center + Vector3(cos(angle), 0.0, sin(angle)) * margin
		var hit_y: Variant = probe_ground_height(space, probe, center_y, excluded)
		if not (hit_y is float) or absf((hit_y as float) - center_y) > RELOCATE_MAX_FLOOR_STEP:
			return false
	return true


static func count_open_directions(
	space: PhysicsDirectSpaceState3D, center: Vector3, center_y: float, excluded: Array[RID]
) -> int:
	var open_count := 0
	var chest_pos := Vector3(center.x, center_y + RELOCATE_WALL_PROBE_HEIGHT_METERS, center.z)
	for idx in range(RELOCATE_RING_DIRECTIONS):
		var angle := TAU * float(idx) / float(RELOCATE_RING_DIRECTIONS)
		var probe := (
			center + Vector3(cos(angle), 0.0, sin(angle)) * RELOCATE_OPENNESS_PROBE_RADIUS_METERS
		)
		var hit_y: Variant = probe_ground_height(space, probe, center_y, excluded)
		if not (hit_y is float) or absf((hit_y as float) - center_y) > RELOCATE_MAX_FLOOR_STEP:
			continue
		var wall_ray := PhysicsRayQueryParameters3D.create(
			chest_pos,
			Vector3(probe.x, chest_pos.y, probe.z),
			CombatLayers.WORLD | CombatLayers.ENEMY_BODY
		)
		wall_ray.exclude = excluded
		if space.intersect_ray(wall_ray).is_empty():
			open_count += 1
	return open_count


static func flat_distance(from_pos: Vector3, to_pos: Vector3) -> float:
	return Vector2(from_pos.x - to_pos.x, from_pos.z - to_pos.z).length()


static func _score_relocate_spot(
	player_dist: float,
	current_player_dist: float,
	move_dist: float,
	anchor_dist: float,
	open_dirs: int
) -> float:
	# Ưu tiên vùng thoáng rộng, đẩy dịch chuyển thật xa và giữ phương hướng đa dạng khó đoán.
	var openness_bonus := float(open_dirs) * 2.1
	var distance_fit := -absf(player_dist - RELOCATE_PREFERRED_SAFE_DISTANCE_METERS) * 0.95
	var getaway_bonus := clampf(player_dist - current_player_dist, -2.0, 5.5) * 0.95
	var move_freshness := clampf(move_dist, 0.0, 10.6) * 0.75
	var center_bias := -anchor_dist * 0.06
	return (
		openness_bonus
		+ distance_fit
		+ getaway_bonus
		+ move_freshness
		+ center_bias
		+ randf_range(-0.95, 0.95)
	)
