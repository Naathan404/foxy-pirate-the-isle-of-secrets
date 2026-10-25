class_name StarfishAttack
extends EnemyState

enum AttackPhase {
	IDLE,
	CHARGE,
	DASH,
}

@export_group("Attack Cycle")
@export_range(0.0, 10.0, 0.01, "suffix:s") var idle_duration: float = 0.6
@export_range(0.0, 5.0, 0.01, "suffix:s") var wind_up: float = 0.3
@export_range(0.0, 10.0, 0.1) var dash_speed_multiplier: float = 3.0
@export_range(0.0, 2.0, 0.01, "suffix:m") var target_arrival_distance: float = 0.1

var _phase: AttackPhase = AttackPhase.IDLE
var _locked_target_position: Vector3 = Vector3.ZERO
var _patrol_direction: Vector3 = Vector3.BACK


func _enter() -> void:
	_patrol_direction = enemy.last_facing_direction
	_begin_attack_cycle()


func _exit() -> void:
	enemy._stop_contact_damage()
	if is_instance_valid(enemy.hurtbox) and not enemy.dead:
		enemy.hurtbox.enabled = true
	if not _patrol_direction.is_zero_approx():
		enemy.face_direction(_patrol_direction)


func _update(delta: float) -> void:
	match _phase:
		AttackPhase.IDLE:
			_update_idle(delta)
		AttackPhase.CHARGE:
			_update_charge(delta)
		AttackPhase.DASH:
			_update_dash(delta)


func _begin_idle() -> void:
	_phase = AttackPhase.IDLE
	timer = idle_duration
	enemy.stop_movement()
	enemy.play_directional_animation(&"idle", true)


func _begin_attack_cycle() -> void:
	_locked_target_position = Vector3.ZERO
	if not enemy.has_target():
		_return_to_patrol()
		return
	_locked_target_position = enemy.target.global_position
	_locked_target_position.y = enemy.global_position.y
	_begin_idle()


func _update_idle(delta: float) -> void:
	enemy.stop_movement(delta)
	if not _timer_finished(delta):
		return
	var direction := _locked_target_position - enemy.global_position
	direction.y = 0.0
	if direction.is_zero_approx():
		_return_to_patrol()
		return
	enemy.face_direction(direction)
	_phase = AttackPhase.CHARGE
	timer = wind_up
	enemy.play_directional_animation(&"charge", true)


func _update_charge(delta: float) -> void:
	enemy.stop_movement(delta)
	if not _timer_finished(delta):
		return
	_phase = AttackPhase.DASH
	if is_instance_valid(enemy.hurtbox):
		enemy.hurtbox.enabled = false
	enemy.play_directional_animation(&"attack", true)
	enemy._start_contact_damage()


func _update_dash(delta: float) -> void:
	var direction := _locked_target_position - enemy.global_position
	direction.y = 0.0
	if direction.length() <= target_arrival_distance:
		_finish_dash()
		return
	enemy.move_in_direction(direction, delta, dash_speed_multiplier)
	if enemy.is_front_blocked() or not enemy.is_ground_ahead():
		_finish_dash()


func _finish_dash() -> void:
	enemy._stop_contact_damage()
	if is_instance_valid(enemy.hurtbox):
		enemy.hurtbox.enabled = true
	enemy.stop_movement()
	if enemy.has_target():
		_begin_attack_cycle()
		return
	_locked_target_position = Vector3.ZERO
	_return_to_patrol()


func _return_to_patrol() -> void:
	request_state(&"patrol")


func _timer_finished(delta: float) -> bool:
	return timer <= 0.0 or update_timer(delta)
