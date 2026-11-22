extends EnemyState
## Trạng thái nghỉ trên mặt đất: phát sáng ấm và cất cánh khi Player vào vùng nhận diện.

var _startle_remaining: float = -1.0


func _enter() -> void:
	var firefly := enemy as FireflyEnemy
	if firefly == null:
		return
	# Nếu vừa bị đánh trong lúc kiệt sức, giữ nốt cửa sổ trên đất trước khi bay lên lại.
	if firefly.exhausted_remaining_seconds > 0.0:
		request_state(&"exhaustedland", 20)
		return
	firefly.set_airborne_alert(false)
	firefly.set_altitude_meters(0.0)
	firefly.set_glow_mode(0)
	firefly.set_air_charge_telegraph(false, 0.0)
	firefly.stop_movement(1.0)
	firefly.play_firefly_animation(&"rest_idle", false, true)
	_startle_remaining = -1.0


func _update(delta: float) -> void:
	var firefly := enemy as FireflyEnemy
	if firefly == null or firefly.dead:
		return
	firefly.stop_movement(delta)

	if firefly.defensive_takeoff_pending:
		firefly.defensive_takeoff_pending = false
		request_state(&"takeoff")
		return

	var zone := firefly.get_current_zone()
	if zone == FireflyAI.Zone.OUT_OF_RANGE:
		_startle_remaining = -1.0
		return

	firefly.face_target()
	var dist := firefly._distance_to_target()
	if zone == FireflyAI.Zone.INNER_ATTACK or dist <= firefly.instant_takeoff_distance_meters:
		request_state(&"takeoff")
		return

	if _startle_remaining < 0.0:
		_startle_remaining = firefly.startle_delay_seconds
		firefly.play_firefly_animation(&"rest_alert", false, true)
	_startle_remaining = maxf(0.0, _startle_remaining - maxf(0.0, delta))
	if _startle_remaining <= 0.0:
		request_state(&"takeoff")
