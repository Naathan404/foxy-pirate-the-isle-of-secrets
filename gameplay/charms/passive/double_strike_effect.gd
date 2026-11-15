class_name DoubleStrikeEffect
extends ProcCharmEffect
## Mỗi hit thứ tư roll đúng một lần với 50% cơ hội nhân đôi.

var _hit_count: int = 0


func setup(owner_actor: Node3D, charm_definition: CharmData, charm_runtime: CharmRuntime) -> bool:
	if not super.setup(owner_actor, charm_definition, charm_runtime):
		return false
	return definition.get_param_float(&"damage_multiplier", 1.0) > 1.0


func modify_outgoing_damage(amount_hp: float, damage: DamageContext) -> float:
	if damage == null or definition == null or amount_hp <= 0:
		return amount_hp
	if damage.source != actor or not damage.is_normal_attack():
		return amount_hp
	_hit_count += 1
	if _hit_count < definition.get_param_int(&"hit_threshold", 4):
		return amount_hp
	_hit_count = 0
	var success := _roll_proc()
	var multiplier := definition.get_param_float(&"damage_multiplier", 1.0)
	damage.record_proc(
		definition.charm_id,
		success,
		&"normal_attack_outgoing_damage",
		multiplier if success else 1.0
	)
	return maxf(0.0, amount_hp * multiplier) if success else amount_hp


func cancel_active() -> void:
	_hit_count = 0
	super.cancel_active()


func on_damage_dealt(damage: DamageContext, _target: Node, applied_hp: float) -> void:
	if damage == null or damage.source != actor or applied_hp <= 0.0:
		return
	var result: Dictionary = damage.proc_results.get(definition.charm_id, {})
	if bool(result.get(&"success", false)):
		runtime.proc_triggered.emit("DOUBLE!", Color(1.0, 0.76, 0.25))
