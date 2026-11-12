extends EnemyState

var sleep_remaining := 0.0


func _enter() -> void:
	var skeleton := enemy as CoralSkeleton
	enemy._set_horizontal_velocity(Vector3.ZERO)
	if not skeleton.has_target() and skeleton.distance_from_home() <= skeleton.home_tolerance:
		skeleton.face_direction(skeleton._get_initial_facing_direction())
	sleep_remaining = skeleton.sleep_delay
	enemy.play_directional_animation(&"idle")


func _update(delta: float) -> void:
	var skeleton := enemy as CoralSkeleton
	if skeleton.has_target():
		request_state(&"chase")
	elif skeleton.distance_from_home() > skeleton.home_tolerance:
		request_state(&"return")
	else:
		sleep_remaining = maxf(0.0, sleep_remaining - maxf(0.0, delta))
		if sleep_remaining <= 0.0:
			skeleton.set_awake(false)
			request_state(&"sleep")
