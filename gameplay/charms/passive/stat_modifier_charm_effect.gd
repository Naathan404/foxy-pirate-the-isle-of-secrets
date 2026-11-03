class_name StatModifierCharmEffect
extends CharmEffect
## Áp dụng stat modifier bằng stable Charm ID để từng nguồn có thể được tháo riêng.

var _applied: bool = false


func setup(owner_actor: Node3D, charm_definition: CharmData, charm_runtime: CharmRuntime) -> bool:
	if not super.setup(owner_actor, charm_definition, charm_runtime):
		return false
	var max_hp_flat := definition.get_param_float(&"max_hp_flat")
	var max_sp_flat := definition.get_param_float(&"max_sp_flat")
	var move_speed_flat := definition.get_param_float(&"move_speed_flat")
	var move_speed_multiplier := definition.get_param_float(&"move_speed_multiplier", 1.0)
	if max_hp_flat == 0 and is_zero_approx(max_sp_flat):
		if is_zero_approx(move_speed_flat) and is_equal_approx(move_speed_multiplier, 1.0):
			return false
	if max_hp_flat != 0 and not is_instance_valid(_get_health_component()):
		return false
	if not is_zero_approx(max_sp_flat) and not is_instance_valid(_get_stamina_component()):
		return false
	if move_speed_multiplier < 0.0:
		return false
	return true


func on_equipped() -> void:
	if _applied or definition == null:
		return
	var source := definition.charm_id
	var health := _get_health_component()
	var stamina := _get_stamina_component()
	var max_hp_flat := definition.get_param_float(&"max_hp_flat")
	var max_sp_flat := definition.get_param_float(&"max_sp_flat")
	if max_hp_flat != 0:
		health.set_max_hp_modifier(source, max_hp_flat)
	if not is_zero_approx(max_sp_flat):
		stamina.set_max_sp_modifier(source, max_sp_flat)
	_applied = true


func on_unequipped() -> void:
	cancel_active()


func modify_stats(stats: Dictionary[StringName, float]) -> void:
	if not _applied or definition == null:
		return
	var flat_bonus := definition.get_param_float(&"move_speed_flat")
	var multiplier := definition.get_param_float(&"move_speed_multiplier", 1.0)
	stats[&"move_speed_flat"] = float(stats.get(&"move_speed_flat", 0.0)) + flat_bonus
	stats[&"move_speed_multiplier"] = (float(stats.get(&"move_speed_multiplier", 1.0)) * multiplier)


func cancel_active() -> void:
	if not _applied or definition == null:
		return
	var source := definition.charm_id
	var health := _get_health_component()
	var stamina := _get_stamina_component()
	if is_instance_valid(health):
		health.remove_max_hp_modifier(source)
	if is_instance_valid(stamina):
		stamina.remove_max_sp_modifier(source)
	_applied = false


func _get_health_component() -> HealthComponent:
	return actor.get("hp") as HealthComponent if is_instance_valid(actor) else null


func _get_stamina_component() -> StaminaComponent:
	return actor.get("stamina") as StaminaComponent if is_instance_valid(actor) else null
