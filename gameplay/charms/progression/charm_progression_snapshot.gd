class_name CharmProgressionSnapshot
extends RefCounted
## Adapter serialize thuần Dictionary; save system tương lai chỉ cần ghi/đọc payload này.

const VERSION := 1


static func capture(manager: CharmSocketManager, registry: CharmRegistry) -> Dictionary:
	if (
		not is_instance_valid(manager)
		or not is_instance_valid(registry)
		or manager.registry != registry
	):
		return {}
	var owned_ids: Array[String] = []
	for charm_id: StringName in registry.get_owned_ids():
		owned_ids.append(String(charm_id))
	var equipped_ids: Array[String] = []
	for socket_id: int in range(CharmConstants.MAX_SOCKET_COUNT):
		equipped_ids.append(String(manager.get_equipped_charm(socket_id)))
	return {
		"version": VERSION,
		"unlocked_socket_count": manager.get_unlocked_socket_count(),
		"owned_charm_ids": owned_ids,
		"equipped_charm_ids": equipped_ids,
	}


static func restore(
	payload: Dictionary, manager: CharmSocketManager, registry: CharmRegistry
) -> bool:
	if (
		payload.is_empty()
		or not is_instance_valid(manager)
		or not is_instance_valid(registry)
		or manager.registry != registry
		or not is_instance_valid(manager.actor)
	):
		return false
	var unlocked_count := clampi(
		int(payload.get("unlocked_socket_count", CharmConstants.STARTING_SOCKET_COUNT)),
		CharmConstants.STARTING_SOCKET_COUNT,
		CharmConstants.MAX_SOCKET_COUNT
	)
	var valid_owned := _read_valid_owned_ids(payload.get("owned_charm_ids", []), registry)
	for charm_id: StringName in registry.get_owned_ids():
		registry.set_owned(charm_id, false)
	for charm_id: StringName in valid_owned:
		registry.set_owned(charm_id, true)
	var equipped := _read_valid_equipped_ids(
		payload.get("equipped_charm_ids", []), unlocked_count, registry
	)
	return manager.restore_progression(unlocked_count, equipped)


static func _read_valid_owned_ids(value: Variant, registry: CharmRegistry) -> Array[StringName]:
	var result: Array[StringName] = []
	var seen: Dictionary[StringName, bool] = {}
	if not value is Array:
		return result
	for raw_id: Variant in value:
		var charm_id := StringName(String(raw_id))
		if charm_id.is_empty() or seen.has(charm_id):
			continue
		if registry.get_definition(charm_id) == null:
			continue
		seen[charm_id] = true
		result.append(charm_id)
	result.sort()
	return result


static func _read_valid_equipped_ids(
	value: Variant, unlocked_count: int, registry: CharmRegistry
) -> Dictionary[int, StringName]:
	var result: Dictionary[int, StringName] = {}
	var seen: Dictionary[StringName, bool] = {}
	if not value is Array:
		return result
	var source := value as Array
	for socket_id: int in range(mini(unlocked_count, source.size())):
		var charm_id := StringName(String(source[socket_id]))
		if charm_id.is_empty() or seen.has(charm_id):
			continue
		if not registry.is_owned(charm_id):
			continue
		seen[charm_id] = true
		result[socket_id] = charm_id
	return result
