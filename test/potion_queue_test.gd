extends SceneTree

const SMALL_HEALTH: Potion = preload("res://data/items/consumables/small_healing_potion.tres")
const LARGE_HEALTH: Potion = preload("res://data/items/consumables/healing_potion.tres")
const SMALL_STAMINA: Potion = preload("res://data/items/consumables/small_stamina_potion.tres")
const INVENTORY_UI: PackedScene = preload("res://gameplay/inventory/inventory_ui.tscn")


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var inventory := Inventory.new()
	root.add_child(inventory)
	var potions := PotionComponent.new()
	potions.inventory = inventory
	potions.health = HealthComponent.new()
	potions.stamina = StaminaComponent.new()
	root.add_child(potions)
	for item: Potion in [SMALL_HEALTH, LARGE_HEALTH, SMALL_STAMINA]:
		assert(inventory.add_item(item, 1) == 0)
	var ui := INVENTORY_UI.instantiate() as InventoryUI
	ui.inventory = inventory
	ui.potion_component = potions
	root.add_child(ui)

	assert(potions.equip_potion(SMALL_HEALTH))
	assert(potions.equipped_potion == SMALL_HEALTH and potions.secondary_potion == null)
	assert(ui.slot_uis[0].potion_assignment_label.text == "MAIN")
	assert(inventory.move_item(0, 3))
	assert(ui.slot_uis[0].potion_assignment_label.text == "")
	assert(ui.slot_uis[3].potion_assignment_label.text == "MAIN")
	assert(inventory.move_item(3, 0))
	assert(potions.equip_potion(LARGE_HEALTH))
	assert(potions.equipped_potion == LARGE_HEALTH and potions.secondary_potion == SMALL_HEALTH)
	assert(ui.slot_uis[0].potion_assignment_label.text == "BACKUP")
	assert(ui.slot_uis[1].potion_assignment_label.text == "MAIN")
	assert(potions.equip_potion(SMALL_STAMINA))
	assert(potions.equipped_potion == SMALL_STAMINA and potions.secondary_potion == LARGE_HEALTH)
	assert(ui.slot_uis[0].potion_assignment_label.text == "")
	assert(ui.slot_uis[1].potion_assignment_label.text == "BACKUP")
	assert(ui.slot_uis[2].potion_assignment_label.text == "MAIN")
	assert(potions.equip_potion(LARGE_HEALTH))
	assert(potions.equipped_potion == LARGE_HEALTH and potions.secondary_potion == SMALL_STAMINA)
	assert(potions.equip_potion(LARGE_HEALTH))
	assert(potions.equipped_potion == LARGE_HEALTH and potions.secondary_potion == SMALL_STAMINA)
	assert(potions.unequip_potion())
	assert(potions.equipped_potion == SMALL_STAMINA and potions.secondary_potion == null)
	assert(potions.unequip_potion())
	assert(potions.equipped_potion == null and potions.secondary_potion == null)
	assert(ui.slot_uis[2].potion_assignment_label.text == "")
	ui.free()
	potions.health.free()
	potions.stamina.free()
	potions.free()
	inventory.free()
	print("Potion queue passed")
	quit()
