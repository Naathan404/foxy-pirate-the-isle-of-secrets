class_name VenomVineStalk
extends EnemyState
## Trạng thái rình rập: theo dõi cự ly/vận tốc mục tiêu và quyết định đòn đánh tối ưu.


func _enter() -> void:
	var vine := enemy as VenomVine
	if vine == null:
		return
	enemy._set_horizontal_velocity(Vector3.ZERO)
	vine.set_awake(true)
	vine.set_sprite_sheet_mode(false)
	vine.face_target()
	vine.play_directional_animation(&"idle")


func _update(delta: float) -> void:
	var vine := enemy as VenomVine
	if vine == null or vine.dead:
		return
	enemy._set_horizontal_velocity(Vector3.ZERO)
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
