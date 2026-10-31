class_name CrescentCleaveEffect
extends CharmEffect
## Tạo một execution bán nguyệt phía trước từ cấu hình Charm.

const CHARM_ATTACK_SCENE = preload("res://gameplay/charms/active/crescent_cleave_attack.tscn")

var _execution: CrescentCleaveAttack


func can_activate(context: CharmActivationContext) -> bool:
	if not super.can_activate(context) or not context.is_valid():
		return false
	if not is_instance_valid(actor) or not is_instance_valid(actor.get_parent()):
		return false
	if definition.get_param_float(&"damage_multiplier") <= 0.0:
		return false
	if definition.get_param_float(&"radius_units") <= 0.0:
		return false
	var half_angle := definition.get_param_float(&"half_angle_degrees")
	if half_angle <= 0.0 or half_angle > 180.0:
		return false
	if definition.get_param_float(&"hit_duration_seconds") <= 0.0:
		return false
	var execution := CHARM_ATTACK_SCENE.instantiate() as CrescentCleaveAttack
	var is_valid := execution != null and execution.validate()
	if is_instance_valid(execution):
		execution.free()
	return is_valid


func activate(context: CharmActivationContext) -> bool:
	if not can_activate(context):
		return false
	var execution := CHARM_ATTACK_SCENE.instantiate() as CrescentCleaveAttack
	var parent := actor.get_parent()
	if execution == null or not is_instance_valid(parent):
		if is_instance_valid(execution):
			execution.free()
		return false
	parent.add_child(execution)
	_execution = execution
	execution.tree_exited.connect(_on_execution_exited.bind(execution), CONNECT_ONE_SHOT)
	execution.context = _build_context(context)
	execution.global_position = actor.global_position
	execution.radius_units = definition.get_param_float(&"radius_units")
	execution.half_angle_degrees = definition.get_param_float(&"half_angle_degrees", 90.0)
	execution.active_seconds = definition.get_param_float(&"hit_duration_seconds", 0.12)
	if execution.activate():
		return true
	execution.queue_free()
	_execution = null
	return false


func on_unequipped() -> void:
	cancel_active()


func cancel_active() -> void:
	if is_instance_valid(_execution):
		_execution.cancel()
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
	result.damage_hp = maxf(0.0, _get_base_damage() * definition.get_param_float(&"damage_multiplier"))
	return result


func _get_base_damage() -> float:
	var weapon_controller := actor.get("weapon_controller") as WeaponController
	if is_instance_valid(weapon_controller) and weapon_controller.equipped != null:
		var attack := weapon_controller.equipped.get_attack(&"normal")
		if attack != null:
			return attack.damage_hp
	return 1


func _on_execution_exited(execution: CrescentCleaveAttack) -> void:
	if _execution == execution:
		_execution = null
