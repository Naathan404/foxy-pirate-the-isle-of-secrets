class_name VenomVineVigilant
extends EnemyState
## Trạng thái cảnh giác sau khi mất dấu: nhìn về hướng cuối trước khi thu nụ ngủ lại.

enum Phase {
	WATCH,
	RETRACT,
}

var _phase: Phase = Phase.WATCH
var _remaining_seconds: float = 0.0


func _enter() -> void:
	var vine := enemy as VenomVine
	if vine == null:
		return
	enemy._set_horizontal_velocity(Vector3.ZERO)
	_phase = Phase.WATCH
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
	if _phase == Phase.WATCH:
		if _remaining_seconds <= 0.0:
			_begin_retract(vine)
		return

	if _remaining_seconds <= 0.0:
		vine.set_awake(false)
		vine.ambushed_wake = false
		request_state(&"dormant")


func _begin_retract(vine: VenomVine) -> void:
	_phase = Phase.RETRACT
	_remaining_seconds = vine.retract_duration_seconds
	vine.set_sprite_sheet_mode(true)
	if is_instance_valid(vine.visual):
		vine.visual.play_animation(&"retract")
