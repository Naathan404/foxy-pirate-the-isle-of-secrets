extends SceneTree

var _failures: int = 0
var _equipment_changes: Array[Potion] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var player := load("res://gameplay/player/foxy.tscn").instantiate() as Player
	root.add_child(player)
	player.set_physics_process(false)
	var inventory: Inventory = player.potion.inventory
	inventory.clear()
	var potion := (
		load("res://data/items/consumables/healing_potion.tres").duplicate() as HealingPotion
	)
	potion.max_stack = 99
	inventory.add_item(potion, 5)
	var other := potion.duplicate() as HealingPotion
	other.item_id = "test_other_healing_potion"
	inventory.add_item(other, 3)
	var material := BaseItem.new()
	material.item_id = "test_material"
	inventory.add_item(material, 1)
	var component: PotionComponent = player.potion
	component.equipped_potion_changed.connect(
		func(value: Potion) -> void: _equipment_changes.append(value)
	)
	var ui: InventoryUI = player.inventory_ui
	var equipment: EquipmentControl = player.get_node("PlayerHUD/EquipmentControl")
	ui.open_inventory()
	ui._on_slot_clicked(0)
	_check(paused and ui.is_open(), "Inventory opens while gameplay is paused")
	_check(ui.equip_potion_button.visible, "Potion offers equip action")
	_check(ui.equip_potion_button.texture_normal == ui.equip_button_texture, "Equip art shown")
	ui.equip_potion_button.pressed.emit()
	_check(component.is_equipped(potion), "Button equips selected potion")
	_check(component.is_equipped(potion.duplicate() as Potion), "Equipped check uses item ID")
	_check(ui.equip_potion_button.texture_normal == ui.unequip_button_texture, "Unequip art shown")
	_check(equipment.potion_icon.texture == potion.icon, "HUD receives equipped icon")
	_check(equipment.potion_quantity.text == "5", "HUD receives equipped quantity")
	# Unequipping during a use animation must not leave a scaled icon for the next equip.
	equipment.feedback_potion_used()
	equipment._potion_tween.pause()
	equipment._potion_tween.custom_step(0.04)
	ui.equip_potion_button.pressed.emit()
	_check(component.equipped_potion == null, "Button unequips selected potion")
	_check(component.get_equipped_quantity() == 0, "Unequipped socket has no quantity")
	_check(inventory.count_item(potion.item_id) == 5, "Unequip preserves inventory stack")
	_check(not equipment.potion_icon.visible, "Unequip hides HUD icon")
	_check(equipment.potion_icon.texture == null, "Unequip clears HUD texture")
	_check(not equipment.potion_quantity.visible, "Unequip hides HUD quantity")
	_check(equipment.potion_icon.scale == equipment._potion_rest_scale, "Icon scale is restored")
	_check(ui.equip_potion_button.texture_normal == ui.equip_button_texture, "Equip art returns")
	player.hp.current_hp = player.hp.get_max_hp() - 2
	var hp_before: int = player.hp.current_hp
	_check(not component.use_equipped_potion(), "Potion shortcut cannot use unequipped potion")
	_check(player.hp.current_hp == hp_before, "Unequipped potion does not heal")
	_check(inventory.count_item(potion.item_id) == 5, "Failed use consumes nothing")
	var changes_before := _equipment_changes.size()
	_check(not component.unequip_potion(), "Unequip empty socket is a no-op")
	_check(_equipment_changes.size() == changes_before, "Empty unequip emits no duplicate change")
	ui.equip_potion_button.pressed.emit()
	_check(component.is_equipped(potion) and equipment.potion_icon.visible, "Potion can re-equip")
	ui._on_slot_clicked(1)
	_check(
		ui.equip_potion_button.texture_normal == ui.equip_button_texture, "Other potion can equip"
	)
	ui.equip_potion_button.pressed.emit()
	_check(component.is_equipped(other), "Different potion replaces equipped selection")
	_check(equipment.potion_quantity.text == "3", "Switch potion updates HUD quantity")
	component.unequip_potion()
	_check(
		ui.equip_potion_button.texture_normal == ui.equip_button_texture,
		"External unequip syncs UI"
	)
	_check(_equipment_changes.back() == null, "Unequip signal carries null")
	ui._on_slot_clicked(2)
	_check(not ui.equip_potion_button.visible, "Material hides potion action")
	ui._on_slot_clicked(3)
	_check(not ui.equip_potion_button.visible, "Empty slot hides potion action")
	_check(inventory.count_item(other.item_id) == 3, "Switch and unequip preserve other stack")
	ui.close_inventory(true)
	player.free()
	if _failures == 0:
		print("Potion equip/unequip button, HUD, signals, quantity and animation cleanup passed")
	quit(0 if _failures == 0 else 1)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
