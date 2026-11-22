class_name EliteThornTendril
extends EnemyState
## Chiêu pha dưới 50% HP: phóng chuỗi rễ gai trồi theo đường sấm sét zíc-zắc khó đoán và giữ lâu.

enum Phase {
	WINDUP,
	ERUPTING,
	RECOVER,
}

const THORN_SEGMENT_SCRIPT := preload("res://gameplay/enemies/venom_vine/venom_thorn_segment.gd")
const VFX_SCRIPT := preload("res://gameplay/enemies/venom_vine/venom_vine_vfx.gd")
const AIM_LOCK_SECONDS := 0.22
const LINE_FLOOR_RAY_UP := 1.5
const LINE_FLOOR_RAY_DOWN := 3.5
const LINE_WALL_RAY_HEIGHT := 0.6
const LIGHTNING_JINK_MIN_RAD := 0.7
const LIGHTNING_JINK_MAX_RAD := 1.04
const LIGHTNING_BASE_OFFSET_RAD := 0.28
const FORK_BRANCH_ANGLE_RAD := 0.92
const FORK_STEP_MIN := 3

var _phase: Phase = Phase.WINDUP
var _phase_remaining_seconds: float = 0.0
var _segment_timer_seconds: float = 0.0
var _spawned_segments: int = 0
var _aim_locked: bool = false
var _line_origin: Vector3 = Vector3.ZERO
var _line_direction: Vector3 = Vector3.BACK
var _last_valid_spot: Vector3 = Vector3.ZERO
var _planned_path: Array[Dictionary] = []


func _enter() -> void:
	var vine := enemy as EliteVenomVine
	if vine == null:
		request_state(&"stalk")
		return
	enemy._set_horizontal_velocity(Vector3.ZERO)
	vine.set_awake(true)
	vine.set_sprite_sheet_mode(false)
	vine.face_target()
	vine.play_directional_animation(&"charge", true)
	vine.set_charge_glow(1.35, true)
	vine.begin_elite_telegraph()
	_phase = Phase.WINDUP
	_phase_remaining_seconds = vine.tendril_windup_seconds
	_aim_locked = false
	_spawned_segments = 0
	_planned_path.clear()
	_line_direction = _compute_tendril_direction(vine)


func _exit() -> void:
	var vine := enemy as EliteVenomVine
	if vine != null:
		vine.end_elite_telegraph()
		vine.set_charge_glow(0.0, false)


func _update(delta: float) -> void:
	var vine := enemy as EliteVenomVine
	if vine == null or vine.dead:
		return
	enemy._set_horizontal_velocity(Vector3.ZERO)
	var step := maxf(0.0, delta)
	match _phase:
		Phase.WINDUP:
			_update_windup(vine, step)
		Phase.ERUPTING:
			_update_erupting(vine, step)
		Phase.RECOVER:
			_phase_remaining_seconds = maxf(0.0, _phase_remaining_seconds - step)
			if _phase_remaining_seconds <= 0.0:
				request_state(&"stalk" if vine.has_target() else &"vigilant")


func _update_windup(vine: EliteVenomVine, step: float) -> void:
	_phase_remaining_seconds = maxf(0.0, _phase_remaining_seconds - step)
	if not _aim_locked and _phase_remaining_seconds <= AIM_LOCK_SECONDS:
		_aim_locked = true
		_line_direction = _compute_tendril_direction(vine)
		vine.face_direction(_line_direction)
	elif not _aim_locked and vine.has_target():
		vine.face_target()
	if _phase_remaining_seconds <= 0.0:
		_begin_erupting(vine)


func _begin_erupting(vine: EliteVenomVine) -> void:
	_phase = Phase.ERUPTING
	_spawned_segments = 0
	_segment_timer_seconds = 0.0
	_line_origin = vine.global_position
	_last_valid_spot = _line_origin
	_planned_path = _build_lightning_path(vine)
	vine.end_elite_telegraph()
	vine.set_charge_glow(0.0, false)
	vine.play_directional_animation(&"shoot", true)
	vine.start_tendril_cooldown()
	_spawn_pending_segments(vine)


