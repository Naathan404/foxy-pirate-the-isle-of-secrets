class_name InventorySlotUI
extends PanelContainer

signal clicked
signal item_dropped(from_index: int, to_index: int)

var inventory: Inventory
var slot_index: int = -1

@onready var icon: TextureRect = $MarginContainer/Icon
@onready var quantity_label: Label = $MarginContainer/QuantityLabel


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		clicked.emit()
		accept_event()


func _get_drag_data(_at_position: Vector2) -> Variant:
	if not is_instance_valid(inventory):
		return null
	var slot: InventorySlot = inventory.get_slot(slot_index)
	if slot == null or slot.is_empty():
		return null

	var preview := Control.new()
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var preview_icon := TextureRect.new()
	preview_icon.texture = slot.item.icon
	preview_icon.texture_filter = texture_filter
	preview_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_icon.position = -size / 2.0
	preview_icon.size = size
	preview_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	preview_icon.modulate.a = 0.7
	preview.add_child(preview_icon)
	var label := Label.new()
	label.label_settings = quantity_label.label_settings
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.position = Vector2(-size.x / 2.0, size.y / 2.0)
	label.text = str(slot.quantity) if slot.item.icon != null else slot.item.display_name
	preview.add_child(label)
	set_drag_preview(preview)

	# Giữ bản chụp để hủy thả nếu item/số lượng nguồn đã thay đổi trong lúc kéo.
	return {
		"inventory": inventory,
		"slot_index": slot_index,
		"item": slot.item,
		"quantity": slot.quantity,
	}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	if not is_visible_in_tree() or not is_instance_valid(inventory) or not data is Dictionary:
		return false
	if data.get("inventory") != inventory or not data.get("slot_index") is int:
		return false
	var from_index: int = data["slot_index"]
	var source: InventorySlot = inventory.get_slot(from_index)
	if source == null or source.is_empty():
		return false
	if source.item != data.get("item") or source.quantity != data.get("quantity"):
		return false
	return inventory.can_move_item(from_index, slot_index)


func _drop_data(at_position: Vector2, data: Variant) -> void:
	if _can_drop_data(at_position, data):
		item_dropped.emit(data["slot_index"], slot_index)


func refresh(slot: InventorySlot) -> void:
	if slot == null or slot.is_empty():
		icon.texture = null
		quantity_label.hide()
		return

	icon.texture = slot.item.icon
	quantity_label.text = str(slot.quantity)

	quantity_label.visible = slot.quantity >= 1
