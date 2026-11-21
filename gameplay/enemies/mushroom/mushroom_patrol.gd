class_name MushroomPatrol
extends EnemyState
## Ambush, observe, leap toward distant detected players, spray spores in range,
## and return to searching when players leave detection range.

enum Phase { DISGUISE, WANDER, OBSERVE, CHASE, CHASE_LEAP, CHARGE, RECOVER, SEARCH }

const ARRIVAL_DISTANCE := 0.6
const AVOID_ANGLE := PI / 3.0
const CHASE_LEAP_RETRY_SECONDS := 0.65
const APPROACH_LEAP_LANDING_BUFFER_METERS := 0.35

var _phase: Phase = Phase.DISGUISE
var _remaining: float = 0.0
var _random := RandomNumberGenerator.new()
var _last_seen: Vector3
var _wander_direction: Vector3 = Vector3.ZERO
var _strafe_sign: float = 1.0
var _has_awakened: bool = false
var _chase_spore_check_remaining: float = 0.0
var _chase_leap_cooldown_remaining: float = 0.0
var _chase_leap_retry_remaining: float = 0.0
var _ambush_hold_remaining: float = -1.0
var _active_charge_duration: float = 1.6
var _skip_next_observe: bool = false


func mark_skip_next_observe() -> void:
	_skip_next_observe = true


func _enter() -> void:
	_random.randomize()
	_ambush_reset()
	_reset_chase_spore_timer()
	if not enemy.damaged.is_connected(_on_damaged):
		enemy.damaged.connect(_on_damaged)
	var mushroom := enemy as MushroomEnemy
	if mushroom == null:
		return
	if _has_awakened:
		if _skip_next_observe:
			_skip_next_observe = false
			if _target_is_detected(mushroom):
				_set_phase(Phase.CHASE, 0.0)
			else:
				_set_phase(Phase.SEARCH, mushroom.search_seconds)
		else:
			_set_phase(Phase.OBSERVE, mushroom.observe_seconds)
	else:
		_set_phase(Phase.DISGUISE, _random_disguise_seconds(mushroom))


func _exit() -> void:
	_reset_charge()
	if enemy.damaged.is_connected(_on_damaged):
		enemy.damaged.disconnect(_on_damaged)


func _update(delta: float) -> void:
	var mushroom := enemy as MushroomEnemy
	if mushroom == null:
		return
	var step := maxf(delta, 0.0)
	_chase_leap_cooldown_remaining = maxf(0.0, _chase_leap_cooldown_remaining - step)
	_chase_leap_retry_remaining = maxf(0.0, _chase_leap_retry_remaining - step)
	if mushroom.is_evading():
		if _phase == Phase.CHARGE:
			_reset_charge()
			_reset_chase_spore_timer()
			_set_phase(Phase.CHASE, 0.0)
		mushroom.stop_movement(step)
		mushroom.play_directional_animation(&"walk")
		return
	_remaining = maxf(0.0, _remaining - step)
	var detected := _target_is_detected(mushroom)
	var has_kb_charge := mushroom.consume_knockback_charge()
	if has_kb_charge and not mushroom.is_inside_poison_cloud():
		_has_awakened = true
		if detected:
			_last_seen = mushroom.target.global_position
			mushroom.face_target()
		_begin_charge(mushroom, step, mushroom.knockback_charge_duration_seconds)
		return
	if detected:
		_last_seen = mushroom.target.global_position
		if _phase == Phase.CHASE:
			_has_awakened = true
			_chase_spore_check_remaining = maxf(0.0, _chase_spore_check_remaining - step)
	else:
		_ambush_reset()
		if _phase in [Phase.OBSERVE, Phase.CHASE, Phase.CHASE_LEAP]:
			_abort_to_search(mushroom)
			return
	_update_phase(mushroom, step, detected)


