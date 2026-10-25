extends EnemyState

@export var recovery_animation: StringName = &"idle"

var _is_recovering: bool = false
var _recovery_remaining: float = 0.0


func _enter() -> void:
	timer = enemy.data.hit_duration if enemy.data != null else 0.0
	timer = maxf(timer, enemy.pending_charm_stun_seconds)
	enemy.pending_charm_stun_seconds = 0.0
	_is_recovering = false
	_recovery_remaining = enemy.data.hit_recovery_duration if enemy.data != null else 0.0
	enemy.end_active_attack()
	enemy._stop_contact_damage()
	enemy.play_directional_animation(&"hit", true)
	if is_instance_valid(enemy.visual):
		enemy.visual.play_hit_feedback()
	_apply_recoil()


func _update(delta: float) -> void:
	if _is_recovering:
		enemy._set_horizontal_velocity(Vector3.ZERO)
		_recovery_remaining = maxf(0.0, _recovery_remaining - maxf(0.0, delta))
		if _recovery_remaining <= 0.0:
			return_to_behavior()
		return
	if enemy.data != null:
		enemy._damp_horizontal_velocity(delta, enemy.data.hit_deceleration)
	if update_timer(delta):
		_begin_recovery()


func _begin_recovery() -> void:
	_is_recovering = true
	enemy._set_horizontal_velocity(Vector3.ZERO)
	if not recovery_animation.is_empty():
		enemy.play_directional_animation(recovery_animation, true)


func _apply_recoil() -> void:
	if enemy.data == null:
		return
	var direction := enemy.pending_hit_direction
	if direction.is_zero_approx():
		direction = -enemy.last_facing_direction
	enemy._set_horizontal_velocity(direction.normalized() * enemy.data.hit_knockback_speed)
