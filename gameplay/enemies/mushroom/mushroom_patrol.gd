extends EnemyState
## Ambush, observe, pursue and reposition between spore attacks.

enum Phase { DISGUISE, WANDER, OBSERVE, CHASE, CHARGE, RECOVER, RETREAT, SEARCH }

const MIN_WANDER_SECONDS := 1.2
const MAX_WANDER_SECONDS := 2.8
const MIN_DISGUISE_SECONDS := 2.0
const MAX_DISGUISE_SECONDS := 4.5
const PURSUIT_BURST_SECONDS := 2.0
const SEARCH_SECONDS := 3.0
const ARRIVAL_DISTANCE := 0.6
const AVOID_ANGLE := PI / 3.0

var _phase: Phase = Phase.DISGUISE
var _remaining: float = 0.0
var _random := RandomNumberGenerator.new()
var _last_seen: Vector3
var _wander_direction: Vector3 = Vector3.ZERO
var _strafe_sign: float = 1.0
var _has_awakened: bool = false


func _enter() -> void:
	_random.randomize()
	if not enemy.damaged.is_connected(_on_damaged):
		enemy.damaged.connect(_on_damaged)
	if _has_awakened:
		_set_phase(Phase.OBSERVE, 0.5)
	else:
		_set_phase(Phase.DISGUISE, _random.randf_range(MIN_DISGUISE_SECONDS, MAX_DISGUISE_SECONDS))


func _exit() -> void:
	_reset_charge()
	if enemy.damaged.is_connected(_on_damaged):
		enemy.damaged.disconnect(_on_damaged)


func _update(delta: float) -> void:
	var mushroom := enemy as MushroomEnemy
	if mushroom == null:
		return
	var step := maxf(delta, 0.0)
	if mushroom.is_evading():
		mushroom.stop_movement(step)
		mushroom.play_directional_animation(&"walk")
		return
	_remaining = maxf(0.0, _remaining - step)
	if _target_is_detected(mushroom):
		_last_seen = mushroom.target.global_position
		_has_awakened = true
	elif _phase in [Phase.OBSERVE, Phase.CHASE, Phase.RETREAT]:
		_set_phase(Phase.SEARCH, SEARCH_SECONDS)
	match _phase:
		Phase.DISGUISE:
			_idle(mushroom, step, &"disguise")
			if _target_is_detected(mushroom):
				_set_phase(Phase.OBSERVE, mushroom.observe_seconds)
			elif _remaining <= 0.0:
				_begin_wander()
		Phase.WANDER:
			if _target_is_detected(mushroom):
				_set_phase(Phase.OBSERVE, mushroom.observe_seconds)
			elif _remaining <= 0.0:
				_set_phase(
					Phase.DISGUISE, _random.randf_range(MIN_DISGUISE_SECONDS, MAX_DISGUISE_SECONDS)
				)
			else:
				_wander(mushroom, step)
		Phase.OBSERVE:
			_idle(mushroom, step, &"idle")
			if _target_is_detected(mushroom):
				mushroom.face_target()
			if _remaining <= 0.0:
				_set_phase(Phase.CHASE, PURSUIT_BURST_SECONDS)
		Phase.CHASE:
			_chase(mushroom, step)
		Phase.CHARGE:
			_charge(mushroom, step)
		Phase.RECOVER:
			_idle(mushroom, step, &"spore_release")
			if _remaining <= 0.0:
				if _target_is_detected(mushroom):
					_set_phase(Phase.RETREAT, mushroom.retreat_seconds)
				else:
					_set_phase(Phase.DISGUISE, MIN_DISGUISE_SECONDS)
		Phase.RETREAT:
			_retreat(mushroom, step)
		Phase.SEARCH:
			_search(mushroom, step)


func _set_phase(phase: Phase, duration: float) -> void:
	_phase = phase
	_remaining = duration


func _begin_wander() -> void:
	var angle := _random.randf_range(0.0, TAU)
	_wander_direction = Vector3(cos(angle), 0.0, sin(angle))
	_set_phase(Phase.WANDER, _random.randf_range(MIN_WANDER_SECONDS, MAX_WANDER_SECONDS))


func _wander(mushroom: MushroomEnemy, delta: float) -> void:
	var from_home := mushroom.global_position - mushroom.home_position
	from_home.y = 0.0
	if from_home.length() >= mushroom.movement_radius:
		_wander_direction = -from_home.normalized()
	if not _move_safely(mushroom, _wander_direction, delta, mushroom.wander_speed_scale):
		_set_phase(Phase.DISGUISE, MIN_DISGUISE_SECONDS)


