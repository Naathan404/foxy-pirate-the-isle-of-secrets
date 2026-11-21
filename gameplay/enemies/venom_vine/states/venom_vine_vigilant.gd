class_name VenomVineVigilant
extends EnemyState
## Cảnh giác sau khi mất dấu, rồi trở về phục kích nếu không tìm lại mục tiêu.

var _remaining_seconds: float = 0.0


func _enter() -> void:
	var vine := enemy as VenomVine
	if vine == null:
		return
	enemy._set_horizontal_velocity(Vector3.ZERO)
	_remaining_seconds = vine.vigilant_duration_seconds
	vine.set_sprite_sheet_mode(false)
	if not vine.last_known_target_position.is_zero_approx():
		vine.face_direction(vine.last_known_target_position - vine.global_position)
	vine.play_directional_animation(&"idle")


func _update(delta: float) -> void:
	var vine := enemy as VenomVine
	if vine == null or vine.dead:
		return
	enemy._set_horizontal_velocity(Vector3.ZERO)

	if vine.consume_pending_counter():
		var counter_plan := vine.build_counter_plan()
		if (
			int(counter_plan.get("mode", VenomVineAI.AttackMode.NONE))
			!= VenomVineAI.AttackMode.NONE
		):
			var attack_state := fsm.states.get("attack") as VenomVineAttack
			if attack_state != null:
				attack_state.set_pending_plan(counter_plan)
			request_state(&"attack")
			return

	if vine.get_current_zone() != VenomVineAI.Zone.OUT_OF_RANGE:
		request_state(&"stalk")
		return

	_remaining_seconds = maxf(0.0, _remaining_seconds - maxf(0.0, delta))
	if _remaining_seconds <= 0.0:
		vine.ambushed_wake = false
		vine._request_burrow(false)
