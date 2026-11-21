extends EnemyState
## Trạng thái bật cánh bay lên từ mặt đất tới độ cao hover_altitude_meters.

const LIFT_FLUTTER_CYCLES := 2.5
const LIFT_FLUTTER_HEIGHT := 0.14
const LAUNCH_PRE_SPLIT := 0.14
const LAUNCH_PRE_ALTITUDE_RATIO := 0.12

var _elapsed_seconds: float = 0.0
var _start_altitude: float = 0.0


func _enter() -> void:
	var firefly := enemy as FireflyEnemy
	if firefly == null:
		return
	firefly.exhausted_remaining_seconds = 0.0
	firefly.exhausted_window_damage_taken = 0.0
	firefly.post_burst_attack_cooldown_seconds = 0.0
	var extra_roam := randf_range(0.0, minf(1.2, firefly.min_free_flight_seconds * 0.3))
	firefly.free_flight_remaining_seconds = firefly.min_free_flight_seconds + extra_roam
	firefly.reset_ground_hit_counter()
	firefly.remaining_burst_charges = firefly.get_burst_charges_per_flight()
	firefly.set_airborne_alert(true)
	firefly.set_glow_mode(1)
	firefly.face_target()
	firefly.play_firefly_animation(&"hover", true, true)
	_start_altitude = firefly.altitude_meters
	_elapsed_seconds = 0.0


func _update(delta: float) -> void:
	var firefly := enemy as FireflyEnemy
	if firefly == null or firefly.dead:
		return
	var duration := maxf(0.12, firefly.takeoff_duration_seconds)
	_elapsed_seconds += maxf(0.0, delta)
	var progress := clampf(_elapsed_seconds / duration, 0.0, 1.0)
	var alt_ratio := 0.0
	if progress < LAUNCH_PRE_SPLIT:
		var pre_p := progress / LAUNCH_PRE_SPLIT
		alt_ratio = pre_p * pre_p * LAUNCH_PRE_ALTITUDE_RATIO
	else:
		var climb_p := (progress - LAUNCH_PRE_SPLIT) / (1.0 - LAUNCH_PRE_SPLIT)
		var smooth := climb_p * climb_p * (3.0 - 2.0 * climb_p)
		var flutter := (
			sin(climb_p * PI * LIFT_FLUTTER_CYCLES) * (1.0 - climb_p) * LIFT_FLUTTER_HEIGHT
		)
		alt_ratio = clampf(
			lerpf(LAUNCH_PRE_ALTITUDE_RATIO, 1.0, smooth) + flutter * 0.18, 0.0, 1.04
		)
	firefly.set_altitude_meters(lerpf(_start_altitude, firefly.hover_altitude_meters, alt_ratio))

	if firefly.has_target():
		firefly.face_target()
		var away := firefly.global_position - firefly.target.global_position
		away.y = 0.0
		if not away.is_zero_approx() and progress >= LAUNCH_PRE_SPLIT and progress < 0.78:
			firefly.move_in_direction(away, delta, 0.3)
		else:
			firefly.stop_movement(delta)
	else:
		firefly.stop_movement(delta)

	if progress >= 1.0:
		firefly.set_altitude_meters(firefly.hover_altitude_meters)
		request_state(&"hoverorbit")
