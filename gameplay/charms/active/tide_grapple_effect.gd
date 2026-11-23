class_name TideGrappleEffect
extends CharmEffect
## Bắn mỏ neo, gây sát thương và điều phối kéo target hoặc actor.

signal grapple_resolved(result: StringName, target: Node)

const CHARM_ATTACK_SCENE = preload("res://gameplay/charms/active/tide_grapple_attack.tscn")

var _execution: TideGrappleAttack
var _cast_direction: Vector3 = Vector3.BACK


func can_activate(context: CharmActivationContext) -> bool:
	if not super.can_activate(context) or not context.is_valid():
		return false
	if not is_instance_valid(actor) or not is_instance_valid(actor.get_parent()):
		return false
	if definition.get_param_float(&"hook_speed", 24.0) <= 0.0:
		return false
	if definition.get_param_float(&"return_speed", 28.0) <= 0.0:
		return false
	for param_id: StringName in [
		&"damage_multiplier",
		&"range_units",
		&"pull_stop_distance",
		&"pull_speed_units_per_second",
		&"stun_seconds",
	]:
		if definition.get_param_float(param_id) <= 0.0:
			return false
	var execution := CHARM_ATTACK_SCENE.instantiate() as TideGrappleAttack
	var is_valid := execution != null and execution.validate()
	if is_instance_valid(execution):
		execution.free()
	return is_valid


func activate(context: CharmActivationContext) -> bool:
	if not can_activate(context):
		return false
	var execution := CHARM_ATTACK_SCENE.instantiate() as TideGrappleAttack
	var parent := actor.get_parent()
	if execution == null or not is_instance_valid(parent):
		if is_instance_valid(execution):
			execution.free()
		return false
	parent.add_child(execution)
	_execution = execution
	execution.tree_exited.connect(_on_execution_exited.bind(execution), CONNECT_ONE_SHOT)
	execution.grapple_resolved.connect(_on_grapple_resolved)
	execution.flight_phase_changed.connect(_on_flight_phase_changed)
	execution.completed.connect(_on_completed)
	execution.context = _build_context(context)
	_cast_direction = execution.context.direction
	execution.global_position = actor.global_position
	execution.range_units = definition.get_param_float(&"range_units")
	execution.pull_stop_distance = definition.get_param_float(&"pull_stop_distance")
	execution.pull_speed_units_per_second = definition.get_param_float(
		&"pull_speed_units_per_second"
	)
	execution.stun_seconds = definition.get_param_float(&"stun_seconds")
	execution.hook_speed_units_per_second = definition.get_param_float(&"hook_speed", 24.0)
	execution.return_speed_units_per_second = definition.get_param_float(&"return_speed", 28.0)
	if execution.activate():
		return true
	execution.queue_free()
	_execution = null
	return false


func on_unequipped() -> void:
	cancel_active()


func cancel_active() -> void:
	_stop_cast_animation()
	if is_instance_valid(_execution):
		_execution.cancel()
	_execution = null


func _on_flight_phase_changed(phase: StringName, seconds: float) -> void:
	_play_cast_animation(phase, _cast_direction, seconds, phase != &"active")


func _on_completed() -> void:
	_play_cast_animation(&"recover", _cast_direction, 0.08, true)


func _build_context(activation: CharmActivationContext) -> AttackContext:
	var result := AttackContext.new()
	result.actor = actor
	result.team = actor.team
	result.attack_id = Time.get_ticks_usec()
	result.action = definition.charm_id
	result.origin = actor.global_position
	result.direction = (
		activation.direction.normalized()
		if not activation.direction.is_zero_approx()
		else Vector3.BACK
	)
	result.direction.y = 0.0
	result.direction = result.direction.normalized()
	result.damage_hp = maxf(
		0.0, _get_base_damage() * definition.get_param_float(&"damage_multiplier")
	)
	return result


func _on_grapple_resolved(result: StringName, target: Node) -> void:
	grapple_resolved.emit(result, target)


func _on_execution_exited(execution: TideGrappleAttack) -> void:
	if _execution == execution:
		_execution = null
