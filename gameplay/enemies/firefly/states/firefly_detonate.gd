extends EnemyState
## Trạng thái kích nổ túi khí độc + phản lực Newton hất nảy Đom đóm lên cao trên không:
## - Nếu còn sức bay: bật nảy lên theo vòng cung rồi lấy thăng bằng tiếp tục lượn (không rớt ngay).
## - Nếu đã cạn lực: văng nảy lên tới đỉnh cung rồi hụt hơi rơi theo parabol xuống đất.

const RECOVER_PEAK_SPLIT := 0.58
const AIRBORNE_RECOIL_SPEED := 1.45

var _elapsed_seconds: float = 0.0
var _recoil_dir: Vector3 = Vector3.BACK
var _start_altitude: float = 0.0
var _peak_altitude: float = 0.0
var _stay_airborne: bool = false


func _enter() -> void:
	var firefly := enemy as FireflyEnemy
	if firefly == null:
		return
	_elapsed_seconds = 0.0
	firefly.remaining_burst_charges = maxi(0, firefly.remaining_burst_charges - 1)
	_stay_airborne = firefly.can_continue_bombing_run()
	_start_altitude = firefly.altitude_meters
	var pop := maxf(0.25, firefly.blast_recoil_pop_height_meters)
	_peak_altitude = _start_altitude + (pop if _stay_airborne else pop * 0.82)

	var blast_center := firefly.pending_blast_center
	firefly.execute_detonate_drop(blast_center)
	firefly.pending_landing_spot = firefly.select_exhausted_landing_spot(blast_center)
	firefly.set_glow_mode(1 if _stay_airborne else 3)
	firefly.play_firefly_animation(&"burst", true, true)

	var away := firefly.pending_landing_spot - blast_center
	away.y = 0.0
	_recoil_dir = away.normalized() if not away.is_zero_approx() else -firefly.last_facing_direction


func _update(delta: float) -> void:
	var firefly := enemy as FireflyEnemy
	if firefly == null or firefly.dead:
		return
	var step := maxf(0.0, delta)
	var duration := maxf(0.2, firefly.detonate_recoil_seconds)
	_elapsed_seconds += step
	var progress := clampf(_elapsed_seconds / duration, 0.0, 1.0)

	# Quỹ đạo ngang giật lùi chậm dần theo lực cản không khí.
	var horiz_scale := AIRBORNE_RECOIL_SPEED * (1.0 - progress * 0.45)
	firefly.move_in_direction(_recoil_dir, step, horiz_scale)

	# Quỹ đạo đứng theo phản lực Newton: vọt lên đỉnh (1 - (1-u)^2) rồi ổn định cánh hoặc rơi từ đỉnh.
	if _stay_airborne:
		if progress < RECOVER_PEAK_SPLIT:
			var up_p := progress / RECOVER_PEAK_SPLIT
			var up_curve := 1.0 - pow(1.0 - up_p, 2.0)
			firefly.set_altitude_meters(lerpf(_start_altitude, _peak_altitude, up_curve))
		else:
			var rec_p := (progress - RECOVER_PEAK_SPLIT) / (1.0 - RECOVER_PEAK_SPLIT)
			var smooth := rec_p * rec_p * (3.0 - 2.0 * rec_p)
			firefly.set_altitude_meters(
				lerpf(_peak_altitude, firefly.hover_altitude_meters, smooth)
			)
	else:
		var apex_curve := 1.0 - pow(1.0 - progress, 2.0)
		firefly.set_altitude_meters(lerpf(_start_altitude, _peak_altitude, apex_curve))

	if progress >= 1.0:
		if _stay_airborne:
			firefly.post_burst_attack_cooldown_seconds = firefly.post_burst_hover_cooldown_seconds
			request_state(&"hoverorbit")
		else:
			request_state(&"exhaustedland")
