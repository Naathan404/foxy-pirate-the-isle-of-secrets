class_name EliteMushroomPatrol
extends MushroomPatrol
## Hành vi tuần tra & chiến đấu của EliteMushroom: chuyển đổi linh hoạt giữa
## Không Chân (ngụy trang, nhảy nặng) <-> Có Chân (chạy nhanh, bọc sườn, giữ cự ly),
## kết hợp chiêu cũ, SporeStream và chiêu cận tử Đại Bào Tử.

const FLANK_SWAP_INTERVAL := 2.2
const ELITE_STEER_ANGLES := [
	0.0,
	PI / 6.0,
	-PI / 6.0,
	PI / 3.0,
	-PI / 3.0,
	1.75,
	-1.75,
]

var _flank_clock: float = 0.0


func _update(delta: float) -> void:
	var elite := enemy as EliteMushroom
	var step := maxf(0.0, delta)
	_flank_clock += step
	if _flank_clock >= FLANK_SWAP_INTERVAL:
		_flank_clock = 0.0
		_strafe_sign = -_strafe_sign

	if elite != null:
		if elite.is_morphing():
			elite.stop_movement(step)
			elite.play_directional_animation(&"morph")
			return
		if not elite.is_evading() and not elite.is_approach_leaping():
			if elite.can_trigger_great_spore():
				elite.consume_knockback_charge()
				_has_awakened = true
				if elite.has_target():
					_last_seen = elite.target.global_position
					elite.face_target()
				_reset_charge()
				if request_state(&"greatspore"):
					return
	super(delta)


func _update_phase(mushroom: MushroomEnemy, step: float, detected: bool) -> void:
	var elite := mushroom as EliteMushroom
	if elite != null:
		if _phase in [Phase.DISGUISE, Phase.WANDER] and elite.is_legged():
			if elite.request_stance(EliteMushroom.Stance.FOOTLESS):
				return
		elif _phase == Phase.SEARCH and elite.is_legged() and _remaining <= 0.6:
			if elite.request_stance(EliteMushroom.Stance.FOOTLESS):
				return
	super(mushroom, step, detected)


func _chase(mushroom: MushroomEnemy, delta: float) -> void:
	var elite := mushroom as EliteMushroom
	if elite == null:
		super(mushroom, delta)
		return
	var offset := _horizontal(elite.target.global_position - elite.global_position)
	var dist := offset.length()

	if _try_start_close_charge(elite, delta):
		return
	var from_home := _horizontal(elite.global_position - elite.home_position)
	if from_home.length() > elite.movement_radius:
		if _try_escape_corner_leap(elite, -from_home.normalized()):
			return
		_elite_move(elite, -from_home.normalized(), delta, elite.legged_chase_speed_scale)
		return

	if _try_start_elite_attack(elite, delta, offset):
		return

	if _try_break_out_of_corner(elite, offset, dist):
		return

	if _maybe_switch_combat_stance(elite, dist):
		return

	# Kite diagonally away when SporeStream is ready and player hugs close inside min range,
	# but never back straight into a cliff/wall corner.
	if (
		elite.is_legged()
		and dist < elite.stream_min_distance_meters
		and elite.stream_cooldown_remaining <= 0.35
		and elite.attack_cooldown_remaining > 0.0
	):
		var away := -offset.normalized() if dist > 0.05 else -elite.last_facing_direction
		var perp := Vector3(-away.z, 0.0, away.x) * _strafe_sign
		var kite_dir := (away * 0.68 + perp * 0.72).normalized()
		if _is_edge_behind(elite, away, 2.4):
			var inward := _horizontal(elite.home_position - elite.global_position).normalized()
			kite_dir = (perp * 0.72 + inward * 0.68).normalized()
		if _elite_move(elite, kite_dir, delta, elite.legged_chase_speed_scale):
			return

	if dist <= elite.attack_range:
		elite.face_target()
		_idle(elite, delta, &"idle")
		return

	if _try_start_approach_leap(elite, offset):
		return
	if _try_roll_random_chase_charge(elite, delta):
		return

	if elite.is_legged():
		var steer_dir := _compute_tactical_flank_direction(offset, dist)
		_elite_move(elite, steer_dir, delta, elite.legged_chase_speed_scale)
	else:
		_elite_move(elite, offset.normalized(), delta, elite.chase_speed_scale)


func _try_start_elite_attack(
	mushroom: MushroomEnemy, _delta: float, target_offset: Vector3
) -> bool:
	var elite := mushroom as EliteMushroom
	if elite == null:
		return false
	if _try_start_stream_attack(elite, target_offset):
		return true
	return false


