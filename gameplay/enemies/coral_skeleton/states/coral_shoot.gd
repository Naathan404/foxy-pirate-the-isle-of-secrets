extends EnemyState

var delay := 0.0
var fired := 0
var finishing := false


func _enter() -> void:
	var skeleton := enemy as CoralSkeleton
	skeleton._set_horizontal_velocity(Vector3.ZERO)
	skeleton.play_directional_animation(&"shoot", true)
	delay = skeleton.fire_delay
	fired = 0
	finishing = false


func _update(delta: float) -> void:
	var skeleton := enemy as CoralSkeleton
	if not skeleton.has_target():
		request_state(&"return")
		return
	skeleton._set_horizontal_velocity(Vector3.ZERO)
	skeleton.face_target()
	delay -= maxf(0.0, delta)
	if delay > 0.0:
		return
	if finishing:
		request_state(&"chase")
		return
	if skeleton.shot_mode == CoralSkeleton.ShotMode.FAN:
		skeleton.fire_fan()
		_finish(skeleton)
		return
	while delay <= 0.0 and fired < maxi(1, skeleton.bullets_per_burst):
		skeleton.fire_bullet()
		fired += 1
		delay += maxf(0.01, skeleton.shot_interval)
	if fired >= maxi(1, skeleton.bullets_per_burst):
		_finish(skeleton)


func _finish(skeleton: CoralSkeleton) -> void:
	skeleton.cooldown_remaining = skeleton.burst_cooldown
	finishing = true
	delay = skeleton.shoot_recovery_time