func _update_phase(mushroom: MushroomEnemy, step: float, detected: bool) -> void:
	match _phase:
		Phase.DISGUISE:
			_disguise(mushroom, step, detected)
		Phase.WANDER:
			if detected:
				_set_phase(Phase.OBSERVE, mushroom.observe_seconds)
			elif _remaining <= 0.0:
				_set_phase(Phase.DISGUISE, _random_disguise_seconds(mushroom))
			else:
				_wander(mushroom, step)
		Phase.OBSERVE:
			_observe(mushroom, step, detected)
		Phase.CHASE:
			_chase(mushroom, step)
		Phase.CHASE_LEAP:
			_chase_leap(mushroom, step)
		Phase.CHARGE:
			_charge(mushroom, step, detected)
		Phase.RECOVER:
			_idle(mushroom, step, &"spore_release")
			if _remaining <= 0.0:
				if detected:
					_set_phase(Phase.CHASE, 0.0)
				elif _has_awakened:
					_set_phase(Phase.SEARCH, mushroom.search_seconds)
				else:
					_set_phase(Phase.DISGUISE, _random_disguise_seconds(mushroom))
		Phase.SEARCH:
			_search(mushroom, step, detected)


func _ambush_reset() -> void:
	_ambush_hold_remaining = -1.0


func _set_phase(phase: Phase, duration: float) -> void:
	_phase = phase
	_remaining = duration


func _abort_to_search(mushroom: MushroomEnemy) -> void:
	_reset_charge()
	_reset_chase_spore_timer()
	mushroom.cancel_approach_leap()
	_set_phase(Phase.SEARCH, mushroom.search_seconds)


func _disguise(mushroom: MushroomEnemy, step: float, detected: bool) -> void:
	_idle(mushroom, step, &"disguise")
	if detected:
		var dist := _distance_to_target_xz(mushroom)
		if _ambush_hold_remaining < 0.0 and mushroom.ai != null:
			_ambush_hold_remaining = mushroom.ai.roll_ambush_hold(
				dist,
				mushroom.ambush_wake_distance,
				mushroom.ambush_delay_min_seconds,
				mushroom.ambush_delay_max_seconds
			)
		elif _ambush_hold_remaining < 0.0:
			_ambush_hold_remaining = 0.0
		if dist <= mushroom.ambush_wake_distance or _ambush_hold_remaining <= 0.0:
			_ambush_reset()
			_has_awakened = true
			_set_phase(Phase.OBSERVE, mushroom.observe_seconds)
			return
		_ambush_hold_remaining = maxf(0.0, _ambush_hold_remaining - step)
		return
	if _remaining <= 0.0:
		_begin_wander(mushroom)


func _begin_wander(mushroom: MushroomEnemy) -> void:
	var angle := _random.randf_range(0.0, TAU)
	_wander_direction = Vector3(cos(angle), 0.0, sin(angle))
	_set_phase(Phase.WANDER, _random_wander_seconds(mushroom))


func _wander(mushroom: MushroomEnemy, delta: float) -> void:
	var from_home := mushroom.global_position - mushroom.home_position
	from_home.y = 0.0
	if from_home.length() >= mushroom.movement_radius:
		_wander_direction = -from_home.normalized()
	if not _move_safely(mushroom, _wander_direction, delta, mushroom.wander_speed_scale):
		_set_phase(Phase.DISGUISE, _random_disguise_seconds(mushroom))


func _observe(mushroom: MushroomEnemy, delta: float, detected: bool) -> void:
	_idle(mushroom, delta, &"idle")
	if detected:
		mushroom.face_target()
		if _distance_to_target_xz(mushroom) <= mushroom.attack_range:
			if _try_start_close_charge(mushroom, delta):
				return
	if _remaining <= 0.0:
		_set_phase(Phase.CHASE, 0.0)


