extends SceneTree

var _failures: int = 0
var _mouse_position: Vector2 = Vector2.ZERO


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	root.size = Vector2i(1280, 720)
	var inventory := Inventory.new()
	root.add_child(inventory)
	var potion: BaseItem = load("res://data/items/consumables/healing_potion.tres")
	potion = potion.duplicate() as BaseItem
	potion.max_stack = 99
	inventory.add_item(potion, 5)
	var ui := load("res://gameplay/inventory/inventory_ui.tscn").instantiate() as InventoryUI
	ui.inventory = inventory
	root.add_child(ui)
	ui.open_inventory()
	ui._transition_tween.pause()
	ui._transition_tween.custom_step(ui.open_duration / 2.0)
	_check(paused and ui.panel.modulate.a > 0.0, "Opening tween runs while world is paused")
	_check(ui.panel.modulate.a < 1.0, "Opening fades in")
	ui._transition_tween.custom_step(ui.open_duration)
	await process_frame
	await process_frame
	var slot: InventorySlotUI = ui.slot_uis[0]
	var slot_rect: Rect2 = slot.get_global_rect()
	_motion(slot_rect.get_center())
	_finish_slot_tween(slot)
	_check(slot.content.scale.x > 1.0, "Hover scales visual content")
	_check(slot.get_global_rect() == slot_rect, "Hover keeps hit region fixed")
	_button(slot_rect.get_center(), true)
	_finish_slot_tween(slot)
	_check(slot.content.scale.x < 1.0, "Press scales down")
	_check(ui.selected_slot_index == 0 and slot._highlight.visible, "Selection gets highlight")
	_button(slot_rect.get_center(), false)
	_finish_slot_tween(slot)
	_check(slot.content.scale.x > 1.0, "Release restores hover scale")
	await _check_drag(ui, inventory)

	ui.close_inventory()
	_check(ui._is_closing and paused, "Keep world paused until closing finishes")
	ui._transition_tween.pause()
	ui._transition_tween.custom_step(ui.close_duration / 2.0)
	ui.toggle_inventory()
	_check(ui.is_open() and not ui._is_closing and paused, "Reopen interrupts close safely")
	ui.close_inventory()
	ui._transition_tween.pause()
	ui._transition_tween.custom_step(ui.close_duration + 0.01)
	_check(not ui.visible and not ui.is_open() and not paused, "Closing releases pause")
	_check(slot.content.scale == slot._content_scale, "Closing clears transient slot scale")
	ui.open_inventory()
	ui.close_inventory(true)
	_check(not paused and not ui.visible, "Forced close is immediate for death/reload")
	ui.free()
	inventory.free()
	if _failures == 0:
		print("Inventory feedback, hit regions and transition checks passed")
	quit(0 if _failures == 0 else 1)


func _check_drag(ui: InventoryUI, inventory: Inventory) -> void:
	var source: InventorySlotUI = ui.slot_uis[0]
	var target: InventorySlotUI = ui.slot_uis[1]
	var start: Vector2 = source.get_global_rect().get_center()
	_motion(start)
	_button(start, true)
	_motion(start + Vector2(16, 0), true)
	await process_frame
	_check(root.gui_is_dragging(), "Drag starts with feedback enabled")
	_finish_slot_tween(source)
	_check(source.content.modulate.a < 1.0, "Dragged source dims")
	var end: Vector2 = target.get_global_rect().get_center()
	_motion(end, true)
	_check(target._drop_target and target._highlight.visible, "Valid drop target highlights")
	_button(end, false)
	_check(inventory.slots[0].is_empty() and inventory.slots[1].quantity == 5, "Drop moves data")
	_check(ui.selected_slot_index == 1, "Selection follows drop")
	_check(target.content.scale.x > 1.0, "Successful drop gives a scale punch")
	_finish_slot_tween(source)
	_check(source.content.modulate.a == 1.0, "Drag end restores source opacity")
	_check(source.get_global_rect().size == Vector2(64, 64), "Drag leaves slot size unchanged")


func _finish_slot_tween(slot: InventorySlotUI) -> void:
	if slot._visual_tween != null and slot._visual_tween.is_valid():
		slot._visual_tween.pause()
		slot._visual_tween.custom_step(slot.feedback_duration + 0.01)


func _motion(position: Vector2, held: bool = false) -> void:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.relative = position - _mouse_position
	_mouse_position = position
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	root.push_input(event)


func _button(position: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = position
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.pressed = pressed
	root.push_input(event)


func _check(condition: bool, message: String) -> void:
	if not condition:
		_failures += 1
		push_error(message)