func _try_start_stream_attack(elite: EliteMushroom, target_offset: Vector3) -> bool:
	if elite.stream_cooldown_remaining > 0.0:
		return false
	if elite.is_evading() or elite.is_approach_leaping() or elite.is_morphing():
		return false
	var distance := target_offset.length()
	if distance < elite.stream_min_distance_meters or distance > elite.stream_max_distance_meters:
		return false
	var dir := target_offset.normalized()
	elite.face_direction(dir)
	elite._refresh_direction_checks()
	if elite.is_front_blocked():
		return false
	return request_state(&"sporestream")


func _maybe_switch_combat_stance(elite: EliteMushroom, dist: float) -> bool:
	if not elite.can_switch_stance():
		return false
	var hp_pressure := elite.get_hp_pressure()
	if not elite.is_legged():
		var need_sprint := dist >= elite.legged_chase_trigger_distance or hp_pressure >= 0.45
		var footless_expired := elite.get_stance_elapsed() >= elite.footless_stance_max_seconds
		if need_sprint or footless_expired:
			return elite.request_stance(EliteMushroom.Stance.LEGGED)
	else:
		var bunker_hold := elite.is_inside_poison_cloud() and dist <= 3.4 and hp_pressure < 0.45
		var legged_expired := (
			elite.get_stance_elapsed() >= elite.legged_stance_max_seconds and dist <= 4.8
		)
		if bunker_hold or legged_expired:
			return elite.request_stance(EliteMushroom.Stance.FOOTLESS)
	return false


func _compute_tactical_flank_direction(offset: Vector3, dist: float) -> Vector3:
	if dist <= 0.05:
		return Vector3.BACK
	var fwd := offset / dist
	var perp := Vector3(-fwd.z, 0.0, fwd.x) * _strafe_sign
	var flank_weight := 0.56 if dist > 4.6 else 0.88
	var fwd_weight := 0.82 if dist > 4.6 else 0.48
	return (fwd * fwd_weight + perp * flank_weight).normalized()


func _try_break_out_of_corner(elite: EliteMushroom, offset: Vector3, dist: float) -> bool:
	if _chase_leap_cooldown_remaining > 0.0 or dist > 4.2 or dist < 0.2:
		return false
	var away := -offset / dist
	if not _is_edge_behind(elite, away, 2.5):
		return false
	return _try_escape_corner_leap(elite, away)


func _try_escape_corner_leap(elite: EliteMushroom, away_from_threat: Vector3) -> bool:
	if _chase_leap_cooldown_remaining > 0.0 or elite.is_evading() or elite.is_morphing():
		return false
	var inward := _horizontal(elite.home_position - elite.global_position)
	var base := inward.normalized() if not inward.is_zero_approx() else -away_from_threat
	var perp := Vector3(-away_from_threat.z, 0.0, away_from_threat.x).normalized() * _strafe_sign
	for cand: Vector3 in [
		(base * 0.7 + perp * 0.7).normalized(),
		(base * 0.7 - perp * 0.7).normalized(),
		base,
		perp,
		-perp,
	]:
		if elite.start_approach_leap(cand, elite.approach_leap_distance_meters * 0.9):
			_strafe_sign = -_strafe_sign
			_chase_leap_cooldown_remaining = elite.approach_leap_cooldown_seconds
			_set_phase(Phase.CHASE_LEAP, elite.approach_leap_duration_seconds)
			return true
	return false


func _is_edge_behind(elite: EliteMushroom, check_dir: Vector3, reach: float) -> bool:
	if check_dir.is_zero_approx():
		return false
	return not elite._is_hop_safe(check_dir.normalized(), reach)


func _elite_move(
	elite: EliteMushroom, desired_dir: Vector3, delta: float, speed_scale: float
) -> bool:
	for angle: float in ELITE_STEER_ANGLES:
		var candidate := desired_dir.rotated(Vector3.UP, angle * _strafe_sign)
		elite.face_direction(candidate)
		elite._refresh_direction_checks()
		if not elite.is_front_blocked() and elite.is_ground_ahead():
			if angle < -0.8:
				_strafe_sign = -_strafe_sign
			elite.move_in_direction(candidate, delta, speed_scale)
			elite.play_directional_animation(&"walk")
			elite.notify_legged_stride(true)
			return true
	elite.stop_movement(delta)
	elite.play_directional_animation(&"idle")
	return false
