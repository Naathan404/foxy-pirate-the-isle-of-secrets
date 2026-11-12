extends EnemyState


func _enter() -> void:
	var skeleton := enemy as CoralSkeleton
	# Shared Hit state returns to the default state. Resume the awake behavior
	# after a stagger instead of putting an alert skeleton back to sleep.
	if skeleton.is_awake:
		if skeleton.has_target():
			request_state(&"chase")
		elif skeleton.distance_from_home() > skeleton.home_tolerance:
			request_state(&"return")
		else:
			request_state(&"guard")
		return
	skeleton._set_horizontal_velocity(Vector3.ZERO)
	skeleton.face_direction(skeleton._get_initial_facing_direction())
	skeleton.play_directional_animation(&"sleep", true)


func _update(_delta: float) -> void:
	var skeleton := enemy as CoralSkeleton
	if skeleton.has_target():
		if skeleton.is_awake:
			request_state(&"chase")
		else:
			request_state(&"wake")
