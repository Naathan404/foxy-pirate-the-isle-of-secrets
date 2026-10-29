class_name PotionComponent
extends Node

signal equipped_potion_changed(potion: Potion)
signal potion_used

@export var inventory: Inventory
@export var health: HealthComponent
@export var stamina: StaminaComponent

# loai binh dang duoc su dung vao socket
var equipped_potion: Potion


func equip_potion(potion: Potion) -> bool:
	if potion == null or inventory == null:
		return false
	if potion is HealingPotion and health == null:
		return false
	if potion is StaminaPotion and stamina == null:
		return false

	if not inventory.has_item(potion.item_id):
		return false

	equipped_potion = potion

	equipped_potion_changed.emit(potion)

	return true


func is_equipped(potion: Potion) -> bool:
	return potion != null and equipped_potion != null and equipped_potion.item_id == potion.item_id


func unequip_potion() -> bool:
	if equipped_potion == null:
		return false
	equipped_potion = null
	equipped_potion_changed.emit(null)
	return true


func get_equipped_quantity() -> int:
	if equipped_potion == null or inventory == null:
		return 0

	var count = inventory.count_item(equipped_potion.item_id)
	return count


func use_equipped_potion() -> bool:
	if equipped_potion == null or inventory == null:
		return false
	if get_equipped_quantity() <= 0:
		return false

	if equipped_potion is HealingPotion:
		if health == null:
			return false
		var used_potion = equipped_potion as HealingPotion
		var healed: int = health.heal(used_potion.heal_amount)
		if healed <= 0:
			return false

	elif equipped_potion is StaminaPotion:
		if stamina == null:
			return false
		var used_potion := equipped_potion as StaminaPotion
		if stamina.restore(used_potion.restore_amount) <= 0.0:
			return false
	else:
		return false

	inventory.remove_item(equipped_potion.item_id, 1)
	potion_used.emit()
	return true
