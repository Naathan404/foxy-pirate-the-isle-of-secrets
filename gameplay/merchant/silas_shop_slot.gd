class_name SilasShopSlot
extends Control

signal clicked

@onready var frame: TextureRect = $Frame
@onready var icon: TextureRect = $Icon
@onready var quantity_label: Label = $Quantity
@onready var selection: TextureRect = $Selection
@onready var price_plate: TextureRect = $PricePlate
@onready var price_label: Label = $PricePlate/Price


func _ready() -> void:
	mouse_entered.connect(_set_hovered.bind(true))
	mouse_exited.connect(_set_hovered.bind(false))


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			grab_focus()
			clicked.emit()
		accept_event()
	elif event.is_action_pressed(&"ui_accept"):
		clicked.emit()
		accept_event()


func set_item(item_icon: Texture2D, quantity: int, price: int = 0, show_price: bool = true) -> void:
	icon.texture = item_icon
	quantity_label.text = str(quantity)
	quantity_label.visible = quantity > 1
	price_plate.visible = show_price and price > 0
	price_label.text = str(price)


func set_selected(selected: bool) -> void:
	selection.visible = selected


func set_unavailable(unavailable: bool) -> void:
	modulate = Color(0.58, 0.56, 0.52) if unavailable else Color.WHITE


func _set_hovered(hovered: bool) -> void:
	frame.modulate = Color(1.15, 1.12, 1.05) if hovered else Color.WHITE