func _update_erupting(vine: EliteVenomVine, step: float) -> void:
	_segment_timer_seconds -= step
	_spawn_pending_segments(vine)


func _spawn_pending_segments(vine: EliteVenomVine) -> void:
	while (
		_phase == Phase.ERUPTING
		and _segment_timer_seconds <= 0.0
		and _spawned_segments < _planned_path.size()
	):
		var step_info := _planned_path[_spawned_segments]
		var spot := step_info["spot"] as Vector3
		var prev_spot := step_info["prev"] as Vector3
		_spawn_lightning_fissure_vfx(vine, prev_spot, spot)
		_spawn_segment_at(vine, spot)
		if bool(step_info.get("is_main", true)):
			_last_valid_spot = spot
		_spawned_segments += 1
		_segment_timer_seconds += vine.tendril_segment_interval_seconds
		if _spawned_segments >= _planned_path.size():
			_finish_erupting(vine)
			return


func _build_lightning_path(vine: EliteVenomVine) -> Array[Dictionary]:
	var plan: Array[Dictionary] = []
	var count := maxi(2, vine.tendril_segment_count)
	var sign_dir := 1.0 if randf() < 0.5 else -1.0
	var base_dir := _line_direction.rotated(
		Vector3.UP, sign_dir * randf_range(0.08, LIGHTNING_BASE_OFFSET_RAD)
	)
	var turn_interval := 2
	var cur_dir := base_dir.rotated(Vector3.UP, sign_dir * 0.42)
	var cur_pos := _line_origin
	var fork_anchor := Vector3.ZERO
	var fork_dir := Vector3.ZERO
	var has_fork := false

	for idx in range(count):
		if idx > 0 and idx % turn_interval == 0:
			sign_dir = -sign_dir
			var bend := randf_range(LIGHTNING_JINK_MIN_RAD, LIGHTNING_JINK_MAX_RAD)
			cur_dir = base_dir.rotated(Vector3.UP, sign_dir * bend)
		var step_len := (
			vine.tendril_start_distance_meters if idx == 0 else vine.tendril_segment_spacing_meters
		)
		var desired := cur_pos + cur_dir * step_len
		var resolved: Variant = _resolve_segment_spot(vine, cur_pos, desired)
		if not (resolved is Vector3):
			# Thử bẻ góc ngược lại nếu vướng tường/vực để nhánh sấm sét tiếp tục uốn thoát.
			var alt_dir := base_dir.rotated(Vector3.UP, -sign_dir * LIGHTNING_JINK_MAX_RAD)
			resolved = _resolve_segment_spot(vine, cur_pos, cur_pos + alt_dir * step_len)
			if not (resolved is Vector3):
				break
		var spot := resolved as Vector3
		plan.append({"prev": cur_pos, "spot": spot, "is_main": true})
		if not has_fork and idx >= FORK_STEP_MIN and count >= 6:
			has_fork = true
			fork_anchor = spot
			fork_dir = cur_dir.rotated(Vector3.UP, -sign_dir * FORK_BRANCH_ANGLE_RAD)
		cur_pos = spot

	if has_fork:
		var branch_prev := fork_anchor
		for _b in range(2):
			var branch_desired := branch_prev + fork_dir * vine.tendril_segment_spacing_meters
			var branch_spot: Variant = _resolve_segment_spot(vine, branch_prev, branch_desired)
			if not (branch_spot is Vector3):
				break
			var b_pos := branch_spot as Vector3
			plan.append({"prev": branch_prev, "spot": b_pos, "is_main": false})
			branch_prev = b_pos
	return plan


