extends EnemyState

var remaining := 0.0


func _enter() -> void:
	var skeleton := enemy as CoralSkeleton
	skeleton.set_awake(true)
	skeleton._set_horizontal_velocity(Vector3.ZERO)
	skeleton.face_target()
	skeleton.play_directional_animation(&"idle", true)
	remaining = skeleton.wake_duration
	# The attack timer continues through pursuit and stagger, even if the target
	# temporarily leaves before the waking animation finishes.
	skeleton.cooldown_remaining = maxf(
		skeleton.cooldown_remaining, skeleton.wake_duration + skeleton.wake_attack_delay
	)


func _update(delta: float) -> void:
	var skeleton := enemy as CoralSkeleton
	if not skeleton.has_target():
		if skeleton.distance_from_home() > skeleton.home_tolerance:
			request_state(&"return")
		else:
			request_state(&"guard")
		return
	skeleton.face_target()
	remaining = maxf(0.0, remaining - maxf(0.0, delta))
	if remaining <= 0.0:
		request_state(&"chase")
