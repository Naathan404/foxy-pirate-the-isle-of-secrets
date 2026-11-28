class_name BackstabberEffect
extends CharmEffect
## Tăng damage cho melee normal attack khi origin nằm ở nửa sau hướng nhìn target.


func setup(owner_actor: Node3D, charm_definition: CharmData, charm_runtime: CharmRuntime) -> bool:
	if not super.setup(owner_actor, charm_definition, charm_runtime):
		return false
	return definition.get_param_float(&"damage_multiplier", 1.0) > 1.0


func modify_outgoing_damage(amount_hp: float, damage: DamageContext) -> float:
	if damage == null or definition == null or amount_hp <= 0:
		return amount_hp
	if damage.source != actor or not damage.is_melee_normal_attack():
		return amount_hp
	if damage.has_proc_result(definition.charm_id):
		return amount_hp
	var is_behind := _is_behind_target(damage)
	var multiplier := definition.get_param_float(&"damage_multiplier", 1.0)
	damage.record_proc(
		definition.charm_id,
		is_behind,
		&"behind_melee_normal_attack" if is_behind else &"outside_backstab_arc",
		multiplier if is_behind else 1.0
	)
	return maxf(0.0, amount_hp * multiplier) if is_behind else amount_hp


func on_damage_dealt(damage: DamageContext, target: Node, applied_hp: float) -> void:
	if damage == null or damage.source != actor or applied_hp <= 0.0:
		return
	var result: Dictionary = damage.proc_results.get(definition.charm_id, {})
	if bool(result.get(&"success", false)):
		runtime.proc_triggered.emit("BACKSTAB", Color(0.8, 0.55, 1.0))
		if target is Node3D:
			# A cut across the back of the target.
			var at := (target as Node3D).global_position + Vector3.UP * 0.7
			var across := Vector3(0.9, 0.35, 0.0)
			CharmVfx.streak(actor.get_parent(), at - across, at + across, CharmVfx.SHADOW, 0.5)
			CharmFeel.local_hitstop(actor, null, target as Node3D, 0.06)
			CharmFeel.shake(actor, 3.0, 0.1)


func _is_behind_target(damage: DamageContext) -> bool:
	var target := damage.target as Node3D
	if not is_instance_valid(target):
		return false
	var facing := Vector3.ZERO
	if target is EnemyBase:
		facing = (target as EnemyBase).last_facing_direction
	elif target.has_method("get_facing_direction"):
		facing = target.call("get_facing_direction") as Vector3
	else:
		return false
	var to_attacker := damage.origin - target.global_position
	facing.y = 0.0
	to_attacker.y = 0.0
	if facing.is_zero_approx() or to_attacker.is_zero_approx():
		return false
	var threshold := definition.get_param_float(&"behind_dot_threshold", 0.0)
	return facing.normalized().dot(to_attacker.normalized()) < threshold
