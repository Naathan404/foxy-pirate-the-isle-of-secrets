class_name StarfishAttack
extends EnemyState

@export_range(0.0, 10.0, 0.1) var charge_multiplier: float = 3.0
@export_range(0.0, 5.0, 0.01, "suffix:s") var wind_up: float = 0.3
@export_range(0.01, 10.0, 0.01, "suffix:s") var charge_time: float = 0.9

var _charging: bool = false
var _charge_direction: Vector3 = Vector3.ZERO


func _enter() -> void:
	enemy.stop_movement()
	_charge_direction = _aim_at_target()
	enemy.face_direction(_charge_direction)
	enemy.play_directional_animation(&"attack", true)
	_charging = false
	timer = wind_up


func _exit() -> void:
	enemy._stop_contact_damage()


func _update(delta: float) -> void:
	if not _charging:
		enemy.stop_movement(delta)
		if update_timer(delta):
			_charging = true
			timer = charge_time
			enemy._start_contact_damage()
		return
	enemy.move_in_direction(_charge_direction, delta, charge_multiplier)
	if enemy.is_front_blocked() or not enemy.is_ground_ahead() or update_timer(delta):
		request_state(&"run")


func _aim_at_target() -> Vector3:
	if not enemy.has_target():
		return enemy.last_facing_direction
	var direction := enemy.target.global_position - enemy.global_position
	direction.y = 0.0
	if direction.is_zero_approx():
		return enemy.last_facing_direction
	return direction.normalized()
