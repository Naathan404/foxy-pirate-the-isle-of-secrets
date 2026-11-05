extends Button
## Match inventory feedback by animating artwork only, keeping the button and grid fixed.

@export_group("Interaction Feedback")
@export_range(1.0, 1.2, 0.01) var hover_scale: float = 1.05
@export_range(0.8, 1.0, 0.01) var pressed_scale: float = 0.94
@export_range(0.05, 0.3, 0.01) var feedback_duration: float = 0.1
@export_range(1.0, 1.3, 0.01) var drop_feedback_scale := 1.12
@export_range(1.0, 1.1, 0.01) var selected_scale := 1.02
@export var hover_tint := Color(1.08, 1.08, 1.08)
@export_range(0.0, 1.0, 0.01) var locked_icon_alpha := 0.35
@export_range(0.0, 1.0, 0.01) var inactive_highlight_alpha := 0.6

var _selected: bool = false
var _hovered: bool = false
var _pressed: bool = false
var _locked: bool = false
var _visual_tween: Tween
var _background_scale: Vector2
var _icon_scale: Vector2

@onready var background: TextureRect = $TextureRect
@onready var item_icon: TextureRect = $Icon
@onready var _highlight: TextureRect = $SelectionHighlight


func _ready() -> void:
	_background_scale = background.scale
	_icon_scale = item_icon.scale
	# The texture supplies the slot frame; remove Button theme art that would stay still.
	for state: StringName in [&"normal", &"hover", &"pressed", &"disabled", &"focus"]:
		add_theme_stylebox_override(state, StyleBoxEmpty.new())
	mouse_entered.connect(_set_hovered.bind(true))
	mouse_exited.connect(_set_hovered.bind(false))
	button_down.connect(_set_pressed.bind(true))
	button_up.connect(_set_pressed.bind(false))
	focus_entered.connect(_animate_visual)
	focus_exited.connect(_animate_visual)
	visibility_changed.connect(_on_visibility_changed)
	resized.connect(_update_pivots.call_deferred)
	_update_pivots.call_deferred()


func present(
	texture: Texture2D, badge: String = "", selected: bool = false, locked: bool = false
) -> void:
	var changed := item_icon.texture != texture or _selected != selected or _locked != locked
	item_icon.texture = texture
	$Badge.text = badge
	$Badge.visible = not badge.is_empty()
	_selected = selected
	_locked = locked
	if changed:
		_animate_visual()


func play_equip_feedback() -> void:
	background.scale = _background_scale * drop_feedback_scale
	item_icon.scale = _icon_scale * drop_feedback_scale
	_animate_visual()


func _set_hovered(hovered: bool) -> void:
	_hovered = hovered and not disabled
	if not _hovered:
		_pressed = false
	_animate_visual()


func _set_pressed(press_active: bool) -> void:
	_pressed = press_active and not disabled
	_animate_visual()


func _on_visibility_changed() -> void:
	if not is_visible_in_tree():
		_hovered = false
		_pressed = false
	_animate_visual()


func _update_pivots() -> void:
	background.pivot_offset = background.size * 0.5
	item_icon.pivot_offset = item_icon.size * 0.5


func _animate_visual() -> void:
	if not is_node_ready():
		return
	if _visual_tween != null and _visual_tween.is_valid():
		_visual_tween.kill()
	var hovered := _hovered and not disabled
	var factor := hover_scale if hovered else (selected_scale if _selected else 1.0)
	if _pressed and not disabled:
		factor = pressed_scale
	var tint := hover_tint if hovered else Color.WHITE
	var icon_tint := Color(tint, locked_icon_alpha if _locked else 1.0)
	_highlight.visible = _selected or hovered or (has_focus() and not disabled)
	_highlight.modulate = Color.WHITE if _selected else Color(1, 1, 1, inactive_highlight_alpha)
	if not is_visible_in_tree():
		background.scale = _background_scale
		item_icon.scale = _icon_scale
		background.modulate = Color.WHITE
		item_icon.modulate = Color(1, 1, 1, locked_icon_alpha if _locked else 1.0)
		return
	_visual_tween = create_tween().set_parallel()
	_visual_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_visual_tween.tween_property(background, "scale", _background_scale * factor, feedback_duration)
	_visual_tween.tween_property(item_icon, "scale", _icon_scale * factor, feedback_duration)
	_visual_tween.tween_property(background, "modulate", tint, feedback_duration)
	_visual_tween.tween_property(item_icon, "modulate", icon_tint, feedback_duration)
