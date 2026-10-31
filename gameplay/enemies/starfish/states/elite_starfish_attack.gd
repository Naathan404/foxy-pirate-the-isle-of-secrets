class_name EliteStarfishAttack
extends EnemyState

## Keep the same visual combat cadence as StarfishAttack:
## idle preparation -> charge wind-up -> attack dash.
## Elite behavior repeats that cadence for each of its three dashes.
enum AttackPhase { PREPARE, CHARGE, DASH, RECOVER }

@export_range(1, 6, 1) var dash_count: int = 3
@export_range(0.05, 3.0, 0.01, "suffix:s") var preparation_duration: float = 0.6
@export_range(0.05, 3.0, 0.01, "suffix:s") var telegraph_duration: float = 0.35
@export_range(0.1, 10.0, 0.1) var dash_speed_multiplier: float = 3.8
## Minimum safety timeout. The actual timeout expands for distant locked targets.
@export_range(0.05, 3.0, 0.01, "suffix:s") var dash_duration: float = 0.55
@export_range(0.05, 3.0, 0.01, "suffix:s") var recovery_duration: float = 0.5
@export_range(0.1, 3.0, 0.01, "suffix:m") var arrival_distance: float = 0.25

var _phase: AttackPhase = AttackPhase.PREPARE
var _dash_index: int = 0
var _locked_target_position: Vector3 = Vector3.ZERO


func _enter() -> void:
	_dash_index = 0
	_begin_dash_cycle()


func _exit() -> void:
	enemy._stop_contact_damage()
	_get_feedback().end_telegraph()


func _update(delta: float) -> void:
	match _phase:
		AttackPhase.PREPARE:
			_update_prepare(delta)
		AttackPhase.CHARGE:
			_update_charge(delta)
		AttackPhase.DASH:
			_update_dash(delta)
		AttackPhase.RECOVER:
			_update_recover(delta)


func _begin_dash_cycle() -> void:
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
		_phase = AttackPhase.DASH
		timer = _get_dash_timeout()
		enemy.play_directional_animation(&"attack", true)
		enemy._start_contact_damage()
		_get_feedback().end_telegraph()


func _update_dash(delta: float) -> void:
	var direction := _locked_target_position - enemy.global_position
	direction.y = 0.0
	if direction.length() <= arrival_distance or _timer_finished(delta):
		_finish_dash()
		return
	if enemy.is_front_blocked() or not enemy.is_ground_ahead():
		_abandon_dash()
		return
	enemy.move_in_direction(direction, delta, dash_speed_multiplier)


func _finish_dash() -> void:
	enemy._stop_contact_damage()
	enemy.stop_movement()
	_dash_index += 1
	if _dash_index < dash_count and enemy.has_target():
		_begin_dash_cycle()
		return
	_phase = AttackPhase.RECOVER
	timer = recovery_duration
	enemy.play_directional_animation(&"idle", true)


func _update_recover(delta: float) -> void:
	enemy.stop_movement(delta)
	if _timer_finished(delta):
		_return_to_patrol()


func _return_to_patrol() -> void:
	request_state(&"patrol")


func _abandon_dash() -> void:
	enemy._stop_contact_damage()
	enemy.stop_movement()
	enemy.turn_around()
	var patrol := get_node_or_null("../Patrol") as StarfishPatrol
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
