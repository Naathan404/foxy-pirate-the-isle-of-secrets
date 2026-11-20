class_name FireflyAI
extends RefCounted
## Bộ não chiến thuật của Firefly: phân vùng nhận diện/tấn công, bay lượn sóng và chọn điểm rơi.

enum Zone {
	OUT_OF_RANGE,
	OUTER_HOVER,
	INNER_ATTACK,
}

const MIN_DISTANCE_METERS := 0.001
const POOL_SEPARATION_BUFFER_METERS := 0.28
const SPOT_SEARCH_ANGLES_DEG := [
	0.0,
	24.0,
	-24.0,
	48.0,
	-48.0,
	72.0,
	-72.0,
	100.0,
	-100.0,
	140.0,
	-140.0,
	180.0,
]
const SPOT_RADIAL_OFFSETS := [0.0, 1.1, 2.2, 3.4, -0.75]
const LANDING_SEARCH_ANGLES_DEG := [
	0.0,
	22.5,
	-22.5,
	45.0,
	-45.0,
	67.5,
	-67.5,
	90.0,
	-90.0,
	112.5,
	-112.5,
	135.0,
	-135.0,
	157.5,
	-157.5,
	180.0,
]
const LANDING_RADIAL_OFFSETS_METERS := [0.0, 0.35, 0.75, 1.35, 2.1, 3.0, 4.0]
const SAFE_RING_OFFSETS_METERS := [0.65, 1.3, 2.0, 2.8, 3.7, 4.7, 5.8]


func classify_zone(
	distance_meters: float,
	outer_radius_meters: float,
	inner_radius_meters: float,
	hysteresis_meters: float,
	is_airborne_alert: bool
) -> Zone:
	var effective_outer := outer_radius_meters + (hysteresis_meters if is_airborne_alert else 0.0)
	if distance_meters > effective_outer:
		return Zone.OUT_OF_RANGE
	if distance_meters <= inner_radius_meters:
		return Zone.INNER_ATTACK
	return Zone.OUTER_HOVER


func compute_hover_direction(
	enemy_pos: Vector3,
	target_pos: Vector3,
	orbit_clock_seconds: float,
	orbit_sign: float,
	inner_attack_radius_meters: float,
	weave_amplitude: float,
	weave_frequency: float
) -> Vector3:
	var to_target := Vector3(target_pos.x - enemy_pos.x, 0.0, target_pos.z - enemy_pos.z)
	var dist := to_target.length()
	if dist <= MIN_DISTANCE_METERS:
		return Vector3.ZERO
	var forward := to_target / dist
	var perp := Vector3(-forward.z, 0.0, forward.x) * (1.0 if orbit_sign >= 0.0 else -1.0)
	var primary_wave := sin(orbit_clock_seconds * weave_frequency) * weave_amplitude
	var harmonic_wave := (
		cos(orbit_clock_seconds * weave_frequency * 0.57 + orbit_sign * 1.4)
		* (weave_amplitude * 0.65)
	)
	var weave := primary_wave + harmonic_wave
	var approach_weight := 0.62 if dist > inner_attack_radius_meters else 0.36
	# Camera nghiêng 45 độ nhìn xuống: giữ Đom đóm có xu hướng lượn phía trên/hai bên (-Z)
	# để hình chiếu màn hình không tụt xuống ngang ngực Foxy khi ở phía trước (+Z).
	var camera_clear_bias := Vector3.ZERO
	if enemy_pos.z > target_pos.z - 0.9:
		var bias_strength := lerpf(0.35, 1.05, clampf(1.0 - dist / 8.0, 0.0, 1.0))
		camera_clear_bias = Vector3(0.0, 0.0, -bias_strength)
	var combined := forward * approach_weight + perp * (0.72 + weave * 0.82) + camera_clear_bias
	if combined.is_zero_approx():
		return forward
	return combined.normalized()


## Quỹ đạo bay tự do uốn lượn như côn trùng tuần tra khi Player đã rời khỏi tầm nhìn.
func compute_free_roam_direction(
	enemy_pos: Vector3,
	home_pos: Vector3,
	clock_seconds: float,
	orbit_sign: float,
	roam_radius_meters: float = 3.4
) -> Vector3:
	var dir_sign := 1.0 if orbit_sign >= 0.0 else -1.0
	var yaw := clock_seconds * 1.05 * dir_sign + sin(clock_seconds * 2.15) * 0.95
	var roam_heading := Vector3(cos(yaw), 0.0, sin(yaw))
	var to_home := Vector3(home_pos.x - enemy_pos.x, 0.0, home_pos.z - enemy_pos.z)
	var home_dist := to_home.length()
	if home_dist > roam_radius_meters:
		var pull := clampf(
			(home_dist - roam_radius_meters) / maxf(0.8, roam_radius_meters), 0.0, 1.5
		)
		roam_heading = (roam_heading + (to_home / home_dist) * (0.85 + pull)).normalized()
	return roam_heading


