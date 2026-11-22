class_name InventoryFilterChip
extends Button
## Filter entry drawn on the artist's red ribbon when active. The ribbon shape and marker make the
## active filter readable without relying on color.

@export var chip_icon: Texture2D
@export var chip_text: String = ""
@export_range(12, 40, 1) var text_size: int = 26
@export var icon_size: Vector2 = Vector2(34, 34)
## Left inset that keeps the content clear of the ribbon's sparkle tip.
@export_range(0.0, 60.0, 1.0, "suffix:px") var content_inset: float = 30.0
@export var idle_color: Color = Color(0.77, 0.61, 0.53)
@export var active_color: Color = Color(0.98, 0.93, 0.86)
## Brightens the tan line-art icons when the chip is active or hovered.
@export var active_icon_tint: Color = Color(1.25, 1.2, 1.15)
@export_range(1.0, 1.2, 0.01) var hover_scale: float = 1.04

var _active: bool = false
var _hovered: bool = false

@onready var _highlight: TextureRect = %Highlight
@onready var _icon: TextureRect = %ChipIcon
@onready var _label: Label = %ChipLabel
@onready var _content: Control = %Content


func _ready() -> void:
	_icon.texture = chip_icon
	_icon.custom_minimum_size = icon_size
	_content.offset_left = content_inset
	_label.text = chip_text
	_label.visible = not chip_text.is_empty()
	_label.add_theme_font_size_override("font_size", text_size)
	if tooltip_text.is_empty():
		tooltip_text = chip_text
	InventoryHoverFeedback.attach(self, null, hover_scale)
	mouse_entered.connect(_set_hovered.bind(true))
	mouse_exited.connect(_set_hovered.bind(false))
	focus_entered.connect(_set_hovered.bind(true))
	focus_exited.connect(_set_hovered.bind(false))
	_apply()


func set_active(active: bool) -> void:
	_active = active
	_apply()


func is_active() -> bool:
	return _active


func _set_hovered(hovered: bool) -> void:
	_hovered = hovered
	_apply()


func _apply() -> void:
	if not is_node_ready():
		return
	_highlight.visible = _active
	var bright := _active or _hovered
	_label.add_theme_color_override("font_color", active_color if bright else idle_color)
	_icon.modulate = active_icon_tint if bright else Color.WHITE
