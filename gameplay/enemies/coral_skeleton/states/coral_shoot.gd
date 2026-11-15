extends EnemyState

var delay := 0.0
var fired := 0
var finishing := false
var _active_shot_mode := CoralSkeleton.ShotMode.FAN
var _special_attack := false
var _telegraph_active := false


func _enter() -> void:
	var skeleton := enemy as CoralSkeleton
	skeleton._set_horizontal_velocity(Vector3.ZERO)
	skeleton.play_directional_animation(&"shoot", true)
	_special_attack = skeleton.is_special_attack_ready()
	_active_shot_mode = skeleton.choose_shot_mode()
	delay = skeleton.fire_delay
	fired = 0
	finishing = false
	_telegraph_active = false
	if _special_attack:
		var feedback := _get_feedback()
		if feedback != null:
			feedback.begin_telegraph()
			_telegraph_active = true


func _exit() -> void:
	_end_telegraph()


func _update(delta: float) -> void:
	var skeleton := enemy as CoralSkeleton
	if not skeleton.has_target():
		_end_telegraph()
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
	if _special_attack:
		_end_telegraph()
		skeleton.fire_special_attack()
		skeleton.notify_special_burst_completed()
		_finish(skeleton)
		return
	if _active_shot_mode == CoralSkeleton.ShotMode.FAN:
		skeleton.fire_fan()
		skeleton.notify_normal_burst_completed()
		_finish(skeleton)
		return
	while delay <= 0.0 and fired < maxi(1, skeleton.bullets_per_burst):
		skeleton.fire_bullet()
		fired += 1
		delay += maxf(0.01, skeleton.shot_interval)
	if fired >= maxi(1, skeleton.bullets_per_burst):
		skeleton.notify_normal_burst_completed()
		_finish(skeleton)


func _finish(skeleton: CoralSkeleton) -> void:
	skeleton.cooldown_remaining = skeleton.burst_cooldown
	finishing = true
	delay = skeleton.shoot_recovery_time


func _end_telegraph() -> void:
	if _telegraph_active:
		_telegraph_active = false
		var feedback := _get_feedback()
		if feedback != null:
			feedback.end_telegraph()


func _get_feedback() -> EliteFeedback:
	return enemy.get_node_or_null("EliteFeedback") as EliteFeedback
