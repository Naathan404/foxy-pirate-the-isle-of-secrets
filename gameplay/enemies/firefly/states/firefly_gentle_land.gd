extends EnemyState
## Trạng thái hạ cánh nhẹ nhàng kiểu côn trùng khi hết thời gian bay hoặc mất dấu quay về tổ.
## Khác hoàn toàn với ExhaustedLand (rớt nhanh xuống sàn sau khi tự kích nổ).

const FLUTTER_CYCLES := 3.0
const FLUTTER_HEIGHT_METERS := 0.16
const BREATH_AMP := 0.032
const MIN_LANDED_WINDOW_SECONDS := 0.2

var _landing: bool = true
var _to_rest: bool = false
var _elapsed_seconds: float = 0.0
var _rest_elapsed_seconds: float = 0.0
var _start_altitude: float = 0.0
var _start_xz: Vector3 = Vector3.ZERO
var _landing_xz: Vector3 = Vector3.ZERO


func _enter() -> void:
	var firefly := enemy as FireflyEnemy
	if firefly == null:
		return
	_to_rest = firefly.pending_gentle_land_to_rest
	firefly.pending_gentle_land_to_rest = false
	_elapsed_seconds = 0.0
	_rest_elapsed_seconds = 0.0
	_start_altitude = firefly.altitude_meters
	_start_xz = firefly.global_position
	_landing = _start_altitude > 0.05
	var desired_spot := (
		firefly.pending_landing_spot
		if not firefly.pending_landing_spot.is_zero_approx()
		else firefly.global_position
	)
	_landing_xz = (
		FireflyEmberMote.resolve_safe_landing_spot(
			firefly,
			desired_spot,
			firefly.home_position.y,
			firefly.landing_clearance_meters,
			firefly.ai
		)
		if _landing
		else firefly.global_position
	)
	firefly.set_glow_mode(0)
	firefly.set_air_charge_telegraph(false, 0.0)
	if _landing:
		firefly.play_firefly_animation(&"hover", true, false)
	else:
		firefly.set_altitude_meters(0.0)
		firefly.play_firefly_animation(&"rest_idle", false, true)


func _exit() -> void:
	var firefly := enemy as FireflyEnemy
	if firefly != null and is_instance_valid(firefly.visual):
		firefly.visual.scale = Vector3.ONE


func _update(delta: float) -> void:
	var firefly := enemy as FireflyEnemy
	if firefly == null or firefly.dead:
		return
	var step := maxf(0.0, delta)

	if _landing:
		_update_descent(firefly, step)
		return

	_update_ground_rest(firefly, step)


func _update_descent(firefly: FireflyEnemy, step: float) -> void:
	if _to_rest and firefly.is_airborne() and _elapsed_seconds >= 0.15:
		var zone := firefly.get_current_zone()
		var dist := firefly._distance_to_target()
		if (
			zone == FireflyAI.Zone.INNER_ATTACK
			or (firefly.has_target() and dist <= firefly.instant_takeoff_distance_meters)
		):
			if firefly.altitude_meters >= firefly.hover_altitude_meters * 0.7:
				request_state(&"hoverorbit")
			else:
				request_state(&"takeoff")
			return

	var duration := maxf(0.25, firefly.gentle_land_duration_seconds)
	_elapsed_seconds += step
	var progress := clampf(_elapsed_seconds / duration, 0.0, 1.0)
	var smooth := progress * progress * (3.0 - 2.0 * progress)
	var flutter := (
		sin(progress * PI * FLUTTER_CYCLES)
		* (1.0 - progress)
		* FLUTTER_HEIGHT_METERS
		* minf(1.0, _start_altitude)
	)
	var next_pos := _start_xz.lerp(_landing_xz, smooth)
	firefly.global_position.x = next_pos.x
	firefly.global_position.z = next_pos.z
	firefly.set_altitude_meters(maxf(0.0, lerpf(_start_altitude, 0.0, smooth) + flutter))
	firefly.stop_movement(step)

	if progress >= 1.0:
		_landing = false
		firefly.set_altitude_meters(0.0)
		firefly.set_airborne_alert(false)
		if _to_rest:
			request_state(&"rest")
			return
		firefly.play_firefly_animation(&"rest_idle", false, true)


func _update_ground_rest(firefly: FireflyEnemy, step: float) -> void:
	firefly.stop_movement(step)
	_rest_elapsed_seconds += step
	if is_instance_valid(firefly.visual):
		var breath := sin(_rest_elapsed_seconds * 4.2) * BREATH_AMP
		firefly.visual.scale = Vector3(1.0 - breath * 0.5, 1.0 + breath, 1.0)

	if firefly.defensive_takeoff_pending:
		firefly.defensive_takeoff_pending = false
		request_state(&"takeoff")
		return

	if _rest_elapsed_seconds >= MIN_LANDED_WINDOW_SECONDS and firefly.has_target():
		var dist := firefly._distance_to_target()
		if dist <= firefly.outer_detection_radius_meters * 0.72:
			request_state(&"takeoff")
			return

	if _rest_elapsed_seconds >= maxf(0.4, firefly.gentle_rest_seconds):
		if firefly.get_current_zone() != FireflyAI.Zone.OUT_OF_RANGE:
			request_state(&"takeoff")
		else:
			request_state(&"rest")
