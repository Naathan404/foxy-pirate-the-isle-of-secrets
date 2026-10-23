extends EnemyState


func _enter() -> void:
	timer = enemy.pending_hit_duration
	enemy.end_attack()
	enemy.play_directional_animation(&"hit", true)
	if is_instance_valid(enemy.visual):
		enemy.visual.play_hit_feedback()
	if enemy.data != null:
		enemy._set_horizontal_velocity(enemy.pending_hit_direction * enemy.data.hit_knockback_speed)


func _update(delta: float) -> void:
	if enemy.data != null:
		enemy._damp_horizontal_velocity(delta, enemy.data.hit_deceleration)
	if update_timer(delta):
		return_to_behavior()
