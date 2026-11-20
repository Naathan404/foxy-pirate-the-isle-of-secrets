extends EnemyState
## Trạng thái rơi xuống đất và nằm nghỉ kiệt sức: mở HurtBox để Foxy tiêu diệt.

const IMPACT_SQUASH_SECONDS := 0.16

var _falling: bool = true
var _fall_elapsed: float = 0.0
var _breath_clock: float = 0.0
var _impact_timer: float = 0.0
var _start_altitude: float = 0.0
var _start_xz: Vector3 = Vector3.ZERO
var _landing_xz: Vector3 = Vector3.ZERO


func _enter() -> void:
	var firefly := enemy as FireflyEnemy
	if firefly == null:
		return
	_breath_clock = 0.0
	_impact_timer = 0.0
	firefly.set_glow_mode(3)
	firefly.set_air_charge_telegraph(false, 0.0)
	if firefly.exhausted_remaining_seconds > 0.0 and not firefly.is_airborne():
		_falling = false
		firefly.set_altitude_meters(0.0)
		firefly.stop_movement(1.0)
		firefly.play_firefly_animation(&"exhausted", false, true)
		return

	_falling = true
	_fall_elapsed = 0.0
	_start_altitude = firefly.altitude_meters
	_start_xz = firefly.global_position
	var desired_spot := (
		firefly.pending_landing_spot
		if not firefly.pending_landing_spot.is_zero_approx()
		else firefly.global_position
	)
	_landing_xz = FireflyEmberMote.resolve_safe_landing_spot(
		firefly, desired_spot, firefly.home_position.y, firefly.landing_clearance_meters, firefly.ai
	)
	firefly.exhausted_window_damage_taken = 0.0
	firefly.exhausted_remaining_seconds = firefly.exhausted_duration_seconds
	firefly.play_firefly_animation(&"exhausted", false, true)


func _exit() -> void:
	var firefly := enemy as FireflyEnemy
	if firefly != null and is_instance_valid(firefly.visual):
		firefly.visual.scale = Vector3.ONE
		firefly.visual.rotation.z = 0.0
		if is_instance_valid(firefly.visual.sprite):
			firefly.visual.sprite.position = Vector3.ZERO


func _update(delta: float) -> void:
	var firefly := enemy as FireflyEnemy
	if firefly == null or firefly.dead:
		return
	var step := maxf(0.0, delta)

	if _falling:
		var fall_duration := maxf(0.2, firefly.fall_to_ground_seconds)
		_fall_elapsed += step
		var progress := clampf(_fall_elapsed / fall_duration, 0.0, 1.0)
		var fall_curve := clampf(progress * progress * (1.85 - 0.85 * progress), 0.0, 1.0)
		var next_pos := _start_xz.lerp(_landing_xz, progress)
		firefly.global_position.x = next_pos.x
		firefly.global_position.z = next_pos.z
		firefly.set_altitude_meters(lerpf(_start_altitude, 0.0, fall_curve))
		if is_instance_valid(firefly.visual):
			var sway := sin(_fall_elapsed * 9.5) * (1.0 - progress * 0.45)
			firefly.visual.rotation.z = sway * 0.16
			if is_instance_valid(firefly.visual.sprite):
				firefly.visual.sprite.position = Vector3(sway * 0.28, 0.0, 0.0)
		firefly.stop_movement(step)
		if progress >= 1.0:
			_falling = false
			_impact_timer = IMPACT_SQUASH_SECONDS
			if is_instance_valid(firefly.visual):
				firefly.visual.rotation.z = 0.0
				if is_instance_valid(firefly.visual.sprite):
					firefly.visual.sprite.position = Vector3.ZERO
			firefly.set_altitude_meters(0.0)
		return

	_breath_clock += step
	if is_instance_valid(firefly.visual):
		if _impact_timer > 0.0:
			_impact_timer = maxf(0.0, _impact_timer - step)
			var sq := _impact_timer / IMPACT_SQUASH_SECONDS
			firefly.visual.scale = Vector3(1.0 + sq * 0.22, 1.0 - sq * 0.22, 1.0)
		else:
			var breath := sin(_breath_clock * 5.2) * 0.06
			firefly.visual.scale = Vector3(1.0 - breath * 0.65, 1.0 + breath, 1.0)

	firefly.stop_movement(step)
	firefly.exhausted_remaining_seconds = maxf(0.0, firefly.exhausted_remaining_seconds - step)
	if firefly.exhausted_remaining_seconds <= 0.45 and firefly.exhausted_remaining_seconds > 0.0:
		var wake_blink := sin(_breath_clock * 20.0) > 0.0
		firefly.set_glow_mode(1 if wake_blink else 3)
	if firefly.exhausted_remaining_seconds <= 0.0:
		if firefly.get_current_zone() != FireflyAI.Zone.OUT_OF_RANGE:
			request_state(&"takeoff")
		else:
			request_state(&"rest")
