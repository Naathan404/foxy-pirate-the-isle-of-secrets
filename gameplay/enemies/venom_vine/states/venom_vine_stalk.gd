class_name VenomVineStalk
extends EnemyState
## Trạng thái rình rập: theo dõi cự ly/vận tốc mục tiêu, phản ứng hit và kích hoạt phản công.

const MIN_ATTACK_COOLDOWN_FOR_BURROW_SECONDS := 0.3

var _was_flinching: bool = false
var _idle_remaining_seconds: float = 0.0
var _decision_remaining_seconds: float = 0.0


func _enter() -> void:
	var vine := enemy as VenomVine
	if vine == null:
		return
	enemy._set_horizontal_velocity(Vector3.ZERO)
	vine.set_awake(true)
	vine.set_sprite_sheet_mode(false)
	vine.face_target()
	_was_flinching = vine.is_flinching()
	_idle_remaining_seconds = vine.idle_min_duration_seconds
	_decision_remaining_seconds = 0.0
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

	var step := maxf(0.0, delta)
	if vine._try_stalk_special_action(step):
		return

	_idle_remaining_seconds = maxf(0.0, _idle_remaining_seconds - step)
	if _idle_remaining_seconds > 0.0:
		return

	if vine.attack_cooldown_remaining > 0.0:
		_decision_remaining_seconds = maxf(0.0, _decision_remaining_seconds - step)
		if _decision_remaining_seconds <= 0.0:
			_decision_remaining_seconds = vine.idle_decision_interval_seconds
			_consider_idle_burrow(vine)
		return

	var plan := vine.build_attack_plan()
	var mode := int(plan.get("mode", VenomVineAI.AttackMode.NONE))
	if mode == VenomVineAI.AttackMode.NONE:
		return
	var attack_state := fsm.states.get("attack") as VenomVineAttack
	if attack_state != null:
		attack_state.set_pending_plan(plan)
	request_state(&"attack")


func _consider_idle_burrow(vine: VenomVine) -> void:
	if (
		vine.ai == null
		or not vine.has_target()
		or vine.has_pending_counter()
		or vine._burrow_cooldown_remaining > 0.0
		or vine.attack_cooldown_remaining <= MIN_ATTACK_COOLDOWN_FOR_BURROW_SECONDS
	):
		return
	var to_vine := vine.global_position - vine.target.global_position
	to_vine.y = 0.0
	var target_velocity := vine.get_target_velocity()
	target_velocity.y = 0.0
	var decision := (
		vine
		. ai
		. choose_idle_decision(
			{
				"burrow_ready": true,
				"distance_meters": to_vine.length(),
				"inner_radius_meters": vine.inner_attack_radius_meters,
				"approach_speed": target_velocity.dot(to_vine.normalized()),
				"hp_ratio": vine.get_hp_ratio(),
				"agitation": vine.agitation,
				"active_venom": vine._has_active_venom(),
			}
		)
	)
	if decision == VenomVineAI.IdleDecision.BURROW:
		vine._request_burrow(false)
