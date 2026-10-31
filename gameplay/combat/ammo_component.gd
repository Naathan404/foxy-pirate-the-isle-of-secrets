class_name AmmoComponent
extends Node

signal ammo_changed(item_id: StringName, ammount: int)

## Inventory is the source of truth when assigned; standalone actors can keep their counter.
@export var inventory: Inventory
@export var ammo_items: Array[BaseItem] = []

# khởi tạo đạn
@export var initial_ammo: Dictionary[StringName, int] = {}
# số đạn mỗi loại: arrow vs bullet
var _amounts: Dictionary[StringName, int] = {}


func _ready() -> void:
	if is_instance_valid(inventory):
		inventory.changed.connect(_on_inventory_changed)
		for item_id: StringName in initial_ammo:
			add_ammo(item_id, initial_ammo[item_id])
		return
	for item_id: StringName in initial_ammo:
		_amounts[item_id] = maxi(0, initial_ammo[item_id])


func get_amount(item_id: StringName) -> int:
	if is_instance_valid(inventory):
		return inventory.count_item(item_id)
	return _amounts.get(item_id, 0)


func can_consume(item_id: StringName, amount: int) -> bool:
	return amount >= 0 and get_amount(item_id) >= amount


func try_consume(item_id: StringName, amount: int) -> bool:
	if not can_consume(item_id, amount):
		return false
	if is_instance_valid(inventory):
		return inventory.remove_item(item_id, amount) == amount
	if amount > 0:
		_amounts[item_id] = get_amount(item_id) - amount
		ammo_changed.emit(item_id, _amounts[item_id])
	return true


func add_ammo(item_id: StringName, amount: int) -> void:
	if amount <= 0 or item_id.is_empty():
		return
	if is_instance_valid(inventory):
		for item: BaseItem in ammo_items:
			if item != null and item.item_id == item_id:
				if inventory.add_item(item, amount) > 0:
					push_warning("AmmoComponent: inventory cannot hold all added ammo")
				return
		push_warning("AmmoComponent: unknown inventory ammo item " + String(item_id))
		return
	_amounts[item_id] = get_amount(item_id) + amount
	ammo_changed.emit(item_id, _amounts[item_id])


func _on_inventory_changed() -> void:
	for item: BaseItem in ammo_items:
		if item != null:
			ammo_changed.emit(StringName(item.item_id), get_amount(StringName(item.item_id)))
