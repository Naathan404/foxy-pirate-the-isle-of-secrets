extends EnemyState
## Trạng thái bay lượn trên không: tiếp cận theo sóng khi còn trong tầm,
## ngừng đuổi và quay về tổ ngay khi mục tiêu chạy ra xa.

var _hover_remaining_seconds: float = 0.0
var _search_remaining_seconds: float = 0.0
var _glitter_cooldown_seconds: float = 0.0
var _orbit_clock_seconds: float = 0.0
var _returning_home: bool = false


func _enter() -> void:
	var firefly := enemy as FireflyEnemy
	if firefly == null:
		return
	firefly.defensive_takeoff_pending = false
	firefly.set_airborne_alert(true)
	if firefly.altitude_meters < firefly.airborne_hurt_threshold_meters:
		firefly.set_altitude_meters(firefly.hover_altitude_meters)
	firefly.set_glow_mode(1)
	firefly.set_air_charge_telegraph(false, 0.0)
	firefly.play_firefly_animation(&"hover", true, true)
	_hover_remaining_seconds = firefly.max_hover_seconds
	_search_remaining_seconds = firefly.search_seconds
	_glitter_cooldown_seconds = firefly.glitter_drop_interval_seconds * 0.75
	_orbit_clock_seconds = 0.0
	_returning_home = false


func _update(delta: float) -> void:
	var firefly := enemy as FireflyEnemy
	if firefly == null or firefly.dead:
		return
	var step := maxf(0.0, delta)
	_orbit_clock_seconds += step
	_hover_remaining_seconds = maxf(0.0, _hover_remaining_seconds - step)
	firefly.free_flight_remaining_seconds = maxf(0.0, firefly.free_flight_remaining_seconds - step)
	var settled_alt := move_toward(
		firefly.altitude_meters, firefly.hover_altitude_meters, step * 2.4
	)
	firefly.set_altitude_meters(settled_alt)

	if _hover_remaining_seconds <= 0.0 and firefly.free_flight_remaining_seconds <= 0.0:
		firefly.pending_landing_spot = FireflyEmberMote.resolve_safe_landing_spot(
			firefly,
			firefly.global_position,
			firefly.home_position.y,
			firefly.landing_clearance_meters,
			firefly.ai
		)
		firefly.pending_gentle_land_to_rest = false
		request_state(&"gentleland")
		return

	var zone := firefly.get_current_zone()
	if zone == FireflyAI.Zone.INNER_ATTACK and firefly.post_burst_attack_cooldown_seconds <= 0.0:
		request_state(&"chargeburst")
		return

	if zone != FireflyAI.Zone.OUT_OF_RANGE and firefly.has_target():
		_returning_home = false
		_search_remaining_seconds = firefly.search_seconds
		_update_active_hover(firefly, step)
		return

	if firefly.free_flight_remaining_seconds > 0.0:
		_returning_home = false
		_search_remaining_seconds = firefly.search_seconds
		_update_free_roam(firefly, step)
		return

	_update_search_or_return(firefly, step)


func _update_active_hover(firefly: FireflyEnemy, step: float) -> void:
	var dir := firefly.ai.compute_hover_direction(
		firefly.global_position,
		firefly.target.global_position,
		_orbit_clock_seconds,
		firefly.orbit_sign,
		firefly.inner_attack_radius_meters,
		firefly.weave_amplitude,
		firefly.weave_frequency
	)
	if firefly.is_front_blocked() or not firefly.is_ground_ahead():
		firefly.orbit_sign *= -1.0
		dir = firefly.target.global_position - firefly.global_position
		dir.y = 0.0
	firefly.move_in_direction(dir, step, firefly.hover_speed_scale)
	firefly.face_target()
	firefly.play_firefly_animation(&"hover", true, false)

	_glitter_cooldown_seconds = maxf(0.0, _glitter_cooldown_seconds - step)
	if _glitter_cooldown_seconds <= 0.0:
		_glitter_cooldown_seconds = firefly.glitter_drop_interval_seconds
		firefly.spawn_glitter_mote()


func _update_search_or_return(firefly: FireflyEnemy, step: float) -> void:
	if not _returning_home:
		firefly.stop_movement(step)
		firefly.play_firefly_animation(&"hover", true, false)
		_search_remaining_seconds = maxf(0.0, _search_remaining_seconds - step)
		if _search_remaining_seconds <= 0.0:
			_returning_home = true
		return

	var to_home := firefly.home_position - firefly.global_position
	to_home.y = 0.0
	if to_home.length() <= 1.25:
		firefly.stop_movement(step)
		firefly.pending_landing_spot = FireflyEmberMote.resolve_safe_landing_spot(
			firefly,
			firefly.home_position,
			firefly.home_position.y,
			firefly.landing_clearance_meters,
			firefly.ai
		)
		firefly.pending_gentle_land_to_rest = true
		request_state(&"gentleland")
		return
	firefly.move_in_direction(to_home, step, firefly.hover_speed_scale * 0.8)
	firefly.play_firefly_animation(&"hover", true, false)


func _update_free_roam(firefly: FireflyEnemy, step: float) -> void:
	if firefly.ai == null:
		firefly.stop_movement(step)
		return
	var dir := firefly.ai.compute_free_roam_direction(
		firefly.global_position, firefly.home_position, _orbit_clock_seconds, firefly.orbit_sign
	)
	if firefly.is_front_blocked() or not firefly.is_ground_ahead():
		firefly.orbit_sign *= -1.0
		var to_home := firefly.home_position - firefly.global_position
		to_home.y = 0.0
		dir = to_home if not to_home.is_zero_approx() else -dir
	firefly.move_in_direction(dir, step, firefly.hover_speed_scale * 0.72)
	firefly.play_firefly_animation(&"hover", true, false)
