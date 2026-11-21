class_name EliteMushroomSporeStream
extends EnemyState
## Chiêu thổi luồng khói & hạt bào tử liên tục của EliteMushroom: gồng khóa hướng gió,
## xả một luồng khói + bào tử liên tục về phía trước (không xoay bám đuổi), rồi hồi phục.

enum StreamPhase { WINDUP, STREAMING, RECOVER }

var _phase: StreamPhase = StreamPhase.WINDUP
var _remaining: float = 0.0
var _windup_duration: float = 0.95
var _aim_locked: bool = false
var _locked_direction: Vector3 = Vector3.BACK
var _active_stream: MushroomSporeStream


func _enter() -> void:
	var elite := enemy as EliteMushroom
	if elite == null:
		request_state(&"patrol")
		return
	elite.stop_movement()
	elite.cancel_approach_leap()
	_phase = StreamPhase.WINDUP
	_windup_duration = elite.get_stream_windup_seconds()
	_remaining = _windup_duration
	_aim_locked = false
	_locked_direction = _compute_aim_direction(elite)
	elite.face_direction(_locked_direction)
	elite.begin_charge_animation(_windup_duration)
	var feedback := elite.get_elite_feedback()
	if feedback != null:
		feedback.begin_telegraph()


func _exit() -> void:
	_stop_active_stream()
	var elite := enemy as EliteMushroom
	if elite != null:
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
		StreamPhase.WINDUP:
			_update_windup(elite)
		StreamPhase.STREAMING:
			_update_streaming(elite)
		StreamPhase.RECOVER:
			_update_recover(elite)


func _update_windup(elite: EliteMushroom) -> void:
	if not _aim_locked and elite.has_target():
		if _remaining <= elite.stream_aim_lock_seconds:
			_aim_locked = true
			_locked_direction = elite.apply_stream_aim_jitter(_locked_direction)
			elite.face_direction(_locked_direction)
		else:
			_locked_direction = _compute_aim_direction(elite)
			elite.face_direction(_locked_direction)
	var progress := 1.0 - _remaining / maxf(0.05, _windup_duration)
	elite.update_charge_feedback(clampf(progress, 0.0, 1.0))
	if _remaining > 0.0:
		return
	elite.cancel_spore_charge()
	var feedback := elite.get_elite_feedback()
	if feedback != null:
		feedback.end_telegraph()
	elite.face_direction(_locked_direction)
	_active_stream = elite.start_spore_stream(_locked_direction)
	elite.play_directional_animation(&"spore_release", true)
	_phase = StreamPhase.STREAMING
	_remaining = elite.stream_duration_seconds


func _update_streaming(elite: EliteMushroom) -> void:
	elite.play_directional_animation(&"spore_release")
	if _remaining > 0.0:
		return
	_stop_active_stream()
	_phase = StreamPhase.RECOVER
	_remaining = elite.stream_recovery_seconds


func _update_recover(elite: EliteMushroom) -> void:
	elite.play_directional_animation(&"idle")
	if _remaining > 0.0:
		return
	var patrol := get_node_or_null("../Patrol") as MushroomPatrol
	if patrol != null:
		patrol.mark_skip_next_observe()
	request_state(&"patrol")


func _stop_active_stream() -> void:
	if is_instance_valid(_active_stream):
		_active_stream.stop_emitting()
	_active_stream = null


func _compute_aim_direction(elite: EliteMushroom) -> Vector3:
	if elite.has_target():
		var offset := elite.target.global_position - elite.global_position
		offset.y = 0.0
		if not offset.is_zero_approx():
			return offset.normalized()
	var fallback := Vector3(elite.last_facing_direction.x, 0.0, elite.last_facing_direction.z)
	return fallback.normalized() if not fallback.is_zero_approx() else Vector3.BACK
