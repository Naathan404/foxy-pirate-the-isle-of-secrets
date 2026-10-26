extends SceneTree

var _failures: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var inventory := Inventory.new()
	root.add_child(inventory)
	var potion: BaseItem = load("res://data/items/consumables/healing_potion.tres")
	var material := BaseItem.new()
	material.item_id = "test_material"
	material.display_name = "Test Material"
	material.description = "Material description"
	material.max_stack = 10
	inventory.add_item(potion, 5)
	inventory.add_item(material, 2)
	var ui = load("res://gameplay/inventory/inventory_ui.tscn").instantiate()
	ui.inventory = inventory
	root.add_child(ui)
	ui.open_inventory()
	await process_frame
	await process_frame
	_check(
		ui.selected_slot_index == -1 and ui.item_icon.texture == null, "Start without a selection"
	)

	# Đi qua hệ thống GUI thật để kiểm tra cả mouse_filter của các node con.
	_click(ui.slot_uis[0])
	_check(ui.selected_slot_index == 0, "Click slot through GUI")
	_check(ui.item_name.text == potion.display_name, "Show item name")
	_check(ui.item_description.text == potion.description, "Show description")
	_check(ui.item_icon.texture == potion.icon, "Show icon")
	_check(ui.item_quantity.text == "5", "Show quantity")
	# Click cả mép và góc của ô đang hiển thị, không chỉ tâm icon.
	var slot_rect: Rect2 = ui.slot_uis[0].get_global_rect()
	var draw_offset: Vector2 = (
		ui.grid.offset_transform_position if ui.grid.offset_transform_enabled else Vector2.ZERO
	)
	for y: float in [2.0, slot_rect.size.y / 2.0, slot_rect.size.y - 2.0]:
		for x: float in [2.0, slot_rect.size.x / 2.0, slot_rect.size.x - 2.0]:
			_click_at(slot_rect.position + draw_offset + Vector2(x, y))
			_check(
				ui.selected_slot_index == 0,
				"Click visible slot edge/corner must select its item: %s" % Vector2(x, y)
			)
	_click(ui.slot_uis[0])
	inventory.remove_from_slot(0, 2)
	_check(ui.item_quantity.text == "3", "Refresh selected quantity after removal")
	inventory.add_item(potion, 1)
	_check(ui.item_quantity.text == "4", "Refresh selected quantity after addition")
	_click(ui.slot_uis[1])
	_check(ui.item_name.text == material.display_name, "Switch selected item")
	_check(ui.item_icon.texture == null, "Item without icon clears previous icon")
	inventory.remove_from_slot(1, 2)
	_check(
		ui.selected_slot_index == -1 and ui.item_quantity.text.is_empty(),
		"Clear info after selected slot becomes empty"
	)
	_click(ui.slot_uis[0])
	_click(ui.slot_uis[2])
	_check(
		ui.selected_slot_index == -1 and ui.item_icon.texture == null,
		"Click empty slot clears selection"
	)
	ui.free()
	inventory.free()
	if _failures == 0:
		print("Inventory selection checks passed")
	quit(0 if _failures == 0 else 1)


func _click(control: Control) -> void:
	var position: Vector2 = control.get_global_rect().get_center()
	_click_at(position)


func _click_at(position: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = position
	root.push_input(motion)
	var event := InputEventMouseButton.new()
	event.position = position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	root.push_input(event)
	var release := event.duplicate() as InputEventMouseButton
	release.pressed = false
	root.push_input(release)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
