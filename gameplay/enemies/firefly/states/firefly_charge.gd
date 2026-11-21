extends EnemyState
## Trạng thái gồng nổ tại chỗ trên không: khóa vị trí của chính Đom đóm,
## báo hiệu bằng thân phình run & quầng sáng trên không (không bám đuổi, không vòng sàn).

var _elapsed_seconds: float = 0.0
var _start_altitude: float = 0.0


func _enter() -> void:
	var firefly := enemy as FireflyEnemy
	if firefly == null:
		return
	_elapsed_seconds = 0.0
	_start_altitude = firefly.altitude_meters
	firefly.pending_blast_center = firefly.compute_self_blast_center()
	firefly.stop_movement(1.0)
	firefly.set_glow_mode(2, 0.15)
	firefly.set_air_charge_telegraph(true, 0.15)
	firefly.face_target()
	firefly.play_firefly_animation(&"charge", true, true)


func _exit() -> void:
	var firefly := enemy as FireflyEnemy
	if firefly != null:
		firefly.set_air_charge_telegraph(false, 0.0)


func _update(delta: float) -> void:
	var firefly := enemy as FireflyEnemy
	if firefly == null or firefly.dead:
		return
	var step := maxf(0.0, delta)
	var duration := maxf(0.15, firefly.charge_duration_seconds)
	_elapsed_seconds += step
	var progress := clampf(_elapsed_seconds / duration, 0.0, 1.0)

	firefly.stop_movement(step)
	firefly.set_altitude_meters(
		lerpf(_start_altitude, firefly.charge_altitude_meters, minf(1.0, progress * 1.25))
	)
	firefly.set_glow_mode(2, progress)
	firefly.set_air_charge_telegraph(true, progress)

	if progress >= 1.0:
		request_state(&"detonatedrop")
