class_name InventorySlot
extends Resource

@export var item: BaseItem = null
@export var quantity: int = 0


func is_full() -> bool:
	if item == null:
		return false
	return quantity >= item.max_stack


func is_empty() -> bool:
	return quantity <= 0 or item == null
