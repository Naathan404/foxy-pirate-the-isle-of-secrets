extends EnemyState

var remaining := 0.0
var pausing := true
var direction := Vector3.ZERO
var turn_sign := 1.0


func _enter() -> void:
	remaining = 0.0
	pausing = true
	turn_sign = 1.0 if randf() < 0.5 else -1.0


func _update(delta: float) -> void:
	var skeleton := enemy as CoralSkeleton
	if skeleton.has_target():
		request_state(&"chase")
		return
	if skeleton.distance_from_home() <= skeleton.home_tolerance:
		skeleton._set_horizontal_velocity(Vector3.ZERO)
		skeleton.face_direction(skeleton._get_initial_facing_direction())
		request_state(&"guard")
		return
	remaining -= maxf(0.0, delta)
	if remaining <= 0.0:
		pausing = not pausing
		if pausing:
			remaining = skeleton.return_pause_time
		else:
			var home := skeleton.home_position - skeleton.global_position
			home.y = 0.0
			turn_sign = -turn_sign
			var min_angle := minf(skeleton.return_min_turn_angle, skeleton.return_max_turn_angle)
			var max_angle := maxf(skeleton.return_min_turn_angle, skeleton.return_max_turn_angle)
			var angle := turn_sign * deg_to_rad(randf_range(min_angle, max_angle))
			direction = skeleton.choose_safe_direction(home.normalized().rotated(Vector3.UP, angle))
			remaining = minf(skeleton.return_segment_time, home.length() / maxf(0.1, skeleton.data.move_speed))
	if pausing or direction.is_zero_approx() or not skeleton.safe_direction(direction):
		skeleton._set_horizontal_velocity(Vector3.ZERO)
		skeleton.play_directional_animation(&"idle")
		if not pausing:
			remaining = 0.0
	else:
		skeleton.move_in_direction(direction, delta)
		skeleton.play_directional_animation(&"walk")
