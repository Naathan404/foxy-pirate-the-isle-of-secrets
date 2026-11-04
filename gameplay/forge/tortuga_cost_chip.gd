class_name TortugaCostChip
extends Control

@onready var item_icon: TextureRect = $Icon
@onready var item_name: Label = $Name
@onready var amount_label: Label = $Amount


func set_cost(icon: Texture2D, title: String, current: int, required: int) -> void:
	item_icon.texture = icon
	item_name.text = title
	amount_label.text = "%d / %d" % [current, required]
	amount_label.add_theme_color_override(
		"font_color", Color(0.24, 0.48, 0.24) if current >= required else Color(0.68, 0.19, 0.13)
	)
