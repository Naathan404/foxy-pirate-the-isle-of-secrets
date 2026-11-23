class_name EliteMushroomGreatSpore
extends EnemyState
## Chiêu thức 2 của EliteMushroom (Đại Bào Tử): nén người gồng phun rồi bật tung lên cao,
## phóng 5-6 cụm hạt bào tử sáng lấp lánh tỏa rộng khắp sân trước khi đáp thành độc hoặc Trứng Nấm.

enum CastPhase { WINDUP, RELEASE, RECOVER }

var _phase: CastPhase = CastPhase.WINDUP
var _remaining: float = 0.0
var _windup_duration: float = 0.95
var _release_duration: float = 0.65


func _enter() -> void:
	var elite := enemy as EliteMushroom
	if elite == null:
		request_state(&"patrol")
		return
	elite.stop_movement()
	elite.cancel_approach_leap()
	elite.face_target()
	_phase = CastPhase.WINDUP
	_windup_duration = maxf(0.4, elite.great_spore_windup_seconds)
	_release_duration = maxf(0.2, elite.great_spore_release_seconds)
	_remaining = _windup_duration
	elite.begin_charge_animation(_windup_duration)
	elite._apply_cast_visual_scale(Vector3.ONE)
	var feedback := elite.get_elite_feedback()
	if feedback != null:
		feedback.begin_telegraph()


func _exit() -> void:
	var elite := enemy as EliteMushroom
	if elite != null:
		elite._apply_cast_visual_scale(Vector3.ONE)
		elite.cancel_spore_charge()
		var feedback := elite.get_elite_feedback()
		if feedback != null:
			feedback.end_telegraph()


func _update(delta: float) -> void:
	var elite := enemy as EliteMushroom
	if elite == null:
		return
	var step := maxf(0.0, delta)
	elite.stop_movement(step)
	_remaining = maxf(0.0, _remaining - step)
	match _phase:
		CastPhase.WINDUP:
			_update_windup(elite)
		CastPhase.RELEASE:
			_update_release(elite)
		CastPhase.RECOVER:
			elite._apply_cast_visual_scale(Vector3.ONE)
			elite.play_directional_animation(&"idle")
			if _remaining <= 0.0:
				var patrol := get_node_or_null("../Patrol") as MushroomPatrol
				if patrol != null:
					patrol.mark_skip_next_observe()
				request_state(&"patrol")


func _update_windup(elite: EliteMushroom) -> void:
	elite.face_target()
	var progress := clampf(1.0 - _remaining / maxf(0.05, _windup_duration), 0.0, 1.0)
	elite.update_charge_feedback(progress)
	# Crouch & widen body while building upward spore eruption pressure inside the cap.
	var squash := Vector3(lerpf(1.0, 1.18, progress), lerpf(1.0, 0.76, progress), 1.0)
	elite._apply_cast_visual_scale(squash)
	if _remaining > 0.0:
		return
	elite.cancel_spore_charge()
	var feedback := elite.get_elite_feedback()
	if feedback != null:
		feedback.end_telegraph()
	elite.launch_great_spores()
	elite.play_directional_animation(&"great_spore_release", true)
	_phase = CastPhase.RELEASE
	_remaining = _release_duration


func _update_release(elite: EliteMushroom) -> void:
	var progress := clampf(1.0 - _remaining / maxf(0.05, _release_duration), 0.0, 1.0)
	var pop := sin(clampf(progress * 1.15, 0.0, 1.0) * PI)
	elite._apply_cast_visual_scale(Vector3(1.0 - 0.14 * pop, 1.0 + 0.3 * pop, 1.0))
	elite.play_directional_animation(&"great_spore_release")
	if _remaining > 0.0:
		return
	elite._apply_cast_visual_scale(Vector3.ONE)
	_phase = CastPhase.RECOVER
	_remaining = elite.great_spore_recovery_seconds
