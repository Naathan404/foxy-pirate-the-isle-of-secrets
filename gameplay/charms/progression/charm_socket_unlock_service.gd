class_name CharmSocketUnlockService
extends RefCounted
## Mua socket qua economy adapter; rollback nếu unlock bất ngờ thất bại.

signal purchase_succeeded(cost: int, unlocked_socket_count: int)
signal purchase_rejected(reason: StringName)


func purchase_next_socket(
	manager: CharmSocketManager, economy: CharmEconomyAdapter, cost: int
) -> bool:
	if not is_instance_valid(manager) or economy == null or cost < 0:
		purchase_rejected.emit(&"invalid_request")
		return false
	if not manager.can_change_loadout():
		purchase_rejected.emit(&"unsafe_location")
		return false
	if not manager.can_unlock_next_socket():
		purchase_rejected.emit(&"max_socket_count")
		return false
	if not economy.can_afford(cost):
		purchase_rejected.emit(&"insufficient_funds")
		return false
	if not economy.try_spend(cost):
		purchase_rejected.emit(&"economy_rejected")
		return false
	if not manager.unlock_next_socket():
		economy.refund(cost)
		purchase_rejected.emit(&"unlock_failed")
		return false
	purchase_succeeded.emit(cost, manager.get_unlocked_socket_count())
	return true