func _spawn_lightning_fissure_vfx(vine: EliteVenomVine, prev_spot: Vector3, spot: Vector3) -> void:
	var parent := vine.get_parent()
	if not is_instance_valid(parent) or parent.is_queued_for_deletion():
		return
	var link := spot - prev_spot
	link.y = 0.0
	if link.is_zero_approx():
		return
	var mid := prev_spot.lerp(spot, 0.5)
	var total_life := (
		vine.tendril_segment_telegraph_seconds
		+ vine.tendril_segment_active_seconds
		+ vine.tendril_segment_retract_seconds
	)
	VFX_SCRIPT.spawn_tunnel_track_scar(
		parent, mid, link.normalized(), 1.15, maxf(1.2, total_life), 0.75
	)
	(
		VFX_SCRIPT
		. spawn_additive_atlas_burst(
			parent,
			"LightningRootFissureFlash",
			spot + Vector3.UP * 0.14,
			{
				"col": 0,
				"pixel_size": 0.0046,
				"tint": Color(0.92, 0.52, 1.0, 0.9),
				"start_scale": 0.35,
				"end_scale": 0.95,
				"duration": 0.24,
				"billboard": true,
				"purple": true,
			}
		)
	)


func _finish_erupting(vine: EliteVenomVine) -> void:
	if _spawned_segments > 0 and vine.tendril_spawn_end_pool:
		vine.spawn_snare_pool_at(_last_valid_spot, vine.tendril_end_pool_radius_meters)
	_phase = Phase.RECOVER
	_phase_remaining_seconds = vine.tendril_recovery_seconds
	vine.attack_cooldown_remaining = maxf(
		vine.attack_cooldown_remaining, vine.tendril_post_attack_delay_seconds
	)
	vine.play_directional_animation(&"idle")


func _spawn_segment_at(vine: EliteVenomVine, world_spot: Vector3) -> void:
	var parent := vine.get_parent()
	if not is_instance_valid(parent) or parent.is_queued_for_deletion():
		return
	var seg := THORN_SEGMENT_SCRIPT.new() as VenomThornSegment
	seg.setup(
		vine,
		vine.team,
		world_spot,
		vine.tendril_visual_radius_meters,
		vine.tendril_hitbox_radius_meters,
		vine.resolve_attack_damage(vine.tendril_damage_multiplier),
		vine.tendril_knockback_multiplier,
		vine.tendril_segment_telegraph_seconds,
		vine.tendril_segment_active_seconds,
		vine.tendril_segment_retract_seconds
	)
	parent.add_child(seg)
	seg.global_position = world_spot


func _resolve_segment_spot(vine: EliteVenomVine, prev_spot: Vector3, desired: Vector3) -> Variant:
	var space := (
		vine.get_world_3d().direct_space_state
		if vine.is_inside_tree() and vine.get_world_3d() != null
		else null
	)
	if space == null:
		return Vector3(desired.x, vine.global_position.y, desired.z)

	var excluded: Array[RID] = [vine.get_rid()]
	var wall_from := prev_spot + Vector3.UP * LINE_WALL_RAY_HEIGHT
	var wall_to := Vector3(desired.x, prev_spot.y + LINE_WALL_RAY_HEIGHT, desired.z)
	var wall_query := PhysicsRayQueryParameters3D.create(wall_from, wall_to, CombatLayers.WORLD)
	wall_query.exclude = excluded
	if not space.intersect_ray(wall_query).is_empty():
		return null

	var floor_from := Vector3(desired.x, vine.global_position.y + LINE_FLOOR_RAY_UP, desired.z)
	var floor_to := Vector3(desired.x, vine.global_position.y - LINE_FLOOR_RAY_DOWN, desired.z)
	var floor_query := PhysicsRayQueryParameters3D.create(floor_from, floor_to, CombatLayers.WORLD)
	floor_query.exclude = excluded
	var hit := space.intersect_ray(floor_query)
	if hit.is_empty():
		return null
	return hit["position"] as Vector3


func _compute_tendril_direction(vine: EliteVenomVine) -> Vector3:
	if not vine.has_target():
		return vine.last_facing_direction
	var aim_pos := vine.target.global_position
	if vine.ai != null:
		aim_pos = vine.ai.compute_lead_position(
			vine.global_position,
			vine.target.global_position,
			vine.get_target_velocity(),
			vine.tendril_windup_seconds * 0.75 + vine.tendril_segment_telegraph_seconds,
			vine.max_lead_meters * 1.15,
			vine.lead_accuracy
		)
	var dir := aim_pos - vine.global_position
	dir.y = 0.0
	return dir.normalized() if not dir.is_zero_approx() else vine.last_facing_direction
