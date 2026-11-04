class_name PotionComponent
extends Node

signal equipped_potion_changed(potion: Potion)
signal secondary_potion_changed(potion: Potion)
signal potion_used

@export var inventory: Inventory
@export var health: HealthComponent
@export var stamina: StaminaComponent

# loai binh dang duoc su dung vao socket
var equipped_potion: Potion
var secondary_potion: Potion


func equip_potion(potion: Potion) -> bool:
	if not _can_equip(potion):
		return false
	if is_equipped(potion):
		return true
	if is_secondary_equipped(potion):
		return swap_potions()
	var previous: Potion = equipped_potion
	equipped_potion = potion
	secondary_potion = previous
	equipped_potion_changed.emit(potion)
	secondary_potion_changed.emit(secondary_potion)
	return true


func equip_secondary_potion(potion: Potion) -> bool:
	if not _can_equip(potion):
		return false
	if is_equipped(potion):
		return swap_potions()
	secondary_potion = potion
	secondary_potion_changed.emit(potion)
	return true


func _can_equip(potion: Potion) -> bool:
	if potion == null or inventory == null:
		return false
	if potion is HealingPotion and health == null:
		return false
	if potion is StaminaPotion and stamina == null:
		return false
	if potion is DualEssencePotion and (health == null or stamina == null):
		return false

	if not inventory.has_item(potion.item_id):
		return false

	return true


func is_secondary_equipped(potion: Potion) -> bool:
	return (
		potion != null and secondary_potion != null and secondary_potion.item_id == potion.item_id
	)


func unequip_secondary_potion() -> bool:
	if secondary_potion == null:
		return false
	secondary_potion = null
	secondary_potion_changed.emit(null)
	return true


## Swap only the two assigned resources, including empty/depleted slots.
func swap_potions() -> bool:
	if equipped_potion == null and secondary_potion == null:
		return false
	var previous: Potion = equipped_potion
	equipped_potion = secondary_potion
	secondary_potion = previous
	# Commit both slots before notifying consumers.
	equipped_potion_changed.emit(equipped_potion)
	secondary_potion_changed.emit(secondary_potion)
	return true


func get_secondary_quantity() -> int:
	if secondary_potion == null or inventory == null:
		return 0
	return inventory.count_item(secondary_potion.item_id)


func is_equipped(potion: Potion) -> bool:
	return potion != null and equipped_potion != null and equipped_potion.item_id == potion.item_id


func unequip_potion() -> bool:
	if equipped_potion == null:
		return false
	equipped_potion = secondary_potion
	secondary_potion = null
	equipped_potion_changed.emit(equipped_potion)
	secondary_potion_changed.emit(null)
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
		var healed: float = health.heal(used_potion.heal_amount)
		if healed <= 0:
			return false

	elif equipped_potion is StaminaPotion:
		if stamina == null:
			return false
		var used_potion := equipped_potion as StaminaPotion
		if stamina.restore(used_potion.restore_amount) <= 0.0:
			return false
	elif equipped_potion is DualEssencePotion:
		if not _use_dual_essence(equipped_potion as DualEssencePotion):
			return false
	else:
		return false

	inventory.remove_item(equipped_potion.item_id, 1)
	potion_used.emit()
	return true


func _use_dual_essence(potion: DualEssencePotion) -> bool:
	if health == null or stamina == null or not health.is_alive():
		return false
	# Always attempt both effects; a full bar must not prevent restoring the other.
	var healed: float = health.heal(potion.heal_amount)
	var restored: float = stamina.restore(potion.stamina_amount)
	return healed > 0.0 or restored > 0.0
