class_name InventorySlotUI
extends PanelContainer

signal clicked
signal item_dropped(from_index: int, to_index: int)

@export_group("Interaction Feedback")
@export_range(1.0, 1.2, 0.01) var hover_scale: float = 1.05
@export_range(0.8, 1.0, 0.01) var pressed_scale: float = 0.94
@export_range(0.05, 0.3, 0.01) var feedback_duration: float = 0.1

var inventory: Inventory
var slot_index: int = -1
var _selected: bool = false
var _hovered: bool = false
var _pressed: bool = false
var _dragging: bool = false
var _drop_target: bool = false
var _visual_tween: Tween
var _background_scale: Vector2
var _content_scale: Vector2
var _highlight: Panel

@onready var background: TextureRect = $Background
@onready var content: MarginContainer = $MarginContainer
@onready var icon: TextureRect = $MarginContainer/Icon
@onready var quantity_label: Label = $MarginContainer/QuantityLabel


func _ready() -> void:
	_background_scale = background.scale
	_content_scale = content.scale
	var style := StyleBoxFlat.new()
	style.draw_center = false
	style.set_border_width_all(2)
	style.border_color = Color.WHITE
	_highlight = Panel.new()
	_highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_highlight.add_theme_stylebox_override("panel", style)
	_highlight.hide()
	add_child(_highlight)
	mouse_entered.connect(_set_hovered.bind(true))
	mouse_exited.connect(_set_hovered.bind(false))
	visibility_changed.connect(_on_visibility_changed)
	resized.connect(_update_pivots.call_deferred)
	_update_pivots.call_deferred()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_pressed = event.pressed
		if event.pressed:
			clicked.emit()
		_animate_visual()
		accept_event()


func _notification(what: int) -> void:
	if what == NOTIFICATION_DRAG_END and is_node_ready():
		_dragging = false
		_drop_target = false
		_pressed = false
		_animate_visual()


func set_selected(selected: bool) -> void:
	if _selected == selected:
		return
	_selected = selected
	_animate_visual()


func play_drop_feedback() -> void:
	background.scale = _background_scale * 1.12
	content.scale = _content_scale * 1.12
	_animate_visual()


func _set_hovered(hovered: bool) -> void:
	_hovered = hovered
	if not hovered:
		_pressed = false
		_drop_target = false
	_animate_visual()


func _on_visibility_changed() -> void:
	if not is_visible_in_tree():
		_hovered = false
		_pressed = false
		_dragging = false
		_drop_target = false
		_animate_visual()


func _update_pivots() -> void:
	background.pivot_offset = background.size * 0.5
	content.pivot_offset = content.size * 0.5


func _animate_visual() -> void:
	if not is_node_ready():
		return
	if _visual_tween != null and _visual_tween.is_valid():
		_visual_tween.kill()
	var factor: float = hover_scale if _hovered else (1.02 if _selected else 1.0)
	if _pressed:
		factor = pressed_scale
	var tint := Color(1.08, 1.08, 1.08) if _hovered else Color.WHITE
	tint.a = 0.4 if _dragging else 1.0
	_highlight.visible = _selected or _hovered or _drop_target
	_highlight.modulate = (
		Color(0.45, 1.0, 0.65)
		if _drop_target
		else (Color(1.0, 0.8, 0.35) if _selected else Color(1, 1, 1, 0.45))
	)
	if not is_visible_in_tree():
		background.scale = _background_scale
		content.scale = _content_scale
		background.modulate = Color.WHITE
		content.modulate = Color.WHITE
		return
	# Scale các hình con; root và vùng nhận click của ô luôn giữ nguyên.
	_visual_tween = create_tween().set_parallel()
	_visual_tween.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_visual_tween.tween_property(background, "scale", _background_scale * factor, feedback_duration)
	_visual_tween.tween_property(content, "scale", _content_scale * factor, feedback_duration)
	_visual_tween.tween_property(background, "modulate", tint, feedback_duration)
	_visual_tween.tween_property(content, "modulate", tint, feedback_duration)


func _get_drag_data(_at_position: Vector2) -> Variant:
	if not is_instance_valid(inventory):
		return null
	var slot: InventorySlot = inventory.get_slot(slot_index)
	if slot == null or slot.is_empty():
		return null
	_dragging = true
	_pressed = false
	_animate_visual()

	var preview := Control.new()
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var preview_icon := TextureRect.new()
	preview_icon.texture = slot.item.icon
	preview_icon.texture_filter = texture_filter
	preview_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview_icon.position = -size / 2.0
	preview_icon.size = size
	preview_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	preview_icon.modulate.a = 0.7
	preview.add_child(preview_icon)
	var label := Label.new()
	label.label_settings = quantity_label.label_settings
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.position = Vector2(-size.x / 2.0, size.y / 2.0)
	label.text = str(slot.quantity) if slot.item.icon != null else slot.item.display_name
	preview.add_child(label)
	set_drag_preview(preview)

	# Giữ bản chụp để hủy thả nếu item/số lượng nguồn đã thay đổi trong lúc kéo.
	return {
		"inventory": inventory,
		"slot_index": slot_index,
		"item": slot.item,
		"quantity": slot.quantity,
	}


func _can_drop_data(_at_position: Vector2, data: Variant) -> bool:
	var valid: bool = _is_valid_drop(data)
	if _drop_target != valid:
		_drop_target = valid
		_animate_visual()
	return valid


func _is_valid_drop(data: Variant) -> bool:
	if not is_visible_in_tree() or not is_instance_valid(inventory) or not data is Dictionary:
		return false
	if data.get("inventory") != inventory or not data.get("slot_index") is int:
		return false
	var from_index: int = data["slot_index"]
	var source: InventorySlot = inventory.get_slot(from_index)
	if source == null or source.is_empty():
		return false
	if source.item != data.get("item") or source.quantity != data.get("quantity"):
		return false
	return inventory.can_move_item(from_index, slot_index)


func _drop_data(at_position: Vector2, data: Variant) -> void:
	if _can_drop_data(at_position, data):
		item_dropped.emit(data["slot_index"], slot_index)


func refresh(slot: InventorySlot) -> void:
	if slot == null or slot.is_empty():
		icon.texture = null
		quantity_label.hide()
		return

	icon.texture = slot.item.icon
	quantity_label.text = str(slot.quantity)

	quantity_label.visible = slot.quantity >= 1
