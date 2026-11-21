class_name TortugaStatRow
extends HBoxContainer
## One "now -> new" comparison line in the Forge choice popup. The trend is written out
## ("better" / "worse") next to the arrow so it does not depend on color alone.

const BETTER_TEXT := "▲ better"
const WORSE_TEXT := "▼ worse"

@export_group("Comparison Colors")
@export var neutral_color: Color = Color(0.77, 0.61, 0.53)
@export var value_color: Color = Color(0.96, 0.89, 0.77)
@export var positive_color: Color = Color(0.66, 0.85, 0.58)
@export var negative_color: Color = Color(0.95, 0.56, 0.5)

@onready var _title_label: Label = %Title
@onready var _before_label: Label = %Before
@onready var _arrow_label: Label = %Arrow
@onready var _after_label: Label = %After
@onready var _trend_label: Label = %Trend


## `trend` is +1 when the new value helps the player, -1 when it hurts and 0 when unchanged.
func set_comparison(title: String, before: String, after: String, trend: int) -> void:
	_title_label.text = title
	_before_label.text = before
	_after_label.text = after
	var color := value_color
	var trend_text := ""
	if trend > 0:
		color = positive_color
		trend_text = BETTER_TEXT
	elif trend < 0:
		color = negative_color
		trend_text = WORSE_TEXT
	_after_label.add_theme_color_override("font_color", color)
	_arrow_label.add_theme_color_override("font_color", color if trend != 0 else neutral_color)
	_trend_label.text = trend_text
	_trend_label.add_theme_color_override("font_color", color)
	_title_label.add_theme_color_override(
		"font_color", value_color if trend != 0 else neutral_color
	)
	tooltip_text = "%s: %s -> %s" % [title, before, after]
