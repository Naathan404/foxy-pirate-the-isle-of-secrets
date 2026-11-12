extends EnemyState


func _update(delta: float) -> void:
	var skeleton := enemy as CoralSkeleton
	if not skeleton.has_target():
		request_state(&"return")
		return
	var offset := skeleton.target.global_position - skeleton.global_position
	offset.y = 0.0
	if offset.length() <= skeleton.shooting_range:
		skeleton._set_horizontal_velocity(Vector3.ZERO)
		skeleton.face_direction(offset)
		skeleton.play_directional_animation(&"idle")
		if skeleton.cooldown_remaining <= 0.0:
			request_state(&"shoot")
		return
	var direction := skeleton.choose_safe_direction(offset.normalized())
	if direction.is_zero_approx():
		skeleton._set_horizontal_velocity(Vector3.ZERO)
		skeleton.play_directional_animation(&"idle")
	else:
		skeleton.move_in_direction(direction, delta)
		skeleton.play_directional_animation(&"walk")