func _chase(mushroom: MushroomEnemy, delta: float) -> void:
	if _try_start_close_charge(mushroom, delta):
		return
	var from_home := _horizontal(mushroom.global_position - mushroom.home_position)
	if from_home.length() > mushroom.movement_radius:
		_move_safely(mushroom, -from_home.normalized(), delta, mushroom.wander_speed_scale)
		return
	var offset := _horizontal(mushroom.target.global_position - mushroom.global_position)
	if offset.length() <= mushroom.attack_range:
		mushroom.face_target()
		_idle(mushroom, delta, &"idle")
		return
	if _try_start_elite_attack(mushroom, delta, offset):
		return
	if _try_start_approach_leap(mushroom, offset):
		return
	if _try_roll_random_chase_charge(mushroom, delta):
		return
	_move_safely(mushroom, offset.normalized(), delta, mushroom.chase_speed_scale)


func _try_start_elite_attack(
	_mushroom: MushroomEnemy, _delta: float, _target_offset: Vector3
) -> bool:
	return false


func _chase_leap(mushroom: MushroomEnemy, delta: float) -> void:
	if not mushroom.is_approach_leaping():
		_set_phase(Phase.CHASE, 0.0)
		return
	mushroom.stop_movement(delta)
	mushroom.play_directional_animation(&"walk")


func _try_start_approach_leap(mushroom: MushroomEnemy, target_offset: Vector3) -> bool:
	if (
		mushroom.ai == null
		or _chase_leap_cooldown_remaining > 0.0
		or _chase_leap_retry_remaining > 0.0
	):
		return false
	var distance := target_offset.length()
	if not mushroom.ai.roll_approach_leap(
		distance, mushroom.approach_leap_trigger_distance, mushroom.approach_leap_chance
	):
		_chase_leap_retry_remaining = CHASE_LEAP_RETRY_SECONDS
		return false
	var leap_distance := minf(
		mushroom.approach_leap_distance_meters,
		distance - mushroom.attack_range - APPROACH_LEAP_LANDING_BUFFER_METERS
	)
	if leap_distance <= 0.0:
		_chase_leap_retry_remaining = CHASE_LEAP_RETRY_SECONDS
		return false
	if not mushroom.start_approach_leap(target_offset.normalized(), leap_distance):
		_chase_leap_retry_remaining = CHASE_LEAP_RETRY_SECONDS
		return false
	_chase_leap_cooldown_remaining = mushroom.approach_leap_cooldown_seconds
	_set_phase(Phase.CHASE_LEAP, mushroom.approach_leap_duration_seconds)
	return true


func _charge(mushroom: MushroomEnemy, delta: float, _detected: bool) -> void:
	mushroom.stop_movement(delta)
	var duration := maxf(0.05, _active_charge_duration)
	var progress := 1.0 - _remaining / duration
	mushroom.update_charge_feedback(clampf(progress, 0.0, 1.0))
	if _remaining > 0.0:
		return
	var released := mushroom.release_cloud()
	_reset_charge()
	if released:
		mushroom.play_directional_animation(&"spore_release", true)
		_set_phase(Phase.RECOVER, mushroom.recovery_seconds)
	elif _detected:
		_set_phase(Phase.CHASE, 0.0)
	else:
		_set_phase(Phase.SEARCH, mushroom.search_seconds)


func _search(mushroom: MushroomEnemy, delta: float, detected: bool) -> void:
	if detected:
		_set_phase(Phase.CHASE, 0.0)
		return
	var offset := _horizontal(_last_seen - mushroom.global_position)
	if _remaining <= 0.0:
		_has_awakened = false
		_set_phase(Phase.DISGUISE, _random_disguise_seconds(mushroom))
	elif offset.length() > ARRIVAL_DISTANCE:
		_move_safely(mushroom, offset.normalized(), delta, mushroom.wander_speed_scale)
	else:
		_idle(mushroom, delta, &"idle")


func _move_safely(mushroom: MushroomEnemy, direction: Vector3, delta: float, speed: float) -> bool:
	for angle in [0.0, AVOID_ANGLE * _strafe_sign, -AVOID_ANGLE * _strafe_sign]:
		var candidate := direction.rotated(Vector3.UP, angle)
		mushroom.face_direction(candidate)
		mushroom._refresh_direction_checks()
		if not mushroom.is_front_blocked() and mushroom.is_ground_ahead():
			mushroom.move_in_direction(candidate, delta, speed)
			mushroom.play_directional_animation(&"walk")
			return true
	mushroom.stop_movement(delta)
	mushroom.play_directional_animation(&"idle")
	return false


