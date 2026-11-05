class_name TortugaCostChip
extends Control

@export_group("Cost Colors")
@export var affordable_color := Color(0.24, 0.48, 0.24)
@export var missing_color := Color(0.68, 0.19, 0.13)

@onready var item_icon: TextureRect = $Icon
@onready var item_name: Label = $Name
@onready var amount_label: Label = $Amount


func set_cost(icon: Texture2D, title: String, current: int, required: int) -> void:
	item_icon.texture = icon
	item_name.text = title
	amount_label.text = "%d / %d" % [current, required]
	amount_label.add_theme_color_override(
		"font_color", affordable_color if current >= required else missing_color
	)
