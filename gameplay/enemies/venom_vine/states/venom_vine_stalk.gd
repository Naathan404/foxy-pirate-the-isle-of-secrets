class_name VenomVineStalk
extends EnemyState
## Trạng thái rình rập: theo dõi cự ly/vận tốc mục tiêu, phản ứng hit và kích hoạt phản công.

var _was_flinching: bool = false


func _enter() -> void:
	var vine := enemy as VenomVine
	if vine == null:
		return
	enemy._set_horizontal_velocity(Vector3.ZERO)
	vine.set_awake(true)
	vine.set_sprite_sheet_mode(false)
	vine.face_target()
	_was_flinching = vine.is_flinching()
	vine.play_directional_animation(&"hit" if _was_flinching else &"idle")


func _update(delta: float) -> void:
	var vine := enemy as VenomVine
	if vine == null or vine.dead:
		return
	enemy._set_horizontal_velocity(Vector3.ZERO)

	if vine.consume_pending_counter():
		var counter_plan := vine.build_counter_plan()
		var counter_mode := int(counter_plan.get("mode", VenomVineAI.AttackMode.NONE))
		if counter_mode != VenomVineAI.AttackMode.NONE:
			var attack_state := fsm.states.get("attack") as VenomVineAttack
			if attack_state != null:
				attack_state.set_pending_plan(counter_plan)
			request_state(&"attack")
			return

	if vine.is_flinching():
		_was_flinching = true
		return
	if _was_flinching:
		_was_flinching = false
		vine.play_directional_animation(&"idle")

	var zone := vine.get_current_zone()
	if zone == VenomVineAI.Zone.OUT_OF_RANGE:
		request_state(&"vigilant")
		return

	vine.face_target()
	if zone == VenomVineAI.Zone.INNER_RING:
		vine.add_inner_agitation(delta)

	if vine.attack_cooldown_remaining > 0.0:
		return

	var plan := vine.build_attack_plan()
	var mode := int(plan.get("mode", VenomVineAI.AttackMode.NONE))
	if mode == VenomVineAI.AttackMode.NONE:
		return
	var attack_state := fsm.states.get("attack") as VenomVineAttack
	if attack_state != null:
		attack_state.set_pending_plan(plan)
	request_state(&"attack")