func _chase(mushroom: MushroomEnemy, delta: float) -> void:
	if not _target_is_detected(mushroom):
		_set_phase(Phase.SEARCH, SEARCH_SECONDS)
		return
	var from_home := _horizontal(mushroom.global_position - mushroom.home_position)
	if from_home.length() > mushroom.movement_radius:
		_move_safely(mushroom, -from_home.normalized(), delta, mushroom.wander_speed_scale)
		return
	var offset := _horizontal(mushroom.target.global_position - mushroom.global_position)
	var distance := offset.length()
	if distance <= mushroom.attack_range and mushroom.attack_cooldown_remaining <= 0.0:
		mushroom.face_target()
		_begin_charge(mushroom, delta)
		return
	if _remaining <= 0.0:
		_set_phase(Phase.OBSERVE, mushroom.observe_seconds)
		return
	if distance <= mushroom.attack_range and mushroom.attack_cooldown_remaining > 0.0:
		var sideways := Vector3(-offset.z, 0.0, offset.x).normalized() * _strafe_sign
		if not _move_safely(mushroom, sideways, delta, mushroom.wander_speed_scale):
			_strafe_sign *= -1.0
	else:
		_move_safely(mushroom, offset.normalized(), delta, mushroom.chase_speed_scale)


func _charge(mushroom: MushroomEnemy, delta: float) -> void:
	mushroom.stop_movement(delta)
	if not _target_is_detected(mushroom):
		_reset_charge()
		_set_phase(Phase.SEARCH, SEARCH_SECONDS)
		return
	var progress := 1.0 - _remaining / mushroom.windup_seconds
	mushroom.update_charge_feedback(clampf(progress, 0.0, 1.0))
	if _remaining > 0.0:
		return
	mushroom.release_cloud()
	_reset_charge()
	mushroom.play_directional_animation(&"spore_release", true)
	_set_phase(Phase.RECOVER, mushroom.recovery_seconds)


func _retreat(mushroom: MushroomEnemy, delta: float) -> void:
	if _remaining <= 0.0:
		_strafe_sign = -1.0 if _random.randi_range(0, 1) == 0 else 1.0
		_set_phase(Phase.OBSERVE, mushroom.observe_seconds)
		return
	var away := _horizontal(mushroom.global_position - _last_seen).normalized()
	if (
		away.is_zero_approx()
		or not _move_safely(mushroom, away, delta, mushroom.retreat_speed_scale)
	):
		_idle(mushroom, delta, &"idle")


func _search(mushroom: MushroomEnemy, delta: float) -> void:
	if _target_is_detected(mushroom):
		_set_phase(Phase.OBSERVE, mushroom.observe_seconds)
		return
	var offset := _horizontal(_last_seen - mushroom.global_position)
	if _remaining <= 0.0:
		_has_awakened = false
		_set_phase(Phase.DISGUISE, _random.randf_range(MIN_DISGUISE_SECONDS, MAX_DISGUISE_SECONDS))
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
	mushroom.play_directional_animation(&"disguise")
	return false


func _idle(mushroom: MushroomEnemy, delta: float, animation: StringName) -> void:
	mushroom.stop_movement(delta)
	mushroom.play_directional_animation(&"disguise" if animation == &"idle" else animation)


func _begin_charge(mushroom: MushroomEnemy, delta: float) -> void:
	mushroom.stop_movement(delta)
	_set_phase(Phase.CHARGE, mushroom.windup_seconds)
	mushroom.begin_charge_animation()


func _reset_charge() -> void:
	var mushroom := enemy as MushroomEnemy
	if mushroom != null:
		mushroom.visual.animation_player.speed_scale = 1.0
		mushroom.cancel_spore_charge()


func _on_damaged(_applied_hp: float) -> void:
	_has_awakened = true
	if _phase == Phase.CHARGE:
		var mushroom := enemy as MushroomEnemy
		_reset_charge()
		mushroom.attack_cooldown_remaining = mushroom.cooldown_seconds
		if not mushroom.hp.is_alive():
			return
		mushroom.play_directional_animation(&"disguise", true)
		if _target_is_detected(mushroom):
			_set_phase(Phase.OBSERVE, mushroom.observe_seconds)
		else:
			_set_phase(Phase.DISGUISE, MIN_DISGUISE_SECONDS)
		return
	if _phase == Phase.DISGUISE or _phase == Phase.WANDER:
		_set_phase(Phase.OBSERVE, 0.5)


func _horizontal(value: Vector3) -> Vector3:
	return Vector3(value.x, 0.0, value.z)


func _target_is_detected(mushroom: MushroomEnemy) -> bool:
	if not mushroom.has_target():
		return false
	var offset := _horizontal(mushroom.target.global_position - mushroom.global_position)
	return offset.length_squared() <= mushroom.detection_radius * mushroom.detection_radius
