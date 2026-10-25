class_name CharmAcquisitionService
extends RefCounted
## Acquisition dựa hoàn toàn trên metadata của CharmData đã đăng ký/playable.

const SHOP_SOURCES: Array[StringName] = [&"shop", &"merchant_or_enemy_drop"]


func grant_fixed_boss_reward(registry: CharmRegistry, charm_id: StringName) -> bool:
	if not is_instance_valid(registry):
		return false
	var definition := registry.get_definition(charm_id)
	if not _is_playable(definition) or definition.acquisition_source != &"fixed_boss_reward":
		return false
	return registry.set_owned(charm_id, true)


func get_shop_pool(registry: CharmRegistry, include_owned: bool = false) -> Array[CharmData]:
	var result: Array[CharmData] = []
	if not is_instance_valid(registry):
		return result
	for charm_id: StringName in registry.get_registered_ids():
		var definition := registry.get_definition(charm_id)
		if not _is_shop_eligible(definition):
			continue
		if not include_owned and registry.is_owned(charm_id):
			continue
		result.append(definition)
	result.sort_custom(
		func(left: CharmData, right: CharmData) -> bool: return left.charm_id < right.charm_id
	)
	return result


func roll_shop_offer(
	registry: CharmRegistry, random: RandomNumberGenerator, include_owned: bool = false
) -> CharmData:
	if random == null:
		return null
	var pool := get_shop_pool(registry, include_owned)
	if pool.is_empty():
		return null
	return pool[random.randi_range(0, pool.size() - 1)]


func _is_shop_eligible(definition: CharmData) -> bool:
	return (
		_is_playable(definition)
		and definition.is_passive()
		and SHOP_SOURCES.has(definition.acquisition_source)
	)


func _is_playable(definition: CharmData) -> bool:
	return (
		definition != null
		and definition.effect_scene != null
		and CharmValidator.validate_data(definition).is_empty()
	)
