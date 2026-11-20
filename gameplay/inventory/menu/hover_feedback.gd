class_name InventoryHoverFeedback
extends Node
## Hover lift, press squash and release punch for one clickable menu control.
## Add as a child of the control; `target` is the visual that scales (defaults to the parent).
## Clicking a disabled button shakes it so the refusal is felt, not only read.

const DEFAULT_LIFT := 1.06
const CENTER_RATIO := 0.5

@export_range(1.0, 1.3, 0.01) var hover_scale: float = DEFAULT_LIFT
@export_range(0.7, 1.0, 0.01) var press_scale: float = 0.92
@export_range(1.0, 1.4, 0.01) var release_scale: float = 1.12
@export var hover_tint: Color = Color(1.12, 1.08, 1.04)
@export_range(0.03, 0.3, 0.01, "suffix:s") var hover_seconds: float = 0.12
@export_range(0.02, 0.2, 0.01, "suffix:s") var press_seconds: float = 0.06
@export_range(0.05, 0.4, 0.01, "suffix:s") var settle_seconds: float = 0.2

var target: Control

var _source: Control
var _hovered: bool = false
var _tween: Tween


## Creates and attaches the feedback node; returns it so callers can tune exports.
static func attach(
	source: Control, visual: Control = null, lift: float = DEFAULT_LIFT
) -> InventoryHoverFeedback:
	var feedback := InventoryHoverFeedback.new()
	feedback.name = "HoverFeedback"
	feedback.target = visual if visual != null else source
	feedback.hover_scale = lift
	source.add_child(feedback)
	return feedback


func _ready() -> void:
	_source = get_parent() as Control
	if _source == null:
		push_error("InventoryHoverFeedback must be a child of a Control")
		return
	if target == null:
		target = _source
	_source.mouse_entered.connect(_set_hovered.bind(true))
	_source.mouse_exited.connect(_set_hovered.bind(false))
	_source.focus_entered.connect(_set_hovered.bind(true))
	_source.focus_exited.connect(_set_hovered.bind(false))
	_source.visibility_changed.connect(_on_visibility_changed)
	_source.gui_input.connect(_on_gui_input)
	if _source is BaseButton:
		var button := _source as BaseButton
		button.button_down.connect(_on_pressed_down)
		button.button_up.connect(_on_released)
	target.resized.connect(_update_pivot)
	_update_pivot()


func _is_disabled() -> bool:
	return _source is BaseButton and (_source as BaseButton).disabled


func _set_hovered(hovered: bool) -> void:
	_hovered = hovered
	_settle(hover_seconds)


func _on_visibility_changed() -> void:
	if not _source.is_visible_in_tree():
		_hovered = false
		_kill()
		target.scale = Vector2.ONE
		target.modulate = Color(Color.WHITE, target.modulate.a)


func _on_gui_input(event: InputEvent) -> void:
	var mouse := event as InputEventMouseButton
	if mouse == null or not mouse.pressed or mouse.button_index != MOUSE_BUTTON_LEFT:
		return
	if _is_disabled():
		InventoryMenuFx.shake(target)
	elif not _source is BaseButton:
		_on_pressed_down()


func _on_pressed_down() -> void:
	_update_pivot()
	_kill()
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(target, "scale", Vector2.ONE * press_scale, press_seconds)


func _on_released() -> void:
	_kill()
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(target, "scale", Vector2.ONE * release_scale, press_seconds)
	_tween.tween_callback(_settle.bind(settle_seconds))


func _settle(seconds: float) -> void:
	if not is_instance_valid(target) or not target.is_inside_tree():
		return
	_update_pivot()
	_kill()
	var lifted := _hovered and not _is_disabled()
	var tint := hover_tint if lifted else Color.WHITE
	tint.a = target.modulate.a
	_tween = create_tween().set_parallel()
	_tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tween.tween_property(target, "scale", Vector2.ONE * (hover_scale if lifted else 1.0), seconds)
	_tween.tween_property(target, "modulate", tint, seconds)


func _update_pivot() -> void:
	if is_instance_valid(target):
		target.pivot_offset = target.size * CENTER_RATIO


func _kill() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
