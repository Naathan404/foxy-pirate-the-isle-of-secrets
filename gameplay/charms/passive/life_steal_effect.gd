class_name LifeStealEffect
extends ProcCharmEffect
## Mỗi hit normal attack hợp lệ thứ 12 hồi HP sau khi damage thực sự được áp dụng.

var _hit_count: int = 0


func setup(owner_actor: Node3D, charm_definition: CharmData, charm_runtime: CharmRuntime) -> bool:
	if not super.setup(owner_actor, charm_definition, charm_runtime):
		return false
	return is_instance_valid(_get_health_component()) and definition.get_param_float(&"heal_hp") > 0


func on_damage_dealt(damage: DamageContext, _target: Node, applied_hp: float) -> void:
	if damage == null or definition == null or applied_hp <= 0:
		return
	if damage.source != actor or not damage.is_normal_attack():
		return
	_hit_count += 1
	if _hit_count < definition.get_param_int(&"hit_threshold", 12):
		return
	_hit_count = 0
	_get_health_component().heal(definition.get_param_float(&"heal_hp"))


func cancel_active() -> void:
	_hit_count = 0
	super.cancel_active()


func _get_health_component() -> HealthComponent:
	return actor.get("hp") as HealthComponent if is_instance_valid(actor) else null
