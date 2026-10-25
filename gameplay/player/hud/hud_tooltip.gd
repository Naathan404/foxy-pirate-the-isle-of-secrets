class_name HudTooltip
extends PanelContainer
## Hiện chỉ số khi hover vaof các thanh trạng thái,
## có delay ghost

@export var hud_layer: CanvasLayer
@export var bars: Array[ArcTooltipBar] = []
@export_range(0.0, 1.0, 0.05) var tooltip_delay: float = 0.2

var _hovered_bar: ArcTooltipBar
var _hover_time: float = 0.0
var _mouse_position: Vector2
var _pointer_inside: bool = false

@onready var value_label: Label = $Value


func _ready() -> void:
	hide()
	_mouse_position = get_viewport().get_mouse_position()
	_pointer_inside = get_viewport().get_visible_rect().has_point(_mouse_position)
	get_viewport().mouse_exited.connect(_on_mouse_exited)


func _process(delta: float) -> void:
	var hovered: ArcTooltipBar = null
	if hud_layer.is_visible() and _pointer_inside:
		for bar: ArcTooltipBar in bars:
			if not is_instance_valid(bar):
				continue
			var local_point := (
				bar.get_global_transform_with_canvas().affine_inverse() * _mouse_position
			)
			if bar.is_visible_in_tree() and bar._has_point(local_point):
				hovered = bar
				break
	if hovered != _hovered_bar:
		_hovered_bar = hovered
		_hover_time = 0.0
	if hovered == null:
		hide()
		return
	_hover_time += delta
	if _hover_time < tooltip_delay or hovered.get_stat_tooltip().is_empty():
		hide()
		return
	value_label.text = hovered.get_stat_tooltip()
	reset_size()
	# Chuyển từ tọa độ viewport sang CanvasLayer để giữ đúng vị trí khi scale HUD.
	var to_local := hud_layer.get_final_transform().affine_inverse()
	var visible_rect := to_local * get_viewport().get_visible_rect()
	var desired := to_local * (_mouse_position + Vector2(14.0, 18.0))
	position = (
		desired
		. clamp(visible_rect.position, (visible_rect.end - size).max(visible_rect.position))
		. round()
	)
	show()


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		_mouse_position = event.position
		_pointer_inside = get_viewport().get_visible_rect().has_point(_mouse_position)


func _on_mouse_exited() -> void:
	_pointer_inside = false
	_hovered_bar = null
	_hover_time = 0.0
	hide()
