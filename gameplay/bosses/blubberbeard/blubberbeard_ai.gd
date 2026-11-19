class_name BlubberbeardAI
extends RefCounted
## Chọn chiêu động theo vị trí Player (gần / trung / xa, có ở gần biên không), phase và ngẫu nhiên.

enum DistanceZone { CLOSE, MID, FAR }

const DEFAULT_CLOSE_RANGE_METERS := 4.5
const DEFAULT_MID_RANGE_METERS := 9.5
const DEFAULT_BOUNDARY_MARGIN_METERS := 3.6
const REPEAT_PENALTY := 0.24

const DEFAULT_COOLDOWNS_SECONDS := {
	BlubberbeardSkillData.Kind.POWDER_BARREL: 4.8,
	BlubberbeardSkillData.Kind.SKY_DIVE: 5.2,
	BlubberbeardSkillData.Kind.SPIKY_INFLATION: 2.5,
	BlubberbeardSkillData.Kind.ANCHOR_SLAM: 3.2,
	BlubberbeardSkillData.Kind.ANCHOR_WHIRLWIND: 3.5,
	BlubberbeardSkillData.Kind.VENOM_SPIT: 5.5,
}

## Bảng quy tắc trọng số theo [DistanceZone, player_near_boundary].
const POSITION_RULES := {
	DistanceZone.CLOSE:
	{
		"open":
		{
			BlubberbeardSkillData.Kind.SPIKY_INFLATION: 6.0,
			BlubberbeardSkillData.Kind.ANCHOR_WHIRLWIND: 4.5,
			BlubberbeardSkillData.Kind.ANCHOR_SLAM: 2.2,
			BlubberbeardSkillData.Kind.VENOM_SPIT: 0.4,
			BlubberbeardSkillData.Kind.POWDER_BARREL: 0.0,
			BlubberbeardSkillData.Kind.SKY_DIVE: 0.0,
		},
		"boundary":
		{
			BlubberbeardSkillData.Kind.SPIKY_INFLATION: 5.8,
			BlubberbeardSkillData.Kind.ANCHOR_WHIRLWIND: 2.6,
			BlubberbeardSkillData.Kind.ANCHOR_SLAM: 1.2,
			BlubberbeardSkillData.Kind.POWDER_BARREL: 1.2,
			BlubberbeardSkillData.Kind.VENOM_SPIT: 0.0,
			BlubberbeardSkillData.Kind.SKY_DIVE: 0.0,
		},
	},
	DistanceZone.MID:
	{
		"open":
		{
			BlubberbeardSkillData.Kind.ANCHOR_WHIRLWIND: 3.6,
			BlubberbeardSkillData.Kind.VENOM_SPIT: 3.2,
			BlubberbeardSkillData.Kind.SKY_DIVE: 2.8,
			BlubberbeardSkillData.Kind.POWDER_BARREL: 2.4,
			BlubberbeardSkillData.Kind.SPIKY_INFLATION: 1.6,
			BlubberbeardSkillData.Kind.ANCHOR_SLAM: 0.0,
		},
		"boundary":
		{
			BlubberbeardSkillData.Kind.POWDER_BARREL: 4.4,
			BlubberbeardSkillData.Kind.SPIKY_INFLATION: 2.2,
			BlubberbeardSkillData.Kind.ANCHOR_WHIRLWIND: 1.4,
			BlubberbeardSkillData.Kind.SKY_DIVE: 0.0,
			BlubberbeardSkillData.Kind.VENOM_SPIT: 0.0,
			BlubberbeardSkillData.Kind.ANCHOR_SLAM: 0.0,
		},
	},
	DistanceZone.FAR:
	{
		"open":
		{
			BlubberbeardSkillData.Kind.SKY_DIVE: 3.8,
			BlubberbeardSkillData.Kind.POWDER_BARREL: 3.2,
			BlubberbeardSkillData.Kind.VENOM_SPIT: 2.6,
			BlubberbeardSkillData.Kind.SPIKY_INFLATION: 0.0,
			BlubberbeardSkillData.Kind.ANCHOR_WHIRLWIND: 0.0,
			BlubberbeardSkillData.Kind.ANCHOR_SLAM: 0.0,
		},
		"boundary":
		{
			BlubberbeardSkillData.Kind.POWDER_BARREL: 5.0,
			BlubberbeardSkillData.Kind.SKY_DIVE: 0.0,
			BlubberbeardSkillData.Kind.VENOM_SPIT: 0.0,
			BlubberbeardSkillData.Kind.SPIKY_INFLATION: 0.0,
			BlubberbeardSkillData.Kind.ANCHOR_WHIRLWIND: 0.0,
			BlubberbeardSkillData.Kind.ANCHOR_SLAM: 0.0,
		},
	},
}

