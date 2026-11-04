class_name BuckshotSalvoEffect
extends CharmEffect
## Radial burst; each pellet has independent target reservation.

const ATTACK_SCENE := preload("res://gameplay/charms/active/charm_active_attack.tscn")
var _executions: Array[CharmActiveAttack] = []


func can_activate(context: CharmActivationContext) -> bool:
	return (
		super.can_activate(context)
		and context != null
		and context.is_valid()
		and is_instance_valid(actor)
		and definition.get_param_int(&"projectile_count", 8) > 0
	)


func activate(context: CharmActivationContext) -> bool:
	if not can_activate(context):
		return false
	var count := definition.get_param_int(&"projectile_count", 8)
	var base_direction := context.direction
	base_direction.y = 0.0
	if base_direction.is_zero_approx():
		base_direction = Vector3.BACK
	base_direction = base_direction.normalized()
	var base_angle := atan2(base_direction.x, base_direction.z)
	for index in count:
		var angle := base_angle + TAU * float(index) / float(count)
		var direction := Vector3(sin(angle), 0.0, cos(angle))
		var execution := ATTACK_SCENE.instantiate() as CharmActiveAttack
		if execution == null:
			continue
		actor.get_parent().add_child(execution)
		_executions.append(execution)
		execution.tree_exited.connect(_on_execution_exited.bind(execution), CONNECT_ONE_SHOT)
		execution.context = AttackContext.new()
		execution.context.actor = actor
		execution.context.team = actor.get("team")
		execution.context.attack_id = Time.get_ticks_usec() + index
		execution.context.action = definition.charm_id
		execution.context.origin = actor.global_position
		execution.context.direction = direction
		execution.context.damage_hp = (
			_get_base_damage() * definition.get_param_float(&"damage_percent", 0.5)
		)
		execution.global_position = actor.global_position
		execution.hitbox_scale = Vector3(0.35, 1.0, 0.7)
		execution.forward_offset = 0.4
		execution.travel_speed_units_per_second = definition.get_param_float(
			&"projectile_speed", 14.0
		)
		execution.max_travel_distance = definition.get_param_float(&"range_units", 5.0)
		execution.activate()
		execution.release_after(
			execution.max_travel_distance / execution.travel_speed_units_per_second + 0.1
		)
	return not _executions.is_empty()


func cancel_active() -> void:
	for execution: CharmActiveAttack in _executions:
		if is_instance_valid(execution):
			execution.deactivate()
			execution.queue_free()
	_executions.clear()


func _get_base_damage() -> float:
	var weapon_controller := actor.get("weapon_controller") as WeaponController
	if is_instance_valid(weapon_controller) and weapon_controller.equipped != null:
		var attack := weapon_controller.equipped.get_attack(&"normal")
		if attack != null:
			return attack.damage_hp
	return 1.0


func _on_execution_exited(execution: CharmActiveAttack) -> void:
	_executions.erase(execution)
