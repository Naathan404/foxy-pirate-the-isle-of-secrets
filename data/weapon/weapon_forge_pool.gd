class_name WeaponForgePool
extends Resource
## Shared catalog: group labels describe tradeoffs and never restrict weapon eligibility.

@export var forges: Array[WeaponForge] = []


func is_valid() -> bool:
	if forges.is_empty():
		return false
	var ids: Dictionary[StringName, bool] = {}
	for forge: WeaponForge in forges:
		if forge == null or not forge.is_valid() or ids.has(forge.forge_id):
			return false
		ids[forge.forge_id] = true
	return true


func get_forge(forge_id: StringName) -> WeaponForge:
	for forge: WeaponForge in forges:
		if forge != null and forge.forge_id == forge_id:
			return forge
	return null


## Returns a shared, read-only definition, or null for invalid/disabled pools.
## Passing the RNG explicitly allows deterministic rolls and avoids global random state.
func roll(random: RandomNumberGenerator) -> WeaponForge:
	if random == null or not is_valid():
		return null
	var total_weight: float = 0.0
	for forge: WeaponForge in forges:
		total_weight += forge.drop_weight
	if total_weight <= 0.0 or not is_finite(total_weight):
		return null
	var remaining := random.randf() * total_weight
	var last_enabled: WeaponForge
	for forge: WeaponForge in forges:
		if forge.drop_weight <= 0.0:
			continue
		last_enabled = forge
		remaining -= forge.drop_weight
		if remaining < 0.0:
			return forge
	return last_enabled