func _idle(mushroom: MushroomEnemy, delta: float, animation: StringName) -> void:
	mushroom.stop_movement(delta)
	mushroom.play_directional_animation(animation)


func _try_start_close_charge(mushroom: MushroomEnemy, delta: float) -> bool:
	if mushroom.attack_cooldown_remaining > 0.0 or mushroom.is_inside_poison_cloud():
		return false
	if _distance_to_target_xz(mushroom) > mushroom.attack_range:
		return false
	mushroom.face_target()
	_begin_charge(mushroom, delta)
	return true


func _try_roll_random_chase_charge(mushroom: MushroomEnemy, delta: float) -> bool:
	if _chase_spore_check_remaining > 0.0:
		return false
	_reset_chase_spore_timer()
	if mushroom.attack_cooldown_remaining > 0.0 or mushroom.is_inside_poison_cloud():
		return false
	if mushroom.is_point_in_poison_cloud(mushroom.target.global_position):
		return false
	var cadence := mushroom.get_attack_cadence()
	var effective_chance := float(cadence.get("chase_chance", mushroom.chase_spore_chance))
	if mushroom.ai != null and mushroom.ai.roll_chase_spore(effective_chance):
		mushroom.face_target()
		_begin_charge(mushroom, delta)
		return true
	return false


func _begin_charge(mushroom: MushroomEnemy, delta: float, duration_override: float = -1.0) -> void:
	mushroom.stop_movement(delta)
	var base_charge := float(
		mushroom.get_attack_cadence().get("charge", mushroom.charge_duration_seconds)
	)
	_active_charge_duration = duration_override if duration_override > 0.0 else base_charge
	_set_phase(Phase.CHARGE, _active_charge_duration)
	mushroom.begin_charge_animation(_active_charge_duration)
	_reset_chase_spore_timer()


func _random_disguise_seconds(mushroom: MushroomEnemy) -> float:
	var low := minf(mushroom.disguise_min_seconds, mushroom.disguise_max_seconds)
	var high := maxf(mushroom.disguise_min_seconds, mushroom.disguise_max_seconds)
	return _random.randf_range(low, high)


func _random_wander_seconds(mushroom: MushroomEnemy) -> float:
	var low := minf(mushroom.wander_min_seconds, mushroom.wander_max_seconds)
	var high := maxf(mushroom.wander_min_seconds, mushroom.wander_max_seconds)
	return _random.randf_range(low, high)


func _reset_chase_spore_timer() -> void:
	var mushroom := enemy as MushroomEnemy
	if mushroom == null:
		return
	_chase_spore_check_remaining = float(
		mushroom.get_attack_cadence().get("chase_interval", mushroom.chase_spore_interval_seconds)
	)


func _reset_charge() -> void:
	var mushroom := enemy as MushroomEnemy
	if mushroom != null:
		mushroom.cancel_spore_charge()


func _on_damaged(_applied_hp: float) -> void:
	_has_awakened = true
	_ambush_reset()
	if _phase == Phase.DISGUISE or _phase == Phase.WANDER:
		var mushroom := enemy as MushroomEnemy
		if mushroom != null and _target_is_detected(mushroom):
			_set_phase(Phase.CHASE, 0.0)
		elif mushroom != null:
			_set_phase(Phase.SEARCH, mushroom.search_seconds)


func _horizontal(value: Vector3) -> Vector3:
	return Vector3(value.x, 0.0, value.z)


func _distance_to_target_xz(mushroom: MushroomEnemy) -> float:
	if not mushroom.has_target():
		return INF
	return _horizontal(mushroom.target.global_position - mushroom.global_position).length()


func _target_is_detected(mushroom: MushroomEnemy) -> bool:
	if not mushroom.has_target():
		return false
	var offset := _horizontal(mushroom.target.global_position - mushroom.global_position)
	return offset.length_squared() <= mushroom.detection_radius * mushroom.detection_radius
