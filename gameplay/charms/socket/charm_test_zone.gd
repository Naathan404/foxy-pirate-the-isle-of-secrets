class_name CharmTestZone
extends Node
## Cấu hình loadout kiểm thử để test_scene luôn có một Charm hoạt động.

signal test_charm_equipped(charm_id: StringName)

@export var player: Player
@export var starting_charm_id: StringName = &"gale_pace"


func _ready() -> void:
	_configure_test_loadout.call_deferred()


func _configure_test_loadout() -> void:
	if not is_instance_valid(player) or not is_instance_valid(player.charm_socket_manager):
		push_error("CharmTestZone: Player and CharmSocketManager are required")
		return
	var manager := player.charm_socket_manager
	var registry := manager.registry
	if not is_instance_valid(registry):
		push_error("CharmTestZone: CharmRegistry is required")
		return
	if manager.get_unlocked_socket_count() != CharmConstants.STARTING_SOCKET_COUNT:
		push_error("CharmTestZone: Player must start with exactly one unlocked socket")
		return
	var definition := registry.get_definition(starting_charm_id)
	if definition == null:
		push_error("CharmTestZone: starting Charm is not registered")
		return
	var previous_max_hp := player.hp.get_max_hp()
	var previous_max_sp := player.stamina.get_max_sp()
	if not registry.set_owned(starting_charm_id, true):
		push_error("CharmTestZone: failed to grant starting Charm")
		return
	manager.set_safe_location(true)
	if not manager.equip_charm(starting_charm_id, CharmConstants.SocketId.Q):
		push_error("CharmTestZone: failed to equip starting Charm")
		return
	if not _validate_equipped_effect(manager, definition, previous_max_hp, previous_max_sp):
		return
	if not manager.unequip_charm(CharmConstants.SocketId.Q):
		push_error("CharmTestZone: failed to unequip starting Charm")
		return
	if not _validate_removed_effect(manager, previous_max_hp, previous_max_sp):
		return
	if not manager.equip_charm(starting_charm_id, CharmConstants.SocketId.Q):
		push_error("CharmTestZone: failed to re-equip starting Charm")
		return
	if not _validate_equipped_effect(manager, definition, previous_max_hp, previous_max_sp):
		return
	test_charm_equipped.emit(starting_charm_id)
	print("Charm test zone ready: 1 socket, %s equip/unequip passed on Q" % starting_charm_id)


func _validate_equipped_effect(
	manager: CharmSocketManager, definition: CharmData, previous_max_hp: int, previous_max_sp: float
) -> bool:
	if manager.get_equipped_charm(CharmConstants.SocketId.Q) != definition.charm_id:
		push_error("CharmTestZone: socket Q does not contain the starting Charm")
		return false
	var expected_max_hp := previous_max_hp + definition.get_param_int(&"max_hp_flat")
	var expected_max_sp := previous_max_sp + definition.get_param_float(&"max_sp_flat")
	if player.hp.get_max_hp() != maxi(1, expected_max_hp):
		push_error("CharmTestZone: starting Charm max HP modifier was not applied")
		return false
	if not is_equal_approx(player.stamina.get_max_sp(), maxf(0.0, expected_max_sp)):
		push_error("CharmTestZone: starting Charm max SP modifier was not applied")
		return false
	var stats: Dictionary[StringName, float] = {
		&"move_speed_flat": 0.0,
		&"move_speed_multiplier": 1.0,
	}
	manager.modify_stats(stats)
	var expected_flat := definition.get_param_float(&"move_speed_flat")
	var expected_multiplier := definition.get_param_float(&"move_speed_multiplier", 1.0)
	if not is_equal_approx(stats[&"move_speed_flat"], expected_flat):
		push_error("CharmTestZone: starting Charm flat speed modifier was not applied")
		return false
	if not is_equal_approx(stats[&"move_speed_multiplier"], expected_multiplier):
		push_error("CharmTestZone: starting Charm speed multiplier was not applied")
		return false
	return true


func _validate_removed_effect(
	manager: CharmSocketManager, previous_max_hp: int, previous_max_sp: float
) -> bool:
	if not manager.get_equipped_charm(CharmConstants.SocketId.Q).is_empty():
		push_error("CharmTestZone: socket Q was not cleared")
		return false
	if player.hp.get_max_hp() != previous_max_hp:
		push_error("CharmTestZone: max HP modifier was not removed")
		return false
	if not is_equal_approx(player.stamina.get_max_sp(), previous_max_sp):
		push_error("CharmTestZone: max SP modifier was not removed")
		return false
	var stats: Dictionary[StringName, float] = {
		&"move_speed_flat": 0.0,
		&"move_speed_multiplier": 1.0,
	}
	manager.modify_stats(stats)
	if not is_zero_approx(stats[&"move_speed_flat"]):
		push_error("CharmTestZone: flat speed modifier was not removed")
		return false
	if not is_equal_approx(stats[&"move_speed_multiplier"], 1.0):
		push_error("CharmTestZone: speed multiplier was not removed")
		return false
	return true
