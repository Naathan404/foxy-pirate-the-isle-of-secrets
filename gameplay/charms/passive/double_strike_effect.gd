class_name DoubleStrikeEffect
extends ProcCharmEffect
## Roll đúng một lần cho mỗi DamageContext của normal attack.


func setup(owner_actor: Node3D, charm_definition: CharmData, charm_runtime: CharmRuntime) -> bool:
	if not super.setup(owner_actor, charm_definition, charm_runtime):
		return false
	return definition.get_param_float(&"damage_multiplier", 1.0) > 1.0


func modify_outgoing_damage(amount_hp: int, damage: DamageContext) -> int:
	if damage == null or definition == null or amount_hp <= 0:
		return amount_hp
	if damage.source != actor or not damage.is_normal_attack():
		return amount_hp
	if damage.has_proc_result(definition.charm_id):
		return amount_hp
	var success := _roll_proc()
	var multiplier := definition.get_param_float(&"damage_multiplier", 1.0)
	damage.record_proc(
		definition.charm_id,
		success,
		&"normal_attack_outgoing_damage",
		multiplier if success else 1.0
	)
	return maxi(0, roundi(amount_hp * multiplier)) if success else amount_hp
