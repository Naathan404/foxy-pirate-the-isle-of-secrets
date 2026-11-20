extends EnemyState

var sleep_remaining := 0.0
var _roam_remaining := 0.0
var _roam_pausing := true
var _roam_direction := Vector3.ZERO


func _enter() -> void:
	var skeleton := enemy as CoralSkeleton
	enemy._set_horizontal_velocity(Vector3.ZERO)
	if not skeleton.has_target() and skeleton.distance_from_home() <= skeleton.home_tolerance:
		skeleton.face_direction(skeleton._get_initial_facing_direction())
	sleep_remaining = skeleton.sleep_delay
	_roam_remaining = 0.0
	_roam_pausing = not skeleton.roam_when_guarding
	_roam_direction = Vector3.ZERO
	enemy.play_directional_animation(&"idle")


func _update(delta: float) -> void:
	var skeleton := enemy as CoralSkeleton
	if skeleton.has_target():
		request_state(&"chase")
		return
	if not skeleton.roam_when_guarding and skeleton.distance_from_home() > skeleton.home_tolerance:
		request_state(&"return")
		return
	if skeleton.can_sleep:
		sleep_remaining = maxf(0.0, sleep_remaining - maxf(0.0, delta))
		if sleep_remaining <= 0.0:
			skeleton.set_awake(false)
			request_state(&"sleep")
			return
	if skeleton.roam_when_guarding:
		_update_roam(skeleton, delta)


func _update_roam(skeleton: CoralSkeleton, delta: float) -> void:
	_roam_remaining -= maxf(0.0, delta)
	if _roam_remaining <= 0.0:
		_roam_pausing = not _roam_pausing
		if _roam_pausing:
			_roam_remaining = skeleton.guard_roam_pause_time
		else:
			var preferred := Vector3.FORWARD.rotated(Vector3.UP, randf_range(0.0, TAU))
			if skeleton.distance_from_home() > skeleton.guard_roam_radius:
				var home := skeleton.home_position - skeleton.global_position
				home.y = 0.0
				if not home.is_zero_approx():
					preferred = home.normalized().rotated(
						Vector3.UP, deg_to_rad(randf_range(-35.0, 35.0))
					)
			_roam_direction = skeleton.choose_safe_direction(preferred)
			_roam_remaining = skeleton.guard_roam_segment_time
	var blocked := _roam_direction.is_zero_approx() or not skeleton.safe_direction(_roam_direction)
	if _roam_pausing or blocked:
		skeleton._set_horizontal_velocity(Vector3.ZERO)
		skeleton.play_directional_animation(&"idle")
		if not _roam_pausing:
			_roam_remaining = 0.0
	else:
		skeleton.move_in_direction(_roam_direction, delta)
		skeleton.play_directional_animation(&"walk")