var close_range_meters: float = DEFAULT_CLOSE_RANGE_METERS
var mid_range_meters: float = DEFAULT_MID_RANGE_METERS

var _cooldowns: Dictionary[int, float] = {}
var _last_skill_kind: int = -1
var _same_skill_streak: int = 0


func tick(delta: float) -> void:
	var step := maxf(0.0, delta)
	for kind: int in _cooldowns.keys():
		var left: float = _cooldowns[kind] - step
		if left <= 0.0:
			_cooldowns.erase(kind)
		else:
			_cooldowns[kind] = left


func reset() -> void:
	_cooldowns.clear()
	_last_skill_kind = -1
	_same_skill_streak = 0


func mark_used(kind: int, custom_cooldown: float = -1.0) -> void:
	var cd := (
		custom_cooldown
		if custom_cooldown >= 0.0
		else float(DEFAULT_COOLDOWNS_SECONDS.get(kind, 3.5))
	)
	if cd > 0.0:
		_cooldowns[kind] = cd
	if kind == _last_skill_kind:
		_same_skill_streak += 1
	else:
		_last_skill_kind = kind
		_same_skill_streak = 1


func get_cooldown_left(kind: int) -> float:
	return float(_cooldowns.get(kind, 0.0))


func resolve_zone(distance_meters: float) -> DistanceZone:
	if distance_meters <= close_range_meters:
		return DistanceZone.CLOSE
	if distance_meters <= mid_range_meters:
		return DistanceZone.MID
	return DistanceZone.FAR


func score_weight(
	kind: int, distance_meters: float, phase_index: int, player_near_boundary: bool = false
) -> float:
	if not _is_allowed_in_phase(kind, phase_index):
		return 0.0
	var zone := resolve_zone(distance_meters)
	var zone_key := "boundary" if player_near_boundary else "open"
	var rule_map: Dictionary = POSITION_RULES[zone][zone_key]
	var weight := float(rule_map.get(kind, 0.0))
	if kind == BlubberbeardSkillData.Kind.ANCHOR_WHIRLWIND and distance_meters > 7.2:
		weight *= 0.35
	return weight


func select_skill_index(
	phase: BossPhaseData,
	phase_index: int,
	distance_meters: float,
	fallback_index: int,
	player_near_boundary: bool = false
) -> int:
	if phase == null or phase.skills.is_empty():
		return 0
	if phase.skills.size() == 1:
		return 0
	var weights: Array[float] = []
	var total := 0.0
	for index in phase.skills.size():
		var candidate := phase.skills[index] as BlubberbeardSkillData
		if candidate == null:
			weights.append(0.0)
			continue
		var weight := score_weight(
			candidate.kind, distance_meters, phase_index, player_near_boundary
		)
		if weight <= 0.0 or get_cooldown_left(candidate.kind) > 0.0:
			weight = 0.0
		elif candidate.kind == _last_skill_kind:
			weight *= 0.0 if _same_skill_streak >= 2 else REPEAT_PENALTY
		weights.append(weight)
		total += weight
	if total <= 0.0:
		return _pick_position_fallback(
			phase, phase_index, distance_meters, fallback_index, player_near_boundary
		)
	var roll := randf() * total
	var accum := 0.0
	for index in weights.size():
		accum += weights[index]
		if roll <= accum and weights[index] > 0.0:
			return index
	return clampi(fallback_index % phase.skills.size(), 0, phase.skills.size() - 1)


