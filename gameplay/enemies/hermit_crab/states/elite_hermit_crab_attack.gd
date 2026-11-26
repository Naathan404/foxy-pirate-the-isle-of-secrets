class_name EliteHermitCrabAttack
extends EnemyState

## One wind-up, three consecutive aimed dashes, then stun. Solid walls and ledges
## interrupt the burst, while props and other enemies are swept out of the way.
enum AttackPhase { PREPARE, CHARGE, DASH, IMPACT, STUN }

@export_range(1, 6, 1) var dash_count: int = 3
@export_range(0.05, 3.0, 0.01, "suffix:s") var preparation_duration: float = 0.6
@export_range(0.05, 3.0, 0.01, "suffix:s") var telegraph_duration: float = 0.35
@export_range(0.1, 10.0, 0.1) var dash_speed_multiplier: float = 3.8
## Minimum safety timeout. The actual timeout expands for distant locked targets.
@export_range(0.05, 3.0, 0.01, "suffix:s") var dash_duration: float = 0.55
@export_range(0.1, 3.0, 0.01, "suffix:m") var arrival_distance: float = 0.25
@export_range(0.5, 10.0, 0.1, "suffix:m") var minimum_dash_distance_meters: float = 2.5

var _phase: AttackPhase = AttackPhase.PREPARE
var _dash_index: int = 0
var _locked_target_position: Vector3 = Vector3.ZERO
var _dash_unreachable := false
var _dash_direction := Vector3.BACK


func _enter() -> void:
	_dash_index = 0
	_dash_direction = enemy.last_facing_direction
	_begin_dash_cycle()


func _exit() -> void:
	enemy._stop_contact_damage()
	(enemy as EliteHermitCrab).end_dash_collision()
	_get_feedback().end_telegraph()


func _update(delta: float) -> void:
	match _phase:
		AttackPhase.PREPARE:
			_update_prepare(delta)
		AttackPhase.CHARGE:
			_update_charge(delta)
		AttackPhase.DASH:
			_update_dash(delta)
		AttackPhase.IMPACT:
			enemy._set_horizontal_velocity(Vector3.ZERO)
			if _timer_finished(delta):
				_begin_stun()
		AttackPhase.STUN:
			enemy._set_horizontal_velocity(Vector3.ZERO)
			if _timer_finished(delta):
				_finish_recovery()


func _begin_dash_cycle() -> void:
	_dash_unreachable = false
	if not enemy.has_target():
		_return_to_patrol()
		return
	_locked_target_position = enemy.target.global_position
	_locked_target_position.y = enemy.global_position.y
	_phase = AttackPhase.PREPARE
	timer = preparation_duration
	enemy.stop_movement()
	enemy.play_directional_animation(&"idle", true)
	_get_feedback().begin_telegraph()


func _update_prepare(delta: float) -> void:
	enemy.stop_movement(delta)
	if _timer_finished(delta):
		enemy.face_direction(_locked_target_position - enemy.global_position)
		_phase = AttackPhase.CHARGE
		timer = telegraph_duration
		enemy.play_directional_animation(&"charge", true)


func _update_charge(delta: float) -> void:
	enemy.stop_movement(delta)
	if _timer_finished(delta):
		_get_feedback().end_telegraph()
		_start_dash()


func _start_dash() -> void:
	var offset := _locked_target_position - enemy.global_position
	offset.y = 0.0
	if enemy.has_target():
		offset = enemy.target.global_position - enemy.global_position
		offset.y = 0.0
	if not offset.is_zero_approx():
		_dash_direction = offset.normalized()
	_locked_target_position = (
		enemy.global_position
		+ _dash_direction * maxf(offset.length(), minimum_dash_distance_meters)
	)
	enemy.face_direction(_dash_direction)
	enemy._refresh_direction_checks()
	if _dash_index > 0:
		# Turn the existing speed into the next leg instead of braking through the target.
		var speed := Vector2(enemy.velocity.x, enemy.velocity.z).length()
		enemy._set_horizontal_velocity(_dash_direction * speed)
	_phase = AttackPhase.DASH
	timer = _get_dash_timeout()
	(enemy as EliteHermitCrab).begin_dash_collision()
	enemy.play_directional_animation(&"attack", true)
	enemy._start_contact_damage()


func _update_dash(delta: float) -> void:
	var speed := enemy.data.move_speed * dash_speed_multiplier
	(enemy as EliteHermitCrab).clear_dash_path(_dash_direction, speed * maxf(delta, 0.0))
	enemy.contact_hitbox.sample_shape()
	if enemy.is_front_blocked():
		_finish_dash(true, true)
		return
	var direction := _locked_target_position - enemy.global_position
	direction.y = 0.0
	if direction.dot(_dash_direction) <= arrival_distance or _timer_finished(delta):
		_finish_dash()
		return
	if not enemy.is_ground_ahead():
		_finish_dash(false, true)
		return
	enemy.move_in_direction(_dash_direction, delta, dash_speed_multiplier)


func _finish_dash(impact: bool = false, unreachable: bool = false) -> void:
	enemy._stop_contact_damage()
	_dash_unreachable = unreachable
	_dash_index += 1
	if _dash_index < dash_count and not unreachable:
		_start_dash()
		return
	enemy.stop_movement()
	enemy._set_horizontal_velocity(Vector3.ZERO)
	(enemy as EliteHermitCrab).end_dash_collision()
	if impact:
		_phase = AttackPhase.IMPACT
		timer = (enemy as HermitCrab).dash_impact_duration_seconds
		enemy.play_directional_animation(&"hit", true)
	else:
		_begin_stun()


func _begin_stun() -> void:
	_phase = AttackPhase.STUN
	timer = (enemy as HermitCrab).dash_stun_duration_seconds
	enemy.play_directional_animation(&"stun", true)


func _finish_recovery() -> void:
	if _dash_unreachable:
		_abandon_dash()
		return
	_return_to_patrol()


func _return_to_patrol() -> void:
	request_state(&"patrol")


func _abandon_dash() -> void:
	enemy._stop_contact_damage()
	enemy.stop_movement()
	enemy.turn_around()
	var patrol := get_node_or_null("../Patrol") as HermitCrabPatrol
	if patrol != null:
		patrol.start_unreachable_target_cooldown()
	request_state(&"patrol")


func _timer_finished(delta: float) -> bool:
	return timer <= 0.0 or update_timer(delta)


func _get_dash_timeout() -> float:
	var offset := _locked_target_position - enemy.global_position
	offset.y = 0.0
	var distance := offset.length()
	var max_speed := 0.0
	if enemy.data != null:
		max_speed = enemy.data.move_speed * dash_speed_multiplier
	# The extra time covers acceleration from rest. A fixed 0.55 s cutoff stopped
	# distant dashes before they reached the position locked during telegraph.
	var travel_time := distance / maxf(0.01, max_speed) + 0.4
	return maxf(dash_duration, travel_time)


func _get_feedback() -> EliteFeedback:
	return enemy.get_node_or_null("EliteFeedback") as EliteFeedback
