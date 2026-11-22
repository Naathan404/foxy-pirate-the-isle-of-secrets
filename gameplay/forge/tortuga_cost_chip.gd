class_name TortugaCostChip
extends PanelContainer
## One cost line for Craft or Forge: icon, name and carried / required amount. A check or cross
## mark and the frame color both tell whether this part of the cost is covered.

const MET_MARK := "✓"
const MISSING_MARK := "✕"
const THOUSAND := 1000
const MILLION := 1000000
## Amounts from here on are shortened ("12.5k") so the chip keeps its width.
const SHORTEN_FROM := 10000

@export_group("Cost Colors")
@export var affordable_color: Color = Color(0.66, 0.85, 0.58)
@export var missing_color: Color = Color(0.95, 0.56, 0.5)
@export var met_border_color: Color = Color(0.77, 0.61, 0.53, 0.8)
@export var missing_border_color: Color = Color(0.85, 0.27, 0.29, 0.95)

@onready var _item_icon: TextureRect = %Icon
@onready var _item_name: Label = %Name
@onready var _amount_label: Label = %Amount
@onready var _mark: Label = %Mark


func set_cost(icon: Texture2D, title: String, current: int, required: int) -> void:
	var met := current >= required
	_item_icon.texture = icon
	_item_name.text = title
	_amount_label.text = "%s / %s" % [_short_number(current), _short_number(required)]
	_amount_label.add_theme_color_override("font_color", affordable_color if met else missing_color)
	_mark.text = MET_MARK if met else MISSING_MARK
	_mark.add_theme_color_override("font_color", affordable_color if met else missing_color)
	tooltip_text = (
		"%s: you have %d, need %d" % [title, current, required]
		+ ("" if met else " (missing %d)" % (required - current))
	)
	var style := get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	if style != null:
		style.border_color = met_border_color if met else missing_border_color
		add_theme_stylebox_override("panel", style)


## Keeps large purses from pushing the chip wider than its column.
func _short_number(value: int) -> String:
	if value >= MILLION:
		return InventoryMenuFormat.number(float(value) / MILLION) + "M"
	if value >= SHORTEN_FROM:
		return InventoryMenuFormat.number(float(value) / THOUSAND) + "k"
	return str(value)