func snap_point_to_ground(
	origin_pos: Vector3,
	ground_y: float,
	space: PhysicsDirectSpaceState3D,
	excluded_rids: Array[RID] = []
) -> Vector3:
	var base := Vector3(origin_pos.x, ground_y, origin_pos.z)
	if space == null:
		return base
	var snapped := _snap_ground(space, base, ground_y, excluded_rids)
	if snapped.has("pos"):
		return snapped["pos"] as Vector3
	return base


func select_landing_spot(context: Dictionary) -> Vector3:
	var origin: Vector3 = context.get("origin_pos", Vector3.ZERO) as Vector3
	var blast_center: Vector3 = context.get("blast_center", origin) as Vector3
	var preferred_dir: Vector3 = context.get("preferred_dir", Vector3.BACK) as Vector3
	var ground_y: float = float(context.get("ground_y", origin.y))
	var pool_radius: float = maxf(0.4, float(context.get("pool_radius", 1.15)))
	var clearance: float = maxf(0.35, float(context.get("landing_clearance", 0.55)))
	var occupied: Array = context.get("occupied_spots", []) as Array
	var space: PhysicsDirectSpaceState3D = context.get("space", null) as PhysicsDirectSpaceState3D
	var excluded_rids: Array[RID] = []
	var raw_excluded: Variant = context.get("excluded_rids", [])
	if raw_excluded is Array:
		for rid_item in raw_excluded:
			if rid_item is RID:
				excluded_rids.append(rid_item)

	var flat_dir := Vector3(preferred_dir.x, 0.0, preferred_dir.z)
	var has_avoid := bool(context.get("has_avoid_pos", false))
	var avoid_pos: Vector3 = context.get("avoid_pos", Vector3.ZERO) as Vector3
	if has_avoid:
		var away := Vector3(blast_center.x - avoid_pos.x, 0.0, blast_center.z - avoid_pos.z)
		if not away.is_zero_approx():
			flat_dir = away
	var base_dir := flat_dir.normalized() if not flat_dir.is_zero_approx() else Vector3.BACK
	var base_radius := pool_radius + clearance
	var fallback := Vector3(
		blast_center.x + base_dir.x * base_radius,
		ground_y,
		blast_center.z + base_dir.z * base_radius
	)
	var has_floor := space != null and _has_ground(space, origin, ground_y, excluded_rids)
	var has_clear := false
	var best_clear_score := -INF
	var best_clear_spot := fallback
	var best_overlap_clearance := -INF
	var best_overlap_spot := fallback

	for angle_deg in LANDING_SEARCH_ANGLES_DEG:
		var cand_dir := base_dir.rotated(Vector3.UP, deg_to_rad(angle_deg))
		for extra_r in LANDING_RADIAL_OFFSETS_METERS:
			var dist := base_radius + float(extra_r)
			var raw_candidate := Vector3(
				blast_center.x + cand_dir.x * dist, ground_y, blast_center.z + cand_dir.z * dist
			)
			var snapped_hit := _resolve_floor_candidate(
				space, raw_candidate, ground_y, has_floor, excluded_rids
			)
			if not snapped_hit.has("pos"):
				continue
			var cand_pos: Vector3 = snapped_hit["pos"] as Vector3
			var clearance_score := _spot_clearance(cand_pos, clearance, occupied)
			if clearance_score >= 0.0:
				var avoid_bonus := 0.0
				if has_avoid:
					var d_avoid := (
						Vector2(cand_pos.x - avoid_pos.x, cand_pos.z - avoid_pos.z).length()
					)
					avoid_bonus = clampf(d_avoid - 1.5, -1.2, 1.8) * 0.65
				var clear_score := -dist * 0.65 + avoid_bonus
				if not has_clear or clear_score > best_clear_score:
					has_clear = true
					best_clear_score = clear_score
					best_clear_spot = cand_pos
			elif not has_clear and clearance_score > best_overlap_clearance:
				best_overlap_clearance = clearance_score
				best_overlap_spot = cand_pos
	return best_clear_spot if has_clear else best_overlap_spot


