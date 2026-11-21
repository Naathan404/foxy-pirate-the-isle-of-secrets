class_name InventoryMenuTabButton
extends Button
## One tab of the top bar. The active tab shows the red banner and the white icon variant, so it
## stays readable without relying on color.

@export var idle_icon: Texture2D
@export var active_icon: Texture2D
@export var title: String = ""
@export var idle_color: Color = Color(0.77, 0.61, 0.53)
@export var active_color: Color = Color(0.98, 0.93, 0.86)
@export var hover_color: Color = Color(0.92, 0.82, 0.74)
@export_range(1.0, 1.3, 0.01) var hover_scale: float = 1.08
## The banner unrolls from the top edge when the tab becomes active.
@export_range(0.0, 1.0, 0.01) var banner_drop_from: float = 0.15
@export_range(0.05, 0.6, 0.01, "suffix:s") var banner_drop_seconds: float = 0.32

var _active: bool = false
var _hovered: bool = false
var _banner_tween: Tween

@onready var _banner: TextureRect = %Banner
@onready var _content: Control = %Content
@onready var _icon: TextureRect = %TabIcon
@onready var _title: Label = %TabTitle


func _ready() -> void:
	_title.text = title
	tooltip_text = title
	InventoryHoverFeedback.attach(self, _content, hover_scale)
	mouse_entered.connect(_set_hovered.bind(true))
	mouse_exited.connect(_set_hovered.bind(false))
	focus_entered.connect(_set_hovered.bind(true))
	focus_exited.connect(_set_hovered.bind(false))
	_apply()


func set_active(active: bool, animate: bool = true) -> void:
	var became_active := active and not _active
	_active = active
	_apply()
	if became_active and animate and is_visible_in_tree():
		_drop_banner()


func _set_hovered(hovered: bool) -> void:
	_hovered = hovered
	_apply()


func _apply() -> void:
	if not is_node_ready():
		return
	_banner.visible = _active
	_icon.texture = active_icon if _active else idle_icon
	var color := active_color if _active else (hover_color if _hovered else idle_color)
	_title.add_theme_color_override("font_color", color)


func _drop_banner() -> void:
	if _banner_tween != null and _banner_tween.is_valid():
		_banner_tween.kill()
	_banner.pivot_offset = Vector2(_banner.size.x * 0.5, 0.0)
	_banner.scale = Vector2(1.0, banner_drop_from)
	_banner_tween = create_tween()
	_banner_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_banner_tween.tween_property(_banner, "scale", Vector2.ONE, banner_drop_seconds)
