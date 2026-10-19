class_name AmmoComponent
extends Node

signal ammo_changed(item_id: StringName, ammount: int)

# khởi tạo đạn
@export var initial_ammo: Dictionary[StringName, int] = {}
# số đạn mỗi loại: arrow vs bullet
var _amounts: Dictionary[StringName, int] = {}


func _ready() -> void:
	for item_id: StringName in initial_ammo:
		_amounts[item_id] = maxi(0, initial_ammo[item_id])


func get_amount(item_id: StringName) -> int:
	return _amounts.get(item_id, 0)


func can_consume(item_id: StringName, amount: int) -> bool:
	return amount >= 0 and get_amount(item_id) >= amount


func try_consume(item_id: StringName, amount: int) -> bool:
	if not can_consume(item_id, amount):
		return false
	if amount > 0:
		_amounts[item_id] = get_amount(item_id) - amount
		ammo_changed.emit(item_id, _amounts[item_id])
	return true


func add_ammo(item_id: StringName, amount: int) -> void:
	if amount > 0 and not item_id.is_empty():
		_amounts[item_id] = get_amount(item_id) + amount
		ammo_changed.emit(item_id, _amounts[item_id])
