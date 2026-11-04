class_name ChaosCollectorEffect
extends CharmEffect
## Adds a fixed amount of Chaos for every confirmed Player normal-attack hit.


func setup(owner_actor: Node3D, charm_definition: CharmData, charm_runtime: CharmRuntime) -> bool:
	if not super.setup(owner_actor, charm_definition, charm_runtime):
		return false
	return (
		is_instance_valid(_get_chaos()) and definition.get_param_float(&"chaos_per_hit", 2.0) > 0.0
	)


func on_damage_dealt(damage: DamageContext, _target: Node, applied_hp: float) -> void:
	if (
		damage == null
		or applied_hp <= 0.0
		or damage.source != actor
		or not damage.is_normal_attack()
	):
		return
	_get_chaos().gain(definition.get_param_float(&"chaos_per_hit", 2.0))


func _get_chaos() -> ChaosComponent:
	return actor.get("chaos") as ChaosComponent if is_instance_valid(actor) else null