## Kiểm tra điểm đáp trên mặt đất không đè vào bất kỳ vùng độc nào.
func is_spot_clear(point: Vector3, self_radius: float, occupied_spots: Array) -> bool:
	return _spot_clearance(point, self_radius, occupied_spots) >= 0.0


## Bảo đảm điểm hạ cánh nằm trên nền đất sạch ngoài mọi vũng độc hiện có và đang rơi.
func ensure_safe_landing_spot(
	origin_position: Vector3,
	desired_position: Vector3,
	ground_y: float,
	clearance_radius: float,
	occupied_spots: Array[Dictionary],
	space: PhysicsDirectSpaceState3D,
	excluded_rids: Array[RID] = [],
	max_search_meters: float = 6.5
) -> Vector3:
	var has_floor := space != null and _has_ground(space, origin_position, ground_y, excluded_rids)
	var direct := _resolve_floor_candidate(
		space, desired_position, ground_y, has_floor, excluded_rids
	)
	var direct_ok := direct.has("pos")
	var anchor: Vector3 = (direct["pos"] as Vector3) if direct_ok else origin_position
	if direct_ok and _spot_clearance(anchor, clearance_radius, occupied_spots) >= 0.0:
		return anchor

	var to_origin := Vector3(origin_position.x - anchor.x, 0.0, origin_position.z - anchor.z)
	var base_dir := to_origin.normalized() if not to_origin.is_zero_approx() else Vector3.BACK
	var best_overlap_clearance := (
		_spot_clearance(anchor, clearance_radius, occupied_spots) if direct_ok else -INF
	)
	var best_overlap_spot := anchor

	for ring_dist in SAFE_RING_OFFSETS_METERS:
		if float(ring_dist) > max_search_meters:
			break
		var has_clear_on_ring := false
		var best_ring_dist_to_origin := INF
		var best_ring_spot := anchor
		for angle_deg in LANDING_SEARCH_ANGLES_DEG:
			var cand_dir := base_dir.rotated(Vector3.UP, deg_to_rad(angle_deg))
			var raw_cand := Vector3(
				anchor.x + cand_dir.x * float(ring_dist),
				ground_y,
				anchor.z + cand_dir.z * float(ring_dist)
			)
			var snapped_hit := _resolve_floor_candidate(
				space, raw_cand, ground_y, has_floor, excluded_rids
			)
			if not snapped_hit.has("pos"):
				continue
			var cand_pos: Vector3 = snapped_hit["pos"] as Vector3
			var clearance := _spot_clearance(cand_pos, clearance_radius, occupied_spots)
			if clearance >= 0.0:
				var d_origin := (
					Vector2(cand_pos.x - origin_position.x, cand_pos.z - origin_position.z).length()
				)
				if not has_clear_on_ring or d_origin < best_ring_dist_to_origin:
					has_clear_on_ring = true
					best_ring_dist_to_origin = d_origin
					best_ring_spot = cand_pos
			elif clearance > best_overlap_clearance:
				best_overlap_clearance = clearance
				best_overlap_spot = cand_pos
		if has_clear_on_ring:
			return best_ring_spot
	return best_overlap_spot


func select_droplet_spots(
	blast_center: Vector3,
	ground_y: float,
	main_pool_radius: float,
	droplet_count: int,
	droplet_radius: float,
	occupied_spots: Array[Dictionary],
	space: PhysicsDirectSpaceState3D,
	excluded_rids: Array[RID] = []
) -> Array[Vector3]:
	var spots: Array[Vector3] = []
	if droplet_count <= 0:
		return spots
	var running_occupied: Array[Dictionary] = occupied_spots.duplicate()
	running_occupied.append({"pos": blast_center, "radius": main_pool_radius})
	var base_angle := randf() * TAU
	var ring_distance := main_pool_radius + droplet_radius + 0.35

	for idx in range(droplet_count):
		var angle := base_angle + TAU * (float(idx) / float(droplet_count))
		var offset := Vector3(cos(angle), 0.0, sin(angle)) * ring_distance
		var desired := Vector3(blast_center.x + offset.x, ground_y, blast_center.z + offset.z)
		var resolved := resolve_ground_spot(
			blast_center,
			desired,
			ground_y,
			droplet_radius,
			running_occupied,
			space,
			excluded_rids,
			main_pool_radius * 0.8,
			ring_distance + 1.4
		)
		spots.append(resolved)
		running_occupied.append({"pos": resolved, "radius": droplet_radius})
	return spots