func _is_allowed_in_phase(kind: int, phase_index: int) -> bool:
	if (
		phase_index <= 0
		and (
			kind == BlubberbeardSkillData.Kind.ANCHOR_WHIRLWIND
			or kind == BlubberbeardSkillData.Kind.VENOM_SPIT
		)
	):
		return false
	return true


func _pick_position_fallback(
	phase: BossPhaseData,
	phase_index: int,
	distance_meters: float,
	fallback_index: int,
	player_near_boundary: bool
) -> int:
	var best_idx := -1
	var best_score := -INF
	for index in phase.skills.size():
		var candidate := phase.skills[index] as BlubberbeardSkillData
		if candidate == null or not _is_allowed_in_phase(candidate.kind, phase_index):
			continue
		var rule_weight := score_weight(
			candidate.kind, distance_meters, phase_index, player_near_boundary
		)
		var cd_penalty := get_cooldown_left(candidate.kind)
		var repeat_penalty := 1.0 if candidate.kind == _last_skill_kind else 0.0
		var score := rule_weight * 4.0 - cd_penalty - repeat_penalty
		if score > best_score:
			best_score = score
			best_idx = index
	if best_idx >= 0:
		return best_idx
	return clampi(fallback_index % phase.skills.size(), 0, phase.skills.size() - 1)


static func is_position_near_boundary(
	space: PhysicsDirectSpaceState3D,
	pos: Vector3,
	ground_y: float,
	margin_meters: float,
	excluded: Array[RID]
) -> bool:
	if space == null or margin_meters <= 0.0:
		return false
	var origin := Vector3(pos.x, ground_y + 1.25, pos.z)
	var has_floor := _has_floor_below(space, origin, excluded)
	for step in 8:
		var angle := TAU * float(step) / 8.0
		var probe_end := origin + Vector3(cos(angle), 0.0, sin(angle)) * margin_meters
		if _hits_boundary_wall(space, origin, probe_end, excluded):
			return true
		if has_floor and not _has_floor_below(space, probe_end, excluded):
			return true
	return false


static func spot_crosses_boundary(
	space: PhysicsDirectSpaceState3D,
	from_pos: Vector3,
	candidate: Vector3,
	ground_y: float,
	excluded: Array[RID]
) -> bool:
	if space == null:
		return false
	var origin := Vector3(from_pos.x, ground_y + 1.25, from_pos.z)
	var dest := Vector3(candidate.x, ground_y + 1.25, candidate.z)
	if _hits_boundary_wall(space, origin, dest, excluded):
		return true
	return _has_floor_below(space, origin, excluded) and not _has_floor_below(space, dest, excluded)


static func _hits_boundary_wall(
	space: PhysicsDirectSpaceState3D, from: Vector3, to: Vector3, excluded: Array[RID]
) -> bool:
	var mask := CombatLayers.WORLD | CombatLayers.PLAYER_BOUNDARY
	var query := PhysicsRayQueryParameters3D.create(from, to, mask, excluded)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return not space.intersect_ray(query).is_empty()


static func _has_floor_below(
	space: PhysicsDirectSpaceState3D, probe: Vector3, excluded: Array[RID]
) -> bool:
	var query := PhysicsRayQueryParameters3D.create(
		probe, probe + Vector3.DOWN * 2.6, CombatLayers.WORLD, excluded
	)
	query.collide_with_areas = false
	query.collide_with_bodies = true
	return not space.intersect_ray(query).is_empty()
