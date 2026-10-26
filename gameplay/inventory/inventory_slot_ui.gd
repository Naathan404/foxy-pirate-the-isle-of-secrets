class_name InventorySlotUI
extends PanelContainer

signal clicked

@onready var icon: TextureRect = $MarginContainer/Icon
@onready var quantity_label: Label = $MarginContainer/QuantityLabel


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		clicked.emit()
		accept_event()


func refresh(slot: InventorySlot) -> void:
	if slot == null or slot.is_empty():
		icon.texture = null
		quantity_label.hide()
		return
	
	icon.texture = slot.item.icon
	quantity_label.text = str(slot.quantity)

	quantity_label.visible = slot.quantity >= 1
