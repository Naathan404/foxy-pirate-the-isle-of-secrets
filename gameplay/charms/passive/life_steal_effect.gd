class_name LifeStealEffect
extends ProcCharmEffect
## Normal attack proc hồi HP sau khi damage thực sự được áp dụng.


func setup(owner_actor: Node3D, charm_definition: CharmData, charm_runtime: CharmRuntime) -> bool:
	if not super.setup(owner_actor, charm_definition, charm_runtime):
		return false
	return is_instance_valid(_get_health_component()) and definition.get_param_int(&"heal_hp") > 0


func on_damage_dealt(damage: DamageContext, _target: Node, applied_hp: int) -> void:
	if damage == null or definition == null or applied_hp <= 0:
		return
	if damage.source != actor or not damage.is_normal_attack():
		return
	if damage.has_proc_result(definition.charm_id):
		return
	var success := _roll_proc()
	damage.record_proc(definition.charm_id, success, &"normal_attack_damage_dealt")
	if success:
		_get_health_component().heal(definition.get_param_int(&"heal_hp"))


func _get_health_component() -> HealthComponent:
	return actor.get("hp") as HealthComponent if is_instance_valid(actor) else null
