class_name CharmLoadout
extends Resource
## Dữ liệu loadout có thể lưu bằng stable Charm ID.

@export_range(1, CharmConstants.MAX_SOCKET_COUNT, 1)
var unlocked_socket_count: int = CharmConstants.STARTING_SOCKET_COUNT
@export var equipped_charm_ids: Dictionary[int, StringName] = {}


func normalize() -> void:
	unlocked_socket_count = clampi(
		unlocked_socket_count, CharmConstants.STARTING_SOCKET_COUNT, CharmConstants.MAX_SOCKET_COUNT
	)
	var invalid_socket_ids: Array[int] = []
	for socket_id: int in equipped_charm_ids.keys():
		if socket_id < 0 or socket_id >= CharmConstants.MAX_SOCKET_COUNT:
			invalid_socket_ids.append(socket_id)
		elif socket_id >= unlocked_socket_count:
			invalid_socket_ids.append(socket_id)
	for socket_id: int in invalid_socket_ids:
		equipped_charm_ids.erase(socket_id)


func set_equipped_charm(socket_id: int, charm_id: StringName) -> bool:
	if socket_id < 0 or socket_id >= unlocked_socket_count:
		return false
	if charm_id.is_empty():
		equipped_charm_ids.erase(socket_id)
	else:
		equipped_charm_ids[socket_id] = charm_id
	return true


func get_equipped_charm(socket_id: int) -> StringName:
	return equipped_charm_ids.get(socket_id, &"") as StringName
