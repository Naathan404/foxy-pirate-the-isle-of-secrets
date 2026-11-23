class_name RewardCard
extends PanelContainer
## Inventory-styled card shared by the Charm and Blueprint reveals: names the reward,
## describes it and shows the confirm key. Owners position it and drive its modulate.

const CHIP_BORDER_WIDTH := 1
const CHIP_CORNER_RADIUS := 10
const CHIP_PADDING_PIXELS := Vector2i(12, 1)
const CHIP_FILL_ALPHA := 0.18
const CHIP_BORDER_ALPHA := 0.75
const DIVIDER_ALPHA := 0.55
const KEY_CAP_FILL_ALPHA := 0.16
const BODY_MAX_LINES := 4
const PROMPT_MIN_ALPHA := 0.6
const PROMPT_PULSE_SPEED := 3.0

@onready var eyebrow_label: Label = %Eyebrow
@onready var title_label: Label = %Title
@onready var body_label: Label = %Body
@onready var hint_label: Label = %Hint
@onready var _chips: HBoxContainer = %Chips
@onready var _divider: ColorRect = %Divider
@onready var _prompt_row: HBoxContainer = %PromptRow
@onready var _key_label: Label = %KeyLabel
@onready var _prompt_label: Label = %PromptLabel
@onready var _panel_style: StyleBoxFlat = get_theme_stylebox(&"panel") as StyleBoxFlat
@onready var _key_style: StyleBoxFlat = (
	(%KeyCap as PanelContainer).get_theme_stylebox(&"panel") as StyleBoxFlat
)


func _ready() -> void:
	body_label.max_lines_visible = BODY_MAX_LINES


## Fills the card. Empty hint or chips are hidden instead of leaving a gap.
func setup(
	eyebrow: String,
	title: String,
	body: String,
	hint: String,
	chips: PackedStringArray,
	accent: Color
) -> void:
	eyebrow_label.text = eyebrow
	title_label.text = title
	body_label.text = body
	body_label.visible = not body.is_empty()
	hint_label.text = hint
	hint_label.visible = not hint.is_empty()
	_apply_accent(accent)
	_set_chips(chips, accent)


func set_prompt(key_text: String, verb: String) -> void:
	_key_label.text = key_text
	_prompt_label.text = verb


## Gentle pulse that keeps the waiting state alive without moving the layout.
func pulse_prompt(clock_seconds: float) -> void:
	_prompt_row.modulate.a = lerpf(
		PROMPT_MIN_ALPHA, 1.0, (sin(clock_seconds * PROMPT_PULSE_SPEED) + 1.0) / 2.0
	)


func _apply_accent(accent: Color) -> void:
	_panel_style.border_color = accent
	_key_style.bg_color = Color(accent, KEY_CAP_FILL_ALPHA)
	_key_style.border_color = accent
	_divider.color = Color(accent, DIVIDER_ALPHA)
	eyebrow_label.add_theme_color_override(&"font_color", accent.lightened(0.25))


func _set_chips(chips: PackedStringArray, accent: Color) -> void:
	for child in _chips.get_children():
		_chips.remove_child(child)
		child.queue_free()
	_chips.visible = not chips.is_empty()
	for text in chips:
		var chip := PanelContainer.new()
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var style := StyleBoxFlat.new()
		style.bg_color = Color(accent, CHIP_FILL_ALPHA)
		style.border_color = Color(accent, CHIP_BORDER_ALPHA)
		style.set_border_width_all(CHIP_BORDER_WIDTH)
		style.set_corner_radius_all(CHIP_CORNER_RADIUS)
		style.content_margin_left = CHIP_PADDING_PIXELS.x
		style.content_margin_right = CHIP_PADDING_PIXELS.x
		style.content_margin_top = CHIP_PADDING_PIXELS.y
		style.content_margin_bottom = CHIP_PADDING_PIXELS.y
		chip.add_theme_stylebox_override(&"panel", style)
		var label := Label.new()
		label.theme_type_variation = &"BodyLabel"
		label.add_theme_font_size_override(&"font_size", 16)
		label.text = text
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(label)
		_chips.add_child(chip)
