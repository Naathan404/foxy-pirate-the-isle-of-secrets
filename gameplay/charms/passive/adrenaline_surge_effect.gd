class_name AdrenalineSurgeEffect
extends ProcCharmEffect
## Player kill proc reset toàn bộ Active Charm cooldown và hồi SP.


func setup(owner_actor: Node3D, charm_definition: CharmData, charm_runtime: CharmRuntime) -> bool:
	if not super.setup(owner_actor, charm_definition, charm_runtime):
		return false
	return (
		is_instance_valid(_get_stamina_component())
		and is_instance_valid(_get_charm_manager())
		and definition.get_param_float(&"restore_sp") > 0.0
	)


func on_target_defeated(target: Node, damage: DamageContext) -> void:
	if damage == null or definition == null or not is_instance_valid(target):
		return
	if damage.source != actor or damage.target != target or not damage.target_defeated:
		return
	if damage.has_proc_result(definition.charm_id):
		return
	var success := _roll_proc()
	damage.record_proc(definition.charm_id, success, &"player_caused_target_defeat")
	if not success:
		return
	_get_charm_manager().reset_active_cooldowns()
	_get_stamina_component().restore(definition.get_param_float(&"restore_sp"))


func _get_stamina_component() -> StaminaComponent:
	return actor.get("stamina") as StaminaComponent if is_instance_valid(actor) else null


func _get_charm_manager() -> CharmSocketManager:
	return (
		actor.get("charm_socket_manager") as CharmSocketManager
		if is_instance_valid(actor)
		else null
	)
