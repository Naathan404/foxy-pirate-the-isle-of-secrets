extends EnemyState
## Trạng thái phản ứng thoát thân đa dạng khi bị đánh trúng dưới đất:
## - SWIFT_ESCAPE: giật mình nhảy né rồi bay vút đi luôn (không gây sát thương).
## - POLLEN_VENT_ESCAPE: co bụng xì ra luồng phấn nhỏ (có trễ sát thương để kịp né) rồi bay đi.
## - GALE_PULSE_ESCAPE: báo sáng 0.5s rồi vỗ cánh đẩy nhẹ khoảng cách & bay lên.

var _elapsed_seconds: float = 0.0
var _released: bool = false
var _windup_seconds: float = 0.18
var _evade_dir: Vector3 = Vector3.BACK


func _enter() -> void:
	var firefly := enemy as FireflyEnemy
	if firefly == null:
		return
	_elapsed_seconds = 0.0
	_released = false
	_windup_seconds = maxf(0.1, firefly.pending_reaction_windup_seconds)
	firefly.exhausted_remaining_seconds = 0.0
	firefly.set_altitude_meters(0.0)
	firefly.stop_movement(1.0)
	firefly.face_target()
	_evade_dir = _compute_evade_dir(firefly)

	match firefly.current_reaction_kind:
		FireflyEnemy.GroundReactionKind.SWIFT_ESCAPE:
			firefly.set_glow_mode(1)
			firefly.set_air_charge_telegraph(false, 0.0)
			firefly.play_firefly_animation(&"rest_alert", false, true)
		FireflyEnemy.GroundReactionKind.POLLEN_VENT_ESCAPE:
			firefly.set_glow_mode(1)
			firefly.set_air_charge_telegraph(false, 0.0)
			firefly.play_firefly_animation(&"rest_alert", false, true)
		FireflyEnemy.GroundReactionKind.GALE_PULSE_ESCAPE:
			firefly.set_glow_mode(2, 0.3)
			firefly.set_air_charge_telegraph(true, 0.3)
			firefly.play_firefly_animation(&"rest_alert", false, true)


func _exit() -> void:
	var firefly := enemy as FireflyEnemy
	if firefly != null:
		firefly.set_air_charge_telegraph(false, 0.0)
		if is_instance_valid(firefly.visual):
			firefly.visual.scale = Vector3.ONE


func _update(delta: float) -> void:
	var firefly := enemy as FireflyEnemy
	if firefly == null or firefly.dead or _released:
		return
	var step := maxf(0.0, delta)
	_elapsed_seconds += step
	var progress := clampf(_elapsed_seconds / _windup_seconds, 0.0, 1.0)

	match firefly.current_reaction_kind:
		FireflyEnemy.GroundReactionKind.SWIFT_ESCAPE:
			firefly.move_in_direction(_evade_dir, step, 0.72)
			if is_instance_valid(firefly.visual):
				var hop := sin(progress * PI) * 0.14
				firefly.visual.scale = Vector3(1.0 - hop * 0.4, 1.0 + hop, 1.0)
		FireflyEnemy.GroundReactionKind.POLLEN_VENT_ESCAPE:
			firefly.stop_movement(step)
			if is_instance_valid(firefly.visual):
				var squeeze := sin(progress * PI) * 0.16
				firefly.visual.scale = Vector3(1.0 + squeeze, 1.0 - squeeze * 0.7, 1.0)
		FireflyEnemy.GroundReactionKind.GALE_PULSE_ESCAPE:
			firefly.stop_movement(step)
			firefly.set_glow_mode(2, lerpf(0.3, 1.0, progress))
			firefly.set_air_charge_telegraph(true, lerpf(0.25, 0.9, progress))

	if progress >= 1.0:
		_released = true
		firefly.execute_counter_burst()
		request_state(&"takeoff")


func _compute_evade_dir(firefly: FireflyEnemy) -> Vector3:
	if firefly.has_target():
		var away := firefly.global_position - firefly.target.global_position
		away.y = 0.0
		if not away.is_zero_approx():
			return away.normalized()
	if not firefly.pending_hit_direction.is_zero_approx():
		var dir := Vector3(firefly.pending_hit_direction.x, 0.0, firefly.pending_hit_direction.z)
		if not dir.is_zero_approx():
			return dir.normalized()
	return -firefly.last_facing_direction
