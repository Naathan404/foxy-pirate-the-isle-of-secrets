class_name TideGrappleEffect
extends CharmEffect
## Bắn mỏ neo, gây sát thương và điều phối kéo target hoặc actor.

signal grapple_resolved(result: StringName, target: Node)

const CHARM_ATTACK_SCENE = preload("res://gameplay/charms/active/tide_grapple_attack.tscn")

var _execution: TideGrappleAttack


func can_activate(context: CharmActivationContext) -> bool:
	if not super.can_activate(context) or not context.is_valid():
		return false
	if not is_instance_valid(actor) or not is_instance_valid(actor.get_parent()):
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
	execution.context = _build_context(context)
	execution.global_position = actor.global_position
	execution.range_units = definition.get_param_float(&"range_units")
	execution.pull_stop_distance = definition.get_param_float(&"pull_stop_distance")
	execution.pull_speed_units_per_second = definition.get_param_float(
		&"pull_speed_units_per_second"
	)
	execution.stun_seconds = definition.get_param_float(&"stun_seconds")
	if execution.activate():
		return true
	execution.queue_free()
	_execution = null
	return false


func on_unequipped() -> void:
	cancel_active()


func cancel_active() -> void:
	if is_instance_valid(_execution):
		_execution.queue_free()
	_execution = null


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
	result.damage_hp = maxi(
		1, roundi(_get_base_damage() * definition.get_param_float(&"damage_multiplier"))
	)
	return result


func _get_base_damage() -> int:
	var weapon_controller := actor.get("weapon_controller") as WeaponController
	if is_instance_valid(weapon_controller) and weapon_controller.equipped != null:
		var attack := weapon_controller.equipped.get_attack(&"normal")
		if attack != null:
			return attack.damage_hp
	return 1


func _on_grapple_resolved(result: StringName, target: Node) -> void:
	grapple_resolved.emit(result, target)


func _on_execution_exited(execution: TideGrappleAttack) -> void:
	if _execution == execution:
		_execution = null