func resolve_ground_spot(
	origin_position: Vector3,
	desired_position: Vector3,
	ground_y: float,
	spot_radius_meters: float,
	occupied_spots: Array[Dictionary],
	space: PhysicsDirectSpaceState3D,
	excluded_rids: Array[RID] = [],
	min_distance_meters: float = 0.4,
	max_distance_meters: float = INF
) -> Vector3:
	var to_desired := desired_position - origin_position
	to_desired.y = 0.0
	var min_d := maxf(0.1, min_distance_meters)
	var max_d := maxf(min_d, max_distance_meters)
	var base_dist := clampf(to_desired.length(), min_d, max_d)
	var base_dir := to_desired.normalized() if not to_desired.is_zero_approx() else Vector3.BACK
	var fallback := Vector3(
		origin_position.x + base_dir.x * base_dist,
		ground_y,
		origin_position.z + base_dir.z * base_dist
	)
	var snapped := _snap_ground(space, fallback, ground_y, excluded_rids)
	if snapped.has("pos"):
		fallback = snapped["pos"] as Vector3
	var best_clearance := _spot_clearance(fallback, spot_radius_meters, occupied_spots)
	var has_floor := space != null and _has_ground(space, origin_position, ground_y, excluded_rids)
	var has_clear := false
	var best_clear_dist := INF
	var best_clear_spot := fallback

	for angle_deg in SPOT_SEARCH_ANGLES_DEG:
		var cand_dir := base_dir.rotated(Vector3.UP, deg_to_rad(angle_deg))
		for r_mult in SPOT_RADIAL_OFFSETS:
			var cand_dist := clampf(base_dist + float(r_mult) * spot_radius_meters, min_d, max_d)
			var raw_candidate := Vector3(
				origin_position.x + cand_dir.x * cand_dist,
				ground_y,
				origin_position.z + cand_dir.z * cand_dist
			)
			var resolved_hit := _resolve_floor_candidate(
				space, raw_candidate, ground_y, has_floor, excluded_rids
			)
			if not resolved_hit.has("pos"):
				continue
			var candidate: Vector3 = resolved_hit["pos"] as Vector3
			var clearance := _spot_clearance(candidate, spot_radius_meters, occupied_spots)
			if clearance >= 0.0:
				var d_desired := (
					Vector2(candidate.x - desired_position.x, candidate.z - desired_position.z)
					. length()
				)
				if not has_clear or d_desired < best_clear_dist:
					has_clear = true
					best_clear_dist = d_desired
					best_clear_spot = candidate
			elif not has_clear and clearance > best_clearance:
				best_clearance = clearance
				fallback = candidate
	return best_clear_spot if has_clear else fallback


func _resolve_floor_candidate(
	space: PhysicsDirectSpaceState3D,
	point: Vector3,
	ground_y: float,
	has_floor: bool,
	excluded_rids: Array[RID]
) -> Dictionary:
	if not has_floor:
		return {"pos": point}
	return _snap_ground(space, point, ground_y, excluded_rids)


func _has_ground(
	space: PhysicsDirectSpaceState3D, point: Vector3, ground_y: float, excluded_rids: Array[RID]
) -> bool:
	return _snap_ground(space, point, ground_y, excluded_rids).has("pos")


func _snap_ground(
	space: PhysicsDirectSpaceState3D, point: Vector3, ground_y: float, excluded_rids: Array[RID]
) -> Dictionary:
	if space == null:
		return {}
	var query := PhysicsRayQueryParameters3D.create(
		Vector3(point.x, ground_y + 1.5, point.z),
		Vector3(point.x, ground_y - 3.5, point.z),
		CombatLayers.WORLD
	)
	query.exclude = excluded_rids
	var result := space.intersect_ray(query)
	if result.is_empty():
		return {}
	return {"pos": result["position"] as Vector3}


func _spot_clearance(point: Vector3, self_radius: float, occupied_spots: Array) -> float:
	var min_clearance := INF
	for item in occupied_spots:
		if not item is Dictionary:
			continue
		var dict := item as Dictionary
		var other_pos: Vector3 = dict.get("pos", Vector3.ZERO) as Vector3
		var other_radius := float(dict.get("radius", 1.0))
		var dist := Vector2(point.x - other_pos.x, point.z - other_pos.z).length()
		min_clearance = minf(
			min_clearance, dist - (self_radius + other_radius + POOL_SEPARATION_BUFFER_METERS)
		)
	return min_clearance if is_finite(min_clearance) else 1.0
