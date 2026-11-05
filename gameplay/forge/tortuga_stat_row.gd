class_name TortugaStatRow
extends Control

@export_group("Comparison Colors")
@export var neutral_color := Color(0.34, 0.25, 0.18)
@export var positive_color := Color(0.15, 0.48, 0.18)
@export var negative_color := Color(0.72, 0.15, 0.12)

@onready var title_label: Label = $Title
@onready var before_label: Label = $Before
@onready var arrow_label: Label = $Arrow
@onready var after_label: Label = $After


func set_comparison(title: String, before: String, after: String, trend: int) -> void:
	title_label.text = title
	before_label.text = before
	after_label.text = after
	var color := neutral_color
	if trend > 0:
		color = positive_color
	elif trend < 0:
		color = negative_color
	after_label.add_theme_color_override("font_color", color)
	arrow_label.add_theme_color_override("font_color", color)
